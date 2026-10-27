import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/finance_health_score.dart';

/// Carte de Santé Financière Globale — Style Exécutif DAF & Directeur Financier.
///
/// Reproduit la jauge circulaire concentrique et les 3 métriques clés du tableau
/// de bord de référence, adaptée à la palette DubaGest (Émeraude, Ardoise, Menthe).
class CardSanteFinanciere extends StatelessWidget {
  const CardSanteFinanciere({
    super.key,
    required this.sante,
    this.chiffreAffaires = 0,
    this.chiffreAffairesPrecedent,
    this.tauxEvolutionCA,
    this.tresorerieDisponible = 0,
    this.tauxRecouvrement = 100.0,
    this.devise = 'FCFA',
    this.periodeLabel = 'Ce mois',
    this.onTap,
    this.onTapCA,
    this.onTapTresorerie,
    this.onTapRecouvrement,
  });

  final SanteFinanciere sante;
  final int chiffreAffaires;
  final int? chiffreAffairesPrecedent;
  final double? tauxEvolutionCA;
  final int tresorerieDisponible;
  final double tauxRecouvrement;
  final String devise;
  final String periodeLabel;
  final VoidCallback? onTap;
  final VoidCallback? onTapCA;
  final VoidCallback? onTapTresorerie;
  final VoidCallback? onTapRecouvrement;

  String _formatMontant(int montant) {
    if (montant >= 1000000) {
      final millions = montant / 1000000;
      return '${millions.toStringAsFixed(millions >= 10 ? 1 : 2)}M $devise';
    } else if (montant >= 1000) {
      final milliers = montant / 1000;
      return '${milliers.toStringAsFixed(0)}k $devise';
    }
    return NumberFormat.decimalPattern('fr').format(montant);
  }

