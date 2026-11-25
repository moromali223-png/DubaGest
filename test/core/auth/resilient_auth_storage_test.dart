import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dubagest/core/auth/resilient_auth_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ResilientAuthStorage Tests', () {
    test('Persists and retrieves session tokens correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = ResilientAuthStorage(prefs: prefs);
      await storage.initialize();

      expect(await storage.hasAccessToken(), isFalse);
      expect(await storage.accessToken(), isNull);

      const fakeSessionJson = '{"access_token":"fake-jwt-token-123","refresh_token":"fake-refresh-token-456"}';
      await storage.persistSession(fakeSessionJson);

      expect(await storage.hasAccessToken(), isTrue);
      expect(await storage.accessToken(), equals(fakeSessionJson));

      await storage.removePersistedSession();
      expect(await storage.hasAccessToken(), isFalse);
      expect(await storage.accessToken(), isNull);
    });
  });
}
