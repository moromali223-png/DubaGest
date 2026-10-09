@Tags(['integration'])
library;

import 'dart:io';

import 'package:dubagest/core/database/app_database.dart';
import 'package:dubagest/core/sync/local/drift_sync_stores.dart';
import 'package:dubagest/core/sync/remote/supabase_sync_gateway.dart';
import 'package:dubagest/core/sync/sync_engine.dart';
import 'package:dubagest/core/sync/sync_models.dart';
import 'package:dubagest/features/entreprise/domain/entities/contexte_session.dart';
import 'package:dubagest/features/finances/data/datasources/finances_local_data_source.dart';
import 'package:dubagest/features/finances/data/repositories/finances_repository_impl.dart';
import 'package:dubagest/features/finances/domain/entities/finances.dart';
import 'package:dubagest/features/finances/domain/services/etat_finances.dart';
import 'package:dubagest/features/finances/domain/usecases/gerer_finances.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/fake_sync_server.dart' show FakeConnectivity;
import '../helpers/test_database.dart';
import 'supabase_integration_test.dart' show alpha, connect, contexteDe;

/// Noyau financier contre Supabase Local. Les écritures sont effacées à la
/// fin (sauf les données de démo du seed).
const _caisseMarche = 'aaaaaaaa-0000-0000-0004-000000000002';
const _creanceAmadou = 'aaaaaaaa-0000-0000-0005-000000000001';
const _amadou = 'aaaaaaaa-0000-0000-0003-000000000001';

bool _available = false;

Future<void> _nettoyer() => Process.run('docker', [
      'exec', 'supabase_db_dubagest', 'psql', '-U', 'postgres', '-c',
      'delete from public.depenses; delete from public.depense_categories where code is null; '
          'delete from public.caisse_mouvements; delete from public.paiement_affectations; '
          'delete from public.paiements; delete from public.caisse_sessions; '
          "delete from public.engagements where id <> '$_creanceAmadou'; "
          "update public.engagements set montant_regle = 0 where id = '$_creanceAmadou';",
    ]);

class _Appareil {
  _Appareil(this.client, this.ctx) {
    db = memoryDatabase();
    queue = DriftSyncQueueStore(db);
    local = FinancesLocalDataSource(db);
    final cursors = DriftSyncCursorStore(db);
    engine = SyncEngine(
      queue: queue,
      remote: SupabaseSyncGateway(client),
      cursors: cursors,
      connectivity: reseau,
      handlers: financesSyncHandlers(local, cursors),
      periodicInterval: const Duration(days: 1),
    );
    repo = FinancesRepositoryImpl(local: local, queue: queue, currentUserId: () => uid, requestSync: () {});
  }

  final SupabaseClient client;
  final ContexteSession ctx;
  final reseau = FakeConnectivity();
  late final AppDatabase db;
  late final DriftSyncQueueStore queue;
  late final FinancesLocalDataSource local;
  late final SyncEngine engine;
  late final FinancesRepositoryImpl repo;
  String get uid => client.auth.currentUser!.id;

  static Future<_Appareil> de(String email) async {
    final client = await connect(email);
    final a = _Appareil(client, await contexteDe(client));
    await a.engine.setScope(SyncScope(userId: a.uid, entrepriseId: alpha));
    await a.engine.syncNow();
    return a;
  }

  Future<EtatFinances> etat() => local.charger(alpha);

