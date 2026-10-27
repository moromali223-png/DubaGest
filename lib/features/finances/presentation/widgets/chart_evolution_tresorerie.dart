import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/finance_dashboard_data.dart';

/// Graphique d'évolution réelle du solde de trésorerie.
class ChartEvolutionTresorerie extends StatelessWidget {
  const ChartEvolutionTresorerie({
    super.key,
    required this.serie,
    this.devise = 'FCFA',
    this.onTapDetail,
  });

  final List<PointSerieTemporelle> serie;
  final String devise;
  final VoidCallback? onTapDetail;

  @override
  Widget build(BuildContext context) {
    if (serie.isEmpty) {
      return const SizedBox.shrink();
    }

    final format = NumberFormat.compact(locale: 'fr');
    final spots = <FlSpot>[];
    for (var i = 0; i < serie.length; i++) {
      spots.add(FlSpot(i.toDouble(), serie[i].valeur.toDouble()));
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
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, size: 20, color: AppColors.green),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Flux de trésorerie journalier',
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
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final point = serie[group.x.toInt()];
                      final val = rod.toY.toInt();
                      return BarTooltipItem(
                        '${point.label ?? ''}\n${val >= 0 ? '+' : ''}${NumberFormat.decimalPattern('fr').format(val)} $devise',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.border.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(
                          format.format(value.toInt()),
                          style: const TextStyle(fontSize: 10, color: AppColors.muted),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (serie.length / 6).clamp(1.0, 10.0),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= serie.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            serie[index].label ?? '',
                            style: const TextStyle(fontSize: 10, color: AppColors.muted),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  for (var i = 0; i < serie.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: serie[i].valeur.toDouble(),
                          color: serie[i].valeur >= 0 ? AppColors.green : AppColors.negative,
                          width: (180 / serie.length).clamp(4.0, 14.0),
                          borderRadius: BorderRadius.circular(3),
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
