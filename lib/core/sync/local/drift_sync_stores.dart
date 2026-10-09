import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../database/app_database.dart';
import '../sync_contracts.dart';
import '../sync_models.dart';

class DriftSyncQueueStore implements SyncQueueStore {
  DriftSyncQueueStore(this._db, {Uuid uuid = const Uuid()}) : _uuid = uuid;

  final AppDatabase _db;
  final Uuid _uuid;

  static const _journalMax = 500;
  static final _waiting = [SyncOpStatus.pending.name, SyncOpStatus.failed.name];

  @override
  Future<void> enqueue({
    required String userId,
    required String entityTable,
    required String recordId,
    required SyncOperationType type,
    required Map<String, dynamic> payload,
    int? baseVersion,
    bool fusionner = true,
  }) {
    return _db.transaction(() async {
      final existing = !fusionner
          ? null
          : await (_db.select(_db.syncQueue)
            ..where((q) =>
                q.userId.equals(userId) &
                q.entityTable.equals(entityTable) &
                q.recordId.equals(recordId) &
                q.status.isIn(_waiting))
            ..orderBy([(q) => OrderingTerm.desc(q.createdAt)])
            ..limit(1))
          .getSingleOrNull();

      if (existing != null) {
        final previous = SyncOperationType.fromWire(existing.operation);
        final merged = {...jsonDecode(existing.payload) as Map<String, dynamic>, ...payload};
        final row = _db.update(_db.syncQueue)..where((q) => q.id.equals(existing.id));
        const reset = SyncQueueCompanion(
          status: Value('pending'),
          nextAttemptAt: Value(null),
          lastError: Value(null),
        );

        switch ((previous, type)) {
          // Créé puis supprimé avant tout envoi : rien à transmettre.
          case (SyncOperationType.insert, SyncOperationType.delete):
            await (_db.delete(_db.syncQueue)..where((q) => q.id.equals(existing.id))).go();
            return;
          case (SyncOperationType.insert, SyncOperationType.update):
          case (SyncOperationType.update, SyncOperationType.update):
            await row.write(reset.copyWith(payload: Value(jsonEncode(merged))));
            return;
          case (SyncOperationType.update, SyncOperationType.delete):
            await row.write(reset.copyWith(
              operation: Value(SyncOperationType.delete.wire),
              payload: const Value('{}'),
            ));
            return;
          default:
            break;
        }
      }

      await _db.into(_db.syncQueue).insert(SyncQueueCompanion.insert(
            id: _uuid.v4(),
            userId: userId,
            entityTable: entityTable,
            recordId: recordId,
            operation: type.wire,
            payload: jsonEncode(payload),
            baseVersion: Value(baseVersion),
            status: SyncOpStatus.pending.name,
            createdAt: DateTime.now(),
          ));
    });
  }

  @override
  Future<List<SyncOperation>> due(String userId, DateTime now) async {
    final rows = await (_db.select(_db.syncQueue)
          ..where((q) =>
              q.userId.equals(userId) &
              q.status.isIn(_waiting) &
              (q.nextAttemptAt.isNull() | q.nextAttemptAt.isSmallerOrEqualValue(now)))
          ..orderBy([(q) => OrderingTerm.asc(q.createdAt)]))
        .get();
    return rows.map(_toOperation).toList();
  }

  @override
  Future<void> markSyncing(String opId) => _setStatus(opId, SyncOpStatus.syncing);

  @override
  Future<void> remove(String opId) =>
      (_db.delete(_db.syncQueue)..where((q) => q.id.equals(opId))).go();

  @override
  Future<void> markFailed(String opId, String error, DateTime nextAttemptAt) {
    return _db.transaction(() async {
      final query = _db.select(_db.syncQueue)..where((q) => q.id.equals(opId));
      final row = await query.getSingleOrNull();
      if (row == null) return;
      await (_db.update(_db.syncQueue)..where((q) => q.id.equals(opId))).write(SyncQueueCompanion(
        status: Value(SyncOpStatus.failed.name),
        attempts: Value(row.attempts + 1),
        lastError: Value(error),
        nextAttemptAt: Value(nextAttemptAt),
      ));
    });
  }

