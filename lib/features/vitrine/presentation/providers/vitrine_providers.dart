import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/di/core_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../data/datasources/vitrine_remote_data_source.dart';
import '../../data/repositories/vitrine_repository_impl.dart';
import '../../domain/entities/vitrine_config.dart';
import '../../domain/entities/vitrine_galerie_item.dart';
import '../../domain/entities/vitrine_membre_equipe.dart';
import '../../domain/entities/vitrine_prestation.dart';
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

      vitrine = VitrineConfig(
        id: '',
        entrepriseId: entrepriseId,
        slug: slugFinal,
        titreHero: nomEnt,
        slogan: 'Bienvenue chez $nomEnt',
        description: profil?.descriptionCommerciale ?? 'Découvrez nos prestations et produits d\'exception.',
        logoUrl: profil?.logoPath,
        banniereUrl: null,
        adresse: profil?.adresse ?? profil?.ville,
        ville: profil?.ville,
        telephone: profil?.telephone,
        whatsapp: profil?.whatsappCommercial ?? profil?.telephone,
      );
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

/// Fournisseur pour la page publique de la vitrine
final vitrinePubliqueDataProvider = FutureProvider.family<VitrinePubliqueData, String>((ref, slugOuId) {
  return ref.watch(vitrineRepositoryProvider).chargerVitrinePublique(slugOuId);
});
