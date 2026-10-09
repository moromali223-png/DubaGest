import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/finance_dashboard_data.dart';

/// Graphique et indicateurs de marge brute (Commerce).
class ChartMargeCommerce extends StatelessWidget {
  const ChartMargeCommerce({
    super.key,
    required this.marge,
    this.devise = 'FCFA',
  });

  final MargeCommerceData marge;
  final String devise;

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat.decimalPattern('fr');
    final formatCompact = NumberFormat.compact(locale: 'fr');

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
              const Icon(Icons.pie_chart_outline_rounded, size: 20, color: AppColors.gold),
              const SizedBox(width: 8),
              const Text(
                'Marge brute (Commerce)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Marge brute', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  const SizedBox(height: 2),
                  Text(
                    '${format.format(marge.margeBrute)} $devise',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.xl),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Taux de marge', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  const SizedBox(height: 2),
                  Text(
                    '${marge.tauxMargePourcent.toStringAsFixed(1)} %',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: marge.tauxMargePourcent >= 20 ? AppColors.green : AppColors.gold,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.xl),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Coût des ventes', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  const SizedBox(height: 2),
                  Text(
                    '${format.format(marge.coutMarchandisesVendues)} $devise',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.muted),
                  ),
                ],
              ),
            ],
          ),
          if (marge.serieMarge.isNotEmpty && marge.serieMarge.any((p) => p.valeur > 0)) ...[
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 140,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final p = marge.serieMarge[spot.x.toInt()];
                          return LineTooltipItem(
                            '${p.label ?? ''}\nMarge : ${format.format(p.valeur)} $devise',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                          );
                        }).toList();
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
                        reservedSize: 40,
                        getTitlesWidget: (v, meta) => Text(
                          formatCompact.format(v.toInt()),
                          style: const TextStyle(fontSize: 9, color: AppColors.muted),
                        ),
                      ),
                    ),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < marge.serieMarge.length; i++)
                          FlSpot(i.toDouble(), marge.serieMarge[i].valeur.toDouble()),
                      ],
                      isCurved: true,
                      color: AppColors.gold,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.gold.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
