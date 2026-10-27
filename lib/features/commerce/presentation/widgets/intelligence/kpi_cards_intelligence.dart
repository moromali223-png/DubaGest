import 'package:flutter/material.dart';
import 'package:dubagest/app/theme/app_theme.dart';
import 'package:dubagest/features/commerce/domain/entities/intelligence_commerciale_data.dart';

class KpiCardsIntelligence extends StatelessWidget {
  const KpiCardsIntelligence({super.key, required this.resume});
  final ResumeIntelligenceCommerciale resume;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                titre: 'Chiffre d’affaires',
                valeur: '${formatMontant(resume.chiffreAffaires)} F',
                sousTitre: '${resume.nombreVentes} vente(s)',
                variationPct: resume.variationCAPct,
                icone: Icons.point_of_sale_rounded,
                accentColor: const Color(0xFF01226C),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                titre: 'Quantité vendue',
                valeur: resume.quantiteVendue.toStringAsFixed(resume.quantiteVendue.truncateToDouble() == resume.quantiteVendue ? 0 : 1),
                sousTitre: 'Panier moyen : ${formatMontant(resume.panierMoyen)} F',
                variationPct: resume.variationQuantitePct,
                icone: Icons.shopping_bag_outlined,
                accentColor: const Color(0xFFDF9540),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _KpiMargeCard(resume: resume),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiTopProduitCard(resume: resume),
            ),
          ],
        ),
      ],
    );
  }

  static String formatMontant(int montant) {
    final s = montant.toString();
    final buffer = StringBuffer();
    var count = 0;
    for (var i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count % 3 == 0 && i > 0) buffer.write(' ');
    }
    return buffer.toString().split('').reversed.join('');
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.titre,
    required this.valeur,
    required this.sousTitre,
    required this.variationPct,
    required this.icone,
    required this.accentColor,
  });

  final String titre;
  final String valeur;
  final String sousTitre;
  final double? variationPct;
  final IconData icone;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                titre,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icone, size: 15, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            valeur,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (variationPct != null)
                _BadgeVariation(variation: variationPct!)
              else
                const Text(
                  '1re période',
                  style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600),
                ),
              const Spacer(),
              Flexible(
                child: Text(
                  sousTitre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiMargeCard extends StatelessWidget {
  const _KpiMargeCard({required this.resume});
  final ResumeIntelligenceCommerciale resume;

  @override
  Widget build(BuildContext context) {
    final fiable = resume.margeFiable && resume.margeBruteEstimee != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Marge brute',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E7E4E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.savings_outlined, size: 15, color: Color(0xFF1E7E4E)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (fiable) ...[
            Text(
              '${KpiCardsIntelligence.formatMontant(resume.margeBruteEstimee!)} F',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E7E4E),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (resume.variationMargePct != null)
                  _BadgeVariation(variation: resume.variationMargePct!)
                else
                  const Text('Estimée', style: TextStyle(fontSize: 11, color: Color(0xFF1E7E4E), fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  '${resume.pourcentageProduitsAvecMarge.toInt()}% couverts',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ] else ...[
            const Text(
              'Coûts partiels',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFFDF9540),
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Calcul de la marge commerciale'),
                    content: const Text(
                      'Pour calculer une marge fiable et non trompeuse, DubaGest exige que le prix d’achat soit renseigné pour au moins 60% des produits vendus.\n\nRenseignez les prix d’achat dans le catalogue pour activer cet indicateur.',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Compris')),
                    ],
                  ),
                );
              },
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 13, color: Color(0xFFDF9540)),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Renseigner achats',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Color(0xFFDF9540), fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KpiTopProduitCard extends StatelessWidget {
  const _KpiTopProduitCard({required this.resume});
  final ResumeIntelligenceCommerciale resume;

  @override
  Widget build(BuildContext context) {
    final aTop = resume.topProduitNom != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top Produit',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.star_rounded, size: 15, color: Color(0xFF8B5CF6)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            aTop ? resume.topProduitNom! : 'Aucune vente',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          if (aTop && resume.topProduitChiffreAffaires != null)
            Row(
              children: [
                Text(
                  '${KpiCardsIntelligence.formatMontant(resume.topProduitChiffreAffaires!)} F',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF01226C),
                  ),
                ),
                const Spacer(),
                if (resume.topProduitQuantite != null)
                  Text(
                    '${resume.topProduitQuantite!.toStringAsFixed(0)} vendus',
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
              ],
            )
          else
            const Text(
              'En attente de données',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
        ],
      ),
    );
  }
}

class _BadgeVariation extends StatelessWidget {
  const _BadgeVariation({required this.variation});
  final double variation;

  @override
  Widget build(BuildContext context) {
    final estHausse = variation > 0;
    final estNul = variation == 0;
    final couleur = estNul
        ? AppColors.muted
        : (estHausse ? const Color(0xFF1E7E4E) : const Color(0xFFDC2626));
    final signe = estHausse ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            estHausse
                ? Icons.arrow_upward_rounded
                : (estNul ? Icons.remove_rounded : Icons.arrow_downward_rounded),
            size: 11,
            color: couleur,
          ),
          const SizedBox(width: 2),
          Text(
            '$signe${variation.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: couleur,
            ),
          ),
        ],
      ),
    );
  }
}
