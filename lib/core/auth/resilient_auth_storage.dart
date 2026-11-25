import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';
import 'resilient_vault.dart';

/// Stockage haute résilience pour la persistance des sessions Supabase Auth.
///
/// Résout le problème critique d'expiration / déconnexion inattendue sur iOS PWA (Safari) :
/// - Safari iOS vide agressivement `window.localStorage` en cas de pression mémoire ou selon
///   les règles ITP (Intelligent Tracking Prevention).
/// - Cette implémentation sécurise le jeton dans trois couches synchronisées :
///   1. `SharedPreferences` (localStorage Web / Keychain Mobile)
///   2. `sessionStorage` Web (persiste durant toute la session du navigateur WebKit)
///   3. `IndexedDB` Web (stockage durable non purgé par le cycle d'épuration ITP de Safari)
///
/// Si `SharedPreferences` est vidé par iOS, `ResilientAuthStorage` restaure automatiquement
/// la session depuis `IndexedDB` et reconstitue les préférences sans forcer l'utilisateur à se reconnecter.
class ResilientAuthStorage extends LocalStorage {
  ResilientAuthStorage({
    this.persistSessionKey = supabasePersistSessionKey,
    SharedPreferences? prefs,
  }) : _prefs = prefs;

  final String persistSessionKey;
  SharedPreferences? _prefs;

  @override
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<bool> hasAccessToken() async {
    final token = await accessToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Future<String?> accessToken() async {
    _prefs ??= await SharedPreferences.getInstance();

    // 1. Couche primaire : SharedPreferences
    final fromPrefs = _prefs?.getString(persistSessionKey);
    if (fromPrefs != null && fromPrefs.isNotEmpty) {
      return fromPrefs;
    }

    // 2. Couche secondaire : SessionStorage (WebKit / Safari PWA)
    final fromSession = ResilientVault.getFromSessionStorage(persistSessionKey);
    if (fromSession != null && fromSession.isNotEmpty) {
      AppLogger.info('Session restaurée depuis le sessionStorage', tag: 'auth_storage');
      await _prefs?.setString(persistSessionKey, fromSession);
      return fromSession;
    }

    // 3. Couche tertiaire : IndexedDB (Protection anti-purge iOS Safari)
    final fromIndexedDB = await ResilientVault.getFromIndexedDB(persistSessionKey);
    if (fromIndexedDB != null && fromIndexedDB.isNotEmpty) {
      AppLogger.info('Session restaurée depuis le coffre-fort IndexedDB (sauvetage anti-purge iOS)', tag: 'auth_storage');
      await _prefs?.setString(persistSessionKey, fromIndexedDB);
      ResilientVault.saveToSessionStorage(persistSessionKey, fromIndexedDB);
      return fromIndexedDB;
    }

    return null;
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(persistSessionKey, persistSessionString);

    // Réplication sur les couches résilientes Web
    ResilientVault.saveToSessionStorage(persistSessionKey, persistSessionString);
    await ResilientVault.saveToIndexedDB(persistSessionKey, persistSessionString);
  }

  @override
  Future<void> removePersistedSession() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.remove(persistSessionKey);

    // Purge de toutes les couches résilientes
    ResilientVault.removeFromSessionStorage(persistSessionKey);
    await ResilientVault.removeFromIndexedDB(persistSessionKey);
  }
}
