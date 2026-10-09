import 'package:uuid/uuid.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/permissions/access_decision.dart';
import '../../../../core/permissions/permission_codes.dart';
import '../../../../core/sync/sync_models.dart';
import '../../../entreprise/domain/entities/contexte_session.dart';
import '../../../finances/domain/entities/finances.dart' as fin;
import '../../../finances/domain/services/etat_finances.dart';
import '../../../modules/domain/entities/app_module.dart';
import '../commerce_repository.dart';
import '../entities/commerce.dart';
import '../services/etat_commerce.dart';

const _uuid = Uuid();

/// Saisie d'un achat (création ou modification d'une commande).
class SaisieAchat {
  const SaisieAchat({
    required this.perimetreId,
    required this.lignes,
    this.fournisseurId,
    this.reference,
    this.date,
    this.note,
  });

  final String perimetreId;
  final String? fournisseurId;
  final String? reference;
  final DateTime? date;
  final List<LigneOperation> lignes;
  final String? note;
}

/// Saisie d'une vente au comptoir.
class SaisieVente {
  const SaisieVente({
    required this.perimetreId,
    required this.lignes,
    this.mode = ModeVente.detail,
    this.remise = 0,
    this.reglement = ReglementVente.immediat,
    this.modePaiement = fin.ModePaiement.especes,
    this.contactId,
    this.note,
    this.acompte = 0,
  });

  final String perimetreId;
  final List<LigneOperation> lignes;
  final ModeVente mode;
  final int remise;
  final ReglementVente reglement;
  final fin.ModePaiement modePaiement;
  final String? contactId;
  final String? note;

  /// Vente à crédit : montant payé tout de suite (0 = rien).
  final int acompte;
}

/// Règles métier du Commerce, appliquées avant toute écriture locale (les
/// mêmes règles sont appliquées par le serveur, qui fait foi).
class GererCommerce {
  const GererCommerce(this._repository);
  final CommerceRepository _repository;

  // ===========================================================================
  // Catalogue
  // ===========================================================================

  Future<CategorieProduit> creerCategorie(
    ContexteSession ctx, {
    required String nom,
    String? parentId,
    String? icone,
    String? couleur,
    int ordre = 100,
  }) async {
    _verifier(_peut(ctx, ModuleCodes.commerceProduits, PermissionCodes.productsCreate));
    final c = CategorieProduit(
      id: _uuid.v4(),
      entrepriseId: ctx.entreprise!.id,
      parentId: parentId,
      nom: _nom(nom, 60),
      icone: icone,
      couleur: couleur,
      ordre: ordre,
      syncStatus: RecordSyncStatus.pendingSync,
    );
    await _repository.creerCategorie(c);
    return c;
  }

  Future<void> modifierCategorie(ContexteSession ctx, CategorieProduit avant, CategorieProduit apres) async {
    _verifier(_peut(ctx, ModuleCodes.commerceProduits, PermissionCodes.productsUpdate));
    await _repository.modifierCategorie(avant, apres.copyWith(nom: _nom(apres.nom, 60)));
  }

  /// Crée le produit et, s'il est donné, son stock de départ dans une boutique.
  Future<Produit> creerProduit(
    ContexteSession ctx,
    EtatCommerce etat,
    Produit brouillon, {
    String? perimetreId,
    Qte stockInitial = Qte.zero,
    UniteVente? uniteStock,
    String? noteStockInitial,
  }) async {
    _verifier(_peut(ctx, ModuleCodes.commerceProduits, PermissionCodes.productsCreate));
    final produit = _produitValide(etat, brouillon);
    MouvementStock? initial;
    if (stockInitial.estPositif) {
      if (perimetreId == null) throw const Failure.rule(RuleCodes.shopRequired);
      _verifier(_peut(ctx, ModuleCodes.commerceStock, PermissionCodes.stockCreate, perimetreId));
      final unite = uniteStock ?? produit.uniteDeBase;
      final base = _quantiteValide(produit, stockInitial, unite.facteur);
      initial = MouvementStock(
        id: _uuid.v4(),
        entrepriseId: produit.entrepriseId,
        perimetreId: perimetreId,
        produitId: produit.id,
        type: TypeMouvementStock.entree,
        motif: MotifMouvement.ajustement,
        quantite: base,
        quantiteSaisie: stockInitial,
        uniteSaisie: unite.nom,
        facteur: unite.facteur,
        delta: base,
        date: DateTime.now(),
        note: noteStockInitial,
        auteurNom: ctx.nomComplet,
        syncStatus: RecordSyncStatus.pendingSync,
      );
    }
    await _repository.creerProduit(produit, stockInitial: initial);
    return produit;
  }

