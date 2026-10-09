import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/language_selector.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../domain/entities/contexte_session.dart';
import '../providers/contexte_providers.dart';

/// Connecté mais sans accès exploitable : aucune entreprise, membre suspendu
/// ou entreprise suspendue.
class ContexteBloquePage extends ConsumerWidget {
  const ContexteBloquePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ctx = ref.watch(contexteSessionProvider).value;
    final nom = ctx?.entreprise?.nom ?? '';

    final (icon, title, message) = switch (ctx?.etat) {
      ContexteEtat.membreSuspendu => (
          Icons.person_off_outlined,
          l10n.contextMemberSuspendedTitle,
          l10n.contextMemberSuspendedMessage(nom),
        ),
      ContexteEtat.entrepriseSuspendue => (
          Icons.pause_circle_outline,
          l10n.contextEntrepriseSuspendedTitle,
          l10n.contextEntrepriseSuspendedMessage(nom),
        ),
      _ => (
          Icons.domain_disabled_outlined,
          l10n.contextNoEntrepriseTitle,
          l10n.contextNoEntrepriseMessage,
        ),
    };

    return Scaffold(
      appBar: AppBar(actions: const [LanguageMenuButton()]),
      body: SafeArea(
        child: MessageView(
          icon: icon,
          title: title,
          message: message,
          action: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () => ref.read(contexteSessionProvider.notifier).rafraichir(),
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
      ),
    );
  }
}
