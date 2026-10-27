import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/finance_dashboard_data.dart';

/// Graphique d'évolution du chiffre d'affaires & flux d'activité.
///
/// Reproduit le design du graphe "Heart Rate" du mockup : carte sombre élégante,
/// indicateur "• En direct", courbe émeraude lissée avec halo dégradé,
/// et repère lumineux sur la dernière valeur enregistrée.
class ChartEvolutionCA extends StatelessWidget {
  const ChartEvolutionCA({
    super.key,
    required this.serie,
    this.totalPeriode,
    this.devise = 'FCFA',
    this.onTapDetail,
  });

  final List<PointSerieTemporelle> serie;
  final int? totalPeriode;
  final String devise;
  final VoidCallback? onTapDetail;

  @override
  Widget build(BuildContext context) {
    final unite = devise == 'XOF' ? 'FCFA' : devise;
    final total = totalPeriode ?? (serie.isEmpty ? 0 : serie.map((p) => p.valeur).fold<int>(0, (a, b) => a + b));

    if (serie.isEmpty || serie.every((p) => p.valeur == 0)) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFF141E1B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF243B34)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2A25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.show_chart_rounded, size: 28, color: Color(0xFF5A756D)),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Aucune transaction sur cette période',
                  style: TextStyle(fontSize: 13, color: Color(0xFFA5B8B1), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final format = NumberFormat.compact(locale: 'fr');
    final maxVal = serie.map((p) => p.valeur).reduce((a, b) => a > b ? a : b);
    final maxPrec = serie.map((p) => p.valeurPrecedente ?? 0).fold<int>(0, (a, b) => a > b ? a : b);
    final maxEchelle = (maxVal > maxPrec ? maxVal : maxPrec) * 1.25;

    final spotsActuels = <FlSpot>[];
    final spotsPrecedents = <FlSpot>[];

    for (var i = 0; i < serie.length; i++) {
      spotsActuels.add(FlSpot(i.toDouble(), serie[i].valeur.toDouble()));
      if (serie[i].valeurPrecedente != null) {
        spotsPrecedents.add(FlSpot(i.toDouble(), serie[i].valeurPrecedente!.toDouble()));
      }
    }

    // Dernier point pour le halo "Live"
    final dernierSpot = spotsActuels.isNotEmpty ? spotsActuels.last : null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF141E1B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF243B34),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. En-tête : Rythme de Trésorerie & Badge "• En direct"
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E7E4E).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  size: 16,
                  color: Color(0xFF2ECC71),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: const Text(
                  'Rythme de Trésorerie & CA',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Badge "• En direct" (style Live du mockup)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2A25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2E463E)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2ECC71),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF2ECC71),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'En direct',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2ECC71),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Chiffre Clé & Sous-titre stratégique DAF
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                NumberFormat.decimalPattern('fr').format(total),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                unite,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2ECC71),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Flux d’encaissements validés • Solvabilité préservée',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFFA5B8B1),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // 3. Graphique FL_CHART
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxEchelle <= 0 ? 10000 : maxEchelle,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1B2A25),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.toInt();
                        if (index < 0 || index >= serie.length) return null;
                        final point = serie[index];
                        final isActuel = spot.barIndex == 0;
                        final val = isActuel ? point.valeur : (point.valeurPrecedente ?? 0);
                        return LineTooltipItem(
                          '${point.label ?? ''}\n${NumberFormat.decimalPattern('fr').format(val)} $unite',
                          const TextStyle(
                            color: Color(0xFF2ECC71),
                            fontWeight: FontWeight.w700,
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
                    color: Colors.white.withValues(alpha: 0.05),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value == meta.max) return const SizedBox.shrink();
                        return Text(
                          format.format(value.toInt()),
                          style: const TextStyle(fontSize: 10, color: Color(0xFF5A756D), fontWeight: FontWeight.w600),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (serie.length / 5).clamp(1.0, 10.0),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= serie.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            serie[index].label ?? '',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF718B82), fontWeight: FontWeight.w600),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Courbe Actuelle (Vibrant Neon Emerald avec Halo)
                  LineChartBarData(
                    spots: spotsActuels,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF2ECC71),
                    barWidth: 3.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, barData) {
                        // Montre un point brillant sur le dernier spot (style marker 128 du mockup)
                        return dernierSpot != null && spot.x == dernierSpot.x;
                      },
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 5,
                        color: const Color(0xFF2ECC71),
                        strokeWidth: 3,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF2ECC71).withValues(alpha: 0.30),
                          const Color(0xFF1E7E4E).withValues(alpha: 0.10),
                          const Color(0xFF1E7E4E).withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                  // Courbe Période Précédente (Ligne fantôme en pointillés)
                  if (spotsPrecedents.isNotEmpty)
                    LineChartBarData(
                      spots: spotsPrecedents,
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: const Color(0xFF5A756D).withValues(alpha: 0.6),
                      barWidth: 2,
                      dashArray: [4, 4],
                      dotData: const FlDotData(show: false),
                    ),
                ],
              ),
            ),
          ),

          if (onTapDetail != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onTapDetail,
                icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF2ECC71)),
                label: const Text(
                  'Voir le journal détaillé',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2ECC71)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
