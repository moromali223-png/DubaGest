import 'dart:math' as math;

import '../../../activites/domain/entities/activite.dart';
import '../../../finances/domain/entities/finances.dart';
import '../../../finances/domain/services/etat_finances.dart';
import '../entities/benefice_commerce_data.dart';
import '../entities/commerce.dart';
import 'etat_commerce.dart';

/// Moteur de calcul pur pour le module Bénéfice Commerce.
/// Fonctionne hors-ligne et en miroir de la fonction Supabase `app.calculer_benefice_commerce`.
abstract final class CalculBeneficeCommerce {
  /// Résout les dates selon le type de filtre sélectionné.
  static IntervalleBenefice resoudreIntervalle(
    TypeFiltreBenefice type, {
    DateTime? datePrecise,
    DateTime? debutPerso,
    DateTime? finPerso,
    DateTime? reference,
  }) {
    final now = reference ?? DateTime.now();
    final minuit = DateTime(now.year, now.month, now.day);
    final finJour = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    switch (type) {
      case TypeFiltreBenefice.aujourdhui:
        final debut = minuit;
        final fin = finJour;
        final debutPrec = debut.subtract(const Duration(days: 1));
        final finPrec = fin.subtract(const Duration(days: 1));
        return IntervalleBenefice(
          type: type,
          debut: debut,
          fin: fin,
          debutPrecedent: debutPrec,
          finPrecedent: finPrec,
        );

      case TypeFiltreBenefice.hier:
        final debut = minuit.subtract(const Duration(days: 1));
        final fin = DateTime(debut.year, debut.month, debut.day, 23, 59, 59, 999);
        final debutPrec = debut.subtract(const Duration(days: 1));
        final finPrec = fin.subtract(const Duration(days: 1));
        return IntervalleBenefice(
          type: type,
          debut: debut,
          fin: fin,
          debutPrecedent: debutPrec,
          finPrecedent: finPrec,
        );

      case TypeFiltreBenefice.cetteSemaine:
        final decalage = now.weekday - 1;
        final debut = DateTime(now.year, now.month, now.day - decalage);
        final fin = finJour;
        final debutPrec = debut.subtract(const Duration(days: 7));
        final finPrec = fin.subtract(const Duration(days: 7));
        return IntervalleBenefice(
          type: type,
          debut: debut,
          fin: fin,
          debutPrecedent: debutPrec,
          finPrecedent: finPrec,
        );

      case TypeFiltreBenefice.semainePrecedente:
        final decalage = now.weekday - 1;
        final debutCourante = DateTime(now.year, now.month, now.day - decalage);
        final debut = debutCourante.subtract(const Duration(days: 7));
        final fin = DateTime(debut.year, debut.month, debut.day + 6, 23, 59, 59, 999);
        final debutPrec = debut.subtract(const Duration(days: 7));
        final finPrec = fin.subtract(const Duration(days: 7));
        return IntervalleBenefice(
          type: type,
          debut: debut,
          fin: fin,
          debutPrecedent: debutPrec,
          finPrecedent: finPrec,
        );

      case TypeFiltreBenefice.ceMois:
        final debut = DateTime(now.year, now.month, 1);
        final fin = finJour;
        final anneePrec = now.month == 1 ? now.year - 1 : now.year;
        final moisPrec = now.month == 1 ? 12 : now.month - 1;
        final maxJourPrec = DateTime(anneePrec, moisPrec + 1, 0).day;
        final jourCible = math.min(now.day, maxJourPrec);
        final debutPrec = DateTime(anneePrec, moisPrec, 1);
        final finPrec = DateTime(anneePrec, moisPrec, jourCible, 23, 59, 59, 999);
        return IntervalleBenefice(
          type: type,
          debut: debut,
          fin: fin,
          debutPrecedent: debutPrec,
          finPrecedent: finPrec,
        );

      case TypeFiltreBenefice.moisPrecedent:
        final anneePrec = now.month == 1 ? now.year - 1 : now.year;
        final moisPrec = now.month == 1 ? 12 : now.month - 1;
        final debut = DateTime(anneePrec, moisPrec, 1);
        final fin = DateTime(now.year, now.month, 0, 23, 59, 59, 999);
        final anneePrec2 = moisPrec == 1 ? anneePrec - 1 : anneePrec;
        final moisPrec2 = moisPrec == 1 ? 12 : moisPrec - 1;
        final debutPrec = DateTime(anneePrec2, moisPrec2, 1);
        final finPrec = DateTime(anneePrec, moisPrec, 0, 23, 59, 59, 999);
        return IntervalleBenefice(
          type: type,
          debut: debut,
          fin: fin,
          debutPrecedent: debutPrec,
          finPrecedent: finPrec,
        );

      case TypeFiltreBenefice.cetteAnnee:
        final debut = DateTime(now.year, 1, 1);
        final fin = finJour;
        final debutPrec = DateTime(now.year - 1, 1, 1);
        final finPrec = DateTime(now.year - 1, now.month, math.min(now.day, 28), 23, 59, 59, 999);
        return IntervalleBenefice(
          type: type,
          debut: debut,
          fin: fin,
          debutPrecedent: debutPrec,
          finPrecedent: finPrec,
        );

      case TypeFiltreBenefice.anneePrecedente:
        final debut = DateTime(now.year - 1, 1, 1);
        final fin = DateTime(now.year - 1, 12, 31, 23, 59, 59, 999);
        final debutPrec = DateTime(now.year - 2, 1, 1);
        final finPrec = DateTime(now.year - 2, 12, 31, 23, 59, 59, 999);
        return IntervalleBenefice(
          type: type,
          debut: debut,
          fin: fin,
          debutPrecedent: debutPrec,
          finPrecedent: finPrec,
        );

      case TypeFiltreBenefice.datePrecise:
        final cible = datePrecise ?? minuit;
        final debut = DateTime(cible.year, cible.month, cible.day);
        final fin = DateTime(cible.year, cible.month, cible.day, 23, 59, 59, 999);
        final debutPrec = debut.subtract(const Duration(days: 1));
        final finPrec = fin.subtract(const Duration(days: 1));
        return IntervalleBenefice(
          type: type,
          debut: debut,
          fin: fin,
          debutPrecedent: debutPrec,
          finPrecedent: finPrec,
          datePreciseSelectionnee: cible,
        );

      case TypeFiltreBenefice.personnalise:
        final d = debutPerso ?? minuit.subtract(const Duration(days: 29));
        final f = finPerso ?? finJour;
        final debut = DateTime(d.year, d.month, d.day);
        final fin = DateTime(f.year, f.month, f.day, 23, 59, 59, 999);
        final duree = fin.difference(debut);
        final debutPrec = debut.subtract(duree);
        final finPrec = debut.subtract(const Duration(milliseconds: 1));
        return IntervalleBenefice(
          type: type,
          debut: debut,
          fin: fin,
          debutPrecedent: debutPrec,
          finPrecedent: finPrec,
        );
    }
  }

