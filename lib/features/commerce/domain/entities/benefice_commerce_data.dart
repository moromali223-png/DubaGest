import 'package:flutter/foundation.dart';

/// Types de filtres temporels pour le module Bénéfice.
enum TypeFiltreBenefice {
  aujourdhui('Aujourd\'hui'),
  hier('Hier'),
  cetteSemaine('Cette semaine'),
  semainePrecedente('Semaine précédente'),
  ceMois('Ce mois'),
  moisPrecedent('Mois précédent'),
  cetteAnnee('Cette année'),
  anneePrecedente('Année précédente'),
  datePrecise('Date précise'),
  personnalise('Période personnalisée');

  const TypeFiltreBenefice(this.libelle);
  final String libelle;
}

/// Intervalle de dates résolu pour l'analyse.
@immutable
class IntervalleBenefice {
  const IntervalleBenefice({
    required this.type,
    required this.debut,
    required this.fin,
    required this.debutPrecedent,
    required this.finPrecedent,
    this.datePreciseSelectionnee,
  });

  final TypeFiltreBenefice type;
  final DateTime debut;
  final DateTime fin;
  final DateTime debutPrecedent;
  final DateTime finPrecedent;
  final DateTime? datePreciseSelectionnee;

  bool contient(DateTime date) => !date.isBefore(debut) && !date.isAfter(fin);
  bool contientPrecedent(DateTime date) => !date.isBefore(debutPrecedent) && !date.isAfter(finPrecedent);

  String get libelleAffiche {
    if (type == TypeFiltreBenefice.datePrecise && datePreciseSelectionnee != null) {
      final d = datePreciseSelectionnee!;
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
    if (type == TypeFiltreBenefice.personnalise) {
      return '${debut.day}/${debut.month}/${debut.year} - ${fin.day}/${fin.month}/${fin.year}';
    }
    return type.libelle;
  }
}

/// Indicateurs de rentabilité commerciale (Compte de résultat estimé).
@immutable
class KpiBeneficeCommerce {
  const KpiBeneficeCommerce({
    required this.chiffreAffairesBrut,
    required this.remises,
    required this.chiffreAffairesNet,
    required this.chiffreAffairesPrecedent,
    required this.nombreVentes,
    required this.cogs,
    required this.cogsPrecedent,
    required this.margeBrute,
    required this.margeBrutePrecedente,
    required this.tauxMarge,
    required this.depensesCommerciales,
    required this.depensesPrecedentes,
    required this.beneficeNetEstime,
    required this.beneficeNetPrecedent,
    required this.tauxBeneficeNet,
    required this.tauxCouvertureCout,
    required this.lignesTotal,
    required this.lignesAvecCout,
  });

  final int chiffreAffairesBrut;
  final int remises;
  final int chiffreAffairesNet;
  final int chiffreAffairesPrecedent;
  final int nombreVentes;

  /// Coût des marchandises vendues (COGS).
  final int cogs;
  final int cogsPrecedent;

  /// Marge brute = CA Net - COGS.
  final int margeBrute;
  final int margeBrutePrecedente;
  final double tauxMarge;

  /// Dépenses d'exploitation imputables au commerce sur la période.
  final int depensesCommerciales;
  final int depensesPrecedentes;

  /// Bénéfice net estimé = Marge Brute - Dépenses Commerciales.
  final int beneficeNetEstime;
  final int beneficeNetPrecedent;
  final double tauxBeneficeNet;

  /// Pourcentage de lignes de vente disposant d'un coût de revient renseigné.
  final double tauxCouvertureCout;
  final int lignesTotal;
  final int lignesAvecCout;

  bool get estBeneficiaire => beneficeNetEstime >= 0;
  bool get couvertureFiable => tauxCouvertureCout >= 65.0;

  double? get variationBeneficePct {
    if (beneficeNetPrecedent == 0) return null;
    return ((beneficeNetEstime - beneficeNetPrecedent) / beneficeNetPrecedent.abs()) * 100;
  }

