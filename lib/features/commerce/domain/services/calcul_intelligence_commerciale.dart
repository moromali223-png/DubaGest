import 'dart:math' as math;

import '../../../contacts/domain/entities/contact.dart';
import '../../../finances/domain/entities/finances.dart';
import '../../../finances/domain/services/etat_finances.dart';
import '../entities/commerce.dart';
import '../entities/intelligence_commerciale_data.dart';
import 'etat_commerce.dart';

/// Moteur de calcul pur pour l'intelligence commerciale et décisionnelle.
///
/// Ne réalise aucune modification en base ni dans les flux opérationnels.
/// Fonctionne hors-ligne à 100% sur les états locaux [EtatCommerce] et [EtatFinances].
abstract final class CalculIntelligenceCommerciale {
  /// Résout les dates d'une période d'analyse et sa période de comparaison équivalente.
  static IntervallePeriode resoudreIntervalle(
    PeriodeAnalyseType type, {
    DateTime? debutPerso,
    DateTime? finPerso,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final aujourdhuiMinuit = DateTime(ref.year, ref.month, ref.day);
    final aujourdhuiFin = DateTime(ref.year, ref.month, ref.day, 23, 59, 59, 999);

    switch (type) {
      case PeriodeAnalyseType.aujourdhui:
        final debut = aujourdhuiMinuit;
        final fin = aujourdhuiFin;
        final debutPrec = debut.subtract(const Duration(days: 1));
        final finPrec = fin.subtract(const Duration(days: 1));
        return IntervallePeriode(
          type: type,
          debut: debut,
          fin: fin,
          debutPrecedent: debutPrec,
          finPrecedent: finPrec,
        );

      case PeriodeAnalyseType.hier:
        final debut = aujourdhuiMinuit.subtract(const Duration(days: 1));
        final fin = DateTime(debut.year, debut.month, debut.day, 23, 59, 59, 999);
        final debutPrec = debut.subtract(const Duration(days: 1));
        final finPrec = fin.subtract(const Duration(days: 1));
        return IntervallePeriode(
          type: type,
          debut: debut,
          fin: fin,
          debutPrecedent: debutPrec,
          finPrecedent: finPrec,
        );

      case PeriodeAnalyseType.septDerniersJours:
        final debut = aujourdhuiMinuit.subtract(const Duration(days: 6));
        final fin = aujourdhuiFin;
        final debutPrec = debut.subtract(const Duration(days: 7));
        final finPrec = debut.subtract(const Duration(milliseconds: 1));
        return IntervallePeriode(
          type: type,
          debut: debut,
          fin: fin,
          debutPrecedent: debutPrec,
          finPrecedent: finPrec,
        );

      case PeriodeAnalyseType.trenteDerniersJours:
        final debut = aujourdhuiMinuit.subtract(const Duration(days: 29));
        final fin = aujourdhuiFin;
        final debutPrec = debut.subtract(const Duration(days: 30));
        final finPrec = debut.subtract(const Duration(milliseconds: 1));
        return IntervallePeriode(
          type: type,
          debut: debut,
          fin: fin,
          debutPrecedent: debutPrec,
          finPrecedent: finPrec,
        );

      case PeriodeAnalyseType.semaineEnCours:
        // Lundi de la semaine en cours
        final decalageLundi = ref.weekday - 1;
        final debut = DateTime(ref.year, ref.month, ref.day - decalageLundi);
        final fin = aujourdhuiFin;
        final debutPrec = debut.subtract(const Duration(days: 7));
        final finPrec = fin.subtract(const Duration(days: 7));
        return IntervallePeriode(
          type: type,
          debut: debut,
          fin: fin,
          debutPrecedent: debutPrec,
          finPrecedent: finPrec,
        );

      case PeriodeAnalyseType.semainePrecedente:
        final decalageLundi = ref.weekday - 1;
        final debutSemaineCourante = DateTime(ref.year, ref.month, ref.day - decalageLundi);
        final debut = debutSemaineCourante.subtract(const Duration(days: 7));
        final fin = DateTime(debut.year, debut.month, debut.day + 6, 23, 59, 59, 999);
        final debutPrec = debut.subtract(const Duration(days: 7));
        final finPrec = fin.subtract(const Duration(days: 7));
        return IntervallePeriode(
          type: type,
          debut: debut,
          fin: fin,
          debutPrecedent: debutPrec,
          finPrecedent: finPrec,
        );

      case PeriodeAnalyseType.moisEnCours:
        final debut = DateTime(ref.year, ref.month, 1);
        final fin = aujourdhuiFin;
        // Même jour dans le mois précédent
        final moisPrecAnnee = ref.month == 1 ? ref.year - 1 : ref.year;
        final moisPrecMois = ref.month == 1 ? 12 : ref.month - 1;
        final maxJourMoisPrec = DateTime(moisPrecAnnee, moisPrecMois + 1, 0).day;
        final jourCible = math.min(ref.day, maxJourMoisPrec);
        final debutPrec = DateTime(moisPrecAnnee, moisPrecMois, 1);
        final finPrec = DateTime(moisPrecAnnee, moisPrecMois, jourCible, 23, 59, 59, 999);
        return IntervallePeriode(
          type: type,
          debut: debut,
          fin: fin,
          debutPrecedent: debutPrec,
          finPrecedent: finPrec,
        );

      case PeriodeAnalyseType.moisPrecedent:
        final moisPrecAnnee = ref.month == 1 ? ref.year - 1 : ref.year;
        final moisPrecMois = ref.month == 1 ? 12 : ref.month - 1;
        final debut = DateTime(moisPrecAnnee, moisPrecMois, 1);
        final fin = DateTime(ref.year, ref.month, 0, 23, 59, 59, 999);
        final moisPrec2Annee = moisPrecMois == 1 ? moisPrecAnnee - 1 : moisPrecAnnee;
        final moisPrec2Mois = moisPrecMois == 1 ? 12 : moisPrecMois - 1;
        final debutPrec = DateTime(moisPrec2Annee, moisPrec2Mois, 1);
        final finPrec = DateTime(moisPrecAnnee, moisPrecMois, 0, 23, 59, 59, 999);
        return IntervallePeriode(
          type: type,
          debut: debut,
          fin: fin,
          debutPrecedent: debutPrec,
          finPrecedent: finPrec,
        );

      case PeriodeAnalyseType.trimestre:
        final moisDebutTrimestre = ((ref.month - 1) ~/ 3) * 3 + 1;
        final debut = DateTime(ref.year, moisDebutTrimestre, 1);
        final fin = aujourdhuiFin;
        final debutPrec = DateTime(ref.year, moisDebutTrimestre - 3, 1);
        final finPrec = DateTime(debut.year, debut.month, 0, 23, 59, 59, 999);
        return IntervallePeriode(
          type: type,
          debut: debut,
          fin: fin,
          debutPrecedent: debutPrec,
          finPrecedent: finPrec,
        );

      case PeriodeAnalyseType.annee:
        final debut = DateTime(ref.year, 1, 1);
        final fin = aujourdhuiFin;
        final debutPrec = DateTime(ref.year - 1, 1, 1);
        final finPrec = DateTime(ref.year - 1, ref.month, math.min(ref.day, 28), 23, 59, 59, 999);
        return IntervallePeriode(
          type: type,
          debut: debut,
          fin: fin,
          debutPrecedent: debutPrec,
          finPrecedent: finPrec,
        );

      case PeriodeAnalyseType.personnalise:
        final d = debutPerso ?? aujourdhuiMinuit.subtract(const Duration(days: 6));
        final f = finPerso ?? aujourdhuiFin;
        final duree = f.difference(d);
        final debutPrec = d.subtract(duree);
        final finPrec = d.subtract(const Duration(milliseconds: 1));
        return IntervallePeriode(
          type: type,
          debut: d,
          fin: f,
          debutPrecedent: debutPrec,
          finPrecedent: finPrec,
        );
    }
  }

  /// Calcule l'état analytique global à partir des données réelles.
  static EtatIntelligenceCommerciale calculer({
    required EtatCommerce commerce,
    required EtatFinances finances,
    required List<Contact> contacts,
    required IntervallePeriode intervalle,
    String? perimetreId,
  }) {
    // 1. Filtrage strict des ventes non-annulées
    final ventesValides = commerce.ventes.where((v) {
      if (v.annulee) return false;
      if (perimetreId != null && v.perimetreId != perimetreId) return false;
      return true;
    }).toList();

    final ventesPeriode = ventesValides.where((v) => intervalle.contient(v.date)).toList();
    final ventesPrecedentes = ventesValides.where((v) => intervalle.contientPrecedent(v.date)).toList();

    // Map rapide des produits
    final mapProduits = {for (final p in commerce.produits) p.id: p};
    final mapContacts = {for (final c in contacts) c.id: c};

    // 2. Chiffre d'affaires & Volumes
    final caActuel = ventesPeriode.fold<int>(0, (acc, v) => acc + v.total);
    final caPrecedent = ventesPrecedentes.fold<int>(0, (acc, v) => acc + v.total);
    final variationCAPct = caPrecedent > 0 ? ((caActuel - caPrecedent) / caPrecedent) * 100 : null;

    final qteActuelle = ventesPeriode.fold<double>(
      0.0,
      (acc, v) => acc + v.lignes.fold<double>(0.0, (lAcc, l) => lAcc + l.quantiteBase.valeur),
    );
    final qtePrecedente = ventesPrecedentes.fold<double>(
      0.0,
      (acc, v) => acc + v.lignes.fold<double>(0.0, (lAcc, l) => lAcc + l.quantiteBase.valeur),
    );
    final variationQtePct = qtePrecedente > 0 ? ((qteActuelle - qtePrecedente) / qtePrecedente) * 100 : null;

    // 3. Calcul de la marge brute estimée (rigoureux)
    int? margeTotaleActuelle;
    int? margeTotalePrecedente;
    var nbLignesTotal = 0;
    var nbLignesAvecCout = 0;

    int totalCoutActuel = 0;
    int caCouvertParCout = 0;

    for (final v in ventesPeriode) {
      for (final l in v.lignes) {
        nbLignesTotal++;
        final p = mapProduits[l.produitId];
        final prixAchatBase = p?.prixAchat;
        if (prixAchatBase != null && prixAchatBase > 0) {
          nbLignesAvecCout++;
          final coutLigne = (l.quantiteBase.valeur * prixAchatBase).round();
          totalCoutActuel += coutLigne;
          caCouvertParCout += l.montant;
        }
      }
    }

    final ratioCouverture = nbLignesTotal > 0 ? (nbLignesAvecCout / nbLignesTotal) : 0.0;
    final margeFiable = ratioCouverture >= 0.60 && nbLignesTotal > 0;

    if (margeFiable) {
      margeTotaleActuelle = caCouvertParCout - totalCoutActuel;
    }

    // Calcul marge période précédente si disponible
    int totalCoutPrec = 0;
    int caCouvertPrec = 0;
    var nbLignesPrecTotal = 0;
    var nbLignesPrecAvecCout = 0;

    for (final v in ventesPrecedentes) {
      for (final l in v.lignes) {
        nbLignesPrecTotal++;
        final p = mapProduits[l.produitId];
        final prixAchatBase = p?.prixAchat;
        if (prixAchatBase != null && prixAchatBase > 0) {
          nbLignesPrecAvecCout++;
          final coutLigne = (l.quantiteBase.valeur * prixAchatBase).round();
          totalCoutPrec += coutLigne;
          caCouvertPrec += l.montant;
        }
      }
    }

    if (nbLignesPrecTotal > 0 && (nbLignesPrecAvecCout / nbLignesPrecTotal) >= 0.60) {
      margeTotalePrecedente = caCouvertPrec - totalCoutPrec;
    }

    double? variationMargePct;
    if (margeTotaleActuelle != null && margeTotalePrecedente != null && margeTotalePrecedente > 0) {
      variationMargePct = ((margeTotaleActuelle - margeTotalePrecedente) / margeTotalePrecedente) * 100;
    }

    // Encaissements et ventes à crédit
    final encaissements = ventesPeriode.fold<int>(0, (acc, v) => acc + v.montantPaye);
    final ventesCredit = ventesPeriode.where((v) => v.reglement == ReglementVente.credit).fold<int>(
          0,
          (acc, v) => acc + (v.total - v.montantPaye).clamp(0, 1000000000),
        );
    final nombreVentes = ventesPeriode.length;
    final panierMoyen = nombreVentes > 0 ? (caActuel ~/ nombreVentes) : 0;

    // 4. Performance détaillée par produit
    final performanceProduits = _calculerPerformancesProduits(
      commerce: commerce,
      ventesPeriode: ventesPeriode,
      ventesPrecedentes: ventesPrecedentes,
      mapProduits: mapProduits,
      intervalle: intervalle,
      perimetreId: perimetreId,
    );

    // Top produit par CA
    PerformanceProduit? topProduit;
    if (performanceProduits.isNotEmpty) {
      final trieParCA = [...performanceProduits]..sort((a, b) => b.chiffreAffaires.compareTo(a.chiffreAffaires));
      topProduit = trieParCA.first;
    }

    // Résumé
    final resume = ResumeIntelligenceCommerciale(
      chiffreAffaires: caActuel,
      chiffreAffairesPrecedent: caPrecedent,
      variationCAPct: variationCAPct,
      quantiteVendue: qteActuelle,
      quantiteVenduePrecedente: qtePrecedente,
      variationQuantitePct: variationQtePct,
      margeBruteEstimee: margeTotaleActuelle,
      margeBrutePrecedente: margeTotalePrecedente,
      variationMargePct: variationMargePct,
      margeFiable: margeFiable,
      pourcentageProduitsAvecMarge: (ratioCouverture * 100).roundToDouble(),
      topProduitNom: topProduit?.nom,
      topProduitChiffreAffaires: topProduit?.chiffreAffaires,
      topProduitQuantite: topProduit?.quantiteVendue,
      nombreVentes: nombreVentes,
      panierMoyen: panierMoyen,
      totalEncaissementsVentes: encaissements,
      totalVentesCredit: ventesCredit,
    );

    // 5. Points d'évolution des ventes (Série chronologique)
    final pointsEvolution = _genererSerieEvolution(
      ventesActuelles: ventesPeriode,
      ventesPrecedentes: ventesPrecedentes,
      intervalle: intervalle,
      mapProduits: mapProduits,
    );

    // 6. Tendances en hausse / baisse
    final progressions = <TendanceProduit>[];
    final ralentissements = <TendanceProduit>[];

    for (final perf in performanceProduits) {
      if (perf.quantiteVendue == 0 && perf.quantiteVenduePrecedente == 0) continue;

      final variation = perf.variationQuantitePct;
      if (variation == null) {
        // Nouveaux produits avec volume significatif
        if (perf.quantiteVendue >= 3) {
          progressions.add(TendanceProduit(
            produit: perf,
            enProgression: true,
            variationQuantite: perf.quantiteVendue,
            variationPourcentage: 100.0,
            niveauConfiance: perf.quantiteVendue >= 10 ? 'Élevé' : 'Modéré',
            conseilAction: 'Nouveau succès commercial : assurez-vous d’anticiper le stock.',
          ));
        }
      } else if (variation >= 15.0 && perf.quantiteVendue >= 3) {
        final diffQte = perf.quantiteVendue - perf.quantiteVenduePrecedente;
        final conf = perf.quantiteVendue >= 15 ? 'Élevé' : (perf.quantiteVendue >= 5 ? 'Modéré' : 'Indicatif');
        progressions.add(TendanceProduit(
          produit: perf,
          enProgression: true,
          variationQuantite: diffQte,
          variationPourcentage: variation,
          niveauConfiance: conf,
          conseilAction: perf.estCritique || perf.estRupture
              ? 'Forte demande mais stock faible : passer commande d’urgence.'
              : 'Produit moteur : maintenir une bonne visibilité en boutique.',
        ));
      } else if (variation <= -15.0 && perf.quantiteVenduePrecedente >= 3) {
        final diffQte = perf.quantiteVendue - perf.quantiteVenduePrecedente;
        final conf = perf.quantiteVenduePrecedente >= 15 ? 'Élevé' : (perf.quantiteVenduePrecedente >= 5 ? 'Modéré' : 'Indicatif');
        String conseil = 'Vérifier la visibilité du produit en rayon.';
        if (perf.stockActuel > 20 && perf.joursCouverture > 45) {
          conseil = 'Surstock avec vente en baisse : envisager une offre groupée.';
        } else if (perf.estRupture) {
          conseil = 'Baisse causée par la rupture de stock : réapprovisionner au plus vite.';
        }
        ralentissements.add(TendanceProduit(
          produit: perf,
          enProgression: false,
          variationQuantite: diffQte,
          variationPourcentage: variation,
          niveauConfiance: conf,
          conseilAction: conseil,
        ));
      }
    }

    progressions.sort((a, b) => b.variationPourcentage.compareTo(a.variationPourcentage));
    ralentissements.sort((a, b) => a.variationPourcentage.compareTo(b.variationPourcentage));

    // 7. Achats & Stocks Intelligents (Recommandations avec conditionnements)
    final recommandationsStock = _genererRecommandationsStock(
      commerce: commerce,
      performances: performanceProduits,
      perimetreId: perimetreId,
      mapContacts: mapContacts,
    );

    // 8. Produits souvent achetés ensemble (Market Basket Analysis)
    final associationsPaniers = _analyserAssociationsPaniers(
      ventes: ventesPeriode.isNotEmpty ? ventesPeriode : ventesValides,
      mapProduits: mapProduits,
    );

    // 9. Analyse Clients et Créances
    final analyseClients = _analyserClientsCredit(
      ventes: ventesValides,
      finances: finances,
      contacts: contacts,
      intervalle: intervalle,
    );

    // 10. Analyse Fournisseurs et Dettes
    final analyseFournisseurs = _analyserFournisseursDette(
      commerce: commerce,
      finances: finances,
      contacts: contacts,
      intervalle: intervalle,
    );

    // 11. Centre de Recommandations & Conseils stratégiques actionnables
    final conseils = _genererConseilsActivite(
      resume: resume,
      recommandationsStock: recommandationsStock,
      progressions: progressions,
      ralentissements: ralentissements,
      associations: associationsPaniers,
      analyseClients: analyseClients,
      analyseFournisseurs: analyseFournisseurs,
      intervalle: intervalle,
    );

    return EtatIntelligenceCommerciale(
      periode: intervalle.type,
      intervalle: intervalle,
      perimetreId: perimetreId,
      resume: resume,
      evolutionVentes: pointsEvolution,
      produitsPerformance: performanceProduits,
      produitsEnProgression: progressions,
      produitsEnRalentissement: ralentissements,
      recommandationsStock: recommandationsStock,
      associationsPaniers: associationsPaniers,
      analyseClients: analyseClients,
      analyseFournisseurs: analyseFournisseurs,
      conseilsActivite: conseils,
      dateCalcul: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // Sous-méthodes d'analyse
  // ---------------------------------------------------------------------------

  static List<PerformanceProduit> _calculerPerformancesProduits({
    required EtatCommerce commerce,
    required List<Vente> ventesPeriode,
    required List<Vente> ventesPrecedentes,
    required Map<String, Produit> mapProduits,
    required IntervallePeriode intervalle,
    String? perimetreId,
  }) {
    final caParProduit = <String, int>{};
    final qteParProduit = <String, double>{};
    final margeParProduit = <String, int>{};
    final aMargeParProduit = <String, bool>{};

    for (final v in ventesPeriode) {
      for (final l in v.lignes) {
        caParProduit[l.produitId] = (caParProduit[l.produitId] ?? 0) + l.montant;
        qteParProduit[l.produitId] = (qteParProduit[l.produitId] ?? 0.0) + l.quantiteBase.valeur;

        final p = mapProduits[l.produitId];
        final pAchat = p?.prixAchat;
        if (pAchat != null && pAchat > 0) {
          final marge = l.montant - (l.quantiteBase.valeur * pAchat).round();
          margeParProduit[l.produitId] = (margeParProduit[l.produitId] ?? 0) + marge;
          aMargeParProduit[l.produitId] = true;
        } else {
          aMargeParProduit[l.produitId] = false;
        }
      }
    }

    final caPrecParProduit = <String, int>{};
    final qtePrecParProduit = <String, double>{};
    for (final v in ventesPrecedentes) {
      for (final l in v.lignes) {
        caPrecParProduit[l.produitId] = (caPrecParProduit[l.produitId] ?? 0) + l.montant;
        qtePrecParProduit[l.produitId] = (qtePrecParProduit[l.produitId] ?? 0.0) + l.quantiteBase.valeur;
      }
    }

    final nbJours = intervalle.dureeJours;
    final perimetres = perimetreId != null ? [perimetreId] : commerce.stocks.map((s) => s.perimetreId).toSet();

    final resultats = <PerformanceProduit>[];

    for (final p in commerce.produitsActifs) {
      final ca = caParProduit[p.id] ?? 0;
      final qte = qteParProduit[p.id] ?? 0.0;
      final caPrec = caPrecParProduit[p.id] ?? 0;
      final qtePrec = qtePrecParProduit[p.id] ?? 0.0;

      // Si le produit n'a jamais été vendu ni sur la période ni sur la précédente,
      // mais qu'il est en stock, on l'inclut pour surveiller la rotation
      final stockQte = commerce.quantite(p.id, perimetres).valeur;
      if (ca == 0 && caPrec == 0 && stockQte <= 0) continue;

      final vitesseJour = nbJours > 0 ? (qte / nbJours) : 0.0;
      final joursCouverture = vitesseJour > 0.0001 ? (stockQte / vitesseJour) : (stockQte > 0 ? 999.0 : 0.0);

      double? variationQte;
      if (qtePrec > 0) {
        variationQte = ((qte - qtePrec) / qtePrec) * 100;
      }

      final marge = margeParProduit[p.id];
      final aMarge = aMargeParProduit[p.id] == true;
      double? margePct;
      if (aMarge && marge != null && ca > 0) {
        margePct = (marge / ca) * 100;
      }

      resultats.add(PerformanceProduit(
        produitId: p.id,
        nom: p.nom,
        code: p.reference ?? p.codeBarres,
        photoUrl: p.photoPrincipale,
        unite: p.uniteBase,
        quantiteVendue: qte,
        quantiteVenduePrecedente: qtePrec,
        chiffreAffaires: ca,
        chiffreAffairesPrecedent: caPrec,
        margeBrute: marge,
        margePourcentage: margePct,
        vitesseVenteJour: vitesseJour,
        stockActuel: stockQte,
        joursCouverture: joursCouverture,
        variationQuantitePct: variationQte,
        aMargeFiable: aMarge,
        prixAchatRef: p.prixAchat,
        prixVenteMoyen: qte > 0 ? (ca / qte).round() : p.prixDetail,
      ));
    }

    resultats.sort((a, b) => b.chiffreAffaires.compareTo(a.chiffreAffaires));
    return resultats;
  }

  static List<PointEvolutionVente> _genererSerieEvolution({
    required List<Vente> ventesActuelles,
    required List<Vente> ventesPrecedentes,
    required IntervallePeriode intervalle,
    required Map<String, Produit> mapProduits,
  }) {
    final points = <PointEvolutionVente>[];
    final type = intervalle.type;

    if (type == PeriodeAnalyseType.aujourdhui || type == PeriodeAnalyseType.hier) {
      // Regroupement par créneau de 2 heures (0h..22h)
      for (var h = 6; h <= 22; h += 2) {
        final label = '${h}h';
        final ventesCreneau = ventesActuelles.where((v) => v.date.hour >= h && v.date.hour < h + 2);
        final ventesPrecCreneau = ventesPrecedentes.where((v) => v.date.hour >= h && v.date.hour < h + 2);

        final ca = ventesCreneau.fold<int>(0, (acc, v) => acc + v.total);
        final caPrec = ventesPrecCreneau.fold<int>(0, (acc, v) => acc + v.total);
        final qte = ventesCreneau.fold<double>(
          0.0,
          (acc, v) => acc + v.lignes.fold<double>(0.0, (lAcc, l) => lAcc + l.quantiteBase.valeur),
        );

        points.add(PointEvolutionVente(
          date: DateTime(intervalle.debut.year, intervalle.debut.month, intervalle.debut.day, h),
          label: label,
          chiffreAffaires: ca,
          chiffreAffairesPrecedent: caPrec,
          quantite: qte,
        ));
      }
    } else {
      // Regroupement par jour
      final nbJours = intervalle.fin.difference(intervalle.debut).inDays + 1;

      for (var i = 0; i < nbJours; i++) {
        final dateJour = intervalle.debut.add(Duration(days: i));
        final jourMin = DateTime(dateJour.year, dateJour.month, dateJour.day);
        final jourMax = DateTime(dateJour.year, dateJour.month, dateJour.day, 23, 59, 59, 999);

        // Date équivalente dans la période précédente
        final dateJourPrec = intervalle.debutPrecedent.add(Duration(days: i));
        final jourPrecMin = DateTime(dateJourPrec.year, dateJourPrec.month, dateJourPrec.day);
        final jourPrecMax = DateTime(dateJourPrec.year, dateJourPrec.month, dateJourPrec.day, 23, 59, 59, 999);

        final ventesJour = ventesActuelles.where((v) => v.date.isAfter(jourMin) && v.date.isBefore(jourMax));
        final ventesJourPrec =
            ventesPrecedentes.where((v) => v.date.isAfter(jourPrecMin) && v.date.isBefore(jourPrecMax));

        final ca = ventesJour.fold<int>(0, (acc, v) => acc + v.total);
        final caPrec = ventesJourPrec.fold<int>(0, (acc, v) => acc + v.total);
        final qte = ventesJour.fold<double>(
          0.0,
          (acc, v) => acc + v.lignes.fold<double>(0.0, (lAcc, l) => lAcc + l.quantiteBase.valeur),
        );

        final label = nbJours > 14
            ? '${dateJour.day.toString().padLeft(2, '0')}/${dateJour.month.toString().padLeft(2, '0')}'
            : '${_nomJour(dateJour.weekday)} ${dateJour.day}';

        points.add(PointEvolutionVente(
          date: jourMin,
          label: label,
          chiffreAffaires: ca,
          chiffreAffairesPrecedent: caPrec,
          quantite: qte,
        ));
      }
    }

    return points;
  }

  static String _nomJour(int weekday) => switch (weekday) {
        DateTime.monday => 'Lun',
        DateTime.tuesday => 'Mar',
        DateTime.wednesday => 'Mer',
        DateTime.thursday => 'Jeu',
        DateTime.friday => 'Ven',
        DateTime.saturday => 'Sam',
        DateTime.sunday => 'Dim',
        _ => '',
      };

  static List<RecommandationStock> _genererRecommandationsStock({
    required EtatCommerce commerce,
    required List<PerformanceProduit> performances,
    required Map<String, Contact> mapContacts,
    String? perimetreId,
  }) {
    final recommandations = <RecommandationStock>[];

    for (final perf in performances) {
      final p = commerce.produit(perf.produitId);
      if (p == null || !p.estActif) continue;

      final vitesse = perf.vitesseVenteJour;
      final stockActuel = perf.stockActuel;

      // Délai approvisionnement estimé : par défaut 4 jours
      const delaiAppro = 4;
      // Couverture cible : 14 jours de vente (2 semaines)
      const horizonCouvertureJours = 14;

      // Stock de sécurité = vitesse * délai * 1.5
      final stockSecurite = (vitesse * delaiAppro * 1.5);
      final seuilReappro = stockSecurite + (vitesse * delaiAppro);

      // Si le stock actuel passe sous le seuil de réapprovisionnement ou est en rupture
      final estEnRupture = stockActuel <= 0 && vitesse > 0;
      final estFaible = stockActuel <= seuilReappro && vitesse > 0;
      final aSeuilFixe = p.seuilAlerte.estPositif && stockActuel <= p.seuilAlerte.valeur;

      if (estEnRupture || estFaible || aSeuilFixe) {
        // Choix de la meilleure unité de commande (carton, sac, etc.)
        final uniteCommande = p.plusGrandeUnite;
        final facteurUnite = uniteCommande.facteur.valeur;

        // Quantité brute recommandée en unité de base pour atteindre l'horizon cible
        final besoinBase = math.max(0.0, (vitesse * horizonCouvertureJours) + stockSecurite - stockActuel);
        // Conversion en unité de conditionnement supérieure (arrondi au carton supérieur)
        final nbLots = (besoinBase / facteurUnite).ceil().clamp(1, 10000);
        final qteRecommandeeBase = nbLots * facteurUnite;

        // Niveau d'urgence
        PrioriteConseil urgence;
        if (estEnRupture || perf.joursCouverture <= 2) {
          urgence = PrioriteConseil.urgent;
        } else if (perf.joursCouverture <= delaiAppro + 2) {
          urgence = PrioriteConseil.important;
        } else {
          urgence = PrioriteConseil.surveiller;
        }

        // Raisonnement explicite
        String raisonnement;
        if (estEnRupture) {
          raisonnement = 'Rupture constatée. À votre rythme de vente (${vitesse.toStringAsFixed(1)} ${p.uniteBase}/jour), '
              'commandez $nbLots ${uniteCommande.nom} pour couvrir les $horizonCouvertureJours prochains jours.';
        } else {
          final jRestants = perf.joursCouverture.toStringAsFixed(0);
          raisonnement = 'Stock estimé pour $jRestants jour(s). '
              'Avec un délai de réapprovisionnement de $delaiAppro jours, commandez $nbLots ${uniteCommande.nom} pour éviter la rupture.';
        }

        final fournisseur = p.fournisseurId != null ? mapContacts[p.fournisseurId] : null;
        final estimationCout = p.prixAchat != null ? (qteRecommandeeBase * p.prixAchat!).round() : null;

        recommandations.add(RecommandationStock(
          produitId: p.id,
          nom: p.nom,
          photoUrl: p.photoPrincipale,
          uniteBase: p.uniteBase,
          uniteCommande: uniteCommande.nom,
          facteurUniteCommande: facteurUnite,
          stockActuel: stockActuel,
          vitesseVenteJour: vitesse,
          delaiApproJours: delaiAppro,
          joursCouverture: perf.joursCouverture,
          stockSecurite: stockSecurite,
          quantiteRecommandee: qteRecommandeeBase,
          quantiteRecommandeeEnUniteCommande: nbLots,
          raisonnement: raisonnement,
          urgence: urgence,
          fournisseurId: p.fournisseurId,
          fournisseurNom: fournisseur?.nom,
          estimationCout: estimationCout,
        ));
      }
    }

    recommandations.sort((a, b) => a.urgence.index.compareTo(b.urgence.index));
    return recommandations;
  }

  static List<AssociationProduits> _analyserAssociationsPaniers({
    required List<Vente> ventes,
    required Map<String, Produit> mapProduits,
  }) {
    final ticketsValides = ventes.where((v) => !v.annulee && v.lignes.length >= 2).toList();
    if (ticketsValides.length < 5) return const [];

    final totalTickets = ticketsValides.length;
    final comptePaires = <String, int>{};
    final compteIndividuel = <String, int>{};

    for (final v in ticketsValides) {
      final produitsDistincts = v.lignes.map((l) => l.produitId).toSet().toList();
      for (final pid in produitsDistincts) {
        compteIndividuel[pid] = (compteIndividuel[pid] ?? 0) + 1;
      }
      for (var i = 0; i < produitsDistincts.length; i++) {
        for (var j = i + 1; j < produitsDistincts.length; j++) {
          final pA = produitsDistincts[i];
          final pB = produitsDistincts[j];
          final clePaire = pA.compareTo(pB) < 0 ? '$pA|$pB' : '$pB|$pA';
          comptePaires[clePaire] = (comptePaires[clePaire] ?? 0) + 1;
        }
      }
    }

    final associations = <AssociationProduits>[];

    comptePaires.forEach((cle, freq) {
      if (freq >= 2) {
        final parts = cle.split('|');
        final idA = parts[0];
        final idB = parts[1];
        final pA = mapProduits[idA];
        final pB = mapProduits[idB];
        if (pA == null || pB == null) return;

        final occA = compteIndividuel[idA] ?? 1;
        final occB = compteIndividuel[idB] ?? 1;
        final maxOcc = math.max(occA, occB);

        final frequencePct = (freq / totalTickets) * 100;
        final confiancePct = (freq / maxOcc) * 100;

        if (confiancePct >= 20.0) {
          associations.add(AssociationProduits(
            produitAId: idA,
            nomA: pA.nom,
            produitBId: idB,
            nomB: pB.nom,
            nombreTicketsEnsemble: freq,
            frequenceAssociationPct: frequencePct,
            indiceConfiancePct: confiancePct,
            suggestion: 'Achetés ensemble dans ${confiancePct.toStringAsFixed(0)}% des paniers. '
                'Positionnez-les à proximité en boutique ou proposez un pack promotionnel.',
          ));
        }
      }
    });

    associations.sort((a, b) => b.nombreTicketsEnsemble.compareTo(a.nombreTicketsEnsemble));
    return associations.take(10).toList();
  }

  static List<AnalyseClientCredit> _analyserClientsCredit({
    required List<Vente> ventes,
    required EtatFinances finances,
    required List<Contact> contacts,
    required IntervallePeriode intervalle,
  }) {
    final mapClients = {for (final c in contacts) c.id: c};

    // Ventes par client
    final caParClient = <String, int>{};
    final nbAchatsParClient = <String, int>{};

    for (final v in ventes) {
      if (v.annulee || v.contactId == null) continue;
      caParClient[v.contactId!] = (caParClient[v.contactId!] ?? 0) + v.total;
      nbAchatsParClient[v.contactId!] = (nbAchatsParClient[v.contactId!] ?? 0) + 1;
    }

    // Créances issues de finances (suivis effectifs)
    final creances = finances.suivis.where(
      (s) => s.engagement.sens == SensEngagement.aRecevoir && !s.engagement.annule && s.reste > 0,
    ).toList();
    final creanceRestanteParClient = <String, int>{};
    final creanceEchueParClient = <String, int>{};
    final retardMaxParClient = <String, int>{};

    final refDate = intervalle.fin;
    for (final s in creances) {
      final cid = s.engagement.contactId;
      if (cid == null) continue;
      final restant = s.reste;
      creanceRestanteParClient[cid] = (creanceRestanteParClient[cid] ?? 0) + restant;

      final echeance = s.engagement.echeance;
      if (echeance != null && echeance.isBefore(refDate)) {
        creanceEchueParClient[cid] = (creanceEchueParClient[cid] ?? 0) + restant;
        final joursRetard = refDate.difference(echeance).inDays;
        final maxActuel = retardMaxParClient[cid] ?? 0;
        if (joursRetard > maxActuel) {
          retardMaxParClient[cid] = joursRetard;
        }
      }
    }

    final analyses = <AnalyseClientCredit>[];
    final allClientIds = {...caParClient.keys, ...creanceRestanteParClient.keys};

    for (final cid in allClientIds) {
      final c = mapClients[cid];
      if (c == null) continue;

      final ca = caParClient[cid] ?? 0;
      final nb = nbAchatsParClient[cid] ?? 0;
      final restant = creanceRestanteParClient[cid] ?? 0;
      final echu = creanceEchueParClient[cid] ?? 0;
      final retard = retardMaxParClient[cid] ?? 0;

      String risque = 'Faible';
      if (retard > 30 || (echu > 0 && echu >= restant * 0.7)) {
        risque = 'Critique';
      } else if (retard > 7 || echu > 0) {
        risque = 'Moyen';
      }

      analyses.add(AnalyseClientCredit(
        contactId: cid,
        nomClient: c.nomAffiche,
        telephone: c.telephone,
        chiffreAffaires: ca,
        nombreAchats: nb,
        creanceRestante: restant,
        creanceEchue: echu,
        joursRetardMax: retard,
        niveauRisque: risque,
      ));
    }

    analyses.sort((a, b) {
      // Priorité aux créances échues et plus gros CA
      if (b.creanceEchue != a.creanceEchue) {
        return b.creanceEchue.compareTo(a.creanceEchue);
      }
      return b.chiffreAffaires.compareTo(a.chiffreAffaires);
    });

    return analyses;
  }

  static List<AnalyseFournisseurDette> _analyserFournisseursDette({
    required EtatCommerce commerce,
    required EtatFinances finances,
    required List<Contact> contacts,
    required IntervallePeriode intervalle,
  }) {
    final mapFournisseurs = {for (final f in contacts) f.id: f};

    final totalAchatsParFournisseur = <String, int>{};
    final produitsParFournisseur = <String, Set<String>>{};

    for (final a in commerce.achats) {
      if (a.fournisseurId == null || a.statut == StatutAchat.annule) continue;
      final fid = a.fournisseurId!;
      totalAchatsParFournisseur[fid] = (totalAchatsParFournisseur[fid] ?? 0) + a.total;

      for (final l in a.lignes) {
        final p = commerce.produit(l.produitId);
        if (p != null) {
          (produitsParFournisseur[fid] ??= {}).add(p.nom);
        }
      }
    }

    // Dettes fournisseurs (SensEngagement.aPayer)
    final dettes = finances.suivis.where(
      (s) => s.engagement.sens == SensEngagement.aPayer && !s.engagement.annule && s.reste > 0,
    ).toList();
    final detteRestanteParFournisseur = <String, int>{};
    final detteEchueParFournisseur = <String, int>{};
    final prochaineEcheanceParFournisseur = <String, DateTime>{};

    final refDate = intervalle.fin;
    for (final s in dettes) {
      final fid = s.engagement.contactId;
      if (fid == null) continue;
      final restant = s.reste;
      detteRestanteParFournisseur[fid] = (detteRestanteParFournisseur[fid] ?? 0) + restant;

      final echeance = s.engagement.echeance;
      if (echeance != null) {
        if (echeance.isBefore(refDate)) {
          detteEchueParFournisseur[fid] = (detteEchueParFournisseur[fid] ?? 0) + restant;
        } else {
          final actuelle = prochaineEcheanceParFournisseur[fid];
          if (actuelle == null || echeance.isBefore(actuelle)) {
            prochaineEcheanceParFournisseur[fid] = echeance;
          }
        }
      }
    }

    final analyses = <AnalyseFournisseurDette>[];
    final allFids = {...totalAchatsParFournisseur.keys, ...detteRestanteParFournisseur.keys};

    for (final fid in allFids) {
      final f = mapFournisseurs[fid];
      if (f == null) continue;

      final totalA = totalAchatsParFournisseur[fid] ?? 0;
      final dette = detteRestanteParFournisseur[fid] ?? 0;
      final echue = detteEchueParFournisseur[fid] ?? 0;
      final montantPaye = math.max(0, totalA - dette);

      analyses.add(AnalyseFournisseurDette(
        fournisseurId: fid,
        nomFournisseur: f.nomAffiche,
        telephone: f.telephone,
        totalAchats: totalA,
        montantPaye: montantPaye,
        detteRestante: dette,
        detteEchue: echue,
        prochaineEcheance: prochaineEcheanceParFournisseur[fid],
        produitsPrincipaux: (produitsParFournisseur[fid] ?? {}).take(3).toList(),
      ));
    }

    analyses.sort((a, b) => b.detteRestante.compareTo(a.detteRestante));
    return analyses;
  }

  static List<ConseilActiviteCommerciale> _genererConseilsActivite({
    required ResumeIntelligenceCommerciale resume,
    required List<RecommandationStock> recommandationsStock,
    required List<TendanceProduit> progressions,
    required List<TendanceProduit> ralentissements,
    required List<AssociationProduits> associations,
    required List<AnalyseClientCredit> analyseClients,
    required List<AnalyseFournisseurDette> analyseFournisseurs,
    required IntervallePeriode intervalle,
  }) {
    final conseils = <ConseilActiviteCommerciale>[];

    // 1. Alertes Ruptures et Réapprovisionnement urgent
    final ruptures = recommandationsStock.where((r) => r.urgence == PrioriteConseil.urgent).toList();
    if (ruptures.isNotEmpty) {
      final topRupture = ruptures.first;
      conseils.add(ConseilActiviteCommerciale(
        id: 'rupture-${topRupture.produitId}',
        priorite: PrioriteConseil.urgent,
        titre: 'Risque de rupture critique : ${topRupture.nom}',
        constat: topRupture.raisonnement,
        justification: 'Vitesse de vente de ${topRupture.vitesseVenteJour.toStringAsFixed(1)}/jour pour un stock de ${topRupture.stockActuel.toStringAsFixed(0)}.',
        periode: intervalle.type.libelle,
        niveauConfiance: 'Élevé',
        actionSuggeree: 'Commander ${topRupture.quantiteRecommandeeEnUniteCommande} ${topRupture.uniteCommande} dès aujourd’hui.',
        routeCible: '/commerce/achats/new?produit=${topRupture.produitId}',
        boutonActionTitre: 'Préparer commande',
        produitId: topRupture.produitId,
      ));
    }

    // 2. Alertes Créances clients échues
    final clientsEnRetard = analyseClients.where((c) => c.creanceEchue > 0).toList();
    if (clientsEnRetard.isNotEmpty) {
      final pireClient = clientsEnRetard.first;
      conseils.add(ConseilActiviteCommerciale(
        id: 'creance-${pireClient.contactId}',
        priorite: PrioriteConseil.important,
        titre: 'Créance échue : ${pireClient.nomClient}',
        constat: 'Créance de ${pireClient.creanceEchue} F CFA arrivée à échéance (retard de ${pireClient.joursRetardMax} jours).',
        justification: 'Le recouvrement rapide évite les pertes sèches et préserve votre trésorerie.',
        periode: 'Échéances en retard',
        niveauConfiance: 'Certifié',
        actionSuggeree: 'Contacter ${pireClient.nomClient} pour convenir d’un versement.',
        routeCible: '/contacts/${pireClient.contactId}',
        boutonActionTitre: 'Voir fiche client',
        contactId: pireClient.contactId,
      ));
    }

    // 3. Dettes fournisseurs arrivant à échéance
    final dettesEchues = analyseFournisseurs.where((f) => f.detteEchue > 0).toList();
    if (dettesEchues.isNotEmpty) {
      final topFournisseur = dettesEchues.first;
      conseils.add(ConseilActiviteCommerciale(
        id: 'dette-${topFournisseur.fournisseurId}',
        priorite: PrioriteConseil.important,
        titre: 'Dette échue envers ${topFournisseur.nomFournisseur}',
        constat: 'Montant impayé de ${topFournisseur.detteEchue} F CFA envers ce fournisseur.',
        justification: 'Le respect des échéances garantit la fidélité de vos fournisseurs et vos remises.',
        periode: 'Échéances fournisseurs',
        niveauConfiance: 'Certifié',
        actionSuggeree: 'Régler la dette ou planifier un échéancier partiel.',
        routeCible: '/contacts/${topFournisseur.fournisseurId}',
        boutonActionTitre: 'Consulter fournisseur',
        contactId: topFournisseur.fournisseurId,
      ));
    }

    // 4. Opportunité Cross-selling (Paniers associés)
    if (associations.isNotEmpty) {
      final topAssoc = associations.first;
      conseils.add(ConseilActiviteCommerciale(
        id: 'assoc-${topAssoc.produitAId}-${topAssoc.produitBId}',
        priorite: PrioriteConseil.opportunite,
        titre: 'Ventes complémentaires détectées',
        constat: 'Les clients achètent fréquemment « ${topAssoc.nomA} » avec « ${topAssoc.nomB} » (${topAssoc.nombreTicketsEnsemble} tickets).',
        justification: 'Taux d’association de ${topAssoc.indiceConfiancePct.toStringAsFixed(0)}% sur vos tickets de vente.',
        periode: intervalle.type.libelle,
        niveauConfiance: 'Élevé',
        actionSuggeree: topAssoc.suggestion,
        routeCible: '/commerce/produits',
        boutonActionTitre: 'Voir catalogue',
      ));
    }

    // 5. Ralentissement produit nécessitant action
    if (ralentissements.isNotEmpty) {
      final topRalenti = ralentissements.first;
      conseils.add(ConseilActiviteCommerciale(
        id: 'ralenti-${topRalenti.produit.produitId}',
        priorite: PrioriteConseil.surveiller,
        titre: 'Ralentissement : ${topRalenti.produit.nom}',
        constat: 'Baisse de ${topRalenti.variationPourcentage.abs().toStringAsFixed(0)}% des ventes comparé à la période précédente.',
        justification: 'Stock actuel de ${topRalenti.produit.stockActuel.toStringAsFixed(0)} ${topRalenti.produit.unite} couvrant ${topRalenti.produit.joursCouverture.toStringAsFixed(0)} jours.',
        periode: intervalle.type.libelle,
        niveauConfiance: topRalenti.niveauConfiance,
        actionSuggeree: topRalenti.conseilAction,
        routeCible: '/commerce/produits/${topRalenti.produit.produitId}',
        boutonActionTitre: 'Détail produit',
        produitId: topRalenti.produit.produitId,
      ));
    }

    // 6. Croissance positive / Moteur de vente
    if (progressions.isNotEmpty) {
      final topProg = progressions.first;
      conseils.add(ConseilActiviteCommerciale(
        id: 'prog-${topProg.produit.produitId}',
        priorite: PrioriteConseil.opportunite,
        titre: 'Forte progression : ${topProg.produit.nom}',
        constat: 'Ventes en hausse de +${topProg.variationPourcentage.toStringAsFixed(0)}% sur la période sélectionnée.',
        justification: 'Quantité vendue passée à ${topProg.produit.quantiteVendue.toStringAsFixed(0)} ${topProg.produit.unite}.',
        periode: intervalle.type.libelle,
        niveauConfiance: topProg.niveauConfiance,
        actionSuggeree: topProg.conseilAction,
        routeCible: '/commerce/produits/${topProg.produit.produitId}',
        boutonActionTitre: 'Fiche produit',
        produitId: topProg.produit.produitId,
      ));
    }

    return conseils;
  }
}
