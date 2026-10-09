import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/sync/standard_sync_handler.dart';
import '../../../core/sync/stockage_miroir.dart';
import '../../../core/sync/sync_contracts.dart';
import '../../../core/sync/sync_models.dart';
import '../../agenda/domain/entities/agenda.dart';
import '../domain/fichiers.dart';

typedef Json = Map<String, dynamic>;
DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);

/// Bucket privé des fichiers de l'entreprise.
const bucketFichiers = 'fichiers';

abstract final class FichiersMapper {
  static Note note(NoteRow r) => Note(
        id: r.id,
        cibleType: CibleType.tryParse(r.cibleType) ?? CibleType.contact,
        cibleId: r.cibleId,
        texte: r.texte,
        createdAt: r.createdAt,
        auteurNom: r.auteurNom,
        createdBy: r.createdBy,
        version: r.version,
        syncStatus: RecordSyncStatus.fromWire(r.syncStatus),
      );

  static NotesCompanion noteServeur(Json j, RecordSyncStatus statut) => NotesCompanion.insert(
        id: j['id'] as String,
        entrepriseId: j['entreprise_id'] as String,
        cibleType: j['cible_type'] as String,
        cibleId: j['cible_id'] as String,
        texte: j['texte'] as String,
        auteurNom: Value(j['auteur_nom'] as String?),
        createdBy: Value(j['created_by'] as String?),
        createdAt: _date(j['created_at']) ?? DateTime.now(),
        version: Value((j['version'] as num?)?.toInt()),
        updatedAt: Value(_date(j['updated_at'])),
        syncStatus: statut.wire,
      );

  static PieceJointe piece(PieceJointeRow r) => PieceJointe(
        id: r.id,
        cibleType: CibleType.tryParse(r.cibleType) ?? CibleType.contact,
        cibleId: r.cibleId,
        chemin: r.chemin,
        nomFichier: r.nomFichier,
        typeMime: r.typeMime,
        taille: r.taille,
        createdAt: r.createdAt,
        auteurNom: r.auteurNom,
        createdBy: r.createdBy,
        version: r.version,
      );

  static PiecesJointesCompanion pieceServeur(Json j, RecordSyncStatus statut) => PiecesJointesCompanion.insert(
        id: j['id'] as String,
        entrepriseId: j['entreprise_id'] as String,
        cibleType: j['cible_type'] as String,
        cibleId: j['cible_id'] as String,
        chemin: j['chemin'] as String,
        nomFichier: j['nom_fichier'] as String,
        typeMime: j['type_mime'] as String,
        taille: (j['taille'] as num).toInt(),
        auteurNom: Value(j['auteur_nom'] as String?),
        createdBy: Value(j['created_by'] as String?),
        createdAt: _date(j['created_at']) ?? DateTime.now(),
        version: Value((j['version'] as num?)?.toInt()),
        updatedAt: Value(_date(j['updated_at'])),
        syncStatus: statut.wire,
      );
}

class FichiersLocalDataSource {
  FichiersLocalDataSource(this._db)
      : notes = StockageMiroir(_db, _db.notes,
            versLocal: FichiersMapper.noteServeur,
            statutDe: (r) => r.syncStatus,
            versionDe: (r) => r.version,
            identique: (l, s) => l.texte == s['texte']),
        pieces = StockageMiroir(_db, _db.piecesJointes,
            versLocal: FichiersMapper.pieceServeur, statutDe: (r) => r.syncStatus, versionDe: (r) => r.version);

  final AppDatabase _db;
  final StockageMiroir<$NotesTable, NoteRow> notes;
  final StockageMiroir<$PiecesJointesTable, PieceJointeRow> pieces;

  Future<void> enTransaction(Future<void> Function() action) => _db.transaction(action);

