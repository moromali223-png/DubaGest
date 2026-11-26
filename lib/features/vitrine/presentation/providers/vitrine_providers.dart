import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/di/core_providers.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../data/datasources/vitrine_remote_data_source.dart';
import '../../data/repositories/vitrine_repository_impl.dart';
import '../../domain/entities/vitrine_bien_immobilier.dart';
import '../../domain/entities/vitrine_config.dart';
import '../../domain/entities/vitrine_demande_visite.dart';
import '../../domain/entities/vitrine_galerie_item.dart';
import '../../domain/entities/vitrine_membre_equipe.dart';
import '../../domain/entities/vitrine_prestation.dart';
import '../../domain/entities/vitrine_produit_item.dart';
import '../../domain/entities/vitrine_publique_data.dart';
import '../../domain/entities/vitrine_rendez_vous.dart';
import '../../domain/entities/vitrine_types.dart';
import '../../domain/repositories/vitrine_repository.dart';

final vitrineRemoteDataSourceProvider = Provider<VitrineRemoteDataSource>((ref) {
  try {
    return VitrineRemoteDataSource(ref.watch(supabaseClientProvider));
  } catch (_) {
    return VitrineRemoteDataSource(Supabase.instance.client);
  }
});

final vitrineRepositoryProvider = Provider<VitrineRepository>((ref) {
  return VitrineRepositoryImpl(ref.watch(vitrineRemoteDataSourceProvider));
});

/// Vitrine actuelle de l'entreprise connectée
final vitrineActuelleProvider = AsyncNotifierProvider<VitrineActuelleNotifier, VitrineConfig?>(
  VitrineActuelleNotifier.new,
);

class VitrineActuelleNotifier extends AsyncNotifier<VitrineConfig?> {
  @override
  Future<VitrineConfig?> build() async {
    final ctx = ref.watch(contexteActifProvider);
    final entrepriseId = ctx?.entreprise?.id;
    if (entrepriseId == null) return null;

    final repo = ref.watch(vitrineRepositoryProvider);
    var vitrine = await repo.chargerVitrine(entrepriseId);

    // Initialisation automatique par défaut si aucune vitrine n'existe encore
    if (vitrine == null) {
      final ent = ctx!.entreprise;
      final profil = await ref.watch(profilEntrepriseProvider.future);
      final nomEnt = ent?.nom ?? profil?.nom ?? 'Mon Activité';
      final baseSlug = (profil?.slug?.isNotEmpty == true ? profil!.slug! : nomEnt)
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      final slugFinal = baseSlug.isNotEmpty ? baseSlug : 'vitrine-${entrepriseId.substring(0, 6)}';

      // Détection automatique intelligente du Domaine et de l'Activité selon l'entreprise connectée
      final activitesEnt = ctx.activites;
      TypeActivite actDetectee = TypeActivite.commerceGeneral;
      ModeleVitrine modDetecte = ModeleVitrine.modeleA;
      ThemeStyle styleDetecte = ThemeStyle.moderneMinimal;

      final nomLower = nomEnt.toLowerCase();
      final descLower = (profil?.descriptionCommerciale ?? '').toLowerCase();
      final combined = '$nomLower $descLower';

      if (activitesEnt.any((a) => a.activite == ActiviteCode.immobilier)) {
        actDetectee = TypeActivite.agenceImmobiliere;
        modDetecte = ModeleVitrine.modeleF;
        styleDetecte = ThemeStyle.naturelChaud;
      } else if (activitesEnt.any((a) => a.activite == ActiviteCode.services)) {
        if (combined.contains('coiff') || combined.contains('hair') || combined.contains('tresse') || combined.contains('barber') || combined.contains('salon')) {
          actDetectee = TypeActivite.salonCoiffure;
          modDetecte = ModeleVitrine.modeleC;
          styleDetecte = ThemeStyle.luxeOr;
        } else if (combined.contains('beaut') || combined.contains('spa') || combined.contains('esthet') || combined.contains('soin') || combined.contains('ongle')) {
          actDetectee = TypeActivite.beauteEsthetique;
          modDetecte = ModeleVitrine.modeleC;
          styleDetecte = ThemeStyle.elegantBeige;
        } else {
          actDetectee = TypeActivite.prestataireServices;
          modDetecte = ModeleVitrine.modeleE;
          styleDetecte = ThemeStyle.commercialVert;
        }
      } else {
        // Domaine Commerce
        if (combined.contains('tech') || combined.contains('gadget') || combined.contains('phone') || combined.contains('tel') || combined.contains('electro')) {
          actDetectee = TypeActivite.boutiqueTech;
          modDetecte = ModeleVitrine.modeleB;
          styleDetecte = ThemeStyle.sombrePro;
        } else if (combined.contains('cosmet') || combined.contains('creme') || combined.contains('baume') || combined.contains('corps')) {
          actDetectee = TypeActivite.cosmetiqueBeaute;
          modDetecte = ModeleVitrine.modeleD;
          styleDetecte = ThemeStyle.elegantBeige;
        } else if (combined.contains('mode') || combined.contains('vetement') || combined.contains('habit') || combined.contains('chaussur') || combined.contains('wax')) {
          actDetectee = TypeActivite.boutiqueSpecialisee;
          modDetecte = ModeleVitrine.modeleB;
          styleDetecte = ThemeStyle.sombrePro;
        } else {
          actDetectee = TypeActivite.commerceGeneral;
          modDetecte = ModeleVitrine.modeleA;
          styleDetecte = ThemeStyle.moderneMinimal;
        }
      }

      vitrine = VitrineConfig(
        id: '',
        entrepriseId: entrepriseId,
        slug: slugFinal,
        titreHero: nomEnt,
        slogan: 'Bienvenue chez $nomEnt',
        description: profil?.descriptionCommerciale ?? 'Découvrez nos prestations, biens et produits d\'exception.',
        logoUrl: profil?.logoPath,
        banniereUrl: null,
        adresse: profil?.adresse ?? profil?.ville,
        ville: profil?.ville,
        telephone: profil?.telephone,
        whatsapp: profil?.whatsappCommercial ?? profil?.telephone,
        typeActivite: actDetectee,
        modeleVisuel: modDetecte,
        themeStyle: styleDetecte,
        sections: VitrineSections.parDefautPour(actDetectee),
      );

      // Persistance automatique immédiate pour garantir que vitrine.id est généré et que le site public existe
      try {
        vitrine = await repo.sauvegarderVitrine(vitrine);
      } catch (_) {}
    }
    return vitrine;
  }

