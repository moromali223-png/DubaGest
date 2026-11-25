import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:dubagest/features/authentication/domain/repositories/auth_repository.dart';

class FakeGoTrueClient implements sb.GoTrueClient {
  String? lastSignInEmail;
  String? lastSignInPhone;
  String? lastSignInPassword;

  String? lastSignUpEmail;
  String? lastSignUpPhone;
  String? lastSignUpPassword;
  Map<String, dynamic>? lastSignUpData;

  String? lastResetEmail;

  bool signUpReturnsSession = true;

  @override
  sb.Session? get currentSession => null;

  @override
  Stream<sb.AuthState> get onAuthStateChange => const Stream.empty();

  @override
  Future<sb.AuthResponse> signInWithPassword({
    String? email,
    String? phone,
    required String password,
    String? captchaToken,
  }) async {
    lastSignInEmail = email;
    lastSignInPhone = phone;
    lastSignInPassword = password;
    return sb.AuthResponse();
  }

  @override
  Future<sb.AuthResponse> signUp({
    String? email,
    String? phone,
    required String password,
    String? emailRedirectTo,
    Map<String, dynamic>? data,
    String? captchaToken,
    sb.OtpChannel channel = sb.OtpChannel.sms,
  }) async {
    lastSignUpEmail = email;
    lastSignUpPhone = phone;
    lastSignUpPassword = password;
    lastSignUpData = data;

    if (signUpReturnsSession) {
      // Retourne un AuthResponse avec un User et une Session
      final user = sb.User(
        id: 'user-123',
        appMetadata: {},
        userMetadata: data ?? {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );
      final session = sb.Session(
        accessToken: 'fake-access-token',
        tokenType: 'bearer',
        user: user,
      );
      return sb.AuthResponse(session: session, user: user);
    }
    return sb.AuthResponse();
  }

  @override
  Future<void> resetPasswordForEmail(
    String email, {
    String? redirectTo,
    String? captchaToken,
  }) async {
    lastResetEmail = email;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeGoTrueClient fakeGoTrue;
  late SupabaseAuthDataSource dataSource;

  setUp(() {
    fakeGoTrue = FakeGoTrueClient();
    dataSource = SupabaseAuthDataSource(fakeGoTrue);
  });

  group('SupabaseAuthDataSource Email / Phone Tests sans OTP', () {
    test('signIn avec e-mail appelle signInWithPassword(email: ...)', () async {
      await dataSource.signIn('test@dubagest.ml', 'secretPassword123');

      expect(fakeGoTrue.lastSignInEmail, equals('test@dubagest.ml'));
      expect(fakeGoTrue.lastSignInPhone, isNull);
      expect(fakeGoTrue.lastSignInPassword, equals('secretPassword123'));
    });

    test('signIn avec téléphone malien appelle signInWithPassword(phone: ...)', () async {
      await dataSource.signIn('76 12 34 56', 'secretPassword123');

      expect(fakeGoTrue.lastSignInPhone, equals('+22376123456'));
      expect(fakeGoTrue.lastSignInEmail, isNull);
      expect(fakeGoTrue.lastSignInPassword, equals('secretPassword123'));
    });

    test('signUp avec e-mail appelle signUp(email: ...) et retourne signedIn directement', () async {
      final result = await dataSource.signUp(
        prenom: 'Amadou',
        nom: 'Traoré',
        identifierInput: 'amadou@dubagest.ml',
        password: 'secretPassword123',
      );

      expect(result, equals(SignUpResult.signedIn));
      expect(fakeGoTrue.lastSignUpEmail, equals('amadou@dubagest.ml'));
      expect(fakeGoTrue.lastSignUpPhone, isNull);
      expect(fakeGoTrue.lastSignUpData?['nom_complet'], equals('Amadou Traoré'));
      expect(fakeGoTrue.lastSignUpData?['email'], equals('amadou@dubagest.ml'));
    });

    test('signUp avec téléphone malien appelle signUp(phone: ...) et retourne signedIn directement sans OTP', () async {
      final result = await dataSource.signUp(
        prenom: 'Fatoumata',
        nom: 'Diallo',
        identifierInput: '76123456',
        password: 'secretPassword123',
      );

      expect(result, equals(SignUpResult.signedIn));
      expect(fakeGoTrue.lastSignUpPhone, equals('+22376123456'));
      expect(fakeGoTrue.lastSignUpEmail, isNull);
      expect(fakeGoTrue.lastSignUpData?['nom_complet'], equals('Fatoumata Diallo'));
      expect(fakeGoTrue.lastSignUpData?['telephone'], equals('+22376123456'));
    });

    test('requestPasswordReset avec e-mail déclenche resetPasswordForEmail', () async {
      await dataSource.requestPasswordReset('amadou@dubagest.ml');
      expect(fakeGoTrue.lastResetEmail, equals('amadou@dubagest.ml'));
    });

    test('requestPasswordReset avec téléphone lève phoneResetUnsupported', () async {
      expect(
        () => dataSource.requestPasswordReset('+22376123456'),
        throwsA(isA<Failure>().having((f) => f.kind, 'kind', FailureKind.phoneResetUnsupported)),
      );
    });
  });
}