  Future<void> fermer() async {
    await engine.dispose();
    await db.close();
    await client.dispose();
  }
}

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

  void skip() => markTestSkipped('Supabase Local indisponible (supabase start)');

  test('vendeur hors-ligne : ouverture, encaissement affecté, retrait, clôture — envoyés dans l\'ordre', () async {
    if (!_available) return skip();
    final vendeur = await _Appareil.de('vendeur@alpha.test');
    final admin = await _Appareil.de('admin@alpha.test');
    addTearDown(vendeur.fermer);
    addTearDown(admin.fermer);

    var e = await vendeur.etat();
    expect(e.caisses.map((c) => c.id), [_caisseMarche], reason: 'RLS : la caisse de sa boutique seulement');
    expect(e.engagements.map((x) => x.id), contains(_creanceAmadou));

    // Tout hors-ligne : l'ouverture et la clôture ne doivent pas fusionner.
    vendeur.reseau.online = false;
    final caisses = GererCaisse(vendeur.repo);
    final session = await caisses.ouvrir(vendeur.ctx, e, e.caisses.single, soldeInitial: 10000);
    await EnregistrerPaiement(vendeur.repo).call(vendeur.ctx, await vendeur.etat(), SaisiePaiement(
      sens: SensPaiement.entree,
      montant: 20000,
      mode: ModePaiement.especes,
      contactId: _amadou,
      sessionId: session.id,
      affectations: {_creanceAmadou: 20000},
    ));
    e = await vendeur.etat();
    await caisses.mouvement(vendeur.ctx, e, e.sessions.single, type: TypeMouvement.retrait, montant: 5000, motif: 'IT');
    // La clôture demande cash.close : le vendeur ne l'a pas.
    final etatVendeur = await vendeur.etat();
    await expectLater(caisses.cloturer(vendeur.ctx, etatVendeur, etatVendeur.sessions.single, soldeReel: 25000),
        throwsA(anything));

    vendeur.reseau.online = true;
    await vendeur.engine.syncNow();
    expect(await vendeur.queue.pendingCount(vendeur.uid), 0);
    final creance = await vendeur.client.from('engagements').select('montant_regle').eq('id', _creanceAmadou).single();
    expect(creance['montant_regle'], 20000);
    e = await vendeur.etat();
    expect(e.solde(e.sessions.single), 25000);
    expect(e.paiements.single.syncStatus, RecordSyncStatus.synced);

    // L'administrateur clôture depuis son appareil : écart calculé par le serveur.
    await admin.engine.syncNow();
    final etatAdmin = await admin.etat();
    await GererCaisse(admin.repo).cloturer(admin.ctx, etatAdmin, etatAdmin.sessions.single, soldeReel: 24000, note: 'IT');
    await admin.engine.syncNow();
    final ferme = await admin.client.from('caisse_sessions').select().eq('id', session.id).single();
    expect((ferme['statut'], ferme['solde_theorique'], ferme['ecart']), ('FERMEE', 25000, -1000));
    final local = (await admin.etat()).sessions.single;
    expect((local.ouverte, local.ecart), (false, -1000), reason: 'résultat serveur redescendu');
  });

  test('annulation : paiement inverse, créance de nouveau due ; refus serveur visible et retirable', () async {
    if (!_available) return skip();
    final admin = await _Appareil.de('admin@alpha.test');
    addTearDown(admin.fermer);

    final dette = await CreerEngagement(admin.repo).call(admin.ctx,
        const SaisieEngagement(sens: SensEngagement.aPayer, libelle: 'IT fournisseur', montant: 9000));
    final p = await EnregistrerPaiement(admin.repo).call(admin.ctx, await admin.etat(), SaisiePaiement(
        sens: SensPaiement.sortie, montant: 9000, mode: ModePaiement.virement, affectations: {dette.id: 9000}));
    await admin.engine.syncNow();
    var e = await admin.etat();
    expect(e.suivi(e.engagements.firstWhere((x) => x.id == dette.id)).reste, 0);

    await AnnulerPaiement(admin.repo).call(admin.ctx, e, e.paiement(p.id)!);
    await admin.engine.syncNow();
    final origine = await admin.client.from('paiements').select('statut').eq('id', p.id).single();
    expect(origine['statut'], 'ANNULE');
    e = await admin.etat();
    expect(e.paiement(p.id)!.annuleServeur, isTrue);
    expect(e.suivi(e.engagements.firstWhere((x) => x.id == dette.id)).reste, 9000);

    // Deux appareils encaissent la même dette hors-ligne : le second est refusé.
    final autre = await _Appareil.de('admin@alpha.test');
    addTearDown(autre.fermer);
    admin.reseau.online = false;
    autre.reseau.online = false;
    for (final appareil in [admin, autre]) {
      await EnregistrerPaiement(appareil.repo).call(appareil.ctx, await appareil.etat(), SaisiePaiement(
          sens: SensPaiement.sortie, montant: 9000, mode: ModePaiement.virement, affectations: {dette.id: 9000}));
    }
    admin.reseau.online = true;
    await admin.engine.syncNow();
    autre.reseau.online = true;
    await autre.engine.syncNow();

    e = await autre.etat();
    final refuse = e.paiements.firstWhere((x) => x.refuse);
    expect(e.suivi(e.engagements.firstWhere((x) => x.id == dette.id)).reste, 0,
        reason: 'le paiement accepté (autre appareil) est compté, le refusé non');
    await RetirerEcritureRefusee(autre.repo).call('paiements', refuse.id);
    expect((await autre.etat()).paiements.where((x) => x.refuse), isEmpty);
  });
}
