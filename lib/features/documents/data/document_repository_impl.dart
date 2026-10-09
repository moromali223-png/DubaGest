import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/sync/standard_sync_handler.dart';
import '../../../core/sync/stockage_miroir.dart';
import '../../../core/sync/sync_contracts.dart';
import '../../../core/sync/sync_models.dart';
import '../domain/entities/document.dart';
import '../domain/repositories/document_repository.dart';

typedef Json = Map<String, dynamic>;

abstract final class DocumentMapper {
  static Document document(DocumentRow r) => Document(
        id: r.id,
        entrepriseId: r.entrepriseId,
        type: TypeDocument.parse(r.type),
        numero: r.numero,
        blocId: r.blocId,
        sequence: r.sequence,
        langue: r.langue,
        date: r.dateDocument,
        montant: r.montant,
        origineType: r.origineType,
        origineId: r.origineId,
        perimetreId: r.perimetreId,
        contactId: r.contactId,
        contenu: jsonDecode(r.contenu) as Json,
        version: r.version,
        syncStatus: RecordSyncStatus.fromWire(r.syncStatus),
      );

  static DocumentsCompanion local(Document d, RecordSyncStatus statut) => DocumentsCompanion.insert(
        id: d.id,
        entrepriseId: d.entrepriseId,
        type: d.type.code,
        numero: d.numero,
        blocId: d.blocId,
        sequence: d.sequence,
        langue: d.langue,
        dateDocument: d.date,
        perimetreId: Value(d.perimetreId),
        contactId: Value(d.contactId),
        montant: d.montant,
        origineType: d.origineType,
        origineId: Value(d.origineId),
        contenu: jsonEncode(d.contenu),
        statut: 'EMIS',
        version: Value(d.version),
        syncStatus: statut.wire,
      );

  static DocumentsCompanion serveur(Json j, RecordSyncStatus statut) => DocumentsCompanion.insert(
        id: j['id'] as String,
        entrepriseId: j['entreprise_id'] as String,
        type: j['type'] as String,
        numero: j['numero'] as String,
        blocId: j['bloc_id'] as String,
        sequence: (j['sequence'] as num).toInt(),
        langue: j['langue'] as String,
        dateDocument: DateTime.parse(j['date_document'] as String),
        perimetreId: Value(j['perimetre_id'] as String?),
        contactId: Value(j['contact_id'] as String?),
        montant: (j['montant'] as num).toInt(),
        origineType: j['origine_type'] as String,
        origineId: Value(j['origine_id'] as String?),
        contenu: jsonEncode(j['contenu'] ?? const {}),
        statut: j['statut'] as String? ?? 'EMIS',
        version: Value((j['version'] as num?)?.toInt()),
        updatedAt: Value(j['updated_at'] == null ? null : DateTime.parse(j['updated_at'] as String)),
        syncStatus: statut.wire,
      );

  static Json creation(Document d) => {
        'entreprise_id': d.entrepriseId,
        'type': d.type.code,
        'bloc_id': d.blocId,
        'sequence': d.sequence,
        'langue': d.langue,
        'date_document': d.date.toUtc().toIso8601String(),
        'perimetre_id': d.perimetreId,
        'contact_id': d.contactId,
        'montant': d.montant,
        'origine_type': d.origineType,
        'origine_id': d.origineId,
        'contenu': d.contenu,
      };

  static NumeroBloc bloc(NumeroBlocRow r) => NumeroBloc(
        id: r.id,
        entrepriseId: r.entrepriseId,
        userId: r.userId,
        type: TypeDocument.parse(r.type),
        prefixe: r.prefixe,
        annee: r.annee,
        debut: r.debut,
        fin: r.fin,
        prochain: r.prochain,
      );
}

class DocumentLocalDataSource {
  DocumentLocalDataSource(this._db)
      : documents = StockageMiroir(_db, _db.documents,
            versLocal: DocumentMapper.serveur, statutDe: (r) => r.syncStatus, versionDe: (r) => r.version);

  final AppDatabase _db;
  final StockageMiroir<$DocumentsTable, DocumentRow> documents;

  Future<void> enTransaction(Future<void> Function() action) => _db.transaction(action);

