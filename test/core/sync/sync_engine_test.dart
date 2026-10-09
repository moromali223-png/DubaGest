import 'package:dubagest/core/database/app_database.dart';
import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/core/sync/local/drift_sync_stores.dart';
import 'package:dubagest/core/sync/sync_engine.dart';
import 'package:dubagest/core/sync/sync_models.dart';
import 'package:dubagest/features/activites/domain/entities/activite.dart';
import 'package:dubagest/features/perimetres/data/datasources/perimetre_local_data_source.dart';
import 'package:dubagest/features/perimetres/data/repositories/perimetre_repository_impl.dart';
import 'package:dubagest/features/perimetres/data/repositories/perimetres_sync_handler.dart';
import 'package:dubagest/features/perimetres/domain/entities/perimetre.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_sync_server.dart';
import '../../helpers/test_database.dart';

/// Chaîne complète hors-ligne : Repository → SQLite + file → moteur → serveur.
void main() {
  const eid = 'e-1';
  const uid = 'u-1';

  late AppDatabase db;
  late DriftSyncQueueStore queue;
  late PerimetreLocalDataSource local;
  late FakeSyncServer server;
  late FakeConnectivity network;
  late SyncEngine engine;
  late PerimetreRepositoryImpl repository;

  setUp(() async {
    db = memoryDatabase();
    queue = DriftSyncQueueStore(db);
    local = PerimetreLocalDataSource(db);
    server = FakeSyncServer();
    network = FakeConnectivity();
    final cursors = DriftSyncCursorStore(db);
    engine = SyncEngine(
      queue: queue,
      remote: server,
      cursors: cursors,
      connectivity: network,
      handlers: [PerimetresSyncHandler(local, cursors)],
      periodicInterval: const Duration(days: 1),
    );
    repository = PerimetreRepositoryImpl(
      local: local,
      queue: queue,
      transaction: (action) => db.transaction(action),
      currentUserId: () => uid,
      requestSync: () {},
    );
    await engine.setScope(const SyncScope(userId: uid, entrepriseId: eid));
    await engine.syncNow();
  });

  tearDown(() async {
    await engine.dispose();
    await db.close();
  });

  Future<List<Perimetre>> locaux() => local.watch(eid).first;

  Future<Perimetre> creer(String nom) => repository.creer(
      entrepriseId: eid, activite: ActiviteCode.commerce, type: PerimetreType.boutique, nom: nom);

  test('hors-ligne : enregistré localement en PENDING_SYNC puis envoyé au retour du réseau', () async {
    network.online = false;
    final p = await creer('Boutique A');

    await engine.syncNow();
    expect(engine.state.phase, SyncPhase.offline);
    expect((await locaux()).single.syncStatus, RecordSyncStatus.pendingSync);
    expect(await queue.pendingCount(uid), 1);
    expect(server.rows, isEmpty);

    network.online = true;
    await engine.syncNow();

    expect(server.rows[p.id]?['nom'], 'Boutique A');
    final synced = (await locaux()).single;
    expect(synced.syncStatus, RecordSyncStatus.synced);
    expect(synced.version, 1);
    expect(await queue.pendingCount(uid), 0);
    expect(engine.state.phase, SyncPhase.idle);
  });

  test('création, modification et suppression hors-ligne fusionnées : rien n\'est envoyé', () async {
    network.online = false;
    final p = await creer('Temporaire');
    await repository.modifier(p, nom: 'Renommé', code: null, type: p.type, estActif: true);
    await repository.supprimer((await locaux()).single);
    network.online = true;
    await engine.syncNow();

    expect(server.pushedOps, isEmpty);
    expect(await locaux(), isEmpty);
  });

  test('création puis modification non fusionnée, hors-ligne : les deux appliquées dans le même cycle', () async {
    network.online = false;
    final p = await creer('Boutique A');
    // Modification séparée (comme une clôture de caisse) : version encore inconnue.
    await queue.enqueue(
      userId: uid,
      entityTable: 'perimetres',
      recordId: p.id,
      type: SyncOperationType.update,
      payload: {'nom': 'Boutique Centre'},
      fusionner: false,
    );
    network.online = true;
    await engine.syncNow();

    expect(server.rows[p.id]?['nom'], 'Boutique Centre', reason: 'la modification part de la version créée');
    expect(server.rows[p.id]?['version'], 2);
    expect(await queue.pendingCount(uid), 0);
  });

  test('modification et suppression synchronisées', () async {
    final p = await creer('Boutique A');
    await engine.syncNow();
    final synced = (await locaux()).single;

    await repository.modifier(synced, nom: 'Boutique Centre', code: 'BC', type: synced.type, estActif: true);
    await engine.syncNow();
    expect(server.rows[p.id]?['nom'], 'Boutique Centre');
    expect(server.rows[p.id]?['version'], 2);
    expect((await locaux()).single.version, 2);

    await repository.supprimer((await locaux()).single);
    await engine.syncNow();
    expect(server.rows[p.id]?['deleted_at'], isNotNull);
    expect(await locaux(), isEmpty);
  });

  test('conflit : la version serveur est conservée et signalée', () async {
    final p = await creer('Boutique A');
    await engine.syncNow();
    final v1 = (await locaux()).single;

    // Un autre appareil modifie la boutique (version 2).
    server.externalUpsert({...server.rows[p.id]!, 'nom': 'Nom serveur'});
    // Modification locale basée sur la version 1.
    await repository.modifier(v1, nom: 'Nom local', code: null, type: v1.type, estActif: true);
    await engine.syncNow();

    final apres = (await locaux()).single;
    expect(apres.nom, 'Nom serveur');
    expect(apres.syncStatus, RecordSyncStatus.conflict);
    expect(await queue.pendingCount(uid), 0, reason: 'le conflit sort de la file active');
  });

  test('erreur réseau pendant l\'envoi : réessai planifié, donnée locale conservée', () async {
    await creer('Boutique A');
    server.failNextPush = const Failure(FailureKind.network);
    await engine.syncNow();

    expect(engine.state.phase, SyncPhase.error);
    final op = (await queue.due(uid, DateTime.now().add(const Duration(hours: 1)))).single;
    expect(op.attempts, 1);
    expect(op.nextAttemptAt!.isAfter(DateTime.now()), isTrue);
    expect((await locaux()).single.syncStatus, RecordSyncStatus.pendingSync);
  });

  test('réponse perdue après application : le rejeu n\'applique pas deux fois', () async {
    final p = await creer('Boutique A');
    server.loseNextResponse = true;
    await engine.syncNow();
    expect(server.rows[p.id], isNotNull);

    // Nouvelle tentative (même identifiant d'opération).
    final engineLater = SyncEngine(
      queue: queue,
      remote: server,
      cursors: DriftSyncCursorStore(db),
      connectivity: network,
      handlers: [PerimetresSyncHandler(local, DriftSyncCursorStore(db))],
      periodicInterval: const Duration(days: 1),
      clock: () => DateTime.now().add(const Duration(hours: 1)),
    );
    await engineLater.setScope(const SyncScope(userId: uid, entrepriseId: eid));
    await engineLater.syncNow();
    await engineLater.dispose();

    expect(server.applyCount, 1);
    expect(server.pushedOps.toSet(), hasLength(1));
    expect((await locaux()).single.syncStatus, RecordSyncStatus.synced);
  });

  test('refus métier définitif (limite) : marqué en erreur, plus renvoyé', () async {
    await creer('Boutique 3');
    server.failNextPush = const Failure.rule('LIMITE_PERIMETRES', {'max': 2});
    await engine.syncNow();

    expect((await locaux()).single.syncStatus, RecordSyncStatus.syncError);
    expect(await queue.pendingCount(uid), 0);
    await engine.syncNow();
    expect(server.pushedOps, hasLength(1));
  });

  test('descente : ajouts et suppressions faits ailleurs, sans écraser une modification locale', () async {
    server.externalUpsert({
      'id': 'srv-1', 'entreprise_id': eid, 'activite_code': 'COMMERCE',
      'type': 'BOUTIQUE', 'nom': 'Créée ailleurs', 'code': null, 'est_actif': true,
    });
    server.externalUpsert({
      'id': 'srv-2', 'entreprise_id': eid, 'activite_code': 'COMMERCE',
      'type': 'BOUTIQUE', 'nom': 'Autre', 'code': null, 'est_actif': true,
    });
    server.externalUpsert({
      'id': 'srv-x', 'entreprise_id': 'autre-entreprise', 'activite_code': 'COMMERCE',
      'type': 'BOUTIQUE', 'nom': 'Pas pour nous', 'code': null, 'est_actif': true,
    });
    await engine.syncNow();
    expect((await locaux()).map((p) => p.nom), ['Autre', 'Créée ailleurs']);

    // Modification locale en attente (hors-ligne) + suppression côté serveur d'une autre ligne.
    network.online = false;
    final srv1 = (await locaux()).firstWhere((p) => p.id == 'srv-1');
    await repository.modifier(srv1, nom: 'Modifiée ici', code: null, type: srv1.type, estActif: true);
    server.externalUpsert({...server.rows['srv-2']!, 'deleted_at': '2026-10-03T12:00:00Z'});
    server.externalUpsert({...server.rows['srv-1']!, 'code': 'SRV'});
    network.online = true;

    // Pull avant push : simulé en ne laissant pas passer la montée.
    server.failNextPush = const Failure(FailureKind.server);
    await engine.syncNow();

    final apres = await locaux();
    expect(apres.map((p) => p.id), ['srv-1'], reason: 'srv-2 supprimée côté serveur');
    expect(apres.single.nom, 'Modifiée ici', reason: 'la modification locale en attente est conservée');
  });
}
