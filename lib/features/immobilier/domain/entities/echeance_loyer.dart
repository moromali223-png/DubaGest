import 'package:flutter/material.dart';

/// Statut de règlement d'une échéance de loyer.
enum StatutEcheanceLoyer {
  aPayer('A_PAYER', 'À payer', Color(0xFF64748B), Icons.schedule_rounded),
  partiellementPaye('PARTIEL', 'Paiement partiel', Color(0xFFDF9540), Icons.hourglass_bottom_rounded),
  solde('SOLDE', 'Soldé / Payé', Color(0xFF10B981), Icons.check_circle_rounded),
  enRetard('EN_RETARD', 'En retard d\'impayé', Color(0xFFEF4444), Icons.warning_amber_rounded),
  annule('ANNULE', 'Annulé', Color(0xFF94A3B8), Icons.cancel_outlined);

  const StatutEcheanceLoyer(this.code, this.libelle, this.couleur, this.icone);
  final String code;
  final String libelle;
  final Color couleur;
  final IconData icone;

  static StatutEcheanceLoyer parse(String? code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return StatutEcheanceLoyer.aPayer;
  }
}

/// Échéance mensuelle de loyer issue d'un contrat de bail actif.
/// Reliée à un engagement financier commun pour l'imputation comptable.
class EcheanceLoyer {
  const EcheanceLoyer({
    required this.id,
    required this.entrepriseId,
    required this.reference,
    required this.contratId,
    required this.bienId,
    required this.locataireId,
    this.proprietaireId,
    required this.engagementId,
    required this.periodeMois,
    required this.periodeAnnee,
    required this.dateEmission,
    required this.dateExigibilite,
    required this.loyerNet,
    this.charges = 0,
    required this.totalDu,
    this.montantRegle = 0,
    this.statut = StatutEcheanceLoyer.aPayer,
    this.quittanceDocumentId,
    this.recuDocumentIds = const [],
    this.derniereDatePaiement,
    this.remarques,
    this.creeLe,
    this.misAJourLe,
    this.version = 1,
  });

  final String id;
  final String entrepriseId;
  final String reference;
  final String contratId;
  final String bienId;
  final String locataireId;
  final String? proprietaireId;
  final String engagementId;
  final int periodeMois;
  final int periodeAnnee;
  final DateTime dateEmission;
  final DateTime dateExigibilite;
  final int loyerNet;
  final int charges;
  final int totalDu;
  final int montantRegle;
  final StatutEcheanceLoyer statut;
  final String? quittanceDocumentId;
  final List<String> recuDocumentIds;
  final DateTime? derniereDatePaiement;
  final String? remarques;
  final DateTime? creeLe;
  final DateTime? misAJourLe;
  final int version;

  /// Montant restant à percevoir.
  int get resteAPayer => statut == StatutEcheanceLoyer.annule
      ? 0
      : (totalDu - montantRegle).clamp(0, totalDu);

  /// Indique si l'échéance est intégralement réglée.
  bool get estSolde => resteAPayer == 0;

  /// Indique si l'échéance accuse un retard par rapport à sa date limite.
  bool estEnRetardCalcule(DateTime maintenant) {
    if (estSolde || statut == StatutEcheanceLoyer.annule) return false;
    final jourMaintenant = DateTime(maintenant.year, maintenant.month, maintenant.day);
    final jourExigibilite = DateTime(dateExigibilite.year, dateExigibilite.month, dateExigibilite.day);
    return jourMaintenant.isAfter(jourExigibilite);
  }

  /// Taux de règlement en pourcentage (0.0 à 100.0).
  double get pourcentageRegle => totalDu > 0 ? ((montantRegle / totalDu) * 100).clamp(0.0, 100.0) : 100.0;

  /// Nom du mois en français.
  String get periodeLibelle {
    const moisNoms = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    final mIndex = (periodeMois >= 1 && periodeMois <= 12) ? periodeMois - 1 : 0;
    return '${moisNoms[mIndex]} $periodeAnnee';
  }

