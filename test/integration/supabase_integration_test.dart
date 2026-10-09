@Tags(['integration'])
library;

import 'package:dubagest/core/errors/error_mapper.dart';
import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/core/permissions/access_decision.dart';
import 'package:dubagest/core/sync/local/drift_sync_stores.dart';
import 'package:dubagest/core/sync/remote/supabase_sync_gateway.dart';
import 'package:dubagest/core/sync/sync_engine.dart';
import 'package:dubagest/core/sync/sync_models.dart';
import 'package:dubagest/features/audit/data/repositories/audit_repository_impl.dart';
import 'package:dubagest/features/entreprise/data/datasources/contexte_remote_data_source.dart';
import 'package:dubagest/features/entreprise/data/repositories/entreprise_repository_impl.dart';
import 'package:dubagest/features/entreprise/data/models/contexte_session_model.dart';
import 'package:dubagest/features/entreprise/domain/entities/contexte_session.dart';
import 'package:dubagest/features/navigation/domain/services/navigation_builder.dart';
import 'package:dubagest/features/perimetres/data/datasources/perimetre_local_data_source.dart';
import 'package:dubagest/features/perimetres/data/repositories/perimetre_repository_impl.dart';
import 'package:dubagest/features/perimetres/data/repositories/perimetres_sync_handler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../helpers/fake_sync_server.dart' show FakeConnectivity;
import '../helpers/test_database.dart';

/// Tests d'intégration contre Supabase Local (`supabase start` + seed).
/// Ignorés si le serveur local n'est pas joignable.
///   flutter test test/integration
const _url = 'http://127.0.0.1:54321';
const _key = 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH';
const _password = 'Password123!';

const alpha = 'aaaaaaaa-0000-0000-0000-000000000001';
const beta = 'bbbbbbbb-0000-0000-0000-000000000001';
const agencePrincipale = 'aaaaaaaa-0000-0000-0001-000000000003';

bool _available = false;

Future<SupabaseClient> connect(String email) async {
  final client = SupabaseClient(_url, _key, authOptions: const AuthClientOptions(autoRefreshToken: false));
  await client.auth.signInWithPassword(email: email, password: _password);
  return client;
}

Future<ContexteSession> contexteDe(SupabaseClient client) async => ContexteSessionModel.fromJson(
      await SupabaseContexteRemoteDataSource(client).fetch(),
      userId: client.auth.currentUser!.id,
      chargeLe: DateTime.now(),
      depuisCache: false,
    );

void skipIfOffline() {
  if (!_available) markTestSkipped('Supabase Local indisponible (supabase start)');
}

