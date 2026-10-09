import 'package:dubagest/core/database/app_database.dart';
import 'package:dubagest/core/sync/local/drift_sync_stores.dart';
import 'package:dubagest/core/sync/sync_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftSyncQueueStore queue;

  setUp(() {
    db = memoryDatabase();
    queue = DriftSyncQueueStore(db);
  });
  tearDown(() => db.close());

  Future<void> enqueue(SyncOperationType type, Map<String, dynamic> payload,
          {String record = 'r1', String user = 'u1', int? base}) =>
      queue.enqueue(
        userId: user,
        entityTable: 'perimetres',
        recordId: record,
        type: type,
        payload: payload,
        baseVersion: base,
      );

  Future<List<SyncOperation>> due([String user = 'u1']) => queue.due(user, DateTime.now());

  group('fusion des opérations en attente', () {
    test('création puis modification → une seule création avec les dernières valeurs', () async {
      await enqueue(SyncOperationType.insert, {'nom': 'A', 'code': 'X'});
      await enqueue(SyncOperationType.update, {'nom': 'B'});
      final ops = await due();
      expect(ops, hasLength(1));
      expect(ops.single.type, SyncOperationType.insert);
      expect(ops.single.payload, {'nom': 'B', 'code': 'X'});
    });

    test('création puis suppression avant envoi → rien à envoyer', () async {
      await enqueue(SyncOperationType.insert, {'nom': 'A'});
      await enqueue(SyncOperationType.delete, {});
      expect(await due(), isEmpty);
    });

    test('modifications successives → version de base d\'origine conservée', () async {
      await enqueue(SyncOperationType.update, {'nom': 'A'}, base: 3);
      await enqueue(SyncOperationType.update, {'code': 'Z'}, base: 3);
      final op = (await due()).single;
      expect(op.payload, {'nom': 'A', 'code': 'Z'});
      expect(op.baseVersion, 3);
    });

    test('modification puis suppression → suppression', () async {
      await enqueue(SyncOperationType.update, {'nom': 'A'}, base: 2);
      await enqueue(SyncOperationType.delete, {}, base: 2);
      final op = (await due()).single;
      expect(op.type, SyncOperationType.delete);
      expect(op.baseVersion, 2);
    });

    test('opération en cours d\'envoi : la suivante est mise en file à part puis rebasée', () async {
      await enqueue(SyncOperationType.insert, {'nom': 'A'});
      final first = (await due()).single;
      await queue.markSyncing(first.id);
      await enqueue(SyncOperationType.update, {'nom': 'B'});

      expect(await due(), hasLength(1), reason: 'l\'opération en cours n\'est pas « due »');
      await queue.remove(first.id);
      await queue.rebase('perimetres', 'r1', 1);
      final next = (await due()).single;
      expect(next.type, SyncOperationType.update);
      expect(next.baseVersion, 1);
    });
  });

  test('ordre de création respecté et isolation par utilisateur', () async {
    await enqueue(SyncOperationType.insert, {'n': 1}, record: 'a');
    await enqueue(SyncOperationType.insert, {'n': 2}, record: 'b');
    await enqueue(SyncOperationType.insert, {'n': 3}, record: 'c', user: 'autre');
    expect((await due()).map((o) => o.recordId), ['a', 'b']);
    expect(await queue.pendingCount('u1'), 2);
    expect(await queue.pendingCount('autre'), 1);
  });

  test('échec transitoire : réessai différé et tentatives comptées', () async {
    await enqueue(SyncOperationType.insert, {'n': 1});
    final op = (await due()).single;
    await queue.markFailed(op.id, 'réseau', DateTime.now().add(const Duration(minutes: 1)));

    expect(await due(), isEmpty, reason: 'pas avant la prochaine tentative');
    final later = await queue.due('u1', DateTime.now().add(const Duration(minutes: 2)));
    expect(later.single.attempts, 1);
    expect(later.single.status, SyncOpStatus.failed);
    expect(await queue.pendingCount('u1'), 1, reason: 'toujours en attente');
  });

  test('refus définitif : sort de la file active', () async {
    await enqueue(SyncOperationType.insert, {'n': 1});
    final op = (await due()).single;
    await queue.markRejected(op.id, 'LIMITE_PERIMETRES');
    expect(await due(), isEmpty);
    expect(await queue.pendingCount('u1'), 0);
  });

  test('reprise après interruption : SYNCING → PENDING', () async {
    await enqueue(SyncOperationType.insert, {'n': 1});
    await queue.markSyncing((await due()).single.id);
    expect(await due(), isEmpty);
    await queue.recoverInterrupted('u1');
    expect(await due(), hasLength(1));
  });
}