  Future<void> modifierProduit(ContexteSession ctx, EtatCommerce etat, Produit avant, Produit apres) async {
    _verifier(_peut(ctx, ModuleCodes.commerceProduits, PermissionCodes.productsUpdate));
    await _repository.modifierProduit(avant, _produitValide(etat, apres));
  }

  Produit _produitValide(EtatCommerce etat, Produit p) {
    final nom = _nom(p.nom, 120);
    final uniteBase = _nom(p.uniteBase, 30, code: RuleCodes.unitInvalid);
    final noms = <String>{uniteBase.toLowerCase()};
    for (final u in p.unites) {
      if (!u.facteur.estPositif || u.nom.trim().isEmpty || !noms.add(u.nom.trim().toLowerCase())) {
        throw const Failure.rule(RuleCodes.unitInvalid);
      }
    }
    final code = _nul(p.codeBarres);
    if (code != null && etat.produits.any((x) => x.id != p.id && x.codeBarres == code && x.estActif)) {
      throw const Failure.rule(RuleCodes.barcodeExists);
    }
    if (p.prixDetail < 0 || (p.prixGros ?? 0) < 0 || (p.prixAchat ?? 0) < 0) {
      throw const Failure.rule(RuleCodes.amountInvalid);
    }
    return p.copyWith(
      nom: nom,
      uniteBase: uniteBase,
      codeBarres: () => code,
      reference: () => _nul(p.reference),
      description: () => _nul(p.description),
      pasMinimum: p.venteFractionnee && p.pasMinimum.estPositif ? p.pasMinimum : Qte.un,
    );
  }

  // ===========================================================================
  // Stock
  // ===========================================================================

  /// Entrée ou sortie simple, saisie dans l'unité choisie.
  Future<MouvementStock> mouvement(
    ContexteSession ctx,
    EtatCommerce etat, {
    required Produit produit,
    required String perimetreId,
    required bool entree,
    required MotifMouvement motif,
    required Qte quantite,
    required UniteVente unite,
    String? note,
  }) async {
    _verifier(_peut(ctx, ModuleCodes.commerceStock, PermissionCodes.stockCreate, perimetreId));
    final base = _quantiteValide(produit, quantite, unite.facteur);
    final avant = etat.quantiteBoutique(produit.id, perimetreId);
    if (!entree) _assezDeStock(produit, avant, base);
    final m = MouvementStock(
      id: _uuid.v4(),
      entrepriseId: produit.entrepriseId,
      perimetreId: perimetreId,
      produitId: produit.id,
      type: entree ? TypeMouvementStock.entree : TypeMouvementStock.sortie,
      motif: motif,
      quantite: base,
      quantiteSaisie: quantite,
      uniteSaisie: unite.nom,
      facteur: unite.facteur,
      delta: entree ? base : -base,
      stockAvant: avant,
      stockApres: entree ? avant + base : avant - base,
      date: DateTime.now(),
      note: _nul(note),
      auteurNom: ctx.nomComplet,
      syncStatus: RecordSyncStatus.pendingSync,
    );
    await _repository.enregistrerMouvement(m);
    return m;
  }

