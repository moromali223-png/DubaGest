import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/finance_dashboard_providers.dart';
import '../widgets/chart_depenses_categories.dart';

/// Page d'analyse détaillée des Charges & Dépenses.
class FinanceChargesPage extends ConsumerWidget {
  const FinanceChargesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = NumberFormat.decimalPattern('fr');
    final dataAsync = ref.watch(financeDashboardDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse des Charges'),
      ),
      body: ResponsiveBody(
        maxWidth: 960,
        child: AsyncValueView(
          value: dataAsync,
          data: (data) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // Synthèse
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.negative,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total des dépenses opérationnelles',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${format.format(data.totalDepenses)} FCFA',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Note explicative Charges vs Achats
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 20, color: AppColors.muted),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Les dépenses opérationnelles concernent les charges de fonctionnement (loyer, salaires, électricité). Les achats de stock marchandise sont suivis séparément.',
                          style: TextStyle(fontSize: 12, height: 1.3, color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Répartition par catégorie
                ChartDepensesCategories(categories: data.categoriesDepenses),
                const SizedBox(height: AppSpacing.lg),

                // Liste complète des catégories
                const Text(
                  'Toutes les catégories de charges',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final cat in data.categoriesDepenses)
                  Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ListTile(
                      title: Text(cat.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${cat.pourcentage.toStringAsFixed(1)} % du total des charges'),
                      trailing: Text(
                        '${format.format(cat.montant)} FCFA',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.negative),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
