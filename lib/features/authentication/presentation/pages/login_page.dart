import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/auth_state.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_form_scaffold.dart';
import '../widgets/google_button.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final signIn = ref.read(signInProvider);
    await ref.read(signInControllerProvider.notifier).run(
          () => signIn(email: _email.text, password: _password.text),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final action = ref.watch(signInControllerProvider);
    final loading = action.isLoading;
    final sessionExpired = ref.watch(
      authStateProvider.select((s) => s.value is Unauthenticated &&
          (s.value! as Unauthenticated).sessionExpired),
    );

    return AuthFormScaffold(
      title: l10n.authLoginTitle,
      subtitle: l10n.authLoginSubtitle,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sessionExpired) ...[
                _Notice(text: l10n.authSessionExpired),
                const SizedBox(height: AppSpacing.md),
              ],
              TextFormField(
                key: const Key('login-email'),
                controller: _email,
                enabled: !loading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email, AutofillHints.username],
                decoration: InputDecoration(
                  labelText: l10n.authEmail,
                  prefixIcon: const Icon(Icons.alternate_email),
                ),
                validator: (v) => AuthValidators.email(v,
                    required: l10n.validationRequired, invalid: l10n.validationEmail),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('login-password'),
                controller: _password,
                enabled: !loading,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: l10n.authPassword,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
                validator: (v) => AuthValidators.requiredField(v, l10n.validationRequired),
              ),
              if (action case AsyncError(:final error)) ...[
                const SizedBox(height: AppSpacing.md),
                _Notice(text: l10n.failure(error), isError: true),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                key: const Key('login-submit'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                onPressed: loading ? null : _submit,
                child: loading
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(l10n.authSignIn, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: loading ? null : () => context.push(Routes.forgotPassword),
                child: Text(
                  l10n.authForgotPassword,
                  style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              const OrDivider(),
              GoogleSignInButton(enabled: !loading),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(l10n.authNoAccount, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  TextButton(
                    key: const Key('go-register'),
                    onPressed: loading ? null : () => context.go(Routes.register),
                    child: Text(
                      l10n.authRegisterLink,
                      style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('go-vitrine-link'),
                onPressed: () => launchUrl(
                  Uri.parse('https://dubagest-ml.vercel.app'),
                  mode: LaunchMode.externalApplication,
                ),
                icon: Icon(Icons.language_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                label: Text(
                  'Visiter le site officiel DubaGest',
                  style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.isError = false});
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bg = isError
        ? (isDark ? scheme.errorContainer : scheme.error.withValues(alpha: 0.1))
        : (isDark ? scheme.primaryContainer : AppColors.greenSoft);
    final borderColor = isError ? scheme.error.withValues(alpha: 0.4) : scheme.primary.withValues(alpha: 0.4);
    final iconColor = isError ? scheme.error : scheme.primary;
    final textColor = isError
        ? (isDark ? scheme.onErrorContainer : const Color(0xFF991B1B))
        : (isDark ? scheme.onPrimaryContainer : AppColors.ink);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: 20,
            color: iconColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
                fontSize: 13.5,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
