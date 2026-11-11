import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:dubagest/app/theme/app_theme.dart';
import 'package:dubagest/features/commerce/domain/entities/benefice_commerce_data.dart';

class ChartEvolutionBenefice extends StatelessWidget {
  const ChartEvolutionBenefice({
    super.key,
    required this.points,
  });

  final List<PointEvolutionBenefice> points;

  String _formatAxeY(double val) {
    if (val.abs() >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(1)}M';
    }
    if (val.abs() >= 1000) {
      return '${(val / 1000).toStringAsFixed(0)}k';
    }
    return val.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    int maxVal = 1000;
    int minVal = 0;

    for (final p in points) {
      maxVal = math.max(maxVal, math.max(p.chiffreAffaires, math.max(p.margeBrute, p.beneficeNet)));
      minVal = math.min(minVal, p.beneficeNet);
    }

    final maxY = (maxVal * 1.15).ceilToDouble();
    final minY = (minVal < 0 ? minVal * 1.15 : 0.0).floorToDouble();

    final spotsCA = <FlSpot>[];
    final spotsMarge = <FlSpot>[];
    final spotsBenefice = <FlSpot>[];

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      spotsCA.add(FlSpot(i.toDouble(), p.chiffreAffaires.toDouble()));
      spotsMarge.add(FlSpot(i.toDouble(), p.margeBrute.toDouble()));
      spotsBenefice.add(FlSpot(i.toDouble(), p.beneficeNet.toDouble()));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Évolution de la Rentabilité',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A2522),
                ),
              ),
              Row(
                children: [
                  _IndicateurLegende(couleur: const Color(0xFF1E7E4E), label: 'Bénéfice'),
                  const SizedBox(width: 8),
                  _IndicateurLegende(couleur: const Color(0xFF0D9488), label: 'Marge'),
                  const SizedBox(width: 8),
                  _IndicateurLegende(couleur: const Color(0xFF94A3B8), label: 'CA Net'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 190,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => const FlLine(
                    color: Color(0xFFF1F5F9),
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
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            _formatAxeY(value),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: math.max(1, (points.length / 5).floor()).toDouble(),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= points.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            points[index].label,
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // CA Net (Arrière-plan gris ardoise léger)
                  LineChartBarData(
                    spots: spotsCA,
                    isCurved: true,
                    color: const Color(0xFFCBD5E1),
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                  ),
                  // Marge Brute (Teal)
                  LineChartBarData(
                    spots: spotsMarge,
                    isCurved: true,
                    color: const Color(0xFF0D9488),
                    barWidth: 2.2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                  ),
                  // Bénéfice Net (Vert Émeraude)
                  LineChartBarData(
                    spots: spotsBenefice,
                    isCurved: true,
                    color: const Color(0xFF1E7E4E),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF1E7E4E).withOpacity(0.12),
                    ),
                    dotData: FlDotData(
                      show: points.length <= 15,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3,
                        color: const Color(0xFF1E7E4E),
                        strokeWidth: 1.5,
                        strokeColor: Colors.white,
                      ),
                    ),
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

class _IndicateurLegende extends StatelessWidget {
  const _IndicateurLegende({
    required this.couleur,
    required this.label,
  });

  final Color couleur;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: couleur,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}

