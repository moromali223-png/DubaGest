import 'package:flutter/material.dart';

/// Type juridique du contrat de bail.
enum TypeBail {
  habitationNue('HABITATION_NUE', 'Habitation nue', Icons.home_outlined),
  habitationMeublee('HABITATION_MEUBLEE', 'Habitation meublée', Icons.chair_outlined),
  commercial('COMMERCIAL', 'Bail commercial', Icons.storefront_outlined),
  professionnel('PROFESSIONNEL', 'Bail professionnel', Icons.business_center_outlined),
  saisonnier('SAISONNIER', 'Bail saisonnier / Vacances', Icons.beach_access_outlined),
  precaire('PRECAIRE', 'Bail précaire / Courte durée', Icons.hourglass_empty_outlined);

  const TypeBail(this.code, this.libelle, this.icone);
  final String code;
  final String libelle;
  final IconData icone;

  static TypeBail parse(String? code) {
    for (final t in values) {
      if (t.code == code) return t;
    }
    return TypeBail.habitationNue;
  }
}

/// Statut dans le cycle de vie du contrat de bail.
enum StatutContratBail {
  brouillon('BROUILLON', 'Brouillon', Color(0xFF64748B), Icons.edit_note_rounded),
  actif('ACTIF', 'Actif / En vigueur', Color(0xFF10B981), Icons.verified_rounded),
  enPreavis('EN_PREAVIS', 'En préavis de congé', Color(0xFFDF9540), Icons.notification_important_rounded),
  termine('TERMINE', 'Arrivé à terme', Color(0xFF3B82F6), Icons.event_available_rounded),
  resilie('RESILIE', 'Résilié', Color(0xFFEF4444), Icons.cancel_outlined);

  const StatutContratBail(this.code, this.libelle, this.couleur, this.icone);
  final String code;
  final String libelle;
  final Color couleur;
  final IconData icone;

  static StatutContratBail parse(String? code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return StatutContratBail.brouillon;
  }
}

/// Modalité d'exigibilité du terme de paiement.
enum TermePaiementType {
  aEchoir('A_ECHOIR', 'Terme à échoir (Paiement en avance / début de période)'),
  echu('ECHU', 'Terme échu (Paiement à terme / fin de période)');

  const TermePaiementType(this.code, this.libelle);
  final String code;
  final String libelle;

  static TermePaiementType parse(String? code) {
    for (final t in values) {
      if (t.code == code) return t;
    }
    return TermePaiementType.aEchoir;
  }
}

/// Contrat de bail liant un propriétaire, un locataire et un bien immobilier.
class ContratBail {
  const ContratBail({
    required this.id,
    required this.entrepriseId,
    required this.reference,
    required this.bienId,
    required this.proprietaireId,
    required this.locataireId,
    this.locationId,
    this.documentId,
    this.typeBail = TypeBail.habitationNue,
    this.statut = StatutContratBail.brouillon,
    required this.dateDebut,
    this.dateFinPrevue,
    this.dateFinReelle,
    this.reconductionTacite = true,
    this.preavisMois = 1,
    required this.loyerMensuel,
    this.chargesMensuelles = 0,
    this.termePaiementJour = 5,
    this.termeType = TermePaiementType.aEchoir,
    this.depotGarantie = 0,
    this.penaliteRetardPourcent,
    this.clausesParticulieres,
    this.dateSignature,
    this.signeParBailleur = false,
    this.signeParLocataire = false,
    this.creeLe,
    this.misAJourLe,
    this.version = 1,
  });

  final String id;
  final String entrepriseId;
  final String reference;
  final String bienId;
  final String proprietaireId;
  final String locataireId;
  final String? locationId;
  final String? documentId;
  final TypeBail typeBail;
  final StatutContratBail statut;
  final DateTime dateDebut;
  final DateTime? dateFinPrevue;
  final DateTime? dateFinReelle;
  final bool reconductionTacite;
  final int preavisMois;
  final int loyerMensuel;
  final int chargesMensuelles;
  final int termePaiementJour;
  final TermePaiementType termeType;
  final int depotGarantie;
  final double? penaliteRetardPourcent;
  final String? clausesParticulieres;
  final DateTime? dateSignature;
  final bool signeParBailleur;
  final bool signeParLocataire;
  final DateTime? creeLe;
  final DateTime? misAJourLe;
  final int version;

  int get totalMensuel => loyerMensuel + chargesMensuelles;

  bool get estBrouillon => statut == StatutContratBail.brouillon;
  bool get estActif => statut == StatutContratBail.actif;
  bool get estEnPreavis => statut == StatutContratBail.enPreavis;
  bool get estCloture => statut == StatutContratBail.termine || statut == StatutContratBail.resilie;
  bool get estEntierementSigne => signeParBailleur && signeParLocataire;

