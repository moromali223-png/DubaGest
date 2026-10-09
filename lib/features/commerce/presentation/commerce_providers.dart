import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/di/sync_providers.dart';
import '../../../core/permissions/permission_codes.dart';
import '../../activites/domain/entities/activite.dart';
import '../../authentication/presentation/providers/auth_providers.dart';
import '../../entreprise/domain/entities/contexte_session.dart';
import '../../entreprise/presentation/providers/contexte_providers.dart';
import '../../entreprise/presentation/providers/espace_providers.dart';
import '../../modules/domain/entities/app_module.dart';
import '../../perimetres/domain/entities/perimetre.dart';
import '../data/commerce_local_data_source.dart';
import '../data/commerce_repository_impl.dart';
import '../data/photos_produits.dart';
import '../data/postes_vente.dart';
import '../domain/commerce_repository.dart';
import '../domain/services/etat_commerce.dart';
import '../domain/usecases/gerer_commerce.dart';

final commerceLocalDataSourceProvider = Provider((ref) => CommerceLocalDataSource(ref.watch(appDatabaseProvider)));

final commerceSyncHandlersProvider = Provider(
  (ref) => commerceSyncHandlers(ref.watch(commerceLocalDataSourceProvider), ref.watch(syncCursorStoreProvider)),
);

final commerceRepositoryProvider = Provider<CommerceRepository>((ref) => CommerceRepositoryImpl(
      local: ref.watch(commerceLocalDataSourceProvider),
      queue: ref.watch(syncQueueStoreProvider),
      currentUserId: () => ref.read(currentUserIdProvider),
      requestSync: ref.watch(syncTriggerProvider),
    ));

final gererCommerceProvider = Provider((ref) => GererCommerce(ref.watch(commerceRepositoryProvider)));

/// Lettres de poste de l'appareil (numérotation des reçus hors-ligne).
final postesVenteProvider = Provider((ref) => PostesVenteService(ref.watch(commerceLocalDataSourceProvider), () {
      try {
        return ref.read(supabaseClientProvider);
      } catch (_) {
        return null; // tests / démarrage sans serveur
      }
    }));

/// Photos des produits ; les photos en attente partent au retour du réseau.
final photosProduitsProvider = Provider<PhotosProduits>((ref) {
  final photos = PhotosProduits(ref.watch(appDatabaseProvider), () {
    try {
      return ref.read(supabaseClientProvider);
    } catch (_) {
      return null; // tests / démarrage sans serveur
    }
  });
  final abonnement = ref.watch(connectivityServiceProvider).onlineChanges.listen((enLigne) {
    if (enLigne) photos.envoyerEnAttente();
  });
  ref.onDispose(abonnement.cancel);
  return photos;
});

final photoProduitProvider = FutureProvider.family<Uint8List?, String>(
  (ref, chemin) => ref.watch(photosProduitsProvider).octets(chemin),
);

/// Données Commerce de l'entreprise, réactives aux saisies et à la synchronisation.
final etatCommerceProvider = StreamProvider<EtatCommerce>((ref) {
  final eid = ref.watch(contexteActifProvider.select((c) => c?.entreprise?.id));
  if (eid == null) return const Stream.empty();
  return ref.watch(commerceLocalDataSourceProvider).watch(eid);
});

/// Boutiques auxquelles l'utilisateur a accès (le serveur n'envoie que celles-là).
final boutiquesProvider = Provider<List<Perimetre>>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null) return const [];
  return [
    for (final p in ctx.perimetres)
      if (p.estActif && p.activite == ActiviteCode.commerce) p,
  ];
});

/// Boutique choisie (`null` = toutes les boutiques accessibles). Partagée
/// avec l'accueil (site de travail) ; une seule boutique → elle.
final boutiqueCouranteProvider = Provider<String?>((ref) {
  final boutiques = ref.watch(boutiquesProvider);
  if (boutiques.length == 1) return boutiques.single.id;
  final site = ref.watch(espaceCourantProvider).perimetreId;
  return boutiques.any((b) => b.id == site) ? site : null;
});

/// Boutiques prises en compte à l'écran (la courante, ou toutes).
final boutiquesVisiblesProvider = Provider<List<String>>((ref) {
  final courante = ref.watch(boutiqueCouranteProvider);
  return courante == null ? [for (final b in ref.watch(boutiquesProvider)) b.id] : [courante];
});

void choisirBoutique(WidgetRef ref, String? perimetreId) =>
    ref.read(espaceCourantProvider.notifier).choisirSite(perimetreId);

String nomBoutique(WidgetRef ref, String perimetreId) =>
    ref.read(boutiquesProvider).where((b) => b.id == perimetreId).firstOrNull?.nom ??
    ref.read(contexteActifProvider)?.perimetres.where((p) => p.id == perimetreId).firstOrNull?.nom ??
    '—';

