import '../../../../core/errors/failure.dart';
import '../../../../core/sync/standard_sync_handler.dart';
import '../../../../core/sync/sync_contracts.dart';
import '../../../../core/sync/sync_models.dart';
import '../../../../core/utils/recherche.dart';
import '../../domain/entities/contact.dart';
import '../../domain/repositories/contact_repository.dart';
import '../datasources/contact_local_data_source.dart';
import '../models/contact_mapper.dart';

/// UI → Repository → SQLite + file de synchronisation → (moteur) → Supabase.
class ContactRepositoryImpl implements ContactRepository {
  ContactRepositoryImpl({
    required ContactLocalDataSource local,
    required SyncQueueStore queue,
    required String? Function() currentUserId,
    required SyncTrigger requestSync,
  })  : _local = local,
        _queue = queue,
        _currentUserId = currentUserId,
        _requestSync = requestSync;

  static const table = 'contacts';

  final ContactLocalDataSource _local;
  final SyncQueueStore _queue;
  final String? Function() _currentUserId;
  final SyncTrigger _requestSync;

  @override
  Stream<List<Contact>> watch(String entrepriseId, FiltreContacts filtre) => _local.watch(entrepriseId, filtre);

  @override
  Stream<Contact?> watchUn(String id) => _local.watchUn(id);

  @override
  Future<List<Contact>> doublonsPotentiels(
    String entrepriseId, {
    String? telephone,
    required String nom,
    String? prenom,
    String? saufId,
  }) async {
    // Huit derniers chiffres : indépendant de l'indicatif (+223 / 00223 / rien).
    String fin(String? t) {
      final c = chiffresSeuls(t);
      return c.length > 8 ? c.substring(c.length - 8) : c;
    }

    final telCible = fin(telephone);
    final nomCible = normaliserRecherche('${prenom ?? ''} $nom');
    return [
      for (final c in await _local.tous(entrepriseId))
        if (c.id != saufId &&
            ((telCible.length >= 6 && (fin(c.telephone) == telCible || fin(c.whatsapp) == telCible)) ||
                (nomCible.isNotEmpty && normaliserRecherche('${c.prenom ?? ''} ${c.nom}') == nomCible)))
          c,
    ];
  }

  @override
  Future<Contact> creer(Contact contact) async {
    final userId = _requireUser();
    await _ecrire(() async {
      await _local.inserer(contact);
      await _queue.enqueue(
        userId: userId,
        entityTable: table,
        recordId: contact.id,
        type: SyncOperationType.insert,
        payload: ContactMapper.payload(contact, creation: true),
      );
    });
    return contact;
  }

  @override
  Future<void> modifier(Contact avant, Contact apres) {
    final userId = _requireUser();
    return _ecrire(() async {
      await _local.remplacer(apres);
      await _queue.enqueue(
        userId: userId,
        entityTable: table,
        recordId: apres.id,
        type: SyncOperationType.update,
        payload: ContactMapper.payload(apres),
        baseVersion: avant.version,
      );
    });
  }

  String _requireUser() => _currentUserId() ?? (throw const Failure(FailureKind.sessionExpired));

  Future<void> _ecrire(Future<void> Function() action) async {
    try {
      await _local.enTransaction(action);
    } on Failure {
      rethrow;
    } catch (e, st) {
      throw Failure(FailureKind.localStorage, cause: e, stackTrace: st);
    }
    _requestSync();
  }
}

/// Synchronisation des contacts : politique commune du socle.
class ContactsSyncHandler extends StandardSyncHandler {
  ContactsSyncHandler(ContactLocalDataSource local, SyncCursorStore cursors)
      : super(local, cursors, local.enTransaction);
}
