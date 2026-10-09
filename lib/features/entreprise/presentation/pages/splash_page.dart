import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../providers/contexte_providers.dart';

/// Restauration de session et chargement du contexte. En cas d'échec sans
/// cache local, propose de réessayer ou de changer de compte.
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final contexte = ref.watch(contexteSessionProvider);

    return Scaffold(
      body: SafeArea(
        child: switch (contexte) {
          AsyncError(:final error) when !contexte.isLoading => MessageView(
              icon: Icons.cloud_off_outlined,
              title: l10n.contextLoadError,
              message: l10n.failure(error),
              action: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  // Développement seulement : la cause technique, pour diagnostiquer.
                  if (kDebugMode && error is Failure && error.cause != null)
                    SelectableText('${error.cause}',
                        key: const Key('splash-cause'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
                    onPressed: () => ref.invalidate(contexteSessionProvider),
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.commonRetry),
                  ),
                  OutlinedButton(
                    onPressed: () => ref.read(signOutProvider).call(),
                    child: Text(l10n.authSignOut),
                  ),
                ],
              ),
            ),
          _ => LoadingView(message: l10n.contextLoading),
        },
      ),
    );
  }
}
