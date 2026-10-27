import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/language_selector.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../providers/auth_providers.dart';
import '../widgets/duba_gest_brand_logo.dart';

/// Compte authentifié sans entreprise : aucun rôle, aucune permission.
/// Deux chemins seulement : créer son entreprise ou accepter une invitation.
class OnboardingPage extends ConsumerWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final nom = ref.watch(contexteSessionProvider).value?.nomComplet?.split(' ').first;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTabletOrDesktop = screenWidth >= 720;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const DubaGestBrandLogo(size: 34, showText: true),
        actions: [
          const LanguageMenuButton(),
          const SizedBox(width: AppSpacing.xs),
          IconButton(
            tooltip: l10n.authSignOut,
            style: IconButton.styleFrom(
              foregroundColor: AppColors.muted,
              hoverColor: theme.colorScheme.error.withValues(alpha: 0.1),
            ),
            onPressed: () => ref.read(signOutProvider).call(),
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Badge démarrage
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.greenLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.green.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.green),
                        SizedBox(width: 6),
                        Text(
                          'Écosystème DubaGest',
                          style: TextStyle(
                            color: AppColors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Titre de bienvenue personnalisé
                  Text(
                    nom == null ? l10n.onboardingWelcomeAnonymous : l10n.onboardingWelcome(nom),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Question onboarding
                  Text(
                    l10n.onboardingQuestion,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.muted,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // Grille responsive des choix
                  if (isTabletOrDesktop)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _OnboardingCard(
                              key: const Key('onboarding-create'),
                              isPrimary: true,
                              badgeText: 'Fondateur',
                              icon: Icons.add_business_rounded,
                              title: l10n.onboardingCreateTitle,
                              subtitle: l10n.onboardingCreateSubtitle,
                              bulletPoints: const [
                                'Commerce, Services ou Immobilier',
                                '14 jours d’essai sans engagement',
                                'Gestion d’équipe et rôles inclus',
                              ],
                              buttonLabel: 'Démarrer la création',
                              onTap: () => context.go(Routes.createCompany),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: _OnboardingCard(
                              key: const Key('onboarding-join'),
                              isPrimary: false,
                              badgeText: 'Collaborateur',
                              icon: Icons.group_add_rounded,
                              title: l10n.onboardingJoinTitle,
                              subtitle: l10n.onboardingJoinSubtitle,
                              bulletPoints: const [
                                'Accès par code ou lien d’invitation',
                                'Rôle et permissions configurés',
                                'Aucun abonnement nécessaire',
                              ],
                              buttonLabel: 'Rejoindre une équipe',
                              onTap: () => context.go(Routes.joinCompany),
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    _OnboardingCard(
                      key: const Key('onboarding-create'),
                      isPrimary: true,
                      badgeText: 'Fondateur',
                      icon: Icons.add_business_rounded,
                      title: l10n.onboardingCreateTitle,
                      subtitle: l10n.onboardingCreateSubtitle,
                      bulletPoints: const [
                        'Commerce, Services ou Immobilier',
                        '14 jours d’essai sans engagement',
                        'Gestion d’équipe et rôles inclus',
                      ],
                      buttonLabel: 'Démarrer la création',
                      onTap: () => context.go(Routes.createCompany),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _OnboardingCard(
                      key: const Key('onboarding-join'),
                      isPrimary: false,
                      badgeText: 'Collaborateur',
                      icon: Icons.group_add_rounded,
                      title: l10n.onboardingJoinTitle,
                      subtitle: l10n.onboardingJoinSubtitle,
                      bulletPoints: const [
                        'Accès par code ou lien d’invitation',
                        'Rôle et permissions configurés',
                        'Aucun abonnement nécessaire',
                      ],
                      buttonLabel: 'Rejoindre une équipe',
                      onTap: () => context.go(Routes.joinCompany),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  // Note d'assistance
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.help_outline_rounded, size: 16, color: AppColors.muted),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Besoin d’aide pour commencer ? Vous pouvez inviter des membres à tout moment.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
                        ),
                      ),
                    ],
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

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({
    super.key,
    required this.isPrimary,
    required this.badgeText,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bulletPoints,
    required this.buttonLabel,
    required this.onTap,
  });

  final bool isPrimary;
  final String badgeText;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> bulletPoints;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPrimary ? AppColors.green.withValues(alpha: 0.35) : AppColors.border,
          width: isPrimary ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isPrimary
                ? AppColors.green.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isPrimary
                              ? [AppColors.green, AppColors.greenPressed]
                              : [const Color(0xFF2C3E50), const Color(0xFF1A252F)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: isPrimary
                                ? AppColors.green.withValues(alpha: 0.3)
                                : Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 28),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPrimary ? AppColors.greenLight : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: isPrimary ? AppColors.green : const Color(0xFF475569),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: AppSpacing.md),
                for (final point in bulletPoints) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: isPrimary ? AppColors.green : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            point,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF334155),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isPrimary ? AppColors.green : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          buttonLabel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isPrimary ? Colors.white : AppColors.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: isPrimary ? Colors.white : AppColors.ink,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
