import 'package:flutter/foundation.dart';

/// Type de période pour l'analyse décisionnelle.
enum PeriodeAnalyseType {
  aujourdhui("Aujourd'hui"),
  hier('Hier'),
  septDerniersJours('7 derniers jours'),
  trenteDerniersJours('30 derniers jours'),
  semaineEnCours('Cette semaine'),
  semainePrecedente('Semaine dernière'),
  moisEnCours('Ce mois'),
  moisPrecedent('Mois dernier'),
  trimestre('Ce trimestre'),
  annee('Cette année'),
  personnalise('Personnalisée');

  const PeriodeAnalyseType(this.libelle);
  final String libelle;
}

/// Intervalle temporel de référence et intervalle de comparaison équivalent.
@immutable
class IntervallePeriode {
  const IntervallePeriode({
    required this.type,
    required this.debut,
    required this.fin,
    required this.debutPrecedent,
    required this.finPrecedent,
  });

  final PeriodeAnalyseType type;
  final DateTime debut;
  final DateTime fin;
  final DateTime debutPrecedent;
  final DateTime finPrecedent;

  int get dureeJours => fin.difference(debut).inDays.clamp(1, 3650);

  bool contient(DateTime date) =>
      (date.isAfter(debut) || date.isAtSameMomentAs(debut)) &&
      (date.isBefore(fin) || date.isAtSameMomentAs(fin));

  bool contientPrecedent(DateTime date) =>
      (date.isAfter(debutPrecedent) || date.isAtSameMomentAs(debutPrecedent)) &&
      (date.isBefore(finPrecedent) || date.isAtSameMomentAs(finPrecedent));
}

/// Niveau d'urgence et de priorité des recommandations.
enum PrioriteConseil {
  urgent('Urgent'),
  important('Important'),
  surveiller('À surveiller'),
  opportunite('Opportunité');

  const PrioriteConseil(this.libelle);
  final String libelle;
}

/// Résumé exécutif des 4 KPIs clés.
@immutable
class ResumeIntelligenceCommerciale {
  const ResumeIntelligenceCommerciale({
    required this.chiffreAffaires,
    required this.chiffreAffairesPrecedent,
    required this.variationCAPct,
    required this.quantiteVendue,
    required this.quantiteVenduePrecedente,
    required this.variationQuantitePct,
    required this.margeBruteEstimee,
    required this.margeBrutePrecedente,
    required this.variationMargePct,
    required this.margeFiable,
    required this.pourcentageProduitsAvecMarge,
    required this.topProduitNom,
    required this.topProduitChiffreAffaires,
    required this.topProduitQuantite,
    required this.nombreVentes,
    required this.panierMoyen,
    required this.totalEncaissementsVentes,
    required this.totalVentesCredit,
  });

  final int chiffreAffaires;
  final int chiffreAffairesPrecedent;
  final double? variationCAPct;

  final double quantiteVendue;
  final double quantiteVenduePrecedente;
  final double? variationQuantitePct;

  final int? margeBruteEstimee;
  final int? margeBrutePrecedente;
  final double? variationMargePct;
  final bool margeFiable;
  final double pourcentageProduitsAvecMarge;

  final String? topProduitNom;
  final int? topProduitChiffreAffaires;
  final double? topProduitQuantite;

  final int nombreVentes;
  final int panierMoyen;
  final int totalEncaissementsVentes;
  final int totalVentesCredit;
}

/// Point d'évolution temporelle pour les graphiques.
@immutable
class PointEvolutionVente {
  const PointEvolutionVente({
    required this.date,
    required this.label,
    required this.chiffreAffaires,
    required this.chiffreAffairesPrecedent,
    required this.quantite,
    this.margeBrute,
  });

  final DateTime date;
  final String label;
  final int chiffreAffaires;
  final int chiffreAffairesPrecedent;
  final double quantite;
  final int? margeBrute;
}

/// Performance granulaire d'un produit.
@immutable
class PerformanceProduit {
  const PerformanceProduit({
    required this.produitId,
    required this.nom,
    this.code,
    this.photoUrl,
    required this.unite,
    required this.quantiteVendue,
    required this.quantiteVenduePrecedente,
    required this.chiffreAffaires,
    required this.chiffreAffairesPrecedent,
    this.margeBrute,
    this.margePourcentage,
    required this.vitesseVenteJour,
    required this.stockActuel,
    required this.joursCouverture,
    required this.variationQuantitePct,
    required this.aMargeFiable,
    this.prixAchatRef,
    this.prixVenteMoyen,
  });

  final String produitId;
  final String nom;
  final String? code;
  final String? photoUrl;
  final String unite;
  final double quantiteVendue;
  final double quantiteVenduePrecedente;
  final int chiffreAffaires;
  final int chiffreAffairesPrecedent;
  final int? margeBrute;
  final double? margePourcentage;
  final double vitesseVenteJour;
  final double stockActuel;
  final double joursCouverture;
  final double? variationQuantitePct;
  final bool aMargeFiable;
  final int? prixAchatRef;
  final int? prixVenteMoyen;

  bool get estRupture => stockActuel <= 0 && vitesseVenteJour > 0;
  bool get estCritique => joursCouverture <= 3 && stockActuel > 0 && vitesseVenteJour > 0;
  bool get estSurstock => joursCouverture > 60 && quantiteVendue > 0;
}

/// Tendance produit (en forte hausse ou baisse).
@immutable
class TendanceProduit {
  const TendanceProduit({
    required this.produit,
    required this.enProgression,
    required this.variationQuantite,
    required this.variationPourcentage,
    required this.niveauConfiance,
    required this.conseilAction,
  });

