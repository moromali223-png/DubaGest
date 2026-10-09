import 'package:dubagest/core/database/app_database.dart';
import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/core/permissions/access_decision.dart';
import 'package:dubagest/core/sync/local/drift_sync_stores.dart';
import 'package:dubagest/core/sync/sync_engine.dart';
import 'package:dubagest/core/sync/sync_models.dart';
import 'package:dubagest/features/agenda/data/agenda_repository_impl.dart';
import 'package:dubagest/features/agenda/domain/entities/agenda.dart';
import 'package:dubagest/features/agenda/domain/services/agenda_service.dart';
import 'package:dubagest/features/agenda/domain/usecases/gerer_agenda.dart';
import 'package:dubagest/features/finances/domain/entities/finances.dart';
import 'package:dubagest/features/finances/domain/services/etat_finances.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contexte_fixtures.dart';
import '../helpers/fake_sync_server.dart';
import '../helpers/test_database.dart';

Matcher _regle(String code) => throwsA(isA<Failure>().having((f) => f.ruleCode, 'règle', code));

void main() {
  final maintenant = DateTime(2026, 10, 5, 10);
  Echeance e(String id, DateTime date, {String? responsable, String createur = userId, int? rappel}) => Echeance(
        id: id, entrepriseId: entrepriseId, type: TypeEcheance.tache, titre: id, dateHeure: date,
        responsableId: responsable, createdBy: createur, rappelMinutes: rappel,
      );

  group('agenda (logique pure)', () {
    test('regroupement : en retard, aujourd\'hui, 7 jours, plus tard ; sommes dues incluses', () {
      final finances = EtatFinances(engagements: [
        Engagement(id: 'dette', entrepriseId: entrepriseId, sens: SensEngagement.aRecevoir, libelle: 'Crédit',
            montantTotal: 1000, dateEngagement: DateTime(2026, 9, 1), echeance: DateTime(2026, 10, 3)),
        Engagement(id: 'soldee', entrepriseId: entrepriseId, sens: SensEngagement.aRecevoir, libelle: 'Soldé',
            montantTotal: 1000, montantRegle: 1000, dateEngagement: DateTime(2026, 9, 1), echeance: DateTime(2026, 10, 6)),
      ]);
      final agenda = AgendaService.construire(
        echeances: [
          e('hier', DateTime(2026, 10, 4, 15)),
          e('ce-matin', DateTime(2026, 10, 5, 8)), // passée mais du jour : « aujourd'hui »
          e('demain', DateTime(2026, 10, 6, 9)),
          e('mois-prochain', DateTime(2026, 11, 20)),
          e('faite', DateTime(2026, 10, 6)).copyWith(statut: StatutEcheance.fait),
        ],
        maintenant: maintenant,
        userId: userId,
        finances: finances,
      );
      String id(ElementAgenda x) => switch (x) {
            ElementEcheance(:final echeance) => echeance.id,
            ElementSommeDue(:final suivi) => suivi.engagement.id,
          };
      expect(agenda.enRetard.map(id), ['dette', 'hier']);
      expect(agenda.aujourdhui.map(id), ['ce-matin']);
      expect(agenda.aVenir.map(id), ['demain'], reason: 'ni tâche faite, ni somme soldée');
      expect(agenda.plusTard.map(id), ['mois-prochain']);
    });

    test('« mes tâches » : confiées à moi, ou créées par moi sans responsable', () {
      final agenda = AgendaService.construire(
        echeances: [
          e('a-moi', maintenant, responsable: userId, createur: 'autre'),
          e('a-un-autre', maintenant, responsable: 'autre'),
          e('perso', maintenant),
        ],
        maintenant: maintenant,
        userId: userId,
        mesTaches: true,
      );
      expect(agenda.aujourdhui.map((x) => (x as ElementEcheance).echeance.id), ['a-moi', 'perso']);
    });

    test('alertes : retard, rappel, créances en retard, caisse ouverte depuis 24 h, refus', () {
      final finances = EtatFinances(
        engagements: [
          Engagement(id: 'd', entrepriseId: entrepriseId, sens: SensEngagement.aRecevoir, libelle: 'X',
              montantTotal: 5000, dateEngagement: DateTime(2026, 9, 1), echeance: DateTime(2026, 9, 30)),
        ],
        caisses: const [Caisse(id: 'k', entrepriseId: entrepriseId, perimetreId: 'b', nom: 'Caisse')],
        sessions: [
          SessionCaisse(id: 's', entrepriseId: entrepriseId, caisseId: 'k', perimetreId: 'b', ouverte: true,
              soldeInitial: 0, ouverteLe: DateTime(2026, 10, 3, 8)),
        ],
        paiements: [
          Paiement(id: 'r', entrepriseId: entrepriseId, sens: SensPaiement.entree, montant: 1,
              mode: ModePaiement.carte, datePaiement: maintenant, syncStatus: RecordSyncStatus.syncError),
        ],
      );
      final alertes = AgendaService.alertes(
        echeances: [
          e('retard', DateTime(2026, 10, 1)),
          e('rappel', DateTime(2026, 10, 6, 9), rappel: 1440),
          e('lointaine', DateTime(2026, 10, 20), rappel: 60),
          e('pas-a-moi', DateTime(2026, 10, 1), responsable: 'autre'),
        ],
        maintenant: maintenant,
        userId: userId,
        finances: finances,
        voirCreances: true,
        voirCaisse: true,
      );
      expect(alertes.whereType<AlerteEcheance>().map((a) => (a.echeance.id, a.enRetard)),
          [('retard', true), ('rappel', false)]);
      expect(alertes.whereType<AlerteCreancesEnRetard>().single.montant, 5000);
      expect(alertes.whereType<AlerteCaisseOuverte>().single.caisse.nom, 'Caisse');
      expect(alertes.whereType<AlerteEcrituresRefusees>().single.nombre, 1);
    });

    test('sans droit financier : aucune alerte financière', () {
      final alertes = AgendaService.alertes(echeances: const [], maintenant: maintenant, userId: userId);
      expect(alertes, isEmpty);
    });
  });

  group('cas d\'usage + base locale + synchronisation', () {
    late AppDatabase db;
    late DriftSyncQueueStore queue;
    late AgendaLocalDataSource local;
    late AgendaRepositoryImpl repo;
    final admin = contexte();
    final vendeur = contexte(role: 'VENDEUR');

    setUp(() {
      db = memoryDatabase();
      queue = DriftSyncQueueStore(db);
      local = AgendaLocalDataSource(db);
      repo = AgendaRepositoryImpl(local: local, queue: queue, currentUserId: () => userId, requestSync: () {});
    });
    tearDown(() => db.close());

    test('créer, confier, marquer faite : hors-ligne puis envoyé', () async {
      final g = GererEcheances(repo);
      final e = await g.creer(admin, SaisieEcheance(
        type: TypeEcheance.relance,
        titre: '  Relancer Amadou ',
        dateHeure: DateTime(2026, 10, 6, 9),
        rappelMinutes: 60,
        responsableId: 'u-2',
        responsableNom: 'Fatou Keita',
        cibleType: CibleType.contact,
        cibleId: 'c-1',
      ));
      expect(e.titre, 'Relancer Amadou');
      await g.changerStatut(admin, (await local.watchEcheances(entrepriseId).first).single, StatutEcheance.fait);
      expect((await local.watchEcheances(entrepriseId).first).single.statut, StatutEcheance.fait);
      expect(await queue.pendingCount(userId), 2, reason: 'création puis statut : envoyés séparément');

      final server = FakeSyncServer();
      final cursors = DriftSyncCursorStore(db);
      final engine = SyncEngine(
        queue: queue, remote: server, cursors: cursors, connectivity: FakeConnectivity(),
        handlers: agendaSyncHandlers(local, cursors), periodicInterval: const Duration(days: 1),
      );
      addTearDown(engine.dispose);
      await engine.setScope(const SyncScope(userId: userId, entrepriseId: entrepriseId));
      await engine.syncNow();
      expect((server.rows[e.id]?['statut'], server.rows[e.id]?['responsable_id']), ('FAIT', 'u-2'));
      expect(await queue.pendingCount(userId), 0);
    });

    test('droits : le vendeur ne crée pas, mais marque faite une tâche qui lui est confiée', () async {
      final g = GererEcheances(repo);
      await expectLater(
        g.creer(vendeur, SaisieEcheance(type: TypeEcheance.tache, titre: 'X', dateHeure: maintenant)),
        _regle(RuleCodes.permissionDenied),
      );
      final confiee = e('t', maintenant, responsable: userId, createur: 'u-chef');
      await local.inserer(confiee);
      await g.changerStatut(vendeur, confiee, StatutEcheance.fait);
      final autre = e('t2', maintenant, responsable: 'u-autre');
      await expectLater(g.changerStatut(vendeur, autre, StatutEcheance.fait), _regle(RuleCodes.permissionDenied));
      await expectLater(g.changerStatut(vendeur, confiee, StatutEcheance.annule), _regle(RuleCodes.permissionDenied));
    });

    test('titre obligatoire', () async {
      await expectLater(
        GererEcheances(repo).creer(admin, SaisieEcheance(type: TypeEcheance.tache, titre: ' ', dateHeure: maintenant)),
        _regle(RuleCodes.labelInvalid),
      );
    });

    test('notification marquée lue : locale, puis envoyée', () async {
      await local.notifications.ecrireDepuisServeur({
        'id': 'n1', 'entreprise_id': entrepriseId, 'destinataire_id': userId, 'type': 'ECHEANCE_CONFIEE',
        'parametres': {'titre': 'Relancer Amadou'}, 'auteur_nom': 'Moussa', 'created_at': '2026-10-05T08:00:00Z',
        'version': 1,
      }, RecordSyncStatus.synced);
      final n = (await local.watchNotifications(entrepriseId, userId).first).single;
      expect((n.type, n.lue, n.parametres['titre']), (TypeNotification.echeanceConfiee, false, 'Relancer Amadou'));
      await GererEcheances(repo).marquerLue(n);
      expect((await local.watchNotifications(entrepriseId, userId).first).single.lue, isTrue);
      expect(await queue.pendingCount(userId), 1);
    });
  });
}
