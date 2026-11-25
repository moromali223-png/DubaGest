import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

class ResilientVault {
  static const _dbName = 'dubagest_auth_vault';
  static const _storeName = 'auth_session';

  static void saveToSessionStorage(String key, String value) {
    try {
      web.window.sessionStorage.setItem(key, value);
    } catch (_) {}
  }

  static String? getFromSessionStorage(String key) {
    try {
      return web.window.sessionStorage.getItem(key);
    } catch (_) {
      return null;
    }
  }

  static void removeFromSessionStorage(String key) {
    try {
      web.window.sessionStorage.removeItem(key);
    } catch (_) {}
  }

  static Future<void> saveToIndexedDB(String key, String value) async {
    final completer = Completer<void>();
    try {
      final request = web.window.indexedDB.open(_dbName, 1);
      request.onupgradeneeded = (web.IDBVersionChangeEvent event) {
        final db = request.result as web.IDBDatabase;
        if (!db.objectStoreNames.contains(_storeName)) {
          db.createObjectStore(_storeName);
        }
      }.toJS;

      request.onsuccess = (web.Event event) {
        final db = request.result as web.IDBDatabase;
        final tx = db.transaction(_storeName.toJS, 'readwrite');
        final store = tx.objectStore(_storeName);
        store.put(value.toJS, key.toJS);
        tx.oncomplete = (web.Event e) {
          db.close();
          if (!completer.isCompleted) completer.complete();
        }.toJS;
        tx.onerror = (web.Event e) {
          db.close();
          if (!completer.isCompleted) completer.complete();
        }.toJS;
      }.toJS;

      request.onerror = (web.Event event) {
        if (!completer.isCompleted) completer.complete();
      }.toJS;
    } catch (_) {
      if (!completer.isCompleted) completer.complete();
    }
    return completer.future;
  }

  static Future<String?> getFromIndexedDB(String key) async {
    final completer = Completer<String?>();
    try {
      final request = web.window.indexedDB.open(_dbName, 1);
      request.onupgradeneeded = (web.IDBVersionChangeEvent event) {
        final db = request.result as web.IDBDatabase;
        if (!db.objectStoreNames.contains(_storeName)) {
          db.createObjectStore(_storeName);
        }
      }.toJS;

      request.onsuccess = (web.Event event) {
        final db = request.result as web.IDBDatabase;
        final tx = db.transaction(_storeName.toJS, 'readonly');
        final store = tx.objectStore(_storeName);
        final getReq = store.get(key.toJS);
        getReq.onsuccess = (web.Event e) {
          final res = getReq.result;
          db.close();
          if (!completer.isCompleted) {
            if (res != null && (res as JSString).toDart.isNotEmpty) {
              completer.complete((res as JSString).toDart);
            } else {
              completer.complete(null);
            }
          }
        }.toJS;
        getReq.onerror = (web.Event e) {
          db.close();
          if (!completer.isCompleted) completer.complete(null);
        }.toJS;
      }.toJS;

      request.onerror = (web.Event event) {
        if (!completer.isCompleted) completer.complete(null);
      }.toJS;
    } catch (_) {
      if (!completer.isCompleted) completer.complete(null);
    }
    return completer.future;
  }

  static Future<void> removeFromIndexedDB(String key) async {
    final completer = Completer<void>();
    try {
      final request = web.window.indexedDB.open(_dbName, 1);
      request.onsuccess = (web.Event event) {
        final db = request.result as web.IDBDatabase;
        final tx = db.transaction(_storeName.toJS, 'readwrite');
        final store = tx.objectStore(_storeName);
        store.delete(key.toJS);
        tx.oncomplete = (web.Event e) {
          db.close();
          if (!completer.isCompleted) completer.complete();
        }.toJS;
        tx.onerror = (web.Event e) {
          db.close();
          if (!completer.isCompleted) completer.complete();
        }.toJS;
      }.toJS;
      request.onerror = (web.Event event) {
        if (!completer.isCompleted) completer.complete();
      }.toJS;
    } catch (_) {
      if (!completer.isCompleted) completer.complete();
    }
    return completer.future;
  }
}
