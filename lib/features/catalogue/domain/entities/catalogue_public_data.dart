/// Modèles représentant les données publiques d'une boutique vitrine DubaGest V2.
/// Ne contiennent AUCUNE information confidentielle (ni marge, ni prix d'achat, ni stock chiffré).

class BoutiquePubliqueData {
  const BoutiquePubliqueData({
    required this.entreprise,
    this.collections = const [],
    this.produits = const [],
    this.nouveautes = const [],
  });

  final InfoEntreprisePublique entreprise;
  final List<CollectionPublique> collections;
  final List<ProduitCataloguePublic> produits;
  final List<NouveautePublique> nouveautes;

  factory BoutiquePubliqueData.fromJson(Map<String, dynamic> json) {
    final eJson = (json['entreprise'] as Map?)?.cast<String, dynamic>() ?? {};
    final colls = [
      for (final c in (json['collections'] as List?) ?? const [])
        CollectionPublique.fromJson((c as Map).cast<String, dynamic>()),
    ];
    final prods = [
      for (final p in (json['produits'] as List?) ?? const [])
        ProduitCataloguePublic.fromJson((p as Map).cast<String, dynamic>()),
    ];
    final nouvs = [
      for (final n in (json['nouveautes'] as List?) ?? const [])
        NouveautePublique.fromJson((n as Map).cast<String, dynamic>()),
    ];

    return BoutiquePubliqueData(
      entreprise: InfoEntreprisePublique.fromJson(eJson),
      collections: colls,
      produits: prods,
      nouveautes: nouvs,
    );
  }
}

class InfoEntreprisePublique {
  const InfoEntreprisePublique({
    required this.id,
    required this.nom,
    this.slug,
    this.descriptionCommerciale,
    this.whatsappCommercial,
    this.telephone,
    this.ville,
    this.pays,
    this.logoUrl,
    this.couvertureUrl,
  });

  final String id;
  final String nom;
  final String? slug;
  final String? descriptionCommerciale;
  final String? whatsappCommercial;
  final String? telephone;
  final String? ville;
  final String? pays;
  final String? logoUrl;
  final String? couvertureUrl;

  String get whatsappContact => (whatsappCommercial != null && whatsappCommercial!.trim().isNotEmpty)
      ? whatsappCommercial!.trim()
      : (telephone ?? '').trim();

  factory InfoEntreprisePublique.fromJson(Map<String, dynamic> j) => InfoEntreprisePublique(
        id: j['id'] as String? ?? '',
        nom: j['nom'] as String? ?? 'Boutique DubaGest',
        slug: j['slug'] as String?,
        descriptionCommerciale: j['description_commerciale'] as String?,
        whatsappCommercial: j['whatsapp_commercial'] as String?,
        telephone: j['telephone'] as String?,
        ville: j['ville'] as String?,
        pays: j['pays'] as String?,
        logoUrl: j['logo_url'] as String?,
        couvertureUrl: j['couverture_url'] as String?,
      );
}

class CollectionPublique {
  const CollectionPublique({
    required this.id,
    required this.nom,
    this.description,
    this.photoUrl,
    this.ordre = 100,
  });

  final String id;
  final String nom;
  final String? description;
  final String? photoUrl;
  final int ordre;

  factory CollectionPublique.fromJson(Map<String, dynamic> j) => CollectionPublique(
        id: j['id'] as String? ?? '',
        nom: j['nom'] as String? ?? '',
        description: j['description'] as String?,
        photoUrl: j['photo_url'] as String?,
        ordre: (j['ordre'] as num?)?.toInt() ?? 100,
      );
}

class ProduitCataloguePublic {
  const ProduitCataloguePublic({
    required this.id,
    required this.nom,
    this.description,
    required this.prix,
    this.prixBarre,
    this.photos = const [],
    this.audioPresentationUrl,
    this.videoPresentationUrl,
    this.collectionId,
    this.uniteBase = 'pièce',
    this.disponible = true,
  });

  final String id;
  final String nom;
  final String? description;
  final int prix;
  final int? prixBarre;
  final List<String> photos;
  final String? audioPresentationUrl;
  final String? videoPresentationUrl;
  final String? collectionId;
  final String uniteBase;
  final bool disponible;

  String? get photoPrincipale => photos.isEmpty ? null : photos.first;
  bool get aPromotion => prixBarre != null && prixBarre! > prix;

  factory ProduitCataloguePublic.fromJson(Map<String, dynamic> j) {
    final rawPhotos = j['photos'] ?? j['photos_v2'];
    final photosList = <String>[
      if (rawPhotos is List)
        for (final p in rawPhotos)
          if (p != null) p.toString()
    ];

    final prixVal = (j['prix_public'] as num?)?.toInt() ?? (j['prix_detail'] as num?)?.toInt() ?? 0;

    return ProduitCataloguePublic(
      id: j['id'] as String? ?? '',
      nom: j['nom'] as String? ?? 'Produit',
      description: j['description'] as String?,
      prix: prixVal,
      prixBarre: (j['prix_barre'] as num?)?.toInt(),
      photos: photosList,
      audioPresentationUrl: j['audio_presentation_url'] as String?,
      videoPresentationUrl: j['video_presentation_url'] as String?,
      collectionId: j['collection_id'] as String?,
      uniteBase: j['unite_base'] as String? ?? 'pièce',
      disponible: j['disponible'] as bool? ?? true,
    );
  }
}

class NouveautePublique {
  const NouveautePublique({
    required this.id,
    required this.titre,
    this.message,
    this.mediaUrl,
    this.produitId,
    this.estEphemere = false,
  });

  final String id;
  final String titre;
  final String? message;
  final String? mediaUrl;
  final String? produitId;
  final bool estEphemere;

  factory NouveautePublique.fromJson(Map<String, dynamic> j) => NouveautePublique(
        id: j['id'] as String? ?? '',
        titre: j['titre'] as String? ?? '',
        message: j['message'] as String?,
        mediaUrl: j['media_url'] as String?,
        produitId: j['produit_id'] as String?,
        estEphemere: j['est_ephemere'] as bool? ?? false,
      );
}
