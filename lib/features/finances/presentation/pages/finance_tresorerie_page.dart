import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/finance_dashboard_providers.dart';
import '../widgets/chart_evolution_tresorerie.dart';

/// Page d'analyse détaillée de la Trésorerie et des Flux de liquidités.
class FinanceTresoreriePage extends ConsumerWidget {
  const FinanceTresoreriePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = NumberFormat.decimalPattern('fr');
    final dataAsync = ref.watch(financeDashboardDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse de la Trésorerie'),
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
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Argent réellement disponible (Trésorerie)',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${format.format(data.tresorerieDisponible.valeurActuelle)} FCFA',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Entrées réelles', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                const SizedBox(height: 2),
                                Text(
                                  '+${format.format(data.fluxTresorerie.entreesReelles)} FCFA',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF2ECC71)),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Sorties réelles', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                const SizedBox(height: 2),
                                Text(
                                  '-${format.format(data.fluxTresorerie.sortiesReelles)} FCFA',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFF4A99F)),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Flux net', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                const SizedBox(height: 2),
                                Text(
                                  '${data.fluxTresorerie.fluxNet >= 0 ? '+' : ''}${format.format(data.fluxTresorerie.fluxNet)} FCFA',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: data.fluxTresorerie.fluxNet >= 0 ? const Color(0xFF2ECC71) : const Color(0xFFF4A99F),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Note transferts internes
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.swap_horiz_rounded, size: 20, color: AppColors.muted),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Règle d’intégrité DUBAGEST : Les transferts entre deux caisses ou deux boutiques sont neutralisés et ne sont jamais comptés comme des revenus ou des dépenses.',
                          style: TextStyle(fontSize: 12, height: 1.3, color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Graphique des flux
                ChartEvolutionTresorerie(serie: data.serieEvolutionTresorerie),
                const SizedBox(height: AppSpacing.lg),

                // Soldes par boutique
                if (data.performancesBoutiques.isNotEmpty) ...[
                  const Text(
                    'Disponibilités par boutique / caisse',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final b in data.performancesBoutiques)
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.background,
                          child: Icon(Icons.point_of_sale_rounded, size: 20, color: Color(0xFF01226C)),
                        ),
                        title: Text(b.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Text(
                          '${format.format(b.soldeCaisse)} FCFA',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink),
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
