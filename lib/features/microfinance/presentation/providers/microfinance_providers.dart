import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/core_providers.dart';
import '../../../../core/di/sync_providers.dart';
import '../../../../core/sync/sync_contracts.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../modules/domain/entities/app_module.dart';
import '../../data/datasources/microfinance_local_data_source.dart';
import '../../data/datasources/microfinance_remote_data_source.dart';
import '../../data/datasources/microfinance_sync_handlers.dart';
import '../../data/repositories/microfinance_repository_impl.dart';
import '../../domain/entities/microfinance_enums.dart';
import '../../domain/entities/microfinance_models.dart';
import '../../domain/repositories/microfinance_repository.dart';
import '../../domain/services/delinquency_analyzer.dart';

// --- DATA SOURCES & REPOSITORY ---

final microfinanceLocalDataSourceProvider = Provider<MicrofinanceLocalDataSource>((ref) {
  return MicrofinanceLocalDataSource(ref.watch(appDatabaseProvider));
});

final microfinanceRemoteDataSourceProvider = Provider<MicrofinanceRemoteDataSource>((ref) {
  return MicrofinanceRemoteDataSource(ref.watch(supabaseClientProvider));
});

final microfinanceRepositoryProvider = Provider<MicrofinanceRepository>((ref) {
  return MicrofinanceRepositoryImpl(
    local: ref.watch(microfinanceLocalDataSourceProvider),
    remote: ref.watch(microfinanceRemoteDataSourceProvider),
    queue: ref.watch(syncQueueStoreProvider),
    currentContext: () => ref.read(contexteActifProvider),
    requestSync: ref.watch(syncTriggerProvider),
  );
});

final microfinanceSyncHandlersProvider = Provider<List<SyncEntityHandler>>((ref) {
  return microfinanceSyncHandlers(
    ref.watch(microfinanceLocalDataSourceProvider),
    ref.watch(syncCursorStoreProvider),
  );
});

// --- CONTRÔLE D'ACCÈS ABONNEMENT PRO ---

final hasMicrofinanceAccessProvider = Provider<bool>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null) return false;
  return ctx.accessPolicy().canAccessModule(ModuleCodes.commerceMicrofinance).isAllowed;
});

// --- STREAMS DES ENTITÉS ---

String? _entrepriseProOuNull(Ref ref) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx?.entreprise == null) return null;
  if (!ctx!.accessPolicy().canAccessModule(ModuleCodes.commerceMicrofinance).isAllowed) {
    return null;
  }
  return ctx.entreprise!.id;
}

final mfAccountsProvider = StreamProvider.autoDispose<List<MicrofinanceAccount>>((ref) {
  final eid = _entrepriseProOuNull(ref);
  if (eid == null) return Stream.value(const []);
  final repo = ref.watch(microfinanceRepositoryProvider);
  repo.refresh(eid);
  return repo.watchAccounts(eid);
});

final mfFundMovementsProvider = StreamProvider.autoDispose<List<MicrofinanceFundMovement>>((ref) {
  final eid = _entrepriseProOuNull(ref);
  if (eid == null) return Stream.value(const []);
  return ref.watch(microfinanceRepositoryProvider).watchFundMovements(eid);
});

final mfBorrowersProvider = StreamProvider.autoDispose<List<MicrofinanceBorrower>>((ref) {
  final eid = _entrepriseProOuNull(ref);
  if (eid == null) return Stream.value(const []);
  return ref.watch(microfinanceRepositoryProvider).watchBorrowers(eid);
});

final mfLoansProvider = StreamProvider.autoDispose<List<MicrofinanceLoan>>((ref) {
  final eid = _entrepriseProOuNull(ref);
  if (eid == null) return Stream.value(const []);
  return ref.watch(microfinanceRepositoryProvider).watchLoans(eid);
});

final mfInstallmentsProvider = StreamProvider.autoDispose<List<MicrofinanceInstallment>>((ref) {
  final eid = _entrepriseProOuNull(ref);
  if (eid == null) return Stream.value(const []);
  return ref.watch(microfinanceRepositoryProvider).watchInstallments(eid);
});

final mfRepaymentsProvider = StreamProvider.autoDispose<List<MicrofinanceRepayment>>((ref) {
  final eid = _entrepriseProOuNull(ref);
  if (eid == null) return Stream.value(const []);
  return ref.watch(microfinanceRepositoryProvider).watchRepayments(eid);
});

final mfTransactionsProvider = StreamProvider.autoDispose<List<MicrofinanceTransaction>>((ref) {
  final eid = _entrepriseProOuNull(ref);
  if (eid == null) return Stream.value(const []);
  return ref.watch(microfinanceRepositoryProvider).watchTransactions(eid);
});

final mfAuditLogsProvider = StreamProvider.autoDispose<List<MicrofinanceAuditLog>>((ref) {
  final eid = _entrepriseProOuNull(ref);
  if (eid == null) return Stream.value(const []);
  return ref.watch(microfinanceRepositoryProvider).watchAuditLogs(eid);
});

// --- FILTRES & PÉRIODE TABLEAU DE BORD ---

class MfPeriodeState {
  const MfPeriodeState({
    this.periode = PeriodeMicrofinance.tout,
    this.debutCustom,
    this.finCustom,
  });

  final PeriodeMicrofinance periode;
  final DateTime? debutCustom;
  final DateTime? finCustom;
}

class MfPeriodeNotifier extends Notifier<MfPeriodeState> {
  @override
  MfPeriodeState build() => const MfPeriodeState();

  void choisir(PeriodeMicrofinance p, {DateTime? debut, DateTime? fin}) {
    state = MfPeriodeState(periode: p, debutCustom: debut, finCustom: fin);
  }
}

final mfPeriodeProvider = NotifierProvider<MfPeriodeNotifier, MfPeriodeState>(MfPeriodeNotifier.new);

final mfDashboardStatsProvider = Provider.autoDispose<MicrofinanceDashboardStats>((ref) {
  final accounts = ref.watch(mfAccountsProvider).value ?? const [];
  final funds = ref.watch(mfFundMovementsProvider).value ?? const [];
  final borrowers = ref.watch(mfBorrowersProvider).value ?? const [];
  final loans = ref.watch(mfLoansProvider).value ?? const [];
  final installments = ref.watch(mfInstallmentsProvider).value ?? const [];
  final repayments = ref.watch(mfRepaymentsProvider).value ?? const [];
  final pState = ref.watch(mfPeriodeProvider);

  final (debut, fin) = DelinquencyAnalyzer.bornesPeriode(
    pState.periode,
    DateTime.now(),
    debutCustom: pState.debutCustom,
    finCustom: pState.finCustom,
  );

  return DelinquencyAnalyzer.calculerDashboard(
    accounts: accounts,
    fundMovements: funds,
    borrowers: borrowers,
    loans: loans,
    installments: installments,
    repayments: repayments,
    debut: debut,
    fin: fin,
  );
});

/// Synthèse financière de tous les emprunteurs (indexée par `borrowerId`).
final mfBorrowerSummariesProvider =
    Provider.autoDispose<Map<String, MicrofinanceBorrowerSummary>>((ref) {
  final borrowers = ref.watch(mfBorrowersProvider).value ?? const [];
  final loans = ref.watch(mfLoansProvider).value ?? const [];
  final installments = ref.watch(mfInstallmentsProvider).value ?? const [];
  final now = DateTime.now();

  return {
    for (final b in borrowers)
      if (b.deletedAt == null)
        b.id: DelinquencyAnalyzer.synthetiserEmprunteur(
          borrower: b,
          loans: loans,
          installments: installments,
          now: now,
        ),
  };
});

