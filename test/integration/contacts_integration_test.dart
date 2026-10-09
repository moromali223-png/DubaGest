@Tags(['integration'])
library;

import 'dart:io';

import 'package:dubagest/core/errors/error_mapper.dart';
import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/core/sync/local/drift_sync_stores.dart';
import 'package:dubagest/core/sync/remote/supabase_sync_gateway.dart';
import 'package:dubagest/core/sync/sync_engine.dart';
import 'package:dubagest/core/sync/sync_models.dart';
import 'package:dubagest/features/contacts/data/datasources/contact_local_data_source.dart';
import 'package:dubagest/features/contacts/data/repositories/contact_repository_impl.dart';
import 'package:dubagest/features/contacts/domain/entities/contact.dart';
import 'package:dubagest/features/contacts/domain/usecases/gerer_contacts.dart';
import 'package:dubagest/features/modules/domain/entities/app_module.dart';
import 'package:dubagest/features/navigation/domain/services/navigation_builder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_sync_server.dart' show FakeConnectivity;
import '../helpers/test_database.dart';
import 'supabase_integration_test.dart' show alpha, beta, connect, contexteDe;

/// Contacts contre Supabase Local (`supabase start` + seed).
/// Les fiches créées ici sont préfixées « IT- » et supprimées à la fin.
bool _available = false;

Future<void> _nettoyer() => Process.run('docker', [
      'exec',
      'supabase_db_dubagest',
      'psql',
      '-U',
      'postgres',
      '-c',
      "delete from public.contacts where nom like 'IT-%';",
    ]);

void main() {
  setUpAll(() async {
    try {
      final c = await connect('admin@alpha.test');
      await c.dispose();
      _available = true;
    } catch (_) {
      _available = false;
    }
  });
  tearDownAll(() async {
    if (_available) await _nettoyer();
  });

  void skip() => markTestSkipped('Supabase Local indisponible (supabase start)');

  test('contexte : Contacts est un module commun, les modules « Clients » ont disparu', () async {
    if (!_available) return skip();
    final client = await connect('vendeur@alpha.test');
    final ctx = await contexteDe(client);
    final nav = const NavigationBuilder().build(ctx);
    expect(nav.modulesCommuns.map((m) => m.code), contains(ModuleCodes.communContacts));
    expect(ctx.modules.map((m) => m.code), isNot(contains('commerce.clients')));
    expect(ctx.modules.map((m) => m.code), isNot(contains('services.clients')));
  });

  test('RLS : chaque entreprise ne voit que ses contacts', () async {
    if (!_available) return skip();
    final client = await connect('admin@beta.test');
    final rows = await SupabaseSyncGateway(client)
        .pull(table: 'contacts', entrepriseId: alpha, afterUpdatedAt: null, afterId: null, limit: 100);
    expect(rows, isEmpty);
    final propres = await SupabaseSyncGateway(client)
        .pull(table: 'contacts', entrepriseId: beta, afterUpdatedAt: null, afterId: null, limit: 100);
    expect(propres.every((r) => r['entreprise_id'] == beta), isTrue);
  });

  test('vendeur : archivage refusé par le serveur même en contournant l\'application', () async {
    if (!_available) return skip();
    final client = await connect('vendeur@alpha.test');
    try {
      await client
          .from('contacts')
          .update({'statut': 'ARCHIVE'})
          .eq('id', 'aaaaaaaa-0000-0000-0003-000000000002');
      fail('archivage inattendu');
    } catch (e) {
      expect(ErrorMapper.map(e).kind, isIn([FailureKind.forbidden, FailureKind.businessRule]));
    }
    final ligne = await client.from('contacts').select('statut').eq('id', 'aaaaaaaa-0000-0000-0003-000000000002').single();
    expect(ligne['statut'], 'ACTIF');
  });

  test('bout en bout : création locale ⇄ moteur ⇄ Supabase, puis recherche hors-ligne', () async {
    if (!_available) return skip();
    final client = await connect('admin@alpha.test');
    final uid = client.auth.currentUser!.id;
    final ctx = await contexteDe(client);
    final db = memoryDatabase();
    final queue = DriftSyncQueueStore(db);
    final cursors = DriftSyncCursorStore(db);
    final local = ContactLocalDataSource(db);
    final engine = SyncEngine(
      queue: queue,
      remote: SupabaseSyncGateway(client),
      cursors: cursors,
      connectivity: FakeConnectivity(),
      handlers: [ContactsSyncHandler(local, cursors)],
      periodicInterval: const Duration(days: 1),
    );
    final repository = ContactRepositoryImpl(
      local: local,
      queue: queue,
      currentUserId: () => uid,
      requestSync: () {},
    );
    addTearDown(() async {
      await engine.dispose();
      await db.close();
      await client.dispose();
    });

    await engine.setScope(SyncScope(userId: uid, entrepriseId: alpha));
    await engine.syncNow();
    final seed = await local.watch(alpha, const FiltreContacts()).first;
    expect(seed.map((c) => c.nomAffiche), containsAll(['Amadou Traoré', 'Mariam Sow']));

    // Doublon détecté sur le téléphone de la fiche de démo (autre format).
    final doublons = await DetecterDoublons(repository).call(
      ctx,
      const SaisieContact(typePersonne: TypePersonne.personne, nom: 'IT-Autre', telephone: '70 11 22 33'),
    );
    expect(doublons.map((c) => c.nom), contains('Traoré'));

    final cree = await CreerContact(repository).call(
      ctx,
      const SaisieContact(
        typePersonne: TypePersonne.organisation,
        nom: 'IT-Quincaillerie Keïta',
        telephone: '+223 65 98 76 54',
        ville: 'Kayes',
        relations: {RelationContact.fournisseur, RelationContact.client},
      ),
    );
    await engine.syncNow();

    final serveur = await client.from('contacts').select().eq('id', cree.id).single();
    expect(serveur['relations'], ['CLIENT', 'FOURNISSEUR']);
    expect(serveur['created_by'], uid);
    expect(serveur['telephone_normalise'], '22365987654');
    final synchro = (await local.watch(alpha, const FiltreContacts(recherche: 'quincaillerie keita')).first).single;
    expect((synchro.syncStatus, synchro.version), (RecordSyncStatus.synced, serveur['version']));

    await ArchiverContact(repository).call(ctx, synchro, archiver: true);
    await engine.syncNow();
    final archive = await client.from('contacts').select('statut').eq('id', cree.id).single();
    expect(archive['statut'], 'ARCHIVE');
    expect(await queue.pendingCount(uid), 0);
  });
}
