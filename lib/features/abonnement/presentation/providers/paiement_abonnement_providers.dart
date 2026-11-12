import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/core_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../data/datasources/paiement_abonnement_remote_data_source.dart';
import '../../domain/entities/paiement_abonnement.dart';

final paiementRemoteDataSourceProvider = Provider<PaiementAbonnementRemoteDataSource>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return PaiementAbonnementRemoteDataSource(client: client);
});

/// État de la page de règlement et réabonnement DubaGest.
class PaiementAbonnementState {
  const PaiementAbonnementState({
    this.planCodeSelectionne = 'NORMAL',
    this.dureeMois = 1,
    this.prestataireSelectionne = PrestatairePaiement.ligdiCash,
    this.telephone = '',
    this.estModeDemo = false,
    this.chargement = false,
    this.erreur,
    this.transactionEnCours,
    this.disponibilites = const {},
    this.historiqueTransactions = const [],
    this.historiqueRenouvellements = const [],
    this.chargementHistorique = false,
    this.detailsReglement,
    this.chargementDetails = false,
  });

  final String planCodeSelectionne;
  final int dureeMois;
  final PrestatairePaiement prestataireSelectionne;
  final String telephone;
  final bool estModeDemo;
  final bool chargement;
  final String? erreur;
  final TransactionAbonnement? transactionEnCours;
  final Map<PrestatairePaiement, DisponibilitePrestataire> disponibilites;
  final List<TransactionAbonnement> historiqueTransactions;
  final List<HistoriqueRenouvellementItem> historiqueRenouvellements;
  final bool chargementHistorique;
  final Map<String, dynamic>? detailsReglement;
  final bool chargementDetails;

  String get planCodeCible => planCodeSelectionne;
  PrestatairePaiement get prestataire => prestataireSelectionne;
  bool get estEnChargement => chargement;
  TransactionAbonnement? get transactionCourante => transactionEnCours;

  PaiementAbonnementState copyWith({
    String? planCodeSelectionne,
    int? dureeMois,
    PrestatairePaiement? prestataireSelectionne,
    String? telephone,
    bool? estModeDemo,
    bool? chargement,
    String? Function()? erreur,
    TransactionAbonnement? Function()? transactionEnCours,
    Map<PrestatairePaiement, DisponibilitePrestataire>? disponibilites,
    List<TransactionAbonnement>? historiqueTransactions,
    List<HistoriqueRenouvellementItem>? historiqueRenouvellements,
    bool? chargementHistorique,
    Map<String, dynamic>? Function()? detailsReglement,
    bool? chargementDetails,
  }) {
    return PaiementAbonnementState(
      planCodeSelectionne: planCodeSelectionne ?? this.planCodeSelectionne,
      dureeMois: dureeMois ?? this.dureeMois,
      prestataireSelectionne: prestataireSelectionne ?? this.prestataireSelectionne,
      telephone: telephone ?? this.telephone,
      estModeDemo: estModeDemo ?? this.estModeDemo,
      chargement: chargement ?? this.chargement,
      erreur: erreur != null ? erreur() : this.erreur,
      transactionEnCours: transactionEnCours != null ? transactionEnCours() : this.transactionEnCours,
      disponibilites: disponibilites ?? this.disponibilites,
      historiqueTransactions: historiqueTransactions ?? this.historiqueTransactions,
      historiqueRenouvellements: historiqueRenouvellements ?? this.historiqueRenouvellements,
      chargementHistorique: chargementHistorique ?? this.chargementHistorique,
      detailsReglement: detailsReglement != null ? detailsReglement() : this.detailsReglement,
      chargementDetails: chargementDetails ?? this.chargementDetails,
    );
  }
}

class PaiementAbonnementNotifier extends Notifier<PaiementAbonnementState> {
  @override
  PaiementAbonnementState build() {
    final ctx = ref.watch(contexteActifProvider);
    final planActuel = ctx?.abonnement?.planCode;
    final initialPlan = (planActuel != null && planActuel.isNotEmpty) ? planActuel : 'NORMAL';

    Future.microtask(() => init(initialPlanCode: initialPlan));
    return PaiementAbonnementState(planCodeSelectionne: initialPlan);
  }