  @override
  Future<void> markRejected(String opId, String error) =>
      (_db.update(_db.syncQueue)..where((q) => q.id.equals(opId))).write(SyncQueueCompanion(
        status: Value(SyncOpStatus.rejected.name),
        lastError: Value(error),
      ));

  @override
  Future<void> markConflict(String opId) => _setStatus(opId, SyncOpStatus.conflict);

  @override
  Future<void> abandonner(String entityTable, String recordId) => (_db.delete(_db.syncQueue)
        ..where((q) =>
            q.entityTable.equals(entityTable) &
            q.recordId.equals(recordId) &
            q.status.isIn([SyncOpStatus.rejected.name, SyncOpStatus.conflict.name])))
      .go();

  @override
  Future<void> rebase(String entityTable, String recordId, int newVersion) =>
      (_db.update(_db.syncQueue)
            ..where((q) =>
                q.entityTable.equals(entityTable) &
                q.recordId.equals(recordId) &
                q.status.isIn(_waiting)))
          .write(SyncQueueCompanion(baseVersion: Value(newVersion)));

  @override
  Future<void> recoverInterrupted(String userId) =>
      (_db.update(_db.syncQueue)
            ..where((q) => q.userId.equals(userId) & q.status.equals(SyncOpStatus.syncing.name)))
          .write(SyncQueueCompanion(status: Value(SyncOpStatus.pending.name)));

  @override
  Stream<int> watchPendingCount(String userId) => _pendingCountQuery(userId).watchSingle();

  @override
  Future<int> pendingCount(String userId) => _pendingCountQuery(userId).getSingle();

  Selectable<int> _pendingCountQuery(String userId) {
    final count = _db.syncQueue.id.count();
    return (_db.selectOnly(_db.syncQueue)
          ..addColumns([count])
          ..where(_db.syncQueue.userId.equals(userId) &
              _db.syncQueue.status.isIn([..._waiting, SyncOpStatus.syncing.name])))
        .map((r) => r.read(count) ?? 0);
  }

  @override
  Future<void> log(String level, String message, {String? opId}) async {
    final id = await _db.into(_db.syncJournal).insert(SyncJournalCompanion.insert(
          at: DateTime.now(),
          level: level,
          opId: Value(opId),
          message: message,
        ));
    if (id % 50 == 0) {
      await (_db.delete(_db.syncJournal)..where((j) => j.id.isSmallerOrEqualValue(id - _journalMax)))
          .go();
    }
  }

  Future<void> _setStatus(String opId, SyncOpStatus status) =>
      (_db.update(_db.syncQueue)..where((q) => q.id.equals(opId)))
          .write(SyncQueueCompanion(status: Value(status.name)));

  SyncOperation _toOperation(SyncQueueRow r) => SyncOperation(
        id: r.id,
        userId: r.userId,
        entityTable: r.entityTable,
        recordId: r.recordId,
        type: SyncOperationType.fromWire(r.operation),
        payload: jsonDecode(r.payload) as Map<String, dynamic>,
        baseVersion: r.baseVersion,
        status: SyncOpStatus.values.byName(r.status),
        attempts: r.attempts,
        createdAt: r.createdAt,
        lastError: r.lastError,
        nextAttemptAt: r.nextAttemptAt,
      );
}

class DriftSyncCursorStore implements SyncCursorStore {
  DriftSyncCursorStore(this._db);
  final AppDatabase _db;

  @override
  Future<String?> read(String table, String scope) async {
    final row = await (_db.select(_db.syncCursors)
          ..where((c) => c.entityTable.equals(table) & c.scope.equals(scope)))
        .getSingleOrNull();
    return row?.lastUpdatedAt;
  }

  @override
  Future<void> reset(String table) =>
      (_db.delete(_db.syncCursors)..where((c) => c.entityTable.equals(table))).go();

  @override
  Future<void> write(String table, String scope, String lastUpdatedAt) =>
      _db.into(_db.syncCursors).insertOnConflictUpdate(SyncCursorsCompanion.insert(
            entityTable: table,
            scope: scope,
            lastUpdatedAt: lastUpdatedAt,
          ));
}
