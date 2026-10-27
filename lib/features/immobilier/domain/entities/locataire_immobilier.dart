import 'package:flutter/material.dart';

/// Types de pièces d'identité acceptées pour le dossier locataire.
enum TypePieceIdentite {
  cni('CNI', 'Carte Nationale d\'Identité (CNI)'),
  passeport('PASSEPORT', 'Passeport'),
  permis('PERMIS', 'Permis de conduire'),
  carteSejour('CARTE_SEJOUR', 'Carte de séjour / Résident'),
  rccm('RCCM', 'Registre du Commerce (RCCM)'),
  nif('NIF', 'Numéro Fiscal (NIF)'),
  autre('AUTRE', 'Autre pièce officielle');

  const TypePieceIdentite(this.code, this.libelle);
  final String code;
  final String libelle;

  static TypePieceIdentite parse(String? code) {
    for (final t in values) {
      if (t.code == code) return t;
    }
    return TypePieceIdentite.cni;
  }
}

/// Statut financier du locataire dans la gestion locative.
enum StatutFinancierLocataire {
  aJour('A_JOUR', 'À jour', Color(0xFF10B981), Icons.check_circle_rounded),
  enRetard('EN_RETARD', 'En retard', Color(0xFFF59E0B), Icons.warning_amber_rounded),
  contentieux('CONTENTIEUX', 'Contentieux', Color(0xFFEF4444), Icons.gavel_rounded);

  const StatutFinancierLocataire(this.code, this.libelle, this.couleur, this.icone);
  final String code;
  final String libelle;
  final Color couleur;
  final IconData icone;

  static StatutFinancierLocataire parse(String? code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return StatutFinancierLocataire.aJour;
  }
}

/// Situation financière consolidée d'un locataire (calculée en temps réel).
class SituationFinanciereLocataire {
  const SituationFinanciereLocataire({
    required this.totalAppeles,
    required this.totalRegle,
    required this.soldeDu,
    required this.impayes,
    required this.statut,
  });

  factory SituationFinanciereLocataire.vide() => const SituationFinanciereLocataire(
        totalAppeles: 0,
        totalRegle: 0,
        soldeDu: 0,
        impayes: 0,
        statut: StatutFinancierLocataire.aJour,
      );

  final int totalAppeles;
  final int totalRegle;
  final int soldeDu;
  final int impayes;
  final StatutFinancierLocataire statut;

  bool get estAJour => soldeDu <= 0;
  bool get aDesImpayes => impayes > 0;
}

/// Dossier locatif et informations complémentaires d'un locataire.
/// Lié à la fiche Contact principale via `contactId`.
class ProfilLocataire {
  const ProfilLocataire({
    required this.contactId,
    required this.entrepriseId,
    this.typePiece = TypePieceIdentite.cni,
    this.numeroPiece,
    this.dateDelivrancePiece,
    this.profession,
    this.employeur,
    this.revenuMensuelEstime,
    this.nomGarant,
    this.telephoneGarant,
    this.lienGarant,
    this.adresseGarant,
    this.nomUrgence,
    this.telephoneUrgence,
    this.lienUrgence,
    this.notesLocatives,
    this.statutFinancier = StatutFinancierLocataire.aJour,
    this.updatedAt,
  });

  final String contactId;
  final String entrepriseId;
  final TypePieceIdentite typePiece;
  final String? numeroPiece;
  final DateTime? dateDelivrancePiece;
  final String? profession;
  final String? employeur;
  final double? revenuMensuelEstime;

  // Cautionnaire / Garant
  final String? nomGarant;
  final String? telephoneGarant;
  final String? lienGarant;
  final String? adresseGarant;

  // Contact d'urgence
  final String? nomUrgence;
  final String? telephoneUrgence;
  final String? lienUrgence;

  // Notes
  final String? notesLocatives;
  final StatutFinancierLocataire statutFinancier;
  final DateTime? updatedAt;

  bool get aGarant =>
      (nomGarant?.trim().isNotEmpty ?? false) || (telephoneGarant?.trim().isNotEmpty ?? false);

