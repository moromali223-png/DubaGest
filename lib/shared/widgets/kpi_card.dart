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
    this.badge,
    this.tone = KpiTone.light,
    this.onTap,
  });

  final String label;
  final String value;
  final String? unit;
  final KpiTrend? trend;
  final KpiTrend? badge;
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: sub, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 4),
                    _BadgeEvolution(trend: badge!, tone: tone),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      style: TextStyle(
                        color: fg,
                        fontSize: 22,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
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

class _BadgeEvolution extends StatelessWidget {
  const _BadgeEvolution({required this.trend, required this.tone});
  final KpiTrend trend;
  final KpiTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (trend.kind) {
      KpiTrendKind.good => switch (tone) {
          KpiTone.primary => (Colors.white.withValues(alpha: 0.22), Colors.white),
          KpiTone.dark => (const Color(0xFF1E7E4E).withValues(alpha: 0.35), const Color(0xFF4ADE80)),
          KpiTone.light => (const Color(0xFFE8F5EE), const Color(0xFF1E7E4E)),
        },
      KpiTrendKind.bad => switch (tone) {
          KpiTone.primary => (Colors.black.withValues(alpha: 0.25), const Color(0xFFFFB4B4)),
          KpiTone.dark => (const Color(0xFF7F1D1D).withValues(alpha: 0.35), const Color(0xFFF87171)),
          KpiTone.light => (const Color(0xFFFEE2E2), const Color(0xFFDC2626)),
        },
      KpiTrendKind.warning => switch (tone) {
          KpiTone.primary => (Colors.black.withValues(alpha: 0.2), const Color(0xFFFEF3C7)),
          KpiTone.dark => (const Color(0xFF78350F).withValues(alpha: 0.35), const Color(0xFFFBBF24)),
          KpiTone.light => (const Color(0xFFFDECDA), const Color(0xFFB45309)),
        },
      KpiTrendKind.neutral => switch (tone) {
          KpiTone.primary => (Colors.white.withValues(alpha: 0.18), Colors.white),
          KpiTone.dark => (const Color(0xFF2E403B), const Color(0xFFA5B8B1)),
          KpiTone.light => (const Color(0xFFF1F5F9), const Color(0xFF64748B)),
        },
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        trend.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
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
