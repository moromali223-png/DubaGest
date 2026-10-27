import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Barre de raccourcis rapides inspirée d'Image 2 ("My bonuses, My budget, Finance Analysis").
///
/// Propose 4 cartes carrées modernes aux coins arrondis pour naviguer
/// instantanément vers les sous-modules sans surcharger l'écran.
class BarreRaccourcisFinance extends StatelessWidget {
  const BarreRaccourcisFinance({
    super.key,
    required this.onTapCaisse,
    required this.onTapDepenses,
    required this.onTapDettes,
    required this.onTapAnalyse,
  });

  final VoidCallback onTapCaisse;
  final VoidCallback onTapDepenses;
  final VoidCallback onTapDettes;
  final VoidCallback onTapAnalyse;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final items = [
          _ItemRaccourci(
            icone: Icons.point_of_sale_rounded,
            iconeCouleur: const Color(0xFF2ECC71),
            titre: 'Ma Caisse',
            onTap: onTapCaisse,
          ),
          _ItemRaccourci(
            icone: Icons.receipt_long_rounded,
            iconeCouleur: const Color(0xFFF59E0B),
            titre: 'Dépenses',
            onTap: onTapDepenses,
          ),
          _ItemRaccourci(
            icone: Icons.swap_vert_rounded,
            iconeCouleur: const Color(0xFF38BDF8),
            titre: 'Dettes & Dû',
            onTap: onTapDettes,
          ),
          _ItemRaccourci(
            icone: Icons.insights_rounded,
            iconeCouleur: const Color(0xFFA855F7),
            titre: 'Analyse DAF',
            onTap: onTapAnalyse,
          ),
        ];

        return Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              Expanded(child: items[i]),
              if (i < items.length - 1) const SizedBox(width: AppSpacing.sm),
            ],
          ],
        );
      },
    );
  }
}

class _ItemRaccourci extends StatelessWidget {
  const _ItemRaccourci({
    required this.icone,
    required this.iconeCouleur,
    required this.titre,
    required this.onTap,
  });

  final IconData icone;
  final Color iconeCouleur;
  final String titre;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF141E1B),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF223830),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Squircle pour l'icône (style Image 2)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconeCouleur.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: iconeCouleur.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Icon(icone, color: iconeCouleur, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                titre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
