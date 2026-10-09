import 'package:dubagest/core/database/app_database.dart';
import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/core/permissions/access_decision.dart';
import 'package:dubagest/core/sync/local/drift_sync_stores.dart';
import 'package:dubagest/core/sync/sync_engine.dart';
import 'package:dubagest/core/sync/sync_models.dart';
import 'package:dubagest/features/finances/data/datasources/finances_local_data_source.dart';
import 'package:dubagest/features/finances/data/repositories/finances_repository_impl.dart';
import 'package:dubagest/features/finances/domain/entities/finances.dart';
import 'package:dubagest/features/finances/domain/services/etat_finances.dart';
import 'package:dubagest/features/finances/domain/usecases/gerer_depenses.dart';
import 'package:dubagest/features/finances/domain/usecases/gerer_finances.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contexte_fixtures.dart';
import '../helpers/fake_sync_server.dart';
import '../helpers/test_database.dart';

Matcher _regle(String code) => throwsA(isA<Failure>().having((f) => f.ruleCode, 'règle', code));

void main() {
  final admin = contexte(perimetres: [perimetreJson('b1')]);
  final vendeur = contexte(role: 'VENDEUR', perimetres: [perimetreJson('b1')]);

  late AppDatabase db;
  late DriftSyncQueueStore queue;
  late FinancesLocalDataSource local;
  late FakeSyncServer server;
  late FakeConnectivity network;
  late SyncEngine engine;
  late FinancesRepositoryImpl repo;

  setUp(() async {
    db = memoryDatabase();
    queue = DriftSyncQueueStore(db);
    local = FinancesLocalDataSource(db);
    server = FakeSyncServer();
    network = FakeConnectivity(online: false);
    final cursors = DriftSyncCursorStore(db);
    engine = SyncEngine(
      queue: queue,
      remote: server,
      cursors: cursors,
      connectivity: network,
      handlers: financesSyncHandlers(local, cursors),
      periodicInterval: const Duration(days: 1),
    );
    repo = FinancesRepositoryImpl(local: local, queue: queue, currentUserId: () => userId, requestSync: () {});
    await engine.setScope(const SyncScope(userId: userId, entrepriseId: entrepriseId));
    // Catégories fournies par le serveur (descente).
    await local.categories.ecrireDepuisServeur(
      {'id': 'cat-transport', 'entreprise_id': entrepriseId, 'code': 'TRANSPORT', 'est_active': true, 'version': 1},
      RecordSyncStatus.synced,
    );
    await local.categories.ecrireDepuisServeur(
      {'id': 'cat-off', 'entreprise_id': entrepriseId, 'nom': 'Ancienne', 'est_active': false, 'version': 1},
      RecordSyncStatus.synced,
    );
  });

  tearDown(() async {
    await engine.dispose();
    await db.close();
  });

  Future<EtatFinances> etat() => local.charger(entrepriseId);

  Future<SessionCaisse> caisseOuverte(int solde) async {
    final caisses = GererCaisse(repo);
    final c = await caisses.creer(admin, perimetreId: 'b1', nom: 'Caisse');
    return caisses.ouvrir(admin, await etat(), c, soldeInitial: solde);
  }

  test('payée en espèces : somme à payer réglée, paiement et sortie de caisse, une seule opération', () async {
    final session = await caisseOuverte(20000);
    final avant = await queue.pendingCount(userId);
    final d = await EnregistrerDepense(repo).call(admin, await etat(), SaisieDepense(
      categorieId: 'cat-transport',
      libelle: 'Taxi livraison',
      montant: 5000,
      payeeMaintenant: true,
      sessionId: session.id,
    ));

    final e = await etat();
    final suivi = e.suivi(e.engagements.single);
    expect((suivi.engagement.id, suivi.engagement.origineType, suivi.reste), (d.id, 'DEPENSE', 0));
    expect(e.paiement(d.paiementId!)!.sens, SensPaiement.sortie);
    expect(e.solde(e.sessions.single), 15000);
    final resume = e.resume(DateTime.now());
    expect((resume.depensesDuMois, resume.aPayer, resume.decaisseAujourdhui), (5000, 0, 5000));
    expect(await queue.pendingCount(userId) - avant, 1, reason: 'dépense + liens : une opération');
  });

  test('à payer plus tard : somme due ouverte, réglable ensuite', () async {
    final d = await EnregistrerDepense(repo).call(admin, await etat(), SaisieDepense(
      categorieId: 'cat-transport',
      libelle: 'Facture transporteur',
      montant: 30000,
      payeeMaintenant: false,
      echeance: DateTime.now().add(const Duration(days: 10)),
    ));
    var e = await etat();
    expect(e.suivi(e.engagements.single).reste, 30000);
    expect(e.resume(DateTime.now()).aPayer, 30000);

    await EnregistrerPaiement(repo).call(admin, e, SaisiePaiement(
        sens: SensPaiement.sortie, montant: 30000, mode: ModePaiement.virement, affectations: {d.id: 30000}));
    e = await etat();
    expect(e.suivi(e.engagements.single).reste, 0);
  });

  test('règles : catégorie active, solde de caisse, droits', () async {
    final session = await caisseOuverte(1000);
    final e = await etat();
    await expectLater(
      EnregistrerDepense(repo).call(admin, e,
          const SaisieDepense(categorieId: 'cat-off', libelle: 'X', montant: 100, payeeMaintenant: false)),
      _regle(RuleCodes.categoryInvalid),
    );
    await expectLater(
      EnregistrerDepense(repo).call(admin, e, SaisieDepense(
          categorieId: 'cat-transport', libelle: 'X', montant: 5000, payeeMaintenant: true, sessionId: session.id)),
      _regle(RuleCodes.cashInsufficient),
    );
    await expectLater(
      EnregistrerDepense(repo).call(vendeur, e,
          const SaisieDepense(categorieId: 'cat-transport', libelle: 'X', montant: 100, payeeMaintenant: false)),
      _regle(RuleCodes.permissionDenied),
    );
  });

  test('annulation d\'une dépense payée : paiement inverse puis annulation, caisse rétablie', () async {
    final session = await caisseOuverte(20000);
    final d = await EnregistrerDepense(repo).call(admin, await etat(), SaisieDepense(
        categorieId: 'cat-transport', libelle: 'Taxi', montant: 5000, payeeMaintenant: true, sessionId: session.id));
    final annuler = ModifierDepense(repo, AnnulerPaiement(repo));
    var e = await etat();
    await annuler.annuler(admin, e, e.depenses.single, motif: 'Erreur');

    e = await etat();
    expect(e.depenses.single.annulee, isTrue);
    expect(e.engagements.single.annule, isTrue);
    expect(e.estAnnule(e.paiement(d.paiementId!)!), isTrue);
    expect(e.solde(e.sessions.single), 20000);
    expect(e.resume(DateTime.now()).depensesDuMois, 0);
    await expectLater(
      ModifierDepense(repo, AnnulerPaiement(repo)).call(admin, e, e.depenses.single,
          categorieId: 'cat-transport', libelle: 'Y', date: DateTime.now()),
      _regle(RuleCodes.expenseCancelled),
    );
  });

  test('la somme liée se gère depuis la dépense', () async {
    await EnregistrerDepense(repo).call(admin, await etat(),
        const SaisieDepense(categorieId: 'cat-transport', libelle: 'X', montant: 100, payeeMaintenant: false));
    final e = await etat();
    await expectLater(
      ModifierEngagement(repo).annuler(admin, e.suivi(e.engagements.single)),
      _regle(RuleCodes.commitmentLinked),
    );
  });

  test('synchronisation : dépense envoyée, paiement local marqué synchronisé', () async {
    final d = await EnregistrerDepense(repo).call(admin, await etat(),
        const SaisieDepense(categorieId: 'cat-transport', libelle: 'Taxi', montant: 2000, payeeMaintenant: true,
            mode: ModePaiement.mobileMoney));
    network.online = true;
    await engine.syncNow();
    expect(server.rows[d.id]?['paiement_id'], d.paiementId);
    expect(server.rows[d.id]?['reglement'], 'IMMEDIAT');
    final e = await etat();
    expect(e.depenses.single.syncStatus, RecordSyncStatus.synced);
    expect(e.paiement(d.paiementId!)!.syncStatus, RecordSyncStatus.synced);
    expect(await queue.pendingCount(userId), 0);
  });

  test('refus serveur : dépense, somme liée et paiement exclus des totaux, puis retirés', () async {
    final d = await EnregistrerDepense(repo).call(admin, await etat(),
        const SaisieDepense(categorieId: 'cat-transport', libelle: 'Taxi', montant: 2000, payeeMaintenant: true,
            mode: ModePaiement.mobileMoney));
    network.online = true;
    server.failNextPush = const Failure.rule('CATEGORIE_INVALIDE');
    await engine.syncNow();

    var e = await etat();
    expect(e.depenses.single.refusee, isTrue);
    expect(e.engagements.single.refuse, isTrue);
    expect(e.paiement(d.paiementId!)!.refuse, isTrue);
    final r = e.resume(DateTime.now());
    expect((r.depensesDuMois, r.aPayer, r.decaisseAujourdhui), (0, 0, 0));

    await RetirerEcritureRefusee(repo).call('depenses', d.id);
    e = await etat();
    expect(e.depenses, isEmpty);
    expect(e.engagements, isEmpty);
    expect(e.paiements, isEmpty);
  });

  test('catégories : création et désactivation', () async {
    final g = GererCategories(repo);
    final c = await g.creer(admin, await etat(), 'Publicité');
    await g.modifier(admin, (await etat()).categorie(c.id)!, estActive: false);
    expect((await etat()).categorie(c.id)!.estActive, isFalse);
    await expectLater(g.creer(vendeur, await etat(), 'X'), _regle(RuleCodes.permissionDenied));
  });
}