  /// Inventaire : la quantité comptée remplace le stock ; l'écart est tracé.
  Future<MouvementStock> inventaire(
    ContexteSession ctx,
    EtatCommerce etat, {
    required Produit produit,
    required String perimetreId,
    required Qte compte,
    required UniteVente unite,
    required MotifMouvement motif,
    String? note,
  }) async {
    _verifier(_peut(ctx, ModuleCodes.commerceStock, PermissionCodes.stockUpdate, perimetreId));
    if (compte.estNegatif) throw const Failure.rule(RuleCodes.quantityInvalid);
    final base = compte.fois(unite.facteur);
    final avant = etat.quantiteBoutique(produit.id, perimetreId);
    final m = MouvementStock(
      id: _uuid.v4(),
      entrepriseId: produit.entrepriseId,
      perimetreId: perimetreId,
      produitId: produit.id,
      type: TypeMouvementStock.inventaire,
      motif: motif,
      quantite: base,
      quantiteSaisie: compte,
      uniteSaisie: unite.nom,
      facteur: unite.facteur,
      delta: base - avant,
      stockAvant: avant,
      stockApres: base,
      date: DateTime.now(),
      note: _nul(note),
      auteurNom: ctx.nomComplet,
      syncStatus: RecordSyncStatus.pendingSync,
    );
    await _repository.enregistrerMouvement(m);
    return m;
  }

  /// Transfert : une seule opération pour l'utilisateur, une sortie et une
  /// entrée liées pour le système.
  Future<Transfert> transferer(
    ContexteSession ctx,
    EtatCommerce etat, {
    required Produit produit,
    required String dePerimetreId,
    required String versPerimetreId,
    required Qte quantite,
    required UniteVente unite,
    String? note,
  }) async {
    if (dePerimetreId == versPerimetreId) throw const Failure.rule(RuleCodes.transferSameShop);
    _verifier(_peut(ctx, ModuleCodes.commerceStock, PermissionCodes.stockUpdate, dePerimetreId));
    _verifier(_peut(ctx, ModuleCodes.commerceStock, PermissionCodes.stockUpdate, versPerimetreId));
    final base = _quantiteValide(produit, quantite, unite.facteur);
    final avantDe = etat.quantiteBoutique(produit.id, dePerimetreId);
    final avantVers = etat.quantiteBoutique(produit.id, versPerimetreId);
    _assezDeStock(produit, avantDe, base);
    final maintenant = DateTime.now();
    final t = Transfert(
      id: _uuid.v4(),
      entrepriseId: produit.entrepriseId,
      produitId: produit.id,
      dePerimetreId: dePerimetreId,
      versPerimetreId: versPerimetreId,
      quantite: base,
      quantiteSaisie: quantite,
      uniteSaisie: unite.nom,
      facteur: unite.facteur,
      mouvementEntreeId: _uuid.v4(),
      date: maintenant,
      note: _nul(note),
      auteurNom: ctx.nomComplet,
      syncStatus: RecordSyncStatus.pendingSync,
    );
    MouvementStock m(String id, String perimetre, TypeMouvementStock type, Qte delta, Qte avant) => MouvementStock(
          id: id,
          entrepriseId: t.entrepriseId,
          perimetreId: perimetre,
          produitId: t.produitId,
          type: type,
          motif: MotifMouvement.transfert,
          quantite: base,
          quantiteSaisie: quantite,
          uniteSaisie: unite.nom,
          facteur: unite.facteur,
          delta: delta,
          stockAvant: avant,
          stockApres: avant + delta,
          origineType: 'TRANSFERT',
          origineId: t.id,
          note: t.note,
          date: maintenant,
          auteurNom: ctx.nomComplet,
          syncStatus: RecordSyncStatus.pendingSync,
        );
    await _repository.transferer(
      t,
      sortie: m(t.id, dePerimetreId, TypeMouvementStock.transfertSortie, -base, avantDe),
      entree: m(t.mouvementEntreeId, versPerimetreId, TypeMouvementStock.transfertEntree, base, avantVers),
    );
    return t;
  }

  // ===========================================================================
  // Achats
  // ===========================================================================

