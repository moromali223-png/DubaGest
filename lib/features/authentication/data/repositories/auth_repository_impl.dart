import 'dart:async';

import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);
  final SupabaseAuthDataSource _remote;

  @override
  Stream<AuthState> watch() async* {
    yield _remote.current;
    yield* _remote.watch();
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(() => _remote.signIn(email, password));

  @override
  Future<SignUpResult> signUp({
    required String prenom,
    required String nom,
    required String email,
    required String password,
  }) =>
      _guard(() => _remote.signUp(prenom: prenom, nom: nom, email: email, password: password));

  @override
  Future<void> signInWithGoogle() => _guard(_remote.signInWithGoogle);

  @override
  Future<void> signOut() => _guard(_remote.signOut);

  @override
  Future<void> requestPasswordReset(String email) =>
      _guard(() => _remote.requestPasswordReset(email));

  @override
  Future<void> changePassword(String newPassword) =>
      _guard(() => _remote.changePassword(newPassword));

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
  }
}
