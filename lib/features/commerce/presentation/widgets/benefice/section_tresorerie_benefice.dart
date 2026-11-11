import 'package:flutter/material.dart';

import 'package:dubagest/app/theme/app_theme.dart';
import 'package:dubagest/features/commerce/domain/entities/benefice_commerce_data.dart';

/// Section affichant les mouvements réels de trésorerie sur la période,
/// en distinguant strictement la rentabilité commerciale des encaissements/décaissements.
class SectionTresorerieBenefice extends StatelessWidget {
  const SectionTresorerieBenefice({
    super.key,
    required this.tresorerie,
    required this.onTapDetail,
  });

  final TresorerieReelleCommerce tresorerie;
  final void Function(String indicateur) onTapDetail;

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
    final estPositif = tresorerie.fluxPositif;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.1),
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
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E7E4E).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF1E7E4E), size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Trésorerie Réelle (Flux financiers)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A2522),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: estPositif ? const Color(0xFFE8F5EE) : const Color(0xFFFFECEB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  estPositif ? 'Flux net +' : 'Flux net -',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: estPositif ? const Color(0xFF1E7E4E) : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Mouvements de caisse réels encaissés et décaissés sur la période. Distinct du compte de résultat commercial.',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
              height: 1.3,
            ),
          ),
          const Divider(height: 20, color: AppColors.border),

          // Ligne 1 : Solde Net Réel
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SOLDE NET DES FLUX',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatMontant(tresorerie.soldeNetFlux),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: estPositif ? const Color(0xFF1E7E4E) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                Icon(
                  estPositif ? Icons.arrow_circle_up_rounded : Icons.arrow_circle_down_rounded,
                  color: estPositif ? const Color(0xFF1E7E4E) : const Color(0xFFDC2626),
                  size: 28,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Ligne 2 : Détail 3 colonnes (Encaissé, Décaissé, Créances restantes)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => onTapDetail('encaisse'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Encaissé',
                          style: TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _formatMontant(tresorerie.totalEncaisse),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E7E4E)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => onTapDetail('decaisse'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Décaissé',
                          style: TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _formatMontant(tresorerie.totalDecaisse),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => onTapDetail('creances'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Créances dues',
                          style: TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _formatMontant(tresorerie.creancesClientsRestantes),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
                          ),
                        ),
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

