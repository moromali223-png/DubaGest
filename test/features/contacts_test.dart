import 'package:dubagest/core/database/app_database.dart';
import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/core/permissions/access_decision.dart';
import 'package:dubagest/core/sync/local/drift_sync_stores.dart';
import 'package:dubagest/core/sync/sync_engine.dart';
import 'package:dubagest/core/sync/sync_models.dart';
import 'package:dubagest/features/contacts/data/datasources/contact_local_data_source.dart';
import 'package:dubagest/features/contacts/data/repositories/contact_repository_impl.dart';
import 'package:dubagest/features/contacts/domain/entities/contact.dart';
import 'package:dubagest/features/contacts/domain/usecases/gerer_contacts.dart';
import 'package:dubagest/features/modules/domain/entities/app_module.dart';
import 'package:dubagest/features/navigation/domain/services/navigation_builder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contexte_fixtures.dart';
import '../helpers/fake_sync_server.dart';
import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftSyncQueueStore queue;
  late ContactLocalDataSource local;
  late FakeSyncServer server;
  late FakeConnectivity network;
  late SyncEngine engine;
  late ContactRepositoryImpl repository;

  final admin = contexte();
  final vendeur = contexte(role: 'VENDEUR');

  setUp(() async {
    db = memoryDatabase();
    queue = DriftSyncQueueStore(db);
    local = ContactLocalDataSource(db);
    server = FakeSyncServer();
    network = FakeConnectivity();
    final cursors = DriftSyncCursorStore(db);
    engine = SyncEngine(
      queue: queue,
      remote: server,
      cursors: cursors,
      connectivity: network,
      handlers: [ContactsSyncHandler(local, cursors)],
      periodicInterval: const Duration(days: 1),
    );
    repository = ContactRepositoryImpl(
      local: local,
      queue: queue,
      currentUserId: () => userId,
      requestSync: () {},
    );
    await engine.setScope(const SyncScope(userId: userId, entrepriseId: entrepriseId));
    await engine.syncNow();
  });

  tearDown(() async {
    await engine.dispose();
    await db.close();
  });

  Future<Contact> creer(
    String nom, {
    String? prenom,
    String? telephone,
    String? ville,
    Set<RelationContact> relations = const {RelationContact.client},
  }) =>
      CreerContact(repository).call(
        admin,
        SaisieContact(
          typePersonne: TypePersonne.personne,
          nom: nom,
          prenom: prenom,
          telephone: telephone,
          ville: ville,
          relations: relations,
        ),
      );

  Future<List<Contact>> liste([FiltreContacts filtre = const FiltreContacts()]) =>
      local.watch(entrepriseId, filtre).first;

  group('validation et permissions', () {
    test('le nom est obligatoire', () async {
      await expectLater(
        creer('   '),
        throwsA(isA<Failure>().having((f) => f.ruleCode, 'règle', RuleCodes.nameInvalid)),
      );
    });

    test('e-mail invalide refusé, e-mail valide normalisé en minuscules', () async {
      final creerContact = CreerContact(repository);
      await expectLater(
        creerContact(admin, const SaisieContact(typePersonne: TypePersonne.personne, nom: 'Sow', email: 'pas-un-mail')),
        throwsA(isA<Failure>().having((f) => f.ruleCode, 'règle', RuleCodes.emailInvalid)),
      );
      final c = await creerContact(
          admin, const SaisieContact(typePersonne: TypePersonne.personne, nom: 'Sow', email: ' Mariam@Exemple.ML '));
      expect(c.email, 'mariam@exemple.ml');
    });

    test('une organisation n\'a pas de prénom ; les champs vides deviennent nuls', () async {
      final c = await CreerContact(repository).call(
        admin,
        const SaisieContact(
            typePersonne: TypePersonne.organisation, nom: ' Sotelma ', prenom: 'X', telephone: '  ', ville: ''),
      );
      expect((c.nom, c.prenom, c.telephone, c.ville), ('Sotelma', null, null, null));
      expect(c.nomAffiche, 'Sotelma');
    });

    test('remarque limitée à la longueur acceptée par le serveur', () async {
      await expectLater(
        CreerContact(repository).call(
          admin,
          SaisieContact(typePersonne: TypePersonne.personne, nom: 'Sow', remarque: 'x' * (longueurMaxRemarque + 1)),
        ),
        throwsA(isA<Failure>().having((f) => f.ruleCode, 'règle', RuleCodes.textTooLong)),
      );
    });

    test('vendeur : peut créer et modifier, mais pas archiver', () async {
      final c = await creer('Traoré');
      final droits = DroitsContacts.de(vendeur);
      expect((droits.voir, droits.creer, droits.modifier, droits.archiver), (true, true, true, false));
      await expectLater(
        ArchiverContact(repository).call(vendeur, c, archiver: true),
        throwsA(isA<Failure>().having((f) => f.ruleCode, 'règle', RuleCodes.permissionDenied)),
      );
    });

    test('sans contacts.view : liste refusée', () {
      final sansDroit = contexte(role: 'VENDEUR', permissions: {'sales.view'});
      expect(() => ObserverContacts(repository).call(sansDroit, const FiltreContacts()), throwsA(isA<Failure>()));
    });

    test('abonnement inactif : création refusée', () async {
      final expire = contexte(abonnementStatut: 'EXPIRE');
      await expectLater(
        CreerContact(repository).call(expire, const SaisieContact(typePersonne: TypePersonne.personne, nom: 'Sow')),
        throwsA(isA<Failure>().having((f) => f.ruleCode, 'règle', RuleCodes.subscriptionInactive)),
      );
    });
  });

  group('recherche locale (hors-ligne)', () {
    setUp(() async {
      await creer('Traoré', prenom: 'Amadou', telephone: '+223 76 12 34 56', ville: 'Bamako',
          relations: {RelationContact.client, RelationContact.fournisseur});
      await creer('Sow', prenom: 'Mariam', telephone: '66 00 11 22', ville: 'Ségou');
      await creer('محمد', prenom: 'أحمد', relations: {RelationContact.locataire});
    });

    Future<List<String>> noms(FiltreContacts f) async => [for (final c in await liste(f)) c.nom];

    test('sans accent ni majuscule', () async {
      expect(await noms(const FiltreContacts(recherche: 'traore')), ['Traoré']);
      expect(await noms(const FiltreContacts(recherche: 'SEGOU')), ['Sow']);
      expect(await noms(const FiltreContacts(recherche: 'amadou bamako')), ['Traoré']);
    });

    test('arabe : variantes d\'alef ignorées', () async {
      expect(await noms(const FiltreContacts(recherche: 'احمد')), ['محمد']);
    });

    test('par téléphone, quel que soit le format saisi', () async {
      expect(await noms(const FiltreContacts(recherche: '76123456')), ['Traoré']);
      expect(await noms(const FiltreContacts(recherche: '66 00 11')), ['Sow']);
    });

    test('filtre par relation', () async {
      expect(await noms(const FiltreContacts(relation: RelationContact.fournisseur)), ['Traoré']);
      expect((await noms(const FiltreContacts(relation: RelationContact.client))).toSet(), {'Traoré', 'Sow'});
      expect(await noms(const FiltreContacts(relation: RelationContact.locataire)), ['محمد']);
    });

    test('les archivés sont masqués sauf demande explicite', () async {
      final sow = (await liste(const FiltreContacts(recherche: 'sow'))).single;
      await ArchiverContact(repository).call(admin, sow, archiver: true);
      expect(await noms(const FiltreContacts(recherche: 'sow')), isEmpty);
      expect(await noms(const FiltreContacts(recherche: 'sow', inclureArchives: true)), ['Sow']);
    });
  });

  group('doublons', () {
    test('même téléphone (avec ou sans indicatif) ou même nom complet', () async {
      final amadou = await creer('Traoré', prenom: 'Amadou', telephone: '+223 76 12 34 56');
      final detecter = DetecterDoublons(repository);

      Future<List<String>> pour(SaisieContact s, {String? sauf}) async =>
          [for (final c in await detecter(admin, s, saufId: sauf)) c.id];

      expect(await pour(const SaisieContact(typePersonne: TypePersonne.personne, nom: 'Inconnu', telephone: '76123456')),
          [amadou.id]);
      expect(await pour(const SaisieContact(typePersonne: TypePersonne.personne, nom: 'TRAORE', prenom: 'amadou')),
          [amadou.id]);
      expect(await pour(const SaisieContact(typePersonne: TypePersonne.personne, nom: 'Traoré', prenom: 'Moussa')),
          isEmpty);
      expect(
          await pour(const SaisieContact(typePersonne: TypePersonne.personne, nom: 'Traoré', prenom: 'Amadou'),
              sauf: amadou.id),
          isEmpty);
    });

    test('ajouter une relation à la fiche existante plutôt que la dupliquer', () async {
      final c = await creer('Sow', prenom: 'Mariam');
      await ModifierContact(repository).ajouterRelation(admin, c, {RelationContact.fournisseur});
      final apres = (await liste()).single;
      expect(apres.relations, {RelationContact.client, RelationContact.fournisseur});
    });
  });

  group('synchronisation', () {
    test('créé hors-ligne en attente, envoyé au retour du réseau avec les relations en tableau', () async {
      network.online = false;
      final c = await creer('Traoré', relations: {RelationContact.fournisseur, RelationContact.client});
      await engine.syncNow();
      expect((await liste()).single.syncStatus, RecordSyncStatus.pendingSync);
      expect(server.rows, isEmpty);

      network.online = true;
      await engine.syncNow();
      expect(server.rows[c.id]?['relations'], ['CLIENT', 'FOURNISSEUR']);
      expect(server.rows[c.id]?['entreprise_id'], entrepriseId);
      final synchro = (await liste()).single;
      expect((synchro.syncStatus, synchro.version), (RecordSyncStatus.synced, 1));
    });

    test('modification venant d\'un autre appareil reçue et cherchable', () async {
      server.externalUpsert({
        'id': 'c-ext',
        'entreprise_id': entrepriseId,
        'type_personne': 'PERSONNE',
        'nom': 'Keïta',
        'prenom': 'Fatou',
        'telephone': '70 00 00 01',
        'relations': ['LOCATAIRE', 'INCONNUE'],
        'statut': 'ACTIF',
      });
      await engine.syncNow();
      final recu = (await liste(const FiltreContacts(recherche: 'keita fatou'))).single;
      expect(recu.relations, {RelationContact.locataire});
      expect(recu.syncStatus, RecordSyncStatus.synced);
    });

    test('conflit : la version serveur gagne et la fiche est signalée', () async {
      final c = await creer('Sow');
      await engine.syncNow();
      server.externalUpsert({...server.rows[c.id]!, 'ville': 'Kayes'});

      network.online = false;
      final locale = (await liste()).single;
      await ModifierContact(repository).call(
          admin, locale, const SaisieContact(typePersonne: TypePersonne.personne, nom: 'Sow', ville: 'Mopti'));
      network.online = true;
      await engine.syncNow();

      final apres = (await liste()).single;
      expect((apres.ville, apres.syncStatus), ('Kayes', RecordSyncStatus.conflict));
    });

    test('supprimé côté serveur : retiré de l\'appareil', () async {
      final c = await creer('Sow');
      await engine.syncNow();
      server.externalUpsert({...server.rows[c.id]!, 'deleted_at': '2026-10-03T12:00:00Z'});
      await engine.syncNow();
      expect(await liste(const FiltreContacts(inclureArchives: true)), isEmpty);
    });
  });

  group('navigation', () {
    test('Contacts est un outil commun, visible quelle que soit l\'activité choisie', () {
      final ctx = contexte(activites: ['COMMERCE', 'SERVICES']);
      for (final activite in [null, ...ctx.activites.map((a) => a.activite)]) {
        final nav = const NavigationBuilder().build(ctx, activite: activite);
        expect(nav.modulesCommuns.map((m) => m.code), contains(ModuleCodes.communContacts));
        expect(nav.modulesAdministration.map((m) => m.code), isNot(contains(ModuleCodes.communContacts)));
        expect(nav.sections.expand((s) => s.modules).map((m) => m.code), isNot(contains('commerce.clients')));
      }
    });

    test('catégorie lue depuis le serveur, déduite de l\'activité sinon', () {
      final contacts = admin.modules.firstWhere((m) => m.code == ModuleCodes.communContacts);
      expect((contacts.categorie, contacts.estCommun, contacts.estAdministration),
          (ModuleCategorie.commun, true, false));
      const ancien = AppModule(code: 'admin.x', activite: null, permissionAcces: 'x', ordre: 1);
      expect(ancien.categorie, ModuleCategorie.administration);
    });
  });
}
