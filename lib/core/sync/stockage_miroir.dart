import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'standard_sync_handler.dart';
import 'sync_models.dart';

/// Stockage synchronisé générique d'une table « miroir » du serveur
/// (id, version, sync_status), pour la politique commune [StandardSyncHandler].
class StockageMiroir<T extends Table, R> implements StockageSynchronise {
  StockageMiroir(
    this._db,
    this._info, {
    required this.versLocal,
    required this.statutDe,
    required this.versionDe,
    this.identique,
  });

  final AppDatabase _db;
  final TableInfo<T, R> _info;
  final Insertable<R> Function(Map<String, dynamic> json, RecordSyncStatus statut) versLocal;
  final String Function(R ligne) statutDe;
  final int? Function(R ligne) versionDe;

  /// Champs modifiables identiques ? `null` : table en ajout seul.
  final bool Function(R locale, Map<String, dynamic> serveur)? identique;

  @override
  String get table => _info.actualTableName;

  Future<R?> ligne(String id) async {
    final rows = await _db
        .customSelect('SELECT * FROM "$table" WHERE id = ?', variables: [Variable.withString(id)], readsFrom: {_info})
        .get();
    return rows.isEmpty ? null : await _info.map(rows.single.data);
  }

  @override
  Future<LigneLocale?> lire(String id) async {
    final r = await ligne(id);
    return r == null
        ? null
        : LigneLocale(statut: RecordSyncStatus.fromWire(statutDe(r)), version: versionDe(r), ligne: r as Object);
  }

  @override
  Future<void> ecrireDepuisServeur(Map<String, dynamic> json, RecordSyncStatus statut) async {
    if (json['deleted_at'] != null) return supprimer(json['id'] as String);
    await _db.into(_info).insertOnConflictUpdate(versLocal(json, statut));
  }

  @override
  Future<void> supprimer(String id) => _executer('DELETE FROM "$table" WHERE id = ?', [id], UpdateKind.delete);

  @override
  Future<void> marquer(String id, RecordSyncStatus statut) =>
      _executer('UPDATE "$table" SET sync_status = ? WHERE id = ?', [statut.wire, id], UpdateKind.update);

  @override
  Future<void> mettreAJourVersion(String id, int version) =>
      _executer('UPDATE "$table" SET version = ? WHERE id = ?', [version, id], UpdateKind.update);

  @override
  bool memeContenu(LigneLocale locale, Map<String, dynamic> serveur) =>
      identique?.call(locale.ligne as R, serveur) ?? true;

  Future<void> _executer(String sql, List<Object> valeurs, UpdateKind kind) => _db.customUpdate(
        sql,
        variables: [for (final v in valeurs) v is int ? Variable.withInt(v) : Variable.withString(v as String)],
        updates: {_info},
        updateKind: kind,
      );
}