  @override
  Widget build(BuildContext context) {
    final unite = devise == 'XOF' ? 'FCFA' : devise;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xFF141E1B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF243B34),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF1E7E4E).withValues(alpha: 0.08),
            blurRadius: 32,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // En-tête de la carte : Titre + Tag période
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E7E4E).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.donut_large_rounded,
                                size: 16,
                                color: Color(0xFF2ECC71),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Flexible(
                              child: Text(
                                'Santé Financière',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Tag de période (dropdown visual)
                      InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B2A25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF2E463E)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                periodeLabel,
                                style: const TextStyle(
                                  color: Color(0xFFA5B8B1),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 14,
                                color: Color(0xFFA5B8B1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Corps : Jauge circulaire concentrique + Colonne des 3 métriques
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _JaugeCirculaireCentre(sante: sante, onTap: onTap),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          flex: 6,
                          child: _ColonneMetriques(
                            chiffreAffairesLabel: _formatMontant(chiffreAffaires),
                            tauxEvolutionCA: tauxEvolutionCA,
                            tresorerieLabel: _formatMontant(tresorerieDisponible),
                            tauxRecouvrement: tauxRecouvrement,
                            unite: unite,
                            onTapCA: onTapCA,
                            onTapTresorerie: onTapTresorerie,
                            onTapRecouvrement: onTapRecouvrement,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _JaugeCirculaireCentre(sante: sante, onTap: onTap),
                    const SizedBox(height: AppSpacing.md),
                    _ColonneMetriques(
                      chiffreAffairesLabel: _formatMontant(chiffreAffaires),
                      tauxEvolutionCA: tauxEvolutionCA,
                      tresorerieLabel: _formatMontant(tresorerieDisponible),
                      tauxRecouvrement: tauxRecouvrement,
                      unite: unite,
                      onTapCA: onTapCA,
                      onTapTresorerie: onTapTresorerie,
                      onTapRecouvrement: onTapRecouvrement,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Jauge circulaire avec anneaux concentriques et score DAF central.
class _JaugeCirculaireCentre extends StatelessWidget {
  const _JaugeCirculaireCentre({required this.sante, this.onTap});

  final SanteFinanciere sante;
  final VoidCallback? onTap;

  String _badgeTexte() {
    return switch (sante.niveau) {
      NiveauSanteFinanciere.bonne => 'Excellent ⚡',
      NiveauSanteFinanciere.stable => 'Solide 🛡️',
      NiveauSanteFinanciere.aSurveiller => 'Vigilance ⚠️',
      NiveauSanteFinanciere.tension => 'Tension 🚨',
    };
  }

  Color _badgeCouleur() {
    return switch (sante.niveau) {
      NiveauSanteFinanciere.bonne => const Color(0xFF2ECC71),
      NiveauSanteFinanciere.stable => const Color(0xFF38BDF8),
      NiveauSanteFinanciere.aSurveiller => const Color(0xFFF59E0B),
      NiveauSanteFinanciere.tension => const Color(0xFFEF4444),
    };
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = _badgeCouleur();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(180, 180),
                painter: _ConcentricGaugePainter(
                  scoreRatio: (sante.score / 100).clamp(0.0, 1.0),
                  scoreColor: badgeColor,
                ),
              ),
              // Contenu textuel au centre des anneaux
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Score DAF',
                    style: TextStyle(
                      color: Color(0xFFA5B8B1),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${sante.score}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'sur 100',
                    style: TextStyle(
                      color: Color(0xFF718B82),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: badgeColor.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _badgeTexte(),
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Peintre personnalisé pour dessiner la jauge à double anneau concentrique
/// avec extrémités arrondies et dégradé émeraude.
class _ConcentricGaugePainter extends CustomPainter {
  const _ConcentricGaugePainter({
    required this.scoreRatio,
    required this.scoreColor,
  });

  final double scoreRatio;
  final Color scoreColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radiusOuter = size.width / 2 - 12;
    final radiusInner = radiusOuter - 14;

    // Arc ouvert : 270 degrés (de 135° à 405°)
    const startAngle = 0.75 * math.pi;
    const totalSweep = 1.5 * math.pi;

    // 1. Pistes d'arrière-plan (Track)
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9.0
      ..strokeCap = StrokeCap.round;

    // Anneau extérieur track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radiusOuter),
      startAngle,
      totalSweep,
      false,
      trackPaint,
    );

    // Anneau intérieur track
    final innerTrackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radiusInner),
      startAngle,
      totalSweep,
      false,
      innerTrackPaint,
    );

    // 2. Anneau actif extérieur (Score principal avec dégradé émeraude)
    final activeSweepOuter = totalSweep * scoreRatio;
    if (activeSweepOuter > 0) {
      final rectOuter = Rect.fromCircle(center: center, radius: radiusOuter);
      final gradient = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + totalSweep,
        colors: [
          const Color(0xFF1E7E4E),
          scoreColor,
          const Color(0xFF52E592),
        ],
        stops: const [0.0, 0.6, 1.0],
      );

      final activePaintOuter = Paint()
        ..shader = gradient.createShader(rectOuter)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9.0
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rectOuter,
        startAngle,
        activeSweepOuter,
        false,
        activePaintOuter,
      );
    }

    // 3. Anneau actif intérieur (Second anneau d'efficience)
    final secondaryRatio = (scoreRatio * 0.9).clamp(0.1, 1.0);
    final activeSweepInner = totalSweep * secondaryRatio;
    if (activeSweepInner > 0) {
      final activePaintInner = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radiusInner),
        startAngle,
        activeSweepInner,
        false,
        activePaintInner,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConcentricGaugePainter oldDelegate) {
    return oldDelegate.scoreRatio != scoreRatio || oldDelegate.scoreColor != scoreColor;
  }
}

/// Colonne des 3 métriques alignées à droite, style cartes pillules du mockup.
class _ColonneMetriques extends StatelessWidget {
  const _ColonneMetriques({
    required this.chiffreAffairesLabel,
    required this.tauxEvolutionCA,
    required this.tresorerieLabel,
    required this.tauxRecouvrement,
    required this.unite,
    this.onTapCA,
    this.onTapTresorerie,
    this.onTapRecouvrement,
  });

  final String chiffreAffairesLabel;
  final double? tauxEvolutionCA;
  final String tresorerieLabel;
  final double tauxRecouvrement;
  final String unite;
  final VoidCallback? onTapCA;
  final VoidCallback? onTapTresorerie;
  final VoidCallback? onTapRecouvrement;

  @override
  Widget build(BuildContext context) {
    final evolutionTexte = tauxEvolutionCA != null
        ? '${tauxEvolutionCA! >= 0 ? '+' : ''}${tauxEvolutionCA!.toStringAsFixed(1)}%'
        : 'Activité';

    return Column(
      children: [
        // 1. Chiffre d'affaires
        _MetriqueLigne(
          icone: Icons.local_fire_department_rounded,
          iconeCouleur: const Color(0xFF2ECC71),
          titre: 'Chiffre d’Affaires',
          valeur: chiffreAffairesLabel,
          sousTitre: evolutionTexte,
          onTap: onTapCA,
        ),
        const SizedBox(height: AppSpacing.sm),

        // 2. Trésorerie Active
        _MetriqueLigne(
          icone: Icons.account_balance_wallet_rounded,
          iconeCouleur: const Color(0xFF38BDF8),
          titre: 'Trésorerie Active',
          valeur: tresorerieLabel,
          sousTitre: 'Liquidités nettes',
          onTap: onTapTresorerie,
        ),
        const SizedBox(height: AppSpacing.sm),

        // 3. Taux de Recouvrement
        _MetriqueLigne(
          icone: Icons.shield_rounded,
          iconeCouleur: const Color(0xFFF59E0B),
          titre: 'Recouvrement',
          valeur: '${tauxRecouvrement.toStringAsFixed(0)}%',
          sousTitre: 'Créances sécurisées',
          onTap: onTapRecouvrement,
        ),
      ],
    );
  }
}

class _MetriqueLigne extends StatelessWidget {
  const _MetriqueLigne({
    required this.icone,
    required this.iconeCouleur,
    required this.titre,
    required this.valeur,
    required this.sousTitre,
    this.onTap,
  });

  final IconData icone;
  final Color iconeCouleur;
  final String titre;
  final String valeur;
  final String sousTitre;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1B2824),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconeCouleur.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icone, color: iconeCouleur, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titre,
                      style: const TextStyle(
                        color: Color(0xFFA5B8B1),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      valeur,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    sousTitre,
                    style: TextStyle(
                      color: iconeCouleur,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: Color(0xFF5A756D),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
