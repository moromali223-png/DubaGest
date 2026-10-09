import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../core/permissions/access_decision.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/navigation_providers.dart';

/// Affichée quand une route devient inaccessible (droits retirés, module hors
/// abonnement, lien direct…), avec la raison du refus.
class AccessDeniedPage extends ConsumerWidget {
  const AccessDeniedPage({super.key, this.moduleCode});
  final String? moduleCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final decision = moduleCode == null ? null : ref.watch(moduleAccessProvider(moduleCode!));
    final reason = decision is AccessDenied ? l10n.decision(decision) : l10n.rulePermissionDenied;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accessDeniedTitle)),
      body: MessageView(
        icon: Icons.lock_outline,
        title: l10n.accessDeniedTitle,
        message: reason,
        action: FilledButton.tonal(
          onPressed: () => context.go(Routes.home),
          child: Text(l10n.accessDeniedBackHome),
        ),
      ),
    );
  }
}
