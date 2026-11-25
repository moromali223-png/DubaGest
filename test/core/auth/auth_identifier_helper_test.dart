import 'package:flutter_test/flutter_test.dart';
import 'package:dubagest/core/auth/auth_identifier_helper.dart';

void main() {
  group('AuthIdentifier Tests', () {
    test('Identifie et normalise correctement les adresses e-mail', () {
      final res1 = AuthIdentifier.parse('User@Example.COM ');
      expect(res1.isValid, isTrue);
      expect(res1.isEmail, isTrue);
      expect(res1.isPhone, isFalse);
      expect(res1.normalized, 'user@example.com');

      final res2 = AuthIdentifier.parse('amadou.traore@dubagest.ml');
      expect(res2.isValid, isTrue);
      expect(res2.isEmail, isTrue);
      expect(res2.normalized, 'amadou.traore@dubagest.ml');
    });

    test('Identifie et normalise les numéros maliens standards à 8 chiffres (+223)', () {
      final res1 = AuthIdentifier.parse('76 12 34 56');
      expect(res1.isValid, isTrue);
      expect(res1.isPhone, isTrue);
      expect(res1.isEmail, isFalse);
      expect(res1.normalized, '+22376123456');

      final res2 = AuthIdentifier.parse('66-00-11-22');
      expect(res2.isValid, isTrue);
      expect(res2.isPhone, isTrue);
      expect(res2.normalized, '+22366001122');
    });

    test('Identifie et normalise les numéros avec indicatif international déjà présent', () {
      final res1 = AuthIdentifier.parse('+22376123456');
      expect(res1.isValid, isTrue);
      expect(res1.isPhone, isTrue);
      expect(res1.normalized, '+22376123456');

      final res2 = AuthIdentifier.parse('0022376123456');
      expect(res2.isValid, isTrue);
      expect(res2.isPhone, isTrue);
      expect(res2.normalized, '+22376123456');

      final res3 = AuthIdentifier.parse('+33 6 12 34 56 78');
      expect(res3.isValid, isTrue);
      expect(res3.isPhone, isTrue);
      expect(res3.normalized, '+33612345678');
    });

    test('Rejette les identifiants invalides', () {
      final empty = AuthIdentifier.parse('   ');
      expect(empty.isValid, isFalse);

      final invalidMail = AuthIdentifier.parse('user@');
      expect(invalidMail.isValid, isFalse);

      final garbage = AuthIdentifier.parse('abc12');
      expect(garbage.isValid, isFalse);
    });
  });
}
