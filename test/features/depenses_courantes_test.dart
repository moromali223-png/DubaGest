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

DateTime _j(int a, int m, int j) => DateTime(a, m, j);

void main() {
  group('échéances (même règle que le serveur)', () {
    test('mensuel du 31 : 28 février puis retour au 31, sans dérive', () {
      expect(echeanceSuivante(_j(2026, 1, 31), PeriodeRecurrence.mois, 1, _j(2026, 1, 31)), _j(2026, 2, 28));
      expect(echeanceSuivante(_j(2026, 1, 31), PeriodeRecurrence.mois, 1, _j(2026, 2, 28)), _j(2026, 3, 31));
    });

    test('jour, 2 semaines, trimestre, année, avant le début', () {
      expect(echeanceSuivante(_j(2026, 10, 7), PeriodeRecurrence.jour, 1, _j(2026, 10, 20)), _j(2026, 10, 21));
      expect(echeanceSuivante(_j(2026, 10, 1), PeriodeRecurrence.semaine, 2, _j(2026, 10, 1)), _j(2026, 10, 15));
      expect(echeanceSuivante(_j(2026, 10, 1), PeriodeRecurrence.mois, 3, _j(2026, 10, 1)), _j(2027, 1, 1));
      expect(echeanceSuivante(_j(2026, 3, 15), PeriodeRecurrence.an, 1, _j(2026, 12, 31)), _j(2027, 3, 15));
      expect(echeanceSuivante(_j(2026, 11, 1), PeriodeRecurrence.mois, 1, _j(2026, 10, 7)), _j(2026, 11, 1));
    });

    test('fréquences courantes reconnues, « Personnalisé » sinon', () {
      expect(Frequence.de(PeriodeRecurrence.semaine, 2), Frequence.bimensuelle);
      expect(Frequence.de(PeriodeRecurrence.mois, 6), Frequence.semestrielle);
      expect(Frequence.de(PeriodeRecurrence.jour, 10), isNull);
    });
  });

  final admin = contexte(perimetres: [perimetreJson('b1')]);
  final superviseur = contexte(
    role: 'SUPERVISEUR',
    perimetres: [perimetreJson('b1')],
    permissions: {'expenses.view', 'expenses.create', 'payments.create', 'payments.view'},
  );

  late AppDatabase db;
  late DriftSyncQueueStore queue;
  late FinancesLocalDataSource local;
  late SyncEngine engine;
  late FinancesRepositoryImpl repo;
  late GererDepensesCourantes courantes;

  setUp(() async {
    db = memoryDatabase();
    queue = DriftSyncQueueStore(db);
    local = FinancesLocalDataSource(db);
    final cursors = DriftSyncCursorStore(db);
    engine = SyncEngine(
      queue: queue,
      remote: FakeSyncServer(),
      cursors: cursors,
      connectivity: FakeConnectivity(online: false),
      handlers: financesSyncHandlers(local, cursors),
      periodicInterval: const Duration(days: 1),
    );
    repo = FinancesRepositoryImpl(local: local, queue: queue, currentUserId: () => userId, requestSync: () {});
    courantes = GererDepensesCourantes(repo, EnregistrerDepense(repo));
    await engine.setScope(const SyncScope(userId: userId, entrepriseId: entrepriseId));
    await local.categories.ecrireDepuisServeur(
      {'id': 'cat-energie', 'entreprise_id': entrepriseId, 'code': 'ENERGIE', 'est_active': true, 'version': 1},
      RecordSyncStatus.synced,
    );
  });

  tearDown(() async {
    await engine.dispose();
    await db.close();
  });

  Future<EtatFinances> etat() => local.charger(entrepriseId);
  ModifierDepense modifier() => ModifierDepense(repo, AnnulerPaiement(repo));

  Future<DepenseCourante> electricite({DateTime? debut}) async => courantes.creer(
        admin,
        await etat(),
        SaisieCourante(
          nom: 'Électricité',
          categorieId: 'cat-energie',
          montantPrevu: 75000,
          montantVariable: true,
          periode: PeriodeRecurrence.mois,
          prochaineEcheance: debut ?? _j(2026, 10, 10),
          perimetreId: 'b1',
          mode: ModePaiement.virement,
        ),
      );

  test('une dépense courante n\'est jamais comptée comme payée', () async {
    await electricite();
    final e = await etat();
    expect(e.courantes.single.prochaineEcheance, _j(2026, 10, 10));
    expect(e.depenses, isEmpty);
    expect(e.engagements, isEmpty, reason: 'rien à payer tant que l\'échéance n\'est pas confirmée');
    expect(e.resume(_j(2026, 10, 12)).depensesDuMois, 0);
  });

  test('à prévoir : échéances non payées jusqu\'à la date, retards compris', () async {
    await electricite(debut: _j(2026, 9, 10));
    final e = await etat();
    final aPrevoir = e.aPrevoir(_j(2026, 10, 31));
    expect(aPrevoir.map((x) => x.echeance), [_j(2026, 9, 10), _j(2026, 10, 10)]);
    expect(e.montantAPrevoir(_j(2026, 10, 31)), 150000);
    expect(e.etatEcheance(e.courantes.single, _j(2026, 10, 7)), EtatEcheance.enRetard);
  });

  test('payer une échéance : vraie dépense au montant réel, la courante avance', () async {
    final c = await electricite();
    final d = await courantes.payer(admin, await etat(), c, montant: 68500, payeeMaintenant: false);

    final e = await etat();
    expect((d.montant, d.couranteId, d.echeancePrevue, d.libelle), (68500, c.id, _j(2026, 10, 10), 'Électricité'));
    expect(e.courantes.single.prochaineEcheance, _j(2026, 11, 10));
    expect(e.suivi(e.engagements.single).reste, 68500, reason: 'circuit financier de la dépense, inchangé');
    expect(e.montantAPrevoir(_j(2026, 10, 31)), 0);
  });

  test('une échéance ne se paie qu\'une fois', () async {
    final c = await electricite();
    await courantes.payer(admin, await etat(), c, montant: 68500, payeeMaintenant: false);
    expect(
      () async => courantes.payer(admin, await etat(), c, montant: 1000, payeeMaintenant: false),
      _regle(RuleCodes.dueAlreadyPaid),
    );
  });

  test('dépense de l\'échéance annulée : l\'échéance redevient à payer', () async {
    final c = await electricite();
    final d = await courantes.payer(admin, await etat(), c, montant: 68500, payeeMaintenant: false);
    await modifier().annuler(admin, await etat(), d, motif: 'Erreur');
    final e = await etat();
    expect(e.courantes.single.prochaineEcheance, _j(2026, 10, 10));
    expect(e.paiementEcheance(c.id, _j(2026, 10, 10)), isNull);
  });

  test('ignorer une échéance, arrêter : rien n\'est payé, l\'historique reste', () async {
    final c = await electricite();
    await courantes.ignorerEcheance(admin, c);
    var e = await etat();
    expect(e.courantes.single.prochaineEcheance, _j(2026, 11, 10));
    expect(e.depenses, isEmpty);

    await courantes.activer(admin, e.courantes.single, active: false);
    e = await etat();
    expect(e.courantes.single.estActive, isFalse);
    expect(e.aPrevoir(_j(2027, 1, 1)), isEmpty, reason: 'arrêtée : plus rien à prévoir');
  });

  test('nouveau rythme : repart de la prochaine échéance', () async {
    final c = await electricite();
    await courantes.modifier(
      admin,
      await etat(),
      c,
      const SaisieCourante(
          nom: 'Électricité', categorieId: 'cat-energie', montantPrevu: 80000, periode: PeriodeRecurrence.mois,
          intervalle: 2),
    );
    final apres = (await etat()).courantes.single;
    expect((apres.dateDebut, apres.prochaineEcheance, apres.montantPrevu), (_j(2026, 10, 10), _j(2026, 10, 10), 80000));
    expect(apres.suivante(apres.prochaineEcheance), _j(2026, 12, 10));
  });

  test('droits : sans expenses.recurring, pas de dépense courante ; sans expenses.cancel, pas d\'annulation', () async {
    expect(
      () async => courantes.creer(superviseur, await etat(), const SaisieCourante(
          nom: 'Loyer', categorieId: 'cat-energie', montantPrevu: 1, periode: PeriodeRecurrence.mois)),
      throwsA(isA<Failure>()),
    );
    final d = await EnregistrerDepense(repo).call(superviseur, await etat(), const SaisieDepense(
        categorieId: 'cat-energie', libelle: 'Ampoules', montant: 2000, payeeMaintenant: false, perimetreId: 'b1',
        beneficiaire: 'Quincaillerie Diallo'));
    expect(d.beneficiaire, 'Quincaillerie Diallo');
    expect(
      () async => modifier().annuler(superviseur, await etat(), d),
      throwsA(isA<Failure>()),
    );
  });
}