  double? get variationCAPct {
    if (chiffreAffairesPrecedent <= 0) return null;
    return ((chiffreAffairesNet - chiffreAffairesPrecedent) / chiffreAffairesPrecedent) * 100;
  }
}

/// Indicateurs de flux de trésorerie réels (Distinction nette de la rentabilité).
@immutable
class TresorerieReelleCommerce {
  const TresorerieReelleCommerce({
    required this.totalEncaisse,
    required this.totalDecaisse,
    required this.soldeNetFlux,
    required this.creancesClientsRestantes,
  });

  /// Total des encaissements effectifs (ventes comptant + règlements de créances).
  final int totalEncaisse;

  /// Total des décaissements effectifs (dépenses payées + règlements fournisseurs).
  final int totalDecaisse;

  /// Solde net des flux = Total encaissé - Total décaissé.
  final int soldeNetFlux;

  /// Créances clients restant à recouvrer sur les ventes à crédit.
  final int creancesClientsRestantes;

  bool get fluxPositif => soldeNetFlux >= 0;
}

/// Point d'évolution chronologique (Graphique).
@immutable
class PointEvolutionBenefice {
  const PointEvolutionBenefice({
    required this.date,
    required this.label,
    required this.chiffreAffaires,
    required this.cogs,
    required this.margeBrute,
    required this.depenses,
    required this.beneficeNet,
  });

  final DateTime date;
  final String label;
  final int chiffreAffaires;
  final int cogs;
  final int margeBrute;
  final int depenses;
  final int beneficeNet;
}

/// Répartition d'une dépense par catégorie.
@immutable
class RepartitionDepenseItem {
  const RepartitionDepenseItem({
    required this.categorieId,
    required this.categorieNom,
    required this.total,
    required this.pourcentage,
    this.icone,
    this.couleur,
  });

  final String categorieId;
  final String categorieNom;
  final int total;
  final double pourcentage;
  final String? icone;
  final String? couleur;
}

/// Rentabilité par produit.
@immutable
class ProduitRentabiliteItem {
  const ProduitRentabiliteItem({
    required this.produitId,
    required this.nom,
    required this.uniteBase,
    required this.quantiteVendue,
    required this.chiffreAffaires,
    required this.coutAchatUnitaire,
    required this.cogs,
    required this.margeBrute,
    required this.coutManquant,
    this.reference,
  });

  final String produitId;
  final String nom;
  final String uniteBase;
  final double quantiteVendue;
  final int chiffreAffaires;
  final int? coutAchatUnitaire;
  final int cogs;
  final int margeBrute;
  final bool coutManquant;
  final String? reference;

  double get tauxMarge => chiffreAffaires > 0 ? (margeBrute / chiffreAffaires) * 100 : 0.0;
}

/// Produit dont le prix d'achat est absent.
@immutable
class ProduitCoutManquantItem {
  const ProduitCoutManquantItem({
    required this.produitId,
    required this.nom,
    required this.uniteBase,
    this.reference,
  });

  final String produitId;
  final String nom;
  final String uniteBase;
  final String? reference;
}

/// État consolidé du module Bénéfice.
@immutable
class EtatBeneficeCommerce {
  const EtatBeneficeCommerce({
    required this.intervalle,
    required this.perimetreId,
    required this.kpi,
    required this.tresorerie,
    required this.repartitionDepenses,
    required this.produitsRentabilite,
    required this.produitsCoutManquant,
    required this.pointsEvolution,
    required this.dateCalcul,
  });

  final IntervalleBenefice intervalle;
  final String? perimetreId;
  final KpiBeneficeCommerce kpi;
  final TresorerieReelleCommerce tresorerie;
  final List<RepartitionDepenseItem> repartitionDepenses;
  final List<ProduitRentabiliteItem> produitsRentabilite;
  final List<ProduitCoutManquantItem> produitsCoutManquant;
  final List<PointEvolutionBenefice> pointsEvolution;
  final DateTime dateCalcul;

  bool get estVueConsolidee => perimetreId == null;
}

