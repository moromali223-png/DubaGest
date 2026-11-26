import '../../../catalogue/domain/entities/catalogue_public_data.dart';
import 'vitrine_bien_immobilier.dart';
import 'vitrine_config.dart';
import 'vitrine_galerie_item.dart';
import 'vitrine_membre_equipe.dart';
import 'vitrine_prestation.dart';

/// Données complètes publiques pour le rendu de la vitrine (tous modèles confondus : Commerce, Services, Immobilier)
class VitrinePubliqueData {
  const VitrinePubliqueData({
    required this.vitrine,
    this.prestations = const [],
    this.galerie = const [],
    this.equipe = const [],
    this.produits = const [],
    this.collections = const [],
    this.nouveautes = const [],
    this.biens = const [],
  });

  final VitrineConfig vitrine;
  final List<VitrinePrestation> prestations;
  final List<VitrineGalerieItem> galerie;
  final List<VitrineMembreEquipe> equipe;
  final List<ProduitCataloguePublic> produits;
  final List<CollectionPublique> collections;
  final List<NouveautePublique> nouveautes;
  final List<VitrineBienImmobilier> biens;

  factory VitrinePubliqueData.fromJson(Map<String, dynamic> json) {
    final vJson = (json['vitrine'] as Map?)?.cast<String, dynamic>() ?? {};
    final prestas = [
      for (final p in (json['prestations'] as List?) ?? const [])
        if (p is Map) VitrinePrestation.fromJson(p.cast<String, dynamic>()),
    ];
    final gals = [
      for (final g in (json['galerie'] as List?) ?? const [])
        if (g is Map) VitrineGalerieItem.fromJson(g.cast<String, dynamic>()),
    ];
    final eqs = [
      for (final e in (json['equipe'] as List?) ?? const [])
        if (e is Map) VitrineMembreEquipe.fromJson(e.cast<String, dynamic>()),
    ];
    final prods = [
      for (final pr in (json['produits'] as List?) ?? const [])
        if (pr is Map) ProduitCataloguePublic.fromJson(pr.cast<String, dynamic>()),
    ];

    // Intégrer les produits ajoutés spécifiquement dans la vitrine si non présents
    final prodsVitrine = (vJson['reseaux_sociaux'] as Map?)?['produits_vitrine'];
    if (prodsVitrine is List) {
      for (final pv in prodsVitrine) {
        if (pv is Map) {
          final estPublie = (pv['est_publie_catalogue'] as bool?) ?? (pv['est_publie'] as bool?) ?? true;
          final id = pv['id'] as String? ?? '';
          if (estPublie && !prods.any((p) => p.id == id)) {
            prods.add(ProduitCataloguePublic.fromJson(pv.cast<String, dynamic>()));
          }
        }
      }
    }
    final colls = [
      for (final c in (json['collections'] as List?) ?? const [])
        if (c is Map) CollectionPublique.fromJson(c.cast<String, dynamic>()),
    ];
    final nouvs = [
      for (final n in (json['nouveautes'] as List?) ?? const [])
        if (n is Map) NouveautePublique.fromJson(n.cast<String, dynamic>()),
    ];
    final bns = [
      for (final b in (json['biens'] as List?) ?? const [])
        if (b is Map) VitrineBienImmobilier.fromJson(b.cast<String, dynamic>()),
    ];

    return VitrinePubliqueData(
      vitrine: VitrineConfig.fromJson(vJson),
      prestations: prestas,
      galerie: gals,
      equipe: eqs,
      produits: prods,
      collections: colls,
      nouveautes: nouvs,
      biens: bns,
    );
  }
}
