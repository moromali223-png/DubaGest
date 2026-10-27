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
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
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
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: AppColors.greenLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_read_outlined, size: 48, color: AppColors.green),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => context.go(Routes.login),
              child: Text(l10n.authSignInLink),
            ),
          ],
        ),
      );
    }

    InputDecoration deco(String label, {IconData? icon, Widget? suffixIcon}) => InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, size: 20, color: AppColors.muted) : null,
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.green, width: 2),
          ),
        );

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
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 360;
                  final prenomField = TextFormField(
                    key: const Key('register-prenom'),
                    controller: _prenom,
                    enabled: !loading,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.givenName],
                    decoration: deco(l10n.authFirstName, icon: Icons.person_outline_rounded),
                    validator: (v) => AuthValidators.requiredField(v?.trim(), l10n.validationRequired),
                  );
                  final nomField = TextFormField(
                    key: const Key('register-nom'),
                    controller: _nom,
                    enabled: !loading,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.familyName],
                    decoration: deco(l10n.authLastName, icon: Icons.badge_outlined),
                    validator: (v) => AuthValidators.requiredField(v?.trim(), l10n.validationRequired),
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: prenomField),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: nomField),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      prenomField,
                      const SizedBox(height: AppSpacing.md),
                      nomField,
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('register-email'),
                controller: _email,
                enabled: !loading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: deco(l10n.authEmail, icon: Icons.alternate_email_rounded),
                validator: (v) => AuthValidators.email(v,
                    required: l10n.validationRequired, invalid: l10n.validationEmail),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('register-password'),
                controller: _password,
                enabled: !loading,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: deco(
                  l10n.authPassword,
                  icon: Icons.lock_outline_rounded,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20,
                      color: AppColors.muted,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) => (v ?? '').length < SignUp.minPasswordLength
                    ? l10n.validationPasswordLength(SignUp.minPasswordLength)
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('register-confirm'),
                controller: _confirm,
                enabled: !loading,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: deco(
                  l10n.authConfirmPassword,
                  icon: Icons.lock_reset_rounded,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20,
                      color: AppColors.muted,
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) => v != _password.text ? l10n.validationPasswordsMismatch : null,
              ),
              if (action case AsyncError(:final error)) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 18, color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.failure(error),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                key: const Key('register-submit'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: loading ? null : _submit,
                child: loading
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        l10n.authCreateAccount,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    l10n.authHaveAccount,
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  TextButton(
                    onPressed: loading ? null : () => context.go(Routes.login),
                    child: Text(
                      l10n.authSignInLink,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.green),
                    ),
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
