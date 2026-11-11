import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dubagest/app/theme/app_theme.dart';
import 'package:dubagest/shared/widgets/responsive_body.dart';
import 'package:dubagest/shared/widgets/state_views.dart';
import '../commerce_providers.dart';
import '../providers/benefice_commerce_providers.dart';
import '../widgets/benefice/bottom_sheet_detail_indicateur.dart';
import '../widgets/benefice/chart_evolution_benefice.dart';
import '../widgets/benefice/chart_repartition_depenses.dart';
import '../widgets/benefice/kpi_cards_benefice.dart';
import '../widgets/benefice/section_tresorerie_benefice.dart';
import '../widgets/benefice/selecteur_periode_benefice_sheet.dart';

/// Page principale du module Bénéfice (Activité COMMERCE).
///
/// Cockpit de suivi de la rentabilité commerciale et de la trésorerie réelle.
class BeneficeCommercePage extends ConsumerWidget {
  const BeneficeCommercePage({super.key});

  void _ouvrirDetail(BuildContext context, String indicateur, dynamic etat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BottomSheetDetailIndicateur(
        indicateur: indicateur,
        etat: etat,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(beneficeCommerceProvider);
    final boutiqueId = ref.watch(boutiqueBeneficeProvider);
    final boutiques = ref.watch(boutiquesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'Bénéfice Commercial',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF1A2522),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        actions: [
          // Sélecteur Multi-Boutiques (Vue Globale vs Boutique spécifique)
          if (boutiques.length > 1)
            PopupMenuButton<String?>(
              initialValue: boutiqueId,
              tooltip: 'Filtrer par boutique',
              onSelected: (val) {
                ref.read(boutiqueBeneficeProvider.notifier).choisir(val);
              },
              icon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5EE),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF1E7E4E).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      boutiqueId == null ? Icons.business : Icons.storefront,
                      size: 14,
                      color: const Color(0xFF1E7E4E),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      boutiqueId == null
                          ? 'Vue globale'
                          : (boutiques.where((b) => b.id == boutiqueId).firstOrNull?.nom ?? 'Boutique'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E7E4E),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF1E7E4E)),
                  ],
                ),
              ),
              itemBuilder: (context) => [
                const PopupMenuItem<String?>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(Icons.business, color: Color(0xFF1E7E4E), size: 18),
                      SizedBox(width: 10),
                      Text('Vue globale (toutes les boutiques)'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                for (final b in boutiques)
                  PopupMenuItem<String?>(
                    value: b.id,
                    child: Row(
                      children: [
                        const Icon(Icons.storefront, color: Color(0xFF6B7280), size: 18),
                        const SizedBox(width: 10),
                        Text(b.nom),
                      ],
                    ),
                  ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF1E7E4E)),
            onPressed: () => ref.invalidate(beneficeCommerceProvider),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Barre des filtres temporels
            const SelecteurPeriodeBeneficeBar(),
            Container(color: AppColors.border, height: 1),

            // Contenu
            Expanded(
              child: asyncData.when(
                loading: () => const Center(child: LoadingView()),
                error: (err, stack) => ErrorView(
                  error: err,
                  onRetry: () => ref.invalidate(beneficeCommerceProvider),
                ),
                data: (etat) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(beneficeCommerceProvider);
                    },
                    color: const Color(0xFF1E7E4E),
                    child: ResponsiveBody(
                      maxWidth: 960,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                        children: [
                          // 1. Cartes d'indicateurs maîtres (Bénéfice, CA, COGS, Marge, Dépenses)
                          KpiCardsBenefice(
                            kpi: etat.kpi,
                            onTapDetail: (ind) => _ouvrirDetail(context, ind, etat),
                            onTapProduitsSansCout: () => _ouvrirDetail(context, 'produits_sans_cout', etat),
                          ),
                          const SizedBox(height: 16),

                          // 2. Section Trésorerie Réelle (Flux financiers distincts)
                          SectionTresorerieBenefice(
                            tresorerie: etat.tresorerie,
                            onTapDetail: (ind) => _ouvrirDetail(context, ind, etat),
                          ),
                          const SizedBox(height: 16),

                          // 3. Graphique d'évolution chronologique
                          if (etat.pointsEvolution.isNotEmpty) ...[
                            ChartEvolutionBenefice(points: etat.pointsEvolution),
                            const SizedBox(height: 16),
                          ],

                          // 4. Graphique de répartition des dépenses
                          ChartRepartitionDepenses(
                            depenses: etat.repartitionDepenses,
                            totalDepenses: etat.kpi.depensesCommerciales,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

