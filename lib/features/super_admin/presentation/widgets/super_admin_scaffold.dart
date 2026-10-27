import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';

class SuperAdminScaffold extends ConsumerWidget {
  const SuperAdminScaffold({
    super.key,
    required this.currentIndex,
    required this.title,
    required this.child,
    this.actions,
    this.floatingActionButton,
  });

  final int currentIndex;
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  static const Color primaryDark = Color(0xFF0F172A); // Slate 900
  static const Color accentIndigo = Color(0xFF6366F1); // Indigo
  static const Color accentPurple = Color(0xFF8B5CF6);

  void _onNavigation(BuildContext context, int index) {
    if (index == currentIndex) return;
    switch (index) {
      case 0:
        context.go(Routes.superAdmin);
        break;
      case 1:
        context.go(Routes.superAdminEntreprises);
        break;
      case 2:
        context.go(Routes.superAdminSponsorises);
        break;
      case 3:
        context.go(Routes.superAdminAudit);
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: primaryDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: 'Retour à l\'application',
          onPressed: () => context.go(Routes.home),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [accentIndigo, accentPurple]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_rounded, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'SUPER ADMIN',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          ...?actions,
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            tooltip: 'Déconnexion',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Déconnexion Super Admin'),
                  content: const Text('Voulez-vous fermer votre session d\'administration centrale ?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Déconnexion'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(signOutProvider).call();
                if (context.mounted) context.go(Routes.login);
              }
            },
          ),
        ],
      ),
      body: Row(
        children: [
          if (isDesktop)
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: (i) => _onNavigation(context, i),
              backgroundColor: primaryDark,
              selectedIconTheme: const IconThemeData(color: Colors.white),
              unselectedIconTheme: const IconThemeData(color: Colors.white54),
              selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              unselectedLabelTextStyle: const TextStyle(color: Colors.white54),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded),
                  label: Text('Tableau de bord'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.business_outlined),
                  selectedIcon: Icon(Icons.business_rounded),
                  label: Text('Entreprises'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.stars_outlined),
                  selectedIcon: Icon(Icons.stars_rounded),
                  label: Text('Partenaires'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.policy_outlined),
                  selectedIcon: Icon(Icons.policy_rounded),
                  label: Text('Audit & Sécurité'),
                ),
              ],
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: (i) => _onNavigation(context, i),
              type: BottomNavigationBarType.fixed,
              backgroundColor: primaryDark,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white54,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              unselectedLabelStyle: const TextStyle(fontSize: 10),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard_rounded),
                  label: 'Tableau bord',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.business_outlined),
                  activeIcon: Icon(Icons.business_rounded),
                  label: 'Entreprises',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.stars_outlined),
                  activeIcon: Icon(Icons.stars_rounded),
                  label: 'Partenaires',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.policy_outlined),
                  activeIcon: Icon(Icons.policy_rounded),
                  label: 'Audit',
                ),
              ],
            ),
      floatingActionButton: floatingActionButton,
    );
  }
}
