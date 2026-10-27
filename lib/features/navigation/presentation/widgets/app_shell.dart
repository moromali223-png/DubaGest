import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../modules/domain/entities/app_module.dart';
import '../../domain/entities/navigation_model.dart';
import '../providers/navigation_providers.dart';
import 'floating_nav_bar.dart';
import 'quick_action_sheet.dart';

/// Coque de navigation adaptative :
/// - mobile (< 600 dp) : barre flottante anthracite en bas, au pouce ;
/// - tablette / desktop : rail latéral anthracite.
/// Les destinations et l'action principale proviennent du NavigationModel
/// (droits réels et activité active).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static String pathOf(NavDestination d) => switch (d) {
        NavDestination.accueil => Routes.home,
        NavDestination.stock => ModuleRoutes.path(ModuleCodes.commerceStock),
        NavDestination.prestations => ModuleRoutes.path('services.prestations'),
        NavDestination.loyers => ModuleRoutes.path('immobilier.loyers'),
        NavDestination.ventes => ModuleRoutes.path(ModuleCodes.commerceVentes),
        NavDestination.finances => Routes.finances,
        NavDestination.compte => Routes.settings,
      };

  NavDestination _current() {
    if (location.startsWith(ModuleRoutes.path(ModuleCodes.commerceStock))) return NavDestination.stock;
    if (location.startsWith(ModuleRoutes.path('services.prestations'))) return NavDestination.prestations;
    if (location.startsWith(ModuleRoutes.path('immobilier.loyers'))) return NavDestination.loyers;
    if (location.startsWith(ModuleRoutes.path(ModuleCodes.commerceVentes))) return NavDestination.ventes;
    if (location.startsWith(Routes.finances)) return NavDestination.finances;
    if (location.startsWith(Routes.settings)) return NavDestination.compte;
    return NavDestination.accueil;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final nav = ref.watch(navigationModelProvider);
    final destinations = nav?.destinations ?? const [NavDestination.accueil, NavDestination.compte];
    final current = _current();

    (IconData, IconData, String) visual(NavDestination d) => switch (d) {
          NavDestination.accueil => (Icons.home_outlined, Icons.home_rounded, l10n.navHome),
          NavDestination.stock => (Icons.inventory_2_outlined, Icons.inventory_2, l10n.navStock),
          NavDestination.prestations => (Icons.assignment_outlined, Icons.assignment, 'Contrats'),
          NavDestination.loyers => (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Loyers'),
          NavDestination.ventes => (Icons.point_of_sale_outlined, Icons.point_of_sale, 'Ventes'),
          NavDestination.finances => (Icons.insights_outlined, Icons.insights, l10n.navFinances),
          NavDestination.compte => (Icons.person_outline_rounded, Icons.person_rounded, l10n.navAccount),
        };

    final actionType = nav?.actionCentrale ?? (nav?.venteDisponible == true ? QuickActionType.vendre : null);

    FloatingNavItem? centerButton() {
      if (actionType == null) return null;
      final (IconData icon, String label, VoidCallback action) = switch (actionType) {
        QuickActionType.vendre => (
            Icons.add_rounded,
            l10n.navSell,
            () => context.push(ModuleRoutes.path(ModuleCodes.commerceVentes)),
          ),
        QuickActionType.prester => (
            Icons.add_rounded,
            'Prester',
            () => context.push(Routes.prestationNouvelle),
          ),
        QuickActionType.encaisser => (
            Icons.add_rounded,
            'Encaisser',
            () => context.push(Routes.paiementNouveau()),
          ),
        QuickActionType.multi => (
            Icons.add_rounded,
            'Action',
            () => QuickActionSheet.show(context),
          ),
      };

      return FloatingNavItem(
        icon: icon,
        selectedIcon: icon,
        label: label,
        selected: false,
        onTap: action,
      );
    }

    final content = Column(children: [const OfflineBanner(), Expanded(child: child)]);

    if (MediaQuery.sizeOf(context).width < AppBreakpoints.medium) {
      return Scaffold(
        body: content,
        bottomNavigationBar: FloatingNavBar(
          items: [
            for (final d in destinations)
              FloatingNavItem(
                icon: visual(d).$1,
                selectedIcon: visual(d).$2,
                label: visual(d).$3,
                selected: d == current,
                onTap: () => context.go(pathOf(d)),
              ),
          ],
          centerAction: centerButton(),
        ),
      );
    }

    final selected = destinations.indexOf(current).clamp(0, destinations.length - 1);
    final cBtn = centerButton();

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: AppColors.ink,
            indicatorColor: AppColors.inkRaised,
            selectedIndex: selected,
            onDestinationSelected: (i) => context.go(pathOf(destinations[i])),
            labelType: NavigationRailLabelType.all,
            selectedIconTheme: const IconThemeData(color: AppColors.greenOnDark),
            unselectedIconTheme: const IconThemeData(color: AppColors.onInkMuted),
            selectedLabelTextStyle:
                const TextStyle(color: AppColors.greenOnDark, fontWeight: FontWeight.w800, fontSize: 12),
            unselectedLabelTextStyle:
                const TextStyle(color: AppColors.onInkMuted, fontWeight: FontWeight.w600, fontSize: 12),
            leading: cBtn != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: FloatingActionButton(
                      key: const Key('rail-sell'),
                      tooltip: cBtn.label,
                      onPressed: cBtn.onTap,
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.ink,
                      child: Icon(cBtn.icon),
                    ),
                  )
                : null,
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(
                  icon: Icon(visual(d).$1),
                  selectedIcon: Icon(visual(d).$2),
                  label: Text(visual(d).$3),
                ),
            ],
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}