  Future<Achat> creerAchat(ContexteSession ctx, EtatCommerce etat, SaisieAchat s, {bool recevoirTout = false}) async {
    _verifier(_peut(ctx, ModuleCodes.commerceAchats, PermissionCodes.purchasesCreate, s.perimetreId));
    if (recevoirTout) {
      _verifier(_peut(ctx, ModuleCodes.commerceAchats, PermissionCodes.purchasesUpdate, s.perimetreId));
    }
    final lignes = _lignesValides(etat, s.lignes, avecPrix: true);
    final achat = Achat(
      id: _uuid.v4(),
      entrepriseId: ctx.entreprise!.id,
      perimetreId: s.perimetreId,
      fournisseurId: s.fournisseurId,
      reference: _nul(s.reference),
      dateAchat: _jour(s.date ?? DateTime.now()),
      lignes: lignes,
      total: totalLignes(lignes),
      note: _nul(s.note),
      auteurNom: ctx.nomComplet,
      creeLe: DateTime.now(),
      syncStatus: RecordSyncStatus.pendingSync,
    );
    final dette = achat.total <= 0
        ? null
        : fin.Engagement(
            id: achat.id,
            entrepriseId: achat.entrepriseId,
            perimetreId: achat.perimetreId,
            sens: fin.SensEngagement.aPayer,
            contactId: achat.fournisseurId,
            libelle: 'Achat ${achat.reference ?? ''}'.trim(),
            montantTotal: achat.total,
            dateEngagement: achat.dateAchat,
            origineType: 'ACHAT',
          );
    if (!recevoirTout) {
      await _repository.creerAchat(achat, dette: dette);
      return achat;
    }
    final (reception, entrees, achatRecu) =
        _reception(ctx, etat, achat, {for (final l in achat.lignes) l.id: l.quantite});
    await _repository.creerAchat(achat, dette: dette, reception: reception, entrees: entrees, achatRecu: achatRecu);
    return achat;
  }

  /// Une commande pas encore reçue se modifie (produits, quantités, prix).
  Future<void> modifierAchat(ContexteSession ctx, EtatCommerce etat, Achat avant, SaisieAchat s) async {
    _verifier(_peut(ctx, ModuleCodes.commerceAchats, PermissionCodes.purchasesUpdate, avant.perimetreId));
    if (avant.annule) throw const Failure.rule(RuleCodes.purchaseCancelled);
    if (avant.statut != StatutAchat.commande) throw const Failure.rule(RuleCodes.purchaseReceived);
    final lignes = _lignesValides(etat, s.lignes, avecPrix: true);
    await _repository.modifierAchat(
      avant,
      avant.copyWith(
        lignes: lignes,
        total: totalLignes(lignes),
        fournisseurId: () => s.fournisseurId,
        reference: () => _nul(s.reference),
        note: () => _nul(s.note),
        dateAchat: _jour(s.date ?? avant.dateAchat),
      ),
    );
  }

  Future<void> annulerAchat(ContexteSession ctx, Achat achat, {EtatFinances? finances}) async {
    _verifier(_peut(ctx, ModuleCodes.commerceAchats, PermissionCodes.purchasesUpdate, achat.perimetreId));
    if (achat.annule) return;
    if (achat.statut != StatutAchat.commande) throw const Failure.rule(RuleCodes.purchaseReceived);
    final dette = finances?.engagements.where((e) => e.id == achat.id).firstOrNull;
    if (dette != null && finances!.regle(dette) > 0) throw const Failure.rule(RuleCodes.purchasePaid);
    await _repository.modifierAchat(achat, achat.copyWith(statut: StatutAchat.annule));
  }

  /// Réception totale ou partielle : seules les quantités reçues entrent en stock.
  Future<Reception> receptionner(
    ContexteSession ctx,
    EtatCommerce etat,
    Achat achat,
    Map<String, Qte> quantites, {
    String? note,
  }) async {
    _verifier(_peut(ctx, ModuleCodes.commerceAchats, PermissionCodes.purchasesUpdate, achat.perimetreId));
    if (achat.annule) throw const Failure.rule(RuleCodes.purchaseCancelled);
    if (!achat.aRecevoir) throw const Failure.rule(RuleCodes.purchaseReceived);
    final (reception, entrees, achatRecu) = _reception(ctx, etat, achat, quantites, note: note);
    await _repository.receptionner(reception, entrees: entrees, achatRecu: achatRecu);
    return reception;
  }

