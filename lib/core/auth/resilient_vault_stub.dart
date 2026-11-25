class ResilientVault {
  static void saveToSessionStorage(String key, String value) {}
  static String? getFromSessionStorage(String key) => null;
  static void removeFromSessionStorage(String key) {}
  static Future<void> saveToIndexedDB(String key, String value) async {}
  static Future<String?> getFromIndexedDB(String key) async => null;
  static Future<void> removeFromIndexedDB(String key) async {}
}
