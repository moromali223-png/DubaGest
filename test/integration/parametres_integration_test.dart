@Tags(['integration'])
library;

import 'dart:io';

import 'package:dubagest/core/database/json_cache_store.dart';
import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/core/sync/local/drift_sync_stores.dart';
import 'package:dubagest/core/sync/remote/supabase_sync_gateway.dart';
import 'package:dubagest/core/sync/sync_engine.dart';
import 'package:dubagest/features/entreprise/data/repositories/entreprise_repository_impl.dart';
import 'package:dubagest/features/finances/data/datasources/finances_local_data_source.dart';
import 'package:dubagest/features/finances/data/repositories/finances_repository_impl.dart';
import 'package:dubagest/features/finances/domain/entities/finances.dart';
import 'package:dubagest/features/finances/domain/usecases/gerer_finances.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_sync_server.dart' show FakeConnectivity;
import '../helpers/test_database.dart';
import 'supabase_integration_test.dart' show alpha, connect, contexteDe;

/// Paramètres d'encaissement contre Supabase Local ; remis à l'état initial à la fin.
bool _available = false;

Future<void> _psql(List<String> ordres) => Process.run('docker', [
      'exec', 'supabase_db_dubagest', 'psql', '-U', 'postgres',
      for (final o in ordres) ...['-c', o],
    ]);

Future<void> _nettoyer() => _psql([
      'delete from public.caisse_mouvements',
      'delete from public.paiement_affectations',
      'delete from public.paiements',
      "update public.entreprises set modes_paiement = default, pied_recu = null where id = '$alpha'",
      "update public.entreprises set modes_paiement_modifies_le = null where id = '$alpha'",
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

  test('l\'administration règle les modes ; un mode retiré est refusé par le serveur, même hors-ligne', () async {
    if (!_available) return markTestSkipped('Supabase Local indisponible (supabase start)');
    final admin = await connect('admin@alpha.test');
    final db = memoryDatabase();
    addTearDown(() async {
      await db.close();
      await admin.dispose();
    });
    final repoAdmin = EntrepriseRepositoryImpl(admin, cache: JsonCacheStore(db));
    await repoAdmin.enregistrerParametres(alpha, modesPaiement: ['ESPECES', 'MOBILE_MONEY'], piedRecu: ' Merci ');
    final profil = await repoAdmin.profil(alpha);
    expect(profil.modesPaiement, ['ESPECES', 'MOBILE_MONEY']);
    expect(profil.piedRecu, 'Merci');

    // Le vendeur ne peut pas les changer : la RLS masque la ligne, signalé comme refus.
    final vendeur = await connect('vendeur@alpha.test');
    addTearDown(vendeur.dispose);
    await expectLater(
      EntrepriseRepositoryImpl(vendeur).enregistrerParametres(alpha, modesPaiement: ['CARTE']),
      throwsA(isA<Failure>().having((f) => f.kind, 'type', FailureKind.forbidden)),
    );

    // Changement fait la veille : un paiement par carte saisi hors-ligne aujourd'hui est refusé.
    await _psql(["update public.entreprises set modes_paiement_modifies_le = now() - interval '1 day' where id = '$alpha'"]);
    final uid = vendeur.auth.currentUser!.id;
    final ctx = await contexteDe(vendeur);
    final finances = FinancesLocalDataSource(db);
    final queue = DriftSyncQueueStore(db);
    final cursors = DriftSyncCursorStore(db);
    final engine = SyncEngine(
      queue: queue, remote: SupabaseSyncGateway(vendeur), cursors: cursors, connectivity: FakeConnectivity(),
      handlers: financesSyncHandlers(finances, cursors), periodicInterval: const Duration(days: 1),
    );
    addTearDown(engine.dispose);
    await engine.setScope(SyncScope(userId: uid, entrepriseId: alpha));
    final repo = FinancesRepositoryImpl(local: finances, queue: queue, currentUserId: () => uid, requestSync: () {});
    Future<Paiement> payer(ModePaiement mode) async => EnregistrerPaiement(repo).call(ctx, await finances.charger(alpha),
        SaisiePaiement(sens: SensPaiement.entree, montant: 1000, mode: mode, perimetreId: 'aaaaaaaa-0000-0000-0001-000000000002'));
    final carte = await payer(ModePaiement.carte);
    final mobile = await payer(ModePaiement.mobileMoney);
    await engine.syncNow();

    final etat = await finances.charger(alpha);
    expect(etat.paiement(carte.id)?.refuse, isTrue, reason: 'MODE_PAIEMENT_DESACTIVE');
    expect(etat.paiement(mobile.id)?.refuse, isFalse);
  });
}