  Future<void> sauvegarder(VitrineConfig config) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(vitrineRepositoryProvider);
      return await repo.sauvegarderVitrine(config);
    });
  }

  Future<void> changerModele({
    required TypeActivite activite,
    required ModeleVitrine modele,
    required ThemeStyle style,
  }) async {
    final current = state.value;
    if (current == null) return;

    final maj = current.copyWith(
      typeActivite: activite,
      modeleVisuel: modele,
      themeStyle: style,
      couleurPrincipale: '#${style.primaire.toARGB32().toRadixString(16).substring(2)}',
      couleurSecondaire: '#${style.secondaire.toARGB32().toRadixString(16).substring(2)}',
      sections: VitrineSections.parDefautPour(activite),
    );

    await sauvegarder(maj);
  }

  Future<void> basculerPublication(bool estPublie) async {
    final current = state.value;
    if (current == null) return;
    await sauvegarder(current.copyWith(estPublie: estPublie));
  }
}

/// Prestations & Soins de la vitrine
final vitrinePrestationsProvider = FutureProvider<List<VitrinePrestation>>((ref) async {
  final vitrine = await ref.watch(vitrineActuelleProvider.future);
  if (vitrine == null || vitrine.entrepriseId.isEmpty) return const [];
  return ref.watch(vitrineRepositoryProvider).chargerPrestations(vitrine.id, vitrine.entrepriseId);
});

/// Galerie de réalisations (coiffures, avant/après)
final vitrineGalerieProvider = FutureProvider<List<VitrineGalerieItem>>((ref) async {
  final vitrine = await ref.watch(vitrineActuelleProvider.future);
  if (vitrine == null || vitrine.entrepriseId.isEmpty) return const [];
  return ref.watch(vitrineRepositoryProvider).chargerGalerie(vitrine.id, vitrine.entrepriseId);
});

/// Équipe de la vitrine
final vitrineEquipeProvider = FutureProvider<List<VitrineMembreEquipe>>((ref) async {
  final vitrine = await ref.watch(vitrineActuelleProvider.future);
  if (vitrine == null || vitrine.entrepriseId.isEmpty) return const [];
  return ref.watch(vitrineRepositoryProvider).chargerEquipe(vitrine.id, vitrine.entrepriseId);
});

