class AuthUser {
  const AuthUser({required this.id, this.email});
  final String id;
  final String? email;
}

/// État d'authentification. Les mots de passe ne transitent jamais hors de
/// Supabase Auth ; l'application ne connaît que l'identité.
sealed class AuthState {
  const AuthState();
}

/// Restauration de session en cours (démarrage).
final class AuthUnknown extends AuthState {
  const AuthUnknown();
}

final class Authenticated extends AuthState {
  const Authenticated(this.user, {this.passwordRecovery = false});
  final AuthUser user;

  /// Connecté via un lien de réinitialisation : un nouveau mot de passe est attendu.
  final bool passwordRecovery;
}

final class Unauthenticated extends AuthState {
  const Unauthenticated({this.sessionExpired = false});

  /// Déconnexion subie (jeton révoqué/expiré), pas demandée par l'utilisateur.
  final bool sessionExpired;
}