  bool get aContactUrgence =>
      (nomUrgence?.trim().isNotEmpty ?? false) || (telephoneUrgence?.trim().isNotEmpty ?? false);

  bool get aPieceIdentite => numeroPiece?.trim().isNotEmpty ?? false;

  ProfilLocataire copyWith({
    TypePieceIdentite? typePiece,
    String? numeroPiece,
    DateTime? dateDelivrancePiece,
    String? profession,
    String? employeur,
    double? revenuMensuelEstime,
    String? nomGarant,
    String? telephoneGarant,
    String? lienGarant,
    String? adresseGarant,
    String? nomUrgence,
    String? telephoneUrgence,
    String? lienUrgence,
    String? notesLocatives,
    StatutFinancierLocataire? statutFinancier,
    DateTime? updatedAt,
  }) {
    return ProfilLocataire(
      contactId: contactId,
      entrepriseId: entrepriseId,
      typePiece: typePiece ?? this.typePiece,
      numeroPiece: numeroPiece ?? this.numeroPiece,
      dateDelivrancePiece: dateDelivrancePiece ?? this.dateDelivrancePiece,
      profession: profession ?? this.profession,
      employeur: employeur ?? this.employeur,
      revenuMensuelEstime: revenuMensuelEstime ?? this.revenuMensuelEstime,
      nomGarant: nomGarant ?? this.nomGarant,
      telephoneGarant: telephoneGarant ?? this.telephoneGarant,
      lienGarant: lienGarant ?? this.lienGarant,
      adresseGarant: adresseGarant ?? this.adresseGarant,
      nomUrgence: nomUrgence ?? this.nomUrgence,
      telephoneUrgence: telephoneUrgence ?? this.telephoneUrgence,
      lienUrgence: lienUrgence ?? this.lienUrgence,
      notesLocatives: notesLocatives ?? this.notesLocatives,
      statutFinancier: statutFinancier ?? this.statutFinancier,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'contact_id': contactId,
        'entreprise_id': entrepriseId,
        'type_piece': typePiece.code,
        'numero_piece': numeroPiece,
        'date_delivrance_piece': dateDelivrancePiece?.toIso8601String().split('T').first,
        'profession': profession,
        'employeur': employeur,
        'revenu_mensuel_estime': revenuMensuelEstime,
        'nom_garant': nomGarant,
        'telephone_garant': telephoneGarant,
        'lien_garant': lienGarant,
        'adresse_garant': adresseGarant,
        'nom_urgence': nomUrgence,
        'telephone_urgence': telephoneUrgence,
        'lien_urgence': lienUrgence,
        'notes_locatives': notesLocatives,
        'statut_financier': statutFinancier.code,
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory ProfilLocataire.fromJson(Map<String, dynamic> json) => ProfilLocataire(
        contactId: json['contact_id'] as String,
        entrepriseId: json['entreprise_id'] as String,
        typePiece: TypePieceIdentite.parse(json['type_piece'] as String?),
        numeroPiece: json['numero_piece'] as String?,
        dateDelivrancePiece: json['date_delivrance_piece'] != null
            ? DateTime.tryParse(json['date_delivrance_piece'].toString())
            : null,
        profession: json['profession'] as String?,
        employeur: json['employeur'] as String?,
        revenuMensuelEstime: (json['revenu_mensuel_estime'] as num?)?.toDouble(),
        nomGarant: json['nom_garant'] as String?,
        telephoneGarant: json['telephone_garant'] as String?,
        lienGarant: json['lien_garant'] as String?,
        adresseGarant: json['adresse_garant'] as String?,
        nomUrgence: json['nom_urgence'] as String?,
        telephoneUrgence: json['telephone_urgence'] as String?,
        lienUrgence: json['lien_urgence'] as String?,
        notesLocatives: json['notes_locatives'] as String?,
        statutFinancier: StatutFinancierLocataire.parse(json['statut_financier'] as String?),
        updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
      );
}
