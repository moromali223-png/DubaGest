import '../entities/super_admin_entities.dart';

abstract class SuperAdminRepository {
  Future<bool> estSuperAdmin();

  Future<SuperAdminDashboard> getTableauDeBord();

  Future<List<AdminEntreprise>> listerEntreprises({
    String? recherche,
    String? statut,
    String? plan,
    int limit = 50,
    int offset = 0,
  });

  Future<Map<String, dynamic>> detailEntreprise(String entrepriseId);

  Future<void> suspendreEntreprise(String entrepriseId, String motif);

  Future<void> reactiverEntreprise(String entrepriseId, {String? motif});

  Future<void> accorderAccesSponsorise({
    required String entrepriseId,
    required String planCode,
    required String motif,
  });

  Future<void> revoquerAccesSponsorise({
    required String entrepriseId,
    required String motif,
  });

  Future<List<AdminAuditLog>> listerAuditLogs({int limit = 50, int offset = 0});

  Future<void> bootstrapSuperAdmin({required String email, required String motif});
}
