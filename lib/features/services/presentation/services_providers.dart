import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/core_providers.dart';
import '../../../../core/permissions/permission_codes.dart';
import '../../roles/domain/entities/role.dart';
import '../../entreprise/presentation/providers/contexte_providers.dart';
import '../../entreprise/presentation/providers/espace_providers.dart';
import '../data/datasources/services_local_data_source.dart';
import '../data/datasources/services_remote_data_source.dart';
import '../data/repositories/services_repository_impl.dart';
import '../domain/entities/prestation.dart';
import '../domain/entities/service_catalogue.dart';
import '../domain/repositories/services_repository.dart';
import '../domain/services/moteur_echeances.dart';
import '../domain/usecases/gerer_services.dart';

// --- INFRASTRUCTURE & REPOSITORIES ---

final servicesLocalDataSourceProvider = Provider<ServicesLocalDataSource>((ref) {
  return ServicesLocalDataSource(ref.watch(appDatabaseProvider));
});

final servicesRemoteDataSourceProvider = Provider<ServicesRemoteDataSource>((ref) {
  return ServicesRemoteDataSource(ref.watch(supabaseClientProvider));
});

final servicesRepositoryProvider = Provider<ServicesRepository>((ref) {
  return ServicesRepositoryImpl(
    remote: ref.watch(servicesRemoteDataSourceProvider),
    local: ref.watch(servicesLocalDataSourceProvider),
  );
});

final gererServicesProvider = Provider<GererServices>((ref) {
  return GererServices(ref.watch(servicesRepositoryProvider));
});

final moteurEcheancesProvider = Provider<MoteurEcheances>((ref) {
  return const MoteurEcheances();
});

// --- DROITS D'ACCÈS DU MODULE SERVICES ---

class DroitsServices {
  const DroitsServices({
    required this.peutVoirServices,
    required this.peutCreerServices,
    required this.peutModifierServices,
    required this.peutVoirPrestations,
    required this.peutCreerPrestations,
    required this.peutModifierPrestations,
    required this.peutAnnulerPrestations,
    required this.peutVoirDevis,
    required this.peutCreerDevis,
    required this.peutModifierDevis,
  });

  final bool peutVoirServices;
  final bool peutCreerServices;
  final bool peutModifierServices;
  final bool peutVoirPrestations;
  final bool peutCreerPrestations;
  final bool peutModifierPrestations;
  final bool peutAnnulerPrestations;
  final bool peutVoirDevis;
  final bool peutCreerDevis;
  final bool peutModifierDevis;
}

final droitsServicesProvider = Provider<DroitsServices>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null) {
    return const DroitsServices(
      peutVoirServices: false,
      peutCreerServices: false,
      peutModifierServices: false,
      peutVoirPrestations: false,
      peutCreerPrestations: false,
      peutModifierPrestations: false,
      peutAnnulerPrestations: false,
      peutVoirDevis: false,
      peutCreerDevis: false,
      peutModifierDevis: false,
    );
  }

  final policy = ctx.accessPolicy();
  final isAdmin = ctx.membre?.roleCode == RoleCodes.administrateur ||
      ctx.permissions.contains(PermissionCodes.entrepriseManage);

  bool peut(String moduleCode, String permission) {
    if (isAdmin) return true;
    return policy.canPerform(moduleCode: moduleCode, permission: permission).isAllowed;
  }

  return DroitsServices(
    peutVoirServices: peut('services.services', 'services.view'),
    peutCreerServices: peut('services.services', 'services.create'),
    peutModifierServices: peut('services.services', 'services.update'),
    peutVoirPrestations: peut('services.prestations', 'prestations.view'),
    peutCreerPrestations: peut('services.prestations', 'prestations.create'),
    peutModifierPrestations: peut('services.prestations', 'prestations.update'),
    peutAnnulerPrestations: peut('services.prestations', 'prestations.cancel'),
    peutVoirDevis: peut('services.prestations', 'quotes.view'),
    peutCreerDevis: peut('services.prestations', 'quotes.create'),
    peutModifierDevis: peut('services.prestations', 'quotes.update'),
  );
});

// --- STREAMS DE DONNÉES ---

final servicesCatalogueProvider = StreamProvider<List<ServiceCatalogue>>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  final entrepriseId = ctx?.entreprise?.id;
  if (entrepriseId == null) return Stream.value(const []);
  return ref.watch(servicesRepositoryProvider).observerCatalogue(entrepriseId);
});

final prestationsProvider = StreamProvider<List<Prestation>>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  final espace = ref.watch(espaceCourantProvider);
  final entrepriseId = ctx?.entreprise?.id;
  if (entrepriseId == null) return Stream.value(const []);
  return ref.watch(servicesRepositoryProvider).observerPrestations(
        entrepriseId,
        perimetreId: espace.perimetreId,
      );
});

final prestationDetailProvider = FutureProvider.family<Prestation?, String>((ref, id) {
  return ref.watch(servicesRepositoryProvider).getPrestation(id);
});

final historiquePrestationProvider = StreamProvider.family<List<PrestationHistorique>, String>((ref, id) {
  return ref.watch(servicesRepositoryProvider).observerHistorique(id);
});

final devisServicesProvider = StreamProvider<List<DevisPrestation>>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  final espace = ref.watch(espaceCourantProvider);
  final entrepriseId = ctx?.entreprise?.id;
  if (entrepriseId == null) return Stream.value(const []);
  return ref.watch(servicesRepositoryProvider).observerDevis(
        entrepriseId,
        perimetreId: espace.perimetreId,
      );
});

// --- SYNTHÈSE & PLANNING ---

final syntheseServicesProvider = Provider<SyntheseServices?>((ref) {
  final prestations = ref.watch(prestationsProvider).value;
  final devis = ref.watch(devisServicesProvider).value ?? const [];
  if (prestations == null) return null;

  final moteur = ref.watch(moteurEcheancesProvider);
  return moteur.synthese(prestations: prestations, devis: devis);
});

final alertesServicesProvider = Provider<List<Prestation>>((ref) {
  final prestations = ref.watch(prestationsProvider).value ?? const [];
  final moteur = ref.watch(moteurEcheancesProvider);
  final now = DateTime.now();

  return prestations.where((p) => moteur.estAlerteActive(p, now)).toList()
    ..sort((a, b) {
      final pA = moteur.calculerPriorite(a, now);
      final pB = moteur.calculerPriorite(b, now);
      return pB.index.compareTo(pA.index); // Plus urgent en premier
    });
});

final prestationsContactProvider = Provider.family<List<Prestation>, String>((ref, contactId) {
  final prestations = ref.watch(prestationsProvider).value ?? const [];
  return prestations.where((p) => p.contactId == contactId).toList();
});

final devisContactProvider = Provider.family<List<DevisPrestation>, String>((ref, contactId) {
  final devis = ref.watch(devisServicesProvider).value ?? const [];
  return devis.where((d) => d.contactId == contactId).toList();
});