  (Reception, List<MouvementStock>, Achat) _reception(
    ContexteSession ctx,
    EtatCommerce etat,
    Achat achat,
    Map<String, Qte> quantites, {
    String? note,
  }) {
    final maintenant = DateTime.now();
    final receptionId = _uuid.v4();
    final lignes = <LigneReception>[];
    final entrees = <MouvementStock>[];
    final recues = <LigneOperation>[];
    for (final l in achat.lignes) {
      final q = quantites[l.id] ?? Qte.zero;
      if (q.estNegatif) throw const Failure.rule(RuleCodes.quantityInvalid);
      if (q > l.reste) throw Failure.rule(RuleCodes.receptionAboveOrdered, {'reste': l.reste.valeur});
      recues.add(l.copyWith(recu: l.recu + q));
      if (!q.estPositif) continue;
      final id = _uuid.v4();
      final base = q.fois(l.facteur);
      final avant = etat.quantiteBoutique(l.produitId, achat.perimetreId);
      lignes.add(LigneReception(id: id, ligneId: l.id, quantite: q));
      entrees.add(MouvementStock(
        id: id,
        entrepriseId: achat.entrepriseId,
        perimetreId: achat.perimetreId,
        produitId: l.produitId,
        type: TypeMouvementStock.entree,
        motif: MotifMouvement.achat,
        quantite: base,
        quantiteSaisie: q,
        uniteSaisie: l.unite,
        facteur: l.facteur,
        delta: base,
        stockAvant: avant,
        stockApres: avant + base,
        origineType: 'RECEPTION',
        origineId: receptionId,
        date: maintenant,
        auteurNom: ctx.nomComplet,
        syncStatus: RecordSyncStatus.pendingSync,
      ));
    }
    if (lignes.isEmpty) throw const Failure.rule(RuleCodes.quantityInvalid);
    final reception = Reception(
      id: receptionId,
      entrepriseId: achat.entrepriseId,
      achatId: achat.id,
      perimetreId: achat.perimetreId,
      lignes: lignes,
      date: maintenant,
      note: _nul(note),
      auteurNom: ctx.nomComplet,
      syncStatus: RecordSyncStatus.pendingSync,
    );
    final statut = recues.every((l) => l.complete) ? StatutAchat.recu : StatutAchat.recuPartiel;
    return (reception, entrees, achat.copyWith(lignes: recues, statut: statut));
  }

  // ===========================================================================
  // Ventes
  // ===========================================================================

