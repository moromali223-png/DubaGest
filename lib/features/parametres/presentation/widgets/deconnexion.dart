import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../core/di/sync_providers.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';

/// Déconnexion, avec confirmation s'il reste des modifications à envoyer.
Future<void> seDeconnecter(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final pending = ref.read(syncStateProvider).value?.pendingCount ?? 0;
  if (pending > 0) {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.authSignOutPendingTitle),
        content: Text(l10n.authSignOutPendingMessage(pending)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.authSignOut)),
        ],
      ),
    );
    if (!(confirme ?? false)) return;
  }
  try {
    await ref.read(signOutProvider).call();
  } catch (e) {
    if (context.mounted) showFailureSnackBar(context, e);
  }
}
