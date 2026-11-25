import '../../../../core/sync/sync_models.dart';
import '../../../../core/utils/recherche.dart';
import '../entities/commerce.dart';

/// Photographie des données Commerce sur l'appareil : catalogue, stock
/// serveur, opérations locales. Le stock affiché = stock du serveur +
/// mouvements locaux pas encore pris en compte.
class EtatCommerce {
  EtatCommerce({
    this.categories = const [],
    this.produits = const [],
    this.stocks = const [],
    this.lots = const [],
    this.mouvements = const [],
    this.transferts = const [],
    this.achats = const [],
    this.receptions = const [],
    this.ventes = const [],
  }) {
    final produitsAvecStock = <(String, String)>{};
    for (final s in stocks) {
      final cle = (s.produitId, s.perimetreId);
      final existant = (_serveur[s.produitId] ??= {})[s.perimetreId];
      if (existant == null) {
        _serveur[s.produitId]![s.perimetreId] = s.quantite;
      }
      produitsAvecStock.add(cle);
    }

    final ventesAnnulees = {for (final v in ventes) if (v.annulee) v.id};
    final achatsAnnules = {for (final a in achats) if (a.annule) a.id};

    for (final m in mouvements) {
      if (m.origineType == 'VENTE' && ventesAnnulees.contains(m.origineId)) continue;
      if (m.origineType == 'ACHAT' && achatsAnnules.contains(m.origineId)) continue;
      if (m.refuse && m.origineType != 'VENTE' && m.origineType != 'ACHAT') continue;
      final cle = (m.produitId, m.perimetreId);
      final hasServerStock = produitsAvecStock.contains(cle);
      if (hasServerStock && m.syncStatus == RecordSyncStatus.synced) continue;
      final parBoutique = _attente[m.produitId] ??= {};
      parBoutique[m.perimetreId] = (parBoutique[m.perimetreId] ?? Qte.zero) + m.delta;
    }
    for (final p in produits) {
      _produits[p.id] = p;
    }
    for (final c in categories) {
      _categories[c.id] = c;
    }
  }

  final List<CategorieProduit> categories;
  final List<Produit> produits;
  final List<StockBoutique> stocks;
  final List<LotStock> lots;
  final List<MouvementStock> mouvements;
  final List<Transfert> transferts;
  final List<Achat> achats;
  final List<Reception> receptions;
  final List<Vente> ventes;

  final _serveur = <String, Map<String, Qte>>{};
  final _attente = <String, Map<String, Qte>>{};
  final _produits = <String, Produit>{};
  final _categories = <String, CategorieProduit>{};

  Produit? produit(String id) => _produits[id];
  CategorieProduit? categorie(String? id) => id == null ? null : _categories[id];

  List<Produit> get produitsActifs => [for (final p in produits) if (p.estActif) p];

  /// Produits actifs visibles pour une boutique (global ou réservé à cette boutique).
  List<Produit> produitsActifsPour(String? boutiqueId) =>
      [for (final p in produitsActifs) if (p.estVisibleDansBoutique(boutiqueId)) p];

  List<CategorieProduit> get categoriesRacines =>
      [for (final c in categories) if (c.estRacine && c.estActive) c];

  List<CategorieProduit> sousCategories(String parentId) =>
      [for (final c in categories) if (c.parentId == parentId && c.estActive) c];

  /// La catégorie racine d'une catégorie (elle-même si racine).
  CategorieProduit? racine(String? categorieId) {
    final c = categorie(categorieId);
    return c == null || c.estRacine ? c : categorie(c.parentId);
  }

  /// Produits d'une catégorie, sous-catégories comprises.
  bool dansCategorie(Produit p, String categorieId) =>
      p.categorieId == categorieId || categorie(p.categorieId)?.parentId == categorieId;

  int nombreProduits(String categorieId) => produitsActifs.where((p) => dansCategorie(p, categorieId)).length;

  // --- Quantités --------------------------------------------------------------

  /// Quantité dans une boutique (unité de base).
  Qte quantiteBoutique(String produitId, String perimetreId) =>
      (_serveur[produitId]?[perimetreId] ?? Qte.zero) + (_attente[produitId]?[perimetreId] ?? Qte.zero);

  /// Quantité sur les boutiques visibles (ou toutes si non spécifié).
  Qte quantite(String produitId, [Iterable<String>? boutiques]) {
    if (boutiques == null) {
      final s = _serveur[produitId]?.values.somme ?? Qte.zero;
      final a = _attente[produitId]?.values.somme ?? Qte.zero;
      return s + a;
    }
    return boutiques.map((b) => quantiteBoutique(produitId, b)).somme;
  }

  // --- Lots de stock ---------------------------------------------------------