  /// Calcule l'état complet du bénéfice à partir des états métier.
  static EtatBeneficeCommerce calculer({
    required EtatCommerce commerce,
    required EtatFinances finances,
    required IntervalleBenefice intervalle,
    String? perimetreId,
  }) {
    // 1. Filtrage strict des ventes
    final ventesValides = commerce.ventes.where((v) {
      if (v.annulee || v.refuse) return false;
      if (perimetreId != null && v.perimetreId != perimetreId) return false;
      return true;
    }).toList();

    final ventesActuelles = ventesValides.where((v) => intervalle.contient(v.date)).toList();
    final ventesPrecedentes = ventesValides.where((v) => intervalle.contientPrecedent(v.date)).toList();

    // Map des produits
    final mapProduits = {for (final p in commerce.produits) p.id: p};

    // 2. Chiffre d'affaires
    var caBrut = 0;
    var remises = 0;
    var caNet = 0;

    for (final v in ventesActuelles) {
      caBrut += (v.total + v.remise);
      remises += v.remise;
      caNet += v.total;
    }

    final caNetPrec = ventesPrecedentes.fold<int>(0, (acc, v) => acc + v.total);

    // 3. Coût des marchandises vendues (COGS)
    var cogs = 0;
    var nbLignesTotal = 0;
    var nbLignesAvecCout = 0;

    // Agrégat par produit
    final mapQteVendue = <String, double>{};
    final mapCaProduit = <String, int>{};

    for (final v in ventesActuelles) {
      for (final l in v.lignes) {
        nbLignesTotal++;
        final p = mapProduits[l.produitId];
        final qteBase = l.quantiteBase.valeur;
        mapQteVendue[l.produitId] = (mapQteVendue[l.produitId] ?? 0.0) + qteBase;
        mapCaProduit[l.produitId] = (mapCaProduit[l.produitId] ?? 0) + l.montant;

        final prixAchat = p?.prixAchat;
        if (prixAchat != null && prixAchat > 0) {
          nbLignesAvecCout++;
          cogs += (qteBase * prixAchat).round();
        }
      }
    }

    // COGS période précédente
    var cogsPrec = 0;
    for (final v in ventesPrecedentes) {
      for (final l in v.lignes) {
        final p = mapProduits[l.produitId];
        final prixAchat = p?.prixAchat;
        if (prixAchat != null && prixAchat > 0) {
          cogsPrec += (l.quantiteBase.valeur * prixAchat).round();
        }
      }
    }

    final margeBrute = caNet - cogs;
    final margeBrutePrec = caNetPrec - cogsPrec;
    final tauxMarge = caNet > 0 ? (margeBrute / caNet) * 100 : 0.0;
    final tauxCouverture = nbLignesTotal > 0 ? (nbLignesAvecCout / nbLignesTotal) * 100 : 100.0;

    // 4. Dépenses d'exploitation imputables au commerce
    // Règle : Si périmètre choisi -> dépenses de la boutique.
    // Si vue globale -> dépenses commerce de toutes boutiques + dépenses générales de l'entreprise (siège).
    final depensesCommerce = finances.depenses.where((d) {
      if (d.annulee) return false;
      if (d.activite != null && d.activite != ActiviteCode.commerce) return false;
      if (perimetreId != null) {
        return d.perimetreId == perimetreId;
      }
      return true;
    }).toList();

    var depensesActuelles = 0;
    var depensesPrec = 0;

    final mapDepensesCategories = <String, int>{};

    for (final d in depensesCommerce) {
      if (intervalle.contient(d.dateDepense)) {
        depensesActuelles += d.montant;
        mapDepensesCategories[d.categorieId] = (mapDepensesCategories[d.categorieId] ?? 0) + d.montant;
      } else if (intervalle.contientPrecedent(d.dateDepense)) {
        depensesPrec += d.montant;
      }
    }

    final beneficeNet = margeBrute - depensesActuelles;
    final beneficeNetPrec = margeBrutePrec - depensesPrec;
    final tauxBeneficeNet = caNet > 0 ? (beneficeNet / caNet) * 100 : 0.0;

    // 5. Trésorerie réelle sur la période (Mouvements effectifs de cash)
    final paiementsValides = finances.paiements.where((p) {
      if (p.annuleServeur || p.refuse || p.estTransfert || p.estAnnulation) return false;
      if (perimetreId != null && p.perimetreId != perimetreId) return false;
      return true;
    }).toList();

    var totalEncaisse = 0;
    var totalDecaisse = 0;

    for (final p in paiementsValides) {
      if (!intervalle.contient(p.datePaiement)) continue;
      if (p.sens == SensPaiement.entree) {
        totalEncaisse += p.montant;
      } else if (p.sens == SensPaiement.sortie) {
        totalDecaisse += p.montant;
      }
    }

    final soldeNetFlux = totalEncaisse - totalDecaisse;

    // Créances restantes sur ventes à crédit
    var creancesRestantes = 0;
    for (final e in finances.engagements) {
      if (e.annule || e.refuse) continue;
      if (e.sens != SensEngagement.aRecevoir) continue;
      if (e.origineType != 'VENTE') continue;
      if (perimetreId != null && e.perimetreId != perimetreId) continue;
      final reste = e.montantTotal - e.montantRegle;
      if (reste > 0) {
        creancesRestantes += reste;
      }
    }

    // 6. Répartition des dépenses par catégorie
    final repartitionDepenses = <RepartitionDepenseItem>[];

    for (final entry in mapDepensesCategories.entries) {
      final cat = finances.categorie(entry.key);
      final montant = entry.value;
      final pct = depensesActuelles > 0 ? (montant / depensesActuelles) * 100 : 0.0;
      repartitionDepenses.add(RepartitionDepenseItem(
        categorieId: entry.key,
        categorieNom: cat?.nom ?? 'Autres charges',
        total: montant,
        pourcentage: double.parse(pct.toStringAsFixed(1)),
      ));
    }
    repartitionDepenses.sort((a, b) => b.total.compareTo(a.total));

    // 7. Rentabilité par produit
    final produitsRentabilite = <ProduitRentabiliteItem>[];
    final produitsSansCout = <ProduitCoutManquantItem>[];

    for (final entry in mapQteVendue.entries) {
      final p = mapProduits[entry.key];
      final qte = entry.value;
      final ca = mapCaProduit[entry.key] ?? 0;
      final prixAchat = p?.prixAchat;
      final coutManquant = prixAchat == null || prixAchat <= 0;
      final cogsProd = coutManquant ? 0 : (qte * prixAchat).round();
      final margeProd = ca - cogsProd;

      produitsRentabilite.add(ProduitRentabiliteItem(
        produitId: entry.key,
        nom: p?.nom ?? 'Produit inconnu',
        uniteBase: p?.uniteBase ?? 'Pièce',
        quantiteVendue: qte,
        chiffreAffaires: ca,
        coutAchatUnitaire: prixAchat,
        cogs: cogsProd,
        margeBrute: margeProd,
        coutManquant: coutManquant,
        reference: p?.reference,
      ));

      if (coutManquant && p != null) {
        produitsSansCout.add(ProduitCoutManquantItem(
          produitId: p.id,
          nom: p.nom,
          uniteBase: p.uniteBase,
          reference: p.reference,
        ));
      }
    }
    produitsRentabilite.sort((a, b) => b.margeBrute.compareTo(a.margeBrute));

    // 8. Série chronologique d'évolution
    final pointsEvolution = _genererSerieEvolution(
      debut: intervalle.debut,
      fin: intervalle.fin,
      ventes: ventesActuelles,
      depenses: depensesCommerce.where((d) => intervalle.contient(d.dateDepense)).toList(),
      mapProduits: mapProduits,
    );

    return EtatBeneficeCommerce(
      intervalle: intervalle,
      perimetreId: perimetreId,
      kpi: KpiBeneficeCommerce(
        chiffreAffairesBrut: caBrut,
        remises: remises,
        chiffreAffairesNet: caNet,
        chiffreAffairesPrecedent: caNetPrec,
        nombreVentes: ventesActuelles.length,
        cogs: cogs,
        cogsPrecedent: cogsPrec,
        margeBrute: margeBrute,
        margeBrutePrecedente: margeBrutePrec,
        tauxMarge: double.parse(tauxMarge.toStringAsFixed(2)),
        depensesCommerciales: depensesActuelles,
        depensesPrecedentes: depensesPrec,
        beneficeNetEstime: beneficeNet,
        beneficeNetPrecedent: beneficeNetPrec,
        tauxBeneficeNet: double.parse(tauxBeneficeNet.toStringAsFixed(2)),
        tauxCouvertureCout: double.parse(tauxCouverture.toStringAsFixed(2)),
        lignesTotal: nbLignesTotal,
        lignesAvecCout: nbLignesAvecCout,
      ),
      tresorerie: TresorerieReelleCommerce(
        totalEncaisse: totalEncaisse,
        totalDecaisse: totalDecaisse,
        soldeNetFlux: soldeNetFlux,
        creancesClientsRestantes: creancesRestantes,
      ),
      repartitionDepenses: repartitionDepenses,
      produitsRentabilite: produitsRentabilite.take(20).toList(),
      produitsCoutManquant: produitsSansCout.take(15).toList(),
      pointsEvolution: pointsEvolution,
      dateCalcul: DateTime.now(),
    );
  }

