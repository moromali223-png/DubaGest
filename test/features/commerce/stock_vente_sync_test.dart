import 'package:drift/drift.dart';
import 'package:dubagest/core/database/app_database.dart';
import 'package:dubagest/core/sync/local/drift_sync_stores.dart';
import 'package:dubagest/core/sync/sync_models.dart';
import 'package:dubagest/features/commerce/data/commerce_local_data_source.dart';
import 'package:dubagest/features/commerce/data/commerce_repository_impl.dart';
import 'package:dubagest/features/commerce/domain/entities/commerce.dart';
import 'package:dubagest/features/commerce/domain/services/etat_commerce.dart';
import 'package:dubagest/features/commerce/domain/usecases/gerer_commerce.dart';
import 'package:dubagest/features/entreprise/domain/entities/contexte_session.dart';
import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/features/finances/domain/entities/finances.dart' show ModePaiement;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/contexte_fixtures.dart';
import '../../helpers/test_database.dart';

const boutiqueA = 'b-a';

void main() {
  group('Diagnostic Vente & Stock', () {
    late AppDatabase db;
    late CommerceLocalDataSource local;
    late DriftSyncQueueStore queue;
    late GererCommerce gerer;
    late ContexteSession admin;

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
      ]);
    });

    tearDown(() async {
      await db.close();
    });

    test('Scénario 1: Vente hors-ligne (sans sync)', () async {
      // 1. Créer un produit avec stock initial = 10
      final e1 = await local.charger(entrepriseId);
      final p = await gerer.creerProduit(
        admin,
        e1,
        Produit(
          id: 'prod1',
          entrepriseId: entrepriseId,
          nom: 'Savon',
          uniteBase: 'Pièce',
          prixDetail: 500,
        ),
        perimetreId: boutiqueA,
        stockInitial: Qte.depuis(10),
      );

      var e = await local.charger(entrepriseId);
      print('Stock après création: ${e.quantiteBoutique(p.id, boutiqueA).valeur}');
      expect(e.quantiteBoutique(p.id, boutiqueA), Qte.depuis(10));

      // 2. Vendre 3 pièces
      await gerer.vendre(
        admin,
        e,
        null,
        SaisieVente(
          perimetreId: boutiqueA,
          lignes: [
            LigneOperation(
              id: 'l1',
              produitId: p.id,
              unite: 'Pièce',
              facteur: Qte.un,
              quantite: Qte.depuis(3),
              prixUnitaire: 500,
            ),
          ],
          modePaiement: ModePaiement.especes,
        ),
      );

      e = await local.charger(entrepriseId);
      print('Stock après vente hors-ligne: ${e.quantiteBoutique(p.id, boutiqueA).valeur}');
      expect(e.quantiteBoutique(p.id, boutiqueA), Qte.depuis(7));
    });

    test('Scénario 2: Vente avec onPushApplied (simulation en ligne)', () async {
      // 1. Produit créé avec stock initial
      final e1 = await local.charger(entrepriseId);
      final p = await gerer.creerProduit(
        admin,
        e1,
        Produit(
          id: 'prod2',
          entrepriseId: entrepriseId,
          nom: 'Riz 50kg',
          uniteBase: 'Sac',
          prixDetail: 25000,
        ),
        perimetreId: boutiqueA,
        stockInitial: Qte.depuis(10),
      );

      // Simulation : le stock initial a été synchronisé avec le serveur
      // Sur le serveur, la table stocks a été créée avec 10 sacs
      await local.stocks.ecrireDepuisServeur({
        'id': 's2',
        'entreprise_id': entrepriseId,
        'perimetre_id': boutiqueA,
        'produit_id': p.id,
        'quantite': 10,
        'version': 1,
        'updated_at': DateTime.now().toIso8601String(),
        'deleted_at': null,
      }, RecordSyncStatus.synced);

      // Le mouvement initial est marqué synced
      final mvts = await local.charger(entrepriseId);
      for (final m in mvts.mouvements) {
        await (db.update(db.mouvementsStock)..where((t) => t.id.equals(m.id)))
            .write(const MouvementsStockCompanion(syncStatus: Value('SYNCED')));
      }

      var e = await local.charger(entrepriseId);
      print('Stock avant vente (synced): ${e.quantiteBoutique(p.id, boutiqueA).valeur}');
      expect(e.quantiteBoutique(p.id, boutiqueA), Qte.depuis(10));

      // 2. Vendre 2 sacs
      final vente = await gerer.vendre(
        admin,
        e,
        null,
        SaisieVente(
          perimetreId: boutiqueA,
          lignes: [
            LigneOperation(
              id: 'l2',
              produitId: p.id,
              unite: 'Sac',
              facteur: Qte.un,
              quantite: Qte.depuis(2),
              prixUnitaire: 25000,
            ),
          ],
          modePaiement: ModePaiement.especes,
        ),
      );

      e = await local.charger(entrepriseId);
      print('Stock immédiatement après vente: ${e.quantiteBoutique(p.id, boutiqueA).valeur}');
      expect(e.quantiteBoutique(p.id, boutiqueA), Qte.depuis(8));

      // 3. Le serveur valide la vente -> onPushApplied est appelé
      final handler = commerceSyncHandlers(local, DriftSyncCursorStore(db))
          .whereType<OperationSyncHandler>()
          .singleWhere((h) => h.table == 'ventes');

      final ops = await queue.due(userId, DateTime.now().add(const Duration(days: 1)));
      final op = ops.firstWhere((o) => o.entityTable == 'ventes' && o.recordId == vente.id);

      await handler.onPushApplied(op, {
        ...op.payload,
        'id': vente.id,
        'statut': 'VALIDEE',
        'version': 1,
        'updated_at': DateTime.now().toIso8601String(),
      });

      e = await local.charger(entrepriseId);
      print('>>> Stock après onPushApplied (AVANT que la table stocks ne soit pullée): ${e.quantiteBoutique(p.id, boutiqueA).valeur}');
      expect(e.quantiteBoutique(p.id, boutiqueA), Qte.depuis(8));
    });

    test('Scénario 3: Stream watch émet la diminution de stock lors d\'une vente', () async {
      print('[Test 3] Début');
      final e1 = await local.charger(entrepriseId);
      final p = await gerer.creerProduit(
        admin,
        e1,
        Produit(
          id: 'prod3',
          entrepriseId: entrepriseId,
          nom: 'Huile 1L',
          uniteBase: 'Bouteille',
          prixDetail: 1200,
        ),
        perimetreId: boutiqueA,
        stockInitial: Qte.depuis(15),
      );
      print('[Test 3] Produit créé');

      final etatsEmis = <EtatCommerce>[];
      final subscription = local.watch(entrepriseId).listen((etat) {
        print('[Test 3] Reçu émission: ${etat.quantiteBoutique(p.id, boutiqueA).valeur}');
        etatsEmis.add(etat);
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));
      print('[Test 3] Après delay initial, etatsEmis=${etatsEmis.length}');
      expect(etatsEmis.isNotEmpty, isTrue);
      expect(etatsEmis.last.quantiteBoutique(p.id, boutiqueA), Qte.depuis(15));

      print('[Test 3] Avant vendre');
      final etatCourant = etatsEmis.last;
      await gerer.vendre(
        admin,
        etatCourant,
        null,
        SaisieVente(
          perimetreId: boutiqueA,
          lignes: [
            LigneOperation(
              id: 'l3',
              produitId: p.id,
              unite: 'Bouteille',
              facteur: Qte.un,
              quantite: Qte.depuis(5),
              prixUnitaire: 1200,
            ),
          ],
          modePaiement: ModePaiement.especes,
        ),
      );
      print('[Test 3] Après vendre');

      await Future<void>.delayed(const Duration(milliseconds: 100));
      print('[Test 3] Après delay après vente, etatsEmis=${etatsEmis.length}, dernier=${etatsEmis.last.quantiteBoutique(p.id, boutiqueA).valeur}');
      expect(etatsEmis.last.quantiteBoutique(p.id, boutiqueA), Qte.depuis(10));

      await subscription.cancel();
      print('[Test 3] Fin');
    });

    test('Scénario 4: Rejet serveur (ex: erreur de droits ou validation) n\'annule pas la sortie physique', () async {
      // 1. Produit avec stock = 20
      final e1 = await local.charger(entrepriseId);
      final p = await gerer.creerProduit(
        admin,
        e1,
        Produit(
          id: 'prod4',
          entrepriseId: entrepriseId,
          nom: 'Ciment 50kg',
          uniteBase: 'Sac',
          prixDetail: 5000,
        ),
        perimetreId: boutiqueA,
        stockInitial: Qte.depuis(20),
      );

      // 2. Vendre 4 sacs
      var e = await local.charger(entrepriseId);
      final vente = await gerer.vendre(
        admin,
        e,
        null,
        SaisieVente(
          perimetreId: boutiqueA,
          lignes: [
            LigneOperation(
              id: 'l4',
              produitId: p.id,
              unite: 'Sac',
              facteur: Qte.un,
              quantite: Qte.depuis(4),
              prixUnitaire: 5000,
            ),
          ],
          modePaiement: ModePaiement.especes,
        ),
      );

      e = await local.charger(entrepriseId);
      expect(e.quantiteBoutique(p.id, boutiqueA), Qte.depuis(16));

      // 3. Simuler rejet du serveur (onRejected)
      final handler = commerceSyncHandlers(local, DriftSyncCursorStore(db))
          .whereType<OperationSyncHandler>()
          .singleWhere((h) => h.table == 'ventes');
      final ops = await queue.due(userId, DateTime.now().add(const Duration(days: 1)));
      final op = ops.firstWhere((o) => o.entityTable == 'ventes' && o.recordId == vente.id);

      await handler.onRejected(op, const Failure(FailureKind.forbidden));

      // Vérification : le stock reste à 16, la vente n'a pas été effacée magiquement des rayons
      e = await local.charger(entrepriseId);
      expect(e.quantiteBoutique(p.id, boutiqueA), Qte.depuis(16));
    });

    test('Scénario 5: Déduplication des lignes de stock serveur et _appliquerDeltaStock', () async {
      final e1 = await local.charger(entrepriseId);
      final p = await gerer.creerProduit(
        admin,
        e1,
        Produit(
          id: 'prod5',
          entrepriseId: entrepriseId,
          nom: 'Sucre 1kg',
          uniteBase: 'Kg',
          prixDetail: 800,
        ),
        perimetreId: boutiqueA,
        stockInitial: Qte.depuis(50),
      );

      // Simulation d'une écriture locale via _appliquerDeltaStock
      final mvt = await (db.select(db.mouvementsStock)..where((t) => t.produitId.equals(p.id))).getSingle();
      await local.appliquerMouvementAuStock(mvt.id);
      await (db.update(db.mouvementsStock)..where((t) => t.id.equals(mvt.id)))
          .write(const MouvementsStockCompanion(syncStatus: Value('SYNCED')));

      // Simulation de la descente serveur avec son propre UUID
      await local.stocks.ecrireDepuisServeur({
        'id': 'uuid-serveur-officiel',
        'entreprise_id': entrepriseId,
        'perimetre_id': boutiqueA,
        'produit_id': p.id,
        'quantite': 50,
        'version': 1,
        'updated_at': DateTime.now().toIso8601String(),
        'deleted_at': null,
      }, RecordSyncStatus.synced);

      // Vérification qu'il n'y a pas de doublon dans _db.stocks
      final rows = await (db.select(db.stocks)
            ..where((t) => t.produitId.equals(p.id) & t.perimetreId.equals(boutiqueA) & t.deletedAt.isNull()))
          .get();
      expect(rows.length, 1);
      expect(rows.first.id, 'uuid-serveur-officiel');

      // Vente et nouvelle application de delta sans erreur StateError
      var e = await local.charger(entrepriseId);
      final vente = await gerer.vendre(
        admin,
        e,
        null,
        SaisieVente(
          perimetreId: boutiqueA,
          lignes: [
            LigneOperation(
              id: 'l5',
              produitId: p.id,
              unite: 'Kg',
              facteur: Qte.un,
              quantite: Qte.depuis(10),
              prixUnitaire: 800,
            ),
          ],
          modePaiement: ModePaiement.especes,
        ),
      );

      final handler = commerceSyncHandlers(local, DriftSyncCursorStore(db))
          .whereType<OperationSyncHandler>()
          .singleWhere((h) => h.table == 'ventes');
      final ops = await queue.due(userId, DateTime.now().add(const Duration(days: 1)));
      final op = ops.firstWhere((o) => o.entityTable == 'ventes' && o.recordId == vente.id);

      // Ne doit pas lancer d'exception StateError: Bad state: Too many elements
      await handler.onPushApplied(op, {
        ...op.payload,
        'id': vente.id,
        'statut': 'VALIDEE',
        'version': 1,
        'updated_at': DateTime.now().toIso8601String(),
      });

      e = await local.charger(entrepriseId);
      expect(e.quantiteBoutique(p.id, boutiqueA), Qte.depuis(40));
    });
  });
}

