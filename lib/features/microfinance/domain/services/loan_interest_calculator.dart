import 'package:uuid/uuid.dart';

import '../entities/microfinance_enums.dart';
import '../entities/microfinance_models.dart';

/// Résultat complet d'une simulation de prêt avant validation et décaissement.
class SimulationPretResult {
  const SimulationPretResult({
    required this.montantEmprunte,
    required this.montantInteretTotal,
    required this.montantTotalARembourser,
    required this.dureeValeur,
    required this.nombreEcheances,
    required this.montantEcheanceStandard,
    required this.coutTotalCredit,
    required this.dateDebut,
    required this.dateFinPrevue,
    required this.echeances,
  });

  final int montantEmprunte;
  final int montantInteretTotal;
  final int montantTotalARembourser;
  final int dureeValeur;
  final int nombreEcheances;
  final int montantEcheanceStandard;

  /// Coût total du crédit = montant des intérêts facturés en FCFA.
  final int coutTotalCredit;
  final DateTime dateDebut;
  final DateTime dateFinPrevue;
  final List<MicrofinanceInstallment> echeances;
}

/// Moteur de calcul des intérêts et génération d'échéanciers (arrondis FCFA exacts).
abstract final class LoanInterestCalculator {
  static const _uuid = Uuid();

  /// Calcule la date de la k-ième échéance (`index` à partir de 0).
  static DateTime dateEcheance(DateTime datePremiere, FrequenceRemboursement frequence, int index) {
    final base = DateTime(datePremiere.year, datePremiere.month, datePremiere.day);
    return switch (frequence) {
      FrequenceRemboursement.quotidienne => base.add(Duration(days: index)),
      FrequenceRemboursement.hebdomadaire => base.add(Duration(days: index * 7)),
      FrequenceRemboursement.mensuelle => _addMonthsClamp(base, index),
    };
  }

  static DateTime _addMonthsClamp(DateTime date, int monthsToAdd) {
    final totalMonths = date.year * 12 + (date.month - 1) + monthsToAdd;
    final newYear = totalMonths ~/ 12;
    final newMonth = (totalMonths % 12) + 1;
    final daysInTargetMonth = DateTime(newYear, newMonth + 1, 0).day;
    final clampedDay = date.day > daysInTargetMonth ? daysInTargetMonth : date.day;
    return DateTime(newYear, newMonth, clampedDay);
  }

  /// Simule le plan d'amortissement complet d'un prêt avec vérification exacte des arrondis FCFA.
  ///
  /// - [POURCENTAGE_FIXE] : intérêt total = `round(capital * taux / 100)` réparti sur N échéances.
  /// - [MONTANT_FIXE] : intérêt total = `montantInteretFixe` saisi réparti sur N échéances.
  /// - [DEGRESSIF] : amortissement du capital constant, intérêt de chaque période calculé sur
  ///   le capital restant dû en début de période (`round(CRD * taux / 100)`).
  static SimulationPretResult simuler({
    required String entrepriseId,
    required String loanId,
    required String borrowerId,
    String? perimetreId,
    required int montantAccorde,
    required MethodeCalculInteret methode,
    double tauxInteret = 0,
    int montantInteretFixe = 0,
    required FrequenceRemboursement frequence,
    required int nombreEcheances,
    required DateTime dateDebut,
    DateTime? now,
  }) {
    if (montantAccorde <= 0) {
      throw ArgumentError('Le montant accordé doit être supérieur à 0 FCFA.');
    }
    if (nombreEcheances <= 0) {
      throw ArgumentError('Le nombre d\'échéances doit être supérieur à 0.');
    }
    if (tauxInteret < 0 || montantInteretFixe < 0) {
      throw ArgumentError('Les intérêts ne peuvent pas être négatifs.');
    }

    final horodatage = now ?? DateTime.now();
    final n = nombreEcheances;

    // 1. Ventilation du capital sur N échéances (somme exactement égale à montantAccorde).
    final capBase = montantAccorde ~/ n;
    final capitaux = List<int>.filled(n, capBase);
    final resteCap = montantAccorde - (capBase * n);
    if (resteCap > 0) {
      capitaux[n - 1] += resteCap;
    }

    // 2. Calcul des intérêts par échéance selon la méthode sélectionnée.
    final interets = List<int>.filled(n, 0);
    int totalInteret = 0;

    switch (methode) {
      case MethodeCalculInteret.pourcentageFixe:
        totalInteret = (montantAccorde * tauxInteret / 100.0).round();
        final intBase = totalInteret ~/ n;
        for (var i = 0; i < n; i++) {
          interets[i] = intBase;
        }
        final resteInt = totalInteret - (intBase * n);
        if (resteInt > 0) {
          interets[n - 1] += resteInt;
        }
      case MethodeCalculInteret.montantFixe:
        totalInteret = montantInteretFixe;
        final intBase = totalInteret ~/ n;
        for (var i = 0; i < n; i++) {
          interets[i] = intBase;
        }
        final resteInt = totalInteret - (intBase * n);
        if (resteInt > 0) {
          interets[n - 1] += resteInt;
        }
      case MethodeCalculInteret.degressif:
        var crd = montantAccorde;
        for (var i = 0; i < n; i++) {
          final intPeriode = (crd * tauxInteret / 100.0).round();
          interets[i] = intPeriode;
          totalInteret += intPeriode;
          crd -= capitaux[i];
        }
    }

    // 3. Construction de l'échéancier détaillé.
    final echeances = <MicrofinanceInstallment>[];
    for (var i = 0; i < n; i++) {
      final datePrevue = dateEcheance(dateDebut, frequence, i);
      final cap = capitaux[i];
      final intr = interets[i];
      final totalAttendu = cap + intr;
      final todayStart = DateTime(horodatage.year, horodatage.month, horodatage.day);
      final targetDay = DateTime(datePrevue.year, datePrevue.month, datePrevue.day);

      final statut = targetDay.isBefore(todayStart)
          ? StatutEcheance.enRetard
          : (targetDay.isAtSameMomentAs(todayStart) ? StatutEcheance.aujourdHui : StatutEcheance.aVenir);

      echeances.add(MicrofinanceInstallment(
        id: _uuid.v4(),
        entrepriseId: entrepriseId,
        perimetreId: perimetreId,
        loanId: loanId,
        borrowerId: borrowerId,
        numeroEcheance: i + 1,
        datePrevue: datePrevue,
        capitalPrevu: cap,
        interetPrevu: intr,
        montantTotalAttendu: totalAttendu,
        resteAPayer: totalAttendu,
        statut: statut,
        createdAt: horodatage,
        updatedAt: horodatage,
      ));
    }

    final totalARembourser = montantAccorde + totalInteret;
    final indicatif = n > 0 ? echeances.first.montantTotalAttendu : totalARembourser;

    return SimulationPretResult(
      montantEmprunte: montantAccorde,
      montantInteretTotal: totalInteret,
      montantTotalARembourser: totalARembourser,
      dureeValeur: n,
      nombreEcheances: n,
      montantEcheanceStandard: indicatif,
      coutTotalCredit: totalInteret,
      dateDebut: echeances.first.datePrevue,
      dateFinPrevue: echeances.last.datePrevue,
      echeances: echeances,
    );
  }
}

