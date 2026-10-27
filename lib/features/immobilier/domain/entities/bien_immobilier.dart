import 'package:flutter/material.dart';

import '../../../../core/sync/sync_models.dart';

/// Types de biens immobiliers pris en charge.
enum TypeBien {
  appartement('APPARTEMENT', 'Appartement', Icons.apartment_rounded),
  maison('MAISON', 'Maison / Villa', Icons.cottage_rounded),
  chambre('CHAMBRE', 'Chambre / Studio', Icons.bed_rounded),
  magasin('MAGASIN', 'Magasin / Boutique', Icons.storefront_rounded),
  bureau('BUREAU', 'Bureau / Espace pro', Icons.business_center_rounded),
  entrepot('ENTREPOT', 'Entrepôt / Hangar', Icons.warehouse_rounded),
  terrain('TERRAIN', 'Terrain / Parcelle', Icons.landscape_rounded),
  autre('AUTRE', 'Autre bien', Icons.home_work_rounded);

  const TypeBien(this.code, this.libelle, this.icone);
  final String code;
  final String libelle;
  final IconData icone;

  static TypeBien parse(String? code) =>
      values.firstWhere((t) => t.code == code, orElse: () => appartement);
}

/// Statut d'occupation et de disponibilité d'un bien.
enum StatutBien {
  disponible('DISPONIBLE', 'Disponible', Color(0xFF1E7E4E), Icons.check_circle_outline_rounded),
  reserve('RESERVE', 'Réservé', Color(0xFFDF9540), Icons.bookmark_border_rounded),
  occupe('OCCUPE', 'Occupé', Color(0xFF01226C), Icons.key_rounded),
  enTravaux('EN_TRAVAUX', 'En travaux', Color(0xFF7C3AED), Icons.handyman_outlined),
  archive('ARCHIVE', 'Archivé', Color(0xFF64748B), Icons.inventory_2_outlined);

  const StatutBien(this.code, this.libelle, this.couleur, this.icone);
  final String code;
  final String libelle;
  final Color couleur;
  final IconData icone;

  static StatutBien parse(String? code) =>
      values.firstWhere((s) => s.code == code, orElse: () => disponible);

  bool get estDisponible => this == disponible;
  bool get estOccupe => this == occupe;
}

/// Périodicité du paiement du loyer.
enum PeriodiciteLoyer {
  mensuelle('MENSUELLE', 'Mensuel', 1),
  trimestrielle('TRIMESTRIELLE', 'Trimestriel', 3),
  semestrielle('SEMESTRIELLE', 'Semestriel', 6),
  annuelle('ANNUELLE', 'Annuel', 12),
  ponctuelle('PONCTUELLE', 'Ponctuel', 0);

  const PeriodiciteLoyer(this.code, this.libelle, this.nbMois);
  final String code;
  final String libelle;
  final int nbMois;

  static PeriodiciteLoyer parse(String? code) =>
      values.firstWhere((p) => p.code == code, orElse: () => mensuelle);
}

/// Caractéristiques détaillées d'un bien immobilier.
class CaracteristiquesBien {
  const CaracteristiquesBien({
    this.surfaceM2,
    this.nbPieces,
    this.nbChambres,
    this.nbSallesDeBain,
    this.etage,
    this.meuble = false,
    this.climatisation = false,
    this.parking = false,
    this.compteurEauIndependant = true,
    this.compteurElectriciteIndependant = true,
    this.autresDetails = const {},
  });

  final double? surfaceM2;
  final int? nbPieces;
  final int? nbChambres;
  final int? nbSallesDeBain;
  final int? etage;
  final bool meuble;
  final bool climatisation;
  final bool parking;
  final bool compteurEauIndependant;
  final bool compteurElectriciteIndependant;
  final Map<String, dynamic> autresDetails;