  Future<Vente> vendre(ContexteSession ctx, EtatCommerce etat, EtatFinances? finances, SaisieVente s) async {
    _verifier(_peut(ctx, ModuleCodes.commerceVentes, PermissionCodes.salesCreate, s.perimetreId));
    final lignes = _lignesValides(etat, s.lignes, avecPrix: true);

    // Stock négatif interdit : contrôle par produit, toutes lignes confondues.
    final demande = <String, Qte>{};
    for (final l in lignes) {
      demande[l.produitId] = (demande[l.produitId] ?? Qte.zero) + l.quantiteBase;
    }
    for (final MapEntry(key: produitId, value: q) in demande.entries) {
      _assezDeStock(etat.produit(produitId)!, etat.quantiteBoutique(produitId, s.perimetreId), q);
    }

    if (s.remise < 0) throw const Failure.rule(RuleCodes.amountInvalid);
    final total = totalLignes(lignes) - s.remise;
    if (total < 0) throw const Failure.rule(RuleCodes.amountInvalid);
    final credit = s.reglement == ReglementVente.credit;
    if (credit && s.contactId == null) throw const Failure.rule(RuleCodes.customerRequired);
    // Payé tout de suite : le total au comptant, l'acompte à crédit.
    final paye = credit ? s.acompte : total;
    if (credit && (paye < 0 || (paye > 0 && paye >= total))) throw const Failure.rule(RuleCodes.amountInvalid);
    final encaisse = !credit || paye > 0;
    if (encaisse) {
      _verifier(_peut(ctx, ModuleCodes.financesPaiements, PermissionCodes.paymentsCreate, s.perimetreId));
    }

    // Espèces : entrée dans la caisse ouverte de la boutique, s'il y en a une.
    fin.SessionCaisse? session;
    if (encaisse && s.modePaiement.passeParCaisse && finances != null) {
      for (final c in finances.caisses.where((c) => c.perimetreId == s.perimetreId && c.estActive)) {
        session = finances.sessionOuverte(c.id);
        if (session != null) break;
      }
    }

    final maintenant = DateTime.now();
    final venteId = _uuid.v4();
    final paiementId = encaisse ? _uuid.v4() : null;
    final vente = Vente(
      id: venteId,
      entrepriseId: ctx.entreprise!.id,
      perimetreId: s.perimetreId,
      contactId: s.contactId,
      mode: s.mode,
      lignes: lignes,
      remise: s.remise,
      total: total,
      date: maintenant,
      reglement: s.reglement,
      modePaiement: encaisse ? s.modePaiement.code : null,
      sessionId: session?.id,
      paiementId: paiementId,
      note: _nul(s.note),
      auteurNom: ctx.nomComplet,
      syncStatus: RecordSyncStatus.pendingSync,
      dateCommerciale: jourCommercial(maintenant),
      montantPaye: paye,
    );

    final sorties = <MouvementStock>[];
    final cumul = <String, Qte>{};
    for (final l in lignes) {
      final avant = etat.quantiteBoutique(l.produitId, s.perimetreId) - (cumul[l.produitId] ?? Qte.zero);
      cumul[l.produitId] = (cumul[l.produitId] ?? Qte.zero) + l.quantiteBase;
      sorties.add(MouvementStock(
        id: l.id,
        entrepriseId: vente.entrepriseId,
        perimetreId: s.perimetreId,
        produitId: l.produitId,
        type: TypeMouvementStock.sortie,
        motif: MotifMouvement.vente,
        quantite: l.quantiteBase,
        quantiteSaisie: l.quantite,
        uniteSaisie: l.unite,
        facteur: l.facteur,
        delta: -l.quantiteBase,
        stockAvant: avant,
        stockApres: avant - l.quantiteBase,
        origineType: 'VENTE',
        origineId: venteId,
        date: maintenant,
        auteurNom: ctx.nomComplet,
        syncStatus: RecordSyncStatus.pendingSync,
      ));
    }

    // Copies locales de ce que le serveur créera, avec les mêmes identifiants.
    fin.Engagement? creance;
    fin.Paiement? paiement;
    fin.MouvementCaisse? mouvementCaisse;
    if (total > 0) {
      creance = fin.Engagement(
        id: venteId,
        entrepriseId: vente.entrepriseId,
        perimetreId: s.perimetreId,
        sens: fin.SensEngagement.aRecevoir,
        contactId: s.contactId,
        libelle: 'Vente',
        montantTotal: total,
        dateEngagement: _jour(maintenant),
        origineType: 'VENTE',
      );
      if (paiementId != null) {
        paiement = fin.Paiement(
          id: paiementId,
          entrepriseId: vente.entrepriseId,
          perimetreId: s.perimetreId,
          sens: fin.SensPaiement.entree,
          montant: paye,
          mode: s.modePaiement,
          datePaiement: maintenant,
          contactId: s.contactId,
          note: 'Vente',
          sessionId: session?.id,
          affectations: [fin.Affectation(id: paiementId, engagementId: venteId, montant: paye)],
          syncStatus: RecordSyncStatus.pendingSync,
        );
        if (session != null) {
          mouvementCaisse = fin.MouvementCaisse(
            id: paiementId,
            sessionId: session.id,
            caisseId: session.caisseId,
            type: fin.TypeMouvement.encaissement,
            montant: paye,
            paiementId: paiementId,
            createdAt: maintenant,
          );
        }
      }
    }
    return _repository.vendre(vente,
        sorties: sorties, creance: creance, paiement: paiement, mouvementCaisse: mouvementCaisse);
  }

