import 'package:dubagest/app/router/app_router.dart';
import 'package:dubagest/app/router/routes.dart';
import 'package:dubagest/features/authentication/domain/entities/auth_state.dart';
import 'package:dubagest/features/entreprise/domain/entities/contexte_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contexte_fixtures.dart';

void main() {
  const connecte = Authenticated(AuthUser(id: userId));
  final sansEntreprise = contexte(avecEntreprise: false);

  String? redirect(String location,
          {AuthState? auth = connecte, ContexteSession? ctx, bool chargement = false, String? jeton}) =>
      globalRedirect(
        location: location,
        auth: auth,
        contexte: chargement ? null : (ctx ?? contexte()),
        invitationEnAttente: jeton,
      );

  test('session en cours de restauration → écran d\'attente', () {
    expect(redirect(Routes.home, auth: null, chargement: true), Routes.splash);
    expect(redirect(Routes.splash, auth: const AuthUnknown(), chargement: true), isNull);
  });

  test('pas de session → connexion ; pages publiques accessibles', () {
    const anonyme = Unauthenticated();
    expect(redirect(Routes.home, auth: anonyme, chargement: true), Routes.login);
    expect(redirect('/admin/utilisateurs', auth: anonyme, chargement: true), Routes.login);
    for (final r in [Routes.register, Routes.forgotPassword, Routes.joinCompany]) {
      expect(redirect(r, auth: anonyme, chargement: true), isNull, reason: r);
    }
  });

  test('connecté, contexte en chargement → attente, puis application', () {
    expect(redirect(Routes.login, chargement: true), Routes.splash);
    expect(redirect(Routes.splash), Routes.home);
    expect(redirect('/admin/perimetres'), isNull);
  });

  test('compte sans entreprise → onboarding (créer / rejoindre uniquement)', () {
    expect(redirect(Routes.home, ctx: sansEntreprise), Routes.onboarding);
    expect(redirect('/admin/utilisateurs', ctx: sansEntreprise), Routes.onboarding);
    expect(redirect(Routes.createCompany, ctx: sansEntreprise), isNull);
    expect(redirect(Routes.joinCompany, ctx: sansEntreprise), isNull);
  });

  test('invitation en attente → rejoindre l\'entreprise, quel que soit l\'état', () {
    expect(redirect(Routes.onboarding, ctx: sansEntreprise, jeton: 'abc'), Routes.joinCompany);
    expect(redirect(Routes.home, jeton: 'abc'), Routes.joinCompany);
    expect(redirect(Routes.joinCompany, jeton: 'abc'), isNull);
  });

  test('avec entreprise : pas de retour à l\'onboarding ni à la création', () {
    expect(redirect(Routes.onboarding), Routes.home);
    expect(redirect(Routes.createCompany), Routes.home);
    expect(redirect(Routes.register), Routes.home);
    expect(redirect(Routes.joinCompany), isNull, reason: 'rejoindre une 2e entreprise reste possible');
  });

  test('membre suspendu → écran bloqué', () {
    expect(redirect(Routes.home, ctx: contexte(membreStatut: 'SUSPENDU')), Routes.blocked);
  });

  test('lien de réinitialisation → nouveau mot de passe obligatoire', () {
    const recovery = Authenticated(AuthUser(id: userId), passwordRecovery: true);
    expect(redirect(Routes.home, auth: recovery), Routes.resetPassword);
    expect(redirect(Routes.resetPassword, auth: recovery), isNull);
  });

  test('chaque module a une route', () {
    expect(ModuleRoutes.path('admin.perimetres'), '/admin/perimetres');
    expect(ModuleRoutes.path('commerce.ventes'), '/commerce/ventes');
    expect(ModuleRoutes.path('commerce.fournisseurs'), '/commerce/fournisseurs');
    // Un module sans écran dédié ouvre la page « bientôt disponible ».
    expect(ModuleRoutes.path('services.devis'), '/modules/services.devis');
  });
}

