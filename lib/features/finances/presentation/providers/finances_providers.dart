import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/core_providers.dart';
import '../../../../core/di/sync_providers.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../entreprise/domain/entities/espace_courant.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../entreprise/presentation/providers/espace_providers.dart';
import '../../data/datasources/finances_local_data_source.dart';
import '../../data/repositories/finances_repository_impl.dart';
import '../../domain/entities/finances.dart';
import '../../domain/repositories/finances_repository.dart';
import '../../domain/services/caisse_tresorerie_service.dart';
import '../../domain/services/etat_finances.dart';
import '../../domain/usecases/gerer_depenses.dart';
import '../../domain/usecases/gerer_finances.dart';
import '../../domain/usecases/gerer_operations_caisse.dart';

final financesLocalDataSourceProvider = Provider((ref) => FinancesLocalDataSource(ref.watch(appDatabaseProvider)));

final financesSyncHandlersProvider = Provider(
  (ref) => financesSyncHandlers(ref.watch(financesLocalDataSourceProvider), ref.watch(syncCursorStoreProvider)),
);

final financesRepositoryProvider = Provider<FinancesRepository>(
  (ref) => FinancesRepositoryImpl(
    local: ref.watch(financesLocalDataSourceProvider),
    queue: ref.watch(syncQueueStoreProvider),
    currentUserId: () => ref.read(currentUserIdProvider),
    requestSync: ref.watch(syncTriggerProvider),
  ),
);

final observerFinancesProvider = Provider((ref) => ObserverFinances(ref.watch(financesRepositoryProvider)));
final creerEngagementProvider = Provider((ref) => CreerEngagement(ref.watch(financesRepositoryProvider)));
final modifierEngagementProvider = Provider((ref) => ModifierEngagement(ref.watch(financesRepositoryProvider)));
final enregistrerPaiementProvider = Provider((ref) => EnregistrerPaiement(ref.watch(financesRepositoryProvider)));
final annulerPaiementProvider = Provider((ref) => AnnulerPaiement(ref.watch(financesRepositoryProvider)));
final gererCaisseProvider = Provider((ref) => GererCaisse(ref.watch(financesRepositoryProvider)));
final retirerEcritureProvider = Provider((ref) => RetirerEcritureRefusee(ref.watch(financesRepositoryProvider)));
final enregistrerDepenseProvider = Provider((ref) => EnregistrerDepense(ref.watch(financesRepositoryProvider)));
final modifierDepenseProvider = Provider(
  (ref) => ModifierDepense(ref.watch(financesRepositoryProvider), ref.watch(annulerPaiementProvider)),
);
final gererCategoriesProvider = Provider((ref) => GererCategories(ref.watch(financesRepositoryProvider)));
final gererCourantesProvider = Provider(
  (ref) => GererDepensesCourantes(ref.watch(financesRepositoryProvider), ref.watch(enregistrerDepenseProvider)),
);
final caisseTresorerieServiceProvider = Provider((ref) => const CaisseTresorerieService());
final gererOperationsCaisseProvider = Provider(
  (ref) => GererOperationsCaisse(ref.watch(financesRepositoryProvider), ref.watch(enregistrerPaiementProvider)),
);

/// Modes proposés dans les formulaires (paramètres de l'entreprise).
final modesPaiementProvider = Provider.autoDispose<List<ModePaiement>>((ref) {
  final codes = ref.watch(modesPaiementProposesProvider);
  final modes = ModePaiement.values.where((m) => codes.contains(m.code)).toList();
  return modes.isEmpty ? ModePaiement.values : modes;
});

final droitsFinancesProvider = Provider<DroitsFinances>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  return ctx == null ? const DroitsFinances() : DroitsFinances.de(ctx);
});

/// Toutes les données financières locales, recalculées à chaque écriture
/// ou synchronisation (fonctionne hors-ligne).
final etatFinancesProvider = StreamProvider.autoDispose<EtatFinances>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null) return const Stream.empty();
  return ref.watch(observerFinancesProvider).call(ctx);
});

/// Données de l'espace de travail choisi (vue globale, une activité ou un
/// site). Une dimension n'est filtrée que si l'utilisateur avait un vrai
/// choix : avec une seule activité ou un seul site, l'espace est déduit et
/// les écritures de niveau entreprise doivent rester visibles.
final etatFinancesEspaceProvider = Provider.autoDispose<AsyncValue<EtatFinances>>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  final etat = ref.watch(etatFinancesProvider);
  if (ctx == null) return etat;
  final espace = ref.watch(espaceCourantProvider);
  final plusieursActivites = ctx.activites.where((a) => a.estActive).length > 1;
  final plusieursSites = EspaceCourant.sitesPour(ctx, espace.activite).length > 1;
  return etat.whenData(
    (e) => e.restreint(
      activite: plusieursActivites ? espace.activite : null,
      perimetreId: plusieursSites ? espace.perimetreId : null,
      activiteDesSites: {for (final p in ctx.perimetres) p.id: p.activite},
    ),
  );
});

final resumeFinancesProvider = Provider.autoDispose<AsyncValue<ResumeFinances>>(
  (ref) => ref.watch(etatFinancesEspaceProvider).whenData((e) => e.resume(DateTime.now())),
);

/// À recevoir ou à payer, du plus urgent au moins urgent (annulés à la fin).
final engagementsProvider = Provider.autoDispose.family<AsyncValue<List<EngagementSuivi>>, SensEngagement>(
  (ref, sens) => ref.watch(etatFinancesProvider).whenData((etat) {
    final liste = etat.suivis.where((s) => s.engagement.sens == sens).toList()
      ..sort((a, b) {
        int rang(EngagementSuivi s) => s.engagement.annule ? 2 : (s.reste == 0 ? 1 : 0);
        final r = rang(a).compareTo(rang(b));
        if (r != 0) return r;
        final da = a.engagement.echeance ?? DateTime(9999);
        final db = b.engagement.echeance ?? DateTime(9999);
        return da.compareTo(db);
      });
    return liste;
  }),
);
