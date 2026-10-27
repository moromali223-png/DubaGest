import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dubagest/app/theme/app_theme.dart';
import 'package:dubagest/features/commerce/domain/entities/intelligence_commerciale_data.dart';
import 'kpi_cards_intelligence.dart';

enum CritereTriProduit {
  chiffreAffaires('Chiffre d’affaires'),
  quantite('Quantités vendues'),
  marge('Marge brute'),
  vitesse('Vitesse de vente');

  const CritereTriProduit(this.libelle);
  final String libelle;
}

enum FiltreTendance {
  tous('Tous'),
  progression('En hausse 🚀'),
  ralentissement('En baisse ⚠️');

  const FiltreTendance(this.libelle);
  final String libelle;
}

class VueProduitsRanking extends StatefulWidget {
  const VueProduitsRanking({
    super.key,
    required this.produits,
    required this.progressions,
    required this.ralentissements,
  });

  final List<PerformanceProduit> produits;
  final List<TendanceProduit> progressions;
  final List<TendanceProduit> ralentissements;

  @override
  State<VueProduitsRanking> createState() => _VueProduitsRankingState();
}

class _VueProduitsRankingState extends State<VueProduitsRanking> {
  CritereTriProduit _tri = CritereTriProduit.chiffreAffaires;
  FiltreTendance _filtre = FiltreTendance.tous;

  @override
  Widget build(BuildContext context) {
    if (widget.produits.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.2),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.muted),
              SizedBox(height: 10),
              Text(
                'Aucune donnée produit disponible',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
              SizedBox(height: 4),
              Text(
                'Les performances s’afficheront dès les premières ventes.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
    }

    // Filtrage
    var liste = [...widget.produits];
    if (_filtre == FiltreTendance.progression) {
      final ids = widget.progressions.map((p) => p.produit.produitId).toSet();
      liste = liste.where((p) => ids.contains(p.produitId)).toList();
    } else if (_filtre == FiltreTendance.ralentissement) {
      final ids = widget.ralentissements.map((p) => p.produit.produitId).toSet();
      liste = liste.where((p) => ids.contains(p.produitId)).toList();
    }

    // Tri
    liste.sort((a, b) {
      return switch (_tri) {
        CritereTriProduit.chiffreAffaires => b.chiffreAffaires.compareTo(a.chiffreAffaires),
        CritereTriProduit.quantite => b.quantiteVendue.compareTo(a.quantiteVendue),
        CritereTriProduit.marge => (b.margeBrute ?? -999999).compareTo(a.margeBrute ?? -999999),
        CritereTriProduit.vitesse => b.vitesseVenteJour.compareTo(a.vitesseVenteJour),
      };
    });

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
          // En-tête de section
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Performance des produits',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF01226C),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Classement, rotation et contribution',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              // Sélecteur de tri
              PopupMenuButton<CritereTriProduit>(
                initialValue: _tri,
                onSelected: (val) => setState(() => _tri = val),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sort_rounded, size: 16, color: Color(0xFF01226C)),
                      const SizedBox(width: 4),
                      Text(
                        _tri.libelle,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF01226C)),
                      ),
                    ],
                  ),
                ),
                itemBuilder: (ctx) => [
                  for (final critere in CritereTriProduit.values)
                    PopupMenuItem(
                      value: critere,
                      child: Text(critere.libelle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Filtres rapides
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in FiltreTendance.values) ...[
                  ChoiceChip(
                    label: Text(f.libelle),
                    selected: _filtre == f,
                    onSelected: (sel) {
                      if (sel) setState(() => _filtre = f);
                    },
                    selectedColor: const Color(0xFF01226C),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _filtre == f ? Colors.white : AppColors.ink,
                    ),
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),
          // Liste des produits
          if (liste.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Aucun produit ne correspond au filtre sélectionné.', style: TextStyle(color: AppColors.muted)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: liste.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
              itemBuilder: (ctx, i) {
                final perf = liste[i];
                return _ProduitRankingTile(
                  rang: i + 1,
                  performance: perf,
                  onTap: () => _afficherDetailProduit(context, perf),
                );
              },
            ),
        ],
      ),
    );
  }

  void _afficherDetailProduit(BuildContext context, PerformanceProduit perf) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF01226C).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF01226C), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          perf.nom,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                        ),
                        if (perf.code != null)
                          Text('Réf : ${perf.code}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 14),
              _DetailRow(label: 'Chiffre d’affaires généré', valeur: '${KpiCardsIntelligence.formatMontant(perf.chiffreAffaires)} F CFA'),
              _DetailRow(label: 'Quantité vendue', valeur: '${perf.quantiteVendue.toStringAsFixed(1)} ${perf.unite}'),
              _DetailRow(
                label: 'Marge brute estimée',
                valeur: perf.aMargeFiable && perf.margeBrute != null
                    ? '${KpiCardsIntelligence.formatMontant(perf.margeBrute!)} F CFA (${perf.margePourcentage?.toStringAsFixed(1)}%)'
                    : 'Non disponible (coût achat manquant)',
                valeurCouleur: perf.aMargeFiable ? const Color(0xFF1E7E4E) : AppColors.muted,
              ),
              _DetailRow(label: 'Rythme de vente', valeur: '${perf.vitesseVenteJour.toStringAsFixed(2)} ${perf.unite}/jour'),
              _DetailRow(
                label: 'Stock actuel',
                valeur: '${perf.stockActuel.toStringAsFixed(0)} ${perf.unite} (${perf.joursCouverture > 90 ? '> 90' : perf.joursCouverture.toStringAsFixed(0)} jours de couverture)',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push('/commerce/produits/${perf.produitId}');
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Ouvrir la fiche produit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF01226C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProduitRankingTile extends StatelessWidget {
  const _ProduitRankingTile({
    required this.rang,
    required this.performance,
    required this.onTap,
  });

  final int rang;
  final PerformanceProduit performance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (badgeBg, badgeFg) = switch (rang) {
      1 => (const Color(0xFFFEF3C7), const Color(0xFFD97706)),
      2 => (const Color(0xFFF1F5F9), const Color(0xFF64748B)),
      3 => (const Color(0xFFFFEDD5), const Color(0xFFC2410C)),
      _ => (Colors.transparent, AppColors.muted),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badgeBg,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$rang',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: badgeFg,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    performance.nom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${performance.quantiteVendue.toStringAsFixed(0)} ${performance.unite}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      const Text('•', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                      const SizedBox(width: 6),
                      Text(
                        'Stock : ${performance.stockActuel.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: performance.estRupture
                              ? const Color(0xFFDC2626)
                              : (performance.estCritique ? const Color(0xFFDF9540) : AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${KpiCardsIntelligence.formatMontant(performance.chiffreAffaires)} F',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF01226C),
                  ),
                ),
                if (performance.aMargeFiable && performance.margePourcentage != null)
                  Text(
                    'Marge : ${performance.margePourcentage!.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E7E4E)),
                  )
                else
                  Text(
                    '${performance.vitesseVenteJour.toStringAsFixed(1)}/j',
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.valeur, this.valeurCouleur});
  final String label;
  final String valeur;
  final Color? valeurCouleur;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          Flexible(
            child: Text(
              valeur,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: valeurCouleur ?? AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
