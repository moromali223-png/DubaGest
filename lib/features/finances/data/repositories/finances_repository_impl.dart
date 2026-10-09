import '../../../../core/errors/failure.dart';
import '../../../../core/sync/standard_sync_handler.dart';
import '../../../../core/sync/sync_contracts.dart';
import '../../../../core/sync/sync_models.dart';
import '../../domain/entities/finances.dart';
import '../../domain/repositories/finances_repository.dart';
import '../../domain/services/etat_finances.dart';
import '../datasources/finances_local_data_source.dart';
import '../models/finances_mapper.dart';

class FinancesRepositoryImpl implements FinancesRepository {
  FinancesRepositoryImpl({
    required FinancesLocalDataSource local,
    required SyncQueueStore queue,
    required String? Function() currentUserId,
    required SyncTrigger requestSync,
  }) : _local = local,
       _queue = queue,
       _currentUserId = currentUserId,
       _requestSync = requestSync;

  final FinancesLocalDataSource _local;
  final SyncQueueStore _queue;
  final String? Function() _currentUserId;
  final SyncTrigger _requestSync;

  @override
  Stream<EtatFinances> watch(String entrepriseId) => _local.watch(entrepriseId);

  @override
  Future<void> creerEngagement(Engagement e) => _ecrire((uid) async {
    await _local.insererEngagement(e);
    await _envoyer(uid, 'engagements', e.id, SyncOperationType.insert, FinancesMapper.engagementCreation(e));
  });

  @override
  Future<void> modifierEngagement(Engagement avant, Engagement apres) => _ecrire((uid) async {
    await _local.remplacerEngagement(apres);
    await _envoyer(
      uid,
      'engagements',
      apres.id,
      SyncOperationType.update,
      FinancesMapper.engagementModification(apres),
      baseVersion: avant.version,
      // Statut et motif ne sont pas acceptés à la création.
      fusionner: false,
    );
  });

  @override
  Future<void> enregistrerPaiement(Paiement p, {MouvementCaisse? mouvement}) => _ecrire((uid) async {
    await _local.insererPaiement(p, mouvement: mouvement);
    await _envoyer(uid, 'paiements', p.id, SyncOperationType.insert, FinancesMapper.paiementCreation(p));
  });

  @override
  Future<void> creerCaisse(Caisse c) => _ecrire((uid) async {
    await _local.insererCaisse(c);
    await _envoyer(uid, 'caisses', c.id, SyncOperationType.insert, {
      'entreprise_id': c.entrepriseId,
      'perimetre_id': c.perimetreId,
      'nom': c.nom,
    });
  });

  @override
  Future<void> ouvrirSession(SessionCaisse s) => _ecrire((uid) async {
    await _local.insererSession(s);
    await _envoyer(uid, 'caisse_sessions', s.id, SyncOperationType.insert, {
      'entreprise_id': s.entrepriseId,
      'caisse_id': s.caisseId,
      'solde_initial': s.soldeInitial,
    });
  });

  @override
  Future<void> cloturerSession(SessionCaisse s, {required int soldeReel, String? note, MotifEcart? motifEcart}) =>
      _ecrire((uid) async {
        await _local.cloturerSession(s.id, soldeReel: soldeReel, note: note, motifEcart: motifEcart);
        await _envoyer(
          uid,
          'caisse_sessions',
          s.id,
          SyncOperationType.update,
          {'statut': 'FERMEE', 'solde_reel': soldeReel, 'note_cloture': note, 'motif_ecart': motifEcart?.code},
          baseVersion: s.version,
          // Clôture envoyée après l'ouverture et après les mouvements de la session.
          fusionner: false,
        );
      });

  @override
  Future<void> enregistrerTransfert(TransfertTresorerie t, {required List<(Paiement, MouvementCaisse?)> jambes}) =>
      _ecrire((uid) async {
        await _local.insererTransfert(t, jambes: jambes);
        await _envoyer(
          uid,
          'transferts_tresorerie',
          t.id,
          SyncOperationType.insert,
          FinancesMapper.transfertCreation(t),
        );
      });

