import 'dart:async';
import 'dart:math' as math;

import '../errors/error_mapper.dart';
import '../errors/failure.dart';
import '../network/connectivity_service.dart';
import '../utils/app_logger.dart';
import 'sync_contracts.dart';
import 'sync_models.dart';

/// Utilisateur et entreprise pour lesquels la synchronisation tourne.
class SyncScope {
  const SyncScope({required this.userId, required this.entrepriseId});
  final String userId;
  final String entrepriseId;

  @override
  bool operator ==(Object other) =>
      other is SyncScope && other.userId == userId && other.entrepriseId == entrepriseId;

  @override
  int get hashCode => Object.hash(userId, entrepriseId);
}

/// Moteur de synchronisation bidirectionnelle.
///
/// 1. Montée : opérations en file, dans l'ordre, une par une. Une erreur
///    transitoire arrête la montée (ordre préservé) et planifie un réessai
///    avec backoff exponentiel. Un refus définitif marque l'opération REJECTED.
/// 2. Descente : pour chaque entité, lignes modifiées depuis le curseur.
class SyncEngine {
  SyncEngine({
    required SyncQueueStore queue,
    required SyncRemoteGateway remote,
    required SyncCursorStore cursors,
    required ConnectivityService connectivity,
    required List<SyncEntityHandler> handlers,
    this.periodicInterval = const Duration(seconds: 15),
    this.pullPageSize = 200,
    this.pullOverlap = const Duration(minutes: 2),
    DateTime Function()? clock,
  })  : _queue = queue,
        _remote = remote,
        _cursors = cursors,
        _connectivity = connectivity,
        _handlers = {for (final h in handlers) h.table: h},
        _clock = clock ?? DateTime.now;

  final SyncQueueStore _queue;
  final SyncRemoteGateway _remote;
  final SyncCursorStore _cursors;
  final ConnectivityService _connectivity;
  final Map<String, SyncEntityHandler> _handlers;
  final DateTime Function() _clock;
  final Duration periodicInterval;
  final int pullPageSize;

  /// Relecture d'une fenêtre passée : couvre les transactions validées après
  /// d'autres plus récentes (l'application locale est idempotente).
  final Duration pullOverlap;

  static const _tag = 'sync';
  static const _maxBackoff = Duration(minutes: 15);
  static const _definitiveFailures = {
    FailureKind.businessRule,
    FailureKind.forbidden,
    FailureKind.duplicate,
    FailureKind.notFound,
    FailureKind.conflict,
  };

  final _states = StreamController<SyncState>.broadcast();
  SyncState _state = const SyncState();
  SyncScope? _scope;
  Future<void>? _inFlight;
  bool _rerun = false;
  bool _forceNext = false;
  Timer? _timer;
  StreamSubscription<bool>? _connectivitySub;
  StreamSubscription<int>? _pendingSub;

  Stream<SyncState> get states => _states.stream;
  SyncState get state => _state;
  SyncScope? get scope => _scope;

  Future<void> setScope(SyncScope? scope) async {
    if (scope == _scope) return;
    await _detach();
    _scope = scope;
    _emit(const SyncState());
    if (scope == null) return;

    await _queue.recoverInterrupted(scope.userId);
    _pendingSub = _queue.watchPendingCount(scope.userId).distinct().listen((count) {
      final increased = count > _state.pendingCount;
      _emit(_state.copyWith(pendingCount: count));
      if (increased) requestSync();
    });
    _connectivitySub = _connectivity.onlineChanges.listen((online) {
      if (online) {
        requestSync(force: true);
      } else {
        _emit(_state.copyWith(phase: SyncPhase.offline));
      }
    });
    _timer = Timer.periodic(periodicInterval, (_) => requestSync());
    requestSync();
  }

  void requestSync({bool force = false}) {
    if (force) _forceNext = true;
    unawaited(syncNow(force: force));
  }

  /// Lance un cycle ; si un cycle tourne déjà, en programme un nouveau à sa
  /// suite et renvoie le cycle en cours (qui inclut ce nouveau passage).
  Future<void> syncNow({bool force = false}) {
    if (_scope == null) return Future.value();
    if (force) _forceNext = true;
    if (_inFlight case final running?) {
      _rerun = true;
      return running;
    }
    return _inFlight = _run().whenComplete(() => _inFlight = null);
  }

  Future<void> _run() async {
    final scope = _scope;
    if (scope == null) return;
    try {
      do {
        _rerun = false;
        final force = _forceNext;
        _forceNext = false;
        if (!await _connectivity.isOnline()) {
          _emit(_state.copyWith(phase: SyncPhase.offline));
          return;
        }
        _emit(_state.copyWith(phase: SyncPhase.syncing));

        final (pushed, pushError) = await _push(scope, force: force);
        if (!identical(scope, _scope)) return;
        await _pull(scope);
        if (!identical(scope, _scope)) return;

        _emit(_state.copyWith(
          phase: pushed ? SyncPhase.idle : SyncPhase.error,
          lastSyncedAt: _clock(),
          pendingCount: await _queue.pendingCount(scope.userId),
          lastError: pushed ? null : pushError,
        ));
        // Après un échec transitoire, pas de relance immédiate : le réessai
        // suit le backoff (minuteur périodique, retour du réseau).
        if (!pushed) return;
      } while (_rerun);
    } catch (e, st) {
      final failure = ErrorMapper.map(e, st);
      AppLogger.warning('Synchronisation interrompue', tag: _tag, error: failure);
      await _queue.log('error', 'Synchronisation interrompue : $failure');
      if (identical(scope, _scope)) {
        _emit(_state.copyWith(
          phase: failure.kind == FailureKind.network ? SyncPhase.offline : SyncPhase.error,
          lastError: failure.toString(),
        ));
      }
    }
  }

