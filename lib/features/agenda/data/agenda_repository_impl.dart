import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/failure.dart';
import '../../../core/sync/standard_sync_handler.dart';
import '../../../core/sync/stockage_miroir.dart';
import '../../../core/sync/sync_contracts.dart';
import '../../../core/sync/sync_models.dart';
import '../domain/entities/agenda.dart';
import '../domain/repositories/agenda_repository.dart';

typedef Json = Map<String, dynamic>;
DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);

abstract final class AgendaMapper {
  static Echeance echeance(EcheanceRow r) => Echeance(
        id: r.id,
        entrepriseId: r.entrepriseId,
        perimetreId: r.perimetreId,
        type: TypeEcheance.parse(r.type),
        titre: r.titre,
        note: r.note,
        dateHeure: r.dateHeure,
        rappelMinutes: r.rappelMinutes,
        responsableId: r.responsableId,
        responsableNom: r.responsableNom,
        cibleType: CibleType.tryParse(r.cibleType),
        cibleId: r.cibleId,
        statut: StatutEcheance.parse(r.statut),
        faitLe: r.faitLe,
        createdBy: r.createdBy,
        version: r.version,
        syncStatus: RecordSyncStatus.fromWire(r.syncStatus),
      );

  static EcheancesCompanion local(Echeance e, RecordSyncStatus statut) => EcheancesCompanion.insert(
        id: e.id,
        entrepriseId: e.entrepriseId,
        perimetreId: Value(e.perimetreId),
        type: e.type.code,
        titre: e.titre,
        note: Value(e.note),
        dateHeure: e.dateHeure,
        rappelMinutes: Value(e.rappelMinutes),
        responsableId: Value(e.responsableId),
        responsableNom: Value(e.responsableNom),
        cibleType: Value(e.cibleType?.code),
        cibleId: Value(e.cibleId),
        statut: e.statut.code,
        faitLe: Value(e.faitLe),
        createdBy: Value(e.createdBy),
        version: Value(e.version),
        syncStatus: statut.wire,
      );

  static EcheancesCompanion serveur(Json j, RecordSyncStatus statut) => EcheancesCompanion.insert(
        id: j['id'] as String,
        entrepriseId: j['entreprise_id'] as String,
        perimetreId: Value(j['perimetre_id'] as String?),
        type: j['type'] as String,
        titre: j['titre'] as String,
        note: Value(j['note'] as String?),
        dateHeure: DateTime.parse(j['date_heure'] as String),
        rappelMinutes: Value((j['rappel_minutes'] as num?)?.toInt()),
        responsableId: Value(j['responsable_id'] as String?),
        responsableNom: Value(j['responsable_nom'] as String?),
        cibleType: Value(j['cible_type'] as String?),
        cibleId: Value(j['cible_id'] as String?),
        statut: j['statut'] as String? ?? 'A_FAIRE',
        faitLe: Value(_date(j['fait_le'])),
        createdBy: Value(j['created_by'] as String?),
        version: Value((j['version'] as num?)?.toInt()),
        updatedAt: Value(_date(j['updated_at'])),
        syncStatus: statut.wire,
      );

  static Json creation(Echeance e) => {
        'entreprise_id': e.entrepriseId,
        'perimetre_id': e.perimetreId,
        ...modification(e)..remove('statut'),
      };

  static Json modification(Echeance e) => {
        'type': e.type.code,
        'titre': e.titre,
        'note': e.note,
        'date_heure': e.dateHeure.toUtc().toIso8601String(),
        'rappel_minutes': e.rappelMinutes,
        'responsable_id': e.responsableId,
        'cible_type': e.cibleType?.code,
        'cible_id': e.cibleId,
        'statut': e.statut.code,
      };

  static bool identique(EcheanceRow l, Json s) =>
      l.type == s['type'] &&
      l.titre == s['titre'] &&
      l.note == s['note'] &&
      l.dateHeure.isAtSameMomentAs(DateTime.parse(s['date_heure'] as String)) &&
      l.rappelMinutes == (s['rappel_minutes'] as num?)?.toInt() &&
      l.responsableId == s['responsable_id'] &&
      l.statut == (s['statut'] ?? 'A_FAIRE');

  static NotificationApp notification(NotificationRow r) => NotificationApp(
        id: r.id,
        type: TypeNotification.tryParse(r.type),
        parametres: jsonDecode(r.parametres) as Json,
        cibleId: r.cibleId,
        auteurNom: r.auteurNom,
        lueLe: r.lueLe,
        createdAt: r.createdAt,
        version: r.version,
      );

  static NotificationsCompanion notificationServeur(Json j, RecordSyncStatus statut) => NotificationsCompanion.insert(
        id: j['id'] as String,
        entrepriseId: j['entreprise_id'] as String,
        destinataireId: j['destinataire_id'] as String,
        type: j['type'] as String,
        parametres: Value(jsonEncode(j['parametres'] ?? const {})),
        cibleType: Value(j['cible_type'] as String?),
        cibleId: Value(j['cible_id'] as String?),
        auteurNom: Value(j['auteur_nom'] as String?),
        lueLe: Value(_date(j['lue_le'])),
        createdAt: DateTime.parse(j['created_at'] as String),
        version: Value((j['version'] as num?)?.toInt()),
        updatedAt: Value(_date(j['updated_at'])),
        syncStatus: statut.wire,
      );
}

