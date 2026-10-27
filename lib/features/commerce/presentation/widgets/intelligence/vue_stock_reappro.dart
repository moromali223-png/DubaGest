import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dubagest/app/router/routes.dart';
import 'package:dubagest/app/theme/app_theme.dart';
import 'package:dubagest/features/commerce/domain/entities/intelligence_commerciale_data.dart';
import 'kpi_cards_intelligence.dart';

class VueStockReappro extends StatelessWidget {
  const VueStockReappro({super.key, required this.recommandations});
  final List<RecommandationStock> recommandations;

  @override
  Widget build(BuildContext context) {
    if (recommandations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1.2),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_outline_rounded, size: 44, color: Color(0xFF1E7E4E)),
              SizedBox(height: 12),
              Text(
                'Stocks sous contrôle',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              SizedBox(height: 4),
              Text(
                'Aucune rupture imminente ni réapprovisionnement urgent détecté.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
    }

    final nbUrgents = recommandations.where((r) => r.urgence == PrioriteConseil.urgent).length;

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
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Achats & Stock intelligents',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF01226C),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Anticipation des ruptures et quantités conseillées',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (nbUrgents > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$nbUrgents rupture(s)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Cartes de réapprovisionnement
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recommandations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final reco = recommandations[i];
              return _RecommandationStockCard(reco: reco);
            },
          ),
        ],
      ),
    );
  }
}

class _RecommandationStockCard extends StatelessWidget {
  const _RecommandationStockCard({required this.reco});
  final RecommandationStock reco;

  @override
  Widget build(BuildContext context) {
    final estUrgent = reco.urgence == PrioriteConseil.urgent;
    final couleur = estUrgent ? const Color(0xFFDC2626) : const Color(0xFFDF9540);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: couleur.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  estUrgent ? Icons.error_outline_rounded : Icons.alarm_rounded,
                  color: couleur,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reco.nom,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Stock : ${reco.stockActuel.toStringAsFixed(0)} ${reco.uniteBase}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: couleur,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('•', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                        const SizedBox(width: 6),
                        Text(
                          'Vente : ${reco.vitesseVenteJour.toStringAsFixed(1)}/j',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  reco.joursCouverture <= 0
                      ? 'Rupture'
                      : '${reco.joursCouverture.toStringAsFixed(0)} j. restants',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: couleur,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Raisonnement transparent
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
            ),
            child: Text(
              reco.raisonnement,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.ink,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Suggestion de commande & Action
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Commande suggérée :',
                      style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${reco.quantiteRecommandeeEnUniteCommande} ${reco.uniteCommande}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF01226C),
                      ),
                    ),
                    if (reco.estimationCout != null)
                      Text(
                        'Coût estimé : ~${KpiCardsIntelligence.formatMontant(reco.estimationCout!)} F',
                        style: const TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  context.push(
                    Routes.achatNouveau(
                      produitId: reco.produitId,
                      fournisseurId: reco.fournisseurId,
                    ),
                  );
                },
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 15),
                label: const Text('Commander'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF01226C),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
