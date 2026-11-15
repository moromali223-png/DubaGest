import 'dart:math' as math;

import '../../../../core/errors/failure.dart';
import '../../../../core/permissions/access_decision.dart';
import 'delinquency_analyzer.dart';
import '../entities/microfinance_enums.dart';
import '../entities/microfinance_models.dart';

/// Résultat détaillé de l'affectation d'un remboursement sur un prêt et ses échéances.
class RepaymentAllocationResult {
  const RepaymentAllocationResult({
    required this.partCapital,
    required this.partInteret,
    required this.typeDeduit,
    required this.allocations,
    required this.installmentsMisAJour,
    required this.loanMisAJour,
  });

  final int partCapital;
  final int partInteret;
  final TypeRemboursement typeDeduit;
  final List<RepaymentInstallmentAllocation> allocations;
  final List<MicrofinanceInstallment> installmentsMisAJour;
  final MicrofinanceLoan loanMisAJour;
}

/// Service pur d'affectation comptable des remboursements.
///
/// Garantit à tout moment :
/// - `partCapital + partInteret == montantEncaisse`
/// - `capitalRembourse <= montantAccorde`
/// - `interetRembourse <= montantInteretTotal`
/// - Le remboursement du capital ne gonfle jamais les intérêts encaissés.
abstract final class RepaymentAllocator {
  static RepaymentAllocationResult allouer({
    required MicrofinanceLoan loan,
    required List<MicrofinanceInstallment> installments,
    required int montantEncaisse,
    TypeRemboursement? typeSouhaite,
    String? installmentCibleId,
    required DateTime datePaiement,
    DateTime? now,
  }) {
    if (montantEncaisse <= 0) {
      throw const Failure.rule(RuleCodes.amountInvalid);
    }
    if (loan.statut == StatutPret.annule || loan.statut == StatutPret.brouillon) {
      throw const Failure.rule(RuleCodes.commitmentCancelled);
    }

    final restePret = loan.resteAPayerTotal;
    if (restePret <= 0 || loan.statut == StatutPret.solde) {
      throw const Failure.rule(RuleCodes.commitmentPaid);
    }
    if (montantEncaisse > restePret) {
      throw Failure.rule(RuleCodes.amountAboveRemaining, {'reste': restePret});
    }

    final refNow = now ?? datePaiement;
    final triees = List<MicrofinanceInstallment>.from(installments)
      ..sort((a, b) => a.numeroEcheance.compareTo(b.numeroEcheance));

    // Si une échéance cible est précisée, commencer par elle, puis continuer sur les suivantes si excédent (multi-échéances).
    final ordre = <MicrofinanceInstallment>[];
    if (installmentCibleId != null) {
      final cibleIdx = triees.indexWhere((e) => e.id == installmentCibleId && !e.estSoldee);
      if (cibleIdx >= 0) {
        ordre.add(triees[cibleIdx]);
        for (var i = 0; i < triees.length; i++) {
          if (i != cibleIdx && !triees[i].estSoldee) {
            ordre.add(triees[i]);
          }
        }
      } else {
        ordre.addAll(triees.where((e) => !e.estSoldee));
      }
    } else {
      ordre.addAll(triees.where((e) => !e.estSoldee));
    }

    var restantAAllouer = montantEncaisse;
    var totalPartCapital = 0;
    var totalPartInteret = 0;
    final allocations = <RepaymentInstallmentAllocation>[];
    final updatesMap = <String, MicrofinanceInstallment>{};

    for (final ech in ordre) {
      if (restantAAllouer <= 0) break;

      final aPayerSurEch = math.min(restantAAllouer, ech.resteAPayer);
      if (aPayerSurEch <= 0) continue;

      // Imputation comptable : intérêts échus de l'échéance d'abord, puis principal.
      final interetPart = math.min(aPayerSurEch, ech.interetRestant);
      final capitalPart = math.min(aPayerSurEch - interetPart, ech.capitalRestant);

      // Sécurité d'arrondi résiduel (si capitalPart + interetPart != aPayerSurEch)
      final diff = aPayerSurEch - (interetPart + capitalPart);
      final capFinal = capitalPart + diff;

      final nouvCapPaye = ech.capitalPaye + capFinal;
      final nouvIntPaye = ech.interetPaye + interetPart;
      final nouvPaye = ech.montantDejaPaye + aPayerSurEch;
      final nouvReste = (ech.montantTotalAttendu - nouvPaye).clamp(0, ech.montantTotalAttendu);

      final statutEch = nouvReste <= 0
          ? StatutEcheance.paye
          : DelinquencyAnalyzer.statutEcheanceActuel(
              ech.copyWith(
                capitalPaye: nouvCapPaye,
                interetPaye: nouvIntPaye,
                montantDejaPaye: nouvPaye,
                resteAPayer: nouvReste,
                statut: StatutEcheance.partiel,
              ),
              refNow,
            );

      updatesMap[ech.id] = ech.copyWith(
        capitalPaye: nouvCapPaye,
        interetPaye: nouvIntPaye,
        montantDejaPaye: nouvPaye,
        resteAPayer: nouvReste,
        statut: statutEch,
        dateDernierPaiement: datePaiement,
        updatedAt: refNow,
      );

      allocations.add(RepaymentInstallmentAllocation(
        installmentId: ech.id,
        numeroEcheance: ech.numeroEcheance,
        montantAffecte: aPayerSurEch,
        partCapital: capFinal,
        partInteret: interetPart,
      ));

      totalPartCapital += capFinal;
      totalPartInteret += interetPart;
      restantAAllouer -= aPayerSurEch;
    }

    final installmentsMisAJour = [
      for (final ech in triees) updatesMap[ech.id] ?? ech,
    ];

    final nouvCapLoan = loan.capitalRembourse + totalPartCapital;
    final nouvIntLoan = loan.interetRembourse + totalPartInteret;
    final resteFinal = loan.montantTotalARembourser - (nouvCapLoan + nouvIntLoan);

    final nouvStatutLoan = resteFinal <= 0
        ? StatutPret.solde
        : DelinquencyAnalyzer.statutPretActuel(
            loan.copyWith(
              capitalRembourse: nouvCapLoan,
              interetRembourse: nouvIntLoan,
              statut: StatutPret.partiellementRembourse,
            ),
            installmentsMisAJour,
            refNow,
          );

    // Déduction automatique du type de remboursement si non forcé
    final typeDeduit = typeSouhaite ??
        (resteFinal <= 0
            ? (allocations.length > 1 ? TypeRemboursement.anticipe : TypeRemboursement.complet)
            : (allocations.length > 1
                ? TypeRemboursement.multiEcheances
                : ((updatesMap.values.firstOrNull?.resteAPayer ?? 0) > 0
                    ? TypeRemboursement.partiel
                    : TypeRemboursement.complet)));

    final loanMisAJour = loan.copyWith(
      capitalRembourse: nouvCapLoan,
      interetRembourse: nouvIntLoan,
      statut: nouvStatutLoan,
      dateSolde: resteFinal <= 0 ? datePaiement : loan.dateSolde,
      updatedAt: refNow,
    );

    return RepaymentAllocationResult(
      partCapital: totalPartCapital,
      partInteret: totalPartInteret,
      typeDeduit: typeDeduit,
      allocations: allocations,
      installmentsMisAJour: installmentsMisAJour,
      loanMisAJour: loanMisAJour,
    );
  }
}

