import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/finance_period_filter.dart';
import '../providers/finance_dashboard_providers.dart';

/// Bottom sheet de filtres financiers pour les écrans mobiles.
class BottomSheetFiltreMobile extends ConsumerWidget {
  const BottomSheetFiltreMobile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contexteActifProvider);
    final periode = ref.watch(financePeriodFilterProvider);
    final activite = ref.watch(financeActiviteFilterProvider);
    final perimetreId = ref.watch(financePerimetreFilterProvider);

    final activitesActives = ctx?.activites.where((a) => a.estActive).toList() ?? [];
    final perimetres = ctx?.perimetres.where((p) => p.estActif).toList() ?? [];

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Filtres financiers',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Période
          const Text(
            'Période',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final t in [
                TypePeriodeFinance.aujourdhui,
                TypePeriodeFinance.cetteSemaine,
                TypePeriodeFinance.ceMois,
                TypePeriodeFinance.ceTrimestre,
                TypePeriodeFinance.cetteAnnee,
              ])
                ChoiceChip(
                  label: Text(t.code == 'AUJOURDHUI'
                      ? "Aujourd'hui"
                      : t.code == 'CETTE_SEMAINE'
                          ? 'Cette semaine'
                          : t.code == 'CE_MOIS'
                              ? 'Ce mois'
                              : t.code == 'CE_TRIMESTRE'
                                  ? 'Ce trimestre'
                                  : 'Cette année'),
                  selected: periode.type == t,
                  onSelected: (selected) {
                    if (selected) {
                      ref.read(financePeriodFilterProvider.notifier).choisir(t);
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Activité
          if (activitesActives.length > 1) ...[
            const Text(
              'Activité',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                ChoiceChip(
                  label: const Text('Toutes'),
                  selected: activite == null,
                  onSelected: (s) => ref.read(financeActiviteFilterProvider.notifier).filtrer(null),
                ),
                for (final a in activitesActives)
                  ChoiceChip(
                    label: Text(_nomActivite(a.activite)),
                    selected: activite == a.activite,
                    onSelected: (s) => ref
                        .read(financeActiviteFilterProvider.notifier)
                        .filtrer(s ? a.activite : null),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Boutique / Site
          if (perimetres.length > 1) ...[
            const Text(
              'Boutique / Site',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                ChoiceChip(
                  label: const Text('Toutes les boutiques'),
                  selected: perimetreId == null,
                  onSelected: (s) => ref.read(financePerimetreFilterProvider.notifier).filtrer(null),
                ),
                for (final p in perimetres)
                  ChoiceChip(
                    label: Text(p.nom),
                    selected: perimetreId == p.id,
                    onSelected: (s) => ref
                        .read(financePerimetreFilterProvider.notifier)
                        .filtrer(s ? p.id : null),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Appliquer les filtres', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _nomActivite(ActiviteCode code) => switch (code) {
        ActiviteCode.commerce => 'Commerce',
        ActiviteCode.services => 'Services',
        ActiviteCode.immobilier => 'Immobilier',
      };
}
