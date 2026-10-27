import 'package:flutter/material.dart';

/// Statut d'une location immobilière.
enum StatutLocation {
  enAttente('EN_ATTENTE', 'En attente / Réservée', Color(0xFFDF9540), Icons.schedule_rounded),
  active('ACTIVE', 'Active / En cours', Color(0xFF10B981), Icons.check_circle_rounded),
  terminee('TERMINEE', 'Terminée', Color(0xFF64748B), Icons.event_available_rounded),
  resiliee('RESILIEE', 'Résiliée', Color(0xFFEF4444), Icons.cancel_outlined);

  const StatutLocation(this.code, this.libelle, this.couleur, this.icone);
  final String code;
  final String libelle;
  final Color couleur;
  final IconData icone;

  static StatutLocation parse(String? code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return StatutLocation.active;
  }
}

/// Modèle d'une location immobilière (occupation d'un bien par un locataire).
class LocationImmobilier {
  const LocationImmobilier({
    required this.id,
    required this.entrepriseId,
    required this.bienId,
    required this.locataireId,
    this.contratId,
    required this.dateDebut,
    this.dateFinPrevue,
    this.dateFinReelle,
    required this.loyerMensuel,
    this.chargesMensuelles = 0,
    this.depotGarantie = 0,
    this.statut = StatutLocation.active,
    this.motifCloture,
    this.etatLieuxEntree = false,
    this.etatLieuxSortie = false,
    this.remarques,
    this.creeLe,
    this.misAJourLe,
    this.version = 1,
  });

  final String id;
  final String entrepriseId;
  final String bienId;
  final String locataireId;
  final String? contratId;
  final DateTime dateDebut;
  final DateTime? dateFinPrevue;
  final DateTime? dateFinReelle;
  final int loyerMensuel;
  final int chargesMensuelles;
  final int depotGarantie;
  final StatutLocation statut;
  final String? motifCloture;
  final bool etatLieuxEntree;
  final bool etatLieuxSortie;
  final String? remarques;
  final DateTime? creeLe;
  final DateTime? misAJourLe;
  final int version;

  int get totalMensuel => loyerMensuel + chargesMensuelles;

  bool get estActive => statut == StatutLocation.active;
  bool get estEnAttente => statut == StatutLocation.enAttente;
  bool get estCloturee => statut == StatutLocation.terminee || statut == StatutLocation.resiliee;

  /// Vérifie si cette location chevauche une période donnée.
  bool chevauchePeriode(DateTime debut, DateTime? fin) {
    if (statut == StatutLocation.terminee || statut == StatutLocation.resiliee) {
      return false;
    }
    final finEffective = dateFinReelle ?? dateFinPrevue;

    // Début après notre fin -> pas de chevauchement
    if (finEffective != null && !debut.isBefore(finEffective)) {
      return false;
    }

    // Fin avant notre début -> pas de chevauchement
    if (fin != null && !fin.isAfter(dateDebut)) {
      return false;
    }

    return true;
  }

