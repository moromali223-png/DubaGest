@Tags(['integration'])
library;

import 'dart:io';

import 'package:dubagest/core/sync/local/drift_sync_stores.dart';
import 'package:dubagest/core/sync/remote/supabase_sync_gateway.dart';
import 'package:dubagest/core/sync/sync_engine.dart';
import 'package:dubagest/core/sync/sync_models.dart';
import 'package:dubagest/features/documents/data/document_repository_impl.dart';
import 'package:dubagest/features/documents/domain/entities/document.dart';
import 'package:dubagest/features/documents/domain/usecases/gerer_documents.dart';
import 'package:dubagest/features/finances/data/datasources/finances_local_data_source.dart';
import 'package:dubagest/features/finances/data/repositories/finances_repository_impl.dart';
import 'package:dubagest/features/finances/domain/entities/finances.dart';
import 'package:dubagest/features/finances/domain/usecases/gerer_finances.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_sync_server.dart' show FakeConnectivity;
import '../helpers/test_database.dart';
import 'supabase_integration_test.dart' show alpha, connect, contexteDe;

/// Reçus numérotés contre Supabase Local ; écritures effacées à la fin.
bool _available = false;

Future<void> _nettoyer() => Process.run('docker', [
      'exec', 'supabase_db_dubagest', 'psql', '-U', 'postgres', '-c',
      'delete from public.documents; delete from public.numero_blocs; delete from public.document_series; '
          'delete from public.depenses; delete from public.caisse_mouvements; '
          'delete from public.paiement_affectations; delete from public.paiements;',
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

  test('réserve de numéros en ligne, reçus émis hors-ligne, numéros confirmés par le serveur', () async {
    if (!_available) return markTestSkipped('Supabase Local indisponible (supabase start)');
    final client = await connect('vendeur@alpha.test');
    final uid = client.auth.currentUser!.id;
    final ctx = await contexteDe(client);
    final db = memoryDatabase();
    final queue = DriftSyncQueueStore(db);
    final cursors = DriftSyncCursorStore(db);
    final finances = FinancesLocalDataSource(db);
    final docs = DocumentLocalDataSource(db);
    final reseau = FakeConnectivity();
    final engine = SyncEngine(
      queue: queue,
      remote: SupabaseSyncGateway(client),
      cursors: cursors,
      connectivity: reseau,
      handlers: [...financesSyncHandlers(finances, cursors), documentsSyncHandler(docs, cursors)],
      periodicInterval: const Duration(days: 1),
    );
    var enLigne = true;
    final repoFinances =
        FinancesRepositoryImpl(local: finances, queue: queue, currentUserId: () => uid, requestSync: () {});
    final repoDocs = DocumentRepositoryImpl(
        local: docs, queue: queue, client: () => enLigne ? client : null, requestSync: () {});
    addTearDown(() async {
      await engine.dispose();
      await db.close();
      await client.dispose();
    });
    await engine.setScope(SyncScope(userId: uid, entrepriseId: alpha));

    // En ligne : réserve de numéros pour cet appareil.
    await AssurerNumeros(repoDocs).call(ctx, appareilId: 'appareil-integration');
    final blocs = await repoDocs.blocs(alpha, uid, TypeDocument.recu, DateTime.now().year);
    expect(blocs.single.restant, AssurerNumeros.taille);

    // Hors-ligne : deux encaissements et leurs reçus.
    enLigne = false;
    reseau.online = false;
    final recus = <Document>[];
    for (final montant in [7500, 2500]) {
      final p = await EnregistrerPaiement(repoFinances).call(ctx, await finances.charger(alpha), SaisiePaiement(
          sens: SensPaiement.entree, montant: montant, mode: ModePaiement.mobileMoney,
          perimetreId: 'aaaaaaaa-0000-0000-0001-000000000002'));
      recus.add(await EmettreRecu(repoDocs).call(ctx,
          etat: await finances.charger(alpha), paiement: p, existants: recus, appareilId: 'appareil-integration'));
    }
    final debut = blocs.single.debut;
    final annee = DateTime.now().year;
    expect(recus.map((r) => r.numero),
        [formatNumero('REC', annee, debut), formatNumero('REC', annee, debut + 1)]);

    // Retour du réseau : paiements puis reçus envoyés, numéros identiques côté serveur.
    reseau.online = true;
    enLigne = true;
    await engine.syncNow();
    expect(await queue.pendingCount(uid), 0);
    final serveur = await client.from('documents').select('numero, montant').order('numero', ascending: true);
    expect([for (final r in serveur) (r['numero'], r['montant'])],
        [(recus[0].numero, 7500), (recus[1].numero, 2500)]);
    final locaux = await docs.watch(alpha).first;
    expect(locaux.every((d) => d.syncStatus == RecordSyncStatus.synced), isTrue);
  });
}
