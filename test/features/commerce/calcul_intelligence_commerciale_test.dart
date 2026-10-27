import 'package:dubagest/features/commerce/domain/entities/commerce.dart';
import 'package:dubagest/features/commerce/domain/entities/intelligence_commerciale_data.dart';
import 'package:dubagest/features/commerce/domain/services/calcul_intelligence_commerciale.dart';
import 'package:dubagest/features/commerce/domain/services/etat_commerce.dart';
import 'package:dubagest/features/contacts/domain/entities/contact.dart';
import 'package:dubagest/features/finances/domain/entities/finances.dart';
import 'package:dubagest/features/finances/domain/services/etat_finances.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 14, 15, 30);

  group('CalculIntelligenceCommerciale - Intervalles', () {
    test('Aujourd\'hui vs Hier ont la même durée de 24h', () {
      final intervalle = CalculIntelligenceCommerciale.resoudreIntervalle(
        PeriodeAnalyseType.aujourdhui,
        now: now,
      );
      expect(intervalle.debut, DateTime(2026, 10, 14));
      expect(intervalle.fin.day, 14);
      expect(intervalle.debutPrecedent, DateTime(2026, 10, 13));
      expect(intervalle.finPrecedent.day, 13);
    });

    test('7 derniers jours vs 7 jours précédents', () {
      final intervalle = CalculIntelligenceCommerciale.resoudreIntervalle(
        PeriodeAnalyseType.septDerniersJours,
        now: now,
      );
      expect(intervalle.dureeJours, 6); // 6 + 1 = 7 jours
      expect(intervalle.debutPrecedent.isBefore(intervalle.debut), isTrue);
    });
  });

  group('CalculIntelligenceCommerciale - Indicateurs et règles métier', () {
    final p1 = Produit(
      id: 'prod-1',
      entrepriseId: 'e-1',
      nom: 'Riz Parfumé 25kg',
      uniteBase: 'sac',
      prixDetail: 17500,
      prixAchat: 14000,
      unites: [
        UniteProduit(
          id: 'u-carton',
          nom: 'balle (2 sacs)',
          facteur: Qte.depuis(2),
          prixDetail: 34000,
          prixAchat: 27000,
        ),
      ],
    );

    final p2 = Produit(
      id: 'prod-2',
      entrepriseId: 'e-1',
      nom: 'Huile Dinor 5L',
      uniteBase: 'bidon',
      prixDetail: 6500,
      prixAchat: 5000,
    );

    final pSansCout = Produit(
      id: 'prod-3',
      entrepriseId: 'e-1',
      nom: 'Savon Artisanal',
      uniteBase: 'morceau',
      prixDetail: 250,
      prixAchat: null, // Coût inconnu
    );

    final client1 = Contact(
      id: 'client-1',
      entrepriseId: 'e-1',
      nom: 'Moussa Traoré',
      telephone: '+223 70 00 00 01',
      relations: const {RelationContact.client},
    );

    final fournisseur1 = Contact(
      id: 'fournisseur-1',
      entrepriseId: 'e-1',
      nom: 'Grossiste Alim SARL',
      telephone: '+223 66 00 00 02',
      relations: const {RelationContact.fournisseur},
    );

    test('Ignore les ventes annulées et calcule le CA et la variation exacte', () {
      final intervalle = CalculIntelligenceCommerciale.resoudreIntervalle(
        PeriodeAnalyseType.septDerniersJours,
        now: now,
      );

      final ventes = [
        // Vente normale dans la période actuelle
        Vente(
          id: 'v-1',
          entrepriseId: 'e-1',
          perimetreId: 'b-1',
          total: 35000,
          montantPaye: 35000,
          date: now.subtract(const Duration(days: 2)),
          lignes: [
            LigneOperation(
              id: 'l-1',
              produitId: 'prod-1',
              unite: 'sac',
              facteur: Qte.un,
              quantite: Qte.depuis(2),
              prixUnitaire: 17500,
            ),
          ],
        ),
        // Vente annulée dans la période actuelle -> DOIT ÊTRE EXCLUE
        Vente(
          id: 'v-annulee',
          entrepriseId: 'e-1',
          perimetreId: 'b-1',
          total: 100000,
          montantPaye: 100000,
          annulee: true,
          date: now.subtract(const Duration(days: 1)),
          lignes: [
            LigneOperation(
              id: 'l-annulee',
              produitId: 'prod-1',
              unite: 'sac',
              facteur: Qte.un,
              quantite: Qte.depuis(10),
              prixUnitaire: 10000,
            ),
          ],
        ),
        // Vente dans la période précédente
        Vente(
          id: 'v-prec',
          entrepriseId: 'e-1',
          perimetreId: 'b-1',
          total: 17500,
          montantPaye: 17500,
          date: now.subtract(const Duration(days: 9)),
          lignes: [
            LigneOperation(
              id: 'l-prec',
              produitId: 'prod-1',
              unite: 'sac',
              facteur: Qte.un,
              quantite: Qte.depuis(1),
              prixUnitaire: 17500,
            ),
          ],
        ),
      ];

      final etatCommerce = EtatCommerce(
        produits: [p1, p2],
        ventes: ventes,
        stocks: [
          StockBoutique(perimetreId: 'b-1', produitId: 'prod-1', quantite: Qte.depuis(10)),
        ],
      );

      final etatFinances = EtatFinances();

      final resultat = CalculIntelligenceCommerciale.calculer(
        commerce: etatCommerce,
        finances: etatFinances,
        contacts: [client1, fournisseur1],
        intervalle: intervalle,
      );

      // Le CA actuel ne doit pas inclure la vente annulée (35000 au lieu de 135000)
      expect(resultat.resume.chiffreAffaires, 35000);
      expect(resultat.resume.chiffreAffairesPrecedent, 17500);
      // Progression: (35000 - 17500) / 17500 = +100%
      expect(resultat.resume.variationCAPct, 100.0);
      expect(resultat.resume.quantiteVendue, 2.0);
      expect(resultat.resume.quantiteVenduePrecedente, 1.0);
      expect(resultat.resume.variationQuantitePct, 100.0);

      // Marge brute: 35000 - (2 * 14000) = 7000 F CFA
      expect(resultat.resume.margeFiable, isTrue);
      expect(resultat.resume.margeBruteEstimee, 7000);
    });

    test('Si les coûts d\'achats manquent pour la majorité des ventes, margeFiable est faux', () {
      final intervalle = CalculIntelligenceCommerciale.resoudreIntervalle(
        PeriodeAnalyseType.septDerniersJours,
        now: now,
      );

      final ventes = [
        Vente(
          id: 'v-sans-cout',
          entrepriseId: 'e-1',
          perimetreId: 'b-1',
          total: 25000,
          montantPaye: 25000,
          date: now.subtract(const Duration(days: 2)),
          lignes: [
            LigneOperation(
              id: 'l-3',
              produitId: 'prod-3', // pas de prixAchat
              unite: 'morceau',
              facteur: Qte.un,
              quantite: Qte.depuis(100),
              prixUnitaire: 250,
            ),
          ],
        ),
      ];

      final etatCommerce = EtatCommerce(
        produits: [pSansCout],
        ventes: ventes,
      );

      final resultat = CalculIntelligenceCommerciale.calculer(
        commerce: etatCommerce,
        finances: EtatFinances(),
        contacts: [],
        intervalle: intervalle,
      );

      expect(resultat.resume.margeFiable, isFalse);
      expect(resultat.resume.margeBruteEstimee, isNull);
    });

    test('Détection des produits achetés ensemble (Cross-selling)', () {
      final intervalle = CalculIntelligenceCommerciale.resoudreIntervalle(
        PeriodeAnalyseType.septDerniersJours,
        now: now,
      );

      // 6 tickets contenant Riz + Huile ensemble
      final ventes = [
        for (var i = 1; i <= 6; i++)
          Vente(
            id: 'v-panier-$i',
            entrepriseId: 'e-1',
            perimetreId: 'b-1',
            total: 24000,
            date: now.subtract(Duration(days: i)),
            lignes: [
              LigneOperation(
                id: 'l-riz-$i',
                produitId: 'prod-1',
                unite: 'sac',
                facteur: Qte.un,
                quantite: Qte.depuis(1),
                prixUnitaire: 17500,
              ),
              LigneOperation(
                id: 'l-huile-$i',
                produitId: 'prod-2',
                unite: 'bidon',
                facteur: Qte.un,
                quantite: Qte.depuis(1),
                prixUnitaire: 6500,
              ),
            ],
          ),
      ];

      final etatCommerce = EtatCommerce(
        produits: [p1, p2],
        ventes: ventes,
      );

      final resultat = CalculIntelligenceCommerciale.calculer(
        commerce: etatCommerce,
        finances: EtatFinances(),
        contacts: [],
        intervalle: intervalle,
      );

      expect(resultat.associationsPaniers.isNotEmpty, isTrue);
      final assoc = resultat.associationsPaniers.first;
      expect(assoc.nombreTicketsEnsemble, 6);
      expect({assoc.produitAId, assoc.produitBId}, {'prod-1', 'prod-2'});
    });

    test('Recommandation de réapprovisionnement intelligente avec conditionnement', () {
      final intervalle = CalculIntelligenceCommerciale.resoudreIntervalle(
        PeriodeAnalyseType.septDerniersJours,
        now: now,
      );

      // Forte vente de riz (14 sacs sur 7 jours -> 2 sacs/jour)
      final ventes = [
        for (var i = 1; i <= 7; i++)
          Vente(
            id: 'v-riz-$i',
            entrepriseId: 'e-1',
            perimetreId: 'b-1',
            total: 35000,
            date: now.subtract(Duration(days: i)),
            lignes: [
              LigneOperation(
                id: 'l-riz-$i',
                produitId: 'prod-1',
                unite: 'sac',
                facteur: Qte.un,
                quantite: Qte.depuis(2),
                prixUnitaire: 17500,
              ),
            ],
          ),
      ];

      // Stock actuel très bas: 2 sacs seulement (1 jour de couverture!)
      final etatCommerce = EtatCommerce(
        produits: [p1],
        ventes: ventes,
        stocks: [
          StockBoutique(perimetreId: 'b-1', produitId: 'prod-1', quantite: Qte.depuis(2)),
        ],
      );

      final resultat = CalculIntelligenceCommerciale.calculer(
        commerce: etatCommerce,
        finances: EtatFinances(),
        contacts: [],
        intervalle: intervalle,
      );

      expect(resultat.recommandationsStock.isNotEmpty, isTrue);
      final reco = resultat.recommandationsStock.firstWhere((r) => r.produitId == 'prod-1');
      expect(reco.urgence, PrioriteConseil.urgent);
      expect(reco.stockActuel, 2.0);
      expect(reco.vitesseVenteJour > 1.5, isTrue);
      // Recommande un multiple de conditionnement (balle de 2 sacs)
      expect(reco.quantiteRecommandeeEnUniteCommande > 0, isTrue);
      expect(reco.uniteCommande, 'balle (2 sacs)');
    });

    test('Intégration créances clients et dettes fournisseurs', () {
      final intervalle = CalculIntelligenceCommerciale.resoudreIntervalle(
        PeriodeAnalyseType.septDerniersJours,
        now: now,
      );

      // Créance client échue
      final creanceEchue = Engagement(
        id: 'eng-creance-1',
        entrepriseId: 'e-1',
        sens: SensEngagement.aRecevoir,
        contactId: 'client-1',
        libelle: 'Vente à crédit #1',
        montantTotal: 50000,
        montantRegle: 10000,
        dateEngagement: now.subtract(const Duration(days: 45)),
        echeance: now.subtract(const Duration(days: 15)), // 15 jours de retard
      );

      // Dette fournisseur
      final detteFournisseur = Engagement(
        id: 'eng-dette-1',
        entrepriseId: 'e-1',
        sens: SensEngagement.aPayer,
        contactId: 'fournisseur-1',
        libelle: 'Achat marchandises #1',
        montantTotal: 200000,
        montantRegle: 50000,
        dateEngagement: now.subtract(const Duration(days: 20)),
        echeance: now.add(const Duration(days: 5)),
      );

      final etatFinances = EtatFinances(
        engagements: [creanceEchue, detteFournisseur],
      );

      final etatCommerce = EtatCommerce(produits: [p1]);

      final resultat = CalculIntelligenceCommerciale.calculer(
        commerce: etatCommerce,
        finances: etatFinances,
        contacts: [client1, fournisseur1],
        intervalle: intervalle,
      );

      // Analyse clients
      expect(resultat.analyseClients.isNotEmpty, isTrue);
      final clientAnalyse = resultat.analyseClients.firstWhere((c) => c.contactId == 'client-1');
      expect(clientAnalyse.creanceRestante, 40000);
      expect(clientAnalyse.creanceEchue, 40000);
      expect(clientAnalyse.joursRetardMax, 15);
      expect(clientAnalyse.niveauRisque, 'Critique');

      // Analyse fournisseurs
      expect(resultat.analyseFournisseurs.isNotEmpty, isTrue);
      final fourAnalyse = resultat.analyseFournisseurs.firstWhere((f) => f.fournisseurId == 'fournisseur-1');
      expect(fourAnalyse.detteRestante, 150000);
      expect(fourAnalyse.detteEchue, 0);

      // Conseils générés
      expect(resultat.conseilsActivite.any((c) => c.id.startsWith('creance-client-1')), isTrue);
    });
  });
}
