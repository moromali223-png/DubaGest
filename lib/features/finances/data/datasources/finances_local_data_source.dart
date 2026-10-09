import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/stockage_miroir.dart';
import '../../../../core/sync/sync_models.dart';
import '../../domain/entities/finances.dart';
import '../../domain/services/etat_finances.dart';
import '../models/finances_mapper.dart';

/// Données financières sur l'appareil : consultables et saisissables hors-ligne.
class FinancesLocalDataSource {
  FinancesLocalDataSource(this._db)
    : engagements = StockageMiroir(
        _db,
        _db.engagements,
        versLocal: FinancesMapper.engagementServeur,
        statutDe: (r) => r.syncStatus,
        versionDe: (r) => r.version,
        identique: FinancesMapper.engagementIdentique,
      ),
      paiements = StockageMiroir(
        _db,
        _db.paiements,
        versLocal: FinancesMapper.paiementServeur,
        statutDe: (r) => r.syncStatus,
        versionDe: (r) => r.version,
      ),
      affectations = StockageMiroir(
        _db,
        _db.paiementAffectations,
        versLocal: FinancesMapper.affectationServeur,
        statutDe: (r) => r.syncStatus,
        versionDe: (r) => r.version,
      ),
      caisses = StockageMiroir(
        _db,
        _db.caisses,
        versLocal: FinancesMapper.caisseServeur,
        statutDe: (r) => r.syncStatus,
        versionDe: (r) => r.version,
        identique: FinancesMapper.caisseIdentique,
      ),
      sessions = StockageMiroir(
        _db,
        _db.caisseSessions,
        versLocal: FinancesMapper.sessionServeur,
        statutDe: (r) => r.syncStatus,
        versionDe: (r) => r.version,
        identique: FinancesMapper.sessionIdentique,
      ),
      mouvements = StockageMiroir(
        _db,
        _db.caisseMouvements,
        versLocal: FinancesMapper.mouvementServeur,
        statutDe: (r) => r.syncStatus,
        versionDe: (r) => r.version,
      ),
      categories = StockageMiroir(
        _db,
        _db.depenseCategories,
        versLocal: FinancesMapper.categorieServeur,
        statutDe: (r) => r.syncStatus,
        versionDe: (r) => r.version,
        identique: FinancesMapper.categorieIdentique,
      ),
      depenses = StockageMiroir(
        _db,
        _db.depenses,
        versLocal: FinancesMapper.depenseServeur,
        statutDe: (r) => r.syncStatus,
        versionDe: (r) => r.version,
        identique: FinancesMapper.depenseIdentique,
      ),
      courantes = StockageMiroir(
        _db,
        _db.depensesCourantes,
        versLocal: FinancesMapper.couranteServeur,
        statutDe: (r) => r.syncStatus,
        versionDe: (r) => r.version,
        identique: FinancesMapper.couranteIdentique,
      ),
      transferts = StockageMiroir(
        _db,
        _db.transfertsTresorerie,
        versLocal: FinancesMapper.transfertServeur,
        statutDe: (r) => r.syncStatus,
        versionDe: (r) => r.version,
        identique: FinancesMapper.transfertIdentique,
      );

  final AppDatabase _db;
  final StockageMiroir<$EngagementsTable, EngagementRow> engagements;
  final StockageMiroir<$PaiementsTable, PaiementRow> paiements;
  final StockageMiroir<$PaiementAffectationsTable, AffectationRow> affectations;
  final StockageMiroir<$CaissesTable, CaisseRow> caisses;
  final StockageMiroir<$CaisseSessionsTable, SessionCaisseRow> sessions;
  final StockageMiroir<$CaisseMouvementsTable, MouvementCaisseRow> mouvements;
  final StockageMiroir<$DepenseCategoriesTable, CategorieDepenseRow> categories;
  final StockageMiroir<$DepensesTable, DepenseRow> depenses;
  final StockageMiroir<$DepensesCourantesTable, DepenseCouranteRow> courantes;
  final StockageMiroir<$TransfertsTresorerieTable, TransfertRow> transferts;

  List<StockageMiroir> get tous => [
    engagements,
    paiements,
    affectations,
    caisses,
    sessions,
    mouvements,
    categories,
    depenses,
    courantes,
    transferts,
  ];

