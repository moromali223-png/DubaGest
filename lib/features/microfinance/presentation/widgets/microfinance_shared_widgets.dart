import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/microfinance_enums.dart';
import '../../domain/entities/microfinance_models.dart';

/// Ouvre l'aperçu PDF natif/PWA avec impression et partage intégrés.
Future<void> ouvrirApercuPdfMicrofinance(
  BuildContext context, {
  required String titre,
  required String fileName,
  required Future<Uint8List> Function() builder,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(titre)),
        body: PdfPreview(
          build: (_) => builder(),
          pdfFileName: fileName,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
        ),
      ),
    ),
  );
}

class StatutPretBadge extends StatelessWidget {
  const StatutPretBadge({super.key, required this.statut});
  final StatutPret statut;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (Color bg, Color fg) = switch (statut) {
      StatutPret.brouillon => (const Color(0xFFF1F5F9), const Color(0xFF475569)),
      StatutPret.enCours => (AppColors.primarySoft, AppColors.primary),
      StatutPret.partiellementRembourse => (const Color(0xFFFEF3C7), const Color(0xFFB45309)),
      StatutPret.solde => (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      StatutPret.enRetard => (AppColors.negativeSoft, AppColors.negative),
      StatutPret.contentieux => (const Color(0xFF7F1D1D), Colors.white),
      StatutPret.annule => (const Color(0xFFE2E8F0), const Color(0xFF64748B)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statut.libelle(l10n.localeName),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class StatutEcheanceBadge extends StatelessWidget {
  const StatutEcheanceBadge({super.key, required this.statut, this.joursRetard = 0});
  final StatutEcheance statut;
  final int joursRetard;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (Color bg, Color fg) = switch (statut) {
      StatutEcheance.aVenir => (const Color(0xFFF1F5F9), const Color(0xFF475569)),
      StatutEcheance.aujourdHui => (const Color(0xFFFEF3C7), const Color(0xFFB45309)),
      StatutEcheance.partiel => (const Color(0xFFFFF7ED), const Color(0xFFC2410C)),
      StatutEcheance.paye => (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      StatutEcheance.enRetard => (AppColors.negativeSoft, AppColors.negative),
      StatutEcheance.annule => (const Color(0xFFE2E8F0), const Color(0xFF64748B)),
    };

    final label = (statut == StatutEcheance.enRetard && joursRetard > 0)
        ? '${statut.libelle(l10n.localeName)} ($joursRetard j)'
        : statut.libelle(l10n.localeName);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class MicrofinanceKpiCard extends StatelessWidget {
  const MicrofinanceKpiCard({
    super.key,
    required this.titre,
    required this.valeur,
    this.sousTitre,
    required this.icone,
    required this.couleur,
    this.onTap,
  });

  final String titre;
  final String valeur;
  final String? sousTitre;
  final IconData icone;
  final Color couleur;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: couleur.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icone, size: 18, color: couleur),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      titre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  valeur,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (sousTitre != null && sousTitre!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  sousTitre!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: couleur,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Graphique synthétique du portefeuille et de la rentabilité Microfinance.
class MicrofinancePortfolioChart extends StatelessWidget {
  const MicrofinancePortfolioChart({
    super.key,
    required this.stats,
    required this.devise,
  });

  final MicrofinanceDashboardStats stats;
  final String devise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final values = [
      stats.totalMontantsDecaisses.toDouble(),
      stats.totalRemboursementsRecus.toDouble(),
      stats.resteAPayerTotal.toDouble(),
      stats.totalInteretsEncaisses.toDouble(),
      stats.montantTotalImpayes.toDouble(),
    ];
    final maxY = values.fold<double>(0, (a, b) => a > b ? a : b);
    if (maxY <= 0) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Enregistrez un prêt pour visualiser la répartition graphique.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final barData = [
      (0, 'Prêté', stats.totalMontantsDecaisses.toDouble(), const Color(0xFF6366F1)),
      (1, 'Total payé', stats.totalRemboursementsRecus.toDouble(), AppColors.primary),
      (2, 'Reste dû', stats.resteAPayerTotal.toDouble(), const Color(0xFF0284C7)),
      (3, 'Intérêts', stats.totalInteretsEncaisses.toDouble(), const Color(0xFF16A34A)),
      (4, 'Impayés', stats.montantTotalImpayes.toDouble(), AppColors.negative),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Synthèse graphique des prêts et remboursements',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Prêts accordés : ${stats.nombrePretsAccordes} • Total payé : ${l10n.montant(stats.totalRemboursementsRecus, devise)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 185,
              child: BarChart(
                BarChartData(
                  maxY: maxY * 1.18,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        getTitlesWidget: (val, _) {
                          final idx = val.toInt();
                          if (idx < 0 || idx >= barData.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              barData[idx].$2,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (final item in barData)
                      BarChartGroupData(
                        x: item.$1,
                        barRods: [
                          BarChartRodData(
                            toY: item.$3,
                            width: 24,
                            color: item.$4,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

