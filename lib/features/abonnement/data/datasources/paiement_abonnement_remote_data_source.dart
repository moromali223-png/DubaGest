import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/paiement_abonnement.dart';
import '../adapters/payment_gateway_adapter.dart';

class PaiementAbonnementRemoteDataSource {
  PaiementAbonnementRemoteDataSource({
    SupabaseClient? client,
    LigdiCashGatewayAdapter? ligdiCashAdapter,
    OrangeMoneyGatewayAdapter? orangeMoneyAdapter,
  })  : _client = client ?? Supabase.instance.client,
        _ligdiCashAdapter = ligdiCashAdapter ?? LigdiCashGatewayAdapter(client: client),
        _orangeMoneyAdapter = orangeMoneyAdapter ?? OrangeMoneyGatewayAdapter(client: client);

  final SupabaseClient _client;
  final LigdiCashGatewayAdapter _ligdiCashAdapter;
  final OrangeMoneyGatewayAdapter _orangeMoneyAdapter;

  SubscriptionPaymentGatewayAdapter getAdapter(PrestatairePaiement prestataire) {
    switch (prestataire) {
      case PrestatairePaiement.ligdiCash:
        return _ligdiCashAdapter;
      case PrestatairePaiement.orangeMoney:
        return _orangeMoneyAdapter;
    }
  }

  Future<DisponibilitePrestataire> verifierDisponibilite(PrestatairePaiement prestataire) {
    return getAdapter(prestataire).verifierDisponibilite();
  }

  Future<TransactionAbonnement> initialiserPaiement({
    required String entrepriseId,
    required String planCode,
    required int dureeMois,
    required PrestatairePaiement prestataire,
    String? idempotencyKey,
    bool estDemo = false,
  }) {
    return getAdapter(prestataire).initialiserPaiement(
      entrepriseId: entrepriseId,
      planCode: planCode,
      dureeMois: dureeMois,
      idempotencyKey: idempotencyKey,
      estDemo: estDemo,
    );
  }

  Future<TransactionAbonnement> mettreAJourStatutClient({
    required String transactionId,
    required String action, // 'ANNULER' | 'SIMULER_ECHEC'
    Map<String, dynamic> diagnostic = const {},
  }) async {
    final response = await _client.rpc(
      'mettre_a_jour_statut_paiement_abonnement_client',
      params: {
        'p_transaction_id': transactionId,
        'p_action': action,
        'p_diagnostic': diagnostic,
      },
    );

    final data = Map<String, dynamic>.from(response as Map);
    final txMap = Map<String, dynamic>.from(data['transaction'] as Map);
    return TransactionAbonnement.fromJson(txMap);
  }

  Future<Map<String, dynamic>> listerPaiementsEtAbonnements(String entrepriseId) async {
    final response = await _client.rpc(
      'lister_paiements_et_abonnements',
      params: {'p_entreprise_id': entrepriseId},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> preparerReglementAbonnement({
    required String entrepriseId,
    String? planCible,
  }) async {
    final response = await _client.rpc(
      'preparer_reglement_abonnement',
      params: {
        'p_entreprise_id': entrepriseId,
        'p_plan_cible': planCible,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<TransactionAbonnement> verifierStatutTransaction(String transactionId) async {
    final response = await _client.rpc(
      'verifier_statut_transaction',
      params: {'p_transaction_id': transactionId},
    );
    final data = Map<String, dynamic>.from(response as Map);
    final txMap = Map<String, dynamic>.from(data['transaction'] as Map);
    return TransactionAbonnement.fromJson(txMap);
  }

  /// Outil de test Sandbox : permet d'accélérer la fin des 10 jours ou de réinitialiser l'essai
  /// sans attendre et sans affecter les règles commerciales de production.
  Future<Map<String, dynamic>> contournerEssaiPourTest({
    required String entrepriseId,
    String action = 'ACCELERER_FIN_ESSAI',
  }) async {
    final response = await _client.rpc(
      'contourner_essai_pour_test',
      params: {
        'p_entreprise_id': entrepriseId,
        'p_action': action,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// Génère un lien officiel de test de 10 FCFA (Test B avec l'agrégateur)
  Future<Map<String, dynamic>> genererLienTest10Fcfa({
    String? entrepriseId,
    String? planCode,
    String? telephone,
  }) async {
    final res = await _client.functions.invoke(
      'abonnement-paiement',
      body: {
        'action': 'generer_lien_test_10fcfa',
        if (entrepriseId != null) 'entreprise_id': entrepriseId,
        if (planCode != null) 'plan_code': planCode,
        if (telephone != null) 'telephone': telephone,
      },
    );
    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw Exception('Réponse inattendue lors de la génération du lien de test 10 FCFA');
  }

  /// Initialise un paiement direct sans redirection (Test C avec l'agrégateur)
  Future<Map<String, dynamic>> payerSansRedirection({
    required String entrepriseId,
    required String telephone,
    String? planCode,
    int? dureeMois,
    int? montantTest,
    String? operateur,
    String? codeOtp,
  }) async {
    final res = await _client.functions.invoke(
      'abonnement-paiement',
      body: {
        'action': 'payer_sans_redirection',
        'entreprise_id': entrepriseId,
        'telephone': telephone,
        if (planCode != null) 'plan_code': planCode,
        if (dureeMois != null) 'duree_mois': dureeMois,
        if (montantTest != null) 'montant_test': montantTest,
        if (operateur != null) 'operateur': operateur,
        if (codeOtp != null) 'code_otp': codeOtp,
      },
    );
    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw Exception('Échec de la demande de paiement sans redirection');
  }

  /// Valide le code OTP transmis par le testeur pour le paiement direct
  Future<Map<String, dynamic>> validerOtpDirect({
    required String referenceInterne,
    required String codeOtp,
    String? tokenTransaction,
  }) async {
    final res = await _client.functions.invoke(
      'abonnement-paiement',
      body: {
        'action': 'valider_otp_direct',
        'reference_interne': referenceInterne,
        'code_otp': codeOtp,
        if (tokenTransaction != null) 'token_transaction': tokenTransaction,
      },
    );
    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw Exception('Échec de validation du code OTP');
  }
}
