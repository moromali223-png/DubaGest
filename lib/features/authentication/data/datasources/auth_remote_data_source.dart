import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:url_launcher/url_launcher.dart' as ul;

import '../../../../app/config/app_config.dart';
import '../../../../core/auth/auth_identifier_helper.dart';
import '../../../../core/auth/resilient_auth_storage.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/repositories/auth_repository.dart';

/// Seul point de contact avec Supabase Auth. La session (jetons) est
/// persistée et rafraîchie par supabase_flutter ; aucun mot de passe n'est
/// conservé par l'application.
class SupabaseAuthDataSource {
  SupabaseAuthDataSource(this._auth, {this.redirectUrl}) {
    if (_auth.currentSession != null) {
      _lastKnownUser = _user(_auth.currentSession!.user);
    }
  }

  final sb.GoTrueClient _auth;

  /// Retour après Google, confirmation d'e-mail ou réinitialisation.
  final String? redirectUrl;
  bool _signOutRequested = false;
  AuthUser? _lastKnownUser;

  AuthState get current => _fromSession(_auth.currentSession);

  Stream<AuthState> watch() => _auth.onAuthStateChange
      // Erreur de rafraîchissement (souvent hors-ligne) : la session locale est
      // conservée, l'état ne change pas.
      .handleError((Object error, StackTrace stackTrace) {
        AppLogger.warning('Erreur sur le flux Auth Supabase: $error', tag: 'auth', error: error);
      })
      .map((event) => switch (event.event) {
            sb.AuthChangeEvent.passwordRecovery when event.session != null =>
              Authenticated(_recordUser(event.session!.user), passwordRecovery: true),
            sb.AuthChangeEvent.signedOut => _signedOut(),
            sb.AuthChangeEvent.tokenRefreshed when event.session != null =>
              Authenticated(_recordUser(event.session!.user)),
            sb.AuthChangeEvent.signedIn when event.session != null =>
              Authenticated(_recordUser(event.session!.user)),
            sb.AuthChangeEvent.userUpdated when event.session != null =>
              Authenticated(_recordUser(event.session!.user)),
            _ => _fromSession(event.session),
          });

  /// Gère la reprise d'activité de l'application (sortie de veille / retour sur le PWA iOS).
  ///
  /// Évite l'expiration intempestive de session : Safari iOS suspend le moteur JS en veille,
  /// ce qui retarde les timers d'actualisation de jeton. Au réveil, un rafraîchissement contrôlé
  /// est déclenché après rétablissement de la couche réseau, sans déconnecter si le réseau est lent/absent.
  Future<void> handleAppResume() async {
    try {
      final session = _auth.currentSession;
      if (session == null) {
        // Tentative de récupération depuis le coffre-fort résilient
        final storage = ResilientAuthStorage();
        await storage.initialize();
        final rawSession = await storage.accessToken();
        if (rawSession != null && rawSession.isNotEmpty) {
          AppLogger.info('Restauration de session après veille (PWA iOS)...', tag: 'auth');
          await _auth.recoverSession(rawSession);
        }
        return;
      }

      if (session.isExpired) {
        AppLogger.info('Session expirée détectée au réveil, rafraîchissement contrôlé...', tag: 'auth');
        // Délai pour laisser le socket réseau se reconnecter après déverrouillage de l'écran
        await Future<void>.delayed(const Duration(milliseconds: 700));
        await _auth.refreshSession();
        AppLogger.info('Session rafraîchie avec succès au réveil.', tag: 'auth');
      }
    } catch (e) {
      // DubaGest est Offline-First : un échec temporaire au retour de veille
      // ne doit jamais détruire la session locale de l'utilisateur.
      AppLogger.warning('Rafraîchissement différé au réveil (mode hors-ligne ou réseau lent): $e', tag: 'auth');
    }
  }

  Future<void> signIn(String identifierInput, String password) async {
    _signOutRequested = false;
    final parsed = AuthIdentifier.parse(identifierInput);
    if (!parsed.isValid) {
      throw const Failure(FailureKind.invalidIdentifier);
    }

    if (parsed.isPhone) {
      await _auth.signInWithPassword(phone: parsed.normalized, password: password);
    } else {
      await _auth.signInWithPassword(email: parsed.normalized, password: password);
    }
  }

