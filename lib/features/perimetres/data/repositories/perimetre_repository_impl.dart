import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/sync/sync_contracts.dart';
import '../../../../core/sync/sync_models.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../domain/entities/perimetre.dart';
import '../../domain/repositories/perimetre_repository.dart';
import '../datasources/perimetre_local_data_source.dart';
import '../models/perimetre_mapper.dart';

/// UI → Repository → base locale + file de synchronisation → (moteur) → Supabase.
class PerimetreRepositoryImpl implements PerimetreRepository {
  PerimetreRepositoryImpl({
    required PerimetreLocalDataSource local,
    required SyncQueueStore queue,
    required LocalTransaction transaction,
    required String? Function() currentUserId,
    required SyncTrigger requestSync,
    Uuid uuid = const Uuid(),
  })  : _local = local,
        _queue = queue,
        _transaction = transaction,
        _currentUserId = currentUserId,
        _requestSync = requestSync,
        _uuid = uuid;

  static const table = 'perimetres';

  final PerimetreLocalDataSource _local;
  final SyncQueueStore _queue;
  final LocalTransaction _transaction;
  final String? Function() _currentUserId;
  final SyncTrigger _requestSync;
  final Uuid _uuid;

  @override
  Stream<List<Perimetre>> watch(String entrepriseId) => _local.watch(entrepriseId);

  @override
  Future<int> compter(String entrepriseId, ActiviteCode activite) =>
      _guard(() => _local.countActive(entrepriseId, activite));

  @override
  Future<Perimetre> creer({
    required String entrepriseId,
    required ActiviteCode activite,
    required PerimetreType type,
    required String nom,
    String? code,
  }) async {
    final userId = _requireUser();
    final perimetre = Perimetre(
      id: _uuid.v4(),
      entrepriseId: entrepriseId,
      activite: activite,
      type: type,
      nom: nom,
      code: code,
      syncStatus: RecordSyncStatus.pendingSync,
    );
    await _write(() async {
      await _local.insertLocal(perimetre);
      await _queue.enqueue(
        userId: userId,
        entityTable: table,
        recordId: perimetre.id,
        type: SyncOperationType.insert,
        payload: PerimetreMapper.toInsertPayload(perimetre),
      );
    });
    return perimetre;
  }

  @override
  Future<void> modifier(
    Perimetre perimetre, {
    required String nom,
    required String? code,
    required PerimetreType type,
    required bool estActif,
  }) {
    final userId = _requireUser();
    return _write(() async {
      await _local.updateLocal(perimetre.id,
          nom: nom, code: Value(code), type: type, estActif: estActif);
      await _queue.enqueue(
        userId: userId,
        entityTable: table,
        recordId: perimetre.id,
        type: SyncOperationType.update,
        payload: {'nom': nom, 'code': code, 'type': type.code, 'est_actif': estActif},
        baseVersion: perimetre.version,
      );
    });
  }

  @override
  Future<void> supprimer(Perimetre perimetre) {
    final userId = _requireUser();
    return _write(() async {
      // Jamais synchronisé : rien n'existe côté serveur, la ligne disparaît.
      if (perimetre.version == null) {
        await _local.hardDelete(perimetre.id);
      } else {
        await _local.markDeletedLocal(perimetre.id);
      }
      await _queue.enqueue(
        userId: userId,
        entityTable: table,
        recordId: perimetre.id,
        type: SyncOperationType.delete,
        payload: const {},
        baseVersion: perimetre.version,
      );
    });
  }

  String _requireUser() =>
      _currentUserId() ?? (throw const Failure(FailureKind.sessionExpired));

  Future<void> _write(Future<void> Function() action) async {
    await _guard(() => _transaction(action));
    _requestSync();
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Failure {
      rethrow;
    } catch (e, st) {
      throw Failure(FailureKind.localStorage, cause: e, stackTrace: st);
    }
  }
}
