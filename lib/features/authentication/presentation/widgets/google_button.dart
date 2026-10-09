import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/auth_providers.dart';

/// « Continuer avec Google » : authentification seulement, aucun rôle.
class GoogleSignInButton extends ConsumerWidget {
  const GoogleSignInButton({super.key, this.enabled = true});
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(googleSignInControllerProvider);
    ref.listen(googleSignInControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) showFailureSnackBar(context, error);
    });

    return OutlinedButton.icon(
      key: const Key('google-sign-in'),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      onPressed: !enabled || action.isLoading
          ? null
          : () {
              final google = ref.read(signInWithGoogleProvider);
              ref.read(googleSignInControllerProvider.notifier).run(google.call);
            },
      icon: action.isLoading
          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Text('G', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      label: Text(context.l10n.authContinueWithGoogle),
    );
  }
}

/// Séparateur « ou ».
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(context.l10n.authOr, style: Theme.of(context).textTheme.bodySmall),
            ),
            const Expanded(child: Divider()),
          ],
        ),
      );
}
