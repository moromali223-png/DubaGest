import 'package:flutter/foundation.dart';

import '../../../activites/domain/entities/activite.dart';
import 'finance_alert.dart';
import 'finance_forecast.dart';
import 'finance_health_score.dart';
import 'finance_period_filter.dart';

/// Point d'une série temporelle (pour les graphiques linéaires).
@immutable
class PointSerieTemporelle {
  const PointSerieTemporelle({
    required this.date,
    required this.valeur,
    this.valeurPrecedente,
    this.label,
  });

  final DateTime date;
  final int valeur;
  final int? valeurPrecedente;
  final String? label;
}

/// Évolution d'un KPI avec comparaison sur la période précédente.
@immutable
class IndicateurEvolution {
  const IndicateurEvolution({
    required this.valeurActuelle,
    this.valeurPrecedente,
    this.tauxEvolution,
    this.comparaisonValable = false,
  });

  final int valeurActuelle;
  final int? valeurPrecedente;

  /// Pourcentage d'évolution (ex: +12.4% ou -6.2%)
  final double? tauxEvolution;

  /// Vrai si une période précédente comparable et non nulle existe
  final bool comparaisonValable;

  bool get estPositif => (tauxEvolution ?? 0) >= 0;
}

/// Répartition d'une catégorie de dépense.
@immutable
class CategorieDepenseMontant {
  const CategorieDepenseMontant({
    required this.categorieId,
    required this.nom,
    required this.montant,
    required this.pourcentage,
  });

  final String categorieId;
  final String nom;
  final int montant;
  final double pourcentage;
}

/// Performance d'une activité (Commerce, Services, Immobilier).
@immutable
class PerformanceActivite {
  const PerformanceActivite({
    required this.activite,
    required this.nom,
    required this.chiffreAffaires,
    required this.encaissements,
    required this.depenses,
    required this.margeOuResultat,
    required this.creances,
  });

  final ActiviteCode activite;
  final String nom;
  final int chiffreAffaires;
  final int encaissements;
  final int depenses;
  final int margeOuResultat;
  final int creances;
}

/// Performance d'une boutique / site spécifique.
@immutable
class PerformanceBoutique {
  const PerformanceBoutique({
    required this.perimetreId,
    required this.nom,
    required this.chiffreAffaires,
    required this.encaissements,
    required this.depenses,
    required this.resultatEstime,
    required this.soldeCaisse,
    required this.creances,
    required this.dettes,
  });

  final String perimetreId;
  final String nom;
  final int chiffreAffaires;
  final int encaissements;
  final int depenses;
  final int resultatEstime;
  final int soldeCaisse;
  final int creances;
  final int dettes;
}

/// Analyse du taux de recouvrement.
@immutable
class TauxRecouvrementData {
  const TauxRecouvrementData({
    required this.totalFacture,
    required this.totalEncaisse,
    required this.resteARecouvrer,
    required this.tauxPourcent,
  });

  final int totalFacture;
  final int totalEncaisse;
  final int resteARecouvrer;
  final double tauxPourcent;
}

/// Analyse des flux de trésorerie réels (hors transferts internes).
@immutable
class FluxTresorerieData {
  const FluxTresorerieData({
    required this.entreesReelles,
    required this.sortiesReelles,
    required this.fluxNet,
    required this.ventesEncaissees,
    required this.paiementsClients,
    required this.loyersEncaisses,
    required this.depensesExploitation,
    required this.reglementsFournisseurs,
  });

  final int entreesReelles;
  final int sortiesReelles;
  final int fluxNet;
  final int ventesEncaissees;
  final int paiementsClients;
  final int loyersEncaisses;
  final int depensesExploitation;
  final int reglementsFournisseurs;
}

/// Analyse spécifique Commerce (Marge brute & Coût des marchandises vendues).
@immutable
class MargeCommerceData {
  const MargeCommerceData({
    required this.chiffreAffairesCommerce,
    required this.coutMarchandisesVendues,
    required this.margeBrute,
    required this.tauxMargePourcent,
    required this.serieMarge,
  });

  final int chiffreAffairesCommerce;
  final int coutMarchandisesVendues;
  final int margeBrute;
  final double tauxMargePourcent;
  final List<PointSerieTemporelle> serieMarge;
}

/// Synthèse complète de consolidation financière DUBAGEST.
@immutable
class FinanceDashboardData {
  const FinanceDashboardData({
    required this.periode,
    required this.plageDates,
    required this.chiffreAffaires,
    required this.resultatEstime,
    required this.tresorerieDisponible,
    required this.aRecevoir,
    required this.aPayer,
    required this.nombreClientsDebiteurs,
    required this.nombreFournisseursCreanciers,
    required this.creancesEnRetard,
    required this.dettesEnRetard,
    required this.sante,
    required this.serieEvolutionCA,
    required this.serieEvolutionTresorerie,
    required this.totalRevenus,
    required this.totalDepenses,
    required this.margeCommerce,
    required this.categoriesDepenses,
    required this.performancesActivites,
    required this.performancesBoutiques,
    required this.recouvrement,
    required this.fluxTresorerie,
    required this.previsions,
    required this.faitsMarquants,
    required this.alertes,
    required this.donneesVides,
  });

  final FiltrePeriodeFinance periode;
  final PlageDates plageDates;

  // 5 KPI Majeurs
  final IndicateurEvolution chiffreAffaires;
  final IndicateurEvolution resultatEstime;
  final IndicateurEvolution tresorerieDisponible;
  final IndicateurEvolution aRecevoir;
  final IndicateurEvolution aPayer;

  // Détails KPI
  final int nombreClientsDebiteurs;
  final int nombreFournisseursCreanciers;
  final int creancesEnRetard;
  final int dettesEnRetard;

  // Diagnostic Santé
  final SanteFinanciere sante;

  // Graphiques & Séries
  final List<PointSerieTemporelle> serieEvolutionCA;
  final List<PointSerieTemporelle> serieEvolutionTresorerie;

  // Revenus vs Dépenses
  final int totalRevenus;
  final int totalDepenses;

  // Marge (Commerce)
  final MargeCommerceData? margeCommerce;

  // Répartition Dépenses (Top 5)
  final List<CategorieDepenseMontant> categoriesDepenses;

  // Multi-activités et Multi-boutiques
  final List<PerformanceActivite> performancesActivites;
  final List<PerformanceBoutique> performancesBoutiques;

  // Recouvrement & Flux réels
  final TauxRecouvrementData recouvrement;
  final FluxTresorerieData fluxTresorerie;

  // Prévisions
  final PrevisionTresorerie previsions;

  // Ce qui change & Alertes
  final List<FaitMarquantFinance> faitsMarquants;
  final List<AlerteFinanciere> alertes;

  // État sans données
  final bool donneesVides;
}
