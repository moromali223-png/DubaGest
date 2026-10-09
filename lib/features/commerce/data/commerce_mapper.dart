import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_models.dart';
import '../../../core/utils/recherche.dart';
import '../domain/entities/commerce.dart';

/// Conversions ligne locale ↔ entité ↔ JSON serveur pour le Commerce.
/// Quantités : `numeric` côté serveur, dix-millièmes (entiers) en local.
abstract final class CommerceMapper {
  static Qte _q(Object? v) => v == null ? Qte.zero : Qte.depuis(v as num);
  static int? _i(Object? v) => (v as num?)?.toInt();
  static DateTime? _dt(Object? v) => v == null ? null : DateTime.parse(v as String);
  static DateTime _jour(String v) => DateTime.parse(v.substring(0, 10));
  static String jour(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static List<T> _liste<T>(String json, T Function(Map<String, dynamic>) f) =>
      [for (final e in jsonDecode(json) as List) f((e as Map).cast<String, dynamic>())];

  static String _jsonListe(Object? v) => jsonEncode(v ?? const []);

  // --- Catégories -------------------------------------------------------------

  static CategorieProduit categorie(CategorieProduitRow r) => CategorieProduit(
        id: r.id,
        entrepriseId: r.entrepriseId,
        parentId: r.parentId,
        nom: r.nom,
        icone: r.icone,
        couleur: r.couleur,
        ordre: r.ordre,
        estActive: r.estActive,
        version: r.version,
        syncStatus: RecordSyncStatus.fromWire(r.syncStatus),
      );

  static CategoriesProduitsCompanion categorieLocale(CategorieProduit c, RecordSyncStatus statut) =>
      CategoriesProduitsCompanion.insert(
        id: c.id,
        entrepriseId: c.entrepriseId,
        parentId: Value(c.parentId),
        nom: c.nom,
        icone: Value(c.icone),
        couleur: Value(c.couleur),
        ordre: Value(c.ordre),
        estActive: Value(c.estActive),
        version: Value(c.version),
        syncStatus: statut.wire,
      );

  static CategoriesProduitsCompanion categorieServeur(Map<String, dynamic> j, RecordSyncStatus statut) =>
      CategoriesProduitsCompanion.insert(
        id: j['id'] as String,
        entrepriseId: j['entreprise_id'] as String,
        parentId: Value(j['parent_id'] as String?),
        nom: j['nom'] as String,
        icone: Value(j['icone'] as String?),
        couleur: Value(j['couleur'] as String?),
        ordre: Value(_i(j['ordre']) ?? 100),
        estActive: Value(j['est_active'] as bool? ?? true),
        version: Value(_i(j['version'])),
        updatedAt: Value(_dt(j['updated_at'])),
        syncStatus: statut.wire,
      );

  static Map<String, dynamic> categoriePayload(CategorieProduit c, {bool creation = false}) => {
        if (creation) 'entreprise_id': c.entrepriseId,
        'parent_id': c.parentId,
        'nom': c.nom,
        'icone': c.icone,
        'couleur': c.couleur,
        'ordre': c.ordre,
        if (!creation) 'est_active': c.estActive,
      };

  static bool categorieIdentique(CategorieProduitRow l, Map<String, dynamic> s) =>
      l.nom == s['nom'] &&
      l.parentId == s['parent_id'] &&
      l.icone == s['icone'] &&
      l.couleur == s['couleur'] &&
      l.estActive == (s['est_active'] as bool? ?? true);

  // --- Produits ---------------------------------------------------------------

  static Produit produit(ProduitRow r) => Produit(
        id: r.id,
        entrepriseId: r.entrepriseId,
        categorieId: r.categorieId,
        nom: r.nom,
        reference: r.reference,
        codeBarres: r.codeBarres,
        description: r.description,
        photos: [for (final p in jsonDecode(r.photos) as List) p as String],
        uniteBase: r.uniteBase,
        unites: _liste(r.unites, UniteProduit.fromJson),
        prixDetail: r.prixDetail,
        prixGros: r.prixGros,
        prixAchat: r.prixAchat,
        venteFractionnee: r.venteFractionnee,
        pasMinimum: Qte(r.pasMinimum),
        seuilAlerte: Qte(r.seuilAlerte),
        attributs: (jsonDecode(r.attributs) as Map).map((k, v) => MapEntry(k as String, '$v')),
        fournisseurId: r.fournisseurId,
        estActif: r.estActif,
        version: r.version,
        syncStatus: RecordSyncStatus.fromWire(r.syncStatus),
      );

  static String cle(Produit p) =>
      normaliserRecherche([p.nom, p.reference, p.codeBarres, ...p.attributs.values].whereType<String>().join(' '));

  static ProduitsCompanion produitLocal(Produit p, RecordSyncStatus statut) => ProduitsCompanion.insert(
        id: p.id,
        entrepriseId: p.entrepriseId,
        categorieId: Value(p.categorieId),
        nom: p.nom,
        reference: Value(p.reference),
        codeBarres: Value(p.codeBarres),
        description: Value(p.description),
        photos: Value(jsonEncode(p.photos)),
        uniteBase: p.uniteBase,
        unites: Value(jsonEncode([for (final u in p.unites) u.toJson()])),
        prixDetail: Value(p.prixDetail),
        prixGros: Value(p.prixGros),
        prixAchat: Value(p.prixAchat),
        venteFractionnee: Value(p.venteFractionnee),
        pasMinimum: Value(p.pasMinimum.brut),
        seuilAlerte: Value(p.seuilAlerte.brut),
        attributs: Value(jsonEncode(p.attributs)),
        fournisseurId: Value(p.fournisseurId),
        estActif: Value(p.estActif),
        cleRecherche: Value(cle(p)),
        version: Value(p.version),
        syncStatus: statut.wire,
      );

  static Produit produitDepuisServeur(Map<String, dynamic> j) => Produit(
        id: j['id'] as String,
        entrepriseId: j['entreprise_id'] as String,
        categorieId: j['categorie_id'] as String?,
        nom: j['nom'] as String,
        reference: j['reference'] as String?,
        codeBarres: j['code_barres'] as String?,
        description: j['description'] as String?,
        photos: [for (final p in (j['photos'] as List?) ?? const []) p as String],
        uniteBase: j['unite_base'] as String,
        unites: [
          for (final u in (j['unites'] as List?) ?? const []) UniteProduit.fromJson((u as Map).cast<String, dynamic>()),
        ],
        prixDetail: _i(j['prix_detail']) ?? 0,
        prixGros: _i(j['prix_gros']),
        prixAchat: _i(j['prix_achat']),
        venteFractionnee: j['vente_fractionnee'] as bool? ?? false,
        pasMinimum: _q(j['pas_minimum'] ?? 1),
        seuilAlerte: _q(j['seuil_alerte']),
        attributs: ((j['attributs'] as Map?) ?? const {}).map((k, v) => MapEntry(k as String, '$v')),
        fournisseurId: j['fournisseur_id'] as String?,
        estActif: j['est_actif'] as bool? ?? true,
        version: _i(j['version']),
      );

  static ProduitsCompanion produitServeur(Map<String, dynamic> j, RecordSyncStatus statut) =>
      produitLocal(produitDepuisServeur(j), statut).copyWith(updatedAt: Value(_dt(j['updated_at'])));

  static Map<String, dynamic> produitPayload(Produit p, {bool creation = false}) => {
        if (creation) 'entreprise_id': p.entrepriseId,
        'categorie_id': p.categorieId,
        'nom': p.nom,
        'reference': p.reference,
        'code_barres': p.codeBarres,
        'description': p.description,
        'photos': p.photos,
        'unite_base': p.uniteBase,
        'unites': [for (final u in p.unites) u.toJson()],
        'prix_detail': p.prixDetail,
        'prix_gros': p.prixGros,
        'prix_achat': p.prixAchat,
        'vente_fractionnee': p.venteFractionnee,
        'pas_minimum': p.pasMinimum.json,
        'seuil_alerte': p.seuilAlerte.json,
        'attributs': p.attributs,
        'fournisseur_id': p.fournisseurId,
        if (!creation) 'est_actif': p.estActif,
      };

  static bool produitIdentique(ProduitRow l, Map<String, dynamic> s) {
    final serveur = produitLocal(produitDepuisServeur(s), RecordSyncStatus.synced);
    return l.nom == serveur.nom.value &&
        l.categorieId == serveur.categorieId.value &&
        l.reference == serveur.reference.value &&
        l.codeBarres == serveur.codeBarres.value &&
        l.description == serveur.description.value &&
        l.photos == serveur.photos.value &&
        l.uniteBase == serveur.uniteBase.value &&
        l.unites == serveur.unites.value &&
        l.prixDetail == serveur.prixDetail.value &&
        l.prixGros == serveur.prixGros.value &&
        l.prixAchat == serveur.prixAchat.value &&
        l.venteFractionnee == serveur.venteFractionnee.value &&
        l.pasMinimum == serveur.pasMinimum.value &&
        l.seuilAlerte == serveur.seuilAlerte.value &&
        l.attributs == serveur.attributs.value &&
        l.fournisseurId == serveur.fournisseurId.value &&
        l.estActif == serveur.estActif.value;
  }

  // --- Stock et mouvements ----------------------------------------------------

  static StockBoutique stock(StockRow r) =>
      StockBoutique(perimetreId: r.perimetreId, produitId: r.produitId, quantite: Qte(r.quantite));

  static StocksCompanion stockServeur(Map<String, dynamic> j, RecordSyncStatus statut) => StocksCompanion.insert(
        id: j['id'] as String,
        entrepriseId: j['entreprise_id'] as String,
        perimetreId: j['perimetre_id'] as String,
        produitId: j['produit_id'] as String,
        quantite: Value(_q(j['quantite']).brut),
        version: Value(_i(j['version'])),
        updatedAt: Value(_dt(j['updated_at'])),
        syncStatus: statut.wire,
      );

  static MouvementStock mouvement(MouvementStockRow r) => MouvementStock(
        id: r.id,
        entrepriseId: r.entrepriseId,
        perimetreId: r.perimetreId,
        produitId: r.produitId,
        type: TypeMouvementStock.parse(r.type),
        motif: MotifMouvement.parse(r.motif),
        quantite: Qte(r.quantite),
        quantiteSaisie: Qte(r.quantiteSaisie),
        uniteSaisie: r.uniteSaisie,
        facteur: Qte(r.facteur),
        delta: Qte(r.delta),
        stockAvant: r.stockAvant == null ? null : Qte(r.stockAvant!),
        stockApres: r.stockApres == null ? null : Qte(r.stockApres!),
        origineType: r.origineType,
        origineId: r.origineId,
        note: r.note,
        date: r.dateMouvement,
        auteurNom: r.auteurNom,
        version: r.version,
        syncStatus: RecordSyncStatus.fromWire(r.syncStatus),
      );

  static MouvementsStockCompanion mouvementLocal(MouvementStock m, RecordSyncStatus statut) =>
      MouvementsStockCompanion.insert(
        id: m.id,
        entrepriseId: m.entrepriseId,
        perimetreId: m.perimetreId,
        produitId: m.produitId,
        type: m.type.code,
        motif: m.motif.code,
        quantite: m.quantite.brut,
        quantiteSaisie: m.quantiteSaisie.brut,
        uniteSaisie: m.uniteSaisie,
        facteur: Value(m.facteur.brut),
        delta: Value(m.delta.brut),
        stockAvant: Value(m.stockAvant?.brut),
        stockApres: Value(m.stockApres?.brut),
        origineType: Value(m.origineType),
        origineId: Value(m.origineId),
        note: Value(m.note),
        dateMouvement: m.date,
        auteurNom: Value(m.auteurNom),
        version: Value(m.version),
        syncStatus: statut.wire,
      );

  static MouvementsStockCompanion mouvementServeur(Map<String, dynamic> j, RecordSyncStatus statut) =>
      MouvementsStockCompanion.insert(
        id: j['id'] as String,
        entrepriseId: j['entreprise_id'] as String,
        perimetreId: j['perimetre_id'] as String,
        produitId: j['produit_id'] as String,
        type: j['type'] as String,
        motif: j['motif'] as String,
        quantite: _q(j['quantite']).brut,
        quantiteSaisie: _q(j['quantite_saisie']).brut,
        uniteSaisie: j['unite_saisie'] as String,
        facteur: Value(_q(j['facteur'] ?? 1).brut),
        delta: Value(_q(j['delta']).brut),
        stockAvant: Value(_q(j['stock_avant']).brut),
        stockApres: Value(_q(j['stock_apres']).brut),
        origineType: Value(j['origine_type'] as String? ?? 'MANUEL'),
        origineId: Value(j['origine_id'] as String?),
        note: Value(j['note'] as String?),
        dateMouvement: DateTime.parse(j['date_mouvement'] as String),
        auteurNom: Value(j['auteur_nom'] as String?),
        version: Value(_i(j['version'])),
        updatedAt: Value(_dt(j['updated_at'])),
        syncStatus: statut.wire,
      );

  static Map<String, dynamic> mouvementPayload(MouvementStock m) => {
        'entreprise_id': m.entrepriseId,
        'perimetre_id': m.perimetreId,
        'produit_id': m.produitId,
        'type': m.type.code,
        'motif': m.motif.code,
        'quantite': m.quantite.json,
        'quantite_saisie': m.quantiteSaisie.json,
        'unite_saisie': m.uniteSaisie,
        'facteur': m.facteur.json,
        'note': m.note,
        'date_mouvement': m.date.toUtc().toIso8601String(),
      };

  // --- Transferts -------------------------------------------------------------

  static Transfert transfert(TransfertStockRow r) => Transfert(
        id: r.id,
        entrepriseId: r.entrepriseId,
        produitId: r.produitId,
        dePerimetreId: r.dePerimetreId,
        versPerimetreId: r.versPerimetreId,
        quantite: Qte(r.quantite),
        quantiteSaisie: Qte(r.quantiteSaisie),
        uniteSaisie: r.uniteSaisie,
        facteur: Qte(r.facteur),
        mouvementEntreeId: r.mouvementEntreeId,
        date: r.dateTransfert,
        note: r.note,
        auteurNom: r.auteurNom,
        syncStatus: RecordSyncStatus.fromWire(r.syncStatus),
      );

  static TransfertsStockCompanion transfertLocal(Transfert t, RecordSyncStatus statut, {int? version}) =>
      TransfertsStockCompanion.insert(
        id: t.id,
        entrepriseId: t.entrepriseId,
        produitId: t.produitId,
        dePerimetreId: t.dePerimetreId,
        versPerimetreId: t.versPerimetreId,
        quantite: t.quantite.brut,
        quantiteSaisie: t.quantiteSaisie.brut,
        uniteSaisie: t.uniteSaisie,
        facteur: t.facteur.brut,
        mouvementEntreeId: t.mouvementEntreeId,
        note: Value(t.note),
        dateTransfert: t.date,
        auteurNom: Value(t.auteurNom),
        version: Value(version),
        syncStatus: statut.wire,
      );

  static TransfertsStockCompanion transfertServeur(Map<String, dynamic> j, RecordSyncStatus statut) =>
      transfertLocal(
        Transfert(
          id: j['id'] as String,
          entrepriseId: j['entreprise_id'] as String,
          produitId: j['produit_id'] as String,
          dePerimetreId: j['de_perimetre_id'] as String,
          versPerimetreId: j['vers_perimetre_id'] as String,
          quantite: _q(j['quantite']),
          quantiteSaisie: _q(j['quantite_saisie']),
          uniteSaisie: j['unite_saisie'] as String,
          facteur: _q(j['facteur'] ?? 1),
          mouvementEntreeId: j['mouvement_entree_id'] as String,
          date: DateTime.parse(j['date_transfert'] as String),
          note: j['note'] as String?,
          auteurNom: j['auteur_nom'] as String?,
        ),
        statut,
        version: _i(j['version']),
      ).copyWith(updatedAt: Value(_dt(j['updated_at'])));

  static Map<String, dynamic> transfertPayload(Transfert t) => {
        'entreprise_id': t.entrepriseId,
        'produit_id': t.produitId,
        'de_perimetre_id': t.dePerimetreId,
        'vers_perimetre_id': t.versPerimetreId,
        'quantite': t.quantite.json,
        'quantite_saisie': t.quantiteSaisie.json,
        'unite_saisie': t.uniteSaisie,
        'facteur': t.facteur.json,
        'mouvement_entree_id': t.mouvementEntreeId,
        'note': t.note,
        'date_transfert': t.date.toUtc().toIso8601String(),
      };

  // --- Achats -----------------------------------------------------------------

  static Achat achat(AchatRow r) => Achat(
        id: r.id,
        entrepriseId: r.entrepriseId,
        perimetreId: r.perimetreId,
        fournisseurId: r.fournisseurId,
        reference: r.reference,
        dateAchat: _jour(r.dateAchat),
        lignes: _liste(r.lignes, LigneOperation.fromJson),
        total: r.total,
        statut: StatutAchat.parse(r.statut),
        note: r.note,
        auteurNom: r.auteurNom,
        creeLe: r.creeLe,
        version: r.version,
        syncStatus: RecordSyncStatus.fromWire(r.syncStatus),
      );

  static AchatsCompanion achatLocal(Achat a, RecordSyncStatus statut) => AchatsCompanion.insert(
        id: a.id,
        entrepriseId: a.entrepriseId,
        perimetreId: a.perimetreId,
        fournisseurId: Value(a.fournisseurId),
        reference: Value(a.reference),
        dateAchat: jour(a.dateAchat),
        lignes: jsonEncode([for (final l in a.lignes) l.toJson(avecRecu: true)]),
        total: Value(a.total),
        statut: a.statut.code,
        note: Value(a.note),
        auteurNom: Value(a.auteurNom),
        creeLe: a.creeLe,
        version: Value(a.version),
        syncStatus: statut.wire,
      );

  static AchatsCompanion achatServeur(Map<String, dynamic> j, RecordSyncStatus statut) => AchatsCompanion.insert(
        id: j['id'] as String,
        entrepriseId: j['entreprise_id'] as String,
        perimetreId: j['perimetre_id'] as String,
        fournisseurId: Value(j['fournisseur_id'] as String?),
        reference: Value(j['reference'] as String?),
        dateAchat: (j['date_achat'] as String).substring(0, 10),
        lignes: _jsonListe(j['lignes']),
        total: Value(_i(j['total']) ?? 0),
        statut: j['statut'] as String,
        note: Value(j['note'] as String?),
        auteurNom: Value(j['auteur_nom'] as String?),
        creeLe: DateTime.parse(j['created_at'] as String),
        version: Value(_i(j['version'])),
        updatedAt: Value(_dt(j['updated_at'])),
        syncStatus: statut.wire,
      );

  static Map<String, dynamic> achatPayload(Achat a, {bool creation = false}) => {
        if (creation) ...{'entreprise_id': a.entrepriseId, 'perimetre_id': a.perimetreId},
        'fournisseur_id': a.fournisseurId,
        'reference': a.reference,
        'date_achat': jour(a.dateAchat),
        'lignes': [for (final l in a.lignes) l.toJson()],
        'note': a.note,
        if (!creation) 'statut': a.statut.code,
      };

  static bool achatIdentique(AchatRow l, Map<String, dynamic> s) {
    final lignesServeur = [
      for (final e in (s['lignes'] as List?) ?? const [])
        LigneOperation.fromJson((e as Map).cast<String, dynamic>()).toJson(),
    ];
    final lignesLocales = [for (final x in achat(l).lignes) x.toJson()];
    return l.fournisseurId == s['fournisseur_id'] &&
        l.reference == s['reference'] &&
        l.note == s['note'] &&
        l.statut == s['statut'] &&
        jsonEncode(lignesLocales) == jsonEncode(lignesServeur);
  }

  // --- Réceptions -------------------------------------------------------------

  static Reception reception(ReceptionRow r) => Reception(
        id: r.id,
        entrepriseId: r.entrepriseId,
        achatId: r.achatId,
        perimetreId: r.perimetreId,
        lignes: _liste(r.lignes, LigneReception.fromJson),
        date: r.dateReception,
        note: r.note,
        auteurNom: r.auteurNom,
        syncStatus: RecordSyncStatus.fromWire(r.syncStatus),
      );

  static ReceptionsCompanion receptionLocale(Reception r, RecordSyncStatus statut) => ReceptionsCompanion.insert(
        id: r.id,
        entrepriseId: r.entrepriseId,
        achatId: r.achatId,
        perimetreId: Value(r.perimetreId),
        lignes: jsonEncode([for (final l in r.lignes) l.toJson()]),
        dateReception: r.date,
        note: Value(r.note),
        auteurNom: Value(r.auteurNom),
        syncStatus: statut.wire,
      );

  static ReceptionsCompanion receptionServeur(Map<String, dynamic> j, RecordSyncStatus statut) =>
      ReceptionsCompanion.insert(
        id: j['id'] as String,
        entrepriseId: j['entreprise_id'] as String,
        achatId: j['achat_id'] as String,
        perimetreId: Value(j['perimetre_id'] as String?),
        lignes: _jsonListe(j['lignes']),
        dateReception: DateTime.parse(j['date_reception'] as String),
        note: Value(j['note'] as String?),
        auteurNom: Value(j['auteur_nom'] as String?),
        version: Value(_i(j['version'])),
        updatedAt: Value(_dt(j['updated_at'])),
        syncStatus: statut.wire,
      );

  static Map<String, dynamic> receptionPayload(Reception r) => {
        'entreprise_id': r.entrepriseId,
        'achat_id': r.achatId,
        'lignes': [for (final l in r.lignes) l.toJson()],
        'date_reception': r.date.toUtc().toIso8601String(),
        'note': r.note,
      };

  // --- Ventes -----------------------------------------------------------------

  static Vente vente(VenteRow r) {
    var num = r.numero;
    final jour = r.dateCommerciale ?? jourCommercial(r.dateVente);
    if (num == null || num.isEmpty) {
      final seq = r.sequence ?? 1;
      final poste = r.poste ?? '';
      num = numeroRecu(jour, poste, seq);
    }
    return Vente(
      id: r.id,
      entrepriseId: r.entrepriseId,
      perimetreId: r.perimetreId,
      contactId: r.contactId,
      mode: ModeVente.parse(r.mode),
      lignes: _liste(r.lignes, LigneOperation.fromJson),
      remise: r.remise,
      total: r.total,
      date: r.dateVente,
      reglement: ReglementVente.parse(r.reglement),
      modePaiement: r.modeCode,
      sessionId: r.sessionId,
      paiementId: r.paiementId,
      annulee: r.statut == 'ANNULEE',
      motifAnnulation: r.motifAnnulation,
      note: r.note,
      auteurNom: r.auteurNom,
      version: r.version,
      syncStatus: RecordSyncStatus.fromWire(r.syncStatus),
      numero: num,
      dateCommerciale: jour,
      poste: r.poste,
      sequence: r.sequence,
      montantPaye: r.montantPaye,
      annuleeLe: r.annuleeLe,
      annuleeParNom: r.annuleeParNom,
    );
  }

  static VentesCompanion venteLocale(Vente v, RecordSyncStatus statut) => VentesCompanion.insert(
        id: v.id,
        entrepriseId: v.entrepriseId,
        perimetreId: v.perimetreId,
        contactId: Value(v.contactId),
        mode: v.mode.code,
        lignes: jsonEncode([for (final l in v.lignes) l.toJson()]),
        remise: Value(v.remise),
        total: Value(v.total),
        dateVente: v.date,
        reglement: v.reglement.code,
        modeCode: Value(v.modePaiement),
        sessionId: Value(v.sessionId),
        paiementId: Value(v.paiementId),
        statut: v.annulee ? 'ANNULEE' : 'VALIDEE',
        motifAnnulation: Value(v.motifAnnulation),
        note: Value(v.note),
        auteurNom: Value(v.auteurNom),
        version: Value(v.version),
        syncStatus: statut.wire,
        numero: Value(v.numero),
        dateCommerciale: Value(v.dateCommerciale),
        poste: Value(v.poste),
        sequence: Value(v.sequence),
        montantPaye: Value(v.montantPaye),
        annuleeLe: Value(v.annuleeLe),
        annuleeParNom: Value(v.annuleeParNom),
      );

  static VentesCompanion venteServeur(Map<String, dynamic> j, RecordSyncStatus statut) => VentesCompanion.insert(
        id: j['id'] as String,
        entrepriseId: j['entreprise_id'] as String,
        perimetreId: j['perimetre_id'] as String,
        contactId: Value(j['contact_id'] as String?),
        mode: j['mode'] as String,
        lignes: _jsonListe(j['lignes']),
        remise: Value(_i(j['remise']) ?? 0),
        total: Value(_i(j['total']) ?? 0),
        dateVente: DateTime.parse(j['date_vente'] as String),
        reglement: j['reglement'] as String,
        modeCode: Value(j['mode_code'] as String?),
        sessionId: Value(j['session_id'] as String?),
        paiementId: Value(j['paiement_id'] as String?),
        statut: j['statut'] as String,
        motifAnnulation: Value(j['motif_annulation'] as String?),
        note: Value(j['note'] as String?),
        auteurNom: Value(j['auteur_nom'] as String?),
        version: Value(_i(j['version'])),
        updatedAt: Value(_dt(j['updated_at'])),
        syncStatus: statut.wire,
        numero: Value(j['numero'] as String?),
        dateCommerciale: Value(j['date_commerciale'] as String?),
        poste: Value(j['poste'] as String?),
        sequence: Value(_i(j['sequence'])),
        montantPaye: Value(_i(j['montant_paye']) ?? 0),
        annuleeLe: Value(_dt(j['annulee_le'])),
        annuleeParNom: Value(j['annulee_par_nom'] as String?),
      );

  static Map<String, dynamic> ventePayload(Vente v) => {
        'entreprise_id': v.entrepriseId,
        'perimetre_id': v.perimetreId,
        'contact_id': v.contactId,
        'mode': v.mode.code,
        'lignes': [for (final l in v.lignes) l.toJson()],
        'remise': v.remise,
        'date_vente': v.date.toUtc().toIso8601String(),
        'reglement': v.reglement.code,
        'mode_code': v.modePaiement,
        'session_id': v.sessionId,
        'paiement_id': v.paiementId,
        'note': v.note,
        'numero': v.numero,
        'date_commerciale': v.dateCommerciale,
        'poste': v.poste,
        'sequence': v.sequence,
        'montant_paye': v.montantPaye,
      };

  static bool venteIdentique(VenteRow l, Map<String, dynamic> s) =>
      l.note == s['note'] && l.statut == s['statut'] && l.motifAnnulation == s['motif_annulation'];
}
