import 'dart:async';

import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/core/network/connectivity_service.dart';
import 'package:dubagest/core/sync/sync_contracts.dart';
import 'package:dubagest/core/sync/sync_models.dart';

/// Serveur en mémoire respectant le contrat de `public.sync_push` :
/// version contrôlée, suppression logique, rejeu idempotent par op_id.
class FakeSyncServer implements SyncRemoteGateway {
  final rows = <String, Map<String, dynamic>>{};

  /// Table de chaque ligne envoyée (les lignes « externes » valent pour toutes).
  final _tableDe = <String, String>{};
  final _applied = <String, PushResult>{};
  final pushedOps = <String>[];
  int applyCount = 0;
  DateTime _clock = DateTime.utc(2026, 10, 3, 10);

  /// Erreur levée au prochain push (une seule fois).
  Failure? failNextPush;

  /// Applique l'opération puis simule une réponse perdue (réseau).
  bool loseNextResponse = false;

  String _tick() => (_clock = _clock.add(const Duration(seconds: 1))).toIso8601String();

  /// Modification faite par un autre appareil.
  void externalUpsert(Map<String, dynamic> row) {
    final current = rows[row['id']];
    rows[row['id'] as String] = {
      ...?current,
      ...row,
      'version': ((current?['version'] as int?) ?? 0) + 1,
      'updated_at': _tick(),
      'deleted_at': row['deleted_at'],
    };
  }

  @override
  Future<PushResult> push(SyncOperation op) async {
    pushedOps.add(op.id);
    if (failNextPush case final f?) {
      failNextPush = null;
      throw f;
    }
    if (_applied[op.id] case final previous?) {
      return PushResult(previous.status, previous.row, replayed: true);
    }

    final current = rows[op.recordId];
    _tableDe[op.recordId] = op.entityTable;
    late PushResult result;
    switch (op.type) {
      case SyncOperationType.insert:
        rows[op.recordId] = {
          ...op.payload,
          'id': op.recordId,
          'version': 1,
          'updated_at': _tick(),
          'deleted_at': null,
        };
        applyCount++;
        result = PushResult(PushStatus.applied, Map.of(rows[op.recordId]!));
      case SyncOperationType.update || SyncOperationType.delete:
        if (current == null) {
          result = const PushResult(PushStatus.notFound, null);
        } else if (current['version'] != op.baseVersion || current['deleted_at'] != null) {
          result = PushResult(PushStatus.conflict, Map.of(current));
        } else {
          final ts = _tick();
          rows[op.recordId] = {
            ...current,
            if (op.type == SyncOperationType.update) ...op.payload,
            if (op.type == SyncOperationType.delete) 'deleted_at': ts,
            'version': (current['version'] as int) + 1,
            'updated_at': ts,
          };
          applyCount++;
          result = PushResult(PushStatus.applied, Map.of(rows[op.recordId]!));
        }
    }
    _applied[op.id] = result;
    if (loseNextResponse) {
      loseNextResponse = false;
      throw const Failure(FailureKind.network);
    }
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> pull({
    required String table,
    required String entrepriseId,
    required String? afterUpdatedAt,
    required String? afterId,
    required int limit,
  }) async {
    final after = afterUpdatedAt == null ? null : DateTime.parse(afterUpdatedAt);
    final sorted = rows.values
        .where((r) => r['entreprise_id'] == entrepriseId)
        .where((r) => (_tableDe[r['id']] ?? table) == table)
        .where((r) {
          if (after == null) return true;
          final ts = DateTime.parse(r['updated_at'] as String);
          return ts.isAfter(after) ||
              (ts.isAtSameMomentAs(after) && afterId != null && (r['id'] as String).compareTo(afterId) > 0);
        })
        .toList()
      ..sort((a, b) {
        final c = (a['updated_at'] as String).compareTo(b['updated_at'] as String);
        return c != 0 ? c : (a['id'] as String).compareTo(b['id'] as String);
      });
    return sorted.take(limit).map(Map<String, dynamic>.of).toList();
  }
}

class FakeConnectivity implements ConnectivityService {
  FakeConnectivity({this.online = true});
  bool online;
  final _changes = StreamController<bool>.broadcast();

  void set(bool value) {
    online = value;
    _changes.add(value);
  }

  @override
  Stream<bool> get onlineChanges => _changes.stream;

  @override
  Future<bool> isOnline() async => online;
}
