import '../../../activites/domain/entities/activite.dart';
import '../../../commerce/domain/entities/commerce.dart';
import '../../../commerce/domain/services/etat_commerce.dart';
import '../entities/finance_alert.dart';
import '../entities/finance_dashboard_data.dart';
import '../entities/finance_forecast.dart';
import '../entities/finance_period_filter.dart';
import '../entities/finances.dart';
import 'etat_finances.dart';
import 'sante_financiere_evaluator.dart';
import 'tresorerie_forecaster.dart';

/// Moteur de calcul financier consolidé de DUBAGEST.
/// Agrège les données de Ventes, Caisse, Dépenses, Engagements et Paiements
/// sans duplication de données.
class CalculFinancesEngine {
  const CalculFinancesEngine({
    this.santeEvaluator = const SanteFinanciereEvaluator(),
    this.tresorerieForecaster = const TresorerieForecaster(),
  });

  final SanteFinanciereEvaluator santeEvaluator;
  final TresorerieForecaster tresorerieForecaster;

  FinanceDashboardData calculer({
    required EtatFinances etatFinances,
    required EtatCommerce? etatCommerce,
    required FiltrePeriodeFinance periodeFiltre,
    required DateTime maintenant,
    ActiviteCode? activiteFiltre,
    String? perimetreIdFiltre,
    Map<String, String> nomsPerimetres = const {},
    Map<String, String> nomsContacts = const {},
    Map<String, ActiviteCode> activiteDesPerimetres = const {},
  }) {
    final plageActuelle = periodeFiltre.resoudre(maintenant);
    final plagePrecedente = plageActuelle.plagePrecedente();

    // 1. Filtrage spatial (Activité / Boutique)
    final financesFiltrees = etatFinances.restreint(
      activite: activiteFiltre,
      perimetreId: perimetreIdFiltre,
      activiteDesSites: activiteDesPerimetres,
    );

    // Ventes filtrées par espace
    final ventesEspace = [
      if (etatCommerce != null)
        for (final v in etatCommerce.ventes)
          if (!v.annulee && !v.refuse)
            if (perimetreIdFiltre == null || v.perimetreId == perimetreIdFiltre)
              if (activiteFiltre == null || activiteFiltre == ActiviteCode.commerce) v,
    ];

    // 2. Filtrage temporel Période Actuelle vs Période Précédente
    final ventesActuelles = [
      for (final v in ventesEspace)
        if (plageActuelle.contient(v.date)) v,
    ];
    final ventesPrecedentes = [
      for (final v in ventesEspace)
        if (plagePrecedente.contient(v.date)) v,
    ];

    final depensesActuelles = [
      for (final d in financesFiltrees.depenses)
        if (financesFiltrees.depenseComptee(d) && plageActuelle.contient(d.dateDepense)) d,
    ];
    final depensesPrecedentes = [
      for (final d in financesFiltrees.depenses)
        if (financesFiltrees.depenseComptee(d) && plagePrecedente.contient(d.dateDepense)) d,
    ];

    final paiementsActuels = [
      for (final p in financesFiltrees.paiements)
        if (financesFiltrees.compte(p) && !p.estTransfert && plageActuelle.contient(p.datePaiement)) p,
    ];
    final paiementsPrecedents = [
      for (final p in financesFiltrees.paiements)
        if (financesFiltrees.compte(p) && !p.estTransfert && plagePrecedente.contient(p.datePaiement)) p,
    ];

    // 3. Calcul du Chiffre d'Affaires
    final caCommerceActuel = ventesActuelles.fold(0, (s, v) => s + v.total);
    final caCommercePrecedent = ventesPrecedentes.fold(0, (s, v) => s + v.total);

    // CA Autres activités (Services / Immobilier issus des engagements créés dans la période)
    var caAutresActuel = 0;
    var caAutresPrecedent = 0;
    for (final s in financesFiltrees.suivis) {
      final e = s.engagement;
      if (e.annule || e.sens != SensEngagement.aRecevoir || e.origineType == 'VENTE') continue;
      if (plageActuelle.contient(e.dateEngagement)) {
        caAutresActuel += e.montantTotal;
      } else if (plagePrecedente.contient(e.dateEngagement)) {
        caAutresPrecedent += e.montantTotal;
      }
    }

    final caTotalActuel = caCommerceActuel + caAutresActuel;
    final caTotalPrecedent = caCommercePrecedent + caAutresPrecedent;

    // 4. Calcul des Dépenses opérationnelles
    final depensesTotalActuel = depensesActuelles.fold(0, (s, d) => s + d.montant);
    final depensesTotalPrecedent = depensesPrecedentes.fold(0, (s, d) => s + d.montant);

    // 5. Calcul de la Marge Brute et COGS (Commerce)
    var cogsActuel = 0;
    if (etatCommerce != null) {
      for (final v in ventesActuelles) {
        for (final l in v.lignes) {
          final p = etatCommerce.produit(l.produitId);
          final prixAchatUnitaire = p?.prixAchat ?? 0;
          final qteArticles = l.quantiteBase.valeur;
          cogsActuel += (prixAchatUnitaire * qteArticles).round();
        }
      }
    }
    final margeBruteCommerce = caCommerceActuel - cogsActuel;
    final tauxMargeCommerce = caCommerceActuel > 0 ? (margeBruteCommerce / caCommerceActuel) * 100 : 0.0;

    // 6. Résultat estimé
    final resultatEstimeActuel = caTotalActuel - cogsActuel - depensesTotalActuel;
    final resultatEstimePrecedent = caTotalPrecedent - depensesTotalPrecedent;

    // 7. Trésorerie disponible (Argent disponible actuel)
    final tresorerieActuelle = financesFiltrees.caisses
        .map((c) => financesFiltrees.sessionOuverte(c.id))
        .whereType<SessionCaisse>()
        .fold(0, (t, s) => t + financesFiltrees.solde(s));

    // 8. Créances & Dettes actuelles
    var aRecevoirTotal = 0;
    var creancesEnRetard = 0;
    final clientsDebiteurs = <String>{};

    var aPayerTotal = 0;
    var dettesEnRetard = 0;
    final fournisseursCreanciers = <String>{};

    var totalFactureRecouvrement = 0;
    var totalEncaisseRecouvrement = 0;

    for (final s in financesFiltrees.suivis) {
      if (s.engagement.annule || s.engagement.refuse) continue;
      if (s.engagement.sens == SensEngagement.aRecevoir) {
        totalFactureRecouvrement += s.engagement.montantTotal;
        totalEncaisseRecouvrement += s.regle;
        if (s.reste > 0) {
          aRecevoirTotal += s.reste;
          if (s.engagement.contactId != null) clientsDebiteurs.add(s.engagement.contactId!);
          if (s.etat(maintenant) == EtatReglement.enRetard) {
            creancesEnRetard += s.reste;
          }
        }
      } else {
        if (s.reste > 0) {
          aPayerTotal += s.reste;
          if (s.engagement.contactId != null) fournisseursCreanciers.add(s.engagement.contactId!);
          if (s.etat(maintenant) == EtatReglement.enRetard) {
            dettesEnRetard += s.reste;
          }
        }
      }
    }

    // 9. Flux de trésorerie réels sur la période
    var entreesReelles = 0;
    var sortiesReelles = 0;
    var ventesEncaissees = 0;
    var paiementsClients = 0;
    var loyersEncaisses = 0;
    var depensesExploitation = 0;
    var reglementsFournisseurs = 0;

    for (final p in paiementsActuels) {
      if (p.sens == SensPaiement.entree) {
        entreesReelles += p.montant;
        if (p.activite == ActiviteCode.immobilier) {
          loyersEncaisses += p.montant;
        } else if (p.affectations.isNotEmpty) {
          paiementsClients += p.montant;
        } else {
          ventesEncaissees += p.montant;
        }
      } else {
        sortiesReelles += p.montant;
        if (p.affectations.isNotEmpty) {
          reglementsFournisseurs += p.montant;
        } else {
          depensesExploitation += p.montant;
        }
      }
    }

    final fluxNet = entreesReelles - sortiesReelles;

    // 10. Calcul des évolutions comparatives
    double? calcEvolution(int actuel, int precedent) {
      if (precedent <= 0 && actuel <= 0) return null;
      if (precedent <= 0) return 100.0;
      return ((actuel - precedent) / precedent) * 100;
    }

    final evoCA = calcEvolution(caTotalActuel, caTotalPrecedent);
    final evoDepenses = calcEvolution(depensesTotalActuel, depensesTotalPrecedent);
    final evoResultat = calcEvolution(resultatEstimeActuel, resultatEstimePrecedent);

    // 11. Évaluation Santé Financière
    final sante = santeEvaluator.evaluer(
      chiffreAffaires: caTotalActuel,
      depenses: depensesTotalActuel,
      margeOuResultat: resultatEstimeActuel,
      tresorerieActuelle: tresorerieActuelle,
      aRecevoirTotal: aRecevoirTotal,
      creancesEnRetard: creancesEnRetard,
      aPayerTotal: aPayerTotal,
      dettesEnRetard: dettesEnRetard,
      evolutionCA: evoCA,
      evolutionTresorerie: calcEvolution(entreesReelles, sortiesReelles),
    );

    // 12. Séries temporelles
    final serieCA = _genererSerieCA(
      plageActuelle: plageActuelle,
      plagePrecedente: plagePrecedente,
      ventesActuelles: ventesActuelles,
      ventesPrecedentes: ventesPrecedentes,
      engagements: financesFiltrees.engagements,
    );

    final serieTresorerie = _genererSerieTresorerie(
      plage: plageActuelle,
      paiements: financesFiltrees.paiements,
      soldeFinal: tresorerieActuelle,
    );

    final serieMarge = _genererSerieMarge(
      plage: plageActuelle,
      ventes: ventesActuelles,
      etatCommerce: etatCommerce,
    );

    // 13. Répartition Dépenses par catégorie
    final depensesParCat = <String, int>{};
    for (final d in depensesActuelles) {
      depensesParCat[d.categorieId] = (depensesParCat[d.categorieId] ?? 0) + d.montant;
    }
    final categoriesTriees = depensesParCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final categoriesDepensesData = <CategorieDepenseMontant>[];
    for (final entry in categoriesTriees.take(5)) {
      final cat = financesFiltrees.categorie(entry.key);
      final nom = cat?.nom ?? 'Autres charges';
      final pct = depensesTotalActuel > 0 ? (entry.value / depensesTotalActuel) * 100 : 0.0;
      categoriesDepensesData.add(
        CategorieDepenseMontant(
          categorieId: entry.key,
          nom: nom,
          montant: entry.value,
          pourcentage: pct,
        ),
      );
    }

    // 14. Performance par Activité
    final performancesActivites = _calculerPerformancesActivites(
      ventes: ventesActuelles,
      engagements: financesFiltrees.suivis,
      depenses: depensesActuelles,
      paiements: paiementsActuels,
      cogsCommerce: cogsActuel,
    );

    // 15. Performance par Boutique / Site
    final performancesBoutiques = _calculerPerformancesBoutiques(
      finances: financesFiltrees,
      ventes: ventesActuelles,
      nomsPerimetres: nomsPerimetres,
      maintenant: maintenant,
    );

    // 16. Prévisions de trésorerie
    final previsions = tresorerieForecaster.calculer(
      soldeActuel: tresorerieActuelle,
      engagements: financesFiltrees.suivis,
      depensesCourantes: financesFiltrees.courantes,
      maintenant: maintenant,
    );

    // 17. Section « Ce qui change » et Alertes
    final faitsMarquants = _genererFaitsMarquants(
      caActuel: caTotalActuel,
      evoCA: evoCA,
      depensesActuel: depensesTotalActuel,
      evoDepenses: evoDepenses,
      creances: aRecevoirTotal,
      creancesEnRetard: creancesEnRetard,
      margeCommerce: margeBruteCommerce,
      tauxMarge: tauxMargeCommerce,
      previsions: previsions,
    );

    final alertes = _genererAlertes(
      tresorerie: tresorerieActuelle,
      creancesEnRetard: creancesEnRetard,
      dettesEnRetard: dettesEnRetard,
      previsions: previsions,
      evoCA: evoCA,
      margeBrute: margeBruteCommerce,
    );

    final donneesVides = caTotalActuel == 0 &&
        depensesTotalActuel == 0 &&
        tresorerieActuelle == 0 &&
        aRecevoirTotal == 0 &&
        aPayerTotal == 0;

    return FinanceDashboardData(
      periode: periodeFiltre,
      plageDates: plageActuelle,
      chiffreAffaires: IndicateurEvolution(
        valeurActuelle: caTotalActuel,
        valeurPrecedente: caTotalPrecedent,
        tauxEvolution: evoCA,
        comparaisonValable: caTotalPrecedent > 0,
      ),
      resultatEstime: IndicateurEvolution(
        valeurActuelle: resultatEstimeActuel,
        valeurPrecedente: resultatEstimePrecedent,
        tauxEvolution: evoResultat,
        comparaisonValable: resultatEstimePrecedent != 0,
      ),
      tresorerieDisponible: IndicateurEvolution(
        valeurActuelle: tresorerieActuelle,
        comparaisonValable: false,
      ),
      aRecevoir: IndicateurEvolution(
        valeurActuelle: aRecevoirTotal,
        comparaisonValable: false,
      ),
      aPayer: IndicateurEvolution(
        valeurActuelle: aPayerTotal,
        comparaisonValable: false,
      ),
      nombreClientsDebiteurs: clientsDebiteurs.length,
      nombreFournisseursCreanciers: fournisseursCreanciers.length,
      creancesEnRetard: creancesEnRetard,
      dettesEnRetard: dettesEnRetard,
      sante: sante,
      serieEvolutionCA: serieCA,
      serieEvolutionTresorerie: serieTresorerie,
      totalRevenus: caTotalActuel,
      totalDepenses: depensesTotalActuel,
      margeCommerce: MargeCommerceData(
        chiffreAffairesCommerce: caCommerceActuel,
        coutMarchandisesVendues: cogsActuel,
        margeBrute: margeBruteCommerce,
        tauxMargePourcent: tauxMargeCommerce,
        serieMarge: serieMarge,
      ),
      categoriesDepenses: categoriesDepensesData,
      performancesActivites: performancesActivites,
      performancesBoutiques: performancesBoutiques,
      recouvrement: TauxRecouvrementData(
        totalFacture: totalFactureRecouvrement,
        totalEncaisse: totalEncaisseRecouvrement,
        resteARecouvrer: aRecevoirTotal,
        tauxPourcent: totalFactureRecouvrement > 0
            ? (totalEncaisseRecouvrement / totalFactureRecouvrement) * 100
            : 100.0,
      ),
      fluxTresorerie: FluxTresorerieData(
        entreesReelles: entreesReelles,
        sortiesReelles: sortiesReelles,
        fluxNet: fluxNet,
        ventesEncaissees: ventesEncaissees,
        paiementsClients: paiementsClients,
        loyersEncaisses: loyersEncaisses,
        depensesExploitation: depensesExploitation,
        reglementsFournisseurs: reglementsFournisseurs,
      ),
      previsions: previsions,
      faitsMarquants: faitsMarquants,
      alertes: alertes,
      donneesVides: donneesVides,
    );
  }

