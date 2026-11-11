import 'package:flutter/material.dart';

import 'package:dubagest/app/theme/app_theme.dart';
import 'package:dubagest/features/commerce/domain/entities/benefice_commerce_data.dart';

/// Cartes d'indicateurs maîtres du module Bénéfice.
class KpiCardsBenefice extends StatelessWidget {
  const KpiCardsBenefice({
    super.key,
    required this.kpi,
    required this.onTapDetail,
    required this.onTapProduitsSansCout,
  });

  final KpiBeneficeCommerce kpi;
  final void Function(String indicateur) onTapDetail;
  final VoidCallback onTapProduitsSansCout;

  String _formatMontant(int montant) {
    final s = montant.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buffer.write('\u00A0');
      }
      buffer.write(s[i]);
    }
    final signe = montant < 0 ? '-' : '';
    return '$signe${buffer.toString()} FCFA';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final estPositif = kpi.beneficeNetEstime >= 0;
    final couleurMaitre = estPositif ? const Color(0xFF1E7E4E) : const Color(0xFFD32F2F);
    final variationBenefice = kpi.variationBeneficePct;
    final variationCA = kpi.variationCAPct;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. CARTE PRINCIPALE : BÉNÉFICE NET ESTIMÉ
        InkWell(
          onTap: () => onTapDetail('benefice'),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: estPositif
                    ? [const Color(0xFF143E28), const Color(0xFF1E7E4E)]
                    : [const Color(0xFF4A1010), const Color(0xFF8B1E1E)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: couleurMaitre.withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            estPositif ? Icons.trending_up : Icons.trending_down,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'BÉNÉFICE NET ESTIMÉ',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    if (variationBenefice != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${variationBenefice >= 0 ? '+' : ''}${variationBenefice.toStringAsFixed(1)}% vs N-1',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _formatMontant(kpi.beneficeNetEstime),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Taux de rentabilité nette : ${kpi.tauxBeneficeNet.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Voir le détail',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 10),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 2. BANNIÈRE DE FIABILITÉ / COUVERTURE DU COÛT DE REVIENT
        if (!kpi.couvertureFiable && kpi.lignesTotal > 0)
          InkWell(
            onTap: onTapProduitsSansCout,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFEEBA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFF856404), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Attention : seuls ${kpi.tauxCouvertureCout.toStringAsFixed(0)}% des articles ont un prix d\'achat renseigné. Cliquez pour voir les articles.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF856404),
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Color(0xFF856404), size: 12),
                ],
              ),
            ),
          )
        else if (kpi.lignesTotal > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5EE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified, color: Color(0xFF1E7E4E), size: 15),
                const SizedBox(width: 6),
                Text(
                  'Coût de revient renseigné sur ${kpi.tauxCouvertureCout.toStringAsFixed(0)}% des ventes (calcul fiable)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E7E4E),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // 3. GRILLE DES 4 INDICATEURS SECONDAIRES
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                // CHIFFRE D'AFFAIRES NET
                _SecondaireCard(
                  width: cardWidth,
                  titre: 'Chiffre d\'affaires net',
                  montant: _formatMontant(kpi.chiffreAffairesNet),
                  sousTitre: '${kpi.nombreVentes} vente${kpi.nombreVentes > 1 ? 's' : ''}',
                  badgeVariation: variationCA != null
                      ? '${variationCA >= 0 ? '+' : ''}${variationCA.toStringAsFixed(1)}%'
                      : null,
                  badgeVariationPositive: (variationCA ?? 0) >= 0,
                  icone: Icons.point_of_sale,
                  couleurIcone: const Color(0xFF1E7E4E),
                  onTap: () => onTapDetail('ca'),
                ),

                // COÛT DES MARCHANDISES VENDUES (COGS)
                _SecondaireCard(
                  width: cardWidth,
                  titre: 'Coût des ventes (COGS)',
                  montant: _formatMontant(kpi.cogs),
                  sousTitre: 'Stock vendu déduit',
                  icone: Icons.inventory_2_outlined,
                  couleurIcone: const Color(0xFFD97706),
                  onTap: () => onTapDetail('cogs'),
                ),

                // MARGE BRUTE
                _SecondaireCard(
                  width: cardWidth,
                  titre: 'Marge brute',
                  montant: _formatMontant(kpi.margeBrute),
                  sousTitre: 'Taux : ${kpi.tauxMarge.toStringAsFixed(1)}%',
                  icone: Icons.pie_chart_outline,
                  couleurIcone: const Color(0xFF0D9488),
                  onTap: () => onTapDetail('marge'),
                ),

                // DÉPENSES COMMERCIALES
                _SecondaireCard(
                  width: cardWidth,
                  titre: 'Dépenses commerce',
                  montant: _formatMontant(kpi.depensesCommerciales),
                  sousTitre: 'Charges imputables',
                  icone: Icons.receipt_long_outlined,
                  couleurIcone: const Color(0xFFDC2626),
                  onTap: () => onTapDetail('depenses'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SecondaireCard extends StatelessWidget {
  const _SecondaireCard({
    required this.width,
    required this.titre,
    required this.montant,
    required this.sousTitre,
    required this.icone,
    required this.couleurIcone,
    required this.onTap,
    this.badgeVariation,
    this.badgeVariationPositive = true,
  });

  final double width;
  final String titre;
  final String montant;
  final String sousTitre;
  final IconData icone;
  final Color couleurIcone;
  final VoidCallback onTap;
  final String? badgeVariation;
  final bool badgeVariationPositive;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1.1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: couleurIcone.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icone, color: couleurIcone, size: 16),
                ),
                if (badgeVariation != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeVariationPositive ? const Color(0xFFE8F5EE) : const Color(0xFFFFECEB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeVariation!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: badgeVariationPositive ? const Color(0xFF1E7E4E) : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              titre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                montant,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A2522),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sousTitre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

