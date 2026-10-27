/// Type d'opération locale à répliquer sur le serveur.
enum SyncOperationType {
  insert('INSERT'),
  update('UPDATE'),
  delete('DELETE');

  const SyncOperationType(this.wire);
  final String wire;

  static SyncOperationType fromWire(String value) =>
      values.firstWhere((v) => v.wire == value);
}

/// Cycle de vie d'une opération dans la file.
/// PENDING → SYNCING → (supprimée si appliquée) | FAILED (réessai) |
/// REJECTED (refus définitif) | CONFLICT (version serveur conservée).
enum SyncOpStatus { pending, syncing, failed, rejected, conflict }

/// Statut de synchronisation d'un enregistrement local.
enum RecordSyncStatus {
  synced('SYNCED'),
  pendingSync('PENDING_SYNC'),
  syncError('SYNC_ERROR'),
  conflict('CONFLICT');

  const RecordSyncStatus(this.wire);
  final String wire;

  static RecordSyncStatus fromWire(String value) =>
      values.firstWhere((v) => v.wire == value, orElse: () => RecordSyncStatus.synced);
}

class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.userId,
    required this.entityTable,
    required this.recordId,
    required this.type,
    required this.payload,
    required this.baseVersion,
    required this.status,
    required this.attempts,
    required this.createdAt,
    this.lastError,
    this.nextAttemptAt,
  });

  final String id;
  final String userId;
  final String entityTable;
  final String recordId;
  final SyncOperationType type;
  final Map<String, dynamic> payload;
  final int? baseVersion;
  final SyncOpStatus status;
  final int attempts;
  final DateTime createdAt;
  final String? lastError;
  final DateTime? nextAttemptAt;

  SyncOperation withBaseVersion(int version) => SyncOperation(
        id: id,
        userId: userId,
        entityTable: entityTable,
        recordId: recordId,
        type: type,
        payload: payload,
        baseVersion: version,
        status: status,
        attempts: attempts,
        createdAt: createdAt,
        lastError: lastError,
        nextAttemptAt: nextAttemptAt,
      );
}

/// Réponse du serveur à une opération poussée (`sync_push`).
enum PushStatus { applied, conflict, notFound, forbidden }

class PushResult {
  const PushResult(this.status, this.row, {this.replayed = false});
  final PushStatus status;

  /// Ligne serveur après application, ou version serveur en cas de conflit.
  final Map<String, dynamic>? row;

  /// L'opération avait déjà été appliquée (rejeu idempotent).
  final bool replayed;
}

enum SyncPhase { idle, offline, syncing, error }

class SyncState {
  const SyncState({
    this.phase = SyncPhase.idle,
    this.pendingCount = 0,
    this.lastSyncedAt,
    this.lastError,
  });

  final SyncPhase phase;
  final int pendingCount;
  final DateTime? lastSyncedAt;
  final String? lastError;

  SyncState copyWith({
    SyncPhase? phase,
    int? pendingCount,
    DateTime? lastSyncedAt,
    String? lastError,
  }) =>
      SyncState(
        phase: phase ?? this.phase,
        pendingCount: pendingCount ?? this.pendingCount,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        lastError: lastError ?? this.lastError,
      );
}