  List<PointSerieTemporelle> _genererSerieCA({
    required PlageDates plageActuelle,
    required PlageDates plagePrecedente,
    required List<Vente> ventesActuelles,
    required List<Vente> ventesPrecedentes,
    required List<Engagement> engagements,
  }) {
    final points = <PointSerieTemporelle>[];
    final jours = plageActuelle.dureeJours;

    if (jours <= 31) {
      // Découpage journalier
      for (var i = 0; i < jours; i++) {
        final dActuel = plageActuelle.debut.add(Duration(days: i));
        final dPrec = plagePrecedente.debut.add(Duration(days: i));

        final totalActuel = ventesActuelles
            .where((v) => _memeJour(v.date, dActuel))
            .fold(0, (s, v) => s + v.total);

        final totalPrec = ventesPrecedentes
            .where((v) => _memeJour(v.date, dPrec))
            .fold(0, (s, v) => s + v.total);

        points.add(
          PointSerieTemporelle(
            date: dActuel,
            valeur: totalActuel,
            valeurPrecedente: totalPrec,
            label: '${dActuel.day}/${dActuel.month}',
          ),
        );
      }
    } else {
      // Découpage mensuel pour les trimestres / années
      var cur = DateTime(plageActuelle.debut.year, plageActuelle.debut.month, 1);
      final fin = plageActuelle.fin;
      while (!cur.isAfter(fin)) {
        final m = cur.month;
        final y = cur.year;
        final totalMois = ventesActuelles
            .where((v) => v.date.month == m && v.date.year == y)
            .fold(0, (s, v) => s + v.total);

        points.add(
          PointSerieTemporelle(
            date: cur,
            valeur: totalMois,
            label: _nomMoisCourt(m),
          ),
        );
        cur = DateTime(y, m + 1, 1);
      }
    }
    return points;
  }

