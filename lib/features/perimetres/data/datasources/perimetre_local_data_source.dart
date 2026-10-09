import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/standard_sync_handler.dart';
import '../../../../core/sync/sync_models.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../domain/entities/perimetre.dart';
import '../models/perimetre_mapper.dart';

/// Accès local aux périmètres (SQLite natif ou WASM selon la plateforme).
class PerimetreLocalDataSource implements StockageSynchronise {
  PerimetreLocalDataSource(this._db);
  final AppDatabase _db;

  @override
  String get table => 'perimetres';

  Future<void> enTransaction(Future<void> Function() action) => _db.transaction(action);

  Stream<List<Perimetre>> watch(String entrepriseId) => (_db.select(_db.perimetres)
        ..where((p) => p.entrepriseId.equals(entrepriseId) & p.deletedAt.isNull())
        ..orderBy([(p) => OrderingTerm.asc(p.nom)]))
      .watch()
      .map((rows) => rows.map(PerimetreMapper.fromRow).toList());

  Future<PerimetreRow?> _row(String id) =>
      (_db.select(_db.perimetres)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<int> countActive(String entrepriseId, ActiviteCode activite) async {
    final count = _db.perimetres.id.count();
    final query = _db.selectOnly(_db.perimetres)
      ..addColumns([count])
      ..where(_db.perimetres.entrepriseId.equals(entrepriseId) &
          _db.perimetres.activiteCode.equals(activite.code) &
          _db.perimetres.deletedAt.isNull());
    return (await query.getSingle()).read(count) ?? 0;
  }

  Future<void> insertLocal(Perimetre p) =>
      _db.into(_db.perimetres).insert(PerimetreMapper.toLocalCompanion(p));

  Future<void> updateLocal(
    String id, {
    String? nom,
    Value<String?> code = const Value.absent(),
    PerimetreType? type,
    bool? estActif,
  }) =>
      (_db.update(_db.perimetres)..where((p) => p.id.equals(id))).write(PerimetresCompanion(
        nom: nom == null ? const Value.absent() : Value(nom),
        code: code,
        type: type == null ? const Value.absent() : Value(type.code),
        estActif: estActif == null ? const Value.absent() : Value(estActif),
        syncStatus: Value(RecordSyncStatus.pendingSync.wire),
      ));

  Future<void> markDeletedLocal(String id) =>
      (_db.update(_db.perimetres)..where((p) => p.id.equals(id))).write(PerimetresCompanion(
        deletedAt: Value(DateTime.now()),
        syncStatus: Value(RecordSyncStatus.pendingSync.wire),
      ));

  Future<void> hardDelete(String id) => supprimer(id);

  // --- StockageSynchronise -------------------------------------------------

  @override
  Future<LigneLocale?> lire(String id) async {
    final row = await _row(id);
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
    await _db.into(_db.perimetres).insertOnConflictUpdate(PerimetreMapper.fromServer(json, statut));
  }

  @override
  Future<void> supprimer(String id) => (_db.delete(_db.perimetres)..where((p) => p.id.equals(id))).go();

  @override
  Future<void> marquer(String id, RecordSyncStatus statut) =>
      (_db.update(_db.perimetres)..where((p) => p.id.equals(id)))
          .write(PerimetresCompanion(syncStatus: Value(statut.wire)));

  @override
  Future<void> mettreAJourVersion(String id, int version) =>
      (_db.update(_db.perimetres)..where((p) => p.id.equals(id)))
          .write(PerimetresCompanion(version: Value(version)));

  @override
  bool memeContenu(LigneLocale locale, Map<String, dynamic> serveur) =>
      PerimetreMapper.sameContent(locale.ligne as PerimetreRow, serveur);
}