void main() {
  setUpAll(() async {
    try {
      final c = await connect('admin@alpha.test');
      await c.dispose();
      _available = true;
    } catch (e) {
      _available = false;
    }
  });

  group('Auth', () {
    test('mot de passe incorrect → erreur traduisible, sans détail technique', () async {
      if (!_available) return skipIfOffline();
      final client = SupabaseClient(_url, _key);
      try {
        await client.auth.signInWithPassword(email: 'admin@alpha.test', password: 'faux');
        fail('connexion inattendue');
      } catch (e) {
        expect(ErrorMapper.map(e).kind, FailureKind.invalidCredentials);
      }
    });

    test('connexion puis déconnexion', () async {
      if (!_available) return skipIfOffline();
      final client = await connect('vendeur@alpha.test');
      expect(client.auth.currentSession, isNotNull);
      await client.auth.signOut();
      expect(client.auth.currentSession, isNull);
    });
  });

  group('Contexte de session', () {
    test('vendeur Alpha : entreprise, abonnement, activités, rôle, permissions, périmètres', () async {
      if (!_available) return skipIfOffline();
      final ctx = await contexteDe(await connect('vendeur@alpha.test'));

      expect(ctx.etat, ContexteEtat.pret);
      expect(ctx.entreprise!.nom, 'Alpha Distribution');
      expect(ctx.abonnement!.planCode, 'MOYEN');
      expect(ctx.activites.map((a) => a.activite.code), ['COMMERCE', 'SERVICES']);
      expect(ctx.membre!.roleCode, 'VENDEUR');
      expect(ctx.permissions, contains('sales.create'));
      expect(ctx.permissions, isNot(contains('users.manage')));
      expect(ctx.perimetres.map((p) => p.nom), ['Boutique Marché']);

      final nav = const NavigationBuilder().build(ctx);
      final codes = nav.sections.expand((s) => s.modules).map((m) => m.code);
      expect(codes, contains('commerce.ventes'));
      expect(codes.where((c) => c.startsWith('immobilier')), isEmpty);
      expect(nav.modulesAdministration.map((m) => m.code), isNot(contains('admin.utilisateurs')));
    });

    test('admin Beta (NORMAL, Immobilier) : un seul utilisateur', () async {
      if (!_available) return skipIfOffline();
      final ctx = await contexteDe(await connect('admin@beta.test'));
      expect(ctx.abonnement!.planCode, 'NORMAL');
      final limites = ctx.limites();
      expect(limites.maxUtilisateurs, 1);
      expect((limites.canAddUser() as AccessDenied).ruleCode, RuleCodes.usersLimit);
    });
  });

  group('Socle étape 1', () {
    test('profil d\'entreprise modifié par l\'admin, tracé dans le journal', () async {
      if (!_available) return skipIfOffline();
      final admin = await connect('admin@alpha.test');
      final repo = EntrepriseRepositoryImpl(admin);
      final avant = await repo.profil(alpha);
      expect(avant.devise, 'XOF');

      final telephone = '+223 ${DateTime.now().millisecondsSinceEpoch % 100000000}';
      await repo.enregistrerProfil(avant.copyWith(telephone: telephone, ville: 'Bamako'));
      expect((await repo.profil(alpha)).telephone, telephone);

      final journal = await AuditRepositoryImpl(admin).lister(alpha, limite: 5);
      final entree = journal.firstWhere((e) => e.entiteType == 'entreprises');
      expect(entree.apres['telephone'], telephone);
      expect(entree.auteurNom, 'Awa Diallo');
    });

    test('vendeur : ni modification du profil, ni lecture du journal', () async {
      if (!_available) return skipIfOffline();
      final vendeur = await connect('vendeur@alpha.test');
      final repo = EntrepriseRepositoryImpl(vendeur);
      final profil = await repo.profil(alpha);
      await repo.enregistrerProfil(profil.copyWith(telephone: '000'));
      // RLS : la mise à jour ne touche aucune ligne.
      expect((await repo.profil(alpha)).telephone, isNot('000'));
      expect(await AuditRepositoryImpl(vendeur).lister(alpha), isEmpty);
    });

    test('formules NORMAL / MOYEN / PRO et leurs prix', () async {
      if (!_available) return skipIfOffline();
      final offres = await EntrepriseRepositoryImpl(await connect('admin@beta.test')).offres();
      expect({for (final o in offres) o.code: o.prixMensuel}, {'NORMAL': 1000, 'MOYEN': 2000, 'PRO': 5000});
      expect(offres.firstWhere((o) => o.code == 'PRO').maxActivites, 3);
    });
  });

  group('RLS', () {
    test('aucune donnée d\'Alpha n\'est accessible à Beta', () async {
      if (!_available) return skipIfOffline();
      final client = await connect('admin@beta.test');

      final entreprises = await client.from('entreprises').select('id');
      expect(entreprises.map((e) => e['id']), [beta]);
      expect(await client.from('perimetres').select().eq('entreprise_id', alpha), isEmpty);
      expect(await client.from('membres_entreprise').select().eq('entreprise_id', alpha), isEmpty);
      final modifies = await client
          .from('perimetres')
          .update({'nom': 'piraté'})
          .eq('entreprise_id', alpha)
          .select();
      expect(modifies, isEmpty);
    });

    test('superviseur : uniquement sa boutique', () async {
      if (!_available) return skipIfOffline();
      final client = await connect('superviseur@alpha.test');
      final rows = await client.from('perimetres').select('nom');
      expect(rows.map((r) => r['nom']), ['Boutique Centre']);
    });
  });

  group('Synchronisation Supabase', () {
    test('sync_push : appliqué, rejoué sans double effet, conflit sur version périmée', () async {
      if (!_available) return skipIfOffline();
      final client = await connect('admin@alpha.test');
      final gateway = SupabaseSyncGateway(client);
      final avant = await client.from('perimetres').select().eq('id', agencePrincipale).single();
      final version = avant['version'] as int;
      final nomOrigine = avant['nom'] as String;

      SyncOperation op(String id, int base, String nom) => SyncOperation(
            id: id,
            userId: client.auth.currentUser!.id,
            entityTable: 'perimetres',
            recordId: agencePrincipale,
            type: SyncOperationType.update,
            payload: {'nom': nom},
            baseVersion: base,
            status: SyncOpStatus.pending,
            attempts: 0,
            createdAt: DateTime.now(),
          );

      final opId = const Uuid().v4();
      final applique = await gateway.push(op(opId, version, 'Agence test'));
      expect(applique.status, PushStatus.applied);
      expect(applique.row!['version'], version + 1);

      final rejoue = await gateway.push(op(opId, version, 'Agence test'));
      expect(rejoue.replayed, isTrue);
      expect(rejoue.row!['version'], version + 1);

      final conflit = await gateway.push(op(const Uuid().v4(), version, 'Autre'));
      expect(conflit.status, PushStatus.conflict);

      final restaure = await gateway.push(op(const Uuid().v4(), version + 1, nomOrigine));
      expect(restaure.status, PushStatus.applied);
    });

    test('limite d\'abonnement appliquée par le serveur (3e boutique en MOYEN)', () async {
      if (!_available) return skipIfOffline();
      final client = await connect('admin@alpha.test');
      try {
        await SupabaseSyncGateway(client).push(SyncOperation(
          id: const Uuid().v4(),
          userId: client.auth.currentUser!.id,
          entityTable: 'perimetres',
          recordId: const Uuid().v4(),
          type: SyncOperationType.insert,
          payload: {
            'entreprise_id': alpha,
            'activite_code': 'COMMERCE',
            'type': 'BOUTIQUE',
            'nom': 'Boutique 3',
          },
          baseVersion: null,
          status: SyncOpStatus.pending,
          attempts: 0,
          createdAt: DateTime.now(),
        ));
        fail('création inattendue');
      } on Failure catch (f) {
        expect(f.kind, FailureKind.businessRule);
        expect(f.ruleCode, RuleCodes.perimetresLimit);
        expect(f.params['max'], 2);
      }
    });

    test('descente filtrée par RLS : le vendeur ne reçoit que sa boutique', () async {
      if (!_available) return skipIfOffline();
      final client = await connect('vendeur@alpha.test');
      final rows = await SupabaseSyncGateway(client)
          .pull(table: 'perimetres', entrepriseId: alpha, afterUpdatedAt: null, afterId: null, limit: 100);
      expect(rows.map((r) => r['nom']), ['Boutique Marché']);
    });

    test('bout en bout : SQLite local ⇄ moteur ⇄ Supabase', () async {
      if (!_available) return skipIfOffline();
      final client = await connect('admin@alpha.test');
      final db = memoryDatabase();
      final queue = DriftSyncQueueStore(db);
      final cursors = DriftSyncCursorStore(db);
      final local = PerimetreLocalDataSource(db);
      final engine = SyncEngine(
        queue: queue,
        remote: SupabaseSyncGateway(client),
        cursors: cursors,
        connectivity: FakeConnectivity(),
        handlers: [PerimetresSyncHandler(local, cursors)],
        periodicInterval: const Duration(days: 1),
      );
      final repository = PerimetreRepositoryImpl(
        local: local,
        queue: queue,
        transaction: (action) => db.transaction(action),
        currentUserId: () => client.auth.currentUser!.id,
        requestSync: () {},
      );
      addTearDown(() async {
        await engine.dispose();
        await db.close();
      });

      await engine.setScope(SyncScope(userId: client.auth.currentUser!.id, entrepriseId: alpha));
      await engine.syncNow();
      final initiaux = await local.watch(alpha).first;
      expect(initiaux, hasLength(3));

      final agence = initiaux.firstWhere((p) => p.id == agencePrincipale);
      await repository.modifier(agence, nom: 'Agence synchronisée', code: agence.code,
          type: agence.type, estActif: true);
      await engine.syncNow();

      final serveur = await client.from('perimetres').select().eq('id', agencePrincipale).single();
      expect(serveur['nom'], 'Agence synchronisée');
      final apres = (await local.watch(alpha).first).firstWhere((p) => p.id == agencePrincipale);
      expect(apres.syncStatus, RecordSyncStatus.synced);
      expect(apres.version, serveur['version']);

      // Restauration de la donnée de démo.
      await repository.modifier(apres, nom: agence.nom, code: agence.code, type: agence.type, estActif: true);
      await engine.syncNow();
      expect(await queue.pendingCount(client.auth.currentUser!.id), 0);
    });
  });
}
