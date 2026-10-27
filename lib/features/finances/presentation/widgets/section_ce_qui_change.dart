import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/finance_alert.dart';

/// Section intelligente « Ce qui change » affichant les faits marquants calculés.
class SectionCeQuiChange extends StatelessWidget {
  const SectionCeQuiChange({
    super.key,
    required this.faits,
  });

  final List<FaitMarquantFinance> faits;

  @override
  Widget build(BuildContext context) {
    if (faits.isEmpty) {
      return const SizedBox.shrink();
    }

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
              Icon(Icons.insights_rounded, size: 20, color: AppColors.green),
              SizedBox(width: 8),
              Text(
                'Ce qui change',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final f in faits)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    f.positif ? Icons.trending_up_rounded : Icons.info_outline_rounded,
                    size: 18,
                    color: f.positif ? AppColors.positive : AppColors.warning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f.texte,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppColors.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