class AgendaLocalDataSource {
  AgendaLocalDataSource(this._db)
      : echeances = StockageMiroir(_db, _db.echeances,
            versLocal: AgendaMapper.serveur,
            statutDe: (r) => r.syncStatus,
            versionDe: (r) => r.version,
            identique: AgendaMapper.identique),
        notifications = StockageMiroir(_db, _db.notifications,
            versLocal: AgendaMapper.notificationServeur,
            statutDe: (r) => r.syncStatus,
            versionDe: (r) => r.version,
            identique: (l, s) => (l.lueLe == null) == (s['lue_le'] == null));

  final AppDatabase _db;
  final StockageMiroir<$EcheancesTable, EcheanceRow> echeances;
  final StockageMiroir<$NotificationsTable, NotificationRow> notifications;

  Future<void> enTransaction(Future<void> Function() action) => _db.transaction(action);

  Stream<List<Echeance>> watchEcheances(String eid) => (_db.select(_db.echeances)
        ..where((t) => t.entrepriseId.equals(eid) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.dateHeure)]))
      .watch()
      .map((rows) => rows.map(AgendaMapper.echeance).toList());

  Stream<List<NotificationApp>> watchNotifications(String eid, String uid) => (_db.select(_db.notifications)
        ..where((t) => t.entrepriseId.equals(eid) & t.destinataireId.equals(uid) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch()
      .map((rows) => rows.map(AgendaMapper.notification).toList());

  Future<void> inserer(Echeance e) =>
      _db.into(_db.echeances).insert(AgendaMapper.local(e, RecordSyncStatus.pendingSync));

  Future<void> remplacer(Echeance e) => (_db.update(_db.echeances)..where((t) => t.id.equals(e.id)))
      .write(AgendaMapper.local(e, RecordSyncStatus.pendingSync).copyWith(id: const Value.absent()));

  Future<void> marquerLue(String id, DateTime le) => (_db.update(_db.notifications)..where((t) => t.id.equals(id)))
      .write(NotificationsCompanion(lueLe: Value(le), syncStatus: Value(RecordSyncStatus.pendingSync.wire)));
}

class AgendaRepositoryImpl implements AgendaRepository {
  AgendaRepositoryImpl({
    required AgendaLocalDataSource local,
    required SyncQueueStore queue,
    required String? Function() currentUserId,
    required SyncTrigger requestSync,
  })  : _local = local,
        _queue = queue,
        _currentUserId = currentUserId,
        _requestSync = requestSync;

  final AgendaLocalDataSource _local;
  final SyncQueueStore _queue;
  final String? Function() _currentUserId;
  final SyncTrigger _requestSync;

  @override
  Stream<List<Echeance>> watchEcheances(String entrepriseId) => _local.watchEcheances(entrepriseId);

  @override
  Stream<List<NotificationApp>> watchNotifications(String entrepriseId, String userId) =>
      _local.watchNotifications(entrepriseId, userId);

  @override
  Future<void> creer(Echeance e) => _ecrire((uid) async {
        await _local.inserer(e);
        await _queue.enqueue(
            userId: uid, entityTable: 'echeances', recordId: e.id, type: SyncOperationType.insert,
            payload: AgendaMapper.creation(e));
      });

  @override
  Future<void> modifier(Echeance avant, Echeance apres) => _ecrire((uid) async {
        await _local.remplacer(apres);
        await _queue.enqueue(
          userId: uid,
          entityTable: 'echeances',
          recordId: apres.id,
          type: SyncOperationType.update,
          payload: AgendaMapper.modification(apres),
          baseVersion: avant.version,
          // Le statut n'est pas accepté à la création.
          fusionner: false,
        );
      });

  @override
  Future<void> marquerLue(NotificationApp n) => _ecrire((uid) async {
        final le = DateTime.now();
        await _local.marquerLue(n.id, le);
        await _queue.enqueue(
            userId: uid, entityTable: 'notifications', recordId: n.id, type: SyncOperationType.update,
            payload: {'lue_le': le.toUtc().toIso8601String()}, baseVersion: n.version);
      });

  @override
  Future<void> retirerRefusee(String id) => _local.enTransaction(() async {
        await _local.echeances.supprimer(id);
        await _queue.abandonner('echeances', id);
      });

  Future<void> _ecrire(Future<void> Function(String uid) action) async {
    final uid = _currentUserId() ?? (throw const Failure(FailureKind.sessionExpired));
    try {
      await _local.enTransaction(() => action(uid));
    } on Failure {
      rethrow;
    } catch (e, st) {
      throw Failure(FailureKind.localStorage, cause: e, stackTrace: st);
    }
    _requestSync();
  }
}

List<SyncEntityHandler> agendaSyncHandlers(AgendaLocalDataSource local, SyncCursorStore cursors) => [
      StandardSyncHandler(local.echeances, cursors, local.enTransaction),
      StandardSyncHandler(local.notifications, cursors, local.enTransaction),
    ];
