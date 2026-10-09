import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/usecases/change_password.dart';
import '../providers/auth_providers.dart';

/// Changement de mot de passe (depuis les paramètres ou un lien de
/// réinitialisation reçu par e-mail).
class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key, this.recuperation = false});

  /// Arrivée par un lien « mot de passe oublié » (route /reset-password).
  final bool recuperation;

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final change = ref.read(changePasswordProvider);
    final ok = await ref
        .read(changePasswordControllerProvider.notifier)
        .run(() => change(_password.text));
    if (!mounted) return;
    if (ok) {
      showMessageSnackBar(context, context.l10n.authPasswordChanged);
      // Après un lien de réinitialisation, la session redevient normale.
      ref.invalidate(authStateProvider);
      context.go(widget.recuperation ? Routes.home : Routes.settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final action = ref.watch(changePasswordControllerProvider);
    ref.listen(changePasswordControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) showFailureSnackBar(context, error);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recuperation ? l10n.authResetPasswordTitle : l10n.authChangePassword),
      ),
      body: ResponsiveBody(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              TextFormField(
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(labelText: l10n.authNewPassword),
                validator: (v) => (v ?? '').length < ChangePassword.minLength
                    ? l10n.validationPasswordLength(ChangePassword.minLength)
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.authConfirmPassword),
                validator: (v) => v != _password.text ? l10n.validationPasswordsMismatch : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: action.isLoading ? null : _submit,
                child: Text(l10n.commonSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
