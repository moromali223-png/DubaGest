@Tags(['integration'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:dubagest/core/database/json_cache_store.dart';
import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/core/sync/local/drift_sync_stores.dart';
import 'package:dubagest/core/sync/remote/supabase_sync_gateway.dart';
import 'package:dubagest/core/sync/sync_engine.dart';
import 'package:dubagest/features/agenda/domain/entities/agenda.dart';
import 'package:dubagest/features/entreprise/data/logo_entreprise.dart';
import 'package:dubagest/features/fichiers/data/fichiers_repository_impl.dart';
import 'package:dubagest/features/fichiers/domain/fichiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_sync_server.dart' show FakeConnectivity;
import '../helpers/test_database.dart';
import 'supabase_integration_test.dart' show alpha, connect, contexteDe;

/// Notes, pièces jointes et logo contre Supabase Local (stockage compris).
const _amadou = 'aaaaaaaa-0000-0000-0003-000000000001';
const _creance = 'aaaaaaaa-0000-0000-0005-000000000001';
bool _available = false;

// PNG 1×1 valide.
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00,
  0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0, 0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D,
  0x1D, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Un ordre par `-c` : chacun dans sa transaction. (Supabase interdit la
/// suppression directe dans storage.objects : cet ordre peut échouer seul ;
/// les fichiers de test restants sont sans effet, leurs chemins sont uniques.)
Future<void> _nettoyer() => Process.run('docker', [
      'exec', 'supabase_db_dubagest', 'psql', '-U', 'postgres',
      '-c', 'delete from public.notes',
      '-c', 'delete from public.pieces_jointes',
      '-c', "update public.entreprises set logo_path = null where id = '$alpha'",
      '-c', "delete from storage.objects where bucket_id = 'fichiers'",
    ]);

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

  test('justificatif envoyé, lu par lien temporaire ; refusé au vendeur sur une créance ; note synchronisée', () async {
    if (!_available) return markTestSkipped('Supabase Local indisponible (supabase start)');
    final client = await connect('admin@alpha.test');
    final ctx = await contexteDe(client);
    final db = memoryDatabase();
    final local = FichiersLocalDataSource(db);
    final queue = DriftSyncQueueStore(db);
    final cursors = DriftSyncCursorStore(db);
    final engine = SyncEngine(
      queue: queue, remote: SupabaseSyncGateway(client), cursors: cursors, connectivity: FakeConnectivity(),
      handlers: fichiersSyncHandlers(local, cursors), periodicInterval: const Duration(days: 1),
    );
    final repo = FichiersRepositoryImpl(
        local: local, queue: queue, client: () => client, currentUserId: () => ctx.userId, requestSync: () {});
    addTearDown(() async {
      await engine.dispose();
      await db.close();
      await client.dispose();
    });
    await engine.setScope(SyncScope(userId: ctx.userId, entrepriseId: alpha));
    final g = GererFichiers(repo);

    final piece = await g.ajouterPiece(ctx, CibleType.contact, _amadou,
        FichierChoisi(nom: 'carte.png', octets: _png, typeMime: 'image/png'));
    expect(piece.chemin, startsWith('$alpha/pj/CONTACT/$_amadou/'));
    final url = await repo.lienTemporaire(piece.chemin);
    final http = HttpClient();
    addTearDown(http.close);
    final reponse = await (await http.getUrl(Uri.parse(url))).close();
    final octets = await reponse.fold<List<int>>([], (t, b) => t..addAll(b));
    expect((reponse.statusCode, octets.length), (200, _png.length));

    final note = await g.ajouterNote(ctx, CibleType.contact, _amadou, 'IT note');
    await engine.syncNow();
    final serveur = await client.from('notes').select('texte, auteur_nom').eq('id', note.id).single();
    expect((serveur['texte'], serveur['auteur_nom']), ('IT note', 'Awa Diallo'));

    // Le vendeur ne peut pas déposer de fichier sur une créance (règle du stockage).
    final vendeur = await connect('vendeur@alpha.test');
    addTearDown(vendeur.dispose);
    final vctx = await contexteDe(vendeur);
    final vrepo = FichiersRepositoryImpl(
        local: local, queue: queue, client: () => vendeur, currentUserId: () => vctx.userId, requestSync: () {});
    await expectLater(
      vrepo.ajouterPiece(entrepriseId: alpha, type: CibleType.engagement, cibleId: _creance,
          fichier: FichierChoisi(nom: 'x.png', octets: _png, typeMime: 'image/png')),
      throwsA(isA<Failure>()),
    );
  });

  test('logo : envoyé par l\'administration, copie locale pour les reçus hors-ligne', () async {
    if (!_available) return markTestSkipped('Supabase Local indisponible (supabase start)');
    final client = await connect('admin@alpha.test');
    final db = memoryDatabase();
    addTearDown(() async {
      await db.close();
      await client.dispose();
    });
    final logo = LogoEntreprise(client: () => client, cache: JsonCacheStore(db));
    await logo.envoyer(alpha, _png, 'image/png');
    final chemin = (await client.from('entreprises').select('logo_path').eq('id', alpha).single())['logo_path'] as String;
    expect(chemin, startsWith('$alpha/logo/'));

    // Autre appareil : récupère le logo une fois, puis le relit hors-ligne.
    final autreDb = memoryDatabase();
    addTearDown(autreDb.close);
    final autre = LogoEntreprise(client: () => client, cache: JsonCacheStore(autreDb));
    expect(await autre.synchroniser(alpha, chemin), _png);
    final horsLigne = LogoEntreprise(client: () => null, cache: JsonCacheStore(autreDb));
    expect(await horsLigne.local(alpha), _png);

    final vendeur = await connect('vendeur@alpha.test');
    addTearDown(vendeur.dispose);
    await expectLater(
      LogoEntreprise(client: () => vendeur, cache: JsonCacheStore(autreDb)).envoyer(alpha, _png, 'image/png'),
      throwsA(isA<Failure>()),
    );
  });
}
