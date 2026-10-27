import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dubagest/app/theme/app_theme.dart';
import 'package:dubagest/shared/widgets/responsive_body.dart';
import 'package:dubagest/shared/widgets/state_views.dart';
import '../providers/intelligence_commerciale_providers.dart';
import '../widgets/intelligence/conseils_activite_section.dart';
import '../widgets/intelligence/header_intelligence.dart';
import '../widgets/intelligence/kpi_cards_intelligence.dart';
import '../widgets/intelligence/selecteur_onglets_intelligence.dart';
import '../widgets/intelligence/vue_engagements_creances.dart';
import '../widgets/intelligence/vue_paniers_associations.dart';
import '../widgets/intelligence/vue_produits_ranking.dart';
import '../widgets/intelligence/vue_stock_reappro.dart';
import '../widgets/intelligence/vue_ventes_chart.dart';

/// Page d'accueil du module « Intelligence commerciale ».
///
/// Cockpit décisionnel pour commerçants : KPIs exécutifs, conseils actionnables,
/// navigation par onglets évitant le défilement infini, analyses des ventes,
/// des stocks, des paniers clients et des créances/dettes.
class IntelligenceCommercialePage extends ConsumerWidget {
  const IntelligenceCommercialePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(intelligenceCommercialeProvider);
    final ongletActif = ref.watch(vueActiveIntelligenceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'Intelligence commerciale',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF01226C),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: asyncData.when(
          loading: () => const Center(child: LoadingView()),
          error: (err, _) => ErrorView(
            error: err,
            onRetry: () => ref.invalidate(intelligenceCommercialeProvider),
          ),
          data: (etat) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(intelligenceCommercialeProvider);
              },
              color: const Color(0xFF01226C),
              child: ResponsiveBody(
                maxWidth: 960,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                  children: [
                    // 1. En-tête avec sélecteur de période et site
                    HeaderIntelligence(dateCalcul: etat.dateCalcul),
                    const SizedBox(height: 14),

                    // 2. Résumé exécutif (4 KPIs clés)
                    KpiCardsIntelligence(resume: etat.resume),
                    const SizedBox(height: 14),

                    // 3. Conseils pour votre activité
                    if (etat.conseilsActivite.isNotEmpty) ...[
                      ConseilsActiviteSection(conseils: etat.conseilsActivite),
                      const SizedBox(height: 16),
                    ],

                    // 4. Sélecteur d'onglets (Navigation ciblée sans scroll infini)
                    const SelecteurOngletsIntelligence(),
                    const SizedBox(height: 14),

                    // 5. Vue d'analyse ciblée selon l'onglet actif
                    switch (ongletActif) {
                      VueIntelligenceOnglet.ventes => VueVentesChart(
                          points: etat.evolutionVentes,
                          resume: etat.resume,
                          intervalle: etat.intervalle,
                        ),
                      VueIntelligenceOnglet.produits => VueProduitsRanking(
                          produits: etat.produitsPerformance,
                          progressions: etat.produitsEnProgression,
                          ralentissements: etat.produitsEnRalentissement,
                        ),
                      VueIntelligenceOnglet.stocks => VueStockReappro(
                          recommandations: etat.recommandationsStock,
                        ),
                      VueIntelligenceOnglet.paniers => VuePaniersAssociations(
                          associations: etat.associationsPaniers,
                        ),
                      VueIntelligenceOnglet.engagements => VueEngagementsCreances(
                          clients: etat.analyseClients,
                          fournisseurs: etat.analyseFournisseurs,
                        ),
                    },
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
