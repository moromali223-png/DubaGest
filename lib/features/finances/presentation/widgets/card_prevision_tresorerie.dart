import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/finance_forecast.dart';

/// Carte de projection prévisionnelle de trésorerie (J+7, J+30, J+90).
class CardPrevisionTresorerie extends StatelessWidget {
  const CardPrevisionTresorerie({
    super.key,
    required this.previsions,
    this.devise = 'FCFA',
  });

  final PrevisionTresorerie previsions;
  final String devise;

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat.decimalPattern('fr');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: previsions.attentionRequise
              ? AppColors.warning.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph_rounded, size: 20, color: Color(0xFF01226C)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Prévision de trésorerie',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Projection estimée',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            previsions.syntheseGlobale,
            style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _HorizonCard(
                horizon: previsions.horizon7Jours,
                devise: devise,
                format: format,
              ),
              const SizedBox(width: AppSpacing.sm),
              _HorizonCard(
                horizon: previsions.horizon30Jours,
                devise: devise,
                format: format,
                isPrincipal: true,
              ),
              const SizedBox(width: AppSpacing.sm),
              _HorizonCard(
                horizon: previsions.horizon90Jours,
                devise: devise,
                format: format,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HorizonCard extends StatelessWidget {
  const _HorizonCard({
    required this.horizon,
    required this.devise,
    required this.format,
    this.isPrincipal = false,
  });

  final PrevisionHorizon horizon;
  final String devise;
  final NumberFormat format;
  final bool isPrincipal;

  @override
  Widget build(BuildContext context) {
    final couleur = horizon.tensionDetectee
        ? AppColors.negative
        : (horizon.soldePrevu >= 0 ? AppColors.green : AppColors.warning);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isPrincipal ? couleur.withValues(alpha: 0.05) : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrincipal ? couleur.withValues(alpha: 0.2) : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              horizon.libelle,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted),
            ),
            const SizedBox(height: 4),
            Text(
              '${format.format(horizon.soldePrevu)} $devise',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: couleur,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '+${format.format(horizon.encaissementsAttendus)} / -${format.format(horizon.decaissementsPrevus)}',
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
