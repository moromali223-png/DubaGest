import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/finance_dashboard_data.dart';

/// Comparateur de performance par boutique ou site.
class CardPerformanceBoutiques extends StatelessWidget {
  const CardPerformanceBoutiques({
    super.key,
    required this.performances,
    this.devise = 'FCFA',
    this.onTapBoutique,
  });

  final List<PerformanceBoutique> performances;
  final String devise;
  final void Function(String perimetreId)? onTapBoutique;

  @override
  Widget build(BuildContext context) {
    if (performances.length <= 1) {
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
          const Row(
            children: [
              Icon(Icons.storefront_rounded, size: 20, color: Color(0xFF01226C)),
              SizedBox(width: 8),
              Text(
                'Performance par boutique',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final b in performances)
            InkWell(
              onTap: onTapBoutique != null ? () => onTapBoutique!(b.perimetreId) : null,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.nom,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Caisse : ${format.format(b.soldeCaisse)} $devise · Dépenses : ${format.format(b.depenses)} $devise',
                            style: const TextStyle(fontSize: 11, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${format.format(b.chiffreAffaires)} $devise',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Résultat : ${format.format(b.resultatEstime)} $devise',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: b.resultatEstime >= 0 ? AppColors.positive : AppColors.negative,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
