import 'package:dubagest/features/microfinance/domain/entities/microfinance_enums.dart';
import 'package:dubagest/features/microfinance/domain/entities/microfinance_models.dart';
import 'package:dubagest/features/microfinance/domain/services/delinquency_analyzer.dart';
import 'package:dubagest/features/microfinance/domain/services/loan_interest_calculator.dart';
import 'package:dubagest/features/microfinance/domain/services/repayment_allocator.dart';
import 'package:dubagest/features/modules/domain/entities/app_module.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/contexte_fixtures.dart';

void main() {
  final now = DateTime(2026, 11, 14, 10, 0);

  group('Contrôle strict d\'accès Microfinance (Pro 5 000 FCFA uniquement)', () {
    test('Refuse l\'accès pour la formule 1 000 FCFA (NORMAL) et 2 000 FCFA (MOYEN)', () {
      final ctxNormal = contexte(plan: 'NORMAL', activites: const ['COMMERCE']);
      final ctxMoyen = contexte(plan: 'MOYEN', activites: const ['COMMERCE']);

      expect(
        ctxNormal.accessPolicy(DateTime(2026, 10, 3)).canAccessModule(ModuleCodes.commerceMicrofinance).isAllowed,
        isFalse,
      );
      expect(
        ctxMoyen.accessPolicy(DateTime(2026, 10, 3)).canAccessModule(ModuleCodes.commerceMicrofinance).isAllowed,
        isFalse,
      );
    });

    test('Autorise l\'accès uniquement pour la formule PRO active (5 000 FCFA) avec activité Commerce', () {
      final ctxPro = contexte(
        plan: 'PRO',
        activites: const ['COMMERCE'],
        abonnementStatut: 'ACTIF',
        dateFin: DateTime(2026, 12, 31),
      );
      final decision =
          ctxPro.accessPolicy(DateTime(2026, 10, 3)).canAccessModule(ModuleCodes.commerceMicrofinance);
      expect(decision.isAllowed, isTrue);

      final ctxProEssai = contexte(
        plan: 'PRO',
        activites: const ['COMMERCE'],
        abonnementStatut: 'ESSAI',
        dateFin: DateTime(2026, 10, 10),
      );
      expect(
        ctxProEssai.accessPolicy(DateTime(2026, 10, 3)).canAccessModule(ModuleCodes.commerceMicrofinance).isAllowed,
        isTrue,
      );
    });

    test('Suspend l\'accès si la formule PRO est expirée ou sans activité Commerce', () {
      final ctxProExpire = contexte(
        plan: 'PRO',
        activites: const ['COMMERCE'],
        abonnementStatut: 'ACTIF',
        dateFin: DateTime(2026, 10, 1),
      );
      expect(
        ctxProExpire
            .accessPolicy(DateTime(2026, 10, 10))
            .canAccessModule(ModuleCodes.commerceMicrofinance)
            .isAllowed,
        isFalse,
      );

      final ctxProSansCommerce = contexte(
        plan: 'PRO',
        activites: const ['SERVICES'],
        abonnementStatut: 'ACTIF',
        dateFin: DateTime(2026, 12, 31),
      );
      expect(
        ctxProSansCommerce
            .accessPolicy(DateTime(2026, 10, 3))
            .canAccessModule(ModuleCodes.commerceMicrofinance)
            .isAllowed,
        isFalse,
      );
    });
  });

  group('LoanInterestCalculator — 3 méthodes et arrondis FCFA exacts', () {
    test('Pourcentage fixe avec capital non divisible reste exactement égal à la somme des échéances', () {
      final sim = LoanInterestCalculator.simuler(
        entrepriseId: 'e1',
        loanId: 'l1',
        borrowerId: 'b1',
        montantAccorde: 100000,
        methode: MethodeCalculInteret.pourcentageFixe,
        tauxInteret: 15,
        frequence: FrequenceRemboursement.mensuelle,
        nombreEcheances: 3,
        dateDebut: DateTime(2026, 12, 1),
        now: now,
      );

      expect(sim.montantEmprunte, 100000);
      expect(sim.montantInteretTotal, 15000);
      expect(sim.montantTotalARembourser, 115000);
      expect(sim.echeances.length, 3);
      expect(sim.echeances.fold<int>(0, (s, e) => s + e.capitalPrevu), 100000);
      expect(sim.echeances.fold<int>(0, (s, e) => s + e.interetPrevu), 15000);
      expect(sim.echeances.fold<int>(0, (s, e) => s + e.montantTotalAttendu), 115000);
      expect(sim.echeances[0].capitalPrevu, 33333);
      expect(sim.echeances[2].capitalPrevu, 33334);
    });

    test('Montant fixe manuel réparti exactement sur les échéances', () {
      final sim = LoanInterestCalculator.simuler(
        entrepriseId: 'e1',
        loanId: 'l2',
        borrowerId: 'b1',
        montantAccorde: 50000,
        methode: MethodeCalculInteret.montantFixe,
        montantInteretFixe: 10000,
        frequence: FrequenceRemboursement.hebdomadaire,
        nombreEcheances: 4,
        dateDebut: DateTime(2026, 11, 21),
        now: now,
      );

      expect(sim.montantInteretTotal, 10000);
      expect(sim.montantTotalARembourser, 60000);
      expect(sim.echeances[0].montantTotalAttendu, 15000);
      expect(sim.echeances[1].datePrevue, DateTime(2026, 11, 28));
    });

    test('Intérêt dégressif calcule chaque intérêt sur le capital restant dû en début de période', () {
      final sim = LoanInterestCalculator.simuler(
        entrepriseId: 'e1',
        loanId: 'l3',
        borrowerId: 'b1',
        montantAccorde: 100000,
        methode: MethodeCalculInteret.degressif,
        tauxInteret: 10,
        frequence: FrequenceRemboursement.mensuelle,
        nombreEcheances: 2,
        dateDebut: DateTime(2026, 1, 31),
        now: now,
      );

      // Échéance 1 : 10% de 100 000 = 10 000 ; Échéance 2 : 10% de 50 000 = 5 000.
      expect(sim.echeances[0].interetPrevu, 10000);
      expect(sim.echeances[1].interetPrevu, 5000);
      expect(sim.montantInteretTotal, 15000);
      expect(sim.montantTotalARembourser, 115000);
      // Clamping fin de mois (31 janvier -> 28 février 2026).
      expect(sim.echeances[1].datePrevue, DateTime(2026, 2, 28));
    });
  });

  group('RepaymentAllocator — Ventilation stricte capital / intérêts', () {
    test('Affecte un paiement partiel, multi-échéances et un solde anticipé sans confondre capital et intérêt', () {
      final sim = LoanInterestCalculator.simuler(
        entrepriseId: 'e1',
        loanId: 'l4',
        borrowerId: 'b1',
        montantAccorde: 100000,
        methode: MethodeCalculInteret.pourcentageFixe,
        tauxInteret: 20,
        frequence: FrequenceRemboursement.mensuelle,
        nombreEcheances: 2,
        dateDebut: DateTime(2026, 12, 1),
        now: now,
      );

      var loan = MicrofinanceLoan(
        id: 'l4',
        entrepriseId: 'e1',
        reference: 'PR-20261114-001',
        borrowerId: 'b1',
        accountId: 'acc1',
        montantAccorde: 100000,
        methodeInteret: MethodeCalculInteret.pourcentageFixe,
        tauxInteret: 20,
        montantInteretTotal: sim.montantInteretTotal,
        montantTotalARembourser: sim.montantTotalARembourser,
        frequence: FrequenceRemboursement.mensuelle,
        dureeValeur: 2,
        nombreEcheances: 2,
        montantEcheanceIndicatif: sim.montantEcheanceStandard,
        dateOctroi: now,
        dateDecaissement: now,
        dateDebut: sim.dateDebut,
        dateFinPrevue: sim.dateFinPrevue,
        statut: StatutPret.enCours,
        createdAt: now,
        updatedAt: now,
      );
      var echs = sim.echeances;

      // 1) Paiement partiel de 15 000 F sur échéance #1 (Capital 50k + Intérêt 10k).
      // Les intérêts échus de #1 (10 000) sont encaissés en premier, le reste (5 000) amortit le capital.
      final res1 = RepaymentAllocator.allouer(
        loan: loan,
        installments: echs,
        montantEncaisse: 15000,
        datePaiement: now,
      );
      expect(res1.partInteret, 10000);
      expect(res1.partCapital, 5000);
      expect(res1.typeDeduit, TypeRemboursement.partiel);
      expect(res1.loanMisAJour.statut, StatutPret.partiellementRembourse);

      loan = res1.loanMisAJour;
      echs = [
        for (final e in echs)
          res1.installmentsMisAJour.firstWhere((u) => u.id == e.id, orElse: () => e),
      ];

      // 2) Règlement anticipé intégral du solde (105 000 F).
      final res2 = RepaymentAllocator.allouer(
        loan: loan,
        installments: echs,
        montantEncaisse: 105000,
        typeSouhaite: TypeRemboursement.anticipe,
        datePaiement: now,
      );
      expect(res2.partCapital, 95000);
      expect(res2.partInteret, 10000);
      expect(res2.loanMisAJour.resteAPayerTotal, 0);
      expect(res2.loanMisAJour.statut, StatutPret.solde);
    });
  });

  group('DelinquencyAnalyzer — Retards, revenus réels vs capital et résultat net', () {
    test('Distingue rigoureusement capital, remboursement principal, intérêts encaissés et résultat net', () {
      final account = MicrofinanceAccount(
        id: 'acc1',
        entrepriseId: 'e1',
        nom: 'Caisse Principale',
        soldeInitial: 500000,
        soldeActuel: 455000,
        createdAt: now,
        updatedAt: now,
      );

      final movements = [
        MicrofinanceFundMovement(
          id: 'f1',
          entrepriseId: 'e1',
          reference: 'MF-INIT',
          accountId: 'acc1',
          typeMouvement: TypeMouvementFonds.apportInitial,
          montant: 500000,
          dateMouvement: now,
          libelle: 'Capital initial',
          createdAt: now,
          updatedAt: now,
        ),
        MicrofinanceFundMovement(
          id: 'f2',
          entrepriseId: 'e1',
          reference: 'MF-DEP',
          accountId: 'acc1',
          typeMouvement: TypeMouvementFonds.depenseFonctionnement,
          montant: 5000,
          dateMouvement: now,
          libelle: 'Fournitures',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final borrower = MicrofinanceBorrower(
        id: 'b1',
        entrepriseId: 'e1',
        codeEmprunteur: 'EMP-001',
        nomComplet: 'Moussa Koné',
        telephone: '+22370000001',
        dateInscription: now,
        createdAt: now,
        updatedAt: now,
      );

      final loan = MicrofinanceLoan(
        id: 'l10',
        entrepriseId: 'e1',
        reference: 'PR-010',
        borrowerId: 'b1',
        accountId: 'acc1',
        montantAccorde: 100000,
        methodeInteret: MethodeCalculInteret.pourcentageFixe,
        tauxInteret: 20,
        montantInteretTotal: 20000,
        montantTotalARembourser: 120000,
        capitalRembourse: 50000,
        interetRembourse: 10000,
        frequence: FrequenceRemboursement.mensuelle,
        dureeValeur: 2,
        nombreEcheances: 2,
        montantEcheanceIndicatif: 60000,
        dateOctroi: now.subtract(const Duration(days: 40)),
        dateDecaissement: now.subtract(const Duration(days: 40)),
        dateDebut: now.subtract(const Duration(days: 10)),
        dateFinPrevue: now.add(const Duration(days: 20)),
        statut: StatutPret.partiellementRembourse,
        createdAt: now,
        updatedAt: now,
      );

      final echRetard = MicrofinanceInstallment(
        id: 'i1',
        entrepriseId: 'e1',
        loanId: 'l10',
        borrowerId: 'b1',
        numeroEcheance: 1,
        datePrevue: now.subtract(const Duration(days: 5)),
        capitalPrevu: 50000,
        interetPrevu: 10000,
        montantTotalAttendu: 60000,
        capitalPaye: 0,
        interetPaye: 0,
        montantDejaPaye: 0,
        resteAPayer: 60000,
        createdAt: now,
        updatedAt: now,
      );

      final repayment = MicrofinanceRepayment(
        id: 'r1',
        entrepriseId: 'e1',
        reference: 'RB-001',
        loanId: 'l10',
        borrowerId: 'b1',
        accountId: 'acc1',
        datePaiement: now,
        montantEncaisse: 60000,
        partCapital: 50000,
        partInteret: 10000,
        createdAt: now,
        updatedAt: now,
      );

      final stats = DelinquencyAnalyzer.calculerDashboard(
        accounts: [account],
        fundMovements: movements,
        borrowers: [borrower],
        loans: [loan],
        installments: [echRetard],
        repayments: [repayment],
        now: now,
      );

      expect(stats.capitalInitial, 500000);
      expect(stats.capitalTotalDisponible, 455000);
      expect(stats.totalMontantsDecaisses, 100000);
      expect(stats.capitalRestantARecuperer, 50000);
      expect(stats.totalRemboursementsRecus, 60000);
      expect(stats.nombrePretsAccordes, 1);
      expect(stats.nombrePretsTotalPortefeuille, 1);
      expect(stats.nombreRemboursementsRecus, 1);
      expect(stats.partCapitalRemboursee, 50000);
      expect(stats.resteAPayerTotal, 60000);
      // Les revenus réels = intérêts encaissés uniquement (10 000), pas les 60 000 remboursés !
      expect(stats.totalInteretsEncaisses, 10000);
      expect(stats.revenusReels, 10000);
      expect(stats.depensesFonctionnement, 5000);
      expect(stats.resultatFinancierNet, 5000);
      expect(stats.nombrePretsEnRetard, 1);
      expect(stats.montantTotalImpayes, 60000);
      expect(DelinquencyAnalyzer.joursRetardEcheance(echRetard, now), 5);
    });

    test('Filtre correctement le nombre de prêts accordés et le total payé par jour, semaine, mois, année et période personnalisée', () {
      final refNow = DateTime(2026, 11, 14, 15, 30); // Samedi 14 nov 2026
      final borrower = MicrofinanceBorrower(
        id: 'b1',
        entrepriseId: 'e1',
        codeEmprunteur: 'EMP-001',
        nomComplet: 'Awa Diallo',
        telephone: '+22370000002',
        dateInscription: refNow,
        createdAt: refNow,
        updatedAt: refNow,
      );

      MicrofinanceLoan mkLoan(String id, DateTime dt, int montant, int interet) => MicrofinanceLoan(
            id: id,
            entrepriseId: 'e1',
            reference: id,
            borrowerId: 'b1',
            accountId: 'acc1',
            montantAccorde: montant,
            methodeInteret: MethodeCalculInteret.montantFixe,
            montantInteretFixe: interet,
            montantInteretTotal: interet,
            montantTotalARembourser: montant + interet,
            frequence: FrequenceRemboursement.mensuelle,
            dureeValeur: 1,
            nombreEcheances: 1,
            montantEcheanceIndicatif: montant + interet,
            dateOctroi: dt,
            dateDecaissement: dt,
            dateDebut: dt.add(const Duration(days: 30)),
            dateFinPrevue: dt.add(const Duration(days: 30)),
            statut: StatutPret.enCours,
            createdAt: dt,
            updatedAt: dt,
          );

      MicrofinanceRepayment mkRep(String id, String loanId, DateTime dt, int cap, int interet) =>
          MicrofinanceRepayment(
            id: id,
            entrepriseId: 'e1',
            reference: id,
            loanId: loanId,
            borrowerId: 'b1',
            accountId: 'acc1',
            datePaiement: dt,
            montantEncaisse: cap + interet,
            partCapital: cap,
            partInteret: interet,
            createdAt: dt,
            updatedAt: dt,
          );

      final loans = [
        mkLoan('l_jour', DateTime(2026, 11, 14, 10, 0), 50000, 5000), // Jour + Semaine + Mois + Année
        mkLoan('l_semaine', DateTime(2026, 11, 10, 9, 0), 80000, 8000), // Mardi de la même semaine
        mkLoan('l_mois', DateTime(2026, 11, 2, 9, 0), 100000, 10000), // Même mois
        mkLoan('l_annee', DateTime(2026, 5, 15, 9, 0), 120000, 12000), // Même année
        mkLoan('l_ancien', DateTime(2025, 12, 1, 9, 0), 200000, 20000), // Année précédente
      ];

      final repayments = [
        mkRep('r_jour', 'l_jour', DateTime(2026, 11, 14, 12, 0), 10000, 2000), // 12 000
        mkRep('r_semaine', 'l_semaine', DateTime(2026, 11, 11, 12, 0), 15000, 3000), // 18 000
        mkRep('r_mois', 'l_mois', DateTime(2026, 11, 3, 12, 0), 20000, 5000), // 25 000
        mkRep('r_annee', 'l_annee', DateTime(2026, 6, 1, 12, 0), 30000, 5000), // 35 000
        mkRep('r_ancien', 'l_ancien', DateTime(2025, 12, 20, 12, 0), 40000, 10000), // 50 000
      ];

      MicrofinanceDashboardStats evalPeriode(PeriodeMicrofinance p, {DateTime? d, DateTime? f}) {
        final (debut, fin) = DelinquencyAnalyzer.bornesPeriode(
          p,
          refNow,
          debutCustom: d,
          finCustom: f,
        );
        return DelinquencyAnalyzer.calculerDashboard(
          accounts: const [],
          fundMovements: const [],
          borrowers: [borrower],
          loans: loans,
          installments: const [],
          repayments: repayments,
          debut: debut,
          fin: fin,
          now: refNow,
        );
      }

      final sJour = evalPeriode(PeriodeMicrofinance.jour);
      expect(sJour.nombrePretsAccordes, 1);
      expect(sJour.totalMontantsDecaisses, 50000);
      expect(sJour.nombreRemboursementsRecus, 1);
      expect(sJour.totalRemboursementsRecus, 12000);
      expect(sJour.nombrePretsTotalPortefeuille, 5);

      final sSemaine = evalPeriode(PeriodeMicrofinance.semaine);
      expect(sSemaine.nombrePretsAccordes, 2);
      expect(sSemaine.totalMontantsDecaisses, 130000);
      expect(sSemaine.nombreRemboursementsRecus, 2);
      expect(sSemaine.totalRemboursementsRecus, 30000);

      final sMois = evalPeriode(PeriodeMicrofinance.mois);
      expect(sMois.nombrePretsAccordes, 3);
      expect(sMois.totalMontantsDecaisses, 230000);
      expect(sMois.nombreRemboursementsRecus, 3);
      expect(sMois.totalRemboursementsRecus, 55000);

      final sAnnee = evalPeriode(PeriodeMicrofinance.annee);
      expect(sAnnee.nombrePretsAccordes, 4);
      expect(sAnnee.totalMontantsDecaisses, 350000);
      expect(sAnnee.nombreRemboursementsRecus, 4);
      expect(sAnnee.totalRemboursementsRecus, 90000);

      final sCustom = evalPeriode(
        PeriodeMicrofinance.personnalise,
        d: DateTime(2026, 11, 1),
        f: DateTime(2026, 11, 12),
      );
      expect(sCustom.nombrePretsAccordes, 2);
      expect(sCustom.totalMontantsDecaisses, 180000);
      expect(sCustom.nombreRemboursementsRecus, 2);
      expect(sCustom.totalRemboursementsRecus, 43000);

      final sTout = evalPeriode(PeriodeMicrofinance.tout);
      expect(sTout.nombrePretsAccordes, 5);
      expect(sTout.totalMontantsDecaisses, 550000);
      expect(sTout.nombreRemboursementsRecus, 5);
      expect(sTout.totalRemboursementsRecus, 140000);
    });
  });
}

