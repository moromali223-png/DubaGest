import '../repositories/auth_repository.dart';
import 'change_password.dart';

/// Crée un COMPTE (identité). L'utilisateur n'appartient ensuite à aucune
/// entreprise et n'a aucun rôle : il crée son entreprise ou accepte une invitation.
class SignUp {
  const SignUp(this._repository);
  final AuthRepository _repository;

  static const minPasswordLength = ChangePassword.minLength;

  Future<SignUpResult> call({
    required String prenom,
    required String nom,
    required String email,
    required String password,
  }) =>
      _repository.signUp(
        prenom: prenom.trim(),
        nom: nom.trim(),
        email: email.trim().toLowerCase(),
        password: password,
      );
}