  @override
  Future<void> annulerTransfert(
    TransfertTresorerie avant,
    TransfertTresorerie apres, {
    required List<(Paiement, MouvementCaisse?)> jambes,
  }) => _ecrire((uid) async {
    await _local.annulerTransfert(apres, jambes: jambes);
    await _envoyer(
      uid,
      'transferts_tresorerie',
      apres.id,
      SyncOperationType.update,
      {
        'statut': 'ANNULE',
        'motif_annulation': apres.motifAnnulation,
        'annulation_sortie_id': apres.annulationSortieId,
        'annulation_entree_id': apres.annulationEntreeId,
      },
      baseVersion: avant.version,
      // L'annulation part après la création, jamais fusionnée avec elle.
      fusionner: false,
    );
  });

  @override
  Future<void> mouvementManuel(MouvementCaisse m, {required String entrepriseId}) => _ecrire((uid) async {
    final session = await _local.sessions.ligne(m.sessionId);
    await _local.insererMouvement(m, entrepriseId: entrepriseId, perimetreId: session?.perimetreId ?? '');
    await _envoyer(uid, 'caisse_mouvements', m.id, SyncOperationType.insert, {
      'entreprise_id': entrepriseId,
      'session_id': m.sessionId,
      'type': m.type.code,
      'montant': m.montant,
      'motif': m.motif,
    });
  });

  @override
  Future<void> enregistrerDepense(
    Depense d, {
    required Engagement engagement,
    Paiement? paiement,
    MouvementCaisse? mouvement,
  }) => _ecrire((uid) async {
    await _local.insererDepense(d, engagement: engagement, paiement: paiement, mouvement: mouvement);
    await _envoyer(uid, 'depenses', d.id, SyncOperationType.insert, FinancesMapper.depenseCreation(d));
  });

  @override
  Future<void> modifierDepense(Depense avant, Depense apres) => _ecrire((uid) async {
    await _local.remplacerDepense(apres);
    await _envoyer(
      uid,
      'depenses',
      apres.id,
      SyncOperationType.update,
      FinancesMapper.depenseModification(apres),
      baseVersion: avant.version,
      // Statut et motif refusés à la création ; et l'annulation doit
      // partir après l'annulation du paiement.
      fusionner: false,
    );
  });

  @override
  Future<void> creerCourante(DepenseCourante c) => _ecrire((uid) async {
    await _local.insererCourante(c);
    await _envoyer(uid, 'depenses_courantes', c.id, SyncOperationType.insert, FinancesMapper.couranteCreation(c));
  });

  @override
  Future<void> modifierCourante(DepenseCourante avant, DepenseCourante apres) => _ecrire((uid) async {
    await _local.remplacerCourante(apres);
    await _envoyer(
      uid,
      'depenses_courantes',
      apres.id,
      SyncOperationType.update,
      FinancesMapper.couranteModification(apres),
      baseVersion: avant.version,
    );
  });

  @override
  Future<void> creerCategorie(CategorieDepense c) => _ecrire((uid) async {
    await _local.insererCategorie(c);
    await _envoyer(uid, 'depense_categories', c.id, SyncOperationType.insert, {
      'entreprise_id': c.entrepriseId,
      'nom': c.nom,
      'ordre': c.ordre,
    });
  });

  @override
  Future<void> modifierCategorie(CategorieDepense avant, {String? nom, bool? estActive}) => _ecrire((uid) async {
    final apres = CategorieDepense(
      id: avant.id,
      entrepriseId: avant.entrepriseId,
      code: avant.code,
      nom: nom ?? avant.nom,
      estActive: estActive ?? avant.estActive,
      ordre: avant.ordre,
      version: avant.version,
    );
    await _local.remplacerCategorie(apres);
    await _envoyer(
      uid,
      'depense_categories',
      avant.id,
      SyncOperationType.update,
      {'nom': apres.nom, 'est_active': apres.estActive, 'ordre': apres.ordre},
      baseVersion: avant.version,
      fusionner: false,
    );
  });

  @override
  Future<void> retirerRefuse(String table, String id) => _ecrire((_) async {
    await _local.retirer(table, id);
    await _queue.abandonner(table, id);
  }, synchroniser: false);

