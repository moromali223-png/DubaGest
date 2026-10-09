import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/sync_contracts.dart';
import '../sync/sync_engine.dart';
import '../sync/sync_models.dart';
import 'core_providers.dart';

/// Gestionnaires des entités synchronisées, fournis par la composition de
/// l'application (`app/di`) : le cœur ne dépend d'aucune feature.
final syncHandlersProvider = Provider<List<SyncEntityHandler>>((ref) => const []);

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(
    queue: ref.watch(syncQueueStoreProvider),
    remote: ref.watch(syncRemoteGatewayProvider),
    cursors: ref.watch(syncCursorStoreProvider),
    connectivity: ref.watch(connectivityServiceProvider),
    handlers: ref.watch(syncHandlersProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

final syncStateProvider = StreamProvider<SyncState>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return Stream.multi((controller) {
    controller.add(engine.state);
    final sub = engine.states.listen(controller.add);
    controller.onCancel = sub.cancel;
  });
});

final localTransactionProvider = Provider<LocalTransaction>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (action) => db.transaction(action);
});

final syncTriggerProvider = Provider<SyncTrigger>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return engine.requestSync;
});
