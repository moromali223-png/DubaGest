import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Composant de démonstration et d'illustration de la propagation du contexte Boutique
/// dans les futurs modules Vente et Stock.
class BoutiqueContextPreview extends StatelessWidget {
  const BoutiqueContextPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // EXEMPLE 1 : Module Vente
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.point_of_sale_rounded, color: AppColors.green, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Exemple : Contexte dans le module Vente',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Lorsqu\'un vendeur réalise une vente, elle est automatiquement étiquetée avec sa boutique active sans saisie supplémentaire :',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Ticket #REC-000125', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('25 000 FCFA', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF01226C))),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('🏪 Point de vente : Boutique A', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                        Text('👤 Vendeur : Moussa', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // EXEMPLE 2 : Module Stock
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF01226C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF01226C), size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Exemple : Stock Multi-Boutiques',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Stocks isolés physiquement par boutique + Total consolidé dans « Toutes les boutiques » :',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Produit : Ciment 50 kg', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('195 sacs au total', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.green)),
                      ],
                    ),
                    Divider(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('🏪 Boutique A (Centrale)', style: TextStyle(fontSize: 11)),
                        Text('120 sacs', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('🏪 Boutique B (Marché)', style: TextStyle(fontSize: 11)),
                        Text('75 sacs', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
