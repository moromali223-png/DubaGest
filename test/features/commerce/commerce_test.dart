import 'package:dubagest/core/database/app_database.dart';
import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/core/permissions/access_decision.dart';
import 'package:dubagest/core/sync/local/drift_sync_stores.dart';
import 'package:dubagest/core/sync/sync_models.dart';
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

const boutiqueA = 'b-a';
const boutiqueB = 'b-b';

Matcher regle(String code) => isA<Failure>().having((f) => f.ruleCode, 'ruleCode', code);

void main() {
  group('Qte : quantités exactes', () {
    test('lit les saisies du commerçant', () {
      expect(Qte.lire('12'), const Qte(120000));
      expect(Qte.lire('2,5'), const Qte(25000));
      expect(Qte.lire('2.5'), const Qte(25000));
      expect(Qte.lire('1/2'), const Qte(5000));
      expect(Qte.lire('2 1/4'), const Qte(22500));
      expect(Qte.lire('1 250'), const Qte(12500000));
      expect(Qte.lire('abc'), isNull);
      expect(Qte.lire('-3'), isNull);
    });

    test('aucune erreur d\'arrondi : 0,1 + 0,2 = 0,3', () {
      expect(Qte.lire('0,1')! + Qte.lire('0,2')!, Qte.lire('0,3'));
    });

    test('conversions entre unités', () {
      final carton = Qte.depuis(40);
      expect(Qte.depuis(3).fois(carton), Qte.depuis(120));
      expect(Qte.depuis(130).lotsEntiers(carton), 3);
      expect(Qte.depuis(120).divisePar(carton), Qte.depuis(3));
      expect(Qte.depuis(0.75).estMultipleDe(const Qte(2500)), isTrue);
      expect(Qte.depuis(0.3).estMultipleDe(const Qte(2500)), isFalse);
    });
  });

  group('CalculPrix : un seul prix saisi, les autres calculés', () {
    final cent = Qte.depuis(100);

    test('prix pièce → prix carton, et inversement', () {
      expect(CalculPrix.lot(1000, cent), 100000);
      expect(CalculPrix.base(95000, cent), 950);
    });

    test('un prix égal au calcul n\'est pas « fixé » ; un prix différent est conservé', () {
      expect(CalculPrix.aEnregistrer(100000, 1000, cent), isNull);
      expect(CalculPrix.aEnregistrer(95000, 1000, cent), 95000);
      expect(CalculPrix.ecartPourcent(95000, 100000), -5);
    });

    test('prix effectifs de chaque unité', () {
      final ampoule = Produit(
        id: 'p',
        entrepriseId: entrepriseId,
        nom: 'Ampoule',
        uniteBase: 'Pièce',
        prixDetail: 1000,
        prixAchat: 800,
        unites: [UniteProduit(id: 'c', nom: 'Carton', facteur: cent, prixDetail: 95000)],
      );
      final carton = ampoule.unite('c');
      expect(carton.prixDetail, 95000);
      expect(carton.prixDetailFixe, isTrue);
      expect(carton.prixAchat, 80000, reason: 'achat calculé : 800 × 100');
      expect(CalculPrix.benefice(carton.prixDetail, carton.prixAchat), 15000);
    });
  });

  group('Commerce sur l\'appareil (hors-ligne)', () {
    late AppDatabase db;
    late CommerceLocalDataSource local;
    late DriftSyncQueueStore queue;
    late GererCommerce gerer;
    late ContexteSession admin;

    Future<EtatCommerce> etat() => local.charger(entrepriseId);

    Future<Produit> carreaux({Qte stock = Qte.zero, String perimetre = boutiqueA}) async {
      final e = await etat();
      return gerer.creerProduit(
        admin,
        e,
        Produit(
          id: 'carreaux',
          entrepriseId: entrepriseId,
          nom: 'Carreaux 40×40',
          uniteBase: 'Pièce',
          prixDetail: 300,
          prixGros: 275,
          unites: [UniteProduit(id: 'carton', nom: 'Carton', facteur: Qte.depuis(40))],
          seuilAlerte: Qte.depuis(400),
        ),
        perimetreId: perimetre,
        stockInitial: stock,
        uniteStock: const UniteVente(id: 'carton', nom: 'Carton', facteur: Qte(400000), prixDetail: 0),
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

    test('créer un produit avec son stock de départ en cartons', () async {
      final p = await carreaux(stock: Qte.depuis(100));
      final e = await etat();
      expect(e.produit(p.id)!.nom, 'Carreaux 40×40');
      expect(e.quantiteBoutique(p.id, boutiqueA), Qte.depuis(4000), reason: '100 cartons × 40');
      expect(e.statutDans(p, [boutiqueA]), StatutStock.enStock);
      final ops = await queue.due(userId, DateTime.now().add(const Duration(days: 1)));
      expect(ops.map((o) => o.entityTable), ['produits', 'mouvements_stock'], reason: 'le produit part avant son stock');
    });

    test('sortie : stock négatif interdit, message clair', () async {
      final p = await carreaux(stock: Qte.depuis(5));
      final e = await etat();
      await expectLater(
        gerer.mouvement(admin, e,
            produit: p,
            perimetreId: boutiqueA,
            entree: false,
            motif: MotifMouvement.perte,
            quantite: Qte.depuis(6),
            unite: p.unite('carton')),
        throwsA(regle(RuleCodes.stockInsufficient)),
      );
      await gerer.mouvement(admin, e,
          produit: p,
          perimetreId: boutiqueA,
          entree: false,
          motif: MotifMouvement.casse,
          quantite: Qte.depuis(2),
          unite: p.unite('carton'));
      expect((await etat()).quantiteBoutique(p.id, boutiqueA), Qte.depuis(120));
    });

    test('vente fractionnée refusée pour un produit qui se compte à l\'unité', () async {
      final p = await carreaux(stock: Qte.depuis(1));
      await expectLater(
        gerer.mouvement(admin, await etat(),
            produit: p,
            perimetreId: boutiqueA,
            entree: false,
            motif: MotifMouvement.vente,
            quantite: Qte.depuis(0.5),
            unite: p.uniteDeBase),
        throwsA(regle(RuleCodes.fractionInvalid)),
      );
    });

    test('inventaire : l\'écart est calculé et tracé', () async {
      final p = await carreaux(stock: Qte.depuis(10));
      final m = await gerer.inventaire(admin, await etat(),
          produit: p,
          perimetreId: boutiqueA,
          compte: Qte.depuis(9),
          unite: p.unite('carton'),
          motif: MotifMouvement.casse);
      expect(m.delta, -Qte.depuis(40));
      expect((await etat()).quantiteBoutique(p.id, boutiqueA), Qte.depuis(360));
    });

    test('transfert : une opération, une sortie et une entrée liées', () async {
      final p = await carreaux(stock: Qte.depuis(10));
      final t = await gerer.transferer(admin, await etat(),
          produit: p,
          dePerimetreId: boutiqueA,
          versPerimetreId: boutiqueB,
          quantite: Qte.depuis(4),
          unite: p.unite('carton'));
      final e = await etat();
      expect(e.quantiteBoutique(p.id, boutiqueA), Qte.depuis(240));
      expect(e.quantiteBoutique(p.id, boutiqueB), Qte.depuis(160));
      expect(e.mouvements.where((m) => m.origineId == t.id).length, 2);
      final ops = await queue.due(userId, DateTime.now().add(const Duration(days: 1)));
      expect(ops.last.entityTable, 'transferts_stock', reason: 'un seul envoi pour le transfert');
    });

    test('superviseur limité à sa boutique : ni stock ni transfert ailleurs', () async {
      await carreaux(stock: Qte.depuis(10));
      final superviseur = contexte(
        role: 'SUPERVISEUR',
        permissions: {
          'perimetres.view', 'products.view', 'products.create', 'stock.view', 'stock.create', 'stock.update',
          'purchases.view', 'purchases.create', 'purchases.update', 'sales.view', 'sales.create',
          'payments.create', 'contacts.view',
        },
        perimetres: [perimetreJson(boutiqueA, nom: 'Boutique A')],
      );
      final e = await etat();
      final p = e.produit('carreaux')!;
      await expectLater(
        gerer.mouvement(superviseur, e,
            produit: p,
            perimetreId: boutiqueB,
            entree: true,
            motif: MotifMouvement.achat,
            quantite: Qte.un,
            unite: p.uniteDeBase),
        throwsA(regle(RuleCodes.perimetreDenied)),
      );
      await expectLater(
        gerer.transferer(superviseur, e,
            produit: p,
            dePerimetreId: boutiqueA,
            versPerimetreId: boutiqueB,
            quantite: Qte.un,
            unite: p.uniteDeBase),
        throwsA(regle(RuleCodes.perimetreDenied)),
      );
    });

    test('vendeur : peut vendre, pas créer de produit', () async {
      final vendeur = contexte(role: 'VENDEUR', perimetres: [perimetreJson(boutiqueA, nom: 'Boutique A')]);
      await expectLater(
        gerer.creerProduit(vendeur, await etat(),
            const Produit(id: 'x', entrepriseId: entrepriseId, nom: 'X', uniteBase: 'Pièce')),
        throwsA(regle(RuleCodes.permissionDenied)),
      );
    });

    test('achat, réception partielle puis complète', () async {
      final p = await carreaux();
      final achat = await gerer.creerAchat(
        admin,
        await etat(),
        SaisieAchat(perimetreId: boutiqueA, lignes: [
          LigneOperation(
              id: 'l1', produitId: p.id, unite: 'Carton', facteur: Qte.depuis(40), quantite: Qte.depuis(10), prixUnitaire: 11000),
        ]),
      );
      expect(achat.total, 110000);
      var e = await etat();
      expect(e.quantiteBoutique(p.id, boutiqueA), Qte.zero, reason: 'une commande ne change pas le stock');

      await expectLater(
        gerer.receptionner(admin, e, e.achat(achat.id)!, {'l1': Qte.depuis(11)}),
        throwsA(regle(RuleCodes.receptionAboveOrdered)),
      );
      await gerer.receptionner(admin, e, e.achat(achat.id)!, {'l1': Qte.depuis(6)});
      e = await etat();
      expect(e.quantiteBoutique(p.id, boutiqueA), Qte.depuis(240));
      expect(e.achat(achat.id)!.statut, StatutAchat.recuPartiel);

      await gerer.receptionner(admin, e, e.achat(achat.id)!, {'l1': Qte.depuis(4)});
      e = await etat();
      expect(e.achat(achat.id)!.statut, StatutAchat.recu);
      expect(e.quantiteBoutique(p.id, boutiqueA), Qte.depuis(400));
      final dette = await (db.select(db.engagements)..where((x) => x.id.equals(achat.id))).getSingle();
      expect((dette.sens, dette.origineType, dette.montantTotal), ('A_PAYER', 'ACHAT', 110000));
    });

    test('vente en gros payée : stock, somme due et paiement locaux', () async {
      final p = await carreaux(stock: Qte.depuis(10));
      final carton = p.unite('carton');
      final vente = await gerer.vendre(
        admin,
        await etat(),
        null,
        SaisieVente(
          perimetreId: boutiqueA,
          mode: ModeVente.gros,
          lignes: [
            LigneOperation(
                id: 'v1',
                produitId: p.id,
                unite: carton.nom,
                facteur: carton.facteur,
                quantite: Qte.depuis(2),
                prixUnitaire: carton.prix(ModeVente.gros)),
          ],
          modePaiement: ModePaiement.mobileMoney,
        ),
      );
      expect(vente.total, 22000, reason: '2 cartons × 40 × 275');
      final e = await etat();
      expect(e.quantiteBoutique(p.id, boutiqueA), Qte.depuis(320));
      final paiement = await (db.select(db.paiements)..where((x) => x.id.equals(vente.paiementId!))).getSingle();
      expect((paiement.sens, paiement.montant, paiement.syncStatus), ('ENTREE', 22000, 'PENDING_SYNC'));
      final ops = await queue.due(userId, DateTime.now().add(const Duration(days: 1)));
      final op = ops.singleWhere((o) => o.entityTable == 'ventes');
      expect(((op.payload['lignes'] as List).single as Map)['quantite'], 2);
    });

    test('vente : stock insuffisant refusé avant tout envoi', () async {
      final p = await carreaux(stock: Qte.depuis(1));
      await expectLater(
        gerer.vendre(admin, await etat(), null, SaisieVente(perimetreId: boutiqueA, lignes: [
          LigneOperation(id: 'v1', produitId: p.id, unite: 'Pièce', facteur: Qte.un, quantite: Qte.depuis(41), prixUnitaire: 300),
        ])),
        throwsA(regle(RuleCodes.stockInsufficient)),
      );
    });

    test('vente à crédit : client obligatoire', () async {
      final p = await carreaux(stock: Qte.depuis(1));
      await expectLater(
        gerer.vendre(admin, await etat(), null, SaisieVente(
          perimetreId: boutiqueA,
          reglement: ReglementVente.credit,
          lignes: [LigneOperation(id: 'v1', produitId: p.id, unite: 'Pièce', facteur: Qte.un, quantite: Qte.un, prixUnitaire: 300)],
        )),
        throwsA(regle(RuleCodes.customerRequired)),
      );
    });

    test('code-barres unique dans le catalogue', () async {
      await gerer.creerProduit(admin, await etat(),
          const Produit(id: 'eau', entrepriseId: entrepriseId, nom: 'Eau 1,5 L', uniteBase: 'Bouteille', codeBarres: '600123'));
      await expectLater(
        gerer.creerProduit(admin, await etat(),
            const Produit(id: 'eau2', entrepriseId: entrepriseId, nom: 'Eau', uniteBase: 'Bouteille', codeBarres: '600123')),
        throwsA(regle(RuleCodes.barcodeExists)),
      );
      expect((await etat()).parCodeBarres('600123')!.id, 'eau');
    });

    test('recherche tolérante : accents, mots partiels, catégorie', () async {
      final cat = await gerer.creerCategorie(admin, nom: 'Matériaux', icone: 'materiaux');
      await gerer.creerProduit(admin, await etat(),
          Produit(id: 'ciment', entrepriseId: entrepriseId, nom: 'Ciment 50 kg', uniteBase: 'Sac', categorieId: cat.id));
      final e = await etat();
      expect(e.rechercher('cimen').map((p) => p.id), ['ciment']);
      expect(e.rechercher('materiaux').map((p) => p.id), ['ciment']);
      expect(e.rechercher('', categorieId: cat.id).map((p) => p.id), ['ciment']);
    });

    test('après envoi d\'une vente, ses mouvements ne comptent plus deux fois', () async {
      final p = await carreaux(stock: Qte.depuis(10));
      final vente = await gerer.vendre(admin, await etat(), null, SaisieVente(perimetreId: boutiqueA, lignes: [
        LigneOperation(id: 'v1', produitId: p.id, unite: 'Pièce', facteur: Qte.un, quantite: Qte.depuis(4), prixUnitaire: 300),
      ]));
      final handler = commerceSyncHandlers(local, DriftSyncCursorStore(db))
          .whereType<OperationSyncHandler>()
          .singleWhere((h) => h.table == 'ventes');
      final op = (await queue.due(userId, DateTime.now().add(const Duration(days: 1))))
          .singleWhere((o) => o.entityTable == 'ventes');
      // Le serveur a appliqué la vente ; le stock serveur (400 − 4) arrive à la descente.
      await handler.onPushApplied(op, {
        ...op.payload,
        'id': vente.id,
        'total': vente.total,
        'statut': 'VALIDEE',
        'motif_annulation': null,
        'auteur_nom': null,
        'version': 1,
        'updated_at': '2026-10-07T10:00:00Z',
        'deleted_at': null,
      });
      await local.stocks.ecrireDepuisServeur({
        'id': 's1', 'entreprise_id': entrepriseId, 'perimetre_id': boutiqueA, 'produit_id': p.id,
        'quantite': 396, 'version': 2, 'updated_at': '2026-10-07T10:00:00Z', 'deleted_at': null,
      }, RecordSyncStatus.synced);
      // Le stock de départ (mouvement direct) est encore en attente : 396 + 400 serait faux.
      await local.mouvements.marquer(
          (await etat()).mouvements.singleWhere((m) => m.origineId == null).id, RecordSyncStatus.synced);
      expect((await etat()).quantiteBoutique(p.id, boutiqueA), Qte.depuis(396));
    });

    // --- Reçus : numérotation hors-ligne -------------------------------------

    Future<Vente> vendrePiece(Produit p, {SaisieVente? saisie}) async => gerer.vendre(
          admin,
          await etat(),
          null,
          saisie ??
              SaisieVente(perimetreId: boutiqueA, lignes: [
                LigneOperation(
                    id: 'l-${DateTime.now().microsecondsSinceEpoch}',
                    produitId: p.id,
                    unite: 'Pièce',
                    facteur: Qte.un,
                    quantite: Qte.un,
                    prixUnitaire: 300),
              ]),
        );

    test('reçu : hors ligne sans lettre de poste, la vente génère immédiatement un numéro commercial local propre', () async {
      final p = await carreaux(stock: Qte.depuis(10));
      final v = await vendrePiece(p);
      final compact = jourCommercial(DateTime.now()).replaceAll('-', '');
      expect(v.numero, 'REC-$compact-001');
      expect(v.dateCommerciale, jourCommercial(DateTime.now()));
      final op = (await queue.due(userId, DateTime.now().add(const Duration(days: 1))))
          .singleWhere((o) => o.entityTable == 'ventes');
      expect((op.payload['numero'], op.payload['date_commerciale']), ('REC-$compact-001', jourCommercial(DateTime.now())));
    });

    test('reçu : avec sa lettre, l\'appareil numérote seul, sans trou ni doublon', () async {
      final jour = jourCommercial(DateTime.now());
      await local.enregistrerPoste(
          entrepriseId: entrepriseId, perimetreId: boutiqueA, code: 'B', derniers: const {}, jour: jour);
      final p = await carreaux(stock: Qte.depuis(10));
      final v1 = await vendrePiece(p);
      final v2 = await vendrePiece(p);
      final compact = jour.replaceAll('-', '');
      expect([v1.numero, v2.numero], ['REC-$compact-B001', 'REC-$compact-B002']);
      expect((await etat()).vente(v2.id)!.numero, 'REC-$compact-B002', reason: 'numéro enregistré sur l\'appareil');
      final op = (await queue.due(userId, DateTime.now().add(const Duration(days: 1))))
          .lastWhere((o) => o.entityTable == 'ventes');
      expect((op.payload['poste'], op.payload['sequence']), ('B', 2));
    });

    test('reçu : le compteur repart à 1 chaque jour et ne recule jamais', () async {
      await local.enregistrerPoste(
          entrepriseId: entrepriseId, perimetreId: boutiqueA, code: 'A', derniers: const {}, jour: '2026-10-07');
      expect(await local.prochainNumero(entrepriseId, boutiqueA, '2026-10-07'), (poste: 'A', sequence: 1));
      expect(await local.prochainNumero(entrepriseId, boutiqueA, '2026-10-07'), (poste: 'A', sequence: 2));
      expect(await local.prochainNumero(entrepriseId, boutiqueA, '2026-10-08'), (poste: 'A', sequence: 1));
      // Appareil purgé puis reconnecté : le serveur connaît déjà le n° 9 du jour.
      await local.enregistrerPoste(
          entrepriseId: entrepriseId, perimetreId: boutiqueA, code: 'A', derniers: const {'2026-10-08': 9},
          jour: '2026-10-08');
      expect(await local.prochainNumero(entrepriseId, boutiqueA, '2026-10-08'), (poste: 'A', sequence: 10));
      // Le compteur local plus avancé que le serveur (ventes pas encore envoyées) est gardé.
      await local.enregistrerPoste(
          entrepriseId: entrepriseId, perimetreId: boutiqueA, code: 'A', derniers: const {'2026-10-08': 3},
          jour: '2026-10-08');
      expect(await local.prochainNumero(entrepriseId, boutiqueA, '2026-10-08'), (poste: 'A', sequence: 11));
      // Boutique sans poste assigné : démarre son compteur local à 1 indépendamment
      expect(await local.prochainNumero(entrepriseId, boutiqueB, '2026-10-08'), (poste: '', sequence: 1), reason: 'chaque boutique a son compteur indépendant');
    });

    test('reçu : vente à crédit avec acompte — payé, reste, paiement local', () async {
      final p = await carreaux(stock: Qte.depuis(10));
      final v = await vendrePiece(p,
          saisie: SaisieVente(
            perimetreId: boutiqueA,
            reglement: ReglementVente.credit,
            contactId: 'client-1',
            acompte: 500,
            lignes: [
              LigneOperation(id: 'lc', produitId: p.id, unite: 'Pièce', facteur: Qte.un, quantite: Qte.depuis(4),
                  prixUnitaire: 300),
            ],
          ));
      expect((v.total, v.montantPaye, v.resteInitial), (1200, 500, 700));
      final paiement = await (db.select(db.paiements)..where((x) => x.id.equals(v.paiementId!))).getSingle();
      expect(paiement.montant, 500);
      await expectLater(
        vendrePiece(p,
            saisie: SaisieVente(
              perimetreId: boutiqueA,
              reglement: ReglementVente.credit,
              contactId: 'client-1',
              acompte: 300,
              lignes: [
                LigneOperation(id: 'ld', produitId: p.id, unite: 'Pièce', facteur: Qte.un, quantite: Qte.un,
                    prixUnitaire: 300),
              ],
            )),
        throwsA(regle(RuleCodes.amountInvalid)),
        reason: 'acompte = total : ce n\'est pas un crédit',
      );
    });

    test('reçu : une vente annulée garde son numéro, la date et l\'auteur', () async {
      await local.enregistrerPoste(entrepriseId: entrepriseId, perimetreId: boutiqueA, code: 'A', derniers: const {},
          jour: jourCommercial(DateTime.now()));
      final p = await carreaux(stock: Qte.depuis(10));
      final v = await vendrePiece(p,
          saisie: SaisieVente(
            perimetreId: boutiqueA,
            reglement: ReglementVente.credit,
            contactId: 'client-1',
            lignes: [
              LigneOperation(id: 'le', produitId: p.id, unite: 'Pièce', facteur: Qte.un, quantite: Qte.un,
                  prixUnitaire: 300),
            ],
          ));
      await gerer.annulerVente(admin, await etat(), v, motif: 'Erreur');
      final annulee = (await etat()).vente(v.id)!;
      expect(annulee.annulee, isTrue);
      expect(annulee.numero, v.numero);
      expect(annulee.annuleeLe, isNotNull);
      expect(annulee.annuleeParNom, admin.nomComplet);
    });
  });

  test('FinancesLocalDataSource partage la base (copies locales visibles en Finances)', () async {
    final db = memoryDatabase();
    addTearDown(db.close);
    final finances = FinancesLocalDataSource(db);
    expect((await finances.charger(entrepriseId)).engagements, isEmpty);
  });
}