  List<PointSerieTemporelle> _genererSerieTresorerie({
    required PlageDates plage,
    required List<Paiement> paiements,
    required int soldeFinal,
  }) {
    final points = <PointSerieTemporelle>[];
    final jours = plage.dureeJours;
    if (jours <= 31) {
      for (var i = 0; i < jours; i++) {
        final d = plage.debut.add(Duration(days: i));
        final fluxDuJour = paiements
            .where((p) => _memeJour(p.datePaiement, d) && !p.estTransfert)
            .fold(0, (s, p) => s + (p.sens == SensPaiement.entree ? p.montant : -p.montant));

        points.add(
          PointSerieTemporelle(
            date: d,
            valeur: fluxDuJour,
            label: '${d.day}/${d.month}',
          ),
        );
      }
    }
    return points;
  }

  List<PointSerieTemporelle> _genererSerieMarge({
    required PlageDates plage,
    required List<Vente> ventes,
    required EtatCommerce? etatCommerce,
  }) {
    final points = <PointSerieTemporelle>[];
    final jours = plage.dureeJours;
    if (jours <= 31 && etatCommerce != null) {
      for (var i = 0; i < jours; i++) {
        final d = plage.debut.add(Duration(days: i));
        final ventesJour = ventes.where((v) => _memeJour(v.date, d)).toList();
        final caJour = ventesJour.fold(0, (s, v) => s + v.total);
        var cogsJour = 0;
        for (final v in ventesJour) {
          for (final l in v.lignes) {
            final p = etatCommerce.produit(l.produitId);
            final pa = p?.prixAchat ?? 0;
            cogsJour += (pa * l.quantiteBase.valeur).round();
          }
        }
        final margeJour = caJour - cogsJour;
        points.add(
          PointSerieTemporelle(
            date: d,
            valeur: margeJour,
            label: '${d.day}/${d.month}',
          ),
        );
      }
    }
    return points;
  }