  final PerformanceProduit produit;
  final bool enProgression;
  final double variationQuantite;
  final double variationPourcentage;
  final String niveauConfiance; // "Élevé", "Modéré", "Indicatif"
  final String conseilAction;
}

/// Recommandation intelligente de réapprovisionnement.
@immutable
class RecommandationStock {
  const RecommandationStock({
    required this.produitId,
    required this.nom,
    this.photoUrl,
    required this.uniteBase,
    required this.uniteCommande,
    required this.facteurUniteCommande,
    required this.stockActuel,
    required this.vitesseVenteJour,
    required this.delaiApproJours,
    required this.joursCouverture,
    required this.stockSecurite,
    required this.quantiteRecommandee,
    required this.quantiteRecommandeeEnUniteCommande,
    required this.raisonnement,
    required this.urgence,
    this.fournisseurId,
    this.fournisseurNom,
    this.estimationCout,
  });

  final String produitId;
  final String nom;
  final String? photoUrl;
  final String uniteBase;
  final String uniteCommande;
  final double facteurUniteCommande;
  final double stockActuel;
  final double vitesseVenteJour;
  final int delaiApproJours;
  final double joursCouverture;
  final double stockSecurite;
  final double quantiteRecommandee;
  final int quantiteRecommandeeEnUniteCommande;
  final String raisonnement;
  final PrioriteConseil urgence;
  final String? fournisseurId;
  final String? fournisseurNom;
  final int? estimationCout;
}

/// Association de produits souvent achetés ensemble (Analyse de panier).
@immutable
class AssociationProduits {
  const AssociationProduits({
    required this.produitAId,
    required this.nomA,
    required this.produitBId,
    required this.nomB,
    required this.nombreTicketsEnsemble,
    required this.frequenceAssociationPct,
    required this.indiceConfiancePct,
    required this.suggestion,
  });

  final String produitAId;
  final String nomA;
  final String produitBId;
  final String nomB;
  final int nombreTicketsEnsemble;
  final double frequenceAssociationPct;
  final double indiceConfiancePct;
  final String suggestion;
}

/// Analyse commerciale d'un client (volume, fréquence, encaissements et retards).
@immutable
class AnalyseClientCredit {
  const AnalyseClientCredit({
    required this.contactId,
    required this.nomClient,
    this.telephone,
    required this.chiffreAffaires,
    required this.nombreAchats,
    required this.creanceRestante,
    required this.creanceEchue,
    required this.joursRetardMax,
    required this.niveauRisque,
  });

  final String contactId;
  final String nomClient;
  final String? telephone;
  final int chiffreAffaires;
  final int nombreAchats;
  final int creanceRestante;
  final int creanceEchue;
  final int joursRetardMax;
  final String niveauRisque; // "Faible", "Moyen", "Critique"
}

/// Analyse commerciale d'un fournisseur (achats, dettes, prochaine échéance).
@immutable
class AnalyseFournisseurDette {
  const AnalyseFournisseurDette({
    required this.fournisseurId,
    required this.nomFournisseur,
    this.telephone,
    required this.totalAchats,
    required this.montantPaye,
    required this.detteRestante,
    required this.detteEchue,
    this.prochaineEcheance,
    required this.produitsPrincipaux,
  });

  final String fournisseurId;
  final String nomFournisseur;
  final String? telephone;
  final int totalAchats;
  final int montantPaye;
  final int detteRestante;
  final int detteEchue;
  final DateTime? prochaineEcheance;
  final List<String> produitsPrincipaux;
}

/// Conseil et recommandation explicable pour le commerçant.
@immutable
class ConseilActiviteCommerciale {
  const ConseilActiviteCommerciale({
    required this.id,
    required this.priorite,
    required this.titre,
    required this.constat,
    required this.justification,
    required this.periode,
    required this.niveauConfiance,
    required this.actionSuggeree,
    this.routeCible,
    this.boutonActionTitre,
    this.produitId,
    this.contactId,
  });

  final String id;
  final PrioriteConseil priorite;
  final String titre;
  final String constat;
  final String justification;
  final String periode;
  final String niveauConfiance;
  final String actionSuggeree;
  final String? routeCible;
  final String? boutonActionTitre;
  final String? produitId;
  final String? contactId;
}

/// Modèle d'état complet de l'intelligence commerciale.
@immutable
class EtatIntelligenceCommerciale {
  const EtatIntelligenceCommerciale({
    required this.periode,
    required this.intervalle,
    this.perimetreId,
    required this.resume,
    required this.evolutionVentes,
    required this.produitsPerformance,
    required this.produitsEnProgression,
    required this.produitsEnRalentissement,
    required this.recommandationsStock,
    required this.associationsPaniers,
    required this.analyseClients,
    required this.analyseFournisseurs,
    required this.conseilsActivite,
    required this.dateCalcul,
  });

  final PeriodeAnalyseType periode;
  final IntervallePeriode intervalle;
  final String? perimetreId;
  final ResumeIntelligenceCommerciale resume;
  final List<PointEvolutionVente> evolutionVentes;
  final List<PerformanceProduit> produitsPerformance;
  final List<TendanceProduit> produitsEnProgression;
  final List<TendanceProduit> produitsEnRalentissement;
  final List<RecommandationStock> recommandationsStock;
  final List<AssociationProduits> associationsPaniers;
  final List<AnalyseClientCredit> analyseClients;
  final List<AnalyseFournisseurDette> analyseFournisseurs;
  final List<ConseilActiviteCommerciale> conseilsActivite;
  final DateTime dateCalcul;
}
