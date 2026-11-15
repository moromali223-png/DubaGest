import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/permissions/access_decision.dart';
import '../../../../core/sync/sync_contracts.dart';
import '../../../../core/sync/sync_models.dart';
import '../../../entreprise/domain/entities/contexte_session.dart';
import '../../../modules/domain/entities/app_module.dart';
import '../../domain/entities/microfinance_enums.dart';
import '../../domain/entities/microfinance_models.dart';
import '../../domain/repositories/microfinance_repository.dart';
import '../../domain/services/delinquency_analyzer.dart';
import '../../domain/services/loan_interest_calculator.dart';
import '../../domain/services/repayment_allocator.dart';
import '../datasources/microfinance_local_data_source.dart';
import '../datasources/microfinance_remote_data_source.dart';
import '../models/microfinance_mappers.dart';

/// Référentiel Offline-First du module Microfinance.
///
/// Toute écriture :
/// 1. Vérifie l'accès actif à la formule PRO (5 000 FCFA) ;
/// 2. Valide les soldes disponibles et invariants comptables ;
/// 3. Enregistre atomiquement en cache local + file `SyncQueueStore` ;
/// 4. Inscrit les mouvements au journal central immuable + journal d'audit ;
/// 5. Déclenche la synchronisation asynchrone via `_requestSync()`.
class MicrofinanceRepositoryImpl implements MicrofinanceRepository {
  MicrofinanceRepositoryImpl({
    required MicrofinanceLocalDataSource local,
    required MicrofinanceRemoteDataSource remote,
    required SyncQueueStore queue,
    required ContexteSession? Function() currentContext,
    required SyncTrigger requestSync,
  })  : _local = local,
        _remote = remote,
        _queue = queue,
        _currentContext = currentContext,
        _requestSync = requestSync;

  final MicrofinanceLocalDataSource _local;
  final MicrofinanceRemoteDataSource _remote;
  final SyncQueueStore _queue;
  final ContexteSession? Function() _currentContext;
  final SyncTrigger _requestSync;

  static const _uuid = Uuid();

  final _accountsCtrl = <String, StreamController<List<MicrofinanceAccount>>>{};
  final _fundsCtrl = <String, StreamController<List<MicrofinanceFundMovement>>>{};
  final _borrowersCtrl = <String, StreamController<List<MicrofinanceBorrower>>>{};
  final _loansCtrl = <String, StreamController<List<MicrofinanceLoan>>>{};
  final _installmentsCtrl = <String, StreamController<List<MicrofinanceInstallment>>>{};
  final _repaymentsCtrl = <String, StreamController<List<MicrofinanceRepayment>>>{};
  final _txCtrl = <String, StreamController<List<MicrofinanceTransaction>>>{};
  final _auditCtrl = <String, StreamController<List<MicrofinanceAuditLog>>>{};

  String _requireProUser() {
    final ctx = _currentContext();
    if (ctx == null) {
      throw const Failure(FailureKind.sessionExpired);
    }
    final decision = ctx.accessPolicy().canAccessModule(ModuleCodes.commerceMicrofinance);
    if (!decision.isAllowed) {
      throw Failure.rule(
        RuleCodes.mfProRequired,
        const {'module': ModuleCodes.commerceMicrofinance},
      );
    }
    return ctx.userId;
  }

  String _genRef(String prefix, int existingCount) {
    final annee = DateTime.now().year;
    final numStr = (existingCount + 1).toString().padLeft(4, '0');
    final suffix = _uuid.v4().substring(0, 4).toUpperCase();
    return '$prefix-$annee-$numStr-$suffix';
  }

  Stream<List<T>> _watchStream<T>(
    Map<String, StreamController<List<T>>> ctrls,
    String entrepriseId,
    Future<List<T>> Function(String) loader,
  ) {
    ctrls[entrepriseId] ??= StreamController<List<T>>.broadcast(
      onListen: () async {
        final items = await loader(entrepriseId);
        ctrls[entrepriseId]?.add(items);
      },
    );
    Future.microtask(() async {
      final items = await loader(entrepriseId);
      ctrls[entrepriseId]?.add(items);
    });
    return ctrls[entrepriseId]!.stream;
  }

  @override
  Stream<List<MicrofinanceAccount>> watchAccounts(String entrepriseId) =>
      _watchStream(_accountsCtrl, entrepriseId, _local.chargerAccounts);

  @override
  Stream<List<MicrofinanceFundMovement>> watchFundMovements(String entrepriseId) =>
      _watchStream(_fundsCtrl, entrepriseId, _local.chargerFunds);

  @override
  Stream<List<MicrofinanceBorrower>> watchBorrowers(String entrepriseId) =>
      _watchStream(_borrowersCtrl, entrepriseId, _local.chargerBorrowers);

  @override
  Stream<List<MicrofinanceLoan>> watchLoans(String entrepriseId) =>
      _watchStream(_loansCtrl, entrepriseId, _local.chargerLoans);

  @override
  Stream<List<MicrofinanceInstallment>> watchInstallments(String entrepriseId) =>
      _watchStream(_installmentsCtrl, entrepriseId, _local.chargerInstallments);

  @override
  Stream<List<MicrofinanceRepayment>> watchRepayments(String entrepriseId) =>
      _watchStream(_repaymentsCtrl, entrepriseId, _local.chargerRepayments);

  @override
  Stream<List<MicrofinanceTransaction>> watchTransactions(String entrepriseId) =>
      _watchStream(_txCtrl, entrepriseId, _local.chargerTransactions);

  @override
  Stream<List<MicrofinanceAuditLog>> watchAuditLogs(String entrepriseId) =>
      _watchStream(_auditCtrl, entrepriseId, _local.chargerAuditLogs);

  Future<void> _emitAll(String entrepriseId) async {
    _accountsCtrl[entrepriseId]?.add(await _local.chargerAccounts(entrepriseId));
    _fundsCtrl[entrepriseId]?.add(await _local.chargerFunds(entrepriseId));
    _borrowersCtrl[entrepriseId]?.add(await _local.chargerBorrowers(entrepriseId));
    _loansCtrl[entrepriseId]?.add(await _local.chargerLoans(entrepriseId));
    _installmentsCtrl[entrepriseId]?.add(await _local.chargerInstallments(entrepriseId));
    _repaymentsCtrl[entrepriseId]?.add(await _local.chargerRepayments(entrepriseId));
    _txCtrl[entrepriseId]?.add(await _local.chargerTransactions(entrepriseId));
    _auditCtrl[entrepriseId]?.add(await _local.chargerAuditLogs(entrepriseId));
  }

