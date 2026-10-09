@Tags(['integration'])
library;

import 'dart:io';

import 'package:dubagest/core/sync/local/drift_sync_stores.dart';
import 'package:dubagest/core/sync/remote/supabase_sync_gateway.dart';
import 'package:dubagest/core/sync/sync_engine.dart';
import 'package:dubagest/core/sync/sync_models.dart';
import 'package:dubagest/features/finances/data/datasources/finances_local_data_source.dart';
import 'package:dubagest/features/finances/data/repositories/finances_repository_impl.dart';
import 'package:dubagest/features/finances/domain/usecases/gerer_depenses.dart';
import 'package:dubagest/features/finances/domain/usecases/gerer_finances.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_sync_server.dart' show FakeConnectivity;
import '../helpers/test_database.dart';
import 'supabase_integration_test.dart' show alpha, connect, contexteDe;

/// Dépenses contre Supabase Local ; écritures effacées à la fin.
const _creanceAmadou = 'aaaaaaaa-0000-0000-0005-000000000001';
bool _available = false;

Future<void> _nettoyer() => Process.run('docker', [
      'exec', 'supabase_db_dubagest', 'psql', '-U', 'postgres', '-c',
      'delete from public.depenses; delete from public.depense_categories where code is null; '
          'delete from public.caisse_mouvements; delete from public.paiement_affectations; '
          'delete from public.paiements; delete from public.caisse_sessions; '
          "delete from public.engagements where id <> '$_creanceAmadou'; "
          "update public.engagements set montant_regle = 0 where id = '$_creanceAmadou';",
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

  test('hors-ligne : dépense en espèces et dépense à payer, puis annulation, contre le vrai serveur', () async {
    if (!_available) return markTestSkipped('Supabase Local indisponible (supabase start)');
    final client = await connect('admin@alpha.test');
    final uid = client.auth.currentUser!.id;
    final ctx = await contexteDe(client);
    final db = memoryDatabase();
    final queue = DriftSyncQueueStore(db);
    final local = FinancesLocalDataSource(db);
    final cursors = DriftSyncCursorStore(db);
    final reseau = FakeConnectivity();
    final engine = SyncEngine(
      queue: queue,
      remote: SupabaseSyncGateway(client),
      cursors: cursors,
      connectivity: reseau,
      handlers: financesSyncHandlers(local, cursors),
      periodicInterval: const Duration(days: 1),
    );
    final repo = FinancesRepositoryImpl(local: local, queue: queue, currentUserId: () => uid, requestSync: () {});
    addTearDown(() async {
      await engine.dispose();
      await db.close();
      await client.dispose();
    });
    await engine.setScope(SyncScope(userId: uid, entrepriseId: alpha));
    await engine.syncNow();

    var e = await local.charger(alpha);
    expect(e.categories.where((c) => c.code != null), hasLength(18), reason: 'catégories fournies, reçues');
    final transport = e.categories.firstWhere((c) => c.code == 'TRANSPORT');
    final caisse = e.caisses.firstWhere((c) => c.nom == 'Caisse Marché');

    reseau.online = false;
    final session = await GererCaisse(repo).ouvrir(ctx, e, caisse, soldeInitial: 20000);
    final payee = await EnregistrerDepense(repo).call(ctx, await local.charger(alpha), SaisieDepense(
        categorieId: transport.id, libelle: 'IT taxi', montant: 5000, payeeMaintenant: true, sessionId: session.id));
    final differee = await EnregistrerDepense(repo).call(ctx, await local.charger(alpha), SaisieDepense(
        categorieId: transport.id, libelle: 'IT transporteur', montant: 30000, payeeMaintenant: false));

    reseau.online = true;
    await engine.syncNow();
    expect(await queue.pendingCount(uid), 0);

    final serveur = await client.from('engagements').select('id, montant_regle, origine_type')
        .inFilter('id', [payee.id, differee.id]);
    expect({for (final r in serveur) r['id']: (r['montant_regle'], r['origine_type'])},
        {payee.id: (5000, 'DEPENSE'), differee.id: (0, 'DEPENSE')});
    final mouvement = await client.from('caisse_mouvements').select('type').eq('id', payee.paiementId!).single();
    expect(mouvement['type'], 'DECAISSEMENT');

    e = await local.charger(alpha);
    expect(e.solde(e.sessions.firstWhere((s) => s.id == session.id)), 15000);
    expect(e.depenses.every((d) => d.syncStatus == RecordSyncStatus.synced), isTrue);
    expect(e.paiement(payee.paiementId!)!.syncStatus, RecordSyncStatus.synced);

    // Annulation hors-ligne : paiement inverse puis dépense, envoyés dans l'ordre.
    reseau.online = false;
    await ModifierDepense(repo, AnnulerPaiement(repo))
        .annuler(ctx, e, e.depenses.firstWhere((d) => d.id == payee.id), motif: 'IT');
    reseau.online = true;
    await engine.syncNow();

    final dep = await client.from('depenses').select('statut').eq('id', payee.id).single();
    final eng = await client.from('engagements').select('statut, montant_regle').eq('id', payee.id).single();
    expect((dep['statut'], eng['statut'], eng['montant_regle']), ('ANNULEE', 'ANNULE', 0));
    e = await local.charger(alpha);
    expect(e.solde(e.sessions.firstWhere((s) => s.id == session.id)), 20000);
    expect(await queue.pendingCount(uid), 0);
  });
}
