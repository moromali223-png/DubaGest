import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/stockage_miroir.dart';
import '../../../core/sync/sync_models.dart';
import '../../finances/data/models/finances_mapper.dart';
import '../../finances/domain/entities/finances.dart';
import '../domain/entities/commerce.dart';
import '../domain/services/etat_commerce.dart';
import 'commerce_mapper.dart';

/// Données Commerce sur l'appareil : tout se consulte et se saisit hors-ligne.
class CommerceLocalDataSource {
  CommerceLocalDataSource(this._db)
      : categories = StockageMiroir(_db, _db.categoriesProduits,
            versLocal: CommerceMapper.categorieServeur,
            statutDe: (r) => r.syncStatus,
            versionDe: (r) => r.version,
            identique: CommerceMapper.categorieIdentique),
        produits = StockageMiroir(_db, _db.produits,
            versLocal: CommerceMapper.produitServeur,
            statutDe: (r) => r.syncStatus,
            versionDe: (r) => r.version,
            identique: CommerceMapper.produitIdentique),
        stocks = StockageStocks(_db, _db.stocks,
            versLocal: CommerceMapper.stockServeur, statutDe: (r) => r.syncStatus, versionDe: (r) => r.version),
        mouvements = StockageMiroir(_db, _db.mouvementsStock,
            versLocal: CommerceMapper.mouvementServeur, statutDe: (r) => r.syncStatus, versionDe: (r) => r.version),
        transferts = StockageMiroir(_db, _db.transfertsStock,
            versLocal: CommerceMapper.transfertServeur, statutDe: (r) => r.syncStatus, versionDe: (r) => r.version),
        achats = StockageMiroir(_db, _db.achats,
            versLocal: CommerceMapper.achatServeur,
            statutDe: (r) => r.syncStatus,
            versionDe: (r) => r.version,
            identique: CommerceMapper.achatIdentique),
        receptions = StockageMiroir(_db, _db.receptions,
            versLocal: CommerceMapper.receptionServeur, statutDe: (r) => r.syncStatus, versionDe: (r) => r.version),
        ventes = StockageMiroir(_db, _db.ventes,
            versLocal: CommerceMapper.venteServeur,
            statutDe: (r) => r.syncStatus,
            versionDe: (r) => r.version,
            identique: CommerceMapper.venteIdentique);

  final AppDatabase _db;
  final StockageMiroir<$CategoriesProduitsTable, CategorieProduitRow> categories;
  final StockageMiroir<$ProduitsTable, ProduitRow> produits;
  final StockageMiroir<$StocksTable, StockRow> stocks;
  final StockageMiroir<$MouvementsStockTable, MouvementStockRow> mouvements;
  final StockageMiroir<$TransfertsStockTable, TransfertStockRow> transferts;
  final StockageMiroir<$AchatsTable, AchatRow> achats;
  final StockageMiroir<$ReceptionsTable, ReceptionRow> receptions;
  final StockageMiroir<$VentesTable, VenteRow> ventes;

  List<StockageMiroir> get tous => [categories, produits, stocks, mouvements, transferts, achats, receptions, ventes];

  Future<void> enTransaction(Future<void> Function() action) => _db.transaction(action);

  /// Réémis à chaque écriture locale ou synchronisation d'une table Commerce.
  Stream<EtatCommerce> watch(String entrepriseId) async* {
    yield await charger(entrepriseId);
    yield* _db
        .tableUpdates(TableUpdateQuery.onAllTables(_db.tablesCommerce))
        .asyncMap((_) => charger(entrepriseId));
  }

