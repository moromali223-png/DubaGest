import 'dart:convert';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/microfinance_models.dart';
import '../models/microfinance_mappers.dart';

/// Stockage local hors-ligne pour les 8 entités Microfinance via Drift `JsonCache`.
class MicrofinanceLocalDataSource {
  MicrofinanceLocalDataSource(this._db);

  final AppDatabase _db;

  Future<T> transaction<T>(Future<T> Function() action) => _db.transaction(action);

  Future<List<T>> _chargerListe<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final row = await (_db.select(_db.jsonCache)..where((t) => t.cle.equals(key))).getSingleOrNull();
    if (row == null || row.contenu.isEmpty) return const [];
    try {
      final list = jsonDecode(row.contenu) as List<dynamic>;
      return list.map((e) => fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _sauvegarderListe<T>(
    String key,
    List<T> items,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    final jsonStr = jsonEncode(items.map(toJson).toList());
    await _db.into(_db.jsonCache).insertOnConflictUpdate(
          JsonCacheCompanion.insert(
            cle: key,
            contenu: jsonStr,
            majLe: DateTime.now(),
          ),
        );
  }

  // --- Accounts ---
  Future<List<MicrofinanceAccount>> chargerAccounts(String entrepriseId) =>
      _chargerListe('mf_accounts_$entrepriseId', MicrofinanceMappers.accountFromJson);

  Future<void> sauvegarderAccounts(String entrepriseId, List<MicrofinanceAccount> items) =>
      _sauvegarderListe('mf_accounts_$entrepriseId', items, MicrofinanceMappers.accountToJson);

  // --- Funds ---
  Future<List<MicrofinanceFundMovement>> chargerFunds(String entrepriseId) =>
      _chargerListe('mf_funds_$entrepriseId', MicrofinanceMappers.fundFromJson);

  Future<void> sauvegarderFunds(String entrepriseId, List<MicrofinanceFundMovement> items) =>
      _sauvegarderListe('mf_funds_$entrepriseId', items, MicrofinanceMappers.fundToJson);

  // --- Borrowers ---
  Future<List<MicrofinanceBorrower>> chargerBorrowers(String entrepriseId) =>
      _chargerListe('mf_borrowers_$entrepriseId', MicrofinanceMappers.borrowerFromJson);

  Future<void> sauvegarderBorrowers(String entrepriseId, List<MicrofinanceBorrower> items) =>
      _sauvegarderListe('mf_borrowers_$entrepriseId', items, MicrofinanceMappers.borrowerToJson);

  // --- Loans ---
  Future<List<MicrofinanceLoan>> chargerLoans(String entrepriseId) =>
      _chargerListe('mf_loans_$entrepriseId', MicrofinanceMappers.loanFromJson);

  Future<void> sauvegarderLoans(String entrepriseId, List<MicrofinanceLoan> items) =>
      _sauvegarderListe('mf_loans_$entrepriseId', items, MicrofinanceMappers.loanToJson);

  // --- Installments ---
  Future<List<MicrofinanceInstallment>> chargerInstallments(String entrepriseId) =>
      _chargerListe('mf_installments_$entrepriseId', MicrofinanceMappers.installmentFromJson);

  Future<void> sauvegarderInstallments(String entrepriseId, List<MicrofinanceInstallment> items) =>
      _sauvegarderListe('mf_installments_$entrepriseId', items, MicrofinanceMappers.installmentToJson);

  // --- Repayments ---
  Future<List<MicrofinanceRepayment>> chargerRepayments(String entrepriseId) =>
      _chargerListe('mf_repayments_$entrepriseId', MicrofinanceMappers.repaymentFromJson);

  Future<void> sauvegarderRepayments(String entrepriseId, List<MicrofinanceRepayment> items) =>
      _sauvegarderListe('mf_repayments_$entrepriseId', items, MicrofinanceMappers.repaymentToJson);

  // --- Transactions ---
  Future<List<MicrofinanceTransaction>> chargerTransactions(String entrepriseId) =>
      _chargerListe('mf_transactions_$entrepriseId', MicrofinanceMappers.transactionFromJson);

  Future<void> sauvegarderTransactions(String entrepriseId, List<MicrofinanceTransaction> items) =>
      _sauvegarderListe('mf_transactions_$entrepriseId', items, MicrofinanceMappers.transactionToJson);

  // --- Audit logs ---
  Future<List<MicrofinanceAuditLog>> chargerAuditLogs(String entrepriseId) =>
      _chargerListe('mf_audit_logs_$entrepriseId', MicrofinanceMappers.auditLogFromJson);

  Future<void> sauvegarderAuditLogs(String entrepriseId, List<MicrofinanceAuditLog> items) =>
      _sauvegarderListe('mf_audit_logs_$entrepriseId', items, MicrofinanceMappers.auditLogToJson);
}

