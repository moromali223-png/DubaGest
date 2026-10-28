import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

class FloatingNavItem {
  const FloatingNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
}

/// Barre de navigation flottante anthracite : onglet actif en vert (icône,
/// libellé, point), action principale au centre dans un cercle vert.
/// Les libellés restent toujours visibles.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({super.key, required this.items, this.centerAction});

  final List<FloatingNavItem> items;
  final FloatingNavItem? centerAction;

  @override
  Widget build(BuildContext context) {
    final children = [
      for (final item in items) Expanded(child: _Tab(item: item)),
    ];
    if (centerAction != null) {
      children.insert(children.length ~/ 2 + children.length % 2, Expanded(child: _Center(item: centerAction!)));
    }

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 4, 12, bottomInset > 0 ? 4 : 12),
        child: Material(
          color: AppColors.ink,
          elevation: 8,
          shadowColor: AppColors.ink.withValues(alpha: 0.4),
          shape: const StadiumBorder(),
          child: SizedBox(
            height: 66,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(children: children),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item});
  final FloatingNavItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.selected ? AppColors.greenOnDark : AppColors.onInkMuted;
    return Semantics(
      selected: item.selected,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: item.selected ? AppColors.inkRaised : Colors.transparent,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: item.onTap,
            child: SizedBox(
              height: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.selected ? item.selectedIcon : item.icon, color: color, size: 22),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.label,
                      maxLines: 1,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: item.selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (item.selected) ...[
                    const SizedBox(height: 2),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(color: AppColors.greenOnDark, shape: BoxShape.circle),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Center extends StatelessWidget {
  const _Center({required this.item});
  final FloatingNavItem item;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        key: const Key('nav-center-action'),
        customBorder: const StadiumBorder(),
        onTap: item.onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.green,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.green.withValues(alpha: 0.45),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.label,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
