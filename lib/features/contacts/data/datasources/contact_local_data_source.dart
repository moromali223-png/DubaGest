import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/standard_sync_handler.dart';
import '../../../../core/sync/sync_models.dart';
import '../../../../core/utils/recherche.dart';
import '../../domain/entities/contact.dart';
import '../models/contact_mapper.dart';

/// Contacts sur l'appareil : liste, recherche et doublons fonctionnent hors-ligne.
class ContactLocalDataSource implements StockageSynchronise {
  ContactLocalDataSource(this._db);
  final AppDatabase _db;

  @override
  String get table => 'contacts';

  Future<void> enTransaction(Future<void> Function() action) => _db.transaction(action);

  Stream<List<Contact>> watch(String entrepriseId, FiltreContacts filtre) {
    final requete = _db.select(_db.contacts)
      ..where((c) => c.entrepriseId.equals(entrepriseId) & c.deletedAt.isNull());
    if (!filtre.inclureArchives) {
      requete.where((c) => c.statut.equals(StatutContact.actif.code));
    }
    if (filtre.relation case final relation?) {
      // Codes séparés par des virgules : recherche exacte d'un code.
      requete.where((c) =>
          (const Constant(',') + c.relations + const Constant(',')).like('%,${relation.code},%'));
    }
    final texte = normaliserRecherche(filtre.recherche);
    final chiffres = chiffresSeuls(filtre.recherche);
    if (texte.isNotEmpty) {
      requete.where((c) {
        final parMots = texte
            .split(' ')
            .map((mot) => c.cleRecherche.like('%$mot%'))
            .reduce((a, b) => a & b);
        return chiffres.length >= 3 ? (parMots | c.telephoneChiffres.like('%$chiffres%')) : parMots;
      });
    }
    requete.orderBy([(c) => OrderingTerm.asc(c.cleRecherche)]);
    return requete.watch().map((rows) => rows.map(ContactMapper.fromRow).toList());
  }

  Stream<Contact?> watchUn(String id) => (_db.select(_db.contacts)..where((c) => c.id.equals(id)))
      .watchSingleOrNull()
      .map((r) => r == null || r.deletedAt != null ? null : ContactMapper.fromRow(r));

  Future<List<Contact>> tous(String entrepriseId) async {
    final rows = await (_db.select(_db.contacts)
          ..where((c) => c.entrepriseId.equals(entrepriseId) & c.deletedAt.isNull()))
        .get();
    return rows.map(ContactMapper.fromRow).toList();
  }

  Future<void> inserer(Contact c) =>
      _db.into(_db.contacts).insert(ContactMapper.toLocal(c, RecordSyncStatus.pendingSync));

  /// Remplace les champs modifiables ; la ligne passe en attente d'envoi.
  Future<void> remplacer(Contact c) =>
      (_db.update(_db.contacts)..where((t) => t.id.equals(c.id))).write(
        ContactMapper.toLocal(c, RecordSyncStatus.pendingSync).copyWith(id: const Value.absent()),
      );

  // --- StockageSynchronise -------------------------------------------------

  @override
  Future<LigneLocale?> lire(String id) async {
    final row = await (_db.select(_db.contacts)..where((c) => c.id.equals(id))).getSingleOrNull();
    return row == null
        ? null
        : LigneLocale(statut: RecordSyncStatus.fromWire(row.syncStatus), version: row.version, ligne: row);
  }

  @override
  Future<void> ecrireDepuisServeur(Map<String, dynamic> json, RecordSyncStatus statut) async {
    if (json['deleted_at'] != null) {
      await supprimer(json['id'] as String);
      return;
    }
    await _db.into(_db.contacts).insertOnConflictUpdate(ContactMapper.fromServer(json, statut));
  }

  @override
  Future<void> supprimer(String id) => (_db.delete(_db.contacts)..where((c) => c.id.equals(id))).go();

  @override
  Future<void> marquer(String id, RecordSyncStatus statut) =>
      (_db.update(_db.contacts)..where((c) => c.id.equals(id)))
          .write(ContactsCompanion(syncStatus: Value(statut.wire)));

  @override
  Future<void> mettreAJourVersion(String id, int version) =>
      (_db.update(_db.contacts)..where((c) => c.id.equals(id)))
          .write(ContactsCompanion(version: Value(version)));

  @override
  bool memeContenu(LigneLocale locale, Map<String, dynamic> serveur) =>
      ContactMapper.memeContenu(locale.ligne as ContactRow, serveur);
}
