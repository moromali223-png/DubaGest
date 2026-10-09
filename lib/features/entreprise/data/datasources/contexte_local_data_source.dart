import '../../../../core/database/json_cache_store.dart';

abstract interface class ContexteLocalDataSource {
  Future<CachedJson?> read(String userId);
  Future<void> write(String userId, Map<String, dynamic> json);
}

class DriftContexteLocalDataSource implements ContexteLocalDataSource {
  DriftContexteLocalDataSource(this._store);
  final JsonCacheStore _store;

  static String _key(String userId) => 'contexte:$userId';

  @override
  Future<CachedJson?> read(String userId) => _store.read(_key(userId));

  @override
  Future<void> write(String userId, Map<String, dynamic> json) => _store.write(_key(userId), json);
}
