import '../../../core/errors/failure.dart';
import '../../../core/sync/standard_sync_handler.dart';
import '../../../core/sync/sync_contracts.dart';
import '../../../core/sync/sync_models.dart';
import '../../finances/domain/entities/finances.dart';
import '../domain/commerce_repository.dart';
import '../domain/entities/commerce.dart';
import '../domain/services/etat_commerce.dart';
import 'commerce_local_data_source.dart';
import 'commerce_mapper.dart';

/// UI → Repository → SQLite + file de synchronisation → (moteur) → Supabase.
class CommerceRepositoryImpl implements CommerceRepository {
  CommerceRepositoryImpl({
    required CommerceLocalDataSource local,
    required SyncQueueStore queue,
    required String? Function() currentUserId,
    required SyncTrigger requestSync,
  })  : _local = local,
        _queue = queue,
        _currentUserId = currentUserId,
        _requestSync = requestSync;

  final CommerceLocalDataSource _local;
  final SyncQueueStore _queue;
  final String? Function() _currentUserId;
  final SyncTrigger _requestSync;

  @override
  Stream<EtatCommerce> watch(String entrepriseId) => _local.watch(entrepriseId);

  @override
  Future<void> creerCategorie(CategorieProduit c) => _ecrire((uid) async {
        await _local.insererCategorie(c);
        await _envoyer(uid, 'categories_produits', c.id, SyncOperationType.insert,
            CommerceMapper.categoriePayload(c, creation: true));
      });

  @override
  Future<void> modifierCategorie(CategorieProduit avant, CategorieProduit apres) => _ecrire((uid) async {
        await _local.remplacerCategorie(apres);
        await _envoyer(uid, 'categories_produits', apres.id, SyncOperationType.update,
            CommerceMapper.categoriePayload(apres),
            baseVersion: avant.version, fusionner: false);
      });

  @override
  Future<void> creerProduit(Produit p, {MouvementStock? stockInitial, LotStock? lotInitial}) => _ecrire((uid) async {
        await _local.insererProduit(p);
        await _envoyer(uid, 'produits', p.id, SyncOperationType.insert, CommerceMapper.produitPayload(p, creation: true));
        if (lotInitial != null) {
          await _local.insererLot(lotInitial);
          await _envoyer(uid, 'lots_stock', lotInitial.id, SyncOperationType.insert,
              CommerceMapper.lotPayload(lotInitial, creation: true));
        }
        if (stockInitial != null) {
          await _local.insererMouvement(stockInitial);
          await _envoyer(uid, 'mouvements_stock', stockInitial.id, SyncOperationType.insert,
              CommerceMapper.mouvementPayload(stockInitial));
        }
      });

  @override
  Future<void> modifierProduit(Produit avant, Produit apres) => _ecrire((uid) async {
        await _local.remplacerProduit(apres);
        await _envoyer(uid, 'produits', apres.id, SyncOperationType.update, CommerceMapper.produitPayload(apres),
            baseVersion: avant.version,
            // « est_actif » n'est pas accepté à la création.
            fusionner: avant.estActif == apres.estActif);
      });

  @override
  Future<void> modifierLot(LotStock lot) => _ecrire((uid) async {
        await _local.remplacerLot(lot);
        await _envoyer(uid, 'lots_stock', lot.id, SyncOperationType.update, CommerceMapper.lotPayload(lot),
            baseVersion: lot.version);
      });

  @override
  Future<void> supprimerProduit(Produit p) => _ecrire((uid) async {
        await _local.retirer('produits', p.id);
        await _envoyer(uid, 'produits', p.id, SyncOperationType.delete, const {}, baseVersion: p.version);
      });

  @override
  Future<void> enregistrerMouvement(MouvementStock m, {LotStock? lotCree}) => _ecrire((uid) async {
        if (lotCree != null) {
          await _local.insererLot(lotCree);
          await _envoyer(uid, 'lots_stock', lotCree.id, SyncOperationType.insert, CommerceMapper.lotPayload(lotCree, creation: true));
        }
        await _local.insererMouvement(m);
        await _envoyer(uid, 'mouvements_stock', m.id, SyncOperationType.insert, CommerceMapper.mouvementPayload(m));
      });