  /// Retourne `false` si une opération a échoué de façon transitoire.
  Future<(bool, String?)> _push(SyncScope scope, {bool force = false}) async {
    final operations = await _queue.due(scope.userId, _clock(), force: force);
    // Versions serveur obtenues pendant ce cycle : une modification qui suit
    // la création (ou une autre modification) de la même ligne part de la
    // nouvelle version, même si elle a été lue avant le rebase en base.
    final versions = <(String, String), int>{};
    for (final lue in operations) {
      if (!identical(scope, _scope)) return (false, null);
      final connue = versions[(lue.entityTable, lue.recordId)];
      final op = connue != null && lue.type != SyncOperationType.insert ? lue.withBaseVersion(connue) : lue;
      final handler = _handlers[op.entityTable];
      if (handler == null) {
        await _queue.markRejected(op.id, 'Aucun gestionnaire pour ${op.entityTable}');
        continue;
      }

      await _queue.markSyncing(op.id);
      try {
        final result = await _remote.push(op);
        switch (result.status) {
          case PushStatus.applied:
            await handler.onPushApplied(op, result.row);
            await _queue.remove(op.id);
            final version = result.row?['version'];
            if (version is int) {
              versions[(op.entityTable, op.recordId)] = version;
              await _queue.rebase(op.entityTable, op.recordId, version);
            }
            await _queue.log('info', '${op.type.wire} ${op.entityTable}/${op.recordId} appliqué'
                '${result.replayed ? ' (rejeu)' : ''}', opId: op.id);
          case PushStatus.conflict:
            await handler.onConflict(op, result.row);
            await _queue.markConflict(op.id);
            await _queue.log('warning', 'Conflit ${op.entityTable}/${op.recordId} : '
                'version serveur conservée', opId: op.id);
          case PushStatus.notFound:
          case PushStatus.forbidden:
            final failure = Failure(result.status == PushStatus.notFound
                ? FailureKind.notFound
                : FailureKind.forbidden);
            await handler.onRejected(op, failure);
            await _queue.markRejected(op.id, result.status.name);
            await _queue.log('error', 'Refus ${result.status.name} ${op.entityTable}/${op.recordId}',
                opId: op.id);
        }
      } catch (e, st) {
        final failure = ErrorMapper.map(e, st);
        if (_definitiveFailures.contains(failure.kind)) {
          await handler.onRejected(op, failure);
          await _queue.markRejected(op.id, failure.toString());
          await _queue.log('error', 'Rejet ${op.entityTable}/${op.recordId} : $failure', opId: op.id);
          continue;
        }
        await _queue.markFailed(op.id, failure.toString(), _clock().add(backoffFor(op.attempts)));
        await _queue.log('warning', 'Échec transitoire (tentative ${op.attempts + 1}) : $failure',
            opId: op.id);
        return (false, failure.toString());
      }
    }
    return (true, null);
  }

  Future<void> _pull(SyncScope scope) async {
    for (final handler in _handlers.values) {
      final stored = await _cursors.read(handler.table, scope.entrepriseId);
      String? afterTs;
      String? afterId;
      if (stored != null) {
        final (ts, _) = _decodeCursor(stored);
        afterTs = DateTime.parse(ts).toUtc().subtract(pullOverlap).toIso8601String();
      }

      while (true) {
        if (!identical(scope, _scope)) return;
        final rows = await _remote.pull(
          table: handler.table,
          entrepriseId: scope.entrepriseId,
          afterUpdatedAt: afterTs,
          afterId: afterId,
          limit: pullPageSize,
        );
        if (rows.isEmpty) break;
        await handler.applyRemoteRows(rows);
        afterTs = rows.last['updated_at'] as String;
        afterId = (rows.last['id'] ?? rows.last['contact_id'])?.toString() ?? '';
        await _cursors.write(handler.table, scope.entrepriseId, _encodeCursor(afterTs, afterId));
        if (rows.length < pullPageSize) break;
      }
    }
  }

  static Duration backoffFor(int attempts) {
    final seconds = 5 * math.pow(2, math.min(attempts, 10)).toInt();
    final delay = Duration(seconds: seconds);
    return delay > _maxBackoff ? _maxBackoff : delay;
  }

  static String _encodeCursor(String ts, String id) => '$ts|$id';
  static (String, String) _decodeCursor(String raw) {
    final i = raw.lastIndexOf('|');
    return i < 0 ? (raw, '') : (raw.substring(0, i), raw.substring(i + 1));
  }

  void _emit(SyncState state) {
    _state = state;
    if (!_states.isClosed) _states.add(state);
  }

  Future<void> _detach() async {
    _timer?.cancel();
    _timer = null;
    await _connectivitySub?.cancel();
    await _pendingSub?.cancel();
    _connectivitySub = null;
    _pendingSub = null;
  }

  Future<void> dispose() async {
    await _detach();
    _scope = null;
    await _states.close();
  }
}