  Stream<List<Document>> watch(String eid) => (_db.select(_db.documents)
        ..where((t) => t.entrepriseId.equals(eid) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.dateDocument)]))
      .watch()
      .map((rows) => rows.map(DocumentMapper.document).toList());

  Future<List<NumeroBloc>> blocs(String eid, String uid, TypeDocument type, int annee) async {
    final rows = await (_db.select(_db.numeroBlocs)
          ..where((b) =>
              b.entrepriseId.equals(eid) &
              b.userId.equals(uid) &
              b.type.equals(type.code) &
              b.annee.equals(annee) &
              b.prochain.isSmallerOrEqual(b.fin))
          ..orderBy([(b) => OrderingTerm.asc(b.debut)]))
        .get();
    return rows.map(DocumentMapper.bloc).toList();
  }

  Future<void> ajouterBloc(NumeroBloc b) => _db.into(_db.numeroBlocs).insertOnConflictUpdate(NumeroBlocsCompanion.insert(
        id: b.id,
        entrepriseId: b.entrepriseId,
        userId: b.userId,
        type: b.type.code,
        prefixe: b.prefixe,
        annee: b.annee,
        debut: b.debut,
        fin: b.fin,
        prochain: b.prochain,
      ));

  Future<void> avancer(String blocId, int prochain) =>
      (_db.update(_db.numeroBlocs)..where((b) => b.id.equals(blocId))).write(NumeroBlocsCompanion(prochain: Value(prochain)));

  Future<void> inserer(Document d) => _db.into(_db.documents).insert(DocumentMapper.local(d, RecordSyncStatus.pendingSync));
}

class DocumentRepositoryImpl implements DocumentRepository {
  DocumentRepositoryImpl({
    required DocumentLocalDataSource local,
    required SyncQueueStore queue,
    required SupabaseClient? Function() client,
    required SyncTrigger requestSync,
  })  : _local = local,
        _queue = queue,
        _client = client,
        _requestSync = requestSync;

  final DocumentLocalDataSource _local;
  final SyncQueueStore _queue;
  final SupabaseClient? Function() _client;
  final SyncTrigger _requestSync;

  @override
  Stream<List<Document>> watch(String entrepriseId) => _local.watch(entrepriseId);

  @override
  Future<List<NumeroBloc>> blocs(String entrepriseId, String userId, TypeDocument type, int annee) =>
      _local.blocs(entrepriseId, userId, type, annee);

  @override
  Future<NumeroBloc> reserverBloc(String entrepriseId, TypeDocument type, {required String appareilId, int taille = 50}) async {
    final client = _client() ?? (throw const Failure(FailureKind.network));
    Json j;
    try {
      j = (await client.rpc<Map<String, dynamic>>('reserver_bloc', params: {
        'p_entreprise_id': entrepriseId,
        'p_type': type.code,
        'p_appareil_id': appareilId,
        'p_taille': taille,
      }));
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
    final bloc = NumeroBloc(
      id: j['id'] as String,
      entrepriseId: j['entreprise_id'] as String,
      userId: j['user_id'] as String,
      type: TypeDocument.parse(j['type'] as String),
      prefixe: j['prefixe'] as String,
      annee: (j['annee'] as num).toInt(),
      debut: (j['debut'] as num).toInt(),
      fin: (j['fin'] as num).toInt(),
      prochain: (j['debut'] as num).toInt(),
    );
    await _local.ajouterBloc(bloc);
    return bloc;
  }

  @override
  Future<Document?> emettre({
    required String entrepriseId,
    required String userId,
    required TypeDocument type,
    required int annee,
    required Document Function(NumeroBloc bloc, int sequence) construire,
  }) async {
    Document? document;
    try {
      await _local.enTransaction(() async {
        final bloc = (await _local.blocs(entrepriseId, userId, type, annee)).firstOrNull;
        if (bloc == null) return;
        final d = construire(bloc, bloc.prochain);
        await _local.avancer(bloc.id, bloc.prochain + 1);
        await _local.inserer(d);
        await _queue.enqueue(
          userId: userId,
          entityTable: 'documents',
          recordId: d.id,
          type: SyncOperationType.insert,
          payload: DocumentMapper.creation(d),
        );
        document = d;
      });
    } on Failure {
      rethrow;
    } catch (e, st) {
      throw Failure(FailureKind.localStorage, cause: e, stackTrace: st);
    }
    if (document != null) _requestSync();
    return document;
  }

  @override
  Future<void> retirerRefuse(String id) => _local.enTransaction(() async {
        await _local.documents.supprimer(id);
        await _queue.abandonner('documents', id);
      });
}

SyncEntityHandler documentsSyncHandler(DocumentLocalDataSource local, SyncCursorStore cursors) =>
    StandardSyncHandler(local.documents, cursors, local.enTransaction);