  static List<PointEvolutionBenefice> _genererSerieEvolution({
    required DateTime debut,
    required DateTime fin,
    required List<Vente> ventes,
    required List<Depense> depenses,
    required Map<String, Produit> mapProduits,
  }) {
    final duree = fin.difference(debut);
    final points = <PointEvolutionBenefice>[];

    if (duree.inDays <= 35) {
      // Par jour
      var cur = DateTime(debut.year, debut.month, debut.day);
      final finMinuit = DateTime(fin.year, fin.month, fin.day);

      while (!cur.isAfter(finMinuit)) {
        final curFin = DateTime(cur.year, cur.month, cur.day, 23, 59, 59, 999);
        var caJour = 0;
        var cogsJour = 0;

        for (final v in ventes) {
          if (!v.date.isBefore(cur) && !v.date.isAfter(curFin)) {
            caJour += v.total;
            for (final l in v.lignes) {
              final p = mapProduits[l.produitId];
              final prixAchat = p?.prixAchat;
              if (prixAchat != null && prixAchat > 0) {
                cogsJour += (l.quantiteBase.valeur * prixAchat).round();
              }
            }
          }
        }

        var depJour = 0;
        for (final d in depenses) {
          if (!d.dateDepense.isBefore(cur) && !d.dateDepense.isAfter(curFin)) {
            depJour += d.montant;
          }
        }

        final marge = caJour - cogsJour;
        final net = marge - depJour;

        points.add(PointEvolutionBenefice(
          date: cur,
          label: '${cur.day}/${cur.month}',
          chiffreAffaires: caJour,
          cogs: cogsJour,
          margeBrute: marge,
          depenses: depJour,
          beneficeNet: net,
        ));

        cur = cur.add(const Duration(days: 1));
      }
    } else {
      // Par mois
      var cur = DateTime(debut.year, debut.month, 1);
      final finMois = DateTime(fin.year, fin.month, 1);

      while (!cur.isAfter(finMois)) {
        final moisFin = DateTime(cur.year, cur.month + 1, 0, 23, 59, 59, 999);
        var caMois = 0;
        var cogsMois = 0;

        for (final v in ventes) {
          if (!v.date.isBefore(cur) && !v.date.isAfter(moisFin)) {
            caMois += v.total;
            for (final l in v.lignes) {
              final p = mapProduits[l.produitId];
              final prixAchat = p?.prixAchat;
              if (prixAchat != null && prixAchat > 0) {
                cogsMois += (l.quantiteBase.valeur * prixAchat).round();
              }
            }
          }
        }

        var depMois = 0;
        for (final d in depenses) {
          if (!d.dateDepense.isBefore(cur) && !d.dateDepense.isAfter(moisFin)) {
            depMois += d.montant;
          }
        }

        final marge = caMois - cogsMois;
        final net = marge - depMois;

        points.add(PointEvolutionBenefice(
          date: cur,
          label: '${cur.month}/${cur.year}',
          chiffreAffaires: caMois,
          cogs: cogsMois,
          margeBrute: marge,
          depenses: depMois,
          beneficeNet: net,
        ));

        cur = DateTime(cur.year, cur.month + 1, 1);
      }
    }

    return points;
  }
}

