import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/core_providers.dart';
import '../../core/di/sync_providers.dart';
import '../../core/utils/app_logger.dart';
import '../../features/agenda/presentation/providers/agenda_providers.dart';
import '../../features/documents/presentation/providers/documents_providers.dart';
import '../../features/fichiers/presentation/fichiers_providers.dart';
import '../../core/sync/sync_engine.dart';
import '../../features/commerce/presentation/commerce_providers.dart';
import '../../features/contacts/presentation/providers/contacts_providers.dart';
import '../../features/entreprise/presentation/providers/contexte_providers.dart';
import '../../features/finances/presentation/providers/finances_providers.dart';
import '../../features/perimetres/presentation/providers/perimetres_providers.dart';

/// Racine de composition : branche les features sur les services du cœur.
/// Ajouter une entité synchronisée = ajouter son handler ici.
final appOverrides = [
  syncHandlersProvider.overrideWith((ref) => [
        ref.watch(perimetresSyncHandlerProvider),
        ref.watch(contactsSyncHandlerProvider),
        ...ref.watch(financesSyncHandlersProvider),
        ref.watch(documentsSyncHandlerProvider),
        ...ref.watch(agendaSyncHandlersProvider),
        ...ref.watch(fichiersSyncHandlersProvider),
        ...ref.watch(commerceSyncHandlersProvider),
      ]),
];

/// Réserve de numéros de documents : complétée en tâche de fond quand le
/// réseau est là, pour pouvoir émettre des reçus hors-ligne ensuite.
final reserveNumerosProvider = Provider<void>((ref) {
  Future<void> completer() async {
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null || ctx.depuisCache) return;
    try {
      await ref.read(assurerNumerosProvider).call(ctx, appareilId: ref.read(appareilIdProvider));
    } catch (e) {
      // Hors-ligne ou refus : nouvel essai au prochain retour du réseau.
      AppLogger.info('Réserve de numéros non complétée : $e', tag: 'documents');
    }
    // Reçus de vente : lettre de cet appareil dans chaque boutique où l'on vend.
    try {
      final boutiques = DroitsCommerce.de(ctx, ref.read(boutiquesProvider)).boutiquesVente;
      if (boutiques.isNotEmpty) {
        await ref.read(postesVenteProvider).assurer(
              entrepriseId: ctx.entreprise!.id,
              boutiques: boutiques,
              appareilId: ref.read(appareilIdProvider),
            );
      }
    } catch (e) {
      AppLogger.info('Postes de vente non attribués : $e', tag: 'commerce');
    }
  }

  ref.listen(contexteActifProvider, (_, _) => completer(), fireImmediately: true);
  final abonnement = ref.watch(connectivityServiceProvider).onlineChanges.listen((enLigne) {
    if (enLigne) completer();
  });
  ref.onDispose(abonnement.cancel);
});

/// La synchronisation suit la session : démarre quand un contexte valide est
/// chargé, s'arrête à la déconnexion ou au changement d'entreprise.
final sessionSyncCoordinatorProvider = Provider<void>((ref) {
  final engine = ref.watch(syncEngineProvider);
  ref.listen(contexteActifProvider, (_, ctx) {
    engine.setScope(ctx == null
        ? null
        : SyncScope(userId: ctx.userId, entrepriseId: ctx.entreprise!.id));
  }, fireImmediately: true);
});

/// Photos de produits prises hors-ligne : envoyées au retour du réseau.
final photosEnAttenteProvider = Provider<void>((ref) {
  final photos = ref.watch(photosProduitsProvider);
  ref.listen(contexteActifProvider, (_, ctx) {
    if (ctx != null && !ctx.depuisCache) photos.envoyerEnAttente();
  }, fireImmediately: true);
});