  Future<void> _envoyer(
    String uid,
    String table,
    String id,
    SyncOperationType type,
    Map<String, dynamic> payload, {
    int? baseVersion,
    bool fusionner = true,
  }) => _queue.enqueue(
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

/// Une table financière synchronisée = la politique commune du socle.
/// L'ordre compte à la descente : les engagements et les sessions avant les
/// paiements et mouvements qui s'y rapportent.
List<SyncEntityHandler> financesSyncHandlers(FinancesLocalDataSource local, SyncCursorStore cursors) => [
  StandardSyncHandler(local.categories, cursors, local.enTransaction),
  StandardSyncHandler(local.courantes, cursors, local.enTransaction),
  DepensesSyncHandler(local, cursors),
  for (final s in [local.engagements, local.caisses, local.sessions])
    StandardSyncHandler(s, cursors, local.enTransaction),
  TransfertsSyncHandler(local, cursors),
  for (final s in [local.paiements, local.affectations, local.mouvements])
    StandardSyncHandler(s, cursors, local.enTransaction),
];

/// Transferts : politique commune, plus le sort des copies locales de leurs
/// jambes (paiements créés par le serveur avec le transfert ou son annulation).
class TransfertsSyncHandler extends StandardSyncHandler {
  TransfertsSyncHandler(this._local, this._curseurs) : super(_local.transferts, _curseurs, _local.enTransaction);

  final FinancesLocalDataSource _local;
  final SyncCursorStore _curseurs;

  List<String> _jambes(SyncOperation op) => [
    for (final cle in ['sortie_id', 'entree_id', 'annulation_sortie_id', 'annulation_entree_id'])
      if (op.payload[cle] case final String id) id,
  ];

  @override
  Future<void> onPushApplied(SyncOperation op, Map<String, dynamic>? serverRow) async {
    await super.onPushApplied(op, serverRow);
    // Les jambes existent côté serveur : leurs copies serveur suivront.
    for (final id in _jambes(op)) {
      await _local.paiements.marquer(id, RecordSyncStatus.synced);
    }
  }

  @override
  Future<void> onRejected(SyncOperation op, Failure failure) async {
    await super.onRejected(op, failure);
    // Rien n'a été créé : les jambes locales sont exclues des soldes, et le
    // transfert (annulation refusée) est relu depuis le serveur.
    for (final id in _jambes(op)) {
      await _local.paiements.marquer(id, RecordSyncStatus.syncError);
    }
    if (op.type == SyncOperationType.update) {
      await _local.transferts.mettreAJourVersion(op.recordId, -1);
      await _curseurs.reset('transferts_tresorerie');
    }
  }
}

/// Dépenses : politique commune, plus le sort des copies locales de ce que
/// le serveur crée avec elles (somme à payer, paiement).
class DepensesSyncHandler extends StandardSyncHandler {
  DepensesSyncHandler(this._local, this._curseurs) : super(_local.depenses, _curseurs, _local.enTransaction);

  final FinancesLocalDataSource _local;
  final SyncCursorStore _curseurs;

  @override
  Future<void> onPushApplied(SyncOperation op, Map<String, dynamic>? serverRow) async {
    await super.onPushApplied(op, serverRow);
    // Le paiement immédiat existe désormais côté serveur : sa copie serveur
    // (descente du même cycle) remplacera la copie locale.
    if (op.payload['paiement_id'] case final String paiementId) {
      await _local.paiements.marquer(paiementId, RecordSyncStatus.synced);
    }
  }

  @override
  Future<void> onRejected(SyncOperation op, Failure failure) async {
    await super.onRejected(op, failure);
    // Rien n'a été créé : la somme liée et le paiement sont exclus des totaux
    // (création) ou rechargés depuis le serveur (modification refusée).
    await _local.engagements.marquer(op.recordId, RecordSyncStatus.syncError);
    final paiementId = op.payload['paiement_id'] as String?;
    if (paiementId != null) await _local.paiements.marquer(paiementId, RecordSyncStatus.syncError);
    await _curseurs.reset('engagements');
    // L'échéance avancée sur l'appareil n'a pas été payée : la courante est
    // relue (version locale invalidée, sinon la descente la jugerait à jour).
    if (op.payload['courante_id'] case final String couranteId) {
      await _local.courantes.mettreAJourVersion(couranteId, -1);
      await _curseurs.reset('depenses_courantes');
    }
  }
}
