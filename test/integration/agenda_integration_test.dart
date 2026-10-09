@Tags(['integration'])
library;

import 'dart:io';

import 'package:dubagest/core/sync/local/drift_sync_stores.dart';
import 'package:dubagest/core/sync/remote/supabase_sync_gateway.dart';
import 'package:dubagest/core/sync/sync_engine.dart';
import 'package:dubagest/features/agenda/data/agenda_repository_impl.dart';
import 'package:dubagest/features/agenda/domain/entities/agenda.dart';
import 'package:dubagest/features/agenda/domain/usecases/gerer_agenda.dart';
import 'package:dubagest/features/entreprise/domain/entities/contexte_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/fake_sync_server.dart' show FakeConnectivity;
import '../helpers/test_database.dart';
import 'supabase_integration_test.dart' show alpha, connect, contexteDe;

/// Agenda et notifications contre Supabase Local ; écritures effacées à la fin.
bool _available = false;

Future<void> _nettoyer() => Process.run('docker', [
      'exec', 'supabase_db_dubagest', 'psql', '-U', 'postgres', '-c',
      'delete from public.notifications; delete from public.echeances;',
    ]);

class _Appareil {
  _Appareil(this.client, this.ctx) {
    final db = memoryDatabase();
    local = AgendaLocalDataSource(db);
    queue = DriftSyncQueueStore(db);
    final cursors = DriftSyncCursorStore(db);
    engine = SyncEngine(
      queue: queue,
      remote: SupabaseSyncGateway(client),
      cursors: cursors,
      connectivity: reseau,
      handlers: agendaSyncHandlers(local, cursors),
      periodicInterval: const Duration(days: 1),
    );
    gerer = GererEcheances(
        AgendaRepositoryImpl(local: local, queue: queue, currentUserId: () => ctx.userId, requestSync: () {}));
    _fermer = () async {
      await engine.dispose();
      await db.close();
      await client.dispose();
    };
  }

  final SupabaseClient client;
  final ContexteSession ctx;
  final reseau = FakeConnectivity();
  late final AgendaLocalDataSource local;
  late final DriftSyncQueueStore queue;
  late final SyncEngine engine;
  late final GererEcheances gerer;
  late final Future<void> Function() _fermer;

  static Future<_Appareil> de(String email) async {
    final client = await connect(email);
    final a = _Appareil(client, await contexteDe(client));
    await a.engine.setScope(SyncScope(userId: a.ctx.userId, entrepriseId: alpha));
    return a;
  }

  Future<void> fermer() => _fermer();
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

  test('tâche confiée hors-ligne, notifiée, faite par le responsable, auteur notifié', () async {
    if (!_available) return markTestSkipped('Supabase Local indisponible (supabase start)');
    final chef = await _Appareil.de('superviseur@alpha.test');
    final vendeur = await _Appareil.de('vendeur@alpha.test');
    addTearDown(chef.fermer);
    addTearDown(vendeur.fermer);

    // Le superviseur crée et modifie la tâche sans réseau (création + modification séparées).
    chef.reseau.online = false;
    final e = await chef.gerer.creer(chef.ctx, SaisieEcheance(
      type: TypeEcheance.relance,
      titre: 'IT relancer Amadou',
      dateHeure: DateTime.now().add(const Duration(days: 1)),
      responsableId: vendeur.ctx.userId,
      cibleType: CibleType.contact,
      cibleId: 'aaaaaaaa-0000-0000-0003-000000000001',
    ));
    final local = (await chef.local.watchEcheances(alpha).first).single;
    await chef.gerer.modifier(chef.ctx, local, SaisieEcheance(
      type: TypeEcheance.relance,
      titre: 'IT relancer Amadou (solde)',
      dateHeure: local.dateHeure,
      rappelMinutes: 60,
      responsableId: vendeur.ctx.userId,
    ));
    chef.reseau.online = true;
    await chef.engine.syncNow();
    expect(await chef.queue.pendingCount(chef.ctx.userId), 0);

    final serveur = await chef.client.from('echeances').select().eq('id', e.id).single();
    expect((serveur['titre'], serveur['rappel_minutes'], serveur['responsable_nom']),
        ('IT relancer Amadou (solde)', 60, 'Fatou Keita'));

    // Le vendeur reçoit la tâche et la notification, puis la marque faite.
    await vendeur.engine.syncNow();
    final notifs = await vendeur.local.watchNotifications(alpha, vendeur.ctx.userId).first;
    expect(notifs.single.type, TypeNotification.echeanceConfiee);
    expect(notifs.single.auteurNom, 'Moussa Traoré');
    final tache = (await vendeur.local.watchEcheances(alpha).first).single;
    await vendeur.gerer.changerStatut(vendeur.ctx, tache, StatutEcheance.fait);
    await vendeur.gerer.marquerLue(notifs.single);
    await vendeur.engine.syncNow();
    expect(await vendeur.queue.pendingCount(vendeur.ctx.userId), 0);

    // Le superviseur est notifié que la tâche est faite.
    await chef.engine.syncNow();
    final retour = await chef.local.watchNotifications(alpha, chef.ctx.userId).first;
    expect(retour.single.type, TypeNotification.echeanceFaite);
    expect((await chef.local.watchEcheances(alpha).first).single.statut, StatutEcheance.fait);
  });
}
