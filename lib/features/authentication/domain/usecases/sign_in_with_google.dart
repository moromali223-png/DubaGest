import '../repositories/auth_repository.dart';

/// Google sert uniquement à prouver l'identité ; il ne donne aucun rôle.
class SignInWithGoogle {
  const SignInWithGoogle(this._repository);
  final AuthRepository _repository;

  Future<void> call() => _repository.signInWithGoogle();
}
