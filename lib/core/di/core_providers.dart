import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import '../database/json_cache_store.dart';
import '../network/connectivity_service.dart';
import '../sync/local/drift_sync_stores.dart';
import '../sync/remote/supabase_sync_gateway.dart';
import '../sync/sync_contracts.dart';

// Instances créées au démarrage (main.dart) et injectées via overrides.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider non initialisé'),
);
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider non initialisé'),
);
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => throw UnimplementedError('supabaseClientProvider non initialisé'),
);

final connectivityServiceProvider = Provider<ConnectivityService>((ref) => ConnectivityPlusService());

final jsonCacheStoreProvider = Provider<JsonCacheStore>(
  (ref) => JsonCacheStore(ref.watch(appDatabaseProvider)),
);

final syncQueueStoreProvider = Provider<SyncQueueStore>(
  (ref) => DriftSyncQueueStore(ref.watch(appDatabaseProvider)),
);

final syncCursorStoreProvider = Provider<SyncCursorStore>(
  (ref) => DriftSyncCursorStore(ref.watch(appDatabaseProvider)),
);

final syncRemoteGatewayProvider = Provider<SyncRemoteGateway>(
  (ref) => SupabaseSyncGateway(ref.watch(supabaseClientProvider)),
);