  List<PerformanceActivite> _calculerPerformancesActivites({
    required List<Vente> ventes,
    required List<EngagementSuivi> engagements,
    required List<Depense> depenses,
    required List<Paiement> paiements,
    required int cogsCommerce,
  }) {
    final caCommerce = ventes.fold(0, (s, v) => s + v.total);
    final depensesCommerce = depenses
        .where((d) => d.activite == ActiviteCode.commerce)
        .fold(0, (s, d) => s + d.montant);
    final encaissementsCommerce = paiements
        .where((p) => p.activite == ActiviteCode.commerce && p.sens == SensPaiement.entree)
        .fold(0, (s, p) => s + p.montant);
    final creancesCommerce = engagements
        .where((e) => e.engagement.activite == ActiviteCode.commerce && e.engagement.sens == SensEngagement.aRecevoir)
        .fold(0, (s, e) => s + e.reste);

    final caServices = engagements
        .where((e) => e.engagement.activite == ActiviteCode.services && e.engagement.sens == SensEngagement.aRecevoir)
        .fold(0, (s, e) => s + e.engagement.montantTotal);
    final depensesServices = depenses
        .where((d) => d.activite == ActiviteCode.services)
        .fold(0, (s, d) => s + d.montant);
    final encaissementsServices = paiements
        .where((p) => p.activite == ActiviteCode.services && p.sens == SensPaiement.entree)
        .fold(0, (s, p) => s + p.montant);
    final creancesServices = engagements
        .where((e) => e.engagement.activite == ActiviteCode.services && e.engagement.sens == SensEngagement.aRecevoir)
        .fold(0, (s, e) => s + e.reste);

    final caImmo = engagements
        .where((e) => e.engagement.activite == ActiviteCode.immobilier && e.engagement.sens == SensEngagement.aRecevoir)
        .fold(0, (s, e) => s + e.engagement.montantTotal);
    final depensesImmo = depenses
        .where((d) => d.activite == ActiviteCode.immobilier)
        .fold(0, (s, d) => s + d.montant);
    final encaissementsImmo = paiements
        .where((p) => p.activite == ActiviteCode.immobilier && p.sens == SensPaiement.entree)
        .fold(0, (s, p) => s + p.montant);
    final creancesImmo = engagements
        .where((e) => e.engagement.activite == ActiviteCode.immobilier && e.engagement.sens == SensEngagement.aRecevoir)
        .fold(0, (s, e) => s + e.reste);

    return [
      if (caCommerce > 0 || depensesCommerce > 0 || encaissementsCommerce > 0)
        PerformanceActivite(
          activite: ActiviteCode.commerce,
          nom: 'Commerce',
          chiffreAffaires: caCommerce,
          encaissements: encaissementsCommerce,
          depenses: depensesCommerce,
          margeOuResultat: caCommerce - cogsCommerce - depensesCommerce,
          creances: creancesCommerce,
        ),
      if (caServices > 0 || depensesServices > 0 || encaissementsServices > 0)
        PerformanceActivite(
          activite: ActiviteCode.services,
          nom: 'Services',
          chiffreAffaires: caServices,
          encaissements: encaissementsServices,
          depenses: depensesServices,
          margeOuResultat: caServices - depensesServices,
          creances: creancesServices,
        ),
      if (caImmo > 0 || depensesImmo > 0 || encaissementsImmo > 0)
        PerformanceActivite(
          activite: ActiviteCode.immobilier,
          nom: 'Immobilier',
          chiffreAffaires: caImmo,
          encaissements: encaissementsImmo,
          depenses: depensesImmo,
          margeOuResultat: caImmo - depensesImmo,
          creances: creancesImmo,
        ),
    ];
  }