/// Ce que l'utilisateur peut faire dans le Commerce (boutons affichés ou non).
/// La sécurité réelle reste celle du serveur.
class DroitsCommerce {
  const DroitsCommerce({
    this.voirProduits = false,
    this.creerProduits = false,
    this.modifierProduits = false,
    this.voirStock = false,
    this.boutiquesEntreeSortie = const [],
    this.boutiquesAjustement = const [],
    this.voirAchats = false,
    this.boutiquesAchat = const [],
    this.boutiquesReception = const [],
    this.voirVentes = false,
    this.boutiquesVente = const [],
    this.annulerVentes = false,
    this.voirFournisseurs = false,
    this.creerContacts = false,
    this.encaisser = false,
  });

  factory DroitsCommerce.de(ContexteSession ctx, List<Perimetre> boutiques) {
    final politique = ctx.accessPolicy();
    bool peut(String module, String permission) =>
        politique.canPerform(moduleCode: module, permission: permission).isAllowed;
    List<String> ou(String module, String permission) => [
          for (final b in boutiques)
            if (politique.canPerform(moduleCode: module, permission: permission, perimetreId: b.id).isAllowed) b.id,
        ];
    return DroitsCommerce(
      voirProduits: peut(ModuleCodes.commerceProduits, PermissionCodes.productsView),
      creerProduits: peut(ModuleCodes.commerceProduits, PermissionCodes.productsCreate),
      modifierProduits: peut(ModuleCodes.commerceProduits, PermissionCodes.productsUpdate),
      voirStock: peut(ModuleCodes.commerceStock, PermissionCodes.stockView),
      boutiquesEntreeSortie: ou(ModuleCodes.commerceStock, PermissionCodes.stockCreate),
      boutiquesAjustement: ou(ModuleCodes.commerceStock, PermissionCodes.stockUpdate),
      voirAchats: peut(ModuleCodes.commerceAchats, PermissionCodes.purchasesView),
      boutiquesAchat: ou(ModuleCodes.commerceAchats, PermissionCodes.purchasesCreate),
      boutiquesReception: ou(ModuleCodes.commerceAchats, PermissionCodes.purchasesUpdate),
      voirVentes: peut(ModuleCodes.commerceVentes, PermissionCodes.salesView),
      boutiquesVente: ou(ModuleCodes.commerceVentes, PermissionCodes.salesCreate),
      annulerVentes: peut(ModuleCodes.commerceVentes, PermissionCodes.salesUpdate),
      voirFournisseurs: peut(ModuleCodes.commerceFournisseurs, PermissionCodes.suppliersView) &&
          peut(ModuleCodes.communContacts, PermissionCodes.contactsView),
      creerContacts: peut(ModuleCodes.communContacts, PermissionCodes.contactsCreate),
      encaisser: peut(ModuleCodes.financesPaiements, PermissionCodes.paymentsCreate),
    );
  }

  final bool voirProduits;
  final bool creerProduits;
  final bool modifierProduits;
  final bool voirStock;
  final List<String> boutiquesEntreeSortie;
  final List<String> boutiquesAjustement;
  final bool voirAchats;
  final List<String> boutiquesAchat;
  final List<String> boutiquesReception;
  final bool voirVentes;
  final List<String> boutiquesVente;
  final bool annulerVentes;
  final bool voirFournisseurs;
  final bool creerContacts;
  final bool encaisser;

  bool get entreeSortie => boutiquesEntreeSortie.isNotEmpty;
  bool get ajuster => boutiquesAjustement.isNotEmpty;

  /// Un transfert demande de gérer le stock d'au moins deux boutiques.
  bool get transferer => boutiquesAjustement.length >= 2;
  bool get creerAchats => boutiquesAchat.isNotEmpty;
  bool get receptionner => boutiquesReception.isNotEmpty;
  bool get vendre => boutiquesVente.isNotEmpty;
}

final droitsCommerceProvider = Provider<DroitsCommerce>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  return ctx == null ? const DroitsCommerce() : DroitsCommerce.de(ctx, ref.watch(boutiquesProvider));
});

/// Dernière unité utilisée par produit et par opération (« carton » pour les
/// achats, « pièce » pour la vente…), proposée par défaut.
class UnitesMemorisees extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};

  void retenir(String operation, String produitId, String uniteId) =>
      state = {...state, '$operation:$produitId': uniteId};

  String? pour(String operation, String produitId) => state['$operation:$produitId'];
}

final unitesMemoriseesProvider = NotifierProvider<UnitesMemorisees, Map<String, String>>(UnitesMemorisees.new);
