import '../../../catalogue/domain/entities/catalogue_public_data.dart';
import 'vitrine_config.dart';
import 'vitrine_galerie_item.dart';
import 'vitrine_membre_equipe.dart';
import 'vitrine_prestation.dart';

/// Données complètes publiques pour le rendu de la vitrine (tous modèles confondus)
class VitrinePubliqueData {
  const VitrinePubliqueData({
    required this.vitrine,
    this.prestations = const [],
    this.galerie = const [],
    this.equipe = const [],
    this.produits = const [],
    this.collections = const [],
    this.nouveautes = const [],
  });

  final VitrineConfig vitrine;
  final List<VitrinePrestation> prestations;
  final List<VitrineGalerieItem> galerie;
  final List<VitrineMembreEquipe> equipe;
  final List<ProduitCataloguePublic> produits;
  final List<CollectionPublique> collections;
  final List<NouveautePublique> nouveautes;

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
    final colls = [
      for (final c in (json['collections'] as List?) ?? const [])
        if (c is Map) CollectionPublique.fromJson(c.cast<String, dynamic>()),
    ];
    final nouvs = [
      for (final n in (json['nouveautes'] as List?) ?? const [])
        if (n is Map) NouveautePublique.fromJson(n.cast<String, dynamic>()),
    ];

    return VitrinePubliqueData(
      vitrine: VitrineConfig.fromJson(vJson),
      prestations: prestas,
      galerie: gals,
      equipe: eqs,
      produits: prods,
      collections: colls,
      nouveautes: nouvs,
    );
  }
}
