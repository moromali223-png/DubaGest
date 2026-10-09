import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/errors/failure.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/repositories/auth_repository.dart';

/// Seul point de contact avec Supabase Auth. La session (jetons) est
/// persistée et rafraîchie par supabase_flutter ; aucun mot de passe n'est
/// conservé par l'application.
class SupabaseAuthDataSource {
  SupabaseAuthDataSource(this._auth, {this.redirectUrl});

  final sb.GoTrueClient _auth;

  /// Retour après Google, confirmation d'e-mail ou réinitialisation.
  final String? redirectUrl;
  bool _signOutRequested = false;

  AuthState get current => _fromSession(_auth.currentSession);

  Stream<AuthState> watch() => _auth.onAuthStateChange
      // Erreur de rafraîchissement (souvent hors-ligne) : la session locale est
      // conservée, l'état ne change pas.
      .handleError((Object _) {})
      .map((event) => switch (event.event) {
            sb.AuthChangeEvent.passwordRecovery when event.session != null =>
              Authenticated(_user(event.session!.user), passwordRecovery: true),
            sb.AuthChangeEvent.signedOut => _signedOut(),
            _ => _fromSession(event.session),
          });

  Future<void> signIn(String email, String password) async {
    _signOutRequested = false;
    await _auth.signInWithPassword(email: email, password: password);
  }

  Future<SignUpResult> signUp({
    required String prenom,
    required String nom,
    required String email,
    required String password,
  }) async {
    _signOutRequested = false;
    final response = await _auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: redirectUrl,
      // Métadonnées d'identité uniquement : jamais de rôle ici.
      data: {'prenom': prenom, 'nom': nom, 'nom_complet': '$prenom $nom'.trim()},
    );
    // Avec confirmation active, Supabase masque un compte existant en renvoyant
    // un utilisateur sans identité (anti-énumération).
    if (response.session == null && (response.user?.identities?.isEmpty ?? false)) {
      throw const Failure(FailureKind.accountExists);
    }
    return response.session != null ? SignUpResult.signedIn : SignUpResult.confirmationRequired;
  }

  Future<void> signInWithGoogle() async {
    _signOutRequested = false;
    final launched = await _auth.signInWithOAuth(
      sb.OAuthProvider.google,
      redirectTo: redirectUrl,
      authScreenLaunchMode: sb.LaunchMode.platformDefault,
    );
    if (!launched) throw const Failure(FailureKind.oauthUnavailable);
  }

  Future<void> signOut() async {
    _signOutRequested = true;
    try {
      await _auth.signOut();
    } catch (_) {
      // Hors-ligne : la révocation serveur est impossible, la session locale
      // est tout de même supprimée.
      await _auth.signOut(scope: sb.SignOutScope.local);
    }
  }

  Future<void> requestPasswordReset(String email) =>
      _auth.resetPasswordForEmail(email, redirectTo: redirectUrl);

  Future<void> changePassword(String newPassword) =>
      _auth.updateUser(sb.UserAttributes(password: newPassword));

  AuthState _signedOut() {
    final expired = !_signOutRequested;
    _signOutRequested = false;
    return Unauthenticated(sessionExpired: expired);
  }

  static AuthState _fromSession(sb.Session? session) =>
      session == null ? const Unauthenticated() : Authenticated(_user(session.user));

  static AuthUser _user(sb.User user) => AuthUser(id: user.id, email: user.email);
}
