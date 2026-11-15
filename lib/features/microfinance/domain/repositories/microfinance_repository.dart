import '../entities/microfinance_enums.dart';
import '../entities/microfinance_models.dart';

/// Contrat du référentiel Microfinance (Offline-First + Synchronisation + Audit).
abstract interface class MicrofinanceRepository {
  Stream<List<MicrofinanceAccount>> watchAccounts(String entrepriseId);
  Stream<List<MicrofinanceFundMovement>> watchFundMovements(String entrepriseId);
  Stream<List<MicrofinanceBorrower>> watchBorrowers(String entrepriseId);
  Stream<List<MicrofinanceLoan>> watchLoans(String entrepriseId);
  Stream<List<MicrofinanceInstallment>> watchInstallments(String entrepriseId);
  Stream<List<MicrofinanceRepayment>> watchRepayments(String entrepriseId);
  Stream<List<MicrofinanceTransaction>> watchTransactions(String entrepriseId);
  Stream<List<MicrofinanceAuditLog>> watchAuditLogs(String entrepriseId);

  Future<void> refresh(String entrepriseId);

  // --- Comptes & Capital ---
  Future<MicrofinanceAccount> sauvegarderCompte(MicrofinanceAccount account, {bool enregistrerApportInitial = true});

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
  });

  // --- Emprunteurs ---
  Future<MicrofinanceBorrower> sauvegarderEmprunteur(MicrofinanceBorrower borrower);

  // --- Prêts ---
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
  });

  Future<MicrofinanceLoan> decaisserBrouillon({
    required String entrepriseId,
    required String loanId,
    required String accountId,
    required ModePaiementMicrofinance modeDecaissement,
    DateTime? dateDecaissement,
  });

  Future<MicrofinanceLoan> annulerPret({
    required String entrepriseId,
    required String loanId,
    required String motif,
  });

  Future<MicrofinanceLoan> passerEnContentieux({
    required String entrepriseId,
    required String loanId,
    required String motif,
  });

  // --- Remboursements & Contre-passations ---
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
  });

  Future<void> annulerRemboursement({
    required String entrepriseId,
    required String repaymentId,
    required String motif,
  });
}

