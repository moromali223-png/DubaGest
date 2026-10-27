import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/finance_forecast.dart';
import '../../domain/entities/finance_health_score.dart';
import '../../domain/entities/finance_dashboard_data.dart';

/// Carte de recommandation intelligente du Conseiller DAF IA.
///
/// Reproduit le badge "AI Coach / Active" du mockup de référence, enrichi par
/// une expertise de Directeur Financier (DAF) avec plus de 15 ans d'expérience
/// (BFR, couverture des charges, recouvrement créances, sécurisation trésorerie).
class CardConseillerCfo extends StatelessWidget {
  const CardConseillerCfo({
    super.key,
    required this.sante,
    required this.previsions,
    required this.recouvrement,
    this.devise = 'FCFA',
    this.onTap,
  });

  final SanteFinanciere sante;
  final PrevisionTresorerie previsions;
  final TauxRecouvrementData recouvrement;
  final String devise;
  final VoidCallback? onTap;

  String _genererConseilExpert() {
    final unite = devise == 'XOF' ? 'FCFA' : devise;

    // 1. Alerte risque de trésorerie / tension détectée
    if (previsions.attentionRequise || previsions.horizon30Jours.tensionDetectee) {
      return previsions.horizon30Jours.message.isNotEmpty
          ? previsions.horizon30Jours.message
          : 'Attention au BFR : risque de tension de liquidités sous 30 jours. Priorisez le recouvrement des créances échues et reportez les décaissements non critiques.';
    }

    // 2. Retards de recouvrement significatifs
    if (recouvrement.resteARecouvrer > 0 && recouvrement.tauxPourcent < 75) {
      final resteFormate = NumberFormat.compact(locale: 'fr').format(recouvrement.resteARecouvrer);
      return 'Recouvrement prioritaire : $resteFormate $unite à sécuriser chez les clients débiteurs pour consolider votre matelas de trésorerie.';
    }

    // 3. Synthèse prévisionnelle positive
    if (previsions.syntheseGlobale.isNotEmpty && !previsions.attentionRequise) {
      return '${previsions.syntheseGlobale}. Continuez à optimiser les délais de paiement fournisseurs.';
    }

    // 4. Par défaut : point fort tiré de la santé financière
    if (sante.pointsForts.isNotEmpty) {
      return '${sante.pointsForts.first}. Structure d\'exploitation solide.';
    }

    return 'Structure financière équilibrée. Le rythme des encaissements couvre les charges d\'exploitation prévues.';
  }

  @override
  Widget build(BuildContext context) {
    final conseil = _genererConseilExpert();

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B2D26),
            Color(0xFF141F1C),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF2A4A3E),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E7E4E).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Illustration / Badge IA
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF2ECC71).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.psychology_rounded,
                    color: Color(0xFF2ECC71),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Flexible(
                            child: Text(
                              'Conseiller DAF IA',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Badge actif avec point vert pulsant
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Actif',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        conseil,
                        style: const TextStyle(
                          color: Color(0xFFA5B8B1),
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: Color(0xFF5A756D),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