  /// Annuler une vente non encaissée : les produits reviennent en stock.
  Future<void> annulerVente(ContexteSession ctx, EtatCommerce etat, Vente vente,
      {String? motif, EtatFinances? finances}) async {
    _verifier(_peut(ctx, ModuleCodes.commerceVentes, PermissionCodes.salesUpdate, vente.perimetreId));
    if (vente.annulee) throw const Failure.rule(RuleCodes.saleCancelled);
    final creance = finances?.engagements.where((e) => e.id == vente.id).firstOrNull;
    final paye = creance != null && finances!.regle(creance) > 0;
    if (paye || vente.reglement == ReglementVente.immediat && vente.total > 0 && creance == null) {
      throw const Failure.rule(RuleCodes.salePaid);
    }
    final maintenant = DateTime.now();
    final retours = [
      for (final l in vente.lignes)
        MouvementStock(
          id: _uuid.v4(),
          entrepriseId: vente.entrepriseId,
          perimetreId: vente.perimetreId,
          produitId: l.produitId,
          type: TypeMouvementStock.entree,
          motif: MotifMouvement.retour,
          quantite: l.quantiteBase,
          quantiteSaisie: l.quantite,
          uniteSaisie: l.unite,
          facteur: l.facteur,
          delta: l.quantiteBase,
          origineType: 'VENTE',
          origineId: vente.id,
          note: _nul(motif),
          date: maintenant,
          auteurNom: ctx.nomComplet,
          syncStatus: RecordSyncStatus.pendingSync,
        ),
    ];
    // Le reçu reste : il porte le statut « annulé », la date et l'auteur.
    await _repository.annulerVente(
      vente,
      vente.annuler(motif: _nul(motif), le: maintenant, par: ctx.nomComplet),
      retours: retours,
    );
  }

  Future<void> retirerRefuse(String table, String id) => _repository.retirerRefuse(table, id);

  // ===========================================================================
  // Contrôles
  // ===========================================================================

  List<LigneOperation> _lignesValides(EtatCommerce etat, List<LigneOperation> lignes, {required bool avecPrix}) {
    if (lignes.isEmpty || lignes.length > 200) throw const Failure.rule(RuleCodes.linesInvalid);
    for (final l in lignes) {
      final p = etat.produit(l.produitId);
      if (p == null) throw const Failure.rule(RuleCodes.linesInvalid);
      _quantiteValide(p, l.quantite, l.facteur);
      if (avecPrix && l.prixUnitaire < 0) throw const Failure.rule(RuleCodes.amountInvalid);
    }
    return lignes;
  }

  /// Quantité saisie valide pour ce produit ; renvoie la quantité en unité de base.
  static Qte _quantiteValide(Produit p, Qte quantite, Qte facteur) {
    if (!quantite.estPositif || !facteur.estPositif) throw const Failure.rule(RuleCodes.quantityInvalid);
    final base = quantite.fois(facteur);
    if (!p.venteFractionnee && !base.estEntier) {
      throw Failure.rule(RuleCodes.fractionInvalid, {'pas': 1, 'unite': p.uniteBase});
    }
    if (p.venteFractionnee && !base.estMultipleDe(p.pasMinimum)) {
      throw Failure.rule(RuleCodes.fractionInvalid, {'pas': p.pasMinimum.valeur, 'unite': p.uniteBase});
    }
    return base;
  }

  static void _assezDeStock(Produit p, Qte disponible, Qte demande) {
    if (demande > disponible) {
      throw Failure.rule(RuleCodes.stockInsufficient,
          {'disponible': disponible.max(Qte.zero).valeur, 'unite': p.uniteBase, 'produit': p.nom});
    }
  }

  static String _nom(String valeur, int max, {String code = RuleCodes.nameInvalid}) {
    final t = valeur.trim();
    if (t.isEmpty || t.length > max) throw Failure.rule(code);
    return t;
  }
}

AccessDecision _peut(ContexteSession ctx, String module, String permission, [String? perimetreId]) =>
    ctx.accessPolicy().canPerform(moduleCode: module, permission: permission, perimetreId: perimetreId);

void _verifier(AccessDecision decision) {
  if (decision case AccessDenied()) throw decision.toFailure();
}

DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

String? _nul(String? v) {
  final t = v?.trim();
  return t == null || t.isEmpty ? null : t;
}
