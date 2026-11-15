import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/sync/remote/supabase_sync_gateway.dart';
import '../../domain/entities/microfinance_models.dart';
import '../models/microfinance_mappers.dart';

/// Accès distant Supabase aux 8 tables Microfinance (protégées par RLS PRO 5 000 FCFA).
class MicrofinanceRemoteDataSource {
  const MicrofinanceRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<List<T>> _fetch<T>(
    String table,
    String entrepriseId,
    T Function(Map<String, dynamic>) mapper, {
    String orderBy = 'created_at',
  }) async {
    try {
      final rows = await _client
          .from(table)
          .select()
          .eq('entreprise_id', entrepriseId)
          .isFilter('deleted_at', null)
          .order(orderBy, ascending: false);

      return (rows as List<dynamic>).map((j) => mapper(j as Map<String, dynamic>)).toList();
    } on PostgrestException catch (e) {
      if (SupabaseSyncGateway.isMissingRemoteTableError(e) || e.code == '42501') {
        return <T>[];
      }
      rethrow;
    }
  }

  Future<List<MicrofinanceAccount>> chargerAccounts(String entrepriseId) =>
      _fetch('microfinance_accounts', entrepriseId, MicrofinanceMappers.accountFromJson);

  Future<List<MicrofinanceFundMovement>> chargerFunds(String entrepriseId) =>
      _fetch('microfinance_funds', entrepriseId, MicrofinanceMappers.fundFromJson,
          orderBy: 'date_mouvement');

  Future<List<MicrofinanceBorrower>> chargerBorrowers(String entrepriseId) =>
      _fetch('microfinance_borrowers', entrepriseId, MicrofinanceMappers.borrowerFromJson);

  Future<List<MicrofinanceLoan>> chargerLoans(String entrepriseId) =>
      _fetch('microfinance_loans', entrepriseId, MicrofinanceMappers.loanFromJson,
          orderBy: 'date_octroi');

  Future<List<MicrofinanceInstallment>> chargerInstallments(String entrepriseId) =>
      _fetch('microfinance_installments', entrepriseId, MicrofinanceMappers.installmentFromJson,
          orderBy: 'date_prevue');

  Future<List<MicrofinanceRepayment>> chargerRepayments(String entrepriseId) =>
      _fetch('microfinance_repayments', entrepriseId, MicrofinanceMappers.repaymentFromJson,
          orderBy: 'date_paiement');

  Future<List<MicrofinanceTransaction>> chargerTransactions(String entrepriseId) =>
      _fetch('microfinance_transactions', entrepriseId, MicrofinanceMappers.transactionFromJson,
          orderBy: 'date_transaction');

  Future<List<MicrofinanceAuditLog>> chargerAuditLogs(String entrepriseId) =>
      _fetch('microfinance_audit_logs', entrepriseId, MicrofinanceMappers.auditLogFromJson);
}

