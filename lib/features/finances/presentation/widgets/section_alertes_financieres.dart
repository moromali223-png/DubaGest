import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/finance_alert.dart';

/// Section des alertes financières prioritaires (Urgent, À surveiller, Positif).
class SectionAlertesFinancieres extends StatelessWidget {
  const SectionAlertesFinancieres({
    super.key,
    required this.alertes,
  });

  final List<AlerteFinanciere> alertes;

  @override
  Widget build(BuildContext context) {
    if (alertes.isEmpty) {
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
              Icon(Icons.notifications_active_outlined, size: 20, color: AppColors.gold),
              SizedBox(width: 8),
              Text(
                'Alertes & Opportunités',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final a in alertes)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Color(a.priorite.couleurCode).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Color(a.priorite.couleurCode).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    a.priorite == PrioriteAlerteFinance.urgent
                        ? Icons.error_outline_rounded
                        : a.priorite == PrioriteAlerteFinance.aSurveiller
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline_rounded,
                    size: 18,
                    color: Color(a.priorite.couleurCode),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.titre,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(a.priorite.couleurCode),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          a.description,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
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
