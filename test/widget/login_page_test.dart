import 'dart:async';

import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/features/authentication/domain/entities/auth_state.dart';
import 'package:dubagest/features/authentication/domain/repositories/auth_repository.dart';
import 'package:dubagest/features/authentication/presentation/pages/login_page.dart';
import 'package:dubagest/features/authentication/presentation/pages/register_page.dart';
import 'package:dubagest/features/authentication/presentation/providers/auth_providers.dart';
import 'package:dubagest/shared/widgets/language_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

class _FakeAuth implements AuthRepository {
  Completer<void>? pending;
  Failure? error;
  String? lastEmail;

  @override
  Stream<AuthState> watch() => Stream.value(const Unauthenticated());

  @override
  Future<void> signIn({required String email, required String password}) async {
    lastEmail = email;
    if (pending != null) await pending!.future;
    if (error != null) throw error!;
  }

  int googleCalls = 0;
  ({String prenom, String nom, String email})? lastSignUp;
  SignUpResult signUpResult = SignUpResult.confirmationRequired;

  @override
  Future<SignUpResult> signUp({
    required String prenom,
    required String nom,
    required String email,
    required String password,
  }) async {
    lastSignUp = (prenom: prenom, nom: nom, email: email);
    if (error != null) throw error!;
    return signUpResult;
  }

  @override
  Future<void> signInWithGoogle() async => googleCalls++;

  @override
  Future<void> signOut() async {}
  @override
  Future<void> requestPasswordReset(String email) async {}
  @override
  Future<void> changePassword(String newPassword) async {}
}

void main() {
  late _FakeAuth auth;

  Future<void> pump(WidgetTester tester) => pumpApp(
        tester,
        const LoginPage(),
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
      );

  setUp(() => auth = _FakeAuth());

  testWidgets('validation des champs avant tout appel', (tester) async {
    await pump(tester);
    expect(find.byType(LanguageMenuButton), findsOneWidget);

    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Champ obligatoire'), findsNWidgets(2));

    await tester.enterText(find.byKey(const Key('login-email')), 'pas-un-email');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Adresse e-mail invalide'), findsOneWidget);
    expect(auth.lastEmail, isNull);
  });

  testWidgets('état de chargement puis message d\'erreur traduit (jamais technique)', (tester) async {
    auth
      ..pending = Completer<void>()
      ..error = const Failure(FailureKind.invalidCredentials, cause: 'AuthApiException(400)');
    await pump(tester);

    await tester.enterText(find.byKey(const Key('login-email')), ' Admin@Alpha.test ');
    await tester.enterText(find.byKey(const Key('login-password')), 'secret');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    auth.pending!.complete();
    await tester.pumpAndSettle();
    expect(auth.lastEmail, 'admin@alpha.test', reason: 'e-mail normalisé par le cas d\'usage');
    expect(find.text('E-mail ou mot de passe incorrect.'), findsOneWidget);
    expect(find.textContaining('AuthApiException'), findsNothing);
  });

  testWidgets('Google et lien d\'inscription présents ; Google ne passe que par le repository',
      (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('go-register')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('google-sign-in')));
    await tester.tap(find.byKey(const Key('google-sign-in')));
    await tester.pumpAndSettle();
    expect(auth.googleCalls, 1);
  });

  group('Inscription', () {
    Future<void> pumpRegister(WidgetTester tester) => pumpApp(
          tester,
          const RegisterPage(),
          overrides: [authRepositoryProvider.overrideWithValue(auth)],
          size: const Size(400, 1400),
        );

    testWidgets('validation : champs requis, mot de passe, confirmation', (tester) async {
      await pumpRegister(tester);
      await tester.enterText(find.byKey(const Key('register-email')), 'moussa@exemple.com');
      await tester.enterText(find.byKey(const Key('register-password')), 'court');
      await tester.enterText(find.byKey(const Key('register-confirm')), 'autre');
      await tester.tap(find.byKey(const Key('register-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Champ obligatoire'), findsNWidgets(2));
      expect(find.text('Au moins 8 caractères'), findsOneWidget);
      expect(find.text('Les mots de passe ne correspondent pas'), findsOneWidget);
      expect(auth.lastSignUp, isNull);
    });

    testWidgets('compte créé → invitation à confirmer l\'e-mail (aucun rôle)', (tester) async {
      await pumpRegister(tester);
      await tester.enterText(find.byKey(const Key('register-prenom')), ' Moussa ');
      await tester.enterText(find.byKey(const Key('register-nom')), 'Traoré');
      await tester.enterText(find.byKey(const Key('register-email')), 'Moussa@Exemple.com');
      await tester.enterText(find.byKey(const Key('register-password')), 'MotDePasse1');
      await tester.enterText(find.byKey(const Key('register-confirm')), 'MotDePasse1');
      await tester.tap(find.byKey(const Key('register-submit')));
      await tester.pumpAndSettle();

      expect(auth.lastSignUp, (prenom: 'Moussa', nom: 'Traoré', email: 'moussa@exemple.com'));
      expect(find.text('Vérifiez votre e-mail'), findsOneWidget);
    });

    testWidgets('compte existant → message clair', (tester) async {
      auth.error = const Failure(FailureKind.accountExists);
      await pumpRegister(tester);
      await tester.enterText(find.byKey(const Key('register-prenom')), 'A');
      await tester.enterText(find.byKey(const Key('register-nom')), 'B');
      await tester.enterText(find.byKey(const Key('register-email')), 'admin@alpha.test');
      await tester.enterText(find.byKey(const Key('register-password')), 'MotDePasse1');
      await tester.enterText(find.byKey(const Key('register-confirm')), 'MotDePasse1');
      await tester.tap(find.byKey(const Key('register-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Ce compte existe déjà. Connectez-vous.'), findsOneWidget);
    });
  });
}
