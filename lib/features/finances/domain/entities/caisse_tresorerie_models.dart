import 'finances.dart';

/// Intervalle de dates inclusif (domaine pur, sans Flutter).
class Intervalle {
  const Intervalle(this.debut, this.fin);
  final DateTime debut;
  final DateTime fin;

  bool contient(DateTime d) => !d.isBefore(debut) && !d.isAfter(fin);
}

/// Périodes proposées dans la Caisse.
enum FiltrePeriode {
  aujourdhui,
  hier,
  cetteSemaine,
  ceMois,
  cetteAnnee,
  tout;

  Intervalle intervalle(DateTime ref) {
    final jour = DateTime(ref.year, ref.month, ref.day);
    final finJour = DateTime(ref.year, ref.month, ref.day, 23, 59, 59, 999);
    return switch (this) {
      aujourdhui => Intervalle(jour, finJour),
      hier => Intervalle(
        DateTime(jour.year, jour.month, jour.day - 1),
        DateTime(jour.year, jour.month, jour.day - 1, 23, 59, 59, 999),
      ),
      cetteSemaine => Intervalle(DateTime(jour.year, jour.month, jour.day - (jour.weekday - 1)), finJour),
      ceMois => Intervalle(DateTime(ref.year, ref.month), finJour),
      cetteAnnee => Intervalle(DateTime(ref.year), finJour),
      tout => Intervalle(DateTime(2000), finJour),
    };
  }

  /// Période comparable précédente (même durée écoulée) ; `null` pour « Tout ».
  Intervalle? precedent(DateTime ref) {
    final cur = intervalle(ref);
    DateTime moins(DateTime d, {int jours = 0, int mois = 0, int ans = 0}) =>
        DateTime(d.year - ans, d.month - mois, d.day - jours, d.hour, d.minute, d.second, d.millisecond);
    return switch (this) {
      aujourdhui || hier => Intervalle(moins(cur.debut, jours: 1), moins(cur.fin, jours: 1)),
      cetteSemaine => Intervalle(
        moins(cur.debut, jours: 7),
        moins(DateTime(ref.year, ref.month, ref.day, 23, 59, 59), jours: 7),
      ),
      ceMois => Intervalle(moins(cur.debut, mois: 1), moins(cur.fin, mois: 1)),
      cetteAnnee => Intervalle(moins(cur.debut, ans: 1), moins(cur.fin, ans: 1)),
      tout => null,
    };
  }
}

/// Origine d'un mouvement d'argent, tirée des données (jamais d'un texte).
enum OrigineMouvement {
  vente,
  paiementClient,
  prestation,
  loyer,
  achat,
  paiementFournisseur,
  depense,
  apport,
  retrait,
  transfert,
  remboursement,
  ajustement,
  autre,
}

/// Résumé d'une période : soldes (à l'instant) et flux réels (hors transferts).
class ResumeTresorerie {
  const ResumeTresorerie({
    required this.soldeEspeces,
    required this.soldesParMode,
    required this.entrees,
    required this.sorties,
    required this.nombreOperations,
  });

  /// Espèces dans les caisses de l'espace (ouvertes, ou comptées à la clôture).
  final int soldeEspeces;

  /// Solde de chaque moyen d'argent (espèces = [soldeEspeces]).
  final Map<ModePaiement, int> soldesParMode;
  final int entrees;
  final int sorties;
  final int nombreOperations;

  int get tresorerieTotale => soldesParMode.values.fold(0, (a, b) => a + b);
  int get variationNette => entrees - sorties;
}

/// Un jour du graphique d'évolution.
class PointEvolutionTresorerie {
  const PointEvolutionTresorerie({
    required this.date,
    required this.solde,
    required this.entrees,
    required this.sorties,
  });
  final DateTime date;
  final int solde;
  final int entrees;
  final int sorties;
}

/// Part d'une origine dans les entrées ou les sorties d'une période.
class LigneRepartition {
  const LigneRepartition({required this.origine, required this.montant, required this.pourcentage});
  final OrigineMouvement origine;
  final int montant;
  final double pourcentage;
}

/// Part d'un moyen d'argent dans les entrées d'une période.
class ProportionModePaiement {
  const ProportionModePaiement({required this.mode, required this.montant, required this.pourcentage});
  final ModePaiement mode;
  final int montant;
  final double pourcentage;
}

/// Entrées et sorties de la période comparées à la période précédente.
class ComparaisonPeriodeFinances {
  const ComparaisonPeriodeFinances({
    required this.entrees,
    required this.entreesPrecedentes,
    required this.sorties,
    required this.sortiesPrecedentes,
  });

  final int entrees;
  final int entreesPrecedentes;
  final int sorties;
  final int sortiesPrecedentes;

  /// Évolution en % ; `null` sans base comparable (jamais de faux pourcentage).
  static double? evolution(int actuel, int precedent) => precedent <= 0 ? null : (actuel - precedent) * 100 / precedent;

  double? get evolutionEntrees => evolution(entrees, entreesPrecedentes);
  double? get evolutionSorties => evolution(sorties, sortiesPrecedentes);
}

/// Flux et soldes d'une boutique (comparaison multi-boutiques).
class FluxBoutiqueFinances {
  const FluxBoutiqueFinances({
    required this.perimetreId,
    required this.entrees,
    required this.sorties,
    required this.soldeEspeces,
    required this.tresorerieTotale,
    required this.caisseOuverte,
  });

  final String perimetreId;
  final int entrees;
  final int sorties;
  final int soldeEspeces;
  final int tresorerieTotale;
  final bool caisseOuverte;

  int get variationNette => entrees - sorties;
}

enum TypeAlerteTresorerie { ecartCaisse, sortiesEnHausse }

/// Alerte utile seulement (écart constaté, sorties en forte hausse).
class AlerteTresorerie {
  const AlerteTresorerie({required this.type, this.montant, this.pourcentage, this.caisseId, this.perimetreId});
  final TypeAlerteTresorerie type;
  final int? montant;
  final int? pourcentage;
  final String? caisseId;
  final String? perimetreId;
}

/// Une ligne de l'historique : un paiement (vente, dépense, apport…) ou un
/// ancien dépôt / retrait d'espèces saisi directement en caisse.
class OperationTresorerie {
  const OperationTresorerie({
    required this.id,
    required this.date,
    required this.sens,
    required this.montant,
    required this.mode,
    required this.origine,
    this.libelle,
    this.reference,
    this.perimetreId,
    this.contactId,
    this.note,
    this.estAnnule = false,
    this.estAnnulation = false,
    this.estRefuse = false,
    this.enAttente = false,
    this.sessionId,
    this.paiementId,
    this.transfertId,
    this.depenseId,
  });

  final String id;
  final DateTime date;
  final SensPaiement sens;
  final int montant;
  final ModePaiement mode;
  final OrigineMouvement origine;

  /// Libellé issu des données (dépense, somme réglée, motif) ; sinon l'origine.
  final String? libelle;
  final String? reference;
  final String? perimetreId;
  final String? contactId;
  final String? note;
  final bool estAnnule;
  final bool estAnnulation;
  final bool estRefuse;
  final bool enAttente;
  final String? sessionId;
  final String? paiementId;
  final String? transfertId;
  final String? depenseId;

  bool get estEntree => sens == SensPaiement.entree;
}
