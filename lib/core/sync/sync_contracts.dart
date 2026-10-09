import '../errors/failure.dart';
import 'sync_models.dart';

/// File d'attente persistante des opérations locales.
abstract interface class SyncQueueStore {
  /// Ajoute une opération en fusionnant avec une opération encore en attente
  /// sur le même enregistrement (au plus une opération en attente par ligne).
  ///
  /// [fusionner] = false : opération envoyée séparément, après la précédente.
  /// Obligatoire quand la modification porte sur des champs que le serveur
  /// n'accepte pas à la création (clôture de caisse, annulation…) : fusionnée
  /// dans la création, elle serait ignorée.
  Future<void> enqueue({
    required String userId,
    required String entityTable,
    required String recordId,
    required SyncOperationType type,
    required Map<String, dynamic> payload,
    int? baseVersion,
    bool fusionner = true,
  });

  /// Opérations prêtes à être envoyées pour cet utilisateur, dans l'ordre.
  Future<List<SyncOperation>> due(String userId, DateTime now);
  Future<void> markSyncing(String opId);
  Future<void> remove(String opId);
  Future<void> markFailed(String opId, String error, DateTime nextAttemptAt);
  Future<void> markRejected(String opId, String error);
  Future<void> markConflict(String opId);

  /// Retire les opérations refusées d'un enregistrement (l'utilisateur
  /// renonce à une écriture que le serveur n'acceptera jamais).
  Future<void> abandonner(String entityTable, String recordId);

  /// Après application, les opérations suivantes sur la même ligne partent
  /// de la nouvelle version serveur.
  Future<void> rebase(String entityTable, String recordId, int newVersion);

  /// Opérations restées « SYNCING » après une interruption (app tuée) :
  /// remises en attente, le serveur garantissant l'idempotence.
  Future<void> recoverInterrupted(String userId);
  Stream<int> watchPendingCount(String userId);
  Future<int> pendingCount(String userId);
  Future<void> log(String level, String message, {String? opId});
}

/// Accès distant générique utilisé par le moteur.
abstract interface class SyncRemoteGateway {
  Future<PushResult> push(SyncOperation op);

  /// Lignes (y compris supprimées logiquement) modifiées après la position
  /// (`afterUpdatedAt`, `afterId`), triées par (`updated_at`, `id`).
  Future<List<Map<String, dynamic>>> pull({
    required String table,
    required String entrepriseId,
    required String? afterUpdatedAt,
    required String? afterId,
    required int limit,
  });
}

/// Adaptateur par entité synchronisée : applique côté local ce que le
/// serveur renvoie. Chaque feature fournit le sien.
abstract interface class SyncEntityHandler {
  String get table;
  Future<void> applyRemoteRows(List<Map<String, dynamic>> rows);
  Future<void> onPushApplied(SyncOperation op, Map<String, dynamic>? serverRow);

  /// Politique V1 : la version serveur gagne, l'enregistrement est marqué en conflit.
  Future<void> onConflict(SyncOperation op, Map<String, dynamic>? serverRow);
  Future<void> onRejected(SyncOperation op, Failure failure);
}

/// Curseurs de synchronisation descendante.
abstract interface class SyncCursorStore {
  Future<String?> read(String table, String scope);
  Future<void> write(String table, String scope, String lastUpdatedAt);

  /// Force une relecture complète de la table au prochain cycle.
  Future<void> reset(String table);
}

/// Exécute plusieurs écritures locales de façon atomique (donnée + file).
typedef LocalTransaction = Future<void> Function(Future<void> Function() action);

/// Demande un cycle de synchronisation (non bloquant).
typedef SyncTrigger = void Function();