  LotStock? lot(String id) => lots.where((l) => l.id == id).firstOrNull;

  /// Lots rattachés à un produit, filtrés optionnellement par boutiques visibles.
  List<LotStock> lotsDe(String produitId, [Iterable<String>? boutiquesVisibles]) {
    final ensemble = (boutiquesVisibles == null || boutiquesVisibles.isEmpty)
        ? null
        : boutiquesVisibles.toSet();
    final list = [
      for (final l in lots)
        if (l.produitId == produitId && (ensemble == null || ensemble.contains(l.perimetreId)))
          l,
    ];
    // Rétrocompatibilité et robustesse : si un produit dispose de stock physique dans une boutique
    // sans lot formalisé dans la table (ex: ancien stock avant migration ou ajustement direct),
    // on synthétise automatiquement un lot disponible pour garantir l'affichage et la traçabilité.
    final p = _produits[produitId];
    if (p != null) {
      final perimetresStock = <String>{
        ...?_serveur[produitId]?.keys,
        ...?_attente[produitId]?.keys,
      };
      for (final bId in perimetresStock) {
        if (ensemble != null && !ensemble.contains(bId)) continue;
        final qteBoutique = quantiteBoutique(produitId, bId);
        if (qteBoutique.estPositif) {
          final aDejaLotActif = list.any((l) => l.perimetreId == bId && l.quantiteRestante.estPositif);
          if (!aDejaLotActif) {
            final sansTiret = bId.replaceAll('-', '');
            final courtId = sansTiret.substring(0, sansTiret.length.clamp(0, 4)).toUpperCase();
            list.add(
              LotStock(
                id: 'lot-auto-$produitId-$bId',
                entrepriseId: p.entrepriseId,
                perimetreId: bId,
                produitId: produitId,
                reference: 'LOT-${courtId.isEmpty ? '01' : courtId}',
                dateAchat: DateTime(2026, 1, 1),
                dateReception: DateTime(2026, 1, 1),
                quantiteInitiale: qteBoutique,
                quantiteRestante: qteBoutique,
                prixAchatUnitaire: p.prixAchat ?? 0,
                prixVenteUnitaire: p.prixDetail,
                statut: StatutLotStock.actif,
              ),
            );
          }
        }
      }
    }
    list.sort((a, b) => b.dateReception.compareTo(a.dateReception));
    return list;
  }

  /// Lots disponibles dans une boutique donnée, triés selon la méthode FIFO (les plus anciens d'abord).
  List<LotStock> lotsDisponibles(String produitId, String perimetreId) {
    final dispo = [
      for (final l in lotsDe(produitId, [perimetreId]))
        if (l.perimetreId == perimetreId && l.estDisponible)
          l,
    ];
    dispo.sort((a, b) {
      final c1 = a.dateReception.compareTo(b.dateReception);
      if (c1 != 0) return c1;
      final c2 = a.dateAchat.compareTo(b.dateAchat);
      if (c2 != 0) return c2;
      return a.id.compareTo(b.id);
    });
    return dispo;
  }

  /// Quantité cumulée restante dans tous les lots disponibles.
  Qte quantiteLots(String produitId, [Iterable<String>? boutiquesVisibles]) =>
      lotsDe(produitId, boutiquesVisibles).where((l) => l.estDisponible).map((l) => l.quantiteRestante).somme;

  /// Coût moyen pondéré unitaire (FCFA) des lots restants pour un produit.
  int? coutMoyenPondere(String produitId, [String? perimetreId]) {
    final cibles = lots.where((l) =>
        l.produitId == produitId &&
        l.estDisponible &&
        (perimetreId == null || l.perimetreId == perimetreId)).toList();
    if (cibles.isEmpty) return produit(produitId)?.prixAchat;
    final totalQte = cibles.map((l) => l.quantiteRestante).somme;
    if (totalQte <= Qte.zero) return produit(produitId)?.prixAchat;
    final totalCout = cibles.fold(0, (s, l) => s + l.quantiteRestante.montant(l.prixAchatUnitaire));
    return (totalCout * Qte.echelle / totalQte.brut).round();
  }

  /// Répartition par boutique (boutiques visibles seulement où le produit est autorisé).
  Map<String, Qte> repartition(String produitId, Iterable<String> boutiques) {
    final p = _produits[produitId];
    return {
      for (final b in boutiques)
        if (p == null || p.estVisibleDansBoutique(b)) b: quantiteBoutique(produitId, b),
    };
  }

  /// Le produit a-t-il déjà eu du stock dans ces boutiques ?
  bool suiviDans(String produitId, Iterable<String> boutiques) => boutiques.any(
      (b) => _serveur[produitId]?.containsKey(b) == true || _attente[produitId]?.containsKey(b) == true);

