import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/core_providers.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/datasources/super_admin_remote_data_source.dart';
import '../../data/repositories/super_admin_repository_impl.dart';
import '../../domain/entities/super_admin_entities.dart';
import '../../domain/repositories/super_admin_repository.dart';

final superAdminRepositoryProvider = Provider<SuperAdminRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SuperAdminRepositoryImpl(SuperAdminRemoteDataSource(client));
});

/// Vérifie de façon sécurisée côté serveur si l'utilisateur courant est un Super Admin DubaGest.
final estSuperAdminProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.estSuperAdmin();
});

/// Tableau de bord central Super Admin (KPIs globaux).
final superAdminDashboardProvider = FutureProvider<SuperAdminDashboard>((ref) async {
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.getTableauDeBord();
});

class EntreprisesFiltreParams {
  const EntreprisesFiltreParams({
    this.recherche,
    this.statut,
    this.plan,
  });

  final String? recherche;
  final String? statut;
  final String? plan;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntreprisesFiltreParams &&
          runtimeType == other.runtimeType &&
          recherche == other.recherche &&
          statut == other.statut &&
          plan == other.plan;

  @override
  int get hashCode => Object.hash(recherche, statut, plan);
}

class SuperAdminEntreprisesFiltreNotifier extends Notifier<EntreprisesFiltreParams> {
  @override
  EntreprisesFiltreParams build() => const EntreprisesFiltreParams();

  @override
  set state(EntreprisesFiltreParams value) => super.state = value;
}

final superAdminEntreprisesFiltreProvider =
    NotifierProvider<SuperAdminEntreprisesFiltreNotifier, EntreprisesFiltreParams>(
  SuperAdminEntreprisesFiltreNotifier.new,
);

final superAdminEntreprisesProvider = FutureProvider<List<AdminEntreprise>>((ref) async {
  final filtre = ref.watch(superAdminEntreprisesFiltreProvider);
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.listerEntreprises(
    recherche: filtre.recherche,
    statut: filtre.statut,
    plan: filtre.plan,
  );
});

final superAdminDetailEntrepriseProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.detailEntreprise(id);
});

final superAdminAuditLogsProvider = FutureProvider<List<AdminAuditLog>>((ref) async {
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.listerAuditLogs();
});