  ContratBail copyWith({
    String? reference,
    String? bienId,
    String? proprietaireId,
    String? locataireId,
    String? locationId,
    String? documentId,
    TypeBail? typeBail,
    StatutContratBail? statut,
    DateTime? dateDebut,
    DateTime? dateFinPrevue,
    DateTime? dateFinReelle,
    bool? reconductionTacite,
    int? preavisMois,
    int? loyerMensuel,
    int? chargesMensuelles,
    int? termePaiementJour,
    TermePaiementType? termeType,
    int? depotGarantie,
    double? penaliteRetardPourcent,
    String? clausesParticulieres,
    DateTime? dateSignature,
    bool? signeParBailleur,
    bool? signeParLocataire,
    DateTime? misAJourLe,
    int? version,
  }) {
    return ContratBail(
      id: id,
      entrepriseId: entrepriseId,
      reference: reference ?? this.reference,
      bienId: bienId ?? this.bienId,
      proprietaireId: proprietaireId ?? this.proprietaireId,
      locataireId: locataireId ?? this.locataireId,
      locationId: locationId ?? this.locationId,
      documentId: documentId ?? this.documentId,
      typeBail: typeBail ?? this.typeBail,
      statut: statut ?? this.statut,
      dateDebut: dateDebut ?? this.dateDebut,
      dateFinPrevue: dateFinPrevue ?? this.dateFinPrevue,
      dateFinReelle: dateFinReelle ?? this.dateFinReelle,
      reconductionTacite: reconductionTacite ?? this.reconductionTacite,
      preavisMois: preavisMois ?? this.preavisMois,
      loyerMensuel: loyerMensuel ?? this.loyerMensuel,
      chargesMensuelles: chargesMensuelles ?? this.chargesMensuelles,
      termePaiementJour: termePaiementJour ?? this.termePaiementJour,
      termeType: termeType ?? this.termeType,
      depotGarantie: depotGarantie ?? this.depotGarantie,
      penaliteRetardPourcent: penaliteRetardPourcent ?? this.penaliteRetardPourcent,
      clausesParticulieres: clausesParticulieres ?? this.clausesParticulieres,
      dateSignature: dateSignature ?? this.dateSignature,
      signeParBailleur: signeParBailleur ?? this.signeParBailleur,
      signeParLocataire: signeParLocataire ?? this.signeParLocataire,
      creeLe: creeLe,
      misAJourLe: misAJourLe ?? DateTime.now(),
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'entreprise_id': entrepriseId,
        'reference': reference,
        'bien_id': bienId,
        'proprietaire_id': proprietaireId,
        'locataire_id': locataireId,
        'location_id': locationId,
        'document_id': documentId,
        'type_bail': typeBail.code,
        'statut': statut.code,
        'date_debut': dateDebut.toIso8601String().split('T').first,
        'date_fin_prevue': dateFinPrevue?.toIso8601String().split('T').first,
        'date_fin_reelle': dateFinReelle?.toIso8601String().split('T').first,
        'reconduction_tacite': reconductionTacite,
        'preavis_mois': preavisMois,
        'loyer_mensuel': loyerMensuel,
        'charges_mensuelles': chargesMensuelles,
        'terme_paiement_jour': termePaiementJour,
        'terme_type': termeType.code,
        'depot_garantie': depotGarantie,
        'penalite_retard_pourcent': penaliteRetardPourcent,
        'clauses_particulieres': clausesParticulieres,
        'date_signature': dateSignature?.toIso8601String().split('T').first,
        'signe_par_bailleur': signeParBailleur,
        'signe_par_locataire': signeParLocataire,
        'created_at': creeLe?.toIso8601String(),
        'updated_at': misAJourLe?.toIso8601String(),
        'version': version,
      };

  factory ContratBail.fromJson(Map<String, dynamic> json) => ContratBail(
        id: json['id'] as String,
        entrepriseId: json['entreprise_id'] as String,
        reference: json['reference'] as String,
        bienId: json['bien_id'] as String,
        proprietaireId: json['proprietaire_id'] as String,
        locataireId: json['locataire_id'] as String,
        locationId: json['location_id'] as String?,
        documentId: json['document_id'] as String?,
        typeBail: TypeBail.parse(json['type_bail'] as String?),
        statut: StatutContratBail.parse(json['statut'] as String?),
        dateDebut: DateTime.parse(json['date_debut'].toString()),
        dateFinPrevue: json['date_fin_prevue'] != null
            ? DateTime.tryParse(json['date_fin_prevue'].toString())
            : null,
        dateFinReelle: json['date_fin_reelle'] != null
            ? DateTime.tryParse(json['date_fin_reelle'].toString())
            : null,
        reconductionTacite: json['reconduction_tacite'] as bool? ?? true,
        preavisMois: (json['preavis_mois'] as num?)?.toInt() ?? 1,
        loyerMensuel: (json['loyer_mensuel'] as num?)?.toInt() ?? 0,
        chargesMensuelles: (json['charges_mensuelles'] as num?)?.toInt() ?? 0,
        termePaiementJour: (json['terme_paiement_jour'] as num?)?.toInt() ?? 5,
        termeType: TermePaiementType.parse(json['terme_type'] as String?),
        depotGarantie: (json['depot_garantie'] as num?)?.toInt() ?? 0,
        penaliteRetardPourcent: (json['penalite_retard_pourcent'] as num?)?.toDouble(),
        clausesParticulieres: json['clauses_particulieres'] as String?,
        dateSignature: json['date_signature'] != null
            ? DateTime.tryParse(json['date_signature'].toString())
            : null,
        signeParBailleur: json['signe_par_bailleur'] as bool? ?? false,
        signeParLocataire: json['signe_par_locataire'] as bool? ?? false,
        creeLe: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
        misAJourLe: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
        version: (json['version'] as num?)?.toInt() ?? 1,
      );
}