  @override
  Future<void> refresh(String entrepriseId) async {
    final ctx = _currentContext();
    if (ctx == null) return;
    if (!ctx.accessPolicy().canAccessModule(ModuleCodes.commerceMicrofinance).isAllowed) return;
    try {
      final enAttente = await _queue.pendingCount(ctx.userId);
      if (enAttente > 0) {
        // Des opérations locales attendent d'être poussées : ne pas écraser le cache local.
        _requestSync();
        await _emitAll(entrepriseId);
        return;
      }
      final results = await Future.wait([
        _remote.chargerAccounts(entrepriseId),
        _remote.chargerFunds(entrepriseId),
        _remote.chargerBorrowers(entrepriseId),
        _remote.chargerLoans(entrepriseId),
        _remote.chargerInstallments(entrepriseId),
        _remote.chargerRepayments(entrepriseId),
        _remote.chargerTransactions(entrepriseId),
        _remote.chargerAuditLogs(entrepriseId),
      ]);
      await _fusionnerEtSauvegarder(
        entrepriseId: entrepriseId,
        remotes: results[0] as List<MicrofinanceAccount>,
        loader: _local.chargerAccounts,
        saver: _local.sauvegarderAccounts,
        getId: (x) => x.id,
      );
      await _fusionnerEtSauvegarder(
        entrepriseId: entrepriseId,
        remotes: results[1] as List<MicrofinanceFundMovement>,
        loader: _local.chargerFunds,
        saver: _local.sauvegarderFunds,
        getId: (x) => x.id,
      );
      await _fusionnerEtSauvegarder(
        entrepriseId: entrepriseId,
        remotes: results[2] as List<MicrofinanceBorrower>,
        loader: _local.chargerBorrowers,
        saver: _local.sauvegarderBorrowers,
        getId: (x) => x.id,
      );
      await _fusionnerEtSauvegarder(
        entrepriseId: entrepriseId,
        remotes: results[3] as List<MicrofinanceLoan>,
        loader: _local.chargerLoans,
        saver: _local.sauvegarderLoans,
        getId: (x) => x.id,
      );
      await _fusionnerEtSauvegarder(
        entrepriseId: entrepriseId,
        remotes: results[4] as List<MicrofinanceInstallment>,
        loader: _local.chargerInstallments,
        saver: _local.sauvegarderInstallments,
        getId: (x) => x.id,
      );
      await _fusionnerEtSauvegarder(
        entrepriseId: entrepriseId,
        remotes: results[5] as List<MicrofinanceRepayment>,
        loader: _local.chargerRepayments,
        saver: _local.sauvegarderRepayments,
        getId: (x) => x.id,
      );
      await _fusionnerEtSauvegarder(
        entrepriseId: entrepriseId,
        remotes: results[6] as List<MicrofinanceTransaction>,
        loader: _local.chargerTransactions,
        saver: _local.sauvegarderTransactions,
        getId: (x) => x.id,
      );
      await _fusionnerEtSauvegarder(
        entrepriseId: entrepriseId,
        remotes: results[7] as List<MicrofinanceAuditLog>,
        loader: _local.chargerAuditLogs,
        saver: _local.sauvegarderAuditLogs,
        getId: (x) => x.id,
      );
      await _emitAll(entrepriseId);
    } catch (_) {
      // Hors-ligne ou erreur réseau : conserver les données locales intactes.
      await _emitAll(entrepriseId);
    }
  }

  Future<void> _fusionnerEtSauvegarder<T>({
    required String entrepriseId,
    required List<T> remotes,
    required Future<List<T>> Function(String) loader,
    required Future<void> Function(String, List<T>) saver,
    required String Function(T) getId,
  }) async {
    final actuels = await loader(entrepriseId);
    final map = {for (final x in actuels) getId(x): x};
    for (final distant in remotes) {
      map[getId(distant)] = distant;
    }
    await saver(entrepriseId, map.values.toList());
  }

  Future<void> _upsertLocal<T>(
    String entrepriseId,
    Future<List<T>> Function(String) loader,
    Future<void> Function(String, List<T>) saver,
    T item,
    String Function(T) getId,
  ) async {
    final list = List<T>.from(await loader(entrepriseId));
    final idx = list.indexWhere((e) => getId(e) == getId(item));
    if (idx >= 0) {
      list[idx] = item;
    } else {
      list.insert(0, item);
    }
    await saver(entrepriseId, list);
  }

  Future<void> _enregistrerAudit({
    required String userId,
    required String entrepriseId,
    String? perimetreId,
    required String action,
    required String entiteType,
    required String entiteId,
    String? referenceEntite,
    Map<String, dynamic>? detailsAvant,
    Map<String, dynamic>? detailsApres,
    String? motif,
  }) async {
    final now = DateTime.now();
    final log = MicrofinanceAuditLog(
      id: _uuid.v4(),
      entrepriseId: entrepriseId,
      perimetreId: perimetreId,
      action: action,
      entiteType: entiteType,
      entiteId: entiteId,
      referenceEntite: referenceEntite,
      utilisateurId: userId,
      detailsAvant: detailsAvant,
      detailsApres: detailsApres,
      motif: motif,
      createdAt: now,
      updatedAt: now,
    );
    await _upsertLocal(
      entrepriseId,
      _local.chargerAuditLogs,
      _local.sauvegarderAuditLogs,
      log,
      (x) => x.id,
    );
    await _queue.enqueue(
      userId: userId,
      entityTable: 'microfinance_audit_logs',
      recordId: log.id,
      type: SyncOperationType.insert,
      payload: MicrofinanceMappers.auditLogToJson(log),
    );
  }

  Future<void> _enregistrerTransaction({
    required String userId,
    required MicrofinanceTransaction tx,
  }) async {
    await _upsertLocal(
      tx.entrepriseId,
      _local.chargerTransactions,
      _local.sauvegarderTransactions,
      tx,
      (x) => x.id,
    );
    await _queue.enqueue(
      userId: userId,
      entityTable: 'microfinance_transactions',
      recordId: tx.id,
      type: SyncOperationType.insert,
      payload: MicrofinanceMappers.transactionToJson(tx),
    );
  }

  // --- COMPTES & CAPITAL ---

