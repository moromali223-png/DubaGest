import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/finance_dashboard_data.dart';

/// Répartition des dépenses par catégorie (Top 5).
class ChartDepensesCategories extends StatelessWidget {
  const ChartDepensesCategories({
    super.key,
    required this.categories,
    this.devise = 'FCFA',
    this.onTapDetail,
    this.onTapCategorie,
  });

  final List<CategorieDepenseMontant> categories;
  final String devise;
  final VoidCallback? onTapDetail;
  final void Function(String categorieId)? onTapCategorie;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final format = NumberFormat.decimalPattern('fr');

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
              const Icon(Icons.receipt_long_rounded, size: 20, color: AppColors.negative),
              const SizedBox(width: 8),
              const Text(
                'Top dépenses par catégorie',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              if (onTapDetail != null)
                TextButton(
                  onPressed: onTapDetail,
                  child: const Text('Toutes', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final cat in categories)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: InkWell(
                onTap: onTapCategorie != null ? () => onTapCategorie!(cat.categorieId) : null,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              cat.nom,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          Text(
                            '${format.format(cat.montant)} $devise',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${cat.pourcentage.toStringAsFixed(0)} %)',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (cat.pourcentage / 100).clamp(0.01, 1.0),
                          backgroundColor: AppColors.background,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF01226C)),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