  Stream<List<Note>> watchNotes(CibleType type, String id) => (_db.select(_db.notes)
        ..where((t) => t.cibleType.equals(type.code) & t.cibleId.equals(id) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch()
      .map((rows) => rows.map(FichiersMapper.note).toList());

  Stream<List<PieceJointe>> watchPieces(CibleType type, String id) => (_db.select(_db.piecesJointes)
        ..where((t) => t.cibleType.equals(type.code) & t.cibleId.equals(id) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch()
      .map((rows) => rows.map(FichiersMapper.piece).toList());

  Future<void> insererNote(Note n, String eid) => _db.into(_db.notes).insert(NotesCompanion.insert(
        id: n.id,
        entrepriseId: eid,
        cibleType: n.cibleType.code,
        cibleId: n.cibleId,
        texte: n.texte,
        auteurNom: Value(n.auteurNom),
        createdBy: Value(n.createdBy),
        createdAt: n.createdAt,
        syncStatus: RecordSyncStatus.pendingSync.wire,
      ));

  Future<void> modifierNote(String id, String texte) => (_db.update(_db.notes)..where((t) => t.id.equals(id)))
      .write(NotesCompanion(texte: Value(texte), syncStatus: Value(RecordSyncStatus.pendingSync.wire)));

  /// Retrait local immédiat (masqué) ; le serveur le confirmera.
  Future<void> masquerNote(String id) => (_db.update(_db.notes)..where((t) => t.id.equals(id)))
      .write(NotesCompanion(deletedAt: Value(DateTime.now()), syncStatus: Value(RecordSyncStatus.pendingSync.wire)));

  Future<void> masquerPiece(String id) => (_db.update(_db.piecesJointes)..where((t) => t.id.equals(id)))
      .write(PiecesJointesCompanion(deletedAt: Value(DateTime.now()), syncStatus: Value(RecordSyncStatus.pendingSync.wire)));
}

class FichiersRepositoryImpl implements FichiersRepository {
  FichiersRepositoryImpl({
    required FichiersLocalDataSource local,
    required SyncQueueStore queue,
    required SupabaseClient? Function() client,
    required String? Function() currentUserId,
    required SyncTrigger requestSync,
  })  : _local = local,
        _queue = queue,
        _client = client,
        _currentUserId = currentUserId,
        _requestSync = requestSync;

  final FichiersLocalDataSource _local;
  final SyncQueueStore _queue;
  final SupabaseClient? Function() _client;
  final String? Function() _currentUserId;
  final SyncTrigger _requestSync;

  @override
  Stream<List<Note>> notes(CibleType type, String cibleId) => _local.watchNotes(type, cibleId);

  @override
  Stream<List<PieceJointe>> pieces(CibleType type, String cibleId) => _local.watchPieces(type, cibleId);

  @override
  Future<void> ajouterNote(Note note, {required String entrepriseId}) => _ecrire((uid) async {
        await _local.insererNote(note, entrepriseId);
        await _queue.enqueue(userId: uid, entityTable: 'notes', recordId: note.id, type: SyncOperationType.insert,
            payload: {'entreprise_id': entrepriseId, 'cible_type': note.cibleType.code, 'cible_id': note.cibleId, 'texte': note.texte});
      });

  @override
  Future<void> modifierNote(Note avant, String texte) => _ecrire((uid) async {
        await _local.modifierNote(avant.id, texte);
        await _queue.enqueue(userId: uid, entityTable: 'notes', recordId: avant.id, type: SyncOperationType.update,
            payload: {'texte': texte}, baseVersion: avant.version, fusionner: false);
      });

  @override
  Future<void> retirerNote(Note note) => _ecrire((uid) async {
        await _local.masquerNote(note.id);
        await _queue.enqueue(userId: uid, entityTable: 'notes', recordId: note.id, type: SyncOperationType.delete,
            payload: const {}, baseVersion: note.version, fusionner: false);
      });

  @override
  Future<PieceJointe> ajouterPiece({
    required String entrepriseId,
    required CibleType type,
    required String cibleId,
    required FichierChoisi fichier,
  }) async {
    final client = _client() ?? (throw const Failure(FailureKind.network));
    final id = const Uuid().v4();
    final extension = fichier.nom.contains('.') ? fichier.nom.split('.').last.toLowerCase() : 'bin';
    final chemin = '$entrepriseId/pj/${type.code}/$cibleId/$id.$extension';
    try {
      await client.storage.from(bucketFichiers).uploadBinary(
            chemin,
            fichier.octets,
            fileOptions: FileOptions(contentType: fichier.typeMime),
          );
      final ligne = await client
          .from('pieces_jointes')
          .insert({
            'id': id,
            'entreprise_id': entrepriseId,
            'cible_type': type.code,
            'cible_id': cibleId,
            'chemin': chemin,
            'nom_fichier': fichier.nom,
            'type_mime': fichier.typeMime,
            'taille': fichier.octets.length,
          })
          .select()
          .single();
      await _local.pieces.ecrireDepuisServeur(ligne, RecordSyncStatus.synced);
      return FichiersMapper.piece((await _local.pieces.ligne(id))!);
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
  }

  @override
  Future<void> retirerPiece(PieceJointe piece) => _ecrire((uid) async {
        await _local.masquerPiece(piece.id);
        await _queue.enqueue(userId: uid, entityTable: 'pieces_jointes', recordId: piece.id,
            type: SyncOperationType.delete, payload: const {}, baseVersion: piece.version, fusionner: false);
      });

  @override
  Future<String> lienTemporaire(String chemin) async {
    final client = _client() ?? (throw const Failure(FailureKind.network));
    try {
      return await client.storage.from(bucketFichiers).createSignedUrl(chemin, 300);
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
  }

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

List<SyncEntityHandler> fichiersSyncHandlers(FichiersLocalDataSource local, SyncCursorStore cursors) => [
      StandardSyncHandler(local.notes, cursors, local.enTransaction),
      StandardSyncHandler(local.pieces, cursors, local.enTransaction),
    ];
