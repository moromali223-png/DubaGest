import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../modules/domain/entities/app_module.dart';
import '../providers/navigation_providers.dart';

/// Menu modal des actions rapides accessible via le bouton central (+) en multi-activité.
class QuickActionSheet extends ConsumerWidget {
  const QuickActionSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => const QuickActionSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final nav = ref.watch(navigationModelProvider);

    Widget item({
      required IconData icon,
      required Color color,
      required Color background,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Material(
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).pop();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.muted),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final hasCommerce = nav?.sections.any((s) => s.activite.name.toUpperCase() == 'COMMERCE') ?? false;
    final hasServices = nav?.sections.any((s) => s.activite.name.toUpperCase() == 'SERVICES') ?? false;
    final hasImmobilier = nav?.sections.any((s) => s.activite.name.toUpperCase() == 'IMMOBILIER') ?? false;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Actions rapides',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasCommerce || (nav?.venteDisponible ?? false))
              item(
                icon: Icons.point_of_sale_outlined,
                color: AppColors.navy,
                background: AppColors.navySoft,
                title: 'Nouvelle vente',
                subtitle: 'Enregistrer une vente et générer le reçu',
                onTap: () => context.push(ModuleRoutes.path(ModuleCodes.commerceVentes)),
              ),
            if (hasServices)
              item(
                icon: Icons.handyman_outlined,
                color: AppColors.goldDark,
                background: AppColors.goldSoft,
                title: 'Nouvelle prestation',
                subtitle: 'Créer une intervention ou un devis',
                onTap: () => context.push(Routes.prestationNouvelle),
              ),
            if (hasImmobilier)
              item(
                icon: Icons.account_balance_wallet_outlined,
                color: const Color(0xFF0D9488),
                background: const Color(0xFFCCFBF1),
                title: 'Encaisser un loyer',
                subtitle: 'Enregistrer le paiement d\'un locataire',
                onTap: () => context.push(ModuleRoutes.path('immobilier.loyers')),
              ),
            item(
              icon: Icons.receipt_long_outlined,
              color: AppColors.negative,
              background: AppColors.negativeSoft,
              title: 'Enregistrer une dépense',
              subtitle: 'Saisir un achat ou frais d\'exploitation',
              onTap: () => context.push(Routes.depenseNouvelle),
            ),
            item(
              icon: Icons.person_add_alt_1_outlined,
              color: const Color(0xFF6366F1),
              background: const Color(0xFFEEF2FF),
              title: 'Nouveau contact',
              subtitle: 'Ajouter un client, fournisseur ou locataire',
              onTap: () => context.push(Routes.contactNew),
            ),
          ],
        ),
      ),
    );
  }
}
