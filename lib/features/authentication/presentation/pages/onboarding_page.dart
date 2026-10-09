import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/language_selector.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../providers/auth_providers.dart';

/// Compte authentifié sans entreprise : aucun rôle, aucune permission.
/// Deux chemins seulement : créer son entreprise ou accepter une invitation.
class OnboardingPage extends ConsumerWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final nom = ref.watch(contexteSessionProvider).value?.nomComplet?.split(' ').first;

    return Scaffold(
      appBar: AppBar(
        actions: [
          const LanguageMenuButton(),
          IconButton(
            tooltip: l10n.authSignOut,
            onPressed: () => ref.read(signOutProvider).call(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    nom == null ? l10n.onboardingWelcomeAnonymous : l10n.onboardingWelcome(nom),
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.onboardingQuestion, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: AppSpacing.lg),
                  _Choix(
                    key: const Key('onboarding-create'),
                    icon: Icons.add_business_outlined,
                    title: l10n.onboardingCreateTitle,
                    subtitle: l10n.onboardingCreateSubtitle,
                    onTap: () => context.go(Routes.createCompany),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Choix(
                    key: const Key('onboarding-join'),
                    icon: Icons.group_add_outlined,
                    title: l10n.onboardingJoinTitle,
                    subtitle: l10n.onboardingJoinSubtitle,
                    onTap: () => context.go(Routes.joinCompany),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Choix extends StatelessWidget {
  const _Choix({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primaryContainer,
                child: Icon(icon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
