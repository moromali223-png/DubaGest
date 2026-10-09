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
import 'package:dubagest/features/finances/domain/usecases/gerer_finances.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contexte_fixtures.dart';
import '../helpers/fake_sync_server.dart';
import '../helpers/test_database.dart';

Matcher _regle(String code) => throwsA(isA<Failure>().having((f) => f.ruleCode, 'règle', code));

void main() {
  final admin = contexte();
  // Vendeur affecté à la boutique b1.
  final vendeur = contexte(role: 'VENDEUR', perimetres: [perimetreJson('b1')]);

  group('calculs (sans base)', () {
    final e = Engagement(
      id: 'e1',
      entrepriseId: entrepriseId,
      sens: SensEngagement.aRecevoir,
      libelle: 'Crédit',
      montantTotal: 50000,
      montantRegle: 20000,
      dateEngagement: DateTime(2026, 9, 1),
      echeance: DateTime(2026, 9, 30),
    );
    Paiement p(String id, int montant, {RecordSyncStatus s = RecordSyncStatus.synced, String? annule, bool annuleServeur = false}) =>
        Paiement(
          id: id,
          entrepriseId: entrepriseId,
          sens: annule == null ? SensPaiement.entree : SensPaiement.sortie,
          montant: montant,
          mode: ModePaiement.especes,
          datePaiement: DateTime(2026, 10, 3, 9),
          affectations: annule == null ? [Affectation(id: 'a$id', engagementId: 'e1', montant: montant)] : const [],
          annulePaiementId: annule,
          annuleServeur: annuleServeur,
          syncStatus: s,
        );

    test('réglé = serveur + paiements de l\'appareil non envoyés', () {
      final etat = EtatFinances(engagements: [e], paiements: [
        p('p1', 20000), // déjà compté par le serveur
        p('p2', 5000, s: RecordSyncStatus.pendingSync),
        p('p3', 9000, s: RecordSyncStatus.syncError), // refusé : jamais compté
      ]);
      final s = etat.suivi(e);
      expect((s.regle, s.reste), (25000, 25000));
      expect(s.etat(DateTime(2026, 10, 5)), EtatReglement.enRetard);
      expect(s.etat(DateTime(2026, 9, 5)), EtatReglement.partiel);
    });

    test('annulation locale non envoyée : la créance redevient due tout de suite', () {
      final etat = EtatFinances(engagements: [e], paiements: [
        p('p1', 20000),
        p('x1', 20000, s: RecordSyncStatus.pendingSync, annule: 'p1'),
      ]);
      expect(etat.regle(e), 0);
      expect(etat.estAnnule(etat.paiement('p1')!), isTrue);
      expect(etat.resume(DateTime(2026, 10, 3)).encaisseAujourdhui, 0, reason: 'paiement annulé non compté');
    });

    test('annulation déjà prise en compte par le serveur : pas de double déduction', () {
      final serveur = Engagement(
        id: 'e1', entrepriseId: entrepriseId, sens: SensEngagement.aRecevoir, libelle: 'Crédit',
        montantTotal: 50000, montantRegle: 0, dateEngagement: DateTime(2026, 9, 1),
      );
      final etat = EtatFinances(engagements: [serveur], paiements: [
        p('p1', 20000, annuleServeur: true),
        p('x1', 20000, annule: 'p1'),
      ]);
      expect(etat.regle(serveur), 0);
    });

    test('solde de caisse : mouvements valides seulement', () {
      final session = SessionCaisse(
        id: 's1', entrepriseId: entrepriseId, caisseId: 'c1', perimetreId: 'b1',
        ouverte: true, soldeInitial: 10000, ouverteLe: DateTime(2026, 10, 3, 8),
      );
      MouvementCaisse m(String id, TypeMouvement t, int montant, {String? paiementId}) => MouvementCaisse(
            id: id, sessionId: 's1', caisseId: 'c1', type: t, montant: montant,
            paiementId: paiementId, createdAt: DateTime(2026, 10, 3, 9));
      final etat = EtatFinances(
        caisses: const [Caisse(id: 'c1', entrepriseId: entrepriseId, perimetreId: 'b1', nom: 'Caisse')],
        sessions: [session],
        paiements: [p('p3', 9000, s: RecordSyncStatus.syncError)],
        mouvements: [
          m('m1', TypeMouvement.encaissement, 20000, paiementId: 'p1'),
          m('m2', TypeMouvement.retrait, 5000),
          m('p3', TypeMouvement.encaissement, 9000, paiementId: 'p3'), // paiement refusé
        ],
      );
      expect(etat.solde(session), 25000);
      expect(etat.resume(DateTime(2026, 10, 3)).enCaisse, 25000);
    });

    test('répartition automatique : du plus ancien au plus récent', () {
      EngagementSuivi s(String id, int total, DateTime date) => EngagementSuivi(
            Engagement(
              id: id, entrepriseId: entrepriseId, sens: SensEngagement.aRecevoir, libelle: id,
              montantTotal: total, dateEngagement: date,
            ),
            regle: 0,
          );
      final parts = EnregistrerPaiement.repartir(12000, [
        s('recent', 10000, DateTime(2026, 10, 1)),
        s('ancien', 8000, DateTime(2026, 9, 1)),
      ]);
      expect(parts, {'ancien': 8000, 'recent': 4000});
    });
  });

  group('cas d\'usage + base locale + synchronisation', () {
    late AppDatabase db;
    late DriftSyncQueueStore queue;
    late FinancesLocalDataSource local;
    late FakeSyncServer server;
    late FakeConnectivity network;
    late SyncEngine engine;
    late FinancesRepositoryImpl repository;

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
      repository = FinancesRepositoryImpl(
        local: local,
        queue: queue,
        currentUserId: () => userId,
        requestSync: () {},
      );
      await engine.setScope(const SyncScope(userId: userId, entrepriseId: entrepriseId));
    });

    tearDown(() async {
      await engine.dispose();
      await db.close();
    });

    Future<EtatFinances> etat() => local.charger(entrepriseId);

    test('hors-ligne : caisse, créance, encaissement en espèces, retrait, clôture', () async {
      final caisses = GererCaisse(repository);
      final caisse = await caisses.creer(admin, perimetreId: 'b1', nom: 'Caisse Marché');
      final session = await caisses.ouvrir(admin, await etat(), caisse, soldeInitial: 10000);
      await expectLater(caisses.ouvrir(admin, await etat(), caisse, soldeInitial: 0), _regle(RuleCodes.cashAlreadyOpen));

      final dette = await CreerEngagement(repository).call(
        admin,
        const SaisieEngagement(sens: SensEngagement.aRecevoir, libelle: 'Crédit', montant: 50000, contactId: 'c-1'),
      );
      await EnregistrerPaiement(repository).call(
        vendeur,
        await etat(),
        SaisiePaiement(
          sens: SensPaiement.entree,
          montant: 20000,
          mode: ModePaiement.especes,
          contactId: 'c-1',
          sessionId: session.id,
          affectations: {dette.id: 20000},
        ),
      );

      var e = await etat();
      expect(e.suivi(e.engagements.single).reste, 30000);
      expect(e.solde(e.sessions.single), 30000);
      expect(e.paiements.single.syncStatus, RecordSyncStatus.pendingSync);

      await expectLater(
        EnregistrerPaiement(repository).call(vendeur, e, SaisiePaiement(
          sens: SensPaiement.entree, montant: 40000, mode: ModePaiement.mobileMoney, affectations: {dette.id: 40000})),
        _regle(RuleCodes.amountAboveRemaining),
      );
      await expectLater(
        EnregistrerPaiement(repository).call(vendeur, e, SaisiePaiement(
          sens: SensPaiement.entree, montant: 100, mode: ModePaiement.carte, sessionId: session.id)),
        _regle(RuleCodes.modeWithoutCash),
      );
      await expectLater(
        caisses.mouvement(admin, e, e.sessions.single, type: TypeMouvement.retrait, montant: 50000),
        _regle(RuleCodes.cashInsufficient),
      );
      await caisses.mouvement(admin, e, e.sessions.single, type: TypeMouvement.retrait, montant: 5000, motif: 'Banque');
      e = await etat();
      expect(e.solde(e.sessions.single), 25000);

      // Un écart n'est jamais accepté en silence : il se justifie.
      await expectLater(
        caisses.cloturer(admin, e, e.sessions.single, soldeReel: 24000),
        _regle(RuleCodes.discrepancyJustificationRequired),
      );
      await caisses.cloturer(admin, e, e.sessions.single,
          soldeReel: 24000, motifEcart: MotifEcart.renduMonnaie, note: 'Monnaie rendue en trop');
      e = await etat();
      expect(e.sessions.single.ouverte, isFalse);
      expect(await queue.pendingCount(userId), 6, reason: 'caisse, ouverture, créance, paiement, retrait, clôture');
    });

    test('droits : le vendeur n\'annule pas, ne paie pas de dette', () async {
      final e = await etat();
      final p = Paiement(
        id: 'p1', entrepriseId: entrepriseId, sens: SensPaiement.entree, montant: 100,
        mode: ModePaiement.carte, datePaiement: DateTime.now());
      await expectLater(AnnulerPaiement(repository).call(vendeur, e, p), _regle(RuleCodes.permissionDenied));
      await expectLater(
        EnregistrerPaiement(repository).call(vendeur, e,
            const SaisiePaiement(sens: SensPaiement.sortie, montant: 100, mode: ModePaiement.virement)),
        _regle(RuleCodes.permissionDenied),
      );
      final droits = DroitsFinances.de(vendeur);
      expect((droits.encaisser, droits.decaisser, droits.annulerPaiements, droits.cloturerCaisse),
          (true, false, false, false));
    });

    test('annulation : paiement inverse, créance de nouveau due, caisse ajustée', () async {
      final caisses = GererCaisse(repository);
      final caisse = await caisses.creer(admin, perimetreId: 'b1', nom: 'Caisse');
      final session = await caisses.ouvrir(admin, await etat(), caisse, soldeInitial: 0);
      final dette = await CreerEngagement(repository).call(
          admin, const SaisieEngagement(sens: SensEngagement.aRecevoir, libelle: 'X', montant: 10000));
      final p = await EnregistrerPaiement(repository).call(admin, await etat(), SaisiePaiement(
          sens: SensPaiement.entree, montant: 10000, mode: ModePaiement.especes,
          sessionId: session.id, affectations: {dette.id: 10000}));

      await expectLater(
        ModifierEngagement(repository).annuler(admin, (await etat()).suivi((await etat()).engagements.single)),
        _regle(RuleCodes.commitmentPaid),
      );
      await AnnulerPaiement(repository).call(admin, await etat(), p);
      final e = await etat();
      expect(e.suivi(e.engagements.single).reste, 10000);
      expect(e.solde(e.sessions.single), 0);
      await expectLater(AnnulerPaiement(repository).call(admin, e, e.paiement(p.id)!),
          _regle(RuleCodes.paymentAlreadyCancelled));
    });

    test('synchronisation : envoi dans l\'ordre, puis copies serveur reçues', () async {
      final dette = await CreerEngagement(repository).call(
          admin, const SaisieEngagement(sens: SensEngagement.aRecevoir, libelle: 'X', montant: 10000));
      final p = await EnregistrerPaiement(repository).call(admin, await etat(),
          SaisiePaiement(sens: SensPaiement.entree, montant: 4000, mode: ModePaiement.carte, affectations: {dette.id: 4000}));

      network.online = true;
      await engine.syncNow();
      expect(server.rows[p.id]?['affectations'], [
        {'id': p.affectations.single.id, 'engagement_id': dette.id, 'montant': 4000}
      ]);
      expect(server.rows[dette.id]?['montant_total'], 10000);
      final e = await etat();
      expect(e.paiements.single.syncStatus, RecordSyncStatus.synced);
      expect(e.engagements.single.syncStatus, RecordSyncStatus.synced);
      expect(await queue.pendingCount(userId), 0);
    });

    test('écriture refusée par le serveur : exclue des totaux, puis retirée', () async {
      final dette = await CreerEngagement(repository).call(
          admin, const SaisieEngagement(sens: SensEngagement.aRecevoir, libelle: 'X', montant: 10000));
      network.online = true;
      await engine.syncNow();
      final p = await EnregistrerPaiement(repository).call(admin, await etat(),
          SaisiePaiement(sens: SensPaiement.entree, montant: 4000, mode: ModePaiement.carte, affectations: {dette.id: 4000}));
      server.failNextPush = const Failure.rule('MONTANT_SUPERIEUR_RESTE');
      await engine.syncNow();

      var e = await etat();
      expect(e.paiement(p.id)!.refuse, isTrue);
      expect(e.suivi(e.engagements.single).reste, 10000);
      await RetirerEcritureRefusee(repository).call('paiements', p.id);
      e = await etat();
      expect(e.paiements, isEmpty);
      expect(await db.select(db.paiementAffectations).get(), isEmpty);
    });
  });
}
