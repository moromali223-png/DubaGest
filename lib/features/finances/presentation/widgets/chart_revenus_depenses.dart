import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';

/// Comparateur visuel Revenus vs Dépenses avec calcul du solde net.
class ChartRevenusDepenses extends StatelessWidget {
  const ChartRevenusDepenses({
    super.key,
    required this.totalRevenus,
    required this.totalDepenses,
    this.devise = 'FCFA',
    this.onTapDetail,
  });

  final int totalRevenus;
  final int totalDepenses;
  final String devise;
  final VoidCallback? onTapDetail;

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat.decimalPattern('fr');
    final solde = totalRevenus - totalDepenses;
    final total = totalRevenus + totalDepenses;
    final pctRevenus = total > 0 ? (totalRevenus / total) : 0.5;
    final pctDepenses = total > 0 ? (totalDepenses / total) : 0.5;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows_rounded, size: 20, color: AppColors.green),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Revenus vs Dépenses',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (onTapDetail != null)
                TextButton(
                  onPressed: onTapDetail,
                  child: const Text('Détail', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Barre de répartition proportionnelle
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  Expanded(
                    flex: (pctRevenus * 100).round().clamp(1, 100),
                    child: Container(color: AppColors.green),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: (pctDepenses * 100).round().clamp(1, 100),
                    child: Container(color: AppColors.negative),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Wrap : sur un téléphone étroit, les montants passent à la ligne.
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              _FluxItem(
                label: 'Revenus',
                montant: '${format.format(totalRevenus)} $devise',
                couleur: AppColors.green,
                icone: Icons.arrow_downward_rounded,
              ),
              _FluxItem(
                label: 'Dépenses',
                montant: '${format.format(totalDepenses)} $devise',
                couleur: AppColors.negative,
                icone: Icons.arrow_upward_rounded,
              ),
              _FluxItem(
                label: 'Solde net',
                montant: '${solde >= 0 ? '+' : ''}${format.format(solde)} $devise',
                couleur: solde >= 0 ? AppColors.positive : AppColors.negative,
                icone: solde >= 0 ? Icons.check_rounded : Icons.warning_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FluxItem extends StatelessWidget {
  const _FluxItem({
    required this.label,
    required this.montant,
    required this.couleur,
    required this.icone,
  });

  final String label;
  final String montant;
  final Color couleur;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          montant,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: couleur),
        ),
      ],
    );
  }
}
