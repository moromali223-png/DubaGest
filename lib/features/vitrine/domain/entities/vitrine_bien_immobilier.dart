/// Bien immobilier présenté sur une vitrine DubaGest V2 (Modèle Immobilier type Havenly)
class VitrineBienImmobilier {
  const VitrineBienImmobilier({
    required this.id,
    required this.vitrineId,
    required this.entrepriseId,
    required this.titre,
    this.typeBien = 'VILLA',
    this.typeOffre = 'LOCATION', // LOCATION ou VENTE
    required this.prix,
    this.prixBarre,
    this.devise = 'FCFA',
    this.description,
    this.adresse,
    this.ville,
    this.quartier,
    this.photos = const [],
    this.audioUrl,
    this.surfaceM2,
    this.nbChambres,
    this.nbSallesDeBain,
    this.meuble = false,
    this.climatisation = false,
    this.parking = false,
    this.estDisponible = true,
    this.estVedette = false,
    this.ordre = 0,
    this.createdAt,
  });

  final String id;
  final String vitrineId;
  final String entrepriseId;
  final String titre;
  final String typeBien; // VILLA, APPARTEMENT, MAISON, STUDIO, MAGASIN, TERRAIN
  final String typeOffre; // LOCATION ou VENTE
  final int prix;
  final int? prixBarre;
  final String devise;
  final String? description;
  final String? adresse;
  final String? ville;
  final String? quartier;
  final List<String> photos;
  final String? audioUrl;
  final double? surfaceM2;
  final int? nbChambres;
  final int? nbSallesDeBain;
  final bool meuble;
  final bool climatisation;
  final bool parking;
  final bool estDisponible;
  final bool estVedette;
  final int ordre;
  final DateTime? createdAt;

  String get premierePhoto => photos.isNotEmpty ? photos.first : '';

  String get prixFormate {
    final s = prix.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
    if (typeOffre.toUpperCase() == 'LOCATION') {
      return '$s $devise / mois';
    }
    return '$s $devise';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'vitrine_id': vitrineId,
        'entreprise_id': entrepriseId,
        'titre': titre,
        'type_bien': typeBien,
        'type_offre': typeOffre,
        'prix': prix,
        if (prixBarre != null) 'prix_barre': prixBarre,
        'devise': devise,
        if (description != null) 'description': description,
        if (adresse != null) 'adresse': adresse,
        if (ville != null) 'ville': ville,
        if (quartier != null) 'quartier': quartier,
        'photos': photos,
        if (audioUrl != null) 'audio_url': audioUrl,
        if (surfaceM2 != null) 'surface_m2': surfaceM2,
        if (nbChambres != null) 'nb_chambres': nbChambres,
        if (nbSallesDeBain != null) 'nb_salles_de_bain': nbSallesDeBain,
        'meuble': meuble,
        'climatisation': climatisation,
        'parking': parking,
        'est_disponible': estDisponible,
        'est_vedette': estVedette,
        'ordre': ordre,
      };

  factory VitrineBienImmobilier.fromJson(Map<String, dynamic> j) {
    final rawPhotos = j['photos'];
    List<String> listPhotos = [];
    if (rawPhotos is List) {
      listPhotos = rawPhotos.map((e) => e.toString()).toList();
    } else if (j['photo_principale'] != null) {
      listPhotos = [j['photo_principale'].toString()];
    }

    return VitrineBienImmobilier(
      id: j['id']?.toString() ?? '',
      vitrineId: j['vitrine_id']?.toString() ?? '',
      entrepriseId: j['entreprise_id']?.toString() ?? '',
      titre: j['titre']?.toString() ?? j['nom']?.toString() ?? 'Bien immobilier',
      typeBien: j['type_bien']?.toString() ?? j['type']?.toString() ?? 'VILLA',
      typeOffre: j['type_offre']?.toString() ?? 'LOCATION',
      prix: (j['prix'] as num?)?.toInt() ?? (j['loyer_reference'] as num?)?.toInt() ?? 0,
      prixBarre: (j['prix_barre'] as num?)?.toInt(),
      devise: j['devise']?.toString() ?? 'FCFA',
      description: j['description']?.toString(),
      adresse: j['adresse']?.toString(),
      ville: j['ville']?.toString(),
      quartier: j['quartier']?.toString(),
      photos: listPhotos,
      audioUrl: j['audio_url']?.toString(),
      surfaceM2: (j['surface_m2'] as num?)?.toDouble() ??
          ((j['caracteristiques'] as Map?)?['surface_m2'] as num?)?.toDouble(),
      nbChambres: (j['nb_chambres'] as num?)?.toInt() ??
          ((j['caracteristiques'] as Map?)?['nb_chambres'] as num?)?.toInt(),
      nbSallesDeBain: (j['nb_salles_de_bain'] as num?)?.toInt() ??
          ((j['caracteristiques'] as Map?)?['nb_salles_de_bain'] as num?)?.toInt(),
      meuble: j['meuble'] as bool? ??
          ((j['caracteristiques'] as Map?)?['meuble'] as bool?) ??
          false,
      climatisation: j['climatisation'] as bool? ??
          ((j['caracteristiques'] as Map?)?['climatisation'] as bool?) ??
          false,
      parking: j['parking'] as bool? ??
          ((j['caracteristiques'] as Map?)?['parking'] as bool?) ??
          false,
      estDisponible: j['est_disponible'] as bool? ?? true,
      estVedette: j['est_vedette'] as bool? ?? false,
      ordre: (j['ordre'] as num?)?.toInt() ?? 0,
      createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at'].toString()) : null,
    );
  }

  VitrineBienImmobilier copyWith({
    String? titre,
    String? typeBien,
    String? typeOffre,
    int? prix,
    int? prixBarre,
    String? devise,
    String? description,
    String? adresse,
    String? ville,
    String? quartier,
    List<String>? photos,
    String? audioUrl,
    double? surfaceM2,
    int? nbChambres,
    int? nbSallesDeBain,
    bool? meuble,
    bool? climatisation,
    bool? parking,
    bool? estDisponible,
    bool? estVedette,
    int? ordre,
  }) =>
      VitrineBienImmobilier(
        id: id,
        vitrineId: vitrineId,
        entrepriseId: entrepriseId,
        titre: titre ?? this.titre,
        typeBien: typeBien ?? this.typeBien,
        typeOffre: typeOffre ?? this.typeOffre,
        prix: prix ?? this.prix,
        prixBarre: prixBarre ?? this.prixBarre,
        devise: devise ?? this.devise,
        description: description ?? this.description,
        adresse: adresse ?? this.adresse,
        ville: ville ?? this.ville,
        quartier: quartier ?? this.quartier,
        photos: photos ?? this.photos,
        audioUrl: audioUrl ?? this.audioUrl,
        surfaceM2: surfaceM2 ?? this.surfaceM2,
        nbChambres: nbChambres ?? this.nbChambres,
        nbSallesDeBain: nbSallesDeBain ?? this.nbSallesDeBain,
        meuble: meuble ?? this.meuble,
        climatisation: climatisation ?? this.climatisation,
        parking: parking ?? this.parking,
        estDisponible: estDisponible ?? this.estDisponible,
        estVedette: estVedette ?? this.estVedette,
        ordre: ordre ?? this.ordre,
        createdAt: createdAt,
      );
}
