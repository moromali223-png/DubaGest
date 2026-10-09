import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../utils/app_logger.dart';

/// Appareil partagé : quand un autre utilisateur se connecte, les données
/// métier mises en cache par le précédent sont effacées avant tout affichage.
class LocalSessionGuard {
  LocalSessionGuard(this._prefs, this._db);

  final SharedPreferences _prefs;
  final AppDatabase _db;
  static const _key = 'last_user_id';

  Future<void> ensureUser(String userId) async {
    final previous = _prefs.getString(_key);
    if (previous == userId) return;
    if (previous != null) {
      AppLogger.info('Changement d\'utilisateur : purge du cache local', tag: 'session');
      await _db.purgerDonneesUtilisateur();
    }
    await _prefs.setString(_key, userId);
  }
}