  EcheanceLoyer copyWith({
    String? reference,
    int? loyerNet,
    int? charges,
    int? totalDu,
    int? montantRegle,
    StatutEcheanceLoyer? statut,
    String? quittanceDocumentId,
    List<String>? recuDocumentIds,
    DateTime? derniereDatePaiement,
    String? remarques,
    DateTime? misAJourLe,
    int? version,
  }) {
    return EcheanceLoyer(
      id: id,
      entrepriseId: entrepriseId,
      reference: reference ?? this.reference,
      contratId: contratId,
      bienId: bienId,
      locataireId: locataireId,
      proprietaireId: proprietaireId,
      engagementId: engagementId,
      periodeMois: periodeMois,
      periodeAnnee: periodeAnnee,
      dateEmission: dateEmission,
      dateExigibilite: dateExigibilite,
      loyerNet: loyerNet ?? this.loyerNet,
      charges: charges ?? this.charges,
      totalDu: totalDu ?? this.totalDu,
      montantRegle: montantRegle ?? this.montantRegle,
      statut: statut ?? this.statut,
      quittanceDocumentId: quittanceDocumentId ?? this.quittanceDocumentId,
      recuDocumentIds: recuDocumentIds ?? this.recuDocumentIds,
      derniereDatePaiement: derniereDatePaiement ?? this.derniereDatePaiement,
      remarques: remarques ?? this.remarques,
      creeLe: creeLe,
      misAJourLe: misAJourLe ?? DateTime.now(),
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'entreprise_id': entrepriseId,
        'reference': reference,
        'contrat_id': contratId,
        'bien_id': bienId,
        'locataire_id': locataireId,
        'proprietaire_id': proprietaireId,
        'engagement_id': engagementId,
        'periode_mois': periodeMois,
        'periode_annee': periodeAnnee,
        'date_emission': dateEmission.toIso8601String().split('T').first,
        'date_exigibilite': dateExigibilite.toIso8601String().split('T').first,
        'loyer_net': loyerNet,
        'charges': charges,
        'total_du': totalDu,
        'montant_regle': montantRegle,
        'statut': statut.code,
        'quittance_document_id': quittanceDocumentId,
        'recu_document_ids': recuDocumentIds,
        'derniere_date_paiement': derniereDatePaiement?.toIso8601String(),
        'remarques': remarques,
        'created_at': creeLe?.toIso8601String(),
        'updated_at': misAJourLe?.toIso8601String(),
        'version': version,
      };

  factory EcheanceLoyer.fromJson(Map<String, dynamic> json) => EcheanceLoyer(
        id: json['id'] as String,
        entrepriseId: json['entreprise_id'] as String,
        reference: json['reference'] as String,
        contratId: json['contrat_id'] as String,
        bienId: json['bien_id'] as String,
        locataireId: json['locataire_id'] as String,
        proprietaireId: json['proprietaire_id'] as String?,
        engagementId: json['engagement_id'] as String,
        periodeMois: (json['periode_mois'] as num).toInt(),
        periodeAnnee: (json['periode_annee'] as num).toInt(),
        dateEmission: DateTime.parse(json['date_emission'].toString()),
        dateExigibilite: DateTime.parse(json['date_exigibilite'].toString()),
        loyerNet: (json['loyer_net'] as num).toInt(),
        charges: (json['charges'] as num?)?.toInt() ?? 0,
        totalDu: (json['total_du'] as num).toInt(),
        montantRegle: (json['montant_regle'] as num?)?.toInt() ?? 0,
        statut: StatutEcheanceLoyer.parse(json['statut'] as String?),
        quittanceDocumentId: json['quittance_document_id'] as String?,
        recuDocumentIds: (json['recu_document_ids'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        derniereDatePaiement: json['derniere_date_paiement'] != null
            ? DateTime.tryParse(json['derniere_date_paiement'].toString())
            : null,
        remarques: json['remarques'] as String?,
        creeLe: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
        misAJourLe: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
        version: (json['version'] as num?)?.toInt() ?? 1,
      );
}

/// Statistiques consolidées de recouvrement des loyers pour une période donnée.
class RecouvrementStatistiques {
  const RecouvrementStatistiques({
    required this.totalAppele,
    required this.totalEncaisse,
    required this.totalImpayes,
    required this.nbEcheances,
    required this.nbSoldes,
    required this.nbEnRetard,
  });

  final int totalAppele;
  final int totalEncaisse;
  final int totalImpayes;
  final int nbEcheances;
  final int nbSoldes;
  final int nbEnRetard;

  double get tauxRecouvrement =>
      totalAppele > 0 ? ((totalEncaisse / totalAppele) * 100).clamp(0.0, 100.0) : 0.0;
}