  LocationImmobilier copyWith({
    String? bienId,
    String? locataireId,
    String? contratId,
    DateTime? dateDebut,
    DateTime? dateFinPrevue,
    DateTime? dateFinReelle,
    int? loyerMensuel,
    int? chargesMensuelles,
    int? depotGarantie,
    StatutLocation? statut,
    String? motifCloture,
    bool? etatLieuxEntree,
    bool? etatLieuxSortie,
    String? remarques,
    DateTime? misAJourLe,
    int? version,
  }) {
    return LocationImmobilier(
      id: id,
      entrepriseId: entrepriseId,
      bienId: bienId ?? this.bienId,
      locataireId: locataireId ?? this.locataireId,
      contratId: contratId ?? this.contratId,
      dateDebut: dateDebut ?? this.dateDebut,
      dateFinPrevue: dateFinPrevue ?? this.dateFinPrevue,
      dateFinReelle: dateFinReelle ?? this.dateFinReelle,
      loyerMensuel: loyerMensuel ?? this.loyerMensuel,
      chargesMensuelles: chargesMensuelles ?? this.chargesMensuelles,
      depotGarantie: depotGarantie ?? this.depotGarantie,
      statut: statut ?? this.statut,
      motifCloture: motifCloture ?? this.motifCloture,
      etatLieuxEntree: etatLieuxEntree ?? this.etatLieuxEntree,
      etatLieuxSortie: etatLieuxSortie ?? this.etatLieuxSortie,
      remarques: remarques ?? this.remarques,
      creeLe: creeLe,
      misAJourLe: misAJourLe ?? DateTime.now(),
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'entreprise_id': entrepriseId,
        'bien_id': bienId,
        'locataire_id': locataireId,
        'contrat_id': contratId,
        'date_debut': dateDebut.toIso8601String().split('T').first,
        'date_fin_prevue': dateFinPrevue?.toIso8601String().split('T').first,
        'date_fin_reelle': dateFinReelle?.toIso8601String().split('T').first,
        'loyer_mensuel': loyerMensuel,
        'charges_mensuelles': chargesMensuelles,
        'depot_garantie': depotGarantie,
        'statut': statut.code,
        'motif_cloture': motifCloture,
        'etat_lieux_entree': etatLieuxEntree,
        'etat_lieux_sortie': etatLieuxSortie,
        'remarques': remarques,
        'created_at': creeLe?.toIso8601String(),
        'updated_at': misAJourLe?.toIso8601String(),
        'version': version,
      };

  factory LocationImmobilier.fromJson(Map<String, dynamic> json) => LocationImmobilier(
        id: json['id'] as String,
        entrepriseId: json['entreprise_id'] as String,
        bienId: json['bien_id'] as String,
        locataireId: json['locataire_id'] as String,
        contratId: json['contrat_id'] as String?,
        dateDebut: DateTime.parse(json['date_debut'].toString()),
        dateFinPrevue: json['date_fin_prevue'] != null
            ? DateTime.tryParse(json['date_fin_prevue'].toString())
            : null,
        dateFinReelle: json['date_fin_reelle'] != null
            ? DateTime.tryParse(json['date_fin_reelle'].toString())
            : null,
        loyerMensuel: (json['loyer_mensuel'] as num?)?.toInt() ?? 0,
        chargesMensuelles: (json['charges_mensuelles'] as num?)?.toInt() ?? 0,
        depotGarantie: (json['depot_garantie'] as num?)?.toInt() ?? 0,
        statut: StatutLocation.parse(json['statut'] as String?),
        motifCloture: json['motif_cloture'] as String?,
        etatLieuxEntree: json['etat_lieux_entree'] as bool? ?? false,
        etatLieuxSortie: json['etat_lieux_sortie'] as bool? ?? false,
        remarques: json['remarques'] as String?,
        creeLe: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
        misAJourLe: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
        version: (json['version'] as num?)?.toInt() ?? 1,
      );
}

/// Statistiques globales de l'occupation du parc.
class ParcOccupationStatistiques {
  const ParcOccupationStatistiques({
    required this.totalBiens,
    required this.nbOccupes,
    required this.nbVacants,
    required this.nbReserves,
    required this.nbEnTravaux,
    required this.tauxOccupation,
    required this.loyerTotalMensuel,
  });

  factory ParcOccupationStatistiques.vide() => const ParcOccupationStatistiques(
        totalBiens: 0,
        nbOccupes: 0,
        nbVacants: 0,
        nbReserves: 0,
        nbEnTravaux: 0,
        tauxOccupation: 0.0,
        loyerTotalMensuel: 0,
      );

  final int totalBiens;
  final int nbOccupes;
  final int nbVacants;
  final int nbReserves;
  final int nbEnTravaux;
  final double tauxOccupation;
  final int loyerTotalMensuel;
}