  List<PerformanceBoutique> _calculerPerformancesBoutiques({
    required EtatFinances finances,
    required List<Vente> ventes,
    required Map<String, String> nomsPerimetres,
    required DateTime maintenant,
  }) {
    final perimetresIds = <String>{
      for (final v in ventes) v.perimetreId,
      for (final c in finances.caisses) c.perimetreId,
      for (final d in finances.depenses)
        if (d.perimetreId != null) d.perimetreId!,
    };

    final result = <PerformanceBoutique>[];
    for (final pid in perimetresIds) {
      final nom = nomsPerimetres[pid] ?? 'Boutique';
      final ca = ventes.where((v) => v.perimetreId == pid).fold(0, (s, v) => s + v.total);
      final dep = finances.depenses
          .where((d) => d.perimetreId == pid && finances.depenseComptee(d))
          .fold(0, (s, d) => s + d.montant);
      final enc = finances.paiements
          .where((p) => p.perimetreId == pid && p.sens == SensPaiement.entree && finances.compte(p))
          .fold(0, (s, p) => s + p.montant);
      final soldeCaisse = finances.caisses
          .where((c) => c.perimetreId == pid)
          .map((c) => finances.sessionOuverte(c.id))
          .whereType<SessionCaisse>()
          .fold(0, (t, s) => t + finances.solde(s));

      var creances = 0;
      var dettes = 0;
      for (final s in finances.suivis) {
        if (s.engagement.perimetreId == pid && !s.engagement.annule && s.reste > 0) {
          if (s.engagement.sens == SensEngagement.aRecevoir) {
            creances += s.reste;
          } else {
            dettes += s.reste;
          }
        }
      }

      result.add(
        PerformanceBoutique(
          perimetreId: pid,
          nom: nom,
          chiffreAffaires: ca,
          encaissements: enc,
          depenses: dep,
          resultatEstime: ca - dep,
          soldeCaisse: soldeCaisse,
          creances: creances,
          dettes: dettes,
        ),
      );
    }
    result.sort((a, b) => b.chiffreAffaires.compareTo(a.chiffreAffaires));
    return result;
  }