  Future<EtatCommerce> charger(String eid) async {
    Future<List<R>> lire<T extends Table, R>(TableInfo<T, R> t, Expression<bool> Function(T) filtre) =>
        (_db.select(t)..where(filtre)).get();

    final cats = await (_db.select(_db.categoriesProduits)
          ..where((t) => t.entrepriseId.equals(eid) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.ordre), (t) => OrderingTerm.asc(t.nom)]))
        .get();
    final prods = await (_db.select(_db.produits)
          ..where((t) => t.entrepriseId.equals(eid) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.cleRecherche)]))
        .get();
    final stks = await lire(_db.stocks, (t) => t.entrepriseId.equals(eid) & t.deletedAt.isNull());
    final mvts = await lire(_db.mouvementsStock, (t) => t.entrepriseId.equals(eid) & t.deletedAt.isNull());
    final trfs = await lire(_db.transfertsStock, (t) => t.entrepriseId.equals(eid) & t.deletedAt.isNull());
    final achs = await (_db.select(_db.achats)
          ..where((t) => t.entrepriseId.equals(eid) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.dateAchat), (t) => OrderingTerm.desc(t.creeLe)]))
        .get();
    final recs = await lire(_db.receptions, (t) => t.entrepriseId.equals(eid) & t.deletedAt.isNull());
    final vtes = await (_db.select(_db.ventes)
          ..where((t) => t.entrepriseId.equals(eid) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.dateVente)]))
        .get();
    return EtatCommerce(
      categories: cats.map(CommerceMapper.categorie).toList(),
      produits: prods.map(CommerceMapper.produit).toList(),
      stocks: stks.map(CommerceMapper.stock).toList(),
      mouvements: mvts.map(CommerceMapper.mouvement).toList(),
      transferts: trfs.map(CommerceMapper.transfert).toList(),
      achats: achs.map(CommerceMapper.achat).toList(),
      receptions: recs.map(CommerceMapper.reception).toList(),
      ventes: vtes.map(CommerceMapper.vente).toList(),
    );
  }

  // --- Écritures locales ------------------------------------------------------

  Future<void> insererCategorie(CategorieProduit c) =>
      _db.into(_db.categoriesProduits).insert(CommerceMapper.categorieLocale(c, RecordSyncStatus.pendingSync));

  Future<void> remplacerCategorie(CategorieProduit c) =>
      (_db.update(_db.categoriesProduits)..where((t) => t.id.equals(c.id))).write(
        CommerceMapper.categorieLocale(c, RecordSyncStatus.pendingSync).copyWith(id: const Value.absent()),
      );

  Future<void> insererProduit(Produit p) =>
      _db.into(_db.produits).insert(CommerceMapper.produitLocal(p, RecordSyncStatus.pendingSync));

  Future<void> remplacerProduit(Produit p) => (_db.update(_db.produits)..where((t) => t.id.equals(p.id))).write(
        CommerceMapper.produitLocal(p, RecordSyncStatus.pendingSync).copyWith(id: const Value.absent()),
      );

  /// Mouvement en attente : compté dans le stock affiché jusqu'à la réponse du serveur.
  Future<void> insererMouvement(MouvementStock m) =>
      _db.into(_db.mouvementsStock).insert(CommerceMapper.mouvementLocal(m, RecordSyncStatus.pendingSync));

  Future<void> insererTransfert(Transfert t) =>
      _db.into(_db.transfertsStock).insert(CommerceMapper.transfertLocal(t, RecordSyncStatus.pendingSync));

  Future<void> insererAchat(Achat a) =>
      _db.into(_db.achats).insert(CommerceMapper.achatLocal(a, RecordSyncStatus.pendingSync));

  Future<void> remplacerAchat(Achat a) => (_db.update(_db.achats)..where((t) => t.id.equals(a.id))).write(
        CommerceMapper.achatLocal(a, RecordSyncStatus.pendingSync).copyWith(id: const Value.absent()),
      );

  /// Quantités reçues et statut, comme le serveur le fera (sans changer
  /// l'état de synchronisation de l'achat : la copie serveur le remplacera).
  Future<void> majReceptionAchat(Achat a) => (_db.update(_db.achats)..where((t) => t.id.equals(a.id))).write(
        AchatsCompanion(
          lignes: CommerceMapper.achatLocal(a, RecordSyncStatus.synced).lignes,
          statut: Value(a.statut.code),
        ),
      );

  Future<void> insererReception(Reception r) =>
      _db.into(_db.receptions).insert(CommerceMapper.receptionLocale(r, RecordSyncStatus.pendingSync));

  Future<void> insererVente(Vente v) =>
      _db.into(_db.ventes).insert(CommerceMapper.venteLocale(v, RecordSyncStatus.pendingSync));

  Future<void> remplacerVente(Vente v) => (_db.update(_db.ventes)..where((t) => t.id.equals(v.id))).write(
        CommerceMapper.venteLocale(v, RecordSyncStatus.pendingSync).copyWith(id: const Value.absent()),
      );

  // --- Numéros des reçus ------------------------------------------------------

  /// Séquence suivante du jour pour cette boutique ;
  /// Calcule de manière déterministe et atomique le prochain numéro commercial (offline-first & multi-boutiques).
  Future<({String poste, int sequence})> prochainNumero(
    String entrepriseId,
    String perimetreId,
    String jour,
  ) async {
    final p = await (_db.select(_db.postesVente)..where((t) => t.perimetreId.equals(perimetreId))).getSingleOrNull();
    int dernier = 0;
    String code = '';
    if (p != null) {
      code = p.code;
      dernier = p.jour == jour ? p.dernier : 0;
    } else {
      // Calcul depuis les ventes locales existantes de cette boutique pour ce jour
      final ventesDuJour = await (_db.select(_db.ventes)
            ..where((t) => t.perimetreId.equals(perimetreId) & t.dateCommerciale.equals(jour)))
          .get();
      for (final v in ventesDuJour) {
        if (v.sequence != null && v.sequence! > dernier) {
          dernier = v.sequence!;
        }
      }
    }
    final suivant = dernier + 1;
    await _db.into(_db.postesVente).insertOnConflictUpdate(PostesVenteCompanion.insert(
          perimetreId: perimetreId,
          entrepriseId: entrepriseId,
          code: code,
          jour: jour,
          dernier: Value(suivant),
        ));
    return (poste: code, sequence: suivant);
  }

  /// Lettre attribuée par le serveur ; [derniers] = dernières séquences déjà
  /// utilisées par ce poste (par jour) : le compteur ne recule jamais.
  Future<void> enregistrerPoste({
    required String entrepriseId,
    required String perimetreId,
    required String code,
    required Map<String, int> derniers,
    required String jour,
  }) =>
      _db.transaction(() async {
        final p =
            await (_db.select(_db.postesVente)..where((t) => t.perimetreId.equals(perimetreId))).getSingleOrNull();
        final local = p != null && p.code == code && p.jour == jour ? p.dernier : 0;
        final serveur = derniers[jour] ?? 0;
        await _db.into(_db.postesVente).insertOnConflictUpdate(PostesVenteCompanion.insert(
              perimetreId: perimetreId,
              entrepriseId: entrepriseId,
              code: code,
              jour: jour,
              dernier: Value(local > serveur ? local : serveur),
            ));
      });

  Future<Set<String>> boutiquesAvecPoste() async =>
      {for (final p in await _db.select(_db.postesVente).get()) p.perimetreId};

  // --- Copies locales des sommes dues et paiements créés par le serveur --------

  Future<void> insererEngagement(Engagement e) =>
      _db.into(_db.engagements).insertOnConflictUpdate(FinancesMapper.engagementLocal(e, RecordSyncStatus.synced));

  Future<void> majEngagement(String id, {int? montantTotal, String? contactId, bool? annule}) =>
      (_db.update(_db.engagements)..where((t) => t.id.equals(id))).write(EngagementsCompanion(
        montantTotal: montantTotal == null ? const Value.absent() : Value(montantTotal),
        contactId: contactId == null ? const Value.absent() : Value(contactId),
        statut: annule == true ? const Value('ANNULE') : const Value.absent(),
      ));

  Future<void> insererPaiement(Paiement p, {MouvementCaisse? mouvement, required String perimetreId}) async {
    await _db.into(_db.paiements).insert(FinancesMapper.paiementLocal(p, RecordSyncStatus.pendingSync));
    for (final a in p.affectations) {
      await _db.into(_db.paiementAffectations).insert(FinancesMapper.affectationLocale(p, a));
    }
    if (mouvement != null) {
      await _db.into(_db.caisseMouvements).insert(FinancesMapper.mouvementLocal(
            mouvement,
            entrepriseId: p.entrepriseId,
            perimetreId: perimetreId,
            statut: RecordSyncStatus.synced,
          ));
    }
  }

  Future<void> marquerPaiement(String id, RecordSyncStatus statut) =>
      (_db.update(_db.paiements)..where((t) => t.id.equals(id))).write(PaiementsCompanion(syncStatus: Value(statut.wire)));

  Future<void> marquerEngagement(String id, RecordSyncStatus statut) =>
      (_db.update(_db.engagements)..where((t) => t.id.equals(id)))
          .write(EngagementsCompanion(syncStatus: Value(statut.wire)));

  /// Mouvements créés par une opération (transfert, réception, vente).
  /// Applique atomiquement leurs deltas à la table locale des stocks si le statut
  /// devient synchronisé, pour éviter toute régression avant la descente serveur.
  Future<void> marquerMouvementsDe(String origineId, RecordSyncStatus statut) =>
      _db.transaction(() async {
        final pending = await (_db.select(_db.mouvementsStock)
              ..where((t) => t.origineId.equals(origineId) & t.syncStatus.equals(RecordSyncStatus.pendingSync.wire)))
            .get();
        if (statut == RecordSyncStatus.synced && pending.isNotEmpty) {
          for (final m in pending) {
            await _appliquerDeltaStock(m);
          }
        }
        await (_db.update(_db.mouvementsStock)
              ..where((t) => t.origineId.equals(origineId) & t.syncStatus.equals(RecordSyncStatus.pendingSync.wire)))
            .write(MouvementsStockCompanion(syncStatus: Value(statut.wire)));
      });

  Future<void> appliquerMouvementAuStock(String mouvementId) => _db.transaction(() async {
        final m = await (_db.select(_db.mouvementsStock)
              ..where((t) => t.id.equals(mouvementId) & t.syncStatus.equals(RecordSyncStatus.pendingSync.wire)))
            .getSingleOrNull();
        if (m != null) {
          await _appliquerDeltaStock(m);
        }
      });

  Future<void> _appliquerDeltaStock(MouvementStockRow m) async {
    if (m.delta == 0) return;
    final existants = await (_db.select(_db.stocks)
          ..where((t) => t.produitId.equals(m.produitId) & t.perimetreId.equals(m.perimetreId) & t.deletedAt.isNull()))
        .get();
    if (existants.isNotEmpty) {
      final premier = existants.first;
      await (_db.update(_db.stocks)..where((t) => t.id.equals(premier.id))).write(
        StocksCompanion(
          quantite: Value(premier.quantite + m.delta),
          updatedAt: Value(DateTime.now()),
        ),
      );
      // Nettoyer les doublons éventuels pour garantir l'unicité
      for (final doublon in existants.skip(1)) {
        await (_db.delete(_db.stocks)..where((t) => t.id.equals(doublon.id))).go();
      }
    } else {
      await _db.into(_db.stocks).insert(
        StocksCompanion.insert(
          id: const Uuid().v4(),
          entrepriseId: m.entrepriseId,
          perimetreId: m.perimetreId,
          produitId: m.produitId,
          quantite: Value(m.stockApres ?? (m.delta > 0 ? m.delta : 0)),
          syncStatus: RecordSyncStatus.synced.wire,
        ),
      );
    }
  }

  /// Supprime une écriture jamais acceptée par le serveur et ce qui en découle.
  Future<void> retirer(String table, String id) async {
    switch (table) {
      case 'ventes':
        final v = await ventes.ligne(id);
        await (_db.delete(_db.mouvementsStock)..where((t) => t.origineId.equals(id))).go();
        if (v?.paiementId case final paiementId?) {
          await (_db.delete(_db.paiementAffectations)..where((t) => t.paiementId.equals(paiementId))).go();
          await (_db.delete(_db.caisseMouvements)..where((t) => t.paiementId.equals(paiementId))).go();
          await (_db.delete(_db.paiements)..where((t) => t.id.equals(paiementId))).go();
        }
        await (_db.delete(_db.engagements)..where((t) => t.id.equals(id))).go();
        await ventes.supprimer(id);
      case 'achats':
        await (_db.delete(_db.engagements)..where((t) => t.id.equals(id))).go();
        await achats.supprimer(id);
      case 'transferts_stock' || 'receptions':
        await (_db.delete(_db.mouvementsStock)..where((t) => t.origineId.equals(id))).go();
        await tous.firstWhere((s) => s.table == table).supprimer(id);
      default:
        await tous.firstWhere((s) => s.table == table).supprimer(id);
    }
  }
}

/// Stockage miroir spécifique pour la table `stocks` évitant les doublons
/// entre l'UUID généré localement et l'UUID officiel du serveur Supabase.
class StockageStocks extends StockageMiroir<$StocksTable, StockRow> {
  StockageStocks(
    AppDatabase db,
    $StocksTable info, {
    required super.versLocal,
    required super.statutDe,
    required super.versionDe,
  })  : database = db,
        super(db, info);

  final AppDatabase database;

  @override
  Future<void> ecrireDepuisServeur(Map<String, dynamic> json, RecordSyncStatus statut) async {
    final produitId = json['produit_id'] as String?;
    final perimetreId = json['perimetre_id'] as String?;
    final id = json['id'] as String?;
    if (produitId != null && perimetreId != null && id != null) {
      // Éliminer toute ligne locale pour ce même produit et périmètre ayant un identifiant différent
      await (database.delete(database.stocks)
            ..where((t) => t.produitId.equals(produitId) & t.perimetreId.equals(perimetreId) & t.id.equals(id).not()))
          .go();
    }
    await super.ecrireDepuisServeur(json, statut);
  }
}