  factory CaracteristiquesBien.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CaracteristiquesBien();
    return CaracteristiquesBien(
      surfaceM2: (json['surface_m2'] as num?)?.toDouble(),
      nbPieces: json['nb_pieces'] as int?,
      nbChambres: json['nb_chambres'] as int?,
      nbSallesDeBain: json['nb_salles_de_bain'] as int?,
      etage: json['etage'] as int?,
      meuble: json['meuble'] as bool? ?? false,
      climatisation: json['climatisation'] as bool? ?? false,
      parking: json['parking'] as bool? ?? false,
      compteurEauIndependant: json['compteur_eau'] as bool? ?? true,
      compteurElectriciteIndependant: json['compteur_electricite'] as bool? ?? true,
      autresDetails: (json['autres'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Map<String, dynamic> toJson() => {
        if (surfaceM2 != null) 'surface_m2': surfaceM2,
        if (nbPieces != null) 'nb_pieces': nbPieces,
        if (nbChambres != null) 'nb_chambres': nbChambres,
        if (nbSallesDeBain != null) 'nb_salles_de_bain': nbSallesDeBain,
        if (etage != null) 'etage': etage,
        'meuble': meuble,
        'climatisation': climatisation,
        'parking': parking,
        'compteur_eau': compteurEauIndependant,
        'compteur_electricite': compteurElectriciteIndependant,
        if (autresDetails.isNotEmpty) 'autres': autresDetails,
      };

  CaracteristiquesBien copyWith({
    double? surfaceM2,
    int? nbPieces,
    int? nbChambres,
    int? nbSallesDeBain,
    int? etage,
    bool? meuble,
    bool? climatisation,
    bool? parking,
    bool? compteurEauIndependant,
    bool? compteurElectriciteIndependant,
    Map<String, dynamic>? autresDetails,
  }) {
    return CaracteristiquesBien(
      surfaceM2: surfaceM2 ?? this.surfaceM2,
      nbPieces: nbPieces ?? this.nbPieces,
      nbChambres: nbChambres ?? this.nbChambres,
      nbSallesDeBain: nbSallesDeBain ?? this.nbSallesDeBain,
      etage: etage ?? this.etage,
      meuble: meuble ?? this.meuble,
      climatisation: climatisation ?? this.climatisation,
      parking: parking ?? this.parking,
      compteurEauIndependant: compteurEauIndependant ?? this.compteurEauIndependant,
      compteurElectriciteIndependant:
          compteurElectriciteIndependant ?? this.compteurElectriciteIndependant,
      autresDetails: autresDetails ?? this.autresDetails,
    );
  }
}

/// Entité centrale d'un Bien Immobilier.
class BienImmobilier {
  const BienImmobilier({
    required this.id,
    required this.entrepriseId,
    required this.reference,
    required this.nom,
    required this.type,
    required this.proprietaireId,
    this.statut = StatutBien.disponible,
    this.loyerReference = 0,
    this.periodicite = PeriodiciteLoyer.mensuelle,
    this.depotGarantiePrevu = 0,
    this.description,
    this.adresse,
    this.ville,
    this.quartier,
    this.complementAdresse,
    this.photos = const [],
    this.caracteristiques = const CaracteristiquesBien(),
    this.notes,
    this.creeLe,
    this.misAJourLe,
    this.version,
    this.syncStatus = RecordSyncStatus.synced,
  });

  final String id;
  final String entrepriseId;
  final String reference;
  final String nom;
  final TypeBien type;
  final String proprietaireId;
  final StatutBien statut;
  final int loyerReference;
  final PeriodiciteLoyer periodicite;
  final int depotGarantiePrevu;
  final String? description;
  final String? adresse;
  final String? ville;
  final String? quartier;
  final String? complementAdresse;
  final List<String> photos;
  final CaracteristiquesBien caracteristiques;
  final String? notes;
  final DateTime? creeLe;
  final DateTime? misAJourLe;
  final int? version;
  final RecordSyncStatus syncStatus;

  bool get estDisponible => statut == StatutBien.disponible;
  bool get estOccupe => statut == StatutBien.occupe;
  bool get estArchive => statut == StatutBien.archive;

  String get adresseComplete {
    final parts = [adresse, quartier, ville].where((p) => p != null && p.trim().isNotEmpty);
    return parts.join(', ');
  }

  BienImmobilier copyWith({
    String? reference,
    String? nom,
    TypeBien? type,
    String? proprietaireId,
    StatutBien? statut,
    int? loyerReference,
    PeriodiciteLoyer? periodicite,
    int? depotGarantiePrevu,
    String? description,
    String? adresse,
    String? ville,
    String? quartier,
    String? complementAdresse,
    List<String>? photos,
    CaracteristiquesBien? caracteristiques,
    String? notes,
    DateTime? creeLe,
    DateTime? misAJourLe,
    int? version,
    RecordSyncStatus? syncStatus,
  }) {
    return BienImmobilier(
      id: id,
      entrepriseId: entrepriseId,
      reference: reference ?? this.reference,
      nom: nom ?? this.nom,
      type: type ?? this.type,
      proprietaireId: proprietaireId ?? this.proprietaireId,
      statut: statut ?? this.statut,
      loyerReference: loyerReference ?? this.loyerReference,
      periodicite: periodicite ?? this.periodicite,
      depotGarantiePrevu: depotGarantiePrevu ?? this.depotGarantiePrevu,
      description: description ?? this.description,
      adresse: adresse ?? this.adresse,
      ville: ville ?? this.ville,
      quartier: quartier ?? this.quartier,
      complementAdresse: complementAdresse ?? this.complementAdresse,
      photos: photos ?? this.photos,
      caracteristiques: caracteristiques ?? this.caracteristiques,
      notes: notes ?? this.notes,
      creeLe: creeLe ?? this.creeLe,
      misAJourLe: misAJourLe ?? this.misAJourLe,
      version: version ?? this.version,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