  List<FaitMarquantFinance> _genererFaitsMarquants({
    required int caActuel,
    required double? evoCA,
    required int depensesActuel,
    required double? evoDepenses,
    required int creances,
    required int creancesEnRetard,
    required int margeCommerce,
    required double tauxMarge,
    required PrevisionTresorerie previsions,
  }) {
    final faits = <FaitMarquantFinance>[];

    if (evoCA != null && evoCA.abs() >= 5) {
      if (evoCA > 0) {
        faits.add(
          FaitMarquantFinance(
            icone: 'trending_up',
            texte: 'Le chiffre d’affaires a augmenté de ${evoCA.toStringAsFixed(1)} % par rapport à la période précédente.',
            positif: true,
          ),
        );
      } else {
        faits.add(
          FaitMarquantFinance(
            icone: 'trending_down',
            texte: 'Le chiffre d’affaires a diminué de ${evoCA.abs().toStringAsFixed(1)} % sur la période.',
            positif: false,
          ),
        );
      }
    }

    if (creancesEnRetard > 0) {
      faits.add(
        FaitMarquantFinance(
          icone: 'warning',
          texte: 'Des créances clients sont en retard d’échéance (${creancesEnRetard} FCFA au total).',
          positif: false,
        ),
      );
    }

    if (tauxMarge > 0) {
      faits.add(
        FaitMarquantFinance(
          icone: 'percent',
          texte: 'Taux de marge brute moyen de ${tauxMarge.toStringAsFixed(1)} % sur les ventes de marchandises.',
          positif: tauxMarge >= 20,
        ),
      );
    }

    if (previsions.horizon30Jours.tensionDetectee) {
      faits.add(
        FaitMarquantFinance(
          icone: 'schedule',
          texte: 'Attention : tension de trésorerie prévue à 30 jours si les créances ne sont pas encaissées.',
          positif: false,
        ),
      );
    }

    return faits;
  }

