@Tags(['integration'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:dubagest/core/database/app_database.dart';
import 'package:dubagest/core/sync/local/drift_sync_stores.dart';
import 'package:dubagest/core/sync/remote/supabase_sync_gateway.dart';
import 'package:dubagest/core/sync/sync_engine.dart';
import 'package:dubagest/features/commerce/data/commerce_local_data_source.dart';
import 'package:dubagest/features/commerce/data/commerce_repository_impl.dart';
import 'package:dubagest/features/commerce/data/photos_produits.dart';
import 'package:dubagest/features/commerce/domain/entities/commerce.dart';
import 'package:dubagest/features/commerce/domain/usecases/gerer_commerce.dart';
import 'package:dubagest/features/finances/data/datasources/finances_local_data_source.dart';
import 'package:dubagest/features/finances/data/repositories/finances_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/fake_sync_server.dart' show FakeConnectivity;
import '../helpers/test_database.dart';
import 'supabase_integration_test.dart' show alpha, connect, contexteDe;

/// Commerce contre Supabase Local : catalogue, stock, transfert, achat,
/// réception, vente et photos, saisis hors-ligne puis synchronisés.
const _centre = 'aaaaaaaa-0000-0000-0001-000000000001';
const _marche = 'aaaaaaaa-0000-0000-0001-000000000002';
const _fournisseur = 'aaaaaaaa-0000-0000-0003-000000000001';
const _creanceAmadou = 'aaaaaaaa-0000-0000-0005-000000000001';
bool _available = false;

/// Nettoyage par psql sur le port local (indépendant du client Docker).
Future<void> _nettoyer() => Process.run('psql', [
      '-h', '127.0.0.1', '-p', '54322', '-U', 'postgres', '-d', 'postgres',
      '-c', 'delete from public.ventes; delete from public.receptions; delete from public.achats; '
          'delete from public.transferts_stock; delete from public.mouvements_stock; delete from public.stocks; '
          'delete from public.produits; delete from public.categories_produits; '
          'delete from public.paiement_affectations; delete from public.paiements; '
          "delete from public.engagements where id <> '$_creanceAmadou';",
      '-c', "delete from storage.objects where bucket_id = 'fichiers' and name like '%/produits/%'",
    ], environment: {'PGPASSWORD': 'postgres'});

class _Appareil {
  _Appareil._(this.client, this.db, this.local, this.queue, this.engine, this.reseau, this.uid);

  final SupabaseClient client;
  final AppDatabase db;
  final CommerceLocalDataSource local;
  final DriftSyncQueueStore queue;
  final SyncEngine engine;
  final FakeConnectivity reseau;
  final String uid;

  late final repo =
      CommerceRepositoryImpl(local: local, queue: queue, currentUserId: () => uid, requestSync: () {});
  late final gerer = GererCommerce(repo);
  late final photos = PhotosProduits(db, () => client);

  static Future<_Appareil> connecter(String email) async {
    final client = await connect(email);
    final db = memoryDatabase();
    final queue = DriftSyncQueueStore(db);
    final local = CommerceLocalDataSource(db);
    final cursors = DriftSyncCursorStore(db);
    final reseau = FakeConnectivity();
    final engine = SyncEngine(
      queue: queue,
      remote: SupabaseSyncGateway(client),
      cursors: cursors,
      connectivity: reseau,
      handlers: [
        ...financesSyncHandlers(FinancesLocalDataSource(db), cursors),
        ...commerceSyncHandlers(local, cursors),
      ],
      periodicInterval: const Duration(days: 1),
    );
    final uid = client.auth.currentUser!.id;
    await engine.setScope(SyncScope(userId: uid, entrepriseId: alpha));
    await engine.syncNow();
    return _Appareil._(client, db, local, queue, engine, reseau, uid);
  }

  Future<void> fermer() async {
    await engine.dispose();
    await db.close();
    await client.dispose();
  }
}

void main() {
  setUpAll(() async {
    try {
      await (await connect('admin@alpha.test')).dispose();
      _available = true;
    } catch (_) {
      _available = false;
    }
    if (_available) await _nettoyer();
  });
  tearDownAll(() async {
    if (_available) await _nettoyer();
  });

  test('hors-ligne puis synchronisé : le stock serveur et le stock affiché concordent', () async {
    if (!_available) return markTestSkipped('Supabase Local indisponible (supabase start)');
    final admin = await _Appareil.connecter('admin@alpha.test');
    addTearDown(admin.fermer);
    final ctx = await contexteDe(admin.client);

    // --- Hors-ligne : catalogue, stock, transfert, achat, réception, vente --------
    admin.reseau.online = false;
    final cat = await admin.gerer.creerCategorie(ctx, nom: 'Carrelage', icone: 'carrelage', couleur: '#1E7E4E');
    const produitId = 'aaaaaaaa-0000-0000-0010-0000000000a1';
    final photo = await admin.photos.ajouter(
        entrepriseId: alpha, produitId: produitId, octets: Uint8List.fromList(List.filled(64, 7)));
    final produit = await admin.gerer.creerProduit(
      ctx,
      await admin.local.charger(alpha),
      Produit(
        id: produitId,
        entrepriseId: alpha,
        categorieId: cat.id,
        nom: 'Carreaux 40×40 IT',
        uniteBase: 'Pièce',
        prixDetail: 300,
        prixGros: 275,
        photos: [photo],
        venteFractionnee: true,
        pasMinimum: const Qte(2500),
        unites: [UniteProduit(id: 'aaaaaaaa-0000-0000-0012-0000000000a1', nom: 'Carton', facteur: Qte.depuis(40))],
        seuilAlerte: Qte.depuis(80),
      ),
      perimetreId: _centre,
      stockInitial: Qte.depuis(10),
      uniteStock: UniteVente(id: 'x', nom: 'Carton', facteur: Qte.depuis(40), prixDetail: 0),
    );
    final carton = produit.unite('aaaaaaaa-0000-0000-0012-0000000000a1');

    await admin.gerer.transferer(ctx, await admin.local.charger(alpha),
        produit: produit, dePerimetreId: _centre, versPerimetreId: _marche, quantite: Qte.depuis(3), unite: carton);
    final achat = await admin.gerer.creerAchat(
      ctx,
      await admin.local.charger(alpha),
      SaisieAchat(perimetreId: _centre, fournisseurId: _fournisseur, lignes: [
        LigneOperation(
            id: 'aaaaaaaa-0000-0000-0015-0000000000a1',
            produitId: produit.id,
            unite: 'Carton',
            facteur: carton.facteur,
            quantite: Qte.depuis(5),
            prixUnitaire: 10000),
      ]),
    );
    final e0 = await admin.local.charger(alpha);
    await admin.gerer.receptionner(ctx, e0, e0.achat(achat.id)!, {'aaaaaaaa-0000-0000-0015-0000000000a1': Qte.depuis(2)});
    await admin.gerer.vendre(
      ctx,
      await admin.local.charger(alpha),
      null,
      SaisieVente(perimetreId: _centre, lignes: [
        LigneOperation(
            id: 'aaaaaaaa-0000-0000-0013-0000000000a1',
            produitId: produit.id,
            unite: 'Pièce',
            facteur: Qte.un,
            quantite: Qte.depuis(2.5),
            prixUnitaire: 300),
      ]),
    );

    // 10 − 3 + 2 cartons = 9 cartons (360 pièces) − 2,5 pièces = 357,5 pièces au Centre ; 120 au Marché.
    var e = await admin.local.charger(alpha);
    expect(e.quantiteBoutique(produit.id, _centre), Qte.depuis(357.5));
    expect(e.quantiteBoutique(produit.id, _marche), Qte.depuis(120));

    // --- Retour du réseau --------------------------------------------------------
    admin.reseau.online = true;
    await admin.engine.syncNow();
    await admin.engine.syncNow();
    expect(await admin.queue.pendingCount(admin.uid), 0, reason: 'tout est accepté par le serveur');

    final stocks = await admin.client.from('stocks').select('perimetre_id, quantite').eq('produit_id', produit.id);
    expect({for (final s in stocks) s['perimetre_id']: (s['quantite'] as num).toDouble()},
        {_centre: 357.5, _marche: 120.0});
    final achatServeur = await admin.client.from('achats').select('statut, total').eq('id', achat.id).single();
    expect((achatServeur['statut'], achatServeur['total']), ('RECU_PARTIEL', 50000));

    e = await admin.local.charger(alpha);
    expect(e.quantiteBoutique(produit.id, _centre), Qte.depuis(357.5), reason: 'pas de double comptage après sync');
    expect(e.quantiteBoutique(produit.id, _marche), Qte.depuis(120));
    expect(e.mouvements.where((m) => m.enAttente), isEmpty);
    expect(e.produit(produit.id)!.unites.single.facteur, Qte.depuis(40), reason: 'unités relues du serveur');

    // --- Photo : envoyée, puis lue par un autre appareil ---------------------------
    await admin.photos.envoyerEnAttente();
    final vendeur = await _Appareil.connecter('vendeur@alpha.test');
    addTearDown(vendeur.fermer);
    expect(await vendeur.photos.octets(photo), Uint8List.fromList(List.filled(64, 7)));

    // --- Le vendeur (Boutique Marché) ne voit que le stock de sa boutique ---------
    final ev = await vendeur.local.charger(alpha);
    expect(ev.produit(produit.id)!.nom, 'Carreaux 40×40 IT', reason: 'catalogue commun');
    expect(ev.stocks.map((s) => s.perimetreId).toSet(), {_marche});
    expect(ev.achats, isEmpty, reason: 'pas de droit sur les achats');
  });
}
