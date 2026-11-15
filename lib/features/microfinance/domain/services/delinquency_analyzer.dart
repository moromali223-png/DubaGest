import '../entities/microfinance_enums.dart';
import '../entities/microfinance_models.dart';

/// Analyseur de retards, d'impayés et de statistiques financières consolidées Microfinance.
abstract final class DelinquencyAnalyzer {
  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Nombre de jours de retard d'une échéance non soldée à la date [now].
  static int joursRetardEcheance(MicrofinanceInstallment ech, DateTime now) {
    if (ech.estSoldee || ech.statut == StatutEcheance.annule) return 0;
    final diff = _dayOnly(now).difference(_dayOnly(ech.datePrevue)).inDays;
    return diff > 0 ? diff : 0;
  }

  /// Statut dynamique exact d'une échéance par rapport à la date du jour.
  static StatutEcheance statutEcheanceActuel(MicrofinanceInstallment ech, DateTime now) {
    if (ech.statut == StatutEcheance.annule) return StatutEcheance.annule;
    if (ech.resteAPayer <= 0) return StatutEcheance.paye;

    final auj = _dayOnly(now);
    final prevue = _dayOnly(ech.datePrevue);

    if (prevue.isBefore(auj)) return StatutEcheance.enRetard;
    if (ech.montantDejaPaye > 0) return StatutEcheance.partiel;
    if (prevue.isAtSameMomentAs(auj)) return StatutEcheance.aujourdHui;
    return StatutEcheance.aVenir;
  }

  /// Statut dynamique d'un prêt compte tenu de ses remboursements et de ses retards.
  static StatutPret statutPretActuel(
    MicrofinanceLoan loan,
    List<MicrofinanceInstallment> installmentsLoan,
    DateTime now,
  ) {
    if (loan.statut == StatutPret.annule ||
        loan.statut == StatutPret.brouillon ||
        loan.statut == StatutPret.contentieux) {
      return loan.statut;
    }
    if (loan.resteAPayerTotal <= 0) return StatutPret.solde;

    final aEnRetard = installmentsLoan.any((e) => joursRetardEcheance(e, now) > 0);
    if (aEnRetard) return StatutPret.enRetard;
    if (loan.totalRembourse > 0) return StatutPret.partiellementRembourse;
    return StatutPret.enCours;
  }

