import 'package:flutter/material.dart';

import 'package:dubagest/app/theme/app_theme.dart';
import 'package:dubagest/features/commerce/domain/entities/benefice_commerce_data.dart';

/// Graphique et liste de répartition des dépenses par catégorie.
class ChartRepartitionDepenses extends StatelessWidget {
  const ChartRepartitionDepenses({
    super.key,
    required this.depenses,
    required this.totalDepenses,
  });

  final List<RepartitionDepenseItem> depenses;
  final int totalDepenses;

  String _formatMontant(int montant) {
    final s = montant.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buffer.write('\u00A0');
      }
      buffer.write(s[i]);
    }
    return '${buffer.toString()} FCFA';
  }

  @override
  Widget build(BuildContext context) {
    if (depenses.isEmpty || totalDepenses == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.1),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Aucune dépense commerciale enregistrée sur cette période.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ),
        ),
      );
    }

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
              const Text(
                'Répartition des Dépenses',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A2522),
                ),
              ),
              Text(
                'Total : ${_formatMontant(totalDepenses)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Barre horizontale proportionnelle
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  for (final item in depenses)
                    Expanded(
                      flex: (item.pourcentage * 10).clamp(1, 1000).toInt(),
                      child: Container(
                        color: _couleurCategorie(item.categorieNom),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Liste détaillée des catégories
          Column(
            children: [
              for (final item in depenses) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _couleurCategorie(item.categorieNom),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.categorieNom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                      Text(
                        _formatMontant(item.total),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A2522),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 44,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${item.pourcentage.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _couleurCategorie(String nom) {
    final lower = nom.toLowerCase();
    if (lower.contains('loyer')) return const Color(0xFF3B82F6);
    if (lower.contains('salaire') || lower.contains('personnel')) return const Color(0xFF8B5CF6);
    if (lower.contains('electr') || lower.contains('energie') || lower.contains('eau')) return const Color(0xFFF59E0B);
    if (lower.contains('transport') || lower.contains('carburant')) return const Color(0xFF06B6D4);
    if (lower.contains('impot') || lower.contains('taxe')) return const Color(0xFFEF4444);
    if (lower.contains('fourniture') || lower.contains('emballage')) return const Color(0xFF10B981);
    return const Color(0xFF64748B);
  }
}

