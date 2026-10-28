import 'package:dubagest/app/theme/app_theme.dart';
import 'package:dubagest/app/theme/theme_controller.dart';
import 'package:dubagest/features/authentication/domain/entities/auth_state.dart';
import 'package:dubagest/features/authentication/domain/repositories/auth_repository.dart';
import 'package:dubagest/features/authentication/presentation/pages/login_page.dart';
import 'package:dubagest/features/authentication/presentation/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

class _FakeAuth implements AuthRepository {
  @override
  Stream<AuthState> watch() => Stream.value(const Unauthenticated());

  @override
  Future<void> signIn({required String email, required String password}) async {}

  @override
  Future<SignUpResult> signUp({
    required String prenom,
    required String nom,
    required String email,
    required String password,
  }) async => SignUpResult.confirmationRequired;

  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<void> requestPasswordReset(String email) async {}
  @override
  Future<void> changePassword(String newPassword) async {}
}

void main() {
  late _FakeAuth auth;

  setUp(() => auth = _FakeAuth());

  testWidgets('Authentification en Dark Mode : les textes et champs sont lisibles et contrastés',
      (tester) async {
    await pumpApp(
      tester,
      Theme(
        data: AppTheme.dark(),
        child: const LoginPage(),
      ),
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        themeModeControllerProvider.overrideWith(() => _MockThemeModeController(ThemeMode.dark)),
      ],
      size: const Size(400, 900),
    );

    // Vérifie que le titre est bien affiché avec la couleur onSurface du thème sombre
    final titleFinder = find.text('Connexion');
    expect(titleFinder, findsOneWidget);

    final titleWidget = tester.widget<Text>(titleFinder);
    expect(titleWidget.style?.color, AppColors.darkOnSurface);

    // Saisie de texte dans les champs d'authentification
    final emailFieldFinder = find.byKey(const Key('login-email'));
    final passwordFieldFinder = find.byKey(const Key('login-password'));

    expect(emailFieldFinder, findsOneWidget);
    expect(passwordFieldFinder, findsOneWidget);

    await tester.enterText(emailFieldFinder, 'contact@dubagest.com');
    await tester.enterText(passwordFieldFinder, 'MonMotDePasse123');
    await tester.pumpAndSettle();

    // Vérification du bouton de connexion
    final submitButtonFinder = find.byKey(const Key('login-submit'));
    expect(submitButtonFinder, findsOneWidget);
    final buttonWidget = tester.widget<FilledButton>(submitButtonFinder);
    expect(buttonWidget.style?.backgroundColor?.resolve({}), AppColors.greenOnDark);
  });

  testWidgets('Authentification en Light Mode : préserve le style et les couleurs d’origine',
      (tester) async {
    await pumpApp(
      tester,
      Theme(
        data: AppTheme.light(),
        child: const LoginPage(),
      ),
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        themeModeControllerProvider.overrideWith(() => _MockThemeModeController(ThemeMode.light)),
      ],
      size: const Size(400, 900),
    );

    final titleFinder = find.text('Connexion');
    expect(titleFinder, findsOneWidget);

    final titleWidget = tester.widget<Text>(titleFinder);
    expect(titleWidget.style?.color, AppColors.ink);

    final submitButtonFinder = find.byKey(const Key('login-submit'));
    final buttonWidget = tester.widget<FilledButton>(submitButtonFinder);
    expect(buttonWidget.style?.backgroundColor?.resolve({}), AppColors.green);
  });
}

class _MockThemeModeController extends ThemeModeController {
  _MockThemeModeController(this._initial);
  final ThemeMode _initial;

  @override
  ThemeMode build() => _initial;
}