  List<AlerteFinanciere> _genererAlertes({
    required int tresorerie,
    required int creancesEnRetard,
    required int dettesEnRetard,
    required PrevisionTresorerie previsions,
    required double? evoCA,
    required int margeBrute,
  }) {
    final alertes = <AlerteFinanciere>[];

    // 1. Alertes urgentes
    if (tresorerie < 0) {
      alertes.add(
        const AlerteFinanciere(
          id: 'alt_treso_negative',
          priorite: PrioriteAlerteFinance.urgent,
          titre: 'Trésorerie en découvert',
          description: 'Le solde réel de votre caisse et de vos comptes est négatif.',
        ),
      );
    }

    if (dettesEnRetard > 0) {
      alertes.add(
        AlerteFinanciere(
          id: 'alt_dettes_retard',
          priorite: PrioriteAlerteFinance.urgent,
          titre: 'Dettes fournisseurs en retard',
          description: 'Des paiements fournisseurs dont l’échéance est passée attendent d’être réglés.',
        ),
      );
    }

    // 2. Alertes à surveiller
    if (creancesEnRetard > 0) {
      alertes.add(
        AlerteFinanciere(
          id: 'alt_creances_retard',
          priorite: PrioriteAlerteFinance.aSurveiller,
          titre: 'Créances clients en retard',
          description: 'Pensez à relancer les clients dont les factures ou ventes à crédit sont échues.',
        ),
      );
    }

    if (evoCA != null && evoCA < -15) {
      alertes.add(
        AlerteFinanciere(
          id: 'alt_baisse_ca',
          priorite: PrioriteAlerteFinance.aSurveiller,
          titre: 'Forte baisse des ventes',
          description: 'Le chiffre d’affaires est en retrait de plus de 15 % sur la période.',
        ),
      );
    }

    // 3. Alertes positives
    if (evoCA != null && evoCA >= 15) {
      alertes.add(
        AlerteFinanciere(
          id: 'alt_croissance_ca',
          priorite: PrioriteAlerteFinance.positif,
          titre: 'Croissance solide du chiffre d’affaires',
          description: 'Votre activité progresse de +${evoCA.toStringAsFixed(1)} % par rapport à la période précédente.',
        ),
      );
    }

    return alertes;
  }

  bool _memeJour(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _nomMoisCourt(int mois) => const [
        'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
        'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'
      ][(mois - 1).clamp(0, 11)];
}
