import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

enum KpiTone {
  /// Indicateur principal (vert plein).
  primary,

  /// Second indicateur mis en avant (anthracite).
  dark,

  /// Indicateurs courants (carte blanche).
  light,
}

/// Sens d'une évolution : la flèche dit la direction, la couleur dit si
/// c'est bon ou mauvais (jamais la couleur seule).
enum KpiTrendKind { good, bad, warning, neutral }

class KpiTrend {
  const KpiTrend(this.label, this.kind);
  final String label;
  final KpiTrendKind kind;
}

/// Carte d'indicateur chiffré (accueil, finances).
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.trend,
    this.tone = KpiTone.light,
    this.onTap,
  });

  final String label;
  final String value;
  final String? unit;
  final KpiTrend? trend;
  final KpiTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, sub, border) = switch (tone) {
      KpiTone.primary => (AppColors.green, Colors.white, const Color(0xFFE8F5EE), null),
      KpiTone.dark => (AppColors.ink, Colors.white, const Color(0xFFA5B8B1), null),
      KpiTone.light => (AppColors.surface, AppColors.ink, AppColors.muted, AppColors.border),
    };

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: border == null ? BorderSide.none : BorderSide(color: border, width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: sub, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontSize: 21,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  if (unit != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      unit!,
                      style: TextStyle(color: sub, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
              if (trend != null) ...[
                const SizedBox(height: 4),
                _TrendPill(trend: trend!, tone: tone),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendPill extends StatelessWidget {
  const _TrendPill({required this.trend, required this.tone});
  final KpiTrend trend;
  final KpiTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (trend.kind) {
      KpiTrendKind.good => switch (tone) {
          KpiTone.primary => (Colors.white, AppColors.green),
          KpiTone.dark => (const Color(0xFFE8F5EE), AppColors.green),
          KpiTone.light => (const Color(0xFFE8F5EE), AppColors.green),
        },
      KpiTrendKind.bad => switch (tone) {
          KpiTone.primary => (Colors.white, AppColors.negative),
          KpiTone.dark => (const Color(0xFFFEE2E2), AppColors.negative),
          KpiTone.light => (const Color(0xFFFEE2E2), AppColors.negative),
        },
      KpiTrendKind.warning => (const Color(0xFFFDECDA), const Color(0xFFB45309)),
      KpiTrendKind.neutral => switch (tone) {
          KpiTone.primary => (Colors.white, AppColors.green),
          KpiTone.dark => (const Color(0xFF2E403B), Colors.white),
          KpiTone.light => (const Color(0xFFEEF2F0), const Color(0xFF3D4D46)),
        },
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(trend.label, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w800)),
    );
  }
}