  /// Bornes calendaires pour le sélecteur de période du tableau de bord.
  static (DateTime? debut, DateTime? fin) bornesPeriode(
    PeriodeMicrofinance periode,
    DateTime now, {
    DateTime? debutCustom,
    DateTime? finCustom,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final endToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return switch (periode) {
      PeriodeMicrofinance.tout => (null, null),
      PeriodeMicrofinance.jour => (today, endToday),
      PeriodeMicrofinance.semaine => (today.subtract(Duration(days: today.weekday - 1)), endToday),
      PeriodeMicrofinance.mois => (DateTime(now.year, now.month, 1), endToday),
      PeriodeMicrofinance.annee => (DateTime(now.year, 1, 1), endToday),
      PeriodeMicrofinance.personnalise => (
          debutCustom == null ? null : _dayOnly(debutCustom),
          finCustom == null
              ? null
              : DateTime(finCustom.year, finCustom.month, finCustom.day, 23, 59, 59),
        ),
    };
  }

  static bool _dansPeriode(DateTime d, DateTime? debut, DateTime? fin) {
    final local = d.toLocal();
    if (debut != null && local.isBefore(debut)) return false;
    if (fin != null && local.isAfter(fin)) return false;
    return true;
  }

  /// Calcul complet des 16+ indicateurs du Tableau de bord Microfinance.
  static MicrofinanceDashboardStats calculerDashboard({
    required List<MicrofinanceAccount> accounts,
    required List<MicrofinanceFundMovement> fundMovements,
    required List<MicrofinanceBorrower> borrowers,
    required List<MicrofinanceLoan> loans,
    required List<MicrofinanceInstallment> installments,
    required List<MicrofinanceRepayment> repayments,
    DateTime? debut,
    DateTime? fin,
    DateTime? now,
  }) {
    final refNow = now ?? DateTime.now();

    final fondsActifs = fundMovements.where((f) => f.deletedAt == null && !f.estAnnule).toList();
    final fondsPeriode = fondsActifs.where((f) => _dansPeriode(f.dateMouvement, debut, fin)).toList();

    final capitalInitial = fondsPeriode
        .where((f) => f.typeMouvement == TypeMouvementFonds.apportInitial)
        .fold<int>(0, (s, f) => s + f.montant);

    final apportsSupplementaires = fondsPeriode
        .where((f) => f.typeMouvement == TypeMouvementFonds.apportSupplementaire)
        .fold<int>(0, (s, f) => s + f.montant);

    final retraitsCapital = fondsPeriode
        .where((f) => f.typeMouvement == TypeMouvementFonds.retraitCapital)
        .fold<int>(0, (s, f) => s + f.montant);

    final depensesFonctionnement = fondsPeriode
        .where((f) => f.typeMouvement == TypeMouvementFonds.depenseFonctionnement)
        .fold<int>(0, (s, f) => s + f.montant);

    // Trésorerie réellement disponible sur les comptes actifs (état instantané réel)
    final capitalTotalDisponible = accounts
        .where((a) => a.deletedAt == null && a.estActif)
        .fold<int>(0, (s, a) => s + a.soldeActuel);

    // Prêts actifs / décaissés
    final loansValides = loans
        .where((l) => l.deletedAt == null && l.statut != StatutPret.annule && l.statut != StatutPret.brouillon)
        .toList();
    final loansPeriode = loansValides.where((l) => _dansPeriode(l.dateDecaissement ?? l.dateOctroi, debut, fin)).toList();

    final totalMontantsDecaisses = loansPeriode.fold<int>(0, (s, l) => s + l.montantAccorde);
    final totalInteretsPrevus = loansPeriode.fold<int>(0, (s, l) => s + l.montantInteretTotal);
    final nombrePretsAccordes = loansPeriode.length;
    final nombrePretsTotalPortefeuille = loansValides.length;

    // Capital restant à récupérer et reste total à payer sur le portefeuille en cours
    final capitalRestantARecuperer = loansValides.fold<int>(0, (s, l) => s + l.capitalRestantARecuperer);
    final resteAPayerTotal = loansValides.fold<int>(0, (s, l) => s + l.resteAPayerTotal);

    // Remboursements encaissés sur la période (séparation stricte Capital vs Intérêts encaissés)
    final rembValides = repayments
        .where((r) => r.deletedAt == null && !r.estAnnule && _dansPeriode(r.datePaiement, debut, fin))
        .toList();

    final totalRemboursementsRecus = rembValides.fold<int>(0, (s, r) => s + r.montantEncaisse);
    final totalInteretsEncaisses = rembValides.fold<int>(0, (s, r) => s + r.partInteret);
    final partCapitalRemboursee = rembValides.fold<int>(0, (s, r) => s + r.partCapital);
    final nombreRemboursementsRecus = rembValides.length;

    // Analyse des échéances et retards
    final echeancesParLoan = <String, List<MicrofinanceInstallment>>{};
    for (final ech in installments) {
      if (ech.deletedAt == null && ech.statut != StatutEcheance.annule) {
        echeancesParLoan.putIfAbsent(ech.loanId, () => []).add(ech);
      }
    }

    var nbActifs = 0;
    var nbSoldes = 0;
    var nbEnRetard = 0;
    for (final l in loansValides) {
      final echs = echeancesParLoan[l.id] ?? const [];
      final statutLive = statutPretActuel(l, echs, refNow);
      if (statutLive == StatutPret.solde) {
        nbSoldes++;
      } else {
        nbActifs++;
        if (statutLive == StatutPret.enRetard || statutLive == StatutPret.contentieux) {
          nbEnRetard++;
        }
      }
    }

    var montantImpayes = 0;
    var nbEchAuj = 0;
    var montantEchAuj = 0;
    var nbEchRetard = 0;

    final loanIdsValides = loansValides.map((l) => l.id).toSet();
    for (final ech in installments) {
      if (ech.deletedAt != null || !loanIdsValides.contains(ech.loanId)) continue;
      final st = statutEcheanceActuel(ech, refNow);
      if (st == StatutEcheance.enRetard) {
        nbEchRetard++;
        montantImpayes += ech.resteAPayer;
      } else if (st == StatutEcheance.aujourdHui) {
        nbEchAuj++;
        montantEchAuj += ech.resteAPayer;
      }
    }

    final resultatNet = totalInteretsEncaisses - depensesFonctionnement;

    return MicrofinanceDashboardStats(
      capitalInitial: capitalInitial,
      apportsSupplementaires: apportsSupplementaires,
      retraitsCapital: retraitsCapital,
      capitalTotalDisponible: capitalTotalDisponible,
      totalMontantsDecaisses: totalMontantsDecaisses,
      capitalRestantARecuperer: capitalRestantARecuperer,
      totalInteretsPrevus: totalInteretsPrevus,
      totalInteretsEncaisses: totalInteretsEncaisses,
      totalRemboursementsRecus: totalRemboursementsRecus,
      nombreEmprunteurs: borrowers.where((b) => b.deletedAt == null && b.estActif).length,
      nombrePretsActifs: nbActifs,
      nombrePretsSoldes: nbSoldes,
      nombrePretsEnRetard: nbEnRetard,
      montantTotalImpayes: montantImpayes,
      depensesFonctionnement: depensesFonctionnement,
      resultatFinancierNet: resultatNet,
      nombreEcheancesAujourdhui: nbEchAuj,
      montantEcheancesAujourdhui: montantEchAuj,
      nombreEcheancesEnRetard: nbEchRetard,
      nombrePretsAccordes: nombrePretsAccordes,
      nombrePretsTotalPortefeuille: nombrePretsTotalPortefeuille,
      nombreRemboursementsRecus: nombreRemboursementsRecus,
      partCapitalRemboursee: partCapitalRemboursee,
      resteAPayerTotal: resteAPayerTotal,
    );
  }

  /// Construit la fiche de synthèse financière d'un emprunteur.
  static MicrofinanceBorrowerSummary synthetiserEmprunteur({
    required MicrofinanceBorrower borrower,
    required List<MicrofinanceLoan> loans,
    required List<MicrofinanceInstallment> installments,
    DateTime? now,
  }) {
    final refNow = now ?? DateTime.now();
    final sesPrets = loans
        .where((l) => l.borrowerId == borrower.id && l.deletedAt == null && l.statut != StatutPret.annule)
        .toList();

    var nbActifs = 0;
    var nbRetard = 0;
    var totalEmprunte = 0;
    var totalRembourse = 0;
    var resteAPayer = 0;
    var impayes = 0;
    var retardMax = 0;

    for (final l in sesPrets) {
      totalEmprunte += l.montantAccorde;
      totalRembourse += l.totalRembourse;
      resteAPayer += l.resteAPayerTotal;
      final echs = installments.where((e) => e.loanId == l.id && e.deletedAt == null).toList();
      final st = statutPretActuel(l, echs, refNow);
      if (st != StatutPret.solde && st != StatutPret.brouillon) nbActifs++;
      if (st == StatutPret.enRetard || st == StatutPret.contentieux) nbRetard++;
      for (final e in echs) {
        final jr = joursRetardEcheance(e, refNow);
        if (jr > 0) {
          impayes += e.resteAPayer;
          if (jr > retardMax) retardMax = jr;
        }
      }
    }

    return MicrofinanceBorrowerSummary(
      borrower: borrower,
      nombrePretsTotal: sesPrets.length,
      nombrePretsActifs: nbActifs,
      nombrePretsEnRetard: nbRetard,
      totalEmprunte: totalEmprunte,
      totalRembourse: totalRembourse,
      resteAPayerTotal: resteAPayer,
      montantImpayes: impayes,
      joursRetardMax: retardMax,
    );
  }
}

