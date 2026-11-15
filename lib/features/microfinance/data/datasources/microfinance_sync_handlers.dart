import '../../../../core/errors/failure.dart';
import '../../../../core/sync/sync_contracts.dart';
import '../../../../core/sync/sync_models.dart';
import '../models/microfinance_mappers.dart';
import 'microfinance_local_data_source.dart';

/// Fabrique les 8 gestionnaires de synchronisation Microfinance pour `SyncEngine`.
List<SyncEntityHandler> microfinanceSyncHandlers(
  MicrofinanceLocalDataSource local,
  SyncCursorStore cursors,
) =>
    [
      _GenericMicrofinanceSyncHandler(
        tableName: 'microfinance_accounts',
        cursors: cursors,
        fromJson: MicrofinanceMappers.accountFromJson,
        getId: (a) => a.id,
        getEntrepriseId: (a) => a.entrepriseId,
        loadLocal: local.chargerAccounts,
        saveLocal: local.sauvegarderAccounts,
      ),
      _GenericMicrofinanceSyncHandler(
        tableName: 'microfinance_funds',
        cursors: cursors,
        fromJson: MicrofinanceMappers.fundFromJson,
        getId: (f) => f.id,
        getEntrepriseId: (f) => f.entrepriseId,
        loadLocal: local.chargerFunds,
        saveLocal: local.sauvegarderFunds,
      ),
      _GenericMicrofinanceSyncHandler(
        tableName: 'microfinance_borrowers',
        cursors: cursors,
        fromJson: MicrofinanceMappers.borrowerFromJson,
        getId: (b) => b.id,
        getEntrepriseId: (b) => b.entrepriseId,
        loadLocal: local.chargerBorrowers,
        saveLocal: local.sauvegarderBorrowers,
      ),
      _GenericMicrofinanceSyncHandler(
        tableName: 'microfinance_loans',
        cursors: cursors,
        fromJson: MicrofinanceMappers.loanFromJson,
        getId: (l) => l.id,
        getEntrepriseId: (l) => l.entrepriseId,
        loadLocal: local.chargerLoans,
        saveLocal: local.sauvegarderLoans,
      ),
      _GenericMicrofinanceSyncHandler(
        tableName: 'microfinance_installments',
        cursors: cursors,
        fromJson: MicrofinanceMappers.installmentFromJson,
        getId: (i) => i.id,
        getEntrepriseId: (i) => i.entrepriseId,
        loadLocal: local.chargerInstallments,
        saveLocal: local.sauvegarderInstallments,
      ),
      _GenericMicrofinanceSyncHandler(
        tableName: 'microfinance_repayments',
        cursors: cursors,
        fromJson: MicrofinanceMappers.repaymentFromJson,
        getId: (r) => r.id,
        getEntrepriseId: (r) => r.entrepriseId,
        loadLocal: local.chargerRepayments,
        saveLocal: local.sauvegarderRepayments,
      ),
      _GenericMicrofinanceSyncHandler(
        tableName: 'microfinance_transactions',
        cursors: cursors,
        fromJson: MicrofinanceMappers.transactionFromJson,
        getId: (t) => t.id,
        getEntrepriseId: (t) => t.entrepriseId,
        loadLocal: local.chargerTransactions,
        saveLocal: local.sauvegarderTransactions,
      ),
      _GenericMicrofinanceSyncHandler(
        tableName: 'microfinance_audit_logs',
        cursors: cursors,
        fromJson: MicrofinanceMappers.auditLogFromJson,
        getId: (l) => l.id,
        getEntrepriseId: (l) => l.entrepriseId,
        loadLocal: local.chargerAuditLogs,
        saveLocal: local.sauvegarderAuditLogs,
      ),
    ];

class _GenericMicrofinanceSyncHandler<T> implements SyncEntityHandler {
  _GenericMicrofinanceSyncHandler({
    required this.tableName,
    required this.cursors,
    required this.fromJson,
    required this.getId,
    required this.getEntrepriseId,
    required this.loadLocal,
    required this.saveLocal,
  });

  final String tableName;
  final SyncCursorStore cursors;
  final T Function(Map<String, dynamic>) fromJson;
  final String Function(T) getId;
  final String Function(T) getEntrepriseId;
  final Future<List<T>> Function(String entrepriseId) loadLocal;
  final Future<void> Function(String entrepriseId, List<T> items) saveLocal;

  @override
  String get table => tableName;

  @override
  Future<void> applyRemoteRows(List<Map<String, dynamic>> rows) async {
    final activeByCompany = <String, List<T>>{};
    final deletedIdsByCompany = <String, Set<String>>{};

    for (final json in rows) {
      final entrepriseId = json['entreprise_id'] as String?;
      final id = json['id'] as String?;
      if (entrepriseId == null || id == null) continue;
      if (json['deleted_at'] != null) {
        deletedIdsByCompany.putIfAbsent(entrepriseId, () => <String>{}).add(id);
        continue;
      }
      final item = fromJson(json);
      activeByCompany.putIfAbsent(entrepriseId, () => []).add(item);
    }

    final companies = {...activeByCompany.keys, ...deletedIdsByCompany.keys};
    for (final entrepriseId in companies) {
      final actuels = await loadLocal(entrepriseId);
      final map = {for (final x in actuels) getId(x): x};
      for (final deletedId in deletedIdsByCompany[entrepriseId] ?? const <String>{}) {
        map.remove(deletedId);
      }
      for (final distant in activeByCompany[entrepriseId] ?? const <Never>[]) {
        map[getId(distant)] = distant;
      }
      await saveLocal(entrepriseId, map.values.toList());
    }
  }

  @override
  Future<void> onPushApplied(SyncOperation op, Map<String, dynamic>? serverRow) async {
    if (serverRow == null) return;
    final item = fromJson(serverRow);
    final eid = getEntrepriseId(item);
    final actuels = await loadLocal(eid);
    final map = {for (final x in actuels) getId(x): x};
    if (serverRow['deleted_at'] != null) {
      map.remove(getId(item));
    } else {
      map[getId(item)] = item;
    }
    await saveLocal(eid, map.values.toList());
  }

  @override
  Future<void> onConflict(SyncOperation op, Map<String, dynamic>? serverRow) async {
    if (serverRow == null) return;
    await onPushApplied(op, serverRow);
  }

  @override
  Future<void> onRejected(SyncOperation op, Failure failure) async {
    await cursors.reset(table);
  }
}

