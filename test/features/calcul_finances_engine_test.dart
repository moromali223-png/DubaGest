import 'package:dubagest/core/sync/sync_models.dart';
import 'package:dubagest/features/commerce/domain/entities/commerce.dart';
import 'package:dubagest/features/commerce/domain/services/etat_commerce.dart';
import 'package:dubagest/features/finances/domain/entities/finance_period_filter.dart';
import 'package:dubagest/features/finances/domain/entities/finances.dart';
import 'package:dubagest/features/finances/domain/services/calcul_finances_engine.dart';
import 'package:dubagest/features/finances/domain/services/etat_finances.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const entrepriseId = 'ent-1';
  const boutique1 = 'b-1';
  const boutique2 = 'b-2';
  const engine = CalculFinancesEngine();
  final dateRef = DateTime(2026, 10, 15, 12, 0);

  group('CalculFinancesEngine — Scénarios obligatoires', () {
    test('1. Vente au comptant : CA +100k, Encaissement +100k, Créance 0, Trésorerie +100k', () {
      final caisse = Caisse(id: 'c1', entrepriseId: entrepriseId, perimetreId: boutique1, nom: 'Caisse 1');
      final session = SessionCaisse(
        id: 's1',
        entrepriseId: entrepriseId,
        caisseId: 'c1',
        perimetreId: boutique1,
        ouverte: true,
        soldeInitial: 0,
        ouverteLe: DateTime(2026, 10, 1),
      );

      final vente = Vente(
        id: 'v1',
        entrepriseId: entrepriseId,
        perimetreId: boutique1,
        lignes: const [
          LigneOperation(id: 'l1', produitId: 'p1', unite: 'U', facteur: Qte.un, prixUnitaire: 100000, quantite: Qte.un),
        ],
        total: 100000,
        montantPaye: 100000,
        reglement: ReglementVente.immediat,
        date: dateRef,
        paiementId: 'p1',
      );

      final paiement = Paiement(
        id: 'p1',
        entrepriseId: entrepriseId,
        perimetreId: boutique1,
        sens: SensPaiement.entree,
        montant: 100000,
        mode: ModePaiement.especes,
        datePaiement: dateRef,
        sessionId: 's1',
      );

      final mvt = MouvementCaisse(
        id: 'm1',
        sessionId: 's1',
        caisseId: 'c1',
        type: TypeMouvement.encaissement,
        montant: 100000,
        paiementId: 'p1',
        createdAt: dateRef,
      );

      final etatFinances = EtatFinances(
        caisses: [caisse],
        sessions: [session],
        paiements: [paiement],
        mouvements: [mvt],
      );

      final etatCommerce = EtatCommerce(ventes: [vente]);

      final result = engine.calculer(
        etatFinances: etatFinances,
        etatCommerce: etatCommerce,
        periodeFiltre: const FiltrePeriodeFinance(type: TypePeriodeFinance.ceMois),
        maintenant: dateRef,
      );

      expect(result.chiffreAffaires.valeurActuelle, 100000);
      expect(result.fluxTresorerie.entreesReelles, 100000);
      expect(result.aRecevoir.valeurActuelle, 0);
      expect(result.tresorerieDisponible.valeurActuelle, 100000);
    });

    test('2. Vente à crédit : Vente 100k, Payé 40k -> CA 100k, Encaissement 40k, Créance 60k, Trésorerie 40k', () {
      final caisse = Caisse(id: 'c1', entrepriseId: entrepriseId, perimetreId: boutique1, nom: 'Caisse 1');
      final session = SessionCaisse(
        id: 's1',
        entrepriseId: entrepriseId,
        caisseId: 'c1',
        perimetreId: boutique1,
        ouverte: true,
        soldeInitial: 0,
        ouverteLe: DateTime(2026, 10, 1),
      );

      final vente = Vente(
        id: 'v1',
        entrepriseId: entrepriseId,
        perimetreId: boutique1,
        lignes: const [
          LigneOperation(id: 'l1', produitId: 'p1', unite: 'U', facteur: Qte.un, prixUnitaire: 100000, quantite: Qte.un),
        ],
        total: 100000,
        montantPaye: 40000,
        reglement: ReglementVente.credit,
        date: dateRef,
      );

      final engagement = Engagement(
        id: 'e1',
        entrepriseId: entrepriseId,
        perimetreId: boutique1,
        sens: SensEngagement.aRecevoir,
        libelle: 'Vente à crédit',
        montantTotal: 100000,
        montantRegle: 40000,
        dateEngagement: dateRef,
        origineType: 'VENTE',
      );

      final acompte = Paiement(
        id: 'p1',
        entrepriseId: entrepriseId,
        perimetreId: boutique1,
        sens: SensPaiement.entree,
        montant: 40000,
        mode: ModePaiement.especes,
        datePaiement: dateRef,
        sessionId: 's1',
        affectations: const [Affectation(id: 'a1', engagementId: 'e1', montant: 40000)],
      );

      final mvt = MouvementCaisse(
        id: 'm1',
        sessionId: 's1',
        caisseId: 'c1',
        type: TypeMouvement.encaissement,
        montant: 40000,
        paiementId: 'p1',
        createdAt: dateRef,
      );

      final etatFinances = EtatFinances(
        caisses: [caisse],
        sessions: [session],
        engagements: [engagement],
        paiements: [acompte],
        mouvements: [mvt],
      );

      final etatCommerce = EtatCommerce(ventes: [vente]);

      final result = engine.calculer(
        etatFinances: etatFinances,
        etatCommerce: etatCommerce,
        periodeFiltre: const FiltrePeriodeFinance(type: TypePeriodeFinance.ceMois),
        maintenant: dateRef,
      );

      expect(result.chiffreAffaires.valeurActuelle, 100000);
      expect(result.fluxTresorerie.entreesReelles, 40000);
      expect(result.aRecevoir.valeurActuelle, 60000);
      expect(result.tresorerieDisponible.valeurActuelle, 40000);
    });

    test('3. Dépense : Dépense 20k payée en espèces -> Dépenses +20k, Trésorerie -20k', () {
      final caisse = Caisse(id: 'c1', entrepriseId: entrepriseId, perimetreId: boutique1, nom: 'Caisse 1');
      final session = SessionCaisse(
        id: 's1',
        entrepriseId: entrepriseId,
        caisseId: 'c1',
        perimetreId: boutique1,
        ouverte: true,
        soldeInitial: 50000,
        ouverteLe: DateTime(2026, 10, 1),
      );

      final depense = Depense(
        id: 'd1',
        entrepriseId: entrepriseId,
        perimetreId: boutique1,
        categorieId: 'cat1',
        libelle: 'Carburant',
        montant: 20000,
        dateDepense: dateRef,
        payeeImmediatement: true,
        mode: ModePaiement.especes,
        sessionId: 's1',
        paiementId: 'p1',
      );

      final paiement = Paiement(
        id: 'p1',
        entrepriseId: entrepriseId,
        perimetreId: boutique1,
        sens: SensPaiement.sortie,
        montant: 20000,
        mode: ModePaiement.especes,
        datePaiement: dateRef,
        sessionId: 's1',
      );

      final mvt = MouvementCaisse(
        id: 'm1',
        sessionId: 's1',
        caisseId: 'c1',
        type: TypeMouvement.decaissement,
        montant: 20000,
        paiementId: 'p1',
        createdAt: dateRef,
      );

      final etatFinances = EtatFinances(
        caisses: [caisse],
        sessions: [session],
        depenses: [depense],
        paiements: [paiement],
        mouvements: [mvt],
      );

      final result = engine.calculer(
        etatFinances: etatFinances,
        etatCommerce: null,
        periodeFiltre: const FiltrePeriodeFinance(type: TypePeriodeFinance.ceMois),
        maintenant: dateRef,
      );

      expect(result.totalDepenses, 20000);
      expect(result.tresorerieDisponible.valeurActuelle, 30000); // 50000 - 20000
    });

    test('4. Achat à crédit : Achat 500k, Payé 200k -> Dette 300k, Trésorerie -200k, Dépenses exploitation 0', () {
      final caisse = Caisse(id: 'c1', entrepriseId: entrepriseId, perimetreId: boutique1, nom: 'Caisse 1');
      final session = SessionCaisse(
        id: 's1',
        entrepriseId: entrepriseId,
        caisseId: 'c1',
        perimetreId: boutique1,
        ouverte: true,
        soldeInitial: 300000,
        ouverteLe: DateTime(2026, 10, 1),
      );

      final engagement = Engagement(
        id: 'e_achat1',
        entrepriseId: entrepriseId,
        perimetreId: boutique1,
        sens: SensEngagement.aPayer,
        libelle: 'Achat Fournisseur Marchandises',
        montantTotal: 500000,
        montantRegle: 200000,
        dateEngagement: dateRef,
        origineType: 'MANUEL',
      );

      final paiement = Paiement(
        id: 'p_fournisseur',
        entrepriseId: entrepriseId,
        perimetreId: boutique1,
        sens: SensPaiement.sortie,
        montant: 200000,
        mode: ModePaiement.especes,
        datePaiement: dateRef,
        sessionId: 's1',
        affectations: const [Affectation(id: 'a_f', engagementId: 'e_achat1', montant: 200000)],
      );

      final mvt = MouvementCaisse(
        id: 'm_f',
        sessionId: 's1',
        caisseId: 'c1',
        type: TypeMouvement.decaissement,
        montant: 200000,
        paiementId: 'p_fournisseur',
        createdAt: dateRef,
      );

      final etatFinances = EtatFinances(
        caisses: [caisse],
        sessions: [session],
        engagements: [engagement],
        paiements: [paiement],
        mouvements: [mvt],
      );

      final result = engine.calculer(
        etatFinances: etatFinances,
        etatCommerce: null,
        periodeFiltre: const FiltrePeriodeFinance(type: TypePeriodeFinance.ceMois),
        maintenant: dateRef,
      );

      expect(result.aPayer.valeurActuelle, 300000);
      expect(result.totalDepenses, 0); // Les achats de stock ne sont pas des dépenses opérationnelles
      expect(result.tresorerieDisponible.valeurActuelle, 100000); // 300000 - 200000
    });

    test('5. Paiement client ultérieur : Créance -60k, Trésorerie +60k, CA inchangé', () {
      final caisse = Caisse(id: 'c1', entrepriseId: entrepriseId, perimetreId: boutique1, nom: 'Caisse 1');
      final session = SessionCaisse(
        id: 's1',
        entrepriseId: entrepriseId,
        caisseId: 'c1',
        perimetreId: boutique1,
        ouverte: true,
        soldeInitial: 10000,
        ouverteLe: DateTime(2026, 10, 1),
      );

      // Créance issue du mois précédent (septembre)
      final engagement = Engagement(
        id: 'e_client',
        entrepriseId: entrepriseId,
        perimetreId: boutique1,
        sens: SensEngagement.aRecevoir,
        libelle: 'Facture Septembre',
        montantTotal: 60000,
        montantRegle: 60000,
        dateEngagement: DateTime(2026, 9, 15),
        origineType: 'VENTE',
      );

      final paiement = Paiement(
        id: 'p_reglement',
        entrepriseId: entrepriseId,
        perimetreId: boutique1,
        sens: SensPaiement.entree,
        montant: 60000,
        mode: ModePaiement.especes,
        datePaiement: dateRef,
        sessionId: 's1',
        affectations: const [Affectation(id: 'a_reg', engagementId: 'e_client', montant: 60000)],
      );

      final mvt = MouvementCaisse(
        id: 'm_reg',
        sessionId: 's1',
        caisseId: 'c1',
        type: TypeMouvement.encaissement,
        montant: 60000,
        paiementId: 'p_reglement',
        createdAt: dateRef,
      );

      final etatFinances = EtatFinances(
        caisses: [caisse],
        sessions: [session],
        engagements: [engagement],
        paiements: [paiement],
        mouvements: [mvt],
      );

      final result = engine.calculer(
        etatFinances: etatFinances,
        etatCommerce: null,
        periodeFiltre: const FiltrePeriodeFinance(type: TypePeriodeFinance.ceMois),
        maintenant: dateRef,
      );

      expect(result.chiffreAffaires.valeurActuelle, 0); // Vente du mois passé -> CA du mois actuel est 0
      expect(result.aRecevoir.valeurActuelle, 0); // Totalement soldée
      expect(result.tresorerieDisponible.valeurActuelle, 70000); // 10000 + 60000
    });

    test('6. Transfert entre boutiques : impact neutre sur CA et Dépenses', () {
      final caisseA = Caisse(id: 'cA', entrepriseId: entrepriseId, perimetreId: boutique1, nom: 'Caisse A');
      final sessionA = SessionCaisse(
        id: 'sA',
        entrepriseId: entrepriseId,
        caisseId: 'cA',
        perimetreId: boutique1,
        ouverte: true,
        soldeInitial: 200000,
        ouverteLe: DateTime(2026, 10, 1),
      );

      final caisseB = Caisse(id: 'cB', entrepriseId: entrepriseId, perimetreId: boutique2, nom: 'Caisse B');
      final sessionB = SessionCaisse(
        id: 'sB',
        entrepriseId: entrepriseId,
        caisseId: 'cB',
        perimetreId: boutique2,
        ouverte: true,
        soldeInitial: 50000,
        ouverteLe: DateTime(2026, 10, 1),
      );

      final sortie = Paiement(
        id: 'p_trans_out',
        entrepriseId: entrepriseId,
        perimetreId: boutique1,
        sens: SensPaiement.sortie,
        montant: 100000,
        mode: ModePaiement.especes,
        datePaiement: dateRef,
        nature: NaturePaiement.transfert,
        transfertId: 't1',
        sessionId: 'sA',
      );

      final entree = Paiement(
        id: 'p_trans_in',
        entrepriseId: entrepriseId,
        perimetreId: boutique2,
        sens: SensPaiement.entree,
        montant: 100000,
        mode: ModePaiement.especes,
        datePaiement: dateRef,
        nature: NaturePaiement.transfert,
        transfertId: 't1',
        sessionId: 'sB',
      );

      final mvtA = MouvementCaisse(
        id: 'mA',
        sessionId: 'sA',
        caisseId: 'cA',
        type: TypeMouvement.retrait,
        montant: 100000,
        paiementId: 'p_trans_out',
        createdAt: dateRef,
      );

      final mvtB = MouvementCaisse(
        id: 'mB',
        sessionId: 'sB',
        caisseId: 'cB',
        type: TypeMouvement.depot,
        montant: 100000,
        paiementId: 'p_trans_in',
        createdAt: dateRef,
      );

      final transfert = TransfertTresorerie(
        id: 't1',
        entrepriseId: entrepriseId,
        perimetreSourceId: boutique1,
        perimetreDestId: boutique2,
        modeSource: ModePaiement.especes,
        modeDest: ModePaiement.especes,
        montant: 100000,
        sortieId: 'p_trans_out',
        entreeId: 'p_trans_in',
        dateTransfert: dateRef,
      );

      final etatFinances = EtatFinances(
        caisses: [caisseA, caisseB],
        sessions: [sessionA, sessionB],
        paiements: [sortie, entree],
        mouvements: [mvtA, mvtB],
        transferts: [transfert],
      );

      final result = engine.calculer(
        etatFinances: etatFinances,
        etatCommerce: null,
        periodeFiltre: const FiltrePeriodeFinance(type: TypePeriodeFinance.ceMois),
        maintenant: dateRef,
      );

      expect(result.chiffreAffaires.valeurActuelle, 0);
      expect(result.totalDepenses, 0);
      // Trésorerie consolidée = (200000 - 100000) + (50000 + 100000) = 250000
      expect(result.tresorerieDisponible.valeurActuelle, 250000);
      expect(result.fluxTresorerie.fluxNet, 0);
    });

    test('7. Marge Brute Commerce : basée sur le coût des marchandises vendues (COGS) et non les achats', () {
      final produit = Produit(
        id: 'prod1',
        entrepriseId: entrepriseId,
        nom: 'Sac de Riz',
        uniteBase: 'SAC',
        prixDetail: 25000,
        prixAchat: 18000,
      );

      final vente = Vente(
        id: 'v_riz',
        entrepriseId: entrepriseId,
        perimetreId: boutique1,
        lignes: const [
          LigneOperation(id: 'l1', produitId: 'prod1', unite: 'SAC', facteur: Qte.un, prixUnitaire: 25000, quantite: Qte(20000)), // 2 sacs
        ],
        total: 50000,
        montantPaye: 50000,
        date: dateRef,
      );

      final etatCommerce = EtatCommerce(
        produits: [produit],
        ventes: [vente],
      );

      final etatFinances = EtatFinances();

      final result = engine.calculer(
        etatFinances: etatFinances,
        etatCommerce: etatCommerce,
        periodeFiltre: const FiltrePeriodeFinance(type: TypePeriodeFinance.ceMois),
        maintenant: dateRef,
      );

      // CA = 50 000, COGS = 2 * 18 000 = 36 000, Marge brute = 14 000, Taux marge = 28%
      expect(result.chiffreAffaires.valeurActuelle, 50000);
      expect(result.margeCommerce?.coutMarchandisesVendues, 36000);
      expect(result.margeCommerce?.margeBrute, 14000);
      expect(result.margeCommerce?.tauxMargePourcent, closeTo(28.0, 0.01));
    });
  });
}