/// Demandes de rendez-vous reçues
final vitrineRendezVousProvider = AsyncNotifierProvider<VitrineRendezVousNotifier, List<VitrineRendezVous>>(
  VitrineRendezVousNotifier.new,
);

class VitrineRendezVousNotifier extends AsyncNotifier<List<VitrineRendezVous>> {
  @override
  Future<List<VitrineRendezVous>> build() async {
    final ctx = ref.watch(contexteActifProvider);
    final entrepriseId = ctx?.entreprise?.id;
    if (entrepriseId == null) return const [];
    return ref.watch(vitrineRepositoryProvider).chargerRendezVous(entrepriseId);
  }

  Future<void> changerStatut(String rdvId, StatutRendezVous statut, {String? reponse}) async {
    final repo = ref.read(vitrineRepositoryProvider);
    await repo.changerStatutRendezVous(rdvId, statut, reponse: reponse);
    ref.invalidateSelf();
  }
}

/// Biens immobiliers de la vitrine
final vitrineBiensProvider = FutureProvider<List<VitrineBienImmobilier>>((ref) async {
  final vitrine = await ref.watch(vitrineActuelleProvider.future);
  if (vitrine == null || vitrine.entrepriseId.isEmpty) return const [];
  return ref.watch(vitrineRepositoryProvider).chargerBiens(vitrine.id, vitrine.entrepriseId);
});

/// Demandes de visite immobilière reçues
final vitrineDemandesVisiteProvider = AsyncNotifierProvider<VitrineDemandesVisiteNotifier, List<VitrineDemandeVisite>>(
  VitrineDemandesVisiteNotifier.new,
);

class VitrineDemandesVisiteNotifier extends AsyncNotifier<List<VitrineDemandeVisite>> {
  @override
  Future<List<VitrineDemandeVisite>> build() async {
    final ctx = ref.watch(contexteActifProvider);
    final entrepriseId = ctx?.entreprise?.id;
    if (entrepriseId == null) return const [];
    return ref.watch(vitrineRepositoryProvider).chargerDemandesVisite(entrepriseId);
  }

  Future<void> changerStatut(String demandeId, StatutDemandeVisite statut) async {
    final repo = ref.read(vitrineRepositoryProvider);
    await repo.changerStatutDemandeVisite(demandeId, statut);
    ref.invalidateSelf();
  }
}

/// Fournisseur pour la page publique de la vitrine
final vitrinePubliqueDataProvider = FutureProvider.family<VitrinePubliqueData, String>((ref, slugOuId) {
  return ref.watch(vitrineRepositoryProvider).chargerVitrinePublique(slugOuId);
});

/// Produits de l'entreprise affichés ou gérés pour la vitrine
final vitrineProduitsAdminProvider = AsyncNotifierProvider<VitrineProduitsAdminNotifier, List<VitrineProduitItem>>(
  VitrineProduitsAdminNotifier.new,
);

class VitrineProduitsAdminNotifier extends AsyncNotifier<List<VitrineProduitItem>> {
  @override
  Future<List<VitrineProduitItem>> build() async {
    final ctx = ref.watch(contexteActifProvider);
    final entrepriseId = ctx?.entreprise?.id;
    if (entrepriseId == null) return const [];
    return ref.watch(vitrineRepositoryProvider).chargerProduitsVitrine(entrepriseId);
  }

  Future<void> sauvegarderProduit(VitrineProduitItem item) async {
    final ctx = ref.read(contexteActifProvider);
    final entrepriseId = ctx?.entreprise?.id;
    if (entrepriseId == null) return;
    await ref.read(vitrineRepositoryProvider).sauvegarderProduitVitrine(item, entrepriseId);
    ref.invalidateSelf();
    ref.invalidate(vitrineActuelleProvider);
  }

  Future<void> basculerPublication(String produitId, bool estPublie) async {
    final ctx = ref.read(contexteActifProvider);
    final entrepriseId = ctx?.entreprise?.id;
    await ref.read(vitrineRepositoryProvider).basculerPublicationProduit(produitId, estPublie, entrepriseId: entrepriseId);
    ref.invalidateSelf();
    ref.invalidate(vitrineActuelleProvider);
  }

  Future<void> supprimerProduit(String produitId) async {
    final ctx = ref.read(contexteActifProvider);
    final entrepriseId = ctx?.entreprise?.id;
    await ref.read(vitrineRepositoryProvider).supprimerProduitVitrine(produitId, entrepriseId: entrepriseId);
    ref.invalidateSelf();
    ref.invalidate(vitrineActuelleProvider);
  }
}

