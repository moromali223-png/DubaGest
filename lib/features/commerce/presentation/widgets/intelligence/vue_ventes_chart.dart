import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:dubagest/app/theme/app_theme.dart';
import 'package:dubagest/features/commerce/domain/entities/intelligence_commerciale_data.dart';
import 'kpi_cards_intelligence.dart';

class VueVentesChart extends StatelessWidget {
  const VueVentesChart({
    super.key,
    required this.points,
    required this.resume,
    required this.intervalle,
  });

  final List<PointEvolutionVente> points;
  final ResumeIntelligenceCommerciale resume;
  final IntervallePeriode intervalle;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty || (resume.chiffreAffaires == 0 && resume.chiffreAffairesPrecedent == 0)) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.2),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.query_stats_rounded, size: 40, color: AppColors.muted),
              SizedBox(height: 10),
              Text(
                'Aucune vente sur la période sélectionnée',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
              SizedBox(height: 4),
              Text(
                'Changez la période ou enregistrez des ventes pour visualiser les tendances.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
    }

    final maxCA = points.fold<int>(
      1000,
      (max, p) => math.max(max, math.max(p.chiffreAffaires, p.chiffreAffairesPrecedent)),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Évolution des ventes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF01226C),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Comparaison avec la période précédente',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
              // Légende interactive
              Row(
                children: [
                  _LegendePill(couleur: const Color(0xFF01226C), label: 'Période en cours'),
                  const SizedBox(width: 8),
                  _LegendePill(couleur: const Color(0xFFDF9540), label: 'Précédente', dashed: true),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxCA * 1.15,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxCA > 0 ? (maxCA / 3) : 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.border.withValues(alpha: 0.5),
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
                      reservedSize: 44,
                      interval: maxCA > 0 ? (maxCA / 3) : 1,
                      getTitlesWidget: (val, meta) {
                        if (val == 0) return const SizedBox.shrink();
                        return Text(
                          _formaterK(val.toInt()),
                          style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w600),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: (points.length / 5).ceilToDouble().clamp(1, 100),
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            points[idx].label,
                            style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w600),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Ligne Période précédente (Ambre / tirets)
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < points.length; i++)
                        FlSpot(i.toDouble(), points[i].chiffreAffairesPrecedent.toDouble()),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: const Color(0xFFDF9540).withValues(alpha: 0.8),
                    barWidth: 2,
                    dashArray: [5, 4],
                    dotData: const FlDotData(show: false),
                  ),
                  // Ligne Période actuelle (Bleu royal DubaGest)
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < points.length; i++)
                        FlSpot(i.toDouble(), points[i].chiffreAffaires.toDouble()),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.25,
                    color: const Color(0xFF01226C),
                    barWidth: 3.2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: points.length <= 10,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3.5,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: const Color(0xFF01226C),
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF01226C).withValues(alpha: 0.18),
                          const Color(0xFF01226C).withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.spotIndex;
                        final p = points[idx];
                        if (spot.barIndex == 0) {
                          return LineTooltipItem(
                            'Précédent : ${p.chiffreAffairesPrecedent} F',
                            const TextStyle(color: Color(0xFFDF9540), fontSize: 11, fontWeight: FontWeight.w700),
                          );
                        }
                        return LineTooltipItem(
                          '${p.label}\n${p.chiffreAffaires} F (${p.quantite.toStringAsFixed(0)} art.)',
                          const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          // Répartition Règlement Ventes (Comptant vs Crédit)
          Row(
            children: [
              Expanded(
                child: _ReglementPill(
                  titre: 'Encaissements directs',
                  montant: resume.totalEncaissementsVentes,
                  pct: resume.chiffreAffaires > 0
                      ? (resume.totalEncaissementsVentes / resume.chiffreAffaires) * 100
                      : 0,
                  couleur: const Color(0xFF1E7E4E),
                  icone: Icons.check_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReglementPill(
                  titre: 'Ventes à crédit',
                  montant: resume.totalVentesCredit,
                  pct: resume.chiffreAffaires > 0
                      ? (resume.totalVentesCredit / resume.chiffreAffaires) * 100
                      : 0,
                  couleur: const Color(0xFFDF9540),
                  icone: Icons.pending_actions_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formaterK(int montant) {
    if (montant >= 1000000) {
      return '${(montant / 1000000).toStringAsFixed(1)}M';
    }
    if (montant >= 1000) {
      return '${(montant / 1000).toStringAsFixed(0)}k';
    }
    return montant.toString();
  }
}

class _LegendePill extends StatelessWidget {
  const _LegendePill({required this.couleur, required this.label, this.dashed = false});
  final Color couleur;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: couleur,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ReglementPill extends StatelessWidget {
  const _ReglementPill({
    required this.titre,
    required this.montant,
    required this.pct,
    required this.couleur,
    required this.icone,
  });

  final String titre;
  final int montant;
  final double pct;
  final Color couleur;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: couleur.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icone, color: couleur, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${KpiCardsIntelligence.formatMontant(montant)} F (${pct.toStringAsFixed(0)}%)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: couleur),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