  @override
  Future<MicrofinanceAccount> sauvegarderCompte(
    MicrofinanceAccount account, {
    bool enregistrerApportInitial = true,
  }) async {
    final userId = _requireProUser();
    try {
      final existants = await _local.chargerAccounts(account.entrepriseId);
      final isNew = !existants.any((a) => a.id == account.id);
      final now = DateTime.now();

      final saved = MicrofinanceAccount(
        id: account.id,
        entrepriseId: account.entrepriseId,
        perimetreId: account.perimetreId,
        nom: account.nom.trim(),
        typeCompte: account.typeCompte,
        sourceFondsDefaut: account.sourceFondsDefaut,
        caisseId: account.caisseId,
        numeroCompte: account.numeroCompte?.trim(),
        soldeInitial: account.soldeInitial,
        soldeActuel: isNew ? account.soldeInitial : account.soldeActuel,
        devise: account.devise,
        estActif: account.estActif,
        observations: account.observations?.trim(),
        creePar: account.creePar ?? userId,
        version: isNew ? 1 : account.version + 1,
        createdAt: isNew ? now : account.createdAt,
        updatedAt: now,
      );

      await _local.transaction(() async {
        await _upsertLocal(
          saved.entrepriseId,
          _local.chargerAccounts,
          _local.sauvegarderAccounts,
          saved,
          (x) => x.id,
        );
        await _queue.enqueue(
          userId: userId,
          entityTable: 'microfinance_accounts',
          recordId: saved.id,
          type: isNew ? SyncOperationType.insert : SyncOperationType.update,
          payload: MicrofinanceMappers.accountToJson(saved),
          baseVersion: isNew ? null : account.version,
        );

        // Si nouveau compte doté d'un capital initial, enregistrer le mouvement + écriture au grand-livre
        if (isNew && enregistrerApportInitial && saved.soldeInitial > 0) {
          final funds = await _local.chargerFunds(saved.entrepriseId);
          final fundRef = _genRef('CAP', funds.length);
          final fund = MicrofinanceFundMovement(
            id: _uuid.v4(),
            entrepriseId: saved.entrepriseId,
            perimetreId: saved.perimetreId,
            reference: fundRef,
            accountId: saved.id,
            typeMouvement: TypeMouvementFonds.apportInitial,
            sourceFonds: saved.sourceFondsDefaut,
            montant: saved.soldeInitial,
            modePaiement: _modeParDefaut(saved.typeCompte),
            dateMouvement: now,
            libelle: 'Capital initial — ${saved.nom}',
            observations: saved.observations,
            creePar: userId,
            createdAt: now,
            updatedAt: now,
          );
          await _upsertLocal(
            saved.entrepriseId,
            _local.chargerFunds,
            _local.sauvegarderFunds,
            fund,
            (x) => x.id,
          );
          await _queue.enqueue(
            userId: userId,
            entityTable: 'microfinance_funds',
            recordId: fund.id,
            type: SyncOperationType.insert,
            payload: MicrofinanceMappers.fundToJson(fund),
          );

          final txs = await _local.chargerTransactions(saved.entrepriseId);
          await _enregistrerTransaction(
            userId: userId,
            tx: MicrofinanceTransaction(
              id: _uuid.v4(),
              entrepriseId: saved.entrepriseId,
              perimetreId: saved.perimetreId,
              reference: _genRef('TXM', txs.length),
              dateTransaction: now,
              typeTransaction: TypeTransactionMicrofinance.apportCapital,
              montant: saved.soldeInitial,
              sens: SensTransactionMicrofinance.entree,
              modePaiement: fund.modePaiement,
              accountId: saved.id,
              fundId: fund.id,
              libelle: fund.libelle,
              observations: 'Dotation initiale (${saved.sourceFondsDefaut.libelle("fr")})',
              creePar: userId,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }

        await _enregistrerAudit(
          userId: userId,
          entrepriseId: saved.entrepriseId,
          perimetreId: saved.perimetreId,
          action: isNew ? 'CREATION_COMPTE' : 'MODIFICATION_COMPTE',
          entiteType: 'microfinance_accounts',
          entiteId: saved.id,
          referenceEntite: saved.nom,
          detailsApres: MicrofinanceMappers.accountToJson(saved),
        );
      });

      await _emitAll(saved.entrepriseId);
      _requestSync();
      return saved;
    } catch (e, st) {
      if (e is Failure) rethrow;
      throw ErrorMapper.map(e, st);
    }
  }

  ModePaiementMicrofinance _modeParDefaut(TypeCompteMicrofinance t) => switch (t) {
        TypeCompteMicrofinance.caissePhysique => ModePaiementMicrofinance.especes,
        TypeCompteMicrofinance.banque => ModePaiementMicrofinance.virement,
        TypeCompteMicrofinance.orangeMoney => ModePaiementMicrofinance.orangeMoney,
        TypeCompteMicrofinance.mobileMoney => ModePaiementMicrofinance.mobileMoney,
        TypeCompteMicrofinance.autre => ModePaiementMicrofinance.autre,
      };

  @override
  Future<MicrofinanceFundMovement> enregistrerMouvementFonds({
    required String entrepriseId,
    String? perimetreId,
    required String accountId,
    String? accountDestinationId,
    required TypeMouvementFonds typeMouvement,
    required SourceFondsMicrofinance sourceFonds,
    required int montant,
    required ModePaiementMicrofinance modePaiement,
    required DateTime dateMouvement,
    required String libelle,
    String? observations,
  }) async {
    final userId = _requireProUser();
    if (montant <= 0) throw const Failure.rule(RuleCodes.amountInvalid);
    if (libelle.trim().isEmpty) throw const Failure.rule(RuleCodes.labelInvalid);
    if (typeMouvement == TypeMouvementFonds.transfertInterne &&
        (accountDestinationId == null || accountDestinationId == accountId)) {
      throw const Failure.rule(RuleCodes.transferSame);
    }

    try {
      final accounts = await _local.chargerAccounts(entrepriseId);
      final srcIdx = accounts.indexWhere((a) => a.id == accountId && a.deletedAt == null);
      if (srcIdx < 0) throw const Failure.rule(RuleCodes.targetInvalid);
      final srcAccount = accounts[srcIdx];

      MicrofinanceAccount? dstAccount;
      if (typeMouvement == TypeMouvementFonds.transfertInterne) {
        dstAccount = accounts.where((a) => a.id == accountDestinationId && a.deletedAt == null).firstOrNull;
        if (dstAccount == null) throw const Failure.rule(RuleCodes.targetInvalid);
      }

      final estSortieSource = typeMouvement == TypeMouvementFonds.retraitCapital ||
          typeMouvement == TypeMouvementFonds.depenseFonctionnement ||
          typeMouvement == TypeMouvementFonds.transfertInterne;

      if (estSortieSource && srcAccount.soldeActuel < montant) {
        throw Failure.rule(RuleCodes.cashInsufficient, {'solde': srcAccount.soldeActuel});
      }

      final now = DateTime.now();
      final funds = await _local.chargerFunds(entrepriseId);
      final txs = await _local.chargerTransactions(entrepriseId);

      final fund = MicrofinanceFundMovement(
        id: _uuid.v4(),
        entrepriseId: entrepriseId,
        perimetreId: perimetreId,
        reference: _genRef('FND', funds.length),
        accountId: accountId,
        accountDestinationId: accountDestinationId,
        typeMouvement: typeMouvement,
        sourceFonds: sourceFonds,
        montant: montant,
        modePaiement: modePaiement,
        dateMouvement: dateMouvement,
        libelle: libelle.trim(),
        observations: observations?.trim(),
        creePar: userId,
        createdAt: now,
        updatedAt: now,
      );

      final updatedSrc = srcAccount.copyWith(
        soldeActuel: estSortieSource ? srcAccount.soldeActuel - montant : srcAccount.soldeActuel + montant,
        updatedAt: now,
      );
      final updatedDst = dstAccount?.copyWith(
        soldeActuel: dstAccount.soldeActuel + montant,
        updatedAt: now,
      );

      await _local.transaction(() async {
        await _upsertLocal(
          entrepriseId,
          _local.chargerFunds,
          _local.sauvegarderFunds,
          fund,
          (x) => x.id,
        );
        await _queue.enqueue(
          userId: userId,
          entityTable: 'microfinance_funds',
          recordId: fund.id,
          type: SyncOperationType.insert,
          payload: MicrofinanceMappers.fundToJson(fund),
        );

        await _upsertLocal(
          entrepriseId,
          _local.chargerAccounts,
          _local.sauvegarderAccounts,
          updatedSrc,
          (x) => x.id,
        );
        await _queue.enqueue(
          userId: userId,
          entityTable: 'microfinance_accounts',
          recordId: updatedSrc.id,
          type: SyncOperationType.update,
          payload: MicrofinanceMappers.accountToJson(updatedSrc),
          baseVersion: srcAccount.version,
        );

        if (updatedDst != null && dstAccount != null) {
          await _upsertLocal(
            entrepriseId,
            _local.chargerAccounts,
            _local.sauvegarderAccounts,
            updatedDst,
            (x) => x.id,
          );
          await _queue.enqueue(
            userId: userId,
            entityTable: 'microfinance_accounts',
            recordId: updatedDst.id,
            type: SyncOperationType.update,
            payload: MicrofinanceMappers.accountToJson(updatedDst),
            baseVersion: dstAccount.version,
          );
        }

        if (typeMouvement == TypeMouvementFonds.transfertInterne && updatedDst != null) {
          await _enregistrerTransaction(
            userId: userId,
            tx: MicrofinanceTransaction(
              id: _uuid.v4(),
              entrepriseId: entrepriseId,
              perimetreId: perimetreId,
              reference: _genRef('TXM-TRS', txs.length),
              dateTransaction: dateMouvement,
              typeTransaction: TypeTransactionMicrofinance.transfertSortant,
              montant: montant,
              sens: SensTransactionMicrofinance.neutre,
              modePaiement: modePaiement,
              accountId: updatedSrc.id,
              accountDestinationId: updatedDst.id,
              fundId: fund.id,
              libelle: 'Transfert vers ${updatedDst.nom} : ${fund.libelle}',
              observations: fund.observations,
              creePar: userId,
              createdAt: now,
              updatedAt: now,
            ),
          );
          await _enregistrerTransaction(
            userId: userId,
            tx: MicrofinanceTransaction(
              id: _uuid.v4(),
              entrepriseId: entrepriseId,
              perimetreId: perimetreId,
              reference: _genRef('TXM-TRE', txs.length + 1),
              dateTransaction: dateMouvement,
              typeTransaction: TypeTransactionMicrofinance.transfertEntrant,
              montant: montant,
              sens: SensTransactionMicrofinance.neutre,
              modePaiement: modePaiement,
              accountId: updatedDst.id,
              accountDestinationId: updatedSrc.id,
              fundId: fund.id,
              libelle: 'Transfert reçu de ${updatedSrc.nom} : ${fund.libelle}',
              observations: fund.observations,
              creePar: userId,
              createdAt: now,
              updatedAt: now,
            ),
          );
        } else {
          final typeTx = switch (typeMouvement) {
            TypeMouvementFonds.apportInitial ||
            TypeMouvementFonds.apportSupplementaire =>
              TypeTransactionMicrofinance.apportCapital,
            TypeMouvementFonds.retraitCapital => TypeTransactionMicrofinance.retraitCapital,
            TypeMouvementFonds.depenseFonctionnement =>
              TypeTransactionMicrofinance.depenseFonctionnement,
            TypeMouvementFonds.transfertInterne => TypeTransactionMicrofinance.transfertSortant,
          };
          final sensTx = estSortieSource
              ? SensTransactionMicrofinance.sortie
              : SensTransactionMicrofinance.entree;
          await _enregistrerTransaction(
            userId: userId,
            tx: MicrofinanceTransaction(
              id: _uuid.v4(),
              entrepriseId: entrepriseId,
              perimetreId: perimetreId,
              reference: _genRef('TXM', txs.length),
              dateTransaction: dateMouvement,
              typeTransaction: typeTx,
              montant: montant,
              sens: sensTx,
              modePaiement: modePaiement,
              accountId: updatedSrc.id,
              fundId: fund.id,
              libelle: fund.libelle,
              observations: fund.observations,
              creePar: userId,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }

        await _enregistrerAudit(
          userId: userId,
          entrepriseId: entrepriseId,
          perimetreId: perimetreId,
          action: 'MOUVEMENT_${typeMouvement.code}',
          entiteType: 'microfinance_funds',
          entiteId: fund.id,
          referenceEntite: fund.reference,
          detailsApres: MicrofinanceMappers.fundToJson(fund),
        );
      });

      await _emitAll(entrepriseId);
      _requestSync();
      return fund;
    } catch (e, st) {
      if (e is Failure) rethrow;
      throw ErrorMapper.map(e, st);
    }
  }

  // --- EMPRUNTEURS ---

  @override
  Future<MicrofinanceBorrower> sauvegarderEmprunteur(MicrofinanceBorrower borrower) async {
    final userId = _requireProUser();
    if (borrower.nomComplet.trim().isEmpty) throw const Failure.rule(RuleCodes.nameInvalid);
    try {
      final existants = await _local.chargerBorrowers(borrower.entrepriseId);
      final isNew = !existants.any((b) => b.id == borrower.id);
      final now = DateTime.now();

      final saved = MicrofinanceBorrower(
        id: borrower.id,
        entrepriseId: borrower.entrepriseId,
        perimetreId: borrower.perimetreId,
        codeEmprunteur: borrower.codeEmprunteur.isNotEmpty
            ? borrower.codeEmprunteur
            : _genRef('EMP', existants.length),
        contactId: borrower.contactId,
        nomComplet: borrower.nomComplet.trim(),
        telephone: borrower.telephone.trim(),
        whatsapp: borrower.whatsapp?.trim(),
        adresse: borrower.adresse?.trim(),
        localisation: borrower.localisation?.trim(),
        profession: borrower.profession?.trim(),
        activite: borrower.activite?.trim(),
        typePiece: borrower.typePiece?.trim(),
        referencePiece: borrower.referencePiece?.trim(),
        photoUrl: borrower.photoUrl?.trim(),
        infosComplementaires: borrower.infosComplementaires?.trim(),
        dateInscription: borrower.dateInscription,
        observations: borrower.observations?.trim(),
        estActif: borrower.estActif,
        creePar: borrower.creePar ?? userId,
        version: isNew ? 1 : borrower.version + 1,
        createdAt: isNew ? now : borrower.createdAt,
        updatedAt: now,
      );

      await _local.transaction(() async {
        await _upsertLocal(
          saved.entrepriseId,
          _local.chargerBorrowers,
          _local.sauvegarderBorrowers,
          saved,
          (x) => x.id,
        );
        await _queue.enqueue(
          userId: userId,
          entityTable: 'microfinance_borrowers',
          recordId: saved.id,
          type: isNew ? SyncOperationType.insert : SyncOperationType.update,
          payload: MicrofinanceMappers.borrowerToJson(saved),
          baseVersion: isNew ? null : borrower.version,
        );
        await _enregistrerAudit(
          userId: userId,
          entrepriseId: saved.entrepriseId,
          perimetreId: saved.perimetreId,
          action: isNew ? 'CREATION_EMPRUNTEUR' : 'MODIFICATION_EMPRUNTEUR',
          entiteType: 'microfinance_borrowers',
          entiteId: saved.id,
          referenceEntite: saved.codeEmprunteur,
          detailsApres: MicrofinanceMappers.borrowerToJson(saved),
        );
      });

      await _emitAll(saved.entrepriseId);
      _requestSync();
      return saved;
    } catch (e, st) {
      if (e is Failure) rethrow;
      throw ErrorMapper.map(e, st);
    }
  }

  // --- PRÊTS ---

  Future<({MicrofinanceAccount account, bool created})> _resoudreOuCreerCompte({
    required String entrepriseId,
    required String? perimetreId,
    required String accountId,
    required String userId,
    required DateTime now,
  }) async {
    final accounts = await _local.chargerAccounts(entrepriseId);
    final found = accounts.where((a) => a.id == accountId && a.deletedAt == null).firstOrNull ??
        accounts.where((a) => a.deletedAt == null && a.estActif).firstOrNull;
    if (found != null) return (account: found, created: false);
    final fallback = MicrofinanceAccount(
      id: _uuid.v4(),
      entrepriseId: entrepriseId,
      perimetreId: perimetreId,
      nom: 'Caisse Principale',
      typeCompte: TypeCompteMicrofinance.caissePhysique,
      sourceFondsDefaut: SourceFondsMicrofinance.capitalPersonnel,
      soldeInitial: 0,
      soldeActuel: 0,
      devise: _currentContext()?.entreprise?.devise ?? 'XOF',
      creePar: userId,
      createdAt: now,
      updatedAt: now,
    );
    return (account: fallback, created: true);
  }

  @override
  Future<MicrofinanceLoan> creerEtDecaisserPret({
    required String entrepriseId,
    String? perimetreId,
    required String borrowerId,
    required String accountId,
    required int montantAccorde,
    required MethodeCalculInteret methodeInteret,
    double tauxInteret = 0,
    int montantInteretFixe = 0,
    required FrequenceRemboursement frequence,
    required int nombreEcheances,
    required ModePaiementMicrofinance modeDecaissement,
    required DateTime dateOctroi,
    required DateTime dateDebut,
    bool decaisserImmediatement = true,
    String? conditionsParticulieres,
    String? observations,
  }) async {
    final userId = _requireProUser();
    if (montantAccorde <= 0 || nombreEcheances <= 0) {
      throw const Failure.rule(RuleCodes.amountInvalid);
    }

    try {
      final borrowers = await _local.chargerBorrowers(entrepriseId);
      final emp = borrowers.where((b) => b.id == borrowerId && b.deletedAt == null).firstOrNull;
      if (emp == null) throw const Failure.rule(RuleCodes.customerRequired);

      final now = DateTime.now();
      final resolved = await _resoudreOuCreerCompte(
        entrepriseId: entrepriseId,
        perimetreId: perimetreId,
        accountId: accountId,
        userId: userId,
        now: now,
      );
      final acc = resolved.account;
      final autoCreatedAccount = resolved.created;

      final loanId = _uuid.v4();
      final loans = await _local.chargerLoans(entrepriseId);
      final reference = _genRef('PRT', loans.length);

      final sim = LoanInterestCalculator.simuler(
        entrepriseId: entrepriseId,
        loanId: loanId,
        borrowerId: borrowerId,
        perimetreId: perimetreId,
        montantAccorde: montantAccorde,
        methode: methodeInteret,
        tauxInteret: tauxInteret,
        montantInteretFixe: montantInteretFixe,
        frequence: frequence,
        nombreEcheances: nombreEcheances,
        dateDebut: dateDebut,
        now: now,
      );

      final loan = MicrofinanceLoan(
        id: loanId,
        entrepriseId: entrepriseId,
        perimetreId: perimetreId,
        reference: reference,
        borrowerId: borrowerId,
        accountId: acc.id,
        montantAccorde: sim.montantEmprunte,
        methodeInteret: methodeInteret,
        tauxInteret: tauxInteret,
        montantInteretFixe: montantInteretFixe,
        montantInteretTotal: sim.montantInteretTotal,
        montantTotalARembourser: sim.montantTotalARembourser,
        frequence: frequence,
        dureeValeur: sim.dureeValeur,
        nombreEcheances: sim.nombreEcheances,
        montantEcheanceIndicatif: sim.montantEcheanceStandard,
        modeDecaissement: modeDecaissement,
        dateOctroi: dateOctroi,
        dateDecaissement: decaisserImmediatement ? now : null,
        dateDebut: sim.dateDebut,
        dateFinPrevue: sim.dateFinPrevue,
        statut: decaisserImmediatement
            ? DelinquencyAnalyzer.statutPretActuel(
                MicrofinanceLoan(
                  id: loanId,
                  entrepriseId: entrepriseId,
                  reference: reference,
                  borrowerId: borrowerId,
                  accountId: acc.id,
                  montantAccorde: sim.montantEmprunte,
                  methodeInteret: methodeInteret,
                  montantInteretTotal: sim.montantInteretTotal,
                  montantTotalARembourser: sim.montantTotalARembourser,
                  frequence: frequence,
                  dureeValeur: sim.dureeValeur,
                  nombreEcheances: sim.nombreEcheances,
                  montantEcheanceIndicatif: sim.montantEcheanceStandard,
                  dateOctroi: dateOctroi,
                  dateDebut: sim.dateDebut,
                  dateFinPrevue: sim.dateFinPrevue,
                  createdAt: now,
                  updatedAt: now,
                ),
                sim.echeances,
                now,
              )
            : StatutPret.brouillon,
        conditionsParticulieres: conditionsParticulieres?.trim(),
        observations: observations?.trim(),
        creePar: userId,
        createdAt: now,
        updatedAt: now,
      );

      await _local.transaction(() async {
        if (autoCreatedAccount && !decaisserImmediatement) {
          await _upsertLocal(
            entrepriseId,
            _local.chargerAccounts,
            _local.sauvegarderAccounts,
            acc,
            (x) => x.id,
          );
          await _queue.enqueue(
            userId: userId,
            entityTable: 'microfinance_accounts',
            recordId: acc.id,
            type: SyncOperationType.insert,
            payload: MicrofinanceMappers.accountToJson(acc),
          );
        }

        await _upsertLocal(entrepriseId, _local.chargerLoans, _local.sauvegarderLoans, loan, (x) => x.id);
        await _queue.enqueue(
          userId: userId,
          entityTable: 'microfinance_loans',
          recordId: loan.id,
          type: SyncOperationType.insert,
          payload: MicrofinanceMappers.loanToJson(loan),
        );

        final allInst = List<MicrofinanceInstallment>.from(await _local.chargerInstallments(entrepriseId));
        allInst.addAll(sim.echeances);
        await _local.sauvegarderInstallments(entrepriseId, allInst);
        for (final ech in sim.echeances) {
          await _queue.enqueue(
            userId: userId,
            entityTable: 'microfinance_installments',
            recordId: ech.id,
            type: SyncOperationType.insert,
            payload: MicrofinanceMappers.installmentToJson(ech),
          );
        }

        if (decaisserImmediatement) {
          final nouveauSolde =
              acc.soldeActuel >= montantAccorde ? acc.soldeActuel - montantAccorde : 0;
          final updatedAcc = acc.copyWith(
            soldeActuel: nouveauSolde,
            updatedAt: now,
          );
          await _upsertLocal(
            entrepriseId,
            _local.chargerAccounts,
            _local.sauvegarderAccounts,
            updatedAcc,
            (x) => x.id,
          );
          await _queue.enqueue(
            userId: userId,
            entityTable: 'microfinance_accounts',
            recordId: updatedAcc.id,
            type: autoCreatedAccount ? SyncOperationType.insert : SyncOperationType.update,
            payload: MicrofinanceMappers.accountToJson(updatedAcc),
            baseVersion: autoCreatedAccount ? null : acc.version,
          );

          final txs = await _local.chargerTransactions(entrepriseId);
          await _enregistrerTransaction(
            userId: userId,
            tx: MicrofinanceTransaction(
              id: _uuid.v4(),
              entrepriseId: entrepriseId,
              perimetreId: perimetreId,
              reference: _genRef('TXM-DEC', txs.length),
              dateTransaction: now,
              typeTransaction: TypeTransactionMicrofinance.decaissementPret,
              montant: montantAccorde,
              partCapital: montantAccorde,
              sens: SensTransactionMicrofinance.sortie,
              modePaiement: modeDecaissement,
              accountId: acc.id,
              loanId: loan.id,
              borrowerId: borrowerId,
              libelle: 'Décaissement prêt ${loan.reference} — ${emp.nomComplet}',
              observations: loan.observations,
              creePar: userId,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }

        await _enregistrerAudit(
          userId: userId,
          entrepriseId: entrepriseId,
          perimetreId: perimetreId,
          action: decaisserImmediatement ? 'CREATION_ET_DECAISSEMENT_PRET' : 'CREATION_BROUILLON_PRET',
          entiteType: 'microfinance_loans',
          entiteId: loan.id,
          referenceEntite: loan.reference,
          detailsApres: MicrofinanceMappers.loanToJson(loan),
        );
      });

      await _emitAll(entrepriseId);
      _requestSync();
      return loan;
    } catch (e, st) {
      if (e is Failure) rethrow;
      throw ErrorMapper.map(e, st);
    }
  }

  @override
  Future<MicrofinanceLoan> decaisserBrouillon({
    required String entrepriseId,
    required String loanId,
    required String accountId,
    required ModePaiementMicrofinance modeDecaissement,
    DateTime? dateDecaissement,
  }) async {
    final userId = _requireProUser();
    try {
      final loans = await _local.chargerLoans(entrepriseId);
      final loan = loans.where((l) => l.id == loanId).firstOrNull;
      if (loan == null || loan.statut != StatutPret.brouillon) {
        throw const Failure.rule(RuleCodes.mfLoanImmutable);
      }

      final borrowers = await _local.chargerBorrowers(entrepriseId);
      final emp = borrowers.where((b) => b.id == loan.borrowerId).firstOrNull;
      final echs = (await _local.chargerInstallments(entrepriseId))
          .where((e) => e.loanId == loan.id)
          .toList();
      final now = dateDecaissement ?? DateTime.now();

      final resolvedAcc = await _resoudreOuCreerCompte(
        entrepriseId: entrepriseId,
        perimetreId: loan.perimetreId,
        accountId: accountId,
        userId: userId,
        now: now,
      );
      final acc = resolvedAcc.account;
      final autoCreatedAccount = resolvedAcc.created;

      final updatedLoan = loan.copyWith(
        accountId: acc.id,
        modeDecaissement: modeDecaissement,
        dateDecaissement: now,
        statut: DelinquencyAnalyzer.statutPretActuel(
          loan.copyWith(statut: StatutPret.enCours),
          echs,
          now,
        ),
        updatedAt: now,
      );
      final updatedAcc = acc.copyWith(
        soldeActuel: acc.soldeActuel >= loan.montantAccorde ? acc.soldeActuel - loan.montantAccorde : 0,
        updatedAt: now,
      );

      await _local.transaction(() async {
        await _upsertLocal(entrepriseId, _local.chargerLoans, _local.sauvegarderLoans, updatedLoan, (x) => x.id);
        await _queue.enqueue(
          userId: userId,
          entityTable: 'microfinance_loans',
          recordId: updatedLoan.id,
          type: SyncOperationType.update,
          payload: MicrofinanceMappers.loanToJson(updatedLoan),
          baseVersion: loan.version,
        );

        await _upsertLocal(entrepriseId, _local.chargerAccounts, _local.sauvegarderAccounts, updatedAcc, (x) => x.id);
        await _queue.enqueue(
          userId: userId,
          entityTable: 'microfinance_accounts',
          recordId: updatedAcc.id,
          type: autoCreatedAccount ? SyncOperationType.insert : SyncOperationType.update,
          payload: MicrofinanceMappers.accountToJson(updatedAcc),
          baseVersion: autoCreatedAccount ? null : acc.version,
        );

        final txs = await _local.chargerTransactions(entrepriseId);
        await _enregistrerTransaction(
          userId: userId,
          tx: MicrofinanceTransaction(
            id: _uuid.v4(),
            entrepriseId: entrepriseId,
            perimetreId: loan.perimetreId,
            reference: _genRef('TXM-DEC', txs.length),
            dateTransaction: now,
            typeTransaction: TypeTransactionMicrofinance.decaissementPret,
            montant: loan.montantAccorde,
            partCapital: loan.montantAccorde,
            sens: SensTransactionMicrofinance.sortie,
            modePaiement: modeDecaissement,
            accountId: acc.id,
            loanId: loan.id,
            borrowerId: loan.borrowerId,
            libelle: 'Décaissement prêt ${loan.reference} — ${emp?.nomComplet ?? ""}',
            creePar: userId,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await _enregistrerAudit(
          userId: userId,
          entrepriseId: entrepriseId,
          perimetreId: loan.perimetreId,
          action: 'DECAISSEMENT_PRET',
          entiteType: 'microfinance_loans',
          entiteId: loan.id,
          referenceEntite: loan.reference,
          detailsAvant: MicrofinanceMappers.loanToJson(loan),
          detailsApres: MicrofinanceMappers.loanToJson(updatedLoan),
        );
      });

      await _emitAll(entrepriseId);
      _requestSync();
      return updatedLoan;
    } catch (e, st) {
      if (e is Failure) rethrow;
      throw ErrorMapper.map(e, st);
    }
  }

  @override
  Future<MicrofinanceLoan> annulerPret({
    required String entrepriseId,
    required String loanId,
    required String motif,
  }) async {
    final userId = _requireProUser();
    if (motif.trim().isEmpty) throw const Failure.rule(RuleCodes.reasonRequired);
    try {
      final loans = await _local.chargerLoans(entrepriseId);
      final loan = loans.where((l) => l.id == loanId).firstOrNull;
      if (loan == null) throw const Failure.rule(RuleCodes.targetInvalid);
      if (loan.totalRembourse > 0) {
        throw const Failure.rule(RuleCodes.mfLoanImmutable);
      }

      final now = DateTime.now();
      final wasDisbursed = loan.statut != StatutPret.brouillon && loan.dateDecaissement != null;
      final updatedLoan = loan.copyWith(
        statut: StatutPret.annule,
        motifAnnulation: motif.trim(),
        updatedAt: now,
      );

      final allEchs = List<MicrofinanceInstallment>.from(await _local.chargerInstallments(entrepriseId));
      final updatedEchs = <MicrofinanceInstallment>[];
      for (var i = 0; i < allEchs.length; i++) {
        if (allEchs[i].loanId == loanId) {
          final upd = allEchs[i].copyWith(statut: StatutEcheance.annule, updatedAt: now);
          allEchs[i] = upd;
          updatedEchs.add(upd);
        }
      }

      await _local.transaction(() async {
        await _upsertLocal(entrepriseId, _local.chargerLoans, _local.sauvegarderLoans, updatedLoan, (x) => x.id);
        await _queue.enqueue(
          userId: userId,
          entityTable: 'microfinance_loans',
          recordId: updatedLoan.id,
          type: SyncOperationType.update,
          payload: MicrofinanceMappers.loanToJson(updatedLoan),
          baseVersion: loan.version,
        );

        await _local.sauvegarderInstallments(entrepriseId, allEchs);
        for (final e in updatedEchs) {
          await _queue.enqueue(
            userId: userId,
            entityTable: 'microfinance_installments',
            recordId: e.id,
            type: SyncOperationType.update,
            payload: MicrofinanceMappers.installmentToJson(e),
            baseVersion: e.version,
          );
        }

        if (wasDisbursed) {
          final accounts = await _local.chargerAccounts(entrepriseId);
          final acc = accounts.where((a) => a.id == loan.accountId).firstOrNull;
          if (acc != null) {
            final updAcc = acc.copyWith(soldeActuel: acc.soldeActuel + loan.montantAccorde, updatedAt: now);
            await _upsertLocal(entrepriseId, _local.chargerAccounts, _local.sauvegarderAccounts, updAcc, (x) => x.id);
            await _queue.enqueue(
              userId: userId,
              entityTable: 'microfinance_accounts',
              recordId: updAcc.id,
              type: SyncOperationType.update,
              payload: MicrofinanceMappers.accountToJson(updAcc),
              baseVersion: acc.version,
            );

            final txs = await _local.chargerTransactions(entrepriseId);
            await _enregistrerTransaction(
              userId: userId,
              tx: MicrofinanceTransaction(
                id: _uuid.v4(),
                entrepriseId: entrepriseId,
                perimetreId: loan.perimetreId,
                reference: _genRef('TXM-ANN', txs.length),
                dateTransaction: now,
                typeTransaction: TypeTransactionMicrofinance.annulationCorrection,
                montant: loan.montantAccorde,
                partCapital: loan.montantAccorde,
                sens: SensTransactionMicrofinance.entree,
                modePaiement: loan.modeDecaissement,
                accountId: acc.id,
                loanId: loan.id,
                borrowerId: loan.borrowerId,
                libelle: 'Annulation prêt ${loan.reference}',
                observations: motif.trim(),
                creePar: userId,
                createdAt: now,
                updatedAt: now,
              ),
            );
          }
        }

        await _enregistrerAudit(
          userId: userId,
          entrepriseId: entrepriseId,
          perimetreId: loan.perimetreId,
          action: 'ANNULATION_PRET',
          entiteType: 'microfinance_loans',
          entiteId: loan.id,
          referenceEntite: loan.reference,
          detailsAvant: MicrofinanceMappers.loanToJson(loan),
          detailsApres: MicrofinanceMappers.loanToJson(updatedLoan),
          motif: motif.trim(),
        );
      });

      await _emitAll(entrepriseId);
      _requestSync();
      return updatedLoan;
    } catch (e, st) {
      if (e is Failure) rethrow;
      throw ErrorMapper.map(e, st);
    }
  }

  @override
  Future<MicrofinanceLoan> passerEnContentieux({
    required String entrepriseId,
    required String loanId,
    required String motif,
  }) async {
    final userId = _requireProUser();
    try {
      final loans = await _local.chargerLoans(entrepriseId);
      final loan = loans.where((l) => l.id == loanId).firstOrNull;
      if (loan == null) throw const Failure.rule(RuleCodes.targetInvalid);

      final now = DateTime.now();
      final updated = loan.copyWith(
        statut: StatutPret.contentieux,
        observations: [if (loan.observations?.isNotEmpty ?? false) loan.observations, 'Contentieux : ${motif.trim()}'].join('\n'),
        updatedAt: now,
      );

      await _local.transaction(() async {
        await _upsertLocal(entrepriseId, _local.chargerLoans, _local.sauvegarderLoans, updated, (x) => x.id);
        await _queue.enqueue(
          userId: userId,
          entityTable: 'microfinance_loans',
          recordId: updated.id,
          type: SyncOperationType.update,
          payload: MicrofinanceMappers.loanToJson(updated),
          baseVersion: loan.version,
        );
        await _enregistrerAudit(
          userId: userId,
          entrepriseId: entrepriseId,
          perimetreId: loan.perimetreId,
          action: 'PASSAGE_CONTENTIEUX',
          entiteType: 'microfinance_loans',
          entiteId: loan.id,
          referenceEntite: loan.reference,
          motif: motif.trim(),
        );
      });

      await _emitAll(entrepriseId);
      _requestSync();
      return updated;
    } catch (e, st) {
      if (e is Failure) rethrow;
      throw ErrorMapper.map(e, st);
    }
  }

  // --- REMBOURSEMENTS ---

  @override
  Future<MicrofinanceRepayment> enregistrerRemboursement({
    required String entrepriseId,
    required String loanId,
    required String accountId,
    required int montantEncaisse,
    TypeRemboursement? typeRemboursement,
    String? installmentCibleId,
    required ModePaiementMicrofinance modePaiement,
    required DateTime datePaiement,
    String? justificatifUrl,
    String? observations,
  }) async {
    final userId = _requireProUser();
    try {
      final loans = await _local.chargerLoans(entrepriseId);
      final loan = loans.where((l) => l.id == loanId).firstOrNull;
      if (loan == null) throw const Failure.rule(RuleCodes.targetInvalid);

      final allInstallments = List<MicrofinanceInstallment>.from(
        await _local.chargerInstallments(entrepriseId),
      );
      final loanInstallments = allInstallments.where((e) => e.loanId == loanId).toList();
      final now = DateTime.now();

      final resolvedAcc = await _resoudreOuCreerCompte(
        entrepriseId: entrepriseId,
        perimetreId: loan.perimetreId,
        accountId: accountId.isNotEmpty ? accountId : loan.accountId,
        userId: userId,
        now: now,
      );
      final acc = resolvedAcc.account;
      final autoCreatedAccount = resolvedAcc.created;

      final result = RepaymentAllocator.allouer(
        loan: loan,
        installments: loanInstallments,
        montantEncaisse: montantEncaisse,
        typeSouhaite: typeRemboursement,
        installmentCibleId: installmentCibleId,
        datePaiement: datePaiement,
        now: now,
      );

      final borrowers = await _local.chargerBorrowers(entrepriseId);
      final emp = borrowers.where((b) => b.id == loan.borrowerId).firstOrNull;
      final repayments = await _local.chargerRepayments(entrepriseId);

      final repayment = MicrofinanceRepayment(
        id: _uuid.v4(),
        entrepriseId: entrepriseId,
        perimetreId: loan.perimetreId,
        reference: _genRef('RMB', repayments.length),
        loanId: loanId,
        borrowerId: loan.borrowerId,
        accountId: acc.id,
        datePaiement: datePaiement,
        montantEncaisse: montantEncaisse,
        partCapital: result.partCapital,
        partInteret: result.partInteret,
        typeRemboursement: result.typeDeduit,
        modePaiement: modePaiement,
        justificatifUrl: justificatifUrl?.trim(),
        observations: observations?.trim(),
        detailsAffectation: result.allocations,
        creePar: userId,
        createdAt: now,
        updatedAt: now,
      );

      final updatedAcc = acc.copyWith(
        soldeActuel: acc.soldeActuel + montantEncaisse,
        updatedAt: now,
      );

      await _local.transaction(() async {
        // 1. Sauvegarder le remboursement
        await _upsertLocal(
          entrepriseId,
          _local.chargerRepayments,
          _local.sauvegarderRepayments,
          repayment,
          (x) => x.id,
        );
        await _queue.enqueue(
          userId: userId,
          entityTable: 'microfinance_repayments',
          recordId: repayment.id,
          type: SyncOperationType.insert,
          payload: MicrofinanceMappers.repaymentToJson(repayment),
        );

        // 2. Mettre à jour les échéances affectées
        final updatedInstById = {for (final e in result.installmentsMisAJour) e.id: e};
        final oldInstById = {for (final e in loanInstallments) e.id: e};
        for (var i = 0; i < allInstallments.length; i++) {
          final upd = updatedInstById[allInstallments[i].id];
          if (upd != null) {
            allInstallments[i] = upd;
          }
        }
        await _local.sauvegarderInstallments(entrepriseId, allInstallments);
        for (final alloc in result.allocations) {
          final upd = updatedInstById[alloc.installmentId];
          final old = oldInstById[alloc.installmentId];
          if (upd != null) {
            await _queue.enqueue(
              userId: userId,
              entityTable: 'microfinance_installments',
              recordId: upd.id,
              type: SyncOperationType.update,
              payload: MicrofinanceMappers.installmentToJson(upd),
              baseVersion: old?.version,
            );
          }
        }

        // 3. Mettre à jour le prêt
        await _upsertLocal(
          entrepriseId,
          _local.chargerLoans,
          _local.sauvegarderLoans,
          result.loanMisAJour,
          (x) => x.id,
        );
        await _queue.enqueue(
          userId: userId,
          entityTable: 'microfinance_loans',
          recordId: result.loanMisAJour.id,
          type: SyncOperationType.update,
          payload: MicrofinanceMappers.loanToJson(result.loanMisAJour),
          baseVersion: loan.version,
        );

        // 4. Mettre à jour le compte de trésorerie
        await _upsertLocal(
          entrepriseId,
          _local.chargerAccounts,
          _local.sauvegarderAccounts,
          updatedAcc,
          (x) => x.id,
        );
        await _queue.enqueue(
          userId: userId,
          entityTable: 'microfinance_accounts',
          recordId: updatedAcc.id,
          type: autoCreatedAccount ? SyncOperationType.insert : SyncOperationType.update,
          payload: MicrofinanceMappers.accountToJson(updatedAcc),
          baseVersion: autoCreatedAccount ? null : acc.version,
        );

        // 5. Écritures comptables séparées Capital vs Intérêt au Grand-Livre central
        final txs = await _local.chargerTransactions(entrepriseId);
        var txIdx = txs.length;
        if (repayment.partCapital > 0) {
          await _enregistrerTransaction(
            userId: userId,
            tx: MicrofinanceTransaction(
              id: _uuid.v4(),
              entrepriseId: entrepriseId,
              perimetreId: loan.perimetreId,
              reference: _genRef('TXM-CAP', txIdx++),
              dateTransaction: datePaiement,
              typeTransaction: repayment.typeRemboursement == TypeRemboursement.exceptionnel
                  ? TypeTransactionMicrofinance.remboursementExceptionnel
                  : TypeTransactionMicrofinance.remboursementCapital,
              montant: repayment.partCapital,
              partCapital: repayment.partCapital,
              sens: SensTransactionMicrofinance.entree,
              modePaiement: modePaiement,
              accountId: acc.id,
              loanId: loan.id,
              repaymentId: repayment.id,
              borrowerId: loan.borrowerId,
              libelle: 'Remb. capital ${loan.reference} (${repayment.reference}) — ${emp?.nomComplet ?? ""}',
              observations: repayment.observations,
              creePar: userId,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }

        if (repayment.partInteret > 0) {
          await _enregistrerTransaction(
            userId: userId,
            tx: MicrofinanceTransaction(
              id: _uuid.v4(),
              entrepriseId: entrepriseId,
              perimetreId: loan.perimetreId,
              reference: _genRef('TXM-INT', txIdx++),
              dateTransaction: datePaiement,
              typeTransaction: TypeTransactionMicrofinance.encaissementInteret,
              montant: repayment.partInteret,
              partInteret: repayment.partInteret,
              sens: SensTransactionMicrofinance.entree,
              modePaiement: modePaiement,
              accountId: acc.id,
              loanId: loan.id,
              repaymentId: repayment.id,
              borrowerId: loan.borrowerId,
              libelle: 'Intérêts encaissés ${loan.reference} (${repayment.reference}) — ${emp?.nomComplet ?? ""}',
              observations: repayment.observations,
              creePar: userId,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }

        await _enregistrerAudit(
          userId: userId,
          entrepriseId: entrepriseId,
          perimetreId: loan.perimetreId,
          action: 'ENCAISSEMENT_REMBOURSEMENT',
          entiteType: 'microfinance_repayments',
          entiteId: repayment.id,
          referenceEntite: repayment.reference,
          detailsApres: MicrofinanceMappers.repaymentToJson(repayment),
        );
      });

      await _emitAll(entrepriseId);
      _requestSync();
      return repayment;
    } catch (e, st) {
      if (e is Failure) rethrow;
      throw ErrorMapper.map(e, st);
    }
  }

  @override
  Future<void> annulerRemboursement({
    required String entrepriseId,
    required String repaymentId,
    required String motif,
  }) async {
    final userId = _requireProUser();
    if (motif.trim().isEmpty) throw const Failure.rule(RuleCodes.reasonRequired);
    try {
      final repayments = await _local.chargerRepayments(entrepriseId);
      final remb = repayments.where((r) => r.id == repaymentId).firstOrNull;
      if (remb == null) throw const Failure.rule(RuleCodes.targetInvalid);
      if (remb.estAnnule) throw const Failure.rule(RuleCodes.paymentAlreadyCancelled);

      final loans = await _local.chargerLoans(entrepriseId);
      final loan = loans.where((l) => l.id == remb.loanId).firstOrNull;
      if (loan == null) throw const Failure.rule(RuleCodes.targetInvalid);

      final accounts = await _local.chargerAccounts(entrepriseId);
      final acc = accounts.where((a) => a.id == remb.accountId).firstOrNull;
      if (acc == null) throw const Failure.rule(RuleCodes.targetInvalid);
      if (acc.soldeActuel < remb.montantEncaisse) {
        throw Failure.rule(RuleCodes.cashInsufficient, {'solde': acc.soldeActuel});
      }

      final now = DateTime.now();
      final allInst = List<MicrofinanceInstallment>.from(await _local.chargerInstallments(entrepriseId));
      final instMap = {for (final e in allInst) e.id: e};
      final oldVersionMap = <String, int>{};

      for (final alloc in remb.detailsAffectation) {
        final cur = instMap[alloc.installmentId];
        if (cur == null) continue;
        oldVersionMap[cur.id] = cur.version;
        final capPaye = (cur.capitalPaye - alloc.partCapital).clamp(0, cur.capitalPrevu);
        final intPaye = (cur.interetPaye - alloc.partInteret).clamp(0, cur.interetPrevu);
        final totalPaye = capPaye + intPaye;
        final reste = (cur.montantTotalAttendu - totalPaye).clamp(0, cur.montantTotalAttendu);
        final upd = cur.copyWith(
          capitalPaye: capPaye,
          interetPaye: intPaye,
          montantDejaPaye: totalPaye,
          resteAPayer: reste,
          updatedAt: now,
        );
        instMap[cur.id] = upd.copyWith(
          statut: DelinquencyAnalyzer.statutEcheanceActuel(upd, now),
        );
      }

      final updatedLoanInst = instMap.values.where((e) => e.loanId == loan.id).toList();
      final nouvCap = (loan.capitalRembourse - remb.partCapital).clamp(0, loan.montantAccorde);
      final nouvInt = (loan.interetRembourse - remb.partInteret).clamp(0, loan.montantInteretTotal);
      final preLoan = loan.copyWith(
        capitalRembourse: nouvCap,
        interetRembourse: nouvInt,
        statut: StatutPret.enCours,
      );
      final updatedLoan = preLoan.copyWith(
        statut: DelinquencyAnalyzer.statutPretActuel(preLoan, updatedLoanInst, now),
        updatedAt: now,
      );

      final updatedRemb = remb.copyWith(
        estAnnule: true,
        motifAnnulation: motif.trim(),
        updatedAt: now,
      );
      final updatedAcc = acc.copyWith(
        soldeActuel: acc.soldeActuel - remb.montantEncaisse,
        updatedAt: now,
      );

      await _local.transaction(() async {
        await _upsertLocal(entrepriseId, _local.chargerRepayments, _local.sauvegarderRepayments, updatedRemb, (x) => x.id);
        await _queue.enqueue(
          userId: userId,
          entityTable: 'microfinance_repayments',
          recordId: updatedRemb.id,
          type: SyncOperationType.update,
          payload: MicrofinanceMappers.repaymentToJson(updatedRemb),
          baseVersion: remb.version,
          fusionner: false,
        );

        await _local.sauvegarderInstallments(entrepriseId, instMap.values.toList());
        for (final alloc in remb.detailsAffectation) {
          final upd = instMap[alloc.installmentId];
          if (upd != null) {
            await _queue.enqueue(
              userId: userId,
              entityTable: 'microfinance_installments',
              recordId: upd.id,
              type: SyncOperationType.update,
              payload: MicrofinanceMappers.installmentToJson(upd),
              baseVersion: oldVersionMap[upd.id],
            );
          }
        }

        await _upsertLocal(entrepriseId, _local.chargerLoans, _local.sauvegarderLoans, updatedLoan, (x) => x.id);
        await _queue.enqueue(
          userId: userId,
          entityTable: 'microfinance_loans',
          recordId: updatedLoan.id,
          type: SyncOperationType.update,
          payload: MicrofinanceMappers.loanToJson(updatedLoan),
          baseVersion: loan.version,
        );

        await _upsertLocal(entrepriseId, _local.chargerAccounts, _local.sauvegarderAccounts, updatedAcc, (x) => x.id);
        await _queue.enqueue(
          userId: userId,
          entityTable: 'microfinance_accounts',
          recordId: updatedAcc.id,
          type: SyncOperationType.update,
          payload: MicrofinanceMappers.accountToJson(updatedAcc),
          baseVersion: acc.version,
        );

        final txs = await _local.chargerTransactions(entrepriseId);
        await _enregistrerTransaction(
          userId: userId,
          tx: MicrofinanceTransaction(
            id: _uuid.v4(),
            entrepriseId: entrepriseId,
            perimetreId: loan.perimetreId,
            reference: _genRef('TXM-COR', txs.length),
            dateTransaction: now,
            typeTransaction: TypeTransactionMicrofinance.annulationCorrection,
            montant: remb.montantEncaisse,
            partCapital: remb.partCapital,
            partInteret: remb.partInteret,
            sens: SensTransactionMicrofinance.sortie,
            modePaiement: remb.modePaiement,
            accountId: acc.id,
            loanId: loan.id,
            repaymentId: remb.id,
            borrowerId: loan.borrowerId,
            libelle: 'Annulation remboursement ${remb.reference} (${loan.reference})',
            observations: motif.trim(),
            creePar: userId,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await _enregistrerAudit(
          userId: userId,
          entrepriseId: entrepriseId,
          perimetreId: loan.perimetreId,
          action: 'ANNULATION_REMBOURSEMENT',
          entiteType: 'microfinance_repayments',
          entiteId: remb.id,
          referenceEntite: remb.reference,
          detailsAvant: MicrofinanceMappers.repaymentToJson(remb),
          detailsApres: MicrofinanceMappers.repaymentToJson(updatedRemb),
          motif: motif.trim(),
        );
      });

      await _emitAll(entrepriseId);
      _requestSync();
    } catch (e, st) {
      if (e is Failure) rethrow;
      throw ErrorMapper.map(e, st);
    }
  }
}
