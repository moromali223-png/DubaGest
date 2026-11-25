import '../repositories/auth_repository.dart';

class SignIn {
  const SignIn(this._repository);
  final AuthRepository _repository;

  Future<void> call({required String identifier, required String password}) =>
      _repository.signIn(identifier: identifier.trim(), password: password);
}