  Future<SignUpResult> signUp({
    required String prenom,
    required String nom,
    required String identifierInput,
    required String password,
  }) async {
    _signOutRequested = false;
    final parsed = AuthIdentifier.parse(identifierInput);
    if (!parsed.isValid) {
      throw const Failure(FailureKind.invalidIdentifier);
    }

    final metadata = {
      'prenom': prenom,
      'nom': nom,
      'nom_complet': '$prenom $nom'.trim(),
    };

    sb.AuthResponse response;
    if (parsed.isPhone) {
      metadata['telephone'] = parsed.normalized;
      response = await _auth.signUp(
        phone: parsed.normalized,
        password: password,
        data: metadata,
      );
    } else {
      metadata['email'] = parsed.normalized;
      response = await _auth.signUp(
        email: parsed.normalized,
        password: password,
        emailRedirectTo: redirectUrl,
        data: metadata,
      );
    }

    // Avec confirmation active ou duplication, Supabase masque un compte existant
    // en renvoyant un utilisateur sans identité (anti-énumération).
    if (response.session == null && (response.user?.identities?.isEmpty ?? false)) {
      throw const Failure(FailureKind.accountExists);
    }
    return response.session != null ? SignUpResult.signedIn : SignUpResult.confirmationRequired;
  }

  Future<void> signInWithGoogle() async {
    _signOutRequested = false;
    final effectiveRedirect = redirectUrl ??
        (kIsWeb ? Uri.base.origin : AppConfig.mobileRedirect);

    bool launched = false;
    try {
      launched = await _auth.signInWithOAuth(
        sb.OAuthProvider.google,
        redirectTo: effectiveRedirect,
        authScreenLaunchMode: kIsWeb
            ? sb.LaunchMode.platformDefault
            : sb.LaunchMode.externalApplication,
        queryParams: const {'prompt': 'select_account'},
      );
    } catch (e) {
      AppLogger.warning('Échec lancement OAuth principal, tentative fallback: $e', tag: 'auth');
    }

    // Repli pour certains appareils Android dont le navigateur par défaut
    // préfère Custom Tabs (inAppBrowserView) ou le mode par défaut de l'OS.
    if (!launched && !kIsWeb) {
      final res = await _auth.getOAuthSignInUrl(
        provider: sb.OAuthProvider.google,
        redirectTo: effectiveRedirect,
        queryParams: const {'prompt': 'select_account'},
      );
      final uri = Uri.parse(res.url);
      launched = await ul.launchUrl(uri, mode: ul.LaunchMode.inAppBrowserView);
      if (!launched) {
        launched = await ul.launchUrl(uri, mode: ul.LaunchMode.platformDefault);
      }
    }

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

  Future<void> requestPasswordReset(String identifierInput) async {
    final parsed = AuthIdentifier.parse(identifierInput);
    if (!parsed.isValid) {
      throw const Failure(FailureKind.invalidIdentifier);
    }

    if (parsed.isPhone) {
      // Pour le téléphone sans passerelle OTP SMS active : informer clairement l'utilisateur
      throw const Failure(FailureKind.phoneResetUnsupported);
    } else {
      await _auth.resetPasswordForEmail(parsed.normalized, redirectTo: redirectUrl);
    }
  }

  Future<void> changePassword(String newPassword) =>
      _auth.updateUser(sb.UserAttributes(password: newPassword));

  AuthState _signedOut() {
    final expired = !_signOutRequested;
    _signOutRequested = false;
    _lastKnownUser = null;
    return Unauthenticated(sessionExpired: expired);
  }

  AuthUser _recordUser(sb.User user) {
    final u = _user(user);
    _lastKnownUser = u;
    return u;
  }

  AuthState _fromSession(sb.Session? session) {
    if (session != null) {
      return Authenticated(_recordUser(session.user));
    }
    // Si la session Supabase est temporairement absente mais qu'aucun signOut
    // n'a été demandé et qu'un utilisateur était déjà authentifié, on maintient
    // l'état authentifié en local (conformité avec l'architecture Offline-First).
    if (!_signOutRequested && _lastKnownUser != null) {
      return Authenticated(_lastKnownUser!);
    }
    return const Unauthenticated();
  }

  static AuthUser _user(sb.User user) => AuthUser(id: user.id, email: user.email);
}
