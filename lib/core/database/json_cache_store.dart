import 'dart:convert';

import 'app_database.dart';

class CachedJson {
  const CachedJson(this.data, this.storedAt);
  final Map<String, dynamic> data;
  final DateTime storedAt;
}

/// Stockage clé → document JSON pour les données consultables hors-ligne.
class JsonCacheStore {
  JsonCacheStore(this._db);
  final AppDatabase _db;

  Future<CachedJson?> read(String key) async {
    final row = await (_db.select(_db.jsonCache)..where((t) => t.cle.equals(key))).getSingleOrNull();
    if (row == null) return null;
    return CachedJson(jsonDecode(row.contenu) as Map<String, dynamic>, row.majLe);
  }

  Future<void> write(String key, Map<String, dynamic> data) =>
      _db.into(_db.jsonCache).insertOnConflictUpdate(
            JsonCacheCompanion.insert(cle: key, contenu: jsonEncode(data), majLe: DateTime.now()),
          );
}