  @override
  Future<void> transferer(
    Transfert t, {
    required MouvementStock sortie,
    required MouvementStock entree,
    List<LotStock> lotsModifies = const [],
    List<LotStock> lotsCrees = const [],
  }) =>
      _ecrire((uid) async {
        await _local.insererTransfert(t);
        for (final l in lotsModifies) {
          await _local.remplacerLot(l);
        }
        for (final l in lotsCrees) {
          await _local.insererLot(l);
          await _envoyer(uid, 'lots_stock', l.id, SyncOperationType.insert,
              CommerceMapper.lotPayload(l, creation: true));
        }
        await _local.insererMouvement(sortie);
        await _local.insererMouvement(entree);
        await _envoyer(uid, 'transferts_stock', t.id, SyncOperationType.insert, CommerceMapper.transfertPayload(t));
      });

  @override
  Future<void> creerAchat(Achat a, {Engagement? dette, Reception? reception, List<MouvementStock> entrees = const [],
          Achat? achatRecu, List<LotStock> lotsCrees = const []}) =>
      _ecrire((uid) async {
        await _local.insererAchat(a);
        if (dette != null) await _local.insererEngagement(dette);
        await _envoyer(uid, 'achats', a.id, SyncOperationType.insert, CommerceMapper.achatPayload(a, creation: true));
        if (reception != null) {
          await _receptionner(uid, reception, entrees, achatRecu ?? a, lotsCrees);
        }
      });

  @override
  Future<void> modifierAchat(Achat avant, Achat apres) => _ecrire((uid) async {
        await _local.remplacerAchat(apres);
        await _local.majEngagement(apres.id,
            montantTotal: apres.total > 0 ? apres.total : null,
            contactId: apres.fournisseurId,
            annule: apres.annule);
        await _envoyer(uid, 'achats', apres.id, SyncOperationType.update, CommerceMapper.achatPayload(apres),
            baseVersion: avant.version,
            // Le statut n'est pas accepté à la création.
            fusionner: avant.statut == apres.statut);
      });

  @override
  Future<void> receptionner(Reception r, {required List<MouvementStock> entrees, required Achat achatRecu, List<LotStock> lotsCrees = const []}) =>
      _ecrire((uid) => _receptionner(uid, r, entrees, achatRecu, lotsCrees));

  Future<void> _receptionner(String uid, Reception r, List<MouvementStock> entrees, Achat achatRecu,
      [List<LotStock> lotsCrees = const []]) async {
    await _local.insererReception(r);
    for (final l in lotsCrees) {
      await _local.insererLot(l);
      await _envoyer(uid, 'lots_stock', l.id, SyncOperationType.insert, CommerceMapper.lotPayload(l, creation: true));
    }
    for (final m in entrees) {
      await _local.insererMouvement(m);
    }
    await _local.majReceptionAchat(achatRecu);
    await _envoyer(uid, 'receptions', r.id, SyncOperationType.insert, CommerceMapper.receptionPayload(r));
  }

  @override
  Future<Vente> vendre(Vente v,
      {required List<MouvementStock> sorties,
      List<LotStock> lotsModifies = const [],
      Engagement? creance,
      Paiement? paiement,
      MouvementCaisse? mouvementCaisse}) async {
    var numerotee = v;
    await _ecrire((uid) async {
      final jour = v.dateCommerciale ?? jourCommercial(v.date);
      final numInfo = await _local.prochainNumero(v.entrepriseId, v.perimetreId, jour);
      numerotee = v.numerotee(poste: numInfo.poste, sequence: numInfo.sequence, dateCommerciale: jour);
      await _local.insererVente(numerotee);
      for (final lot in lotsModifies) {
        await _local.remplacerLot(lot);
      }
      for (final m in sorties) {
        await _local.insererMouvement(m);
      }
      if (creance != null) await _local.insererEngagement(creance);
      if (paiement != null) {
        await _local.insererPaiement(paiement, mouvement: mouvementCaisse, perimetreId: v.perimetreId);
      }
      await _envoyer(uid, 'ventes', v.id, SyncOperationType.insert, CommerceMapper.ventePayload(numerotee));
    });
    return numerotee;
  }

  @override
  Future<void> annulerVente(Vente avant, Vente apres, {required List<MouvementStock> retours}) => _ecrire((uid) async {
        await _local.remplacerVente(apres);
        for (final l in avant.lignes) {
          if (l.lots.isNotEmpty) {
            await _local.restaurerLots(l.lots);
          }
        }
        for (final m in retours) {
          await _local.insererMouvement(m);
        }
        await _local.majEngagement(apres.id, annule: true);
        await _envoyer(uid, 'ventes', apres.id, SyncOperationType.update,
            {'statut': 'ANNULEE', 'motif_annulation': apres.motifAnnulation, 'note': apres.note},
            baseVersion: avant.version, fusionner: false);
      });

