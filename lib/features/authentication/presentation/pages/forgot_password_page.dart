import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_form_scaffold.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final request = ref.read(requestPasswordResetProvider);
    final ok = await ref
        .read(passwordResetControllerProvider.notifier)
        .run(() => request(_email.text));
    if (mounted && ok) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final action = ref.watch(passwordResetControllerProvider);

    ref.listen(passwordResetControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) showFailureSnackBar(context, error);
    });

    return AuthFormScaffold(
      title: l10n.authForgotPasswordTitle,
      subtitle: _sent ? l10n.authResetLinkSent : l10n.authForgotPasswordHelp,
      showBack: true,
      child: _sent
          ? OutlinedButton(
              onPressed: () => context.go(Routes.login),
              child: Text(l10n.authBackToLogin),
            )
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(labelText: l10n.authEmail),
                    validator: (v) => AuthValidators.email(v,
                        required: l10n.validationRequired, invalid: l10n.validationEmail),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: action.isLoading ? null : _submit,
                    child: Text(l10n.authSendResetLink),
                  ),
                ],
              ),
            ),
    );
  }
}
