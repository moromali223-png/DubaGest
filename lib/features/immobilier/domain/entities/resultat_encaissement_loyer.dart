import '../../../documents/domain/entities/document.dart';
import '../../../finances/domain/entities/finances.dart';
import 'echeance_loyer.dart';

/// Détail de l'affectation du règlement sur une échéance spécifique.
class AllocationLoyer {
  const AllocationLoyer({
    required this.echeanceId,
    required this.periodeLibelle,
    required this.montantAffecte,
    required this.resteAvant,
    required this.resteApres,
    required this.estSolde,
  });

  final String echeanceId;
  final String periodeLibelle;
  final int montantAffecte;
  final int resteAvant;
  final int resteApres;
  final bool estSolde;
}

/// Résultat complet d'un encaissement de loyer, consolidé avec la finance et la quittance.
class ResultatEncaissementLoyer {
  const ResultatEncaissementLoyer({
    required this.echeancePrincipale,
    required this.allocations,
    required this.montantTotalVerse,
    required this.modePaiement,
    this.referencePaiement,
    this.note,
    required this.datePaiement,
    required this.paiementFinancierId,
    this.document,
    required this.estSoldeTotal,
  });

  final EcheanceLoyer echeancePrincipale;
  final List<AllocationLoyer> allocations;
  final int montantTotalVerse;
  final ModePaiement modePaiement;
  final String? referencePaiement;
  final String? note;
  final DateTime datePaiement;
  final String paiementFinancierId;
  final Document? document;

  /// Vrai si l'ensemble des montants dus sur la période ciblée ont été totalement soldés.
  final bool estSoldeTotal;

  /// Montant total restant dû sur les échéances traitées.
  int get resteTotalDu => allocations.fold(0, (tot, a) => tot + a.resteApres);
}
