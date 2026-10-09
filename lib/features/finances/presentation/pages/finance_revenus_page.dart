import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/finance_dashboard_providers.dart';
import '../widgets/chart_evolution_ca.dart';

/// Page d'analyse détaillée des Revenus & Chiffre d'affaires.
class FinanceRevenusPage extends ConsumerWidget {
  const FinanceRevenusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = NumberFormat.decimalPattern('fr');
    final dataAsync = ref.watch(financeDashboardDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse des Revenus'),
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
                    color: const Color(0xFF01226C),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chiffre d’affaires total',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${format.format(data.chiffreAffaires.valeurActuelle)} FCFA',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      if (data.chiffreAffaires.tauxEvolution != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              data.chiffreAffaires.estPositif
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 16,
                              color: data.chiffreAffaires.estPositif ? const Color(0xFF2ECC71) : const Color(0xFFF4A99F),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${data.chiffreAffaires.estPositif ? '+' : ''}${data.chiffreAffaires.tauxEvolution!.toStringAsFixed(1)} % vs période précédente',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: data.chiffreAffaires.estPositif ? const Color(0xFF2ECC71) : const Color(0xFFF4A99F),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Graphique
                ChartEvolutionCA(serie: data.serieEvolutionCA),
                const SizedBox(height: AppSpacing.lg),

                // Répartition par activité
                if (data.performancesActivites.isNotEmpty) ...[
                  const Text(
                    'Répartition par activité',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final act in data.performancesActivites)
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        title: Text(act.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Encaissements réels : ${format.format(act.encaissements)} FCFA'),
                        trailing: Text(
                          '${format.format(act.chiffreAffaires)} FCFA',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Répartition par boutique
                if (data.performancesBoutiques.isNotEmpty) ...[
                  const Text(
                    'Performance par boutique',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final b in data.performancesBoutiques)
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        title: Text(b.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Caisse : ${format.format(b.soldeCaisse)} FCFA'),
                        trailing: Text(
                          '${format.format(b.chiffreAffaires)} FCFA',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                        ),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
