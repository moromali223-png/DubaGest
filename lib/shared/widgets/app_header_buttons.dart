import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Bouton ☰ : rond sombre anthracite/navy, trois barres (celle du milieu plus
/// courte, alignée sur le début de ligne — à droite en arabe).
class AppMenuButton extends StatelessWidget {
  const AppMenuButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    Widget barre(double largeur) => Container(
          width: largeur,
          height: 2.2,
          decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(2)),
        );

    return Tooltip(
      message: MaterialLocalizations.of(context).openAppDrawerTooltip,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.border, width: 1.2),
        ),
        child: InkWell(
          key: const Key('app-menu-button'),
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: SizedBox(
                width: 18,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [barre(18), const SizedBox(height: 3.5), barre(12), const SizedBox(height: 3.5), barre(18)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Style des boutons d'en-tête secondaires (carré arrondi blanc bordé).
ButtonStyle headerIconButtonStyle(BuildContext context) => IconButton.styleFrom(
      fixedSize: const Size.square(44),
      minimumSize: const Size.square(44),
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.ink,
      side: const BorderSide(color: AppColors.border, width: 1.2),
      shape: const CircleBorder(),
    );
