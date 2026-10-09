import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/finance_dashboard_data.dart';

/// Graphique moderne d'évolution du chiffre d'affaires avec courbe comparative.
class ChartEvolutionCA extends StatelessWidget {
  const ChartEvolutionCA({
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
    if (serie.isEmpty || serie.every((p) => p.valeur == 0)) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'Aucune vente enregistrée sur cette période',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
        ),
      );
    }

    final format = NumberFormat.compact(locale: 'fr');
    final maxVal = serie.map((p) => p.valeur).reduce((a, b) => a > b ? a : b);
    final maxPrec = serie.map((p) => p.valeurPrecedente ?? 0).fold(0, (a, b) => a > b ? a : b);
    final maxEchelle = (maxVal > maxPrec ? maxVal : maxPrec) * 1.2;

    final spotsActuels = <FlSpot>[];
    final spotsPrecedents = <FlSpot>[];

    for (var i = 0; i < serie.length; i++) {
      spotsActuels.add(FlSpot(i.toDouble(), serie[i].valeur.toDouble()));
      if (serie[i].valeurPrecedente != null) {
        spotsPrecedents.add(FlSpot(i.toDouble(), serie[i].valeurPrecedente!.toDouble()));
      }
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
              const Icon(Icons.show_chart_rounded, size: 20, color: Color(0xFF01226C)),
              const SizedBox(width: 8),
              const Text(
                'Évolution du chiffre d’affaires',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              if (onTapDetail != null)
                TextButton(
                  onPressed: onTapDetail,
                  child: const Text('Détail', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Légende
          Row(
            children: [
              Container(width: 12, height: 3, color: const Color(0xFF01226C)),
              const SizedBox(width: 4),
              const Text('Période actuelle', style: TextStyle(fontSize: 11, color: AppColors.muted)),
              if (spotsPrecedents.isNotEmpty) ...[
                const SizedBox(width: 16),
                Container(
                  width: 12,
                  height: 2,
                  decoration: BoxDecoration(
                    color: AppColors.muted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('Période précédente', style: TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxEchelle <= 0 ? 10000 : maxEchelle,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.toInt();
                        if (index < 0 || index >= serie.length) return null;
                        final point = serie[index];
                        final isActuel = spot.barIndex == 0;
                        final val = isActuel ? point.valeur : (point.valeurPrecedente ?? 0);
                        return LineTooltipItem(
                          '${point.label ?? ''}\n${NumberFormat.decimalPattern('fr').format(val)} $devise',
                          TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
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
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value == meta.max) return const SizedBox.shrink();
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
                lineBarsData: [
                  // Ligne Actuelle
                  LineChartBarData(
                    spots: spotsActuels,
                    isCurved: true,
                    curveSmoothness: 0.25,
                    color: const Color(0xFF01226C),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: serie.length <= 14,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 3,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: const Color(0xFF01226C),
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF01226C).withValues(alpha: 0.15),
                          const Color(0xFF01226C).withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                  // Ligne Précédente (fantôme)
                  if (spotsPrecedents.isNotEmpty)
                    LineChartBarData(
                      spots: spotsPrecedents,
                      isCurved: true,
                      curveSmoothness: 0.25,
                      color: AppColors.muted.withValues(alpha: 0.4),
                      barWidth: 2,
                      dashArray: [4, 4],
                      dotData: const FlDotData(show: false),
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
