import '../entities/entree_audit.dart';

abstract interface class AuditRepository {
  /// Entrées les plus récentes de l'entreprise (lecture seule, en ligne).
  /// Peut être filtré par entité.
  Future<List<EntreeAudit>> lister(
    String entrepriseId, {
    int limite = 100,
    int? avantId,
    String? entiteType,
    String? entiteId,
  });
}
