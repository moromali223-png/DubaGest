import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/local_session_guard.dart';
import '../../../../core/di/core_providers.dart';
import '../../../activites/domain/usecases/activer_activite.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/datasources/contexte_local_data_source.dart';
import '../../data/datasources/contexte_remote_data_source.dart';
import '../../data/logo_entreprise.dart';
import '../../data/repositories/contexte_repository_impl.dart';
import '../../data/repositories/entreprise_repository_impl.dart';
import '../../domain/entities/contexte_session.dart';
import '../../domain/entities/offre_plan.dart';
import '../../domain/entities/profil_entreprise.dart';
import '../../domain/usecases/profil_entreprise_usecases.dart';
import '../../domain/repositories/contexte_repository.dart';
import '../../domain/repositories/entreprise_repository.dart';
import '../../domain/usecases/charger_contexte_session.dart';
import '../../domain/usecases/creer_entreprise.dart';

final contexteRepositoryProvider = Provider<ContexteRepository>((ref) => ContexteRepositoryImpl(
      remote: SupabaseContexteRemoteDataSource(ref.watch(supabaseClientProvider)),
      local: DriftContexteLocalDataSource(ref.watch(jsonCacheStoreProvider)),
    ));

final chargerContexteSessionProvider =
    Provider((ref) => ChargerContexteSession(ref.watch(contexteRepositoryProvider)));

final localSessionGuardProvider = Provider(
  (ref) => LocalSessionGuard(ref.watch(sharedPreferencesProvider), ref.watch(appDatabaseProvider)),
);

/// Contexte de l'utilisateur connecté ; `null` si personne n'est connecté.
/// Rechargé automatiquement à chaque changement d'utilisateur.
class ContexteSessionNotifier extends AsyncNotifier<ContexteSession?> {
  @override
  Future<ContexteSession?> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return null;
    await ref.read(localSessionGuardProvider).ensureUser(userId);
    return ref.read(chargerContexteSessionProvider).call(userId);
  }

  /// Recharge depuis le serveur en conservant l'état courant pendant l'appel.
  Future<void> rafraichir() async {
    ref.invalidateSelf();
    await future;
  }
}

final contexteSessionProvider =
    AsyncNotifierProvider<ContexteSessionNotifier, ContexteSession?>(ContexteSessionNotifier.new);

final entrepriseRepositoryProvider =
    Provider<EntrepriseRepository>((ref) => EntrepriseRepositoryImpl(
          ref.watch(supabaseClientProvider),
          cache: ref.watch(jsonCacheStoreProvider),
        ));
final creerEntrepriseProvider = Provider((ref) => CreerEntreprise(ref.watch(entrepriseRepositoryProvider)));
final chargerProfilEntrepriseProvider =
    Provider((ref) => ChargerProfilEntreprise(ref.watch(entrepriseRepositoryProvider)));
final modifierProfilEntrepriseProvider =
    Provider((ref) => ModifierProfilEntreprise(ref.watch(entrepriseRepositoryProvider)));
final modifierParametresEntrepriseProvider =
    Provider((ref) => ModifierParametresEntreprise(ref.watch(entrepriseRepositoryProvider)));
final profilEntrepriseProvider = FutureProvider.autoDispose<ProfilEntreprise?>((ref) async {
  final ctx = ref.watch(contexteActifProvider);
  return ctx == null ? null : ref.watch(chargerProfilEntrepriseProvider).call(ctx);
});

/// Codes des modes de paiement proposés par l'entreprise (profil en cache
/// hors-ligne). Tant que le profil n'est pas lu : tout le catalogue, le
/// serveur restant juge.
final modesPaiementProposesProvider = Provider.autoDispose<List<String>>((ref) =>
    ref.watch(profilEntrepriseProvider).value?.modesPaiement ?? ProfilEntreprise.tousLesModes);
final logoEntrepriseServiceProvider = Provider((ref) => LogoEntreprise(
      client: () => ref.read(supabaseClientProvider),
      cache: ref.watch(jsonCacheStoreProvider),
    ));

/// Logo de l'entreprise : copie de l'appareil, mise à jour quand le réseau
/// permet de lire le profil (documents émis hors-ligne compris).
final logoEntrepriseProvider = FutureProvider.autoDispose<Uint8List?>((ref) async {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null) return null;
  final service = ref.watch(logoEntrepriseServiceProvider);
  final eid = ctx.entreprise!.id;
  try {
    final profil = await ref.watch(profilEntrepriseProvider.future);
    return await service.synchroniser(eid, profil?.logoPath);
  } catch (_) {
    return service.local(eid);
  }
});

final activerActiviteProvider = Provider((ref) => ActiverActivite(ref.watch(entrepriseRepositoryProvider)));
final offresPlanProvider = FutureProvider.autoDispose<List<OffrePlan>>(
  (ref) => ref.watch(creerEntrepriseProvider).offres(),
);

/// Contexte prêt (entreprise active, membre actif), sinon `null`.
final contexteActifProvider = Provider<ContexteSession?>((ref) {
  final ctx = ref.watch(contexteSessionProvider).value;
  return ctx != null && ctx.etat == ContexteEtat.pret ? ctx : null;
});
