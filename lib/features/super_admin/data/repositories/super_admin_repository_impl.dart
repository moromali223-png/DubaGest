import '../../domain/entities/super_admin_entities.dart';
import '../../domain/repositories/super_admin_repository.dart';
import '../datasources/super_admin_remote_data_source.dart';

class SuperAdminRepositoryImpl implements SuperAdminRepository {
  SuperAdminRepositoryImpl(this._remote);

  final SuperAdminRemoteDataSource _remote;

  @override
  Future<bool> estSuperAdmin() => _remote.estSuperAdmin();

  @override
  Future<SuperAdminDashboard> getTableauDeBord() => _remote.getTableauDeBord();

  @override
  Future<List<AdminEntreprise>> listerEntreprises({
    String? recherche,
    String? statut,
    String? plan,
    int limit = 50,
    int offset = 0,
  }) =>
      _remote.listerEntreprises(
        recherche: recherche,
        statut: statut,
        plan: plan,
        limit: limit,
        offset: offset,
      );

  @override
  Future<Map<String, dynamic>> detailEntreprise(String entrepriseId) =>
      _remote.detailEntreprise(entrepriseId);

  @override
  Future<void> suspendreEntreprise(String entrepriseId, String motif) =>
      _remote.suspendreEntreprise(entrepriseId, motif);

  @override
  Future<void> reactiverEntreprise(String entrepriseId, {String? motif}) =>
      _remote.reactiverEntreprise(entrepriseId, motif: motif);

  @override
  Future<void> accorderAccesSponsorise({
    required String entrepriseId,
    required String planCode,
    required String motif,
  }) =>
      _remote.accorderAccesSponsorise(
        entrepriseId: entrepriseId,
        planCode: planCode,
        motif: motif,
      );

  @override
  Future<void> revoquerAccesSponsorise({
    required String entrepriseId,
    required String motif,
  }) =>
      _remote.revoquerAccesSponsorise(
        entrepriseId: entrepriseId,
        motif: motif,
      );

  @override
  Future<List<AdminAuditLog>> listerAuditLogs({int limit = 50, int offset = 0}) =>
      _remote.listerAuditLogs(limit: limit, offset: offset);

  @override
  Future<void> bootstrapSuperAdmin({required String email, required String motif}) =>
      _remote.bootstrapSuperAdmin(email: email, motif: motif);
}
