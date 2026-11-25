import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/auth_identifier_helper.dart';
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
  final _identifier = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _identifier.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final request = ref.read(requestPasswordResetProvider);
    final ok = await ref
        .read(passwordResetControllerProvider.notifier)
        .run(() => request(_identifier.text));
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
                    controller: _identifier,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email, AutofillHints.telephoneNumber, AutofillHints.username],
                    decoration: const InputDecoration(
                      labelText: 'E-mail ou numéro de téléphone',
                      hintText: 'exemple@domaine.com ou +223 70 00 00 00',
                      prefixIcon: Icon(Icons.contact_mail_outlined),
                    ),
                    validator: (v) {
                      final trimmed = v?.trim() ?? '';
                      if (trimmed.isEmpty) return l10n.validationRequired;
                      final parsed = AuthIdentifier.parse(trimmed);
                      if (!parsed.isValid) {
                        return 'Saisissez un e-mail valide ou un numéro de téléphone valide';
                      }
                      return null;
                    },
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