  PaiementAbonnementRemoteDataSource get _dataSource => ref.read(paiementRemoteDataSourceProvider);
  String get _entrepriseId {
    final ctx = ref.read(contexteActifProvider);
    return ctx?.entreprise?.id ?? '';
  }

  Future<void> init({String? initialPlanCode}) async {
    final ctx = ref.read(contexteActifProvider);
    final planActuel = ctx?.abonnement?.planCode;
    final planCible = (initialPlanCode != null && initialPlanCode.isNotEmpty)
        ? initialPlanCode
        : ((planActuel != null && planActuel.isNotEmpty) ? planActuel : state.planCodeSelectionne);

    state = state.copyWith(planCodeSelectionne: planCible);
    await verifierDisponibilites();
    await chargerDetailsReglement(state.planCodeSelectionne);
    await chargerHistorique();
  }

  void changerPlan(String planCode) {
    if (state.planCodeSelectionne == planCode) return;
    state = state.copyWith(planCodeSelectionne: planCode, erreur: () => null);
    chargerDetailsReglement(planCode);
  }

  void changerDuree(int mois) {
    state = state.copyWith(dureeMois: mois, erreur: () => null);
  }

  void changerPrestataire(PrestatairePaiement prestataire) {
    if (prestataire == PrestatairePaiement.orangeMoney) {
      // Sécurité client : Orange Money est temporairement désactivé
      return;
    }
    state = state.copyWith(prestataireSelectionne: prestataire, erreur: () => null);
  }

  void changerTelephone(String tel) {
    state = state.copyWith(telephone: tel, erreur: () => null);
  }

  void toggleModeDemo(bool activer) {
    state = state.copyWith(estModeDemo: activer, erreur: () => null);
  }

  Future<void> verifierDisponibilites() async {
    final orange = await _dataSource.verifierDisponibilite(PrestatairePaiement.orangeMoney);
    final ligdi = await _dataSource.verifierDisponibilite(PrestatairePaiement.ligdiCash);
    state = state.copyWith(
      disponibilites: {
        PrestatairePaiement.orangeMoney: orange,
        PrestatairePaiement.ligdiCash: ligdi,
      },
    );
  }

  Future<void> chargerDetailsReglement([String? planCode]) async {
    if (_entrepriseId.isEmpty) return;
    state = state.copyWith(chargementDetails: true);
    try {
      final details = await _dataSource.preparerReglementAbonnement(
        entrepriseId: _entrepriseId,
        planCible: planCode ?? state.planCodeSelectionne,
      );
      state = state.copyWith(
        chargementDetails: false,
        detailsReglement: () => details,
      );
    } catch (e) {
      state = state.copyWith(
        chargementDetails: false,
        erreur: () => e.toString(),
      );
    }
  }

  Future<bool> initialiserPaiement() async {
    // Sécurité client : Refus strict d'Orange Money direct tant qu'inactif
    if (state.prestataireSelectionne == PrestatairePaiement.orangeMoney) {
      state = state.copyWith(
        erreur: () => 'Le paiement Orange Money direct est temporairement désactivé. Veuillez utiliser LigdiCash.',
      );
      return false;
    }

    final dispo = state.disponibilites[state.prestataireSelectionne];
    if (dispo != null && !dispo.estConfigure && !state.estModeDemo) {
      state = state.copyWith(
        erreur: () => DisponibilitePrestataire.messageNonConfigure,
      );
      return false;
    }

    state = state.copyWith(chargement: true, erreur: () => null);
    try {
      final tx = await _dataSource.initialiserPaiement(
        entrepriseId: _entrepriseId,
        planCode: state.planCodeSelectionne,
        dureeMois: state.dureeMois,
        prestataire: state.prestataireSelectionne,
        estDemo: state.estModeDemo,
      );
      state = state.copyWith(
        chargement: false,
        transactionEnCours: () => tx,
      );
      await chargerHistorique();
      return true;
    } catch (e) {
      state = state.copyWith(chargement: false, erreur: () => e.toString());
      return false;
    }
  }

