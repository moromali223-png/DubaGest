import 'package:flutter_test/flutter_test.dart';

import 'package:dubagest/features/activites/domain/entities/activite.dart';
import 'package:dubagest/features/commerce/domain/entities/benefice_commerce_data.dart';
import 'package:dubagest/features/commerce/domain/entities/commerce.dart';
import 'package:dubagest/features/commerce/domain/services/calcul_benefice_commerce.dart';
import 'package:dubagest/features/commerce/domain/services/etat_commerce.dart';
import 'package:dubagest/features/finances/domain/entities/finances.dart';
import 'package:dubagest/features/finances/domain/services/etat_finances.dart';

void main() {
  final refDate = DateTime(2026, 11, 6, 12, 0);

  group('CalculBeneficeCommerce - Résolution des filtres temporels', () {
    test('Aujourd\'hui et Hier résolvent des plages précises', () {
      final interAujourdhui = CalculBeneficeCommerce.resoudreIntervalle(
        TypeFiltreBenefice.aujourdhui,
        reference: refDate,
      );
      expect(interAujourdhui.debut, DateTime(2026, 11, 6));
      expect(interAujourdhui.fin.day, 6);
      expect(interAujourdhui.debutPrecedent, DateTime(2026, 11, 5));

      final interHier = CalculBeneficeCommerce.resoudreIntervalle(
        TypeFiltreBenefice.hier,
        reference: refDate,
      );
      expect(interHier.debut, DateTime(2026, 11, 5));
      expect(interHier.fin.day, 5);
      expect(interHier.debutPrecedent, DateTime(2026, 11, 4));
    });

    test('Date précise et Période personnalisée fonctionnent correctement', () {
      final dateCible = DateTime(2026, 5, 20);
      final interDate = CalculBeneficeCommerce.resoudreIntervalle(
        TypeFiltreBenefice.datePrecise,
        datePrecise: dateCible,
        reference: refDate,
      );
      expect(interDate.debut, DateTime(2026, 5, 20));
      expect(interDate.fin.day, 20);

      final interPerso = CalculBeneficeCommerce.resoudreIntervalle(
        TypeFiltreBenefice.personnalise,
        debutPerso: DateTime(2026, 1, 1),
        finPerso: DateTime(2026, 3, 31),
        reference: refDate,
      );
      expect(interPerso.debut, DateTime(2026, 1, 1));
      expect(interPerso.fin.month, 3);
      expect(interPerso.fin.day, 31);
    });
  });

  group('CalculBeneficeCommerce - Calculs financiers et rentabilité', () {
    final pRiz = Produit(
      id: 'prod-riz',
      entrepriseId: 'ent-1',
      nom: 'Sac de Riz 25kg',
      uniteBase: 'Sac',
      prixDetail: 15000,
      prixAchat: 10000, // Coût unitaire 10 000 FCFA
    );

    final pHuile = Produit(
      id: 'prod-huile',
      entrepriseId: 'ent-1',
      nom: 'Bidon Huile 5L',
      uniteBase: 'Bidon',
      prixDetail: 6000,
      prixAchat: 4500, // Coût unitaire 4 500 FCFA
    );

    final pInconnu = Produit(
      id: 'prod-inconnu',
      entrepriseId: 'ent-1',
      nom: 'Épices Vrac',
      uniteBase: 'Sachet',
      prixDetail: 500,
      prixAchat: null, // Prix d'achat NON renseigné
    );

    final dateVente = DateTime(2026, 11, 6, 10, 0);

    // 1. Vente 1 : 2 sacs de riz (CA = 30 000 FCFA, COGS = 20 000 FCFA, Marge = 10 000 FCFA), immédiate
    final v1 = Vente(
      id: 'v-1',
      entrepriseId: 'ent-1',
      perimetreId: 'boutique-a',
      mode: ModeVente.detail,
      date: dateVente,
      reglement: ReglementVente.immediat,
      lignes: [
        LigneVente(
          id: 'lv-1',
          produitId: 'prod-riz',
          unite: 'Sac',
          quantite: Qte.depuis(2),
          prixUnitaire: 15000,
          montant: 30000,
        ),
      ],
      total: 30000,
      remise: 0,
      montantPaye: 30000,
    );

    // 2. Vente 2 : 1 bidon d'huile à crédit (CA = 6 000 FCFA, COGS = 4 500 FCFA, Encaissé = 2 000 FCFA, Reste = 4 000 FCFA)
    final v2Credit = Vente(
      id: 'v-2',
      entrepriseId: 'ent-1',
      perimetreId: 'boutique-a',
      mode: ModeVente.detail,
      date: dateVente,
      reglement: ReglementVente.credit,
      lignes: [
        LigneVente(
          id: 'lv-2',
          produitId: 'prod-huile',
          unite: 'Bidon',
          quantite: Qte.depuis(1),
          prixUnitaire: 6000,
          montant: 6000,
        ),
      ],
      total: 6000,
      remise: 0,
      montantPaye: 2000,
    );

    // 3. Vente 3 : Vente ANNULÉE (Ne doit pas être comptée dans le CA ni COGS)
    final vAnnulee = Vente(
      id: 'v-3',
      entrepriseId: 'ent-1',
      perimetreId: 'boutique-a',
      mode: ModeVente.detail,
      date: dateVente,
      reglement: ReglementVente.immediat,
      lignes: [
        LigneVente(
          id: 'lv-3',
          produitId: 'prod-riz',
          unite: 'Sac',
          quantite: Qte.depuis(5),
          prixUnitaire: 15000,
          montant: 75000,
        ),
      ],
      total: 75000,
      remise: 0,
      montantPaye: 75000,
      statut: 'ANNULEE',
    );

    // 4. Vente 4 sur Boutique B : 1 article sans coût (CA = 500 FCFA)
    final v4BoutiqueB = Vente(
      id: 'v-4',
      entrepriseId: 'ent-1',
      perimetreId: 'boutique-b',
      mode: ModeVente.detail,
      date: dateVente,
      reglement: ReglementVente.immediat,
      lignes: [
        LigneVente(
          id: 'lv-4',
          produitId: 'prod-inconnu',
          unite: 'Sachet',
          quantite: Qte.depuis(1),
          prixUnitaire: 500,
          montant: 500,
        ),
      ],
      total: 500,
      remise: 0,
      montantPaye: 500,
    );

    // Dépenses
    final depBoutiqueA = Depense(
      id: 'dep-1',
      entrepriseId: 'ent-1',
      perimetreId: 'boutique-a',
      categorieId: 'cat-elec',
      libelle: 'Facture Électricité',
      montant: 5000,
      dateDepense: dateVente,
      payeeImmediatement: true,
      activite: ActiviteCode.commerce,
    );

    final depSiege = Depense(
      id: 'dep-siege',
      entrepriseId: 'ent-1',
      perimetreId: null, // Siège / Générale
      categorieId: 'cat-compta',
      libelle: 'Frais de gestion siège',
      montant: 2000,
      dateDepense: dateVente,
      payeeImmediatement: true,
      activite: ActiviteCode.commerce,
    );

    // Paiements effectifs (Trésorerie)
    final p1 = Paiement(
      id: 'pay-1',
      entrepriseId: 'ent-1',
      perimetreId: 'boutique-a',
      sens: SensPaiement.entree,
      montant: 30000,
      mode: ModePaiement.especes,
      datePaiement: dateVente,
      annuleServeur: false,
    );

    final p2Acompte = Paiement(
      id: 'pay-2',
      entrepriseId: 'ent-1',
      perimetreId: 'boutique-a',
      sens: SensPaiement.entree,
      montant: 2000,
      mode: ModePaiement.especes,
      datePaiement: dateVente,
      annuleServeur: false,
    );

    final pSortieDepense = Paiement(
      id: 'pay-sort',
      entrepriseId: 'ent-1',
      perimetreId: 'boutique-a',
      sens: SensPaiement.sortie,
      montant: 5000,
      mode: ModePaiement.especes,
      datePaiement: dateVente,
      annuleServeur: false,
    );

    // Engagement créance restante pour V2
    final engV2 = Engagement(
      id: 'eng-v2',
      entrepriseId: 'ent-1',
      perimetreId: 'boutique-a',
      sens: SensEngagement.aRecevoir,
      origineType: 'VENTE',
      libelle: 'Vente V2',
      montantTotal: 6000,
      montantRegle: 2000,
      dateEngagement: dateVente,
    );

    final etatCommerce = EtatCommerce(
      categories: const [],
      produits: [pRiz, pHuile, pInconnu],
      achats: const [],
      receptions: const [],
      stocks: const [],
      mouvements: const [],
      transferts: const [],
      ventes: [v1, v2Credit, vAnnulee, v4BoutiqueB],
    );

    final etatFinances = EtatFinances(
      engagements: [engV2],
      categories: [
        const CategorieDepense(id: 'cat-elec', entrepriseId: 'ent-1', nom: 'Électricité'),
        const CategorieDepense(id: 'cat-compta', entrepriseId: 'ent-1', nom: 'Comptabilité'),
      ],
      depenses: [depBoutiqueA, depSiege],
      paiements: [p1, p2Acompte, pSortieDepense],
    );

    final intervalle = CalculBeneficeCommerce.resoudreIntervalle(
      TypeFiltreBenefice.aujourdhui,
      reference: refDate,
    );

    test('Boutique A : calcul exact CA Net, COGS, Marge Brute, Dépenses et Bénéfice Net', () {
      final res = CalculBeneficeCommerce.calculer(
        commerce: etatCommerce,
        finances: etatFinances,
        intervalle: intervalle,
        perimetreId: 'boutique-a',
      );

      // CA Net = V1 (30 000) + V2 (6 000) = 36 000 FCFA (Vente annulée 75 000 exclue)
      expect(res.kpi.chiffreAffairesNet, 36000);
      expect(res.kpi.nombreVentes, 2);

      // COGS = V1 (2 sacs * 10 000 = 20 000) + V2 (1 bidon * 4 500 = 4 500) = 24 500 FCFA
      expect(res.kpi.cogs, 24500);

      // Marge Brute = 36 000 - 24 500 = 11 500 FCFA
      expect(res.kpi.margeBrute, 11500);
      expect(res.kpi.tauxMarge, closeTo(31.94, 0.05));

      // Dépenses imputables à Boutique A = 5 000 FCFA (la dépense du siège 2000 n'est pas imputée à la boutique seule)
      expect(res.kpi.depensesCommerciales, 5000);

      // Bénéfice Net Estimé = 11 500 - 5 000 = 6 500 FCFA
      expect(res.kpi.beneficeNetEstime, 6500);
      expect(res.kpi.tauxBeneficeNet, closeTo(18.06, 0.05));
    });

    test('Boutique A : Trésorerie réelle vs Créances distinctes', () {
      final res = CalculBeneficeCommerce.calculer(
        commerce: etatCommerce,
        finances: etatFinances,
        intervalle: intervalle,
        perimetreId: 'boutique-a',
      );

      // Total Encaissé = P1 (30 000) + P2 (2 000) = 32 000 FCFA
      expect(res.tresorerie.totalEncaisse, 32000);

      // Total Décaissé = P_Sortie (5 000 FCFA)
      expect(res.tresorerie.totalDecaisse, 5000);

      // Solde Net des Flux = 32 000 - 5 000 = 27 000 FCFA
      expect(res.tresorerie.soldeNetFlux, 27000);

      // Créance client restante sur V2 = 6 000 - 2 000 = 4 000 FCFA
      expect(res.tresorerie.creancesClientsRestantes, 4000);
    });

    test('Vue Globale consolidée : intègre toutes les boutiques et les dépenses du siège', () {
      final resConsolidee = CalculBeneficeCommerce.calculer(
        commerce: etatCommerce,
        finances: etatFinances,
        intervalle: intervalle,
        perimetreId: null, // Vue globale
      );

      // CA Net Global = 36 000 (Boutique A) + 500 (Boutique B) = 36 500 FCFA
      expect(resConsolidee.kpi.chiffreAffairesNet, 36500);
      expect(resConsolidee.kpi.nombreVentes, 3);

      // Dépenses Globales = 5 000 (Boutique A) + 2 000 (Siège) = 7 000 FCFA
      expect(resConsolidee.kpi.depensesCommerciales, 7000);

      // Taux de couverture : 2 lignes sur 3 ont un coût = 66.67%
      expect(resConsolidee.kpi.lignesTotal, 3);
      expect(resConsolidee.kpi.lignesAvecCout, 2);
      expect(resConsolidee.kpi.tauxCouvertureCout, closeTo(66.67, 0.05));

      // L'article sans coût est bien recensé pour alerte commerçant
      expect(resConsolidee.produitsCoutManquant.length, 1);
      expect(resConsolidee.produitsCoutManquant.first.nom, 'Épices Vrac');
    });
  });
}