  Future<void> enTransaction(Future<void> Function() action) => _db.transaction(action);

  /// Réémis à chaque écriture locale ou synchronisation d'une table financière.
  Stream<EtatFinances> watch(String entrepriseId) async* {
    yield await charger(entrepriseId);
    await for (final _ in _db.tableUpdates(TableUpdateQuery.onAllTables(_db.tablesFinances))) {
      yield await charger(entrepriseId);
    }
  }

  Future<EtatFinances> charger(String eid) async {
    final engs =
        await (_db.select(_db.engagements)
              ..where((t) => t.entrepriseId.equals(eid) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.dateEngagement)]))
            .get();
    final pais =
        await (_db.select(_db.paiements)
              ..where((t) => t.entrepriseId.equals(eid) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.datePaiement)]))
            .get();
    final cais =
        await (_db.select(_db.caisses)
              ..where((t) => t.entrepriseId.equals(eid) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.nom)]))
            .get();
    final sess = await (_db.select(
      _db.caisseSessions,
    )..where((t) => t.entrepriseId.equals(eid) & t.deletedAt.isNull())).get();
    final mvts = await (_db.select(
      _db.caisseMouvements,
    )..where((t) => t.entrepriseId.equals(eid) & t.deletedAt.isNull())).get();
    final cats =
        await (_db.select(_db.depenseCategories)
              ..where((t) => t.entrepriseId.equals(eid) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.ordre)]))
            .get();
    final deps =
        await (_db.select(_db.depenses)
              ..where((t) => t.entrepriseId.equals(eid) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.dateDepense)]))
            .get();
    final cours =
        await (_db.select(_db.depensesCourantes)
              ..where((t) => t.entrepriseId.equals(eid) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.prochaineEcheance)]))
            .get();
    final trans =
        await (_db.select(_db.transfertsTresorerie)
              ..where((t) => t.entrepriseId.equals(eid) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.dateTransfert)]))
            .get();
    return EtatFinances(
      transferts: trans.map(FinancesMapper.transfert).toList(),
      categories: cats.map(FinancesMapper.categorie).toList(),
      depenses: deps.map(FinancesMapper.depense).toList(),
      courantes: cours.map(FinancesMapper.courante).toList(),
      engagements: engs.map(FinancesMapper.engagement).toList(),
      paiements: pais.map(FinancesMapper.paiement).toList(),
      caisses: cais.map(FinancesMapper.caisse).toList(),
      sessions: sess.map(FinancesMapper.session).toList(),
      mouvements: mvts.map(FinancesMapper.mouvement).toList(),
    );
  }

  // --- Écritures locales ------------------------------------------------------

  Future<void> insererEngagement(Engagement e) =>
      _db.into(_db.engagements).insert(FinancesMapper.engagementLocal(e, RecordSyncStatus.pendingSync));

  Future<void> remplacerEngagement(Engagement e) =>
      (_db.update(_db.engagements)..where((t) => t.id.equals(e.id))).write(
        FinancesMapper.engagementLocal(
          e,
          RecordSyncStatus.pendingSync,
        ).copyWith(id: const Value.absent(), montantRegle: const Value.absent()),
      );

  /// Paiement + copies locales de ses affectations et de son mouvement de
  /// caisse (mêmes identifiants que ceux que créera le serveur).
  Future<void> insererPaiement(Paiement p, {MouvementCaisse? mouvement, String? perimetreCaisse}) async {
    await _db.into(_db.paiements).insert(FinancesMapper.paiementLocal(p, RecordSyncStatus.pendingSync));
    for (final a in p.affectations) {
      await _db.into(_db.paiementAffectations).insert(FinancesMapper.affectationLocale(p, a));
    }
    if (mouvement != null) {
      await _db
          .into(_db.caisseMouvements)
          .insert(
            FinancesMapper.mouvementLocal(
              mouvement,
              entrepriseId: p.entrepriseId,
              perimetreId: perimetreCaisse ?? p.perimetreId ?? '',
              statut: RecordSyncStatus.synced,
            ),
          );
    }
  }

  Future<void> insererCaisse(Caisse c) =>
      _db.into(_db.caisses).insert(FinancesMapper.caisseLocale(c, RecordSyncStatus.pendingSync));

  Future<void> insererSession(SessionCaisse s) =>
      _db.into(_db.caisseSessions).insert(FinancesMapper.sessionLocale(s, RecordSyncStatus.pendingSync));

  Future<void> cloturerSession(String id, {required int soldeReel, String? note, MotifEcart? motifEcart}) =>
      (_db.update(_db.caisseSessions)..where((t) => t.id.equals(id))).write(
        CaisseSessionsCompanion(
          statut: const Value('FERMEE'),
          soldeReel: Value(soldeReel),
          noteCloture: Value(note),
          motifEcart: Value(motifEcart?.code),
          fermeeLe: Value(DateTime.now()),
          syncStatus: Value(RecordSyncStatus.pendingSync.wire),
        ),
      );

  Future<void> insererMouvement(MouvementCaisse m, {required String entrepriseId, required String perimetreId}) => _db
      .into(_db.caisseMouvements)
      .insert(
        FinancesMapper.mouvementLocal(
          m,
          entrepriseId: entrepriseId,
          perimetreId: perimetreId,
          statut: RecordSyncStatus.pendingSync,
        ),
      );

  /// Dépense + copies locales de ce que le serveur créera (mêmes identifiants) :
  /// somme à payer, et pour un paiement immédiat, paiement, affectation et
  /// sortie de caisse. Le paiement reste « en attente » jusqu'à l'envoi de
  /// la dépense (il est compté dans le réglé affiché).
  Future<void> insererDepense(
    Depense d, {
    required Engagement engagement,
    Paiement? paiement,
    MouvementCaisse? mouvement,
  }) async {
    await _db.into(_db.depenses).insert(FinancesMapper.depenseLocale(d, RecordSyncStatus.pendingSync));
    // Échéance payée : la dépense courante avance, comme sur le serveur
    // (sa copie serveur remplacera celle-ci).
    if ((d.couranteId, d.echeancePrevue) case (final String cid, final DateTime echeance)) {
      final ligne = await courantes.ligne(cid);
      if (ligne != null) {
        final c = FinancesMapper.courante(ligne);
        if (!c.prochaineEcheance.isAfter(echeance)) {
          await _avancerCourante(cid, c.suivante(echeance));
        }
      }
    }
    await _db.into(_db.engagements).insert(FinancesMapper.engagementLocal(engagement, RecordSyncStatus.synced));
    if (paiement != null) {
      await _db.into(_db.paiements).insert(FinancesMapper.paiementLocal(paiement, RecordSyncStatus.pendingSync));
      for (final a in paiement.affectations) {
        await _db.into(_db.paiementAffectations).insert(FinancesMapper.affectationLocale(paiement, a));
      }
      if (mouvement != null) {
        final session = await sessions.ligne(mouvement.sessionId);
        await _db
            .into(_db.caisseMouvements)
            .insert(
              FinancesMapper.mouvementLocal(
                mouvement,
                entrepriseId: d.entrepriseId,
                perimetreId: session?.perimetreId ?? d.perimetreId ?? '',
                statut: RecordSyncStatus.synced,
              ),
            );
      }
    }
  }

  Future<void> remplacerDepense(Depense d) async {
    await (_db.update(_db.depenses)..where((t) => t.id.equals(d.id))).write(
      FinancesMapper.depenseLocale(d, RecordSyncStatus.pendingSync).copyWith(id: const Value.absent()),
    );
    // La somme liée suit (le serveur fait de même) ; la copie serveur la remplacera.
    await (_db.update(_db.engagements)..where((t) => t.id.equals(d.id))).write(
      EngagementsCompanion(
        libelle: Value(d.libelle),
        statut: d.annulee ? const Value('ANNULE') : const Value.absent(),
        motifAnnulation: d.annulee ? Value(d.motifAnnulation) : const Value.absent(),
      ),
    );
    // Échéance payée puis annulée : elle redevient à payer (comme le serveur).
    if (d.annulee && d.couranteId != null && d.echeancePrevue != null) {
      final ligne = await courantes.ligne(d.couranteId!);
      if (ligne != null) {
        final c = FinancesMapper.courante(ligne);
        var e = d.echeancePrevue!.isBefore(c.prochaineEcheance) ? d.echeancePrevue! : c.prochaineEcheance;
        if (e.isBefore(c.dateDebut)) e = c.dateDebut;
        await _avancerCourante(c.id, e);
      }
    }
  }

  /// Copie locale de ce que fait le serveur : la ligne n'est pas renvoyée,
  /// la descente suivante apporte la version serveur.
  Future<void> _avancerCourante(String id, DateTime prochaine) => (_db.update(
    _db.depensesCourantes,
  )..where((t) => t.id.equals(id))).write(DepensesCourantesCompanion(prochaineEcheance: Value(jourIso(prochaine))));

  Future<void> insererCourante(DepenseCourante c) =>
      _db.into(_db.depensesCourantes).insert(FinancesMapper.couranteLocale(c, RecordSyncStatus.pendingSync));

  Future<void> remplacerCourante(DepenseCourante c) =>
      (_db.update(_db.depensesCourantes)..where((t) => t.id.equals(c.id))).write(
        FinancesMapper.couranteLocale(
          c,
          RecordSyncStatus.pendingSync,
        ).copyWith(id: const Value.absent(), version: const Value.absent()),
      );

  Future<void> insererCategorie(CategorieDepense c) =>
      _db.into(_db.depenseCategories).insert(FinancesMapper.categorieLocale(c, RecordSyncStatus.pendingSync));

  Future<void> remplacerCategorie(CategorieDepense c) =>
      (_db.update(_db.depenseCategories)..where((t) => t.id.equals(c.id))).write(
        FinancesMapper.categorieLocale(c, RecordSyncStatus.pendingSync).copyWith(id: const Value.absent()),
      );

  /// Transfert + copies locales de ce que le serveur créera avec lui (mêmes
  /// identifiants) : ses deux jambes et leurs mouvements d'espèces.
  Future<void> insererTransfert(TransfertTresorerie t, {required List<(Paiement, MouvementCaisse?)> jambes}) async {
    await _db.into(_db.transfertsTresorerie).insert(FinancesMapper.transfertLocal(t, RecordSyncStatus.pendingSync));
    await _insererJambes(jambes);
  }

  /// Annulation : statut + copies locales des deux paiements inverses.
  Future<void> annulerTransfert(TransfertTresorerie t, {required List<(Paiement, MouvementCaisse?)> jambes}) async {
    await (_db.update(_db.transfertsTresorerie)..where((x) => x.id.equals(t.id))).write(
      FinancesMapper.transfertLocal(
        t,
        RecordSyncStatus.pendingSync,
      ).copyWith(id: const Value.absent(), version: const Value.absent()),
    );
    await _insererJambes(jambes);
  }

  Future<void> _insererJambes(List<(Paiement, MouvementCaisse?)> jambes) async {
    for (final (p, m) in jambes) {
      await _db.into(_db.paiements).insert(FinancesMapper.paiementLocal(p, RecordSyncStatus.pendingSync));
      if (m != null) {
        final session = await sessions.ligne(m.sessionId);
        await _db
            .into(_db.caisseMouvements)
            .insert(
              FinancesMapper.mouvementLocal(
                m,
                entrepriseId: p.entrepriseId,
                perimetreId: session?.perimetreId ?? p.perimetreId ?? '',
                statut: RecordSyncStatus.synced,
              ),
            );
      }
    }
  }

  /// Supprime une écriture jamais acceptée par le serveur et ce qui en découle.
  Future<void> retirer(String table, String id) async {
    switch (table) {
      case 'depenses':
        final d = await depenses.ligne(id);
        if (d?.paiementId case final paiementId?) await retirer('paiements', paiementId);
        await engagements.supprimer(id);
        await depenses.supprimer(id);
      case 'transferts_tresorerie':
        final t = await transferts.ligne(id);
        if (t != null) {
          for (final jambe in [t.sortieId, t.entreeId]) {
            await retirer('paiements', jambe);
          }
        }
        await transferts.supprimer(id);
      case 'paiements':
        await (_db.delete(_db.paiementAffectations)..where((t) => t.paiementId.equals(id))).go();
        await (_db.delete(_db.caisseMouvements)..where((t) => t.paiementId.equals(id))).go();
        await paiements.supprimer(id);
      case 'caisse_sessions':
        await (_db.delete(_db.caisseMouvements)..where((t) => t.sessionId.equals(id))).go();
        await sessions.supprimer(id);
      default:
        await tous.firstWhere((s) => s.table == table).supprimer(id);
    }
  }
}