  @override
  Future<void> retirerRefuse(String table, String id) => _ecrire((_) async {
        await _local.retirer(table, id);
        await _queue.abandonner(table, id);
      }, synchroniser: false);

  Future<void> _envoyer(String uid, String table, String id, SyncOperationType type, Map<String, dynamic> payload,
          {int? baseVersion, bool fusionner = true}) =>
      _queue.enqueue(
        userId: uid,
        entityTable: table,
        recordId: id,
        type: type,
        payload: payload,
        baseVersion: baseVersion,
        fusionner: fusionner,
      );

  Future<void> _ecrire(Future<void> Function(String userId) action, {bool synchroniser = true}) async {
    final uid = _currentUserId() ?? (throw const Failure(FailureKind.sessionExpired));
    try {
      await _local.enTransaction(() => action(uid));
    } on Failure {
      rethrow;
    } catch (e, st) {
      throw Failure(FailureKind.localStorage, cause: e, stackTrace: st);
    }
    if (synchroniser) _requestSync();
  }
}

/// Synchronisation du Commerce. L'ordre compte à la descente : catalogue,
/// opérations, puis stock serveur et mouvements (l'un juste après l'autre,
/// pour que le stock affiché reste juste).
List<SyncEntityHandler> commerceSyncHandlers(CommerceLocalDataSource local, SyncCursorStore cursors) => [
      StandardSyncHandler(local.categories, cursors, local.enTransaction),
      StandardSyncHandler(local.produits, cursors, local.enTransaction),
      StandardSyncHandler(local.lots, cursors, local.enTransaction),
      OperationSyncHandler(local.achats, local, cursors, dettesEtPaiements: true),
      OperationSyncHandler(local.receptions, local, cursors),
      OperationSyncHandler(local.ventes, local, cursors, dettesEtPaiements: true),
      OperationSyncHandler(local.transferts, local, cursors),
      StandardSyncHandler(local.stocks, cursors, local.enTransaction),
      MouvementsSyncHandler(local.mouvements, local, cursors),
    ];

/// Gestionnaire de mouvements de stock : répercute le mouvement sur le stock local
/// dès que le serveur confirme sa création, évitant tout écart d'affichage.
class MouvementsSyncHandler extends StandardSyncHandler {
  MouvementsSyncHandler(
    StockageSynchronise stockage,
    this._local,
    SyncCursorStore curseurs,
  ) : super(stockage, curseurs, _local.enTransaction);

  final CommerceLocalDataSource _local;

  @override
  Future<void> onPushApplied(SyncOperation op, Map<String, dynamic>? serverRow) async {
    await _local.appliquerMouvementAuStock(op.recordId);
    await super.onPushApplied(op, serverRow);
  }
}

/// Opération qui crée d'autres lignes côté serveur (mouvements de stock,
/// somme due, paiement) : leurs copies locales suivent son sort.
class OperationSyncHandler extends StandardSyncHandler {
  OperationSyncHandler(
    StockageSynchronise stockage,
    this._local,
    this._curseurs, {
    this.dettesEtPaiements = false,
  }) : super(stockage, _curseurs, _local.enTransaction);

  final CommerceLocalDataSource _local;
  final SyncCursorStore _curseurs;
  final bool dettesEtPaiements;

  @override
  Future<void> onPushApplied(SyncOperation op, Map<String, dynamic>? serverRow) async {
    await super.onPushApplied(op, serverRow);
    if (op.type != SyncOperationType.insert && op.type != SyncOperationType.update) return;
    // Le serveur a validé l'opération : on répercute les mouvements sur le stock local
    // en même temps qu'ils passent à synced, garantissant une cohérence immédiate.
    await _local.marquerMouvementsDe(op.recordId, RecordSyncStatus.synced);
    if (op.payload['paiement_id'] case final String paiementId) {
      await _local.marquerPaiement(paiementId, RecordSyncStatus.synced);
    }
  }

  @override
  Future<void> onRejected(SyncOperation op, Failure failure) async {
    await super.onRejected(op, failure);
    if (op.type != SyncOperationType.insert) {
      await _curseurs.reset('mouvements_stock');
      return;
    }
    // Rien n'a été créé : les copies locales sortent des totaux.
    await _local.marquerMouvementsDe(op.recordId, RecordSyncStatus.syncError);
    if (dettesEtPaiements) {
      await _local.marquerEngagement(op.recordId, RecordSyncStatus.syncError);
      if (op.payload['paiement_id'] case final String paiementId) {
        await _local.marquerPaiement(paiementId, RecordSyncStatus.syncError);
      }
      await _curseurs.reset('engagements');
    }
  }
}
