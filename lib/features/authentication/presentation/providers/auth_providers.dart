import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/config_providers.dart';
import '../../../../core/di/core_providers.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/change_password.dart';
import '../../domain/usecases/request_password_reset.dart';
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/sign_up.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthRepositoryImpl(SupabaseAuthDataSource(
    client.auth,
    redirectUrl: ref.watch(appConfigProvider).authRedirectUrl,
  ));
});

final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authRepositoryProvider).watch(),
);

/// Identifiant de l'utilisateur connecté (ne change pas au rafraîchissement
/// des jetons, contrairement à l'état complet).
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider.select((s) => switch (s.value) {
        Authenticated(:final user) => user.id,
        _ => null,
      }));
});

final signInProvider = Provider((ref) => SignIn(ref.watch(authRepositoryProvider)));
final signUpProvider = Provider((ref) => SignUp(ref.watch(authRepositoryProvider)));
final signInWithGoogleProvider = Provider((ref) => SignInWithGoogle(ref.watch(authRepositoryProvider)));
final signOutProvider = Provider((ref) => SignOut(ref.watch(authRepositoryProvider)));
final requestPasswordResetProvider =
    Provider((ref) => RequestPasswordReset(ref.watch(authRepositoryProvider)));
final changePasswordProvider = Provider((ref) => ChangePassword(ref.watch(authRepositoryProvider)));

/// Action ponctuelle de formulaire (connexion, réinitialisation…) :
/// expose loading / erreur à l'écran sans logique dans le widget.
class FormActionController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> run(Future<void> Function() action) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(action);
    if (ref.mounted) state = result;
    return !result.hasError;
  }
}

final signInControllerProvider =
    NotifierProvider.autoDispose<FormActionController, AsyncValue<void>>(FormActionController.new);
final signUpControllerProvider =
    NotifierProvider.autoDispose<FormActionController, AsyncValue<void>>(FormActionController.new);
final googleSignInControllerProvider =
    NotifierProvider.autoDispose<FormActionController, AsyncValue<void>>(FormActionController.new);
final passwordResetControllerProvider =
    NotifierProvider.autoDispose<FormActionController, AsyncValue<void>>(FormActionController.new);
final changePasswordControllerProvider =
    NotifierProvider.autoDispose<FormActionController, AsyncValue<void>>(FormActionController.new);
