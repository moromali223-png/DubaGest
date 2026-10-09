import '../entities/auth_state.dart';

/// Résultat d'une inscription par e-mail.
enum SignUpResult {
  /// Session ouverte immédiatement (confirmation désactivée).
  signedIn,

  /// Un e-mail de confirmation a été envoyé ; connexion après validation.
  confirmationRequired,
}

/// Authentification uniquement (« qui est cette personne ? »).
/// Aucune méthode ici n'attribue de rôle métier.
abstract interface class AuthRepository {
  /// Émet l'état courant puis chaque changement (connexion, expiration…).
  Stream<AuthState> watch();
  Future<void> signIn({required String email, required String password});
  Future<SignUpResult> signUp({
    required String prenom,
    required String nom,
    required String email,
    required String password,
  });

  /// Ouvre le parcours Google (navigateur / redirection) ; la session arrive
  /// ensuite par [watch].
  Future<void> signInWithGoogle();
  Future<void> signOut();
  Future<void> requestPasswordReset(String email);
  Future<void> changePassword(String newPassword);
}
