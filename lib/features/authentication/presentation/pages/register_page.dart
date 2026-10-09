import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/sign_up.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_form_scaffold.dart';
import '../widgets/google_button.dart';

/// Création de COMPTE uniquement : ni entreprise, ni rôle à ce stade.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _prenom = TextEditingController();
  final _nom = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _emailAConfirmer;

  @override
  void dispose() {
    for (final c in [_prenom, _nom, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final signUp = ref.read(signUpProvider);
    SignUpResult? result;
    await ref.read(signUpControllerProvider.notifier).run(() async {
      result = await signUp(
        prenom: _prenom.text,
        nom: _nom.text,
        email: _email.text,
        password: _password.text,
      );
    });
    // Session ouverte : le routeur oriente vers l'onboarding.
    if (mounted && result == SignUpResult.confirmationRequired) {
      setState(() => _emailAConfirmer = _email.text.trim().toLowerCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final action = ref.watch(signUpControllerProvider);
    final loading = action.isLoading;

    if (_emailAConfirmer case final email?) {
      return AuthFormScaffold(
        title: l10n.authCheckEmailTitle,
        subtitle: l10n.authCheckEmailMessage(email),
        child: FilledButton(
          onPressed: () => context.go(Routes.login),
          child: Text(l10n.authSignInLink),
        ),
      );
    }

    InputDecoration deco(String label) => InputDecoration(labelText: label);

    return AuthFormScaffold(
      title: l10n.authRegisterTitle,
      subtitle: l10n.authRegisterSubtitle,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GoogleSignInButton(enabled: !loading),
              const OrDivider(),
              TextFormField(
                key: const Key('register-prenom'),
                controller: _prenom,
                enabled: !loading,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.givenName],
                decoration: deco(l10n.authFirstName),
                validator: (v) => AuthValidators.requiredField(v?.trim(), l10n.validationRequired),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('register-nom'),
                controller: _nom,
                enabled: !loading,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.familyName],
                decoration: deco(l10n.authLastName),
                validator: (v) => AuthValidators.requiredField(v?.trim(), l10n.validationRequired),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('register-email'),
                controller: _email,
                enabled: !loading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: deco(l10n.authEmail),
                validator: (v) => AuthValidators.email(v,
                    required: l10n.validationRequired, invalid: l10n.validationEmail),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('register-password'),
                controller: _password,
                enabled: !loading,
                obscureText: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: deco(l10n.authPassword),
                validator: (v) => (v ?? '').length < SignUp.minPasswordLength
                    ? l10n.validationPasswordLength(SignUp.minPasswordLength)
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('register-confirm'),
                controller: _confirm,
                enabled: !loading,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: deco(l10n.authConfirmPassword),
                validator: (v) => v != _password.text ? l10n.validationPasswordsMismatch : null,
              ),
              if (action case AsyncError(:final error)) ...[
                const SizedBox(height: AppSpacing.md),
                Text(l10n.failure(error),
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                key: const Key('register-submit'),
                onPressed: loading ? null : _submit,
                child: loading
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.authCreateAccount),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(l10n.authHaveAccount),
                  TextButton(
                    onPressed: loading ? null : () => context.go(Routes.login),
                    child: Text(l10n.authSignInLink),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
