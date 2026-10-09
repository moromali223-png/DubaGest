import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';

/// Carte de synthèse comparative Créances (« À recevoir ») vs Dettes (« À payer »).
class CardCreancesDettes extends StatelessWidget {
  const CardCreancesDettes({
    super.key,
    required this.aRecevoir,
    required this.nombreDebiteurs,
    required this.creancesEnRetard,
    required this.aPayer,
    required this.nombreCreanciers,
    required this.dettesEnRetard,
    this.devise = 'FCFA',
    this.onTapCreances,
    this.onTapDettes,
  });

  final int aRecevoir;
  final int nombreDebiteurs;
  final int creancesEnRetard;
  final int aPayer;
  final int nombreCreanciers;
  final int dettesEnRetard;
  final String devise;
  final VoidCallback? onTapCreances;
  final VoidCallback? onTapDettes;

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat.decimalPattern('fr');

    return Container(
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
              const Icon(Icons.sync_alt_rounded, size: 20, color: AppColors.gold),
              const SizedBox(width: 8),
              const Text(
                'Créances vs Dettes',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              // Bloc À recevoir
              Expanded(
                child: InkWell(
                  onTap: onTapCreances,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.call_received_rounded, size: 16, color: AppColors.gold),
                            const SizedBox(width: 6),
                            const Flexible(
                              child: Text(
                                'À recevoir',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${format.format(aRecevoir)} $devise',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$nombreDebiteurs client${nombreDebiteurs > 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 11, color: AppColors.muted),
                        ),
                        if (creancesEnRetard > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Dont ${format.format(creancesEnRetard)} en retard',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.negative,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Bloc À payer
              Expanded(
                child: InkWell(
                  onTap: onTapDettes,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.call_made_rounded, size: 16, color: AppColors.negative),
                            const SizedBox(width: 6),
                            const Flexible(
                              child: Text(
                                'À payer',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${format.format(aPayer)} $devise',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$nombreCreanciers fournisseur${nombreCreanciers > 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 11, color: AppColors.muted),
                        ),
                        if (dettesEnRetard > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Dont ${format.format(dettesEnRetard)} en retard',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.negative,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