  StatutStock statut(Produit p, Qte quantite) {
    if (quantite <= Qte.zero) return StatutStock.rupture;
    if (p.seuilAlerte.estPositif && quantite <= p.seuilAlerte) return StatutStock.faible;
    return StatutStock.enStock;
  }

  StatutStock statutDans(Produit p, Iterable<String> boutiques) => statut(p, quantite(p.id, boutiques));

  /// Produits qui demandent une action (stock faible ou rupture), les ruptures d'abord.
  List<Produit> aSurveiller(Iterable<String> boutiques) {
    final ensemble = boutiques.toSet();
    final liste = [
      for (final p in produitsActifs)
        if ((ensemble.isEmpty || ensemble.any(p.estVisibleDansBoutique)) &&
            statutDans(p, boutiques) != StatutStock.enStock)
          p,
    ];
    liste.sort((a, b) => statutDans(b, boutiques).index.compareTo(statutDans(a, boutiques).index));
    return liste;
  }

  ResumeStock resume(Iterable<String> boutiques) {
    var faibles = 0;
    var ruptures = 0;
    var valeurStock = 0;
    var totalArticles = 0;
    final ensemble = boutiques.toSet();
    final actifs = [
      for (final p in produitsActifs)
        if (ensemble.isEmpty || ensemble.any(p.estVisibleDansBoutique)) p,
    ];
    for (final p in actifs) {
      final qte = quantite(p.id, boutiques);
      switch (statutDans(p, boutiques)) {
        case StatutStock.faible:
          faibles++;
        case StatutStock.rupture:
          ruptures++;
        case StatutStock.enStock:
          break;
      }
      if (qte.estPositif) {
        final prixValo = p.prixAchat ?? p.prixDetail;
        valeurStock += (qte.valeur * prixValo).round();
        totalArticles += qte.valeur.round();
      }
    }
    final aujourdhui = DateTime.now();
    final debut = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day);
    var entrees = 0;
    var sorties = 0;
    for (final m in mouvements) {
      if (m.refuse || !ensemble.contains(m.perimetreId) || m.date.isBefore(debut)) continue;
      if (m.delta.estPositif) {
        entrees++;
      } else if (m.delta.estNegatif) {
        sorties++;
      }
    }
    return ResumeStock(
      produits: actifs.length,
      faibles: faibles,
      ruptures: ruptures,
      mouvementsDuJour: entrees + sorties,
      valeurStock: valeurStock,
      entreesDuJour: entrees,
      sortiesDuJour: sorties,
      totalArticlesEnStock: totalArticles,
    );
  }

  // --- Recherche --------------------------------------------------------------

  /// Recherche tolérante : nom, référence, code-barres, marque, catégorie, filtrée par boutique.
  List<Produit> rechercher(String texte, {String? categorieId, String? boutiqueId, bool inclureInactifs = false}) {
    final mots = normaliserRecherche(texte).split(' ').where((m) => m.isNotEmpty).toList();
    final chiffres = texte.replaceAll(RegExp(r'\s'), '');
    return [
      for (final p in inclureInactifs ? produits : produitsActifs)
        if ((boutiqueId == null || p.estVisibleDansBoutique(boutiqueId)) &&
            (categorieId == null || dansCategorie(p, categorieId)) &&
            (mots.isEmpty ||
                (chiffres.isNotEmpty && p.codeBarres == chiffres) ||
                mots.every(cleRecherche(p).contains)))
          p,
    ]..sort((a, b) => normaliserRecherche(a.nom).compareTo(normaliserRecherche(b.nom)));
  }

  String cleRecherche(Produit p) => normaliserRecherche([
        p.nom,
        p.reference,
        p.codeBarres,
        ...p.attributs.values,
        categorie(p.categorieId)?.nom,
        racine(p.categorieId)?.nom,
      ].whereType<String>().join(' '));

  Produit? parCodeBarres(String code, {String? boutiqueId}) {
    final c = code.trim();
    if (c.isEmpty) return null;
    return produits.where((p) => p.codeBarres == c && p.estActif && (boutiqueId == null || p.estVisibleDansBoutique(boutiqueId))).firstOrNull ??
        produits.where((p) => p.reference?.toLowerCase() == c.toLowerCase() && p.estActif && (boutiqueId == null || p.estVisibleDansBoutique(boutiqueId))).firstOrNull;
  }

  // --- Mouvements -------------------------------------------------------------

  List<MouvementStock> mouvementsDe({String? produitId, Iterable<String>? boutiques}) {
    final ensemble = boutiques?.toSet();
    return [
      for (final m in mouvements)
        if ((produitId == null || m.produitId == produitId) &&
            (ensemble == null || ensemble.contains(m.perimetreId)))
          m,
    ]..sort((a, b) => b.date.compareTo(a.date));
  }

  // --- Achats -----------------------------------------------------------------

  Achat? achat(String id) => achats.where((a) => a.id == id).firstOrNull;

  List<Reception> receptionsDe(String achatId) =>
      [for (final r in receptions) if (r.achatId == achatId) r]..sort((a, b) => b.date.compareTo(a.date));

  /// Dernier prix d'achat connu d'un produit, par unité (nom → prix).
  int? dernierPrixAchat(String produitId, String unite) {
    final tries = [...achats.where((a) => !a.annule)]..sort((a, b) => b.dateAchat.compareTo(a.dateAchat));
    for (final a in tries) {
      for (final l in a.lignes) {
        if (l.produitId == produitId && l.unite == unite) return l.prixUnitaire;
      }
    }
    return null;
  }

  List<Achat> achatsDuFournisseur(String fournisseurId) =>
      [for (final a in achats) if (a.fournisseurId == fournisseurId) a]
        ..sort((a, b) => b.dateAchat.compareTo(a.dateAchat));

  /// Produits habituels d'un fournisseur : achetés chez lui ou fournisseur principal.
  List<Produit> produitsDuFournisseur(String fournisseurId) {
    final ids = <String>{
      for (final a in achatsDuFournisseur(fournisseurId))
        if (!a.annule) ...a.lignes.map((l) => l.produitId),
      for (final p in produits)
        if (p.fournisseurId == fournisseurId) p.id,
    };
    return [for (final id in ids) ?produit(id)].where((p) => p.estActif).toList();
  }

  ResumeFournisseur resumeFournisseur(String fournisseurId) {
    final liste = achatsDuFournisseur(fournisseurId).where((a) => !a.annule && !a.refuse).toList();
    return ResumeFournisseur(
      nombreAchats: liste.length,
      totalAchete: liste.fold(0, (s, a) => s + a.total),
      dernierAchat: liste.isEmpty ? null : liste.first.dateAchat,
    );
  }

  // --- Ventes -----------------------------------------------------------------

  Vente? vente(String id) => ventes.where((v) => v.id == id).firstOrNull;

  /// Produits les plus vendus (pour l'onglet « Favoris » de la caisse), filtrés par boutique.
  List<Produit> plusVendus({int limite = 12, String? boutiqueId}) {
    final compte = <String, int>{};
    for (final v in ventes) {
      if (v.annulee || v.refuse) continue;
      if (boutiqueId != null && v.perimetreId != boutiqueId) continue;
      for (final l in v.lignes) {
        compte[l.produitId] = (compte[l.produitId] ?? 0) + 1;
      }
    }
    final ids = compte.keys.toList()..sort((a, b) => compte[b]!.compareTo(compte[a]!));
    return [for (final id in ids) ?produit(id)]
        .where((p) => p.estActif && (boutiqueId == null || p.estVisibleDansBoutique(boutiqueId)))
        .take(limite)
        .toList();
  }

  /// Ventes du jour (non annulées) sur les boutiques visibles.
  int chiffreDuJour(Iterable<String> boutiques) {
    final maintenant = DateTime.now();
    final debut = DateTime(maintenant.year, maintenant.month, maintenant.day);
    final ensemble = boutiques.toSet();
    return ventes
        .where((v) => !v.annulee && !v.refuse && ensemble.contains(v.perimetreId) && !v.date.isBefore(debut))
        .fold(0, (s, v) => s + v.total);
  }

  /// Le catalogue est-il vide (premier usage) ?
  bool get catalogueVide => produits.isEmpty;

  /// Au moins un produit se vend en gros.
  bool get venteEnGros => produitsActifs.any((p) => p.venteEnGros);

  /// Un produit local pas encore accepté par le serveur.
  bool enAttente(Produit p) => p.syncStatus == RecordSyncStatus.pendingSync;
}

class ResumeStock {
  const ResumeStock({
    required this.produits,
    required this.faibles,
    required this.ruptures,
    required this.mouvementsDuJour,
    this.valeurStock = 0,
    this.entreesDuJour = 0,
    this.sortiesDuJour = 0,
    this.totalArticlesEnStock = 0,
  });

  final int produits;
  final int faibles;
  final int ruptures;
  final int mouvementsDuJour;
  final int valeurStock;
  final int entreesDuJour;
  final int sortiesDuJour;
  final int totalArticlesEnStock;
}

class ResumeFournisseur {
  const ResumeFournisseur({required this.nombreAchats, required this.totalAchete, this.dernierAchat});
  final int nombreAchats;
  final int totalAchete;
  final DateTime? dernierAchat;
}
