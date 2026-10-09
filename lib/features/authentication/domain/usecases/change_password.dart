import '../repositories/auth_repository.dart';

class ChangePassword {
  const ChangePassword(this._repository);
  final AuthRepository _repository;

  /// Exigence applicative, supérieure au minimum configuré dans Supabase Auth.
  static const minLength = 8;

  Future<void> call(String newPassword) => _repository.changePassword(newPassword);
}
