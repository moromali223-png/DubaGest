import '../../../finances/domain/entities/finances.dart';

/// Élément d'historique de paiement de loyer consolidé pour le suivi des règlements.
class HistoriquePaiementLoyerItem {
  const HistoriquePaiementLoyerItem({
    required this.id,
    required this.paiementId,
    required this.datePaiement,
    required this.locataireId,
    required this.locataireNom,
    this.locataireTelephone,
    required this.bienId,
    required this.bienNom,
    required this.periodeLibelle,
    required this.periodeMois,
    required this.periodeAnnee,
    required this.montant,
    required this.modePaiement,
    this.referencePaiement,
    required this.resteAPayer,
    required this.estSolde,
    this.documentId,
    this.numeroDocument,
    this.estQuittance = false,
    this.note,
  });

  final String id;
  final String paiementId;
  final DateTime datePaiement;
  final String locataireId;
  final String locataireNom;
  final String? locataireTelephone;
  final String bienId;
  final String bienNom;
  final String periodeLibelle;
  final int periodeMois;
  final int periodeAnnee;
  final int montant;
  final ModePaiement modePaiement;
  final String? referencePaiement;
  final int resteAPayer;
  final bool estSolde;
  final String? documentId;
  final String? numeroDocument;
  final bool estQuittance;
  final String? note;

  String get modeLibelle => switch (modePaiement.code.toUpperCase()) {
        'ESPECES' => 'Espèces',
        'ORANGEMONEY' || 'ORANGE_MONEY' => 'Orange Money',
        'MOOVMONEY' || 'MOOV_MONEY' => 'Moov Money / Mobile Money',
        'VIREMENT' => 'Virement bancaire',
        'CHEQUE' => 'Chèque',
        _ => modePaiement.code,
      };
}

