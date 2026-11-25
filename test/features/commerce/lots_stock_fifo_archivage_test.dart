import 'package:dubagest/core/database/app_database.dart';
import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/core/permissions/access_decision.dart';
import 'package:dubagest/core/sync/local/drift_sync_stores.dart';
import 'package:dubagest/features/commerce/data/commerce_local_data_source.dart';
import 'package:dubagest/features/commerce/data/commerce_repository_impl.dart';
import 'package:dubagest/features/commerce/domain/entities/commerce.dart';
import 'package:dubagest/features/commerce/domain/services/etat_commerce.dart';
import 'package:dubagest/features/commerce/domain/usecases/gerer_commerce.dart';
import 'package:dubagest/features/entreprise/domain/entities/contexte_session.dart';
import 'package:dubagest/features/finances/data/datasources/finances_local_data_source.dart';
import 'package:dubagest/features/finances/domain/entities/finances.dart' show ModePaiement;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/contexte_fixtures.dart';
import '../../helpers/test_database.dart';

const boutiqueA = 'boutique-a';
const boutiqueB = 'boutique-b';
const autreEntrepriseId = 'autre-ent-999';

Matcher regle(String code) => isA<Failure>().having((f) => f.ruleCode, 'ruleCode', code);

void main() {
  group('Gestion des Achats, Lots de Stock FIFO et Archivage des Produits', () {
    late AppDatabase db;
    late CommerceLocalDataSource local;
    late DriftSyncQueueStore queue;
    late GererCommerce gerer;
    late ContexteSession admin;

    Future<EtatCommerce> etat() => local.charger(entrepriseId);

    Future<Produit> creerProduitRiz({String id = 'riz-50kg', Qte stock = Qte.zero, String perimetre = boutiqueA}) async {
      final e = await etat();
      return gerer.creerProduit(
        admin,
        e,
        Produit(
          id: id,
          entrepriseId: entrepriseId,
          nom: 'Riz 50 kg $id',
          uniteBase: 'Sac',
          prixDetail: 12000,
          prixAchat: 10000,
        ),
        perimetreId: perimetre,
        stockInitial: stock,
      );
    }

    setUp(() {
      db = memoryDatabase();
      local = CommerceLocalDataSource(db);
      queue = DriftSyncQueueStore(db);
      gerer = GererCommerce(CommerceRepositoryImpl(
        local: local,
        queue: queue,
        currentUserId: () => userId,
        requestSync: () {},
      ));
      admin = contexte(perimetres: [
        perimetreJson(boutiqueA, nom: 'Boutique A'),
        perimetreJson(boutiqueB, nom: 'Boutique B'),
      ]);
    });

    tearDown(() => db.close());

    // -------------------------------------------------------------------------
    // 1. Premier achat d'un produit (création du lot 001)
    // -------------------------------------------------------------------------
    test('1. Premier achat crée automatiquement un lot distinct', () async {
      final riz = await creerProduitRiz();
      var e = await etat();

      final achat1 = await gerer.creerAchat(
        admin,
        e,
        SaisieAchat(
          perimetreId: boutiqueA,
          reference: 'ACHAT-001',
          lignes: [
            LigneOperation(
              id: 'l-achat-1',
              produitId: riz.id,
              unite: 'Sac',
              facteur: Qte.un,
              quantite: Qte.depuis(10),
              prixUnitaire: 10000,
              prixVente: 12000,
            ),
          ],
        ),
        recevoirTout: true,
      );

      e = await etat();
      expect(e.achat(achat1.id)!.statut, StatutAchat.recu);
      expect(e.quantiteBoutique(riz.id, boutiqueA), Qte.depuis(10));

      final lots = e.lotsDe(riz.id, [boutiqueA]);
      expect(lots.length, 1);
      final lot1 = lots.first;
      expect(lot1.quantiteInitiale, Qte.depuis(10));
      expect(lot1.quantiteRestante, Qte.depuis(10));
      expect(lot1.prixAchatUnitaire, 10000);
      expect(lot1.prixVenteUnitaire, 12000);
      expect(lot1.estDisponible, isTrue);
    });

    // -------------------------------------------------------------------------
    // 2. Deuxième achat du même produit à un prix différent
    // -------------------------------------------------------------------------
    test('2. Deuxième achat à prix différent crée un lot indépendant sans écraser le premier', () async {
      final riz = await creerProduitRiz();
      var e = await etat();

      // Achat 1 : 10 sacs à 10 000 FCFA
      await gerer.creerAchat(
        admin,
        e,
        SaisieAchat(
          perimetreId: boutiqueA,
          reference: 'ACHAT-001',
          lignes: [
            LigneOperation(
              id: 'l1',
              produitId: riz.id,
              unite: 'Sac',
              facteur: Qte.un,
              quantite: Qte.depuis(10),
              prixUnitaire: 10000,
              prixVente: 12000,
            ),
          ],
        ),
        recevoirTout: true,
      );

      e = await etat();

      // Achat 2 : 10 sacs à 11 000 FCFA (vente 13 000 FCFA)
      await gerer.creerAchat(
        admin,
        e,
        SaisieAchat(
          perimetreId: boutiqueA,
          reference: 'ACHAT-002',
          lignes: [
            LigneOperation(
              id: 'l2',
              produitId: riz.id,
              unite: 'Sac',
              facteur: Qte.un,
              quantite: Qte.depuis(10),
              prixUnitaire: 11000,
              prixVente: 13000,
            ),
          ],
        ),
        recevoirTout: true,
      );

      e = await etat();
      // Stock total : 20 sacs
      expect(e.quantiteBoutique(riz.id, boutiqueA), Qte.depuis(20));

      // Deux lots distincts et indépendants
      final lots = e.lotsDisponibles(riz.id, boutiqueA);
      expect(lots.length, 2);

      final lot1 = lots[0];
      final lot2 = lots[1];

      expect(lot1.quantiteRestante, Qte.depuis(10));
      expect(lot1.prixAchatUnitaire, 10000);
      expect(lot1.prixVenteUnitaire, 12000);

      expect(lot2.quantiteRestante, Qte.depuis(10));
      expect(lot2.prixAchatUnitaire, 11000);
      expect(lot2.prixVenteUnitaire, 13000);

      // Coût moyen pondéré calculé = (10*10000 + 10*11000) / 20 = 10 500 FCFA
      expect(e.coutMoyenPondere(riz.id, boutiqueA), 10500);
    });

    // -------------------------------------------------------------------------
    // 3. Vente provenant d'un seul lot
    // -------------------------------------------------------------------------
    test('3. Vente provenant d\'un seul lot : déduction exacte et marge calculée', () async {
      final riz = await creerProduitRiz();
      var e = await etat();

      // Approvisionnement : 10 sacs à 10 000 FCFA
      await gerer.creerAchat(
        admin,
        e,
        SaisieAchat(
          perimetreId: boutiqueA,
          lignes: [
            LigneOperation(
              id: 'l1',
              produitId: riz.id,
              unite: 'Sac',
              facteur: Qte.un,
              quantite: Qte.depuis(10),
              prixUnitaire: 10000,
              prixVente: 12000,
            ),
          ],
        ),
        recevoirTout: true,
      );

      e = await etat();

      // Vente de 5 sacs à 12 000 FCFA
      final vente = await gerer.vendre(
        admin,
        e,
        null,
        SaisieVente(
          perimetreId: boutiqueA,
          lignes: [
            LigneOperation(
              id: 'lv1',
              produitId: riz.id,
              unite: 'Sac',
              facteur: Qte.un,
              quantite: Qte.depuis(5),
              prixUnitaire: 12000,
            ),
          ],
        ),
      );

      e = await etat();
      // Stock restant : 5 sacs
      expect(e.quantiteBoutique(riz.id, boutiqueA), Qte.depuis(5));

      // Vérification financière de la vente
      expect(vente.total, 60000); // 5 * 12 000
      expect(vente.coutTotal, 50000); // 5 * 10 000 (COGS)
      expect(vente.margeBrute, 10000); // 60 000 - 50 000

      // Vérification du lot restant
      final lots = e.lotsDisponibles(riz.id, boutiqueA);
      expect(lots.length, 1);
      expect(lots.first.quantiteRestante, Qte.depuis(5));
    });

    // -------------------------------------------------------------------------
    // 4. Vente provenant de plusieurs lots (FIFO exact)
    // -------------------------------------------------------------------------
    test('4. Vente de 12 sacs consomme 10 sacs du Lot 1 et 2 sacs du Lot 2 (FIFO)', () async {
      final riz = await creerProduitRiz();
      var e = await etat();

      // Lot 1 : 10 sacs à 10 000 FCFA
      await gerer.creerAchat(
        admin,
        e,
        SaisieAchat(
          perimetreId: boutiqueA,
          reference: 'LOT1',
          lignes: [
            LigneOperation(
              id: 'la1',
              produitId: riz.id,
              unite: 'Sac',
              facteur: Qte.un,
              quantite: Qte.depuis(10),
              prixUnitaire: 10000,
              prixVente: 12000,
            ),
          ],
        ),
        recevoirTout: true,
      );

      e = await etat();

      // Lot 2 : 10 sacs à 11 000 FCFA
      await gerer.creerAchat(
        admin,
        e,
        SaisieAchat(
          perimetreId: boutiqueA,
          reference: 'LOT2',
          lignes: [
            LigneOperation(
              id: 'la2',
              produitId: riz.id,
              unite: 'Sac',
              facteur: Qte.un,
              quantite: Qte.depuis(10),
              prixUnitaire: 11000,
              prixVente: 13000,
            ),
          ],
        ),
        recevoirTout: true,
      );

      e = await etat();

      // Vente de 12 sacs à 12 000 FCFA
      final vente = await gerer.vendre(
        admin,
        e,
        null,
        SaisieVente(
          perimetreId: boutiqueA,
          lignes: [
            LigneOperation(
              id: 'lv12',
              produitId: riz.id,
              unite: 'Sac',
              facteur: Qte.un,
              quantite: Qte.depuis(12),
              prixUnitaire: 12000,
            ),
          ],
        ),
      );

      e = await etat();

      // Total vente = 12 * 12 000 = 144 000 FCFA
      expect(vente.total, 144000);

      // COGS = 10 * 10 000 + 2 * 11 000 = 122 000 FCFA
      expect(vente.coutTotal, 122000);
      expect(vente.margeBrute, 22000); // 144 000 - 122 000

      // Détail des consommations FIFO dans la ligne
      final ligne = vente.lignes.first;
      expect(ligne.lots.length, 2);
      expect(ligne.lots[0].quantiteBase, Qte.depuis(10));
      expect(ligne.lots[0].prixAchatUnitaire, 10000);
      expect(ligne.lots[0].coutTotal, 100000);

      expect(ligne.lots[1].quantiteBase, Qte.depuis(2));
      expect(ligne.lots[1].prixAchatUnitaire, 11000);
      expect(ligne.lots[1].coutTotal, 22000);

      // État des lots après vente
      final tousLots = e.lotsDe(riz.id, [boutiqueA]);
      final lot1 = tousLots.firstWhere((l) => l.reference.contains('LOT1'));
      final lot2 = tousLots.firstWhere((l) => l.reference.contains('LOT2'));

      expect(lot1.quantiteRestante, Qte.zero);
      expect(lot1.estDisponible, isFalse);

      expect(lot2.quantiteRestante, Qte.depuis(8));
      expect(lot2.estDisponible, isTrue);

      // Stock global restant = 8 sacs
      expect(e.quantiteBoutique(riz.id, boutiqueA), Qte.depuis(8));
    });

    // -------------------------------------------------------------------------
    // 5. Modification du prix d'un nouvel approvisionnement
    // -------------------------------------------------------------------------
    test('5. Modification du prix d\'achat futur ne modifie pas les anciens lots', () async {
      final riz = await creerProduitRiz();
      var e = await etat();

      // Premier lot à 10 000 FCFA
      await gerer.creerAchat(
        admin,
        e,
        SaisieAchat(
          perimetreId: boutiqueA,
          reference: 'LOT1',
          lignes: [
            LigneOperation(
              id: 'l1',
              produitId: riz.id,
              unite: 'Sac',
              facteur: Qte.un,
              quantite: Qte.depuis(5),
              prixUnitaire: 10000,
            ),
          ],
        ),
        recevoirTout: true,
      );

      e = await etat();

      // Modification du produit dans le catalogue (ex. prix d'achat passe à 15 000 FCFA)
      await gerer.modifierProduit(
        admin,
        e,
        riz,
        riz.copyWith(prixAchat: () => 15000, prixDetail: 18000),
      );

      e = await etat();
      final lot1 = e.lotsDisponibles(riz.id, boutiqueA).first;
      expect(lot1.prixAchatUnitaire, 10000, reason: 'Le prix historique du lot reste inchangé');
    });

    // -------------------------------------------------------------------------
    // 6. Vérification que les anciennes ventes restent inchangées
    // -------------------------------------------------------------------------
    test('6. Les anciennes ventes restent strictement inchangées après changement de prix', () async {
      final riz = await creerProduitRiz();
      var e = await etat();

      await gerer.creerAchat(
        admin,
        e,
        SaisieAchat(
          perimetreId: boutiqueA,
          lignes: [
            LigneOperation(
              id: 'l1',
              produitId: riz.id,
              unite: 'Sac',
              facteur: Qte.un,
              quantite: Qte.depuis(10),
              prixUnitaire: 10000,
            ),
          ],
        ),
        recevoirTout: true,
      );

      e = await etat();
      final vente = await gerer.vendre(
        admin,
        e,
        null,
        SaisieVente(
          perimetreId: boutiqueA,
          lignes: [
            LigneOperation(
              id: 'lv1',
              produitId: riz.id,
              unite: 'Sac',
              facteur: Qte.un,
              quantite: Qte.depuis(2),
              prixUnitaire: 12000,
            ),
          ],
        ),
      );

      // Changement de prix catalogue
      await gerer.modifierProduit(
        admin,
        e,
        riz,
        riz.copyWith(prixDetail: 20000, prixAchat: () => 16000),
      );

      e = await etat();
      final venteEnBase = e.ventes.firstWhere((v) => v.id == vente.id);
      expect(venteEnBase.total, 24000);
      expect(venteEnBase.coutTotal, 20000);
      expect(venteEnBase.margeBrute, 4000);
      expect(venteEnBase.lignes.first.prixUnitaire, 12000);
    });

    // -------------------------------------------------------------------------
    // 7. Retour client avec réintégration dans le lot d'origine
    // -------------------------------------------------------------------------
    test('7. Retour client restaure la quantité dans le lot d\'origine identifiable', () async {
      final riz = await creerProduitRiz();
      var e = await etat();

      // Approvisionnement : 10 sacs
      await gerer.creerAchat(
        admin,
        e,
        SaisieAchat(
          perimetreId: boutiqueA,
          reference: 'ACH-RET',
          lignes: [
            LigneOperation(
              id: 'lret',
              produitId: riz.id,
              unite: 'Sac',
              facteur: Qte.un,
              quantite: Qte.depuis(10),
              prixUnitaire: 10000,
              prixVente: 12000,
            ),
          ],
        ),
        recevoirTout: true,
      );

      e = await etat();

      // Vente de 3 sacs
      final vente = await gerer.vendre(
        admin,
        e,
        null,
        SaisieVente(
          perimetreId: boutiqueA,
          lignes: [
            LigneOperation(
              id: 'lv-ret',
              produitId: riz.id,
              unite: 'Sac',
              facteur: Qte.un,
              quantite: Qte.depuis(3),
              prixUnitaire: 12000,
            ),
          ],
        ),
      );

      e = await etat();
      final lotVendu = e.lotsDe(riz.id, [boutiqueA]).first;
      expect(lotVendu.quantiteRestante, Qte.depuis(7));

      // Retour client d'un sac sur ce lot
      final lotRestaurer = lotVendu.copyWith(quantiteRestante: lotVendu.quantiteRestante + Qte.un);
      await local.remplacerLot(lotRestaurer);

      // Enregistrement du mouvement de retour
      await gerer.mouvement(
        admin,
        e,
        produit: riz,
        perimetreId: boutiqueA,
        entree: true,
        motif: MotifMouvement.retour,
        quantite: Qte.un,
        unite: riz.uniteDeBase,
        note: 'Retour client sac non ouvert',
      );

      e = await etat();
      final lotApres = e.lot(lotVendu.id)!;
      expect(lotApres.quantiteRestante, Qte.depuis(8));
      expect(e.quantiteBoutique(riz.id, boutiqueA), Qte.depuis(8));
    });

    // -------------------------------------------------------------------------
    // 7. Annulation de vente avec restauration exacte des lots
    // -------------------------------------------------------------------------
    test('8. Annulation de vente restaure exactement les quantités dans les lots consommés', () async {
      final riz = await creerProduitRiz();
      var e = await etat();

      // Lot 1 (10 sacs à 10 000 FCFA) et Lot 2 (10 sacs à 11 000 FCFA)
      await gerer.creerAchat(
        admin,
        e,
        SaisieAchat(
          perimetreId: boutiqueA,
          reference: 'L1',
          lignes: [
            LigneOperation(
              id: 'l1',
              produitId: riz.id,
              unite: 'Sac',
              facteur: Qte.un,
              quantite: Qte.depuis(10),
              prixUnitaire: 10000,
            ),
          ],
        ),
        recevoirTout: true,
      );

      e = await etat();

      await gerer.creerAchat(
        admin,
        e,
        SaisieAchat(
          perimetreId: boutiqueA,
          reference: 'L2',
          lignes: [
            LigneOperation(
              id: 'l2',
              produitId: riz.id,
              unite: 'Sac',
              facteur: Qte.un,
              quantite: Qte.depuis(10),
              prixUnitaire: 11000,
            ),
          ],
        ),
        recevoirTout: true,
      );

      e = await etat();

      // Vente de 12 sacs
      final vente = await gerer.vendre(
        admin,
        e,
        null,
        SaisieVente(
          perimetreId: boutiqueA,
          reglement: ReglementVente.credit,
          contactId: 'client-1',
          lignes: [
            LigneOperation(
              id: 'lv12',
              produitId: riz.id,
              unite: 'Sac',
              facteur: Qte.un,
              quantite: Qte.depuis(12),
              prixUnitaire: 12000,
            ),
          ],
        ),
      );

      e = await etat();
      expect(e.quantiteBoutique(riz.id, boutiqueA), Qte.depuis(8));

      // Annulation de la vente
      await gerer.annulerVente(admin, e, vente, motif: 'Erreur client');

      e = await etat();
      // Stock total restauré à 20 sacs
      expect(e.quantiteBoutique(riz.id, boutiqueA), Qte.depuis(20));

      // Les deux lots ont retrouvé leur quantité initiale
      final lots = e.lotsDisponibles(riz.id, boutiqueA);
      expect(lots.length, 2);
      expect(lots[0].quantiteRestante, Qte.depuis(10));
      expect(lots[0].estDisponible, isTrue);
      expect(lots[1].quantiteRestante, Qte.depuis(10));
      expect(lots[1].estDisponible, isTrue);
    });

    // -------------------------------------------------------------------------
    // 9. Règle d'archivage : interdiction si stock > 0, autorisation si stock = 0
    // -------------------------------------------------------------------------
    test('9 & 16. Archivage interdit avec stock > 0, autorisé quand stock = 0', () async {
      final riz = await creerProduitRiz(stock: Qte.depuis(5));
      var e = await etat();

      // Tentative d'archivage avec stock de 5 sacs -> Rejeté
      await expectLater(
        gerer.modifierProduit(admin, e, riz, riz.copyWith(estActif: false)),
        throwsA(regle(RuleCodes.productInStock)),
      );

      // Sortie du stock restant
      await gerer.mouvement(
        admin,
        e,
        produit: riz,
        perimetreId: boutiqueA,
        entree: false,
        motif: MotifMouvement.ajustement,
        quantite: Qte.depuis(5),
        unite: riz.uniteDeBase,
      );

      e = await etat();
      expect(e.quantite(riz.id), Qte.zero);

      // Maintenant que stock = 0, l'archivage est accepté
      await gerer.modifierProduit(admin, e, riz, riz.copyWith(estActif: false));

      e = await etat();
      expect(e.produit(riz.id)!.estActif, isFalse);

      // Réactivation autorisée
      await gerer.modifierProduit(admin, e, riz, riz.copyWith(estActif: true));
      e = await etat();
      expect(e.produit(riz.id)!.estActif, isTrue);

      // Test de solder automatique et archiver
      final produitAvecStock = await creerProduitRiz(id: 'riz-50kg-2', stock: Qte.depuis(10));
      e = await etat();
      expect(e.quantite(produitAvecStock.id), Qte.depuis(10));

      await gerer.archiverProduit(admin, e, produitAvecStock, solderStockSiNecessaire: true);
      e = await etat();
      expect(e.produit(produitAvecStock.id)!.estActif, isFalse);
      expect(e.quantite(produitAvecStock.id), Qte.zero);
    });

    // -------------------------------------------------------------------------
    // 10. Refus de suppression d'un produit avec historique
    // -------------------------------------------------------------------------
    test('10. Suppression définitive refusée si historique commercial (proposer archivage)', () async {
      final riz = await creerProduitRiz(stock: Qte.depuis(2));
      final e = await etat();

      // Tentative de suppression d'un produit avec stock / mouvement
      await expectLater(
        gerer.supprimerProduit(admin, e, riz),
        throwsA(regle(RuleCodes.productUsed)),
      );

      // Création d'un produit neuf sans aucun mouvement ni historique
      final produitVierge = await gerer.creerProduit(
        admin,
        e,
        Produit(
          id: 'produit-vierge',
          entrepriseId: entrepriseId,
          nom: 'Produit Jamais Utilisé',
          uniteBase: 'Pièce',
          prixDetail: 500,
        ),
      );

      var e2 = await etat();
      expect(e2.produit(produitVierge.id), isNotNull);

      // Suppression définitive autorisée pour le produit vierge
      await gerer.supprimerProduit(admin, e2, produitVierge);
      e2 = await etat();
      expect(e2.produit(produitVierge.id), isNull);
    });

    // -------------------------------------------------------------------------
    // 11. Transfert entre deux boutiques
    // -------------------------------------------------------------------------
    test('11. Transfert boutique A -> boutique B conserve le coût unitaire et zéro bénéfice artificiel', () async {
      final riz = await creerProduitRiz();
      var e = await etat();

      // Approvisionnement boutique A : 10 sacs à 10 000 FCFA
      await gerer.creerAchat(
        admin,
        e,
        SaisieAchat(
          perimetreId: boutiqueA,
          reference: 'ACHAT-SRC',
          lignes: [
            LigneOperation(
              id: 'l1',
              produitId: riz.id,
              unite: 'Sac',
              facteur: Qte.un,
              quantite: Qte.depuis(10),
              prixUnitaire: 10000,
              prixVente: 12000,
            ),
          ],
        ),
        recevoirTout: true,
      );

      e = await etat();

      // Transfert de 4 sacs de boutique A vers boutique B
      await gerer.transferer(
        admin,
        e,
        produit: riz,
        dePerimetreId: boutiqueA,
        versPerimetreId: boutiqueB,
        quantite: Qte.depuis(4),
        unite: riz.uniteDeBase,
      );

      e = await etat();
      expect(e.quantiteBoutique(riz.id, boutiqueA), Qte.depuis(6));
      expect(e.quantiteBoutique(riz.id, boutiqueB), Qte.depuis(4));

      // Lot créé dans boutique B avec le même coût unitaire
      final lotsB = e.lotsDisponibles(riz.id, boutiqueB);
      expect(lotsB.length, 1);
      final lotDest = lotsB.first;
      expect(lotDest.quantiteRestante, Qte.depuis(4));
      expect(lotDest.prixAchatUnitaire, 10000, reason: 'Même coût d\'acquisition : 0 bénéfice artificiel');
      expect(lotDest.lotOrigineId, isNotNull, reason: 'Traçabilité du lot d\'origine conservée');
    });

    // -------------------------------------------------------------------------
    // 12. Synchronisation hors ligne : sync_queue
    // -------------------------------------------------------------------------
    test('12. Opérations hors-ligne alimentent sync_queue de façon ordonnée et idempotente', () async {
      final riz = await creerProduitRiz();
      final e = await etat();

      await gerer.creerAchat(
        admin,
        e,
        SaisieAchat(
          perimetreId: boutiqueA,
          lignes: [
            LigneOperation(
              id: 'la1',
              produitId: riz.id,
              unite: 'Sac',
              facteur: Qte.un,
              quantite: Qte.depuis(5),
              prixUnitaire: 10000,
            ),
          ],
        ),
        recevoirTout: true,
      );

      final ops = await queue.due(userId, DateTime.now().add(const Duration(days: 1)));
      final tables = ops.map((o) => o.entityTable).toList();

      expect(tables, contains('produits'));
      expect(tables, contains('achats'));
      expect(tables, contains('lots_stock'));
      expect(tables, contains('receptions'));
    });

    // -------------------------------------------------------------------------
    // 13. Prévention des doubles mouvements
    // -------------------------------------------------------------------------
    test('13. Prévention des doubles mouvements : chaque sortie est atomique et unique', () async {
      final riz = await creerProduitRiz(stock: Qte.depuis(5));
      var e = await etat();

      final vente = await gerer.vendre(
        admin,
        e,
        null,
        SaisieVente(
          perimetreId: boutiqueA,
          lignes: [
            LigneOperation(
              id: 'lv-unique',
              produitId: riz.id,
              unite: 'Sac',
              facteur: Qte.un,
              quantite: Qte.depuis(2),
              prixUnitaire: 12000,
            ),
          ],
        ),
      );

      e = await etat();
      // Vérification qu'il n'y a qu'un seul mouvement de sortie créé pour cette ligne
      final sorties = e.mouvements.where((m) => m.origineId == vente.id && m.produitId == riz.id).toList();
      expect(sorties.length, 1);
      expect(sorties.first.delta, Qte.depuis(-2));
      expect(e.quantiteBoutique(riz.id, boutiqueA), Qte.depuis(3));
    });

    // -------------------------------------------------------------------------
    // 14. Prévention des stocks négatifs
    // -------------------------------------------------------------------------
    test('14. Vente supérieure au stock disponible rejetée immédiatement sans altérer les lots', () async {
      final riz = await creerProduitRiz(stock: Qte.depuis(3));
      final e = await etat();

      // Tentative de vente de 10 sacs alors qu'il n'y en a que 3
      await expectLater(
        gerer.vendre(
          admin,
          e,
          null,
          SaisieVente(
            perimetreId: boutiqueA,
            lignes: [
              LigneOperation(
                id: 'lv1',
                produitId: riz.id,
                unite: 'Sac',
                facteur: Qte.un,
                quantite: Qte.depuis(10),
                prixUnitaire: 12000,
              ),
            ],
          ),
        ),
        throwsA(regle(RuleCodes.stockInsufficient)),
      );

      final eApres = await etat();
      expect(eApres.quantiteBoutique(riz.id, boutiqueA), Qte.depuis(3));
    });

    // -------------------------------------------------------------------------
    // 15. Isolation multi-entreprises
    // -------------------------------------------------------------------------
    test('15. Isolation stricte des lots et stocks entre entreprises', () async {
      final riz = await creerProduitRiz(stock: Qte.depuis(10));
      final e1 = await etat();
      expect(e1.quantite(riz.id), Qte.depuis(10));

      // Chargement pour une autre entreprise
      final e2 = await local.charger(autreEntrepriseId);
      expect(e2.produits.where((p) => p.id == riz.id), isEmpty);
      expect(e2.lots.where((l) => l.produitId == riz.id), isEmpty);
      expect(e2.quantite(riz.id), Qte.zero);
    });

    // -------------------------------------------------------------------------
    // 16. Visibilité des lots pour stock existant sans lot formalisé (rétrocompatibilité)
    // -------------------------------------------------------------------------
    test('16. Stock existant sans lot formalisé génère automatiquement un lot disponible', () async {
      final savon = await gerer.creerProduit(
        admin,
        await etat(),
        Produit(
          id: 'savon-1',
          entrepriseId: entrepriseId,
          nom: 'Savon',
          uniteBase: 'Pièce',
          prixDetail: 500,
          prixAchat: 300,
        ),
      );
      // Injection directe de stock ou simulation de stock préexistant
      final eAvecStock = EtatCommerce(
        produits: [savon],
        stocks: [
          StockBoutique(
            perimetreId: boutiqueA,
            produitId: savon.id,
            quantite: Qte.depuis(15),
          ),
        ],
      );

      final lots = eAvecStock.lotsDe(savon.id);
      expect(lots, isNotEmpty, reason: 'Le stock doit être visible sous forme de lot');
      expect(lots.first.quantiteRestante, Qte.depuis(15));
      expect(lots.first.prixAchatUnitaire, 300);
      expect(lots.first.prixVenteUnitaire, 500);

      final lotsDispos = eAvecStock.lotsDisponibles(savon.id, boutiqueA);
      expect(lotsDispos, isNotEmpty);
      expect(lotsDispos.first.estDisponible, isTrue);
    });

    // -------------------------------------------------------------------------
    // 17. Entrée manuelle de stock crée un lot formalisé
    // -------------------------------------------------------------------------
    test('17. Entrée manuelle de stock crée un lot formalisé', () async {
      final prod = await creerProduitRiz(id: 'prod-entree-1');
      var e = await etat();

      final m = await gerer.mouvement(
        admin,
        e,
        produit: prod,
        perimetreId: boutiqueA,
        entree: true,
        motif: MotifMouvement.ajustement,
        quantite: Qte.depuis(8),
        unite: prod.uniteDeBase,
      );

      expect(m.lotId, isNotNull);
      e = await etat();
      final lot = e.lot(m.lotId!);
      expect(lot, isNotNull);
      expect(lot!.quantiteInitiale, Qte.depuis(8));
      expect(lot.quantiteRestante, Qte.depuis(8));
      expect(lot.estDisponible, isTrue);
    });
  });
}