  Future<void> annulerTransaction([String? referenceOrId]) async {
    final tx = state.transactionEnCours;
    final txId = (referenceOrId != null && referenceOrId.isNotEmpty && referenceOrId != tx?.referenceInterne)
        ? referenceOrId
        : tx?.id;
    if (txId == null || txId.isEmpty) return;

    state = state.copyWith(chargement: true, erreur: () => null);
    try {
      final updated = await _dataSource.mettreAJourStatutClient(
        transactionId: txId,
        action: 'ANNULER',
      );
      state = state.copyWith(
        chargement: false,
        transactionEnCours: () => updated,
      );
      await chargerHistorique();
    } catch (e) {
      state = state.copyWith(chargement: false, erreur: () => e.toString());
    }
  }

  Future<void> simulerEchecDemo() async {
    final tx = state.transactionEnCours;
    if (tx == null || !tx.estDemo) return;

    state = state.copyWith(chargement: true, erreur: () => null);
    try {
      final updated = await _dataSource.mettreAJourStatutClient(
        transactionId: tx.id,
        action: 'SIMULER_ECHEC',
      );
      state = state.copyWith(
        chargement: false,
        transactionEnCours: () => updated,
      );
      await chargerHistorique();
    } catch (e) {
      state = state.copyWith(chargement: false, erreur: () => e.toString());
    }
  }

  Future<void> verifierStatutTransaction([String? referenceOrId]) async {
    final tx = state.transactionEnCours;
    final txId = (referenceOrId != null && referenceOrId.isNotEmpty && referenceOrId != tx?.referenceInterne)
        ? referenceOrId
        : tx?.id;
    if (txId == null || txId.isEmpty) return;

    try {
      final updated = await _dataSource.verifierStatutTransaction(txId);
      state = state.copyWith(transactionEnCours: () => updated);
      if (updated.statut == StatutTransactionAbonnement.confirme) {
        await ref.read(contexteSessionProvider.notifier).rafraichir();
        await chargerDetailsReglement(state.planCodeSelectionne);
      }
      await chargerHistorique();
    } catch (_) {}
  }

  Future<void> verifierStatutTransactionEnCours() => verifierStatutTransaction();

  /// Outil de test SANDBOX : permet d'avancer la fin de l'essai ou de réinitialiser l'essai
  /// pour tester le parcours de règlement sans attendre la fin des 10 jours.
  Future<bool> contournerEssaiPourTest([String action = 'ACCELERER_FIN_ESSAI']) async {
    if (_entrepriseId.isEmpty) return false;
    state = state.copyWith(chargement: true, erreur: () => null);
    try {
      await _dataSource.contournerEssaiPourTest(
        entrepriseId: _entrepriseId,
        action: action,
      );
      await ref.read(contexteSessionProvider.notifier).rafraichir();
      await chargerDetailsReglement(state.planCodeSelectionne);
      state = state.copyWith(chargement: false);
      return true;
    } catch (e) {
      state = state.copyWith(chargement: false, erreur: () => e.toString());
      return false;
    }
  }

  void reinitialiserTransaction() {
    state = state.copyWith(transactionEnCours: () => null, erreur: () => null);
  }

  Future<void> chargerHistorique() async {
    if (_entrepriseId.isEmpty) return;
    state = state.copyWith(chargementHistorique: true);
    try {
      final res = await _dataSource.listerPaiementsEtAbonnements(_entrepriseId);
      final txListRaw = res['transactions'] as List? ?? [];
      final transactions = txListRaw
          .map((e) => TransactionAbonnement.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      final renListRaw = res['renouvellements'] as List? ?? [];
      final renouvellements = renListRaw
          .map((e) => HistoriqueRenouvellementItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      state = state.copyWith(
        chargementHistorique: false,
        historiqueTransactions: transactions,
        historiqueRenouvellements: renouvellements,
      );
    } catch (_) {
      state = state.copyWith(chargementHistorique: false);
    }
  }
}

final paiementAbonnementNotifierProvider =
    NotifierProvider.autoDispose<PaiementAbonnementNotifier, PaiementAbonnementState>(
  PaiementAbonnementNotifier.new,
);
