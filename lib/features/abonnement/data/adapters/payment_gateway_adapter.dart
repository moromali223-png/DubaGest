import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/paiement_abonnement.dart';

/// Contrat d'adaptateur pour l'isolation des prestataires de paiement.
/// Permet d'intégrer LigdiCash et Orange Money sans exposer de secrets
/// ni inventer d'URL ou d'implémentation anticipée non confirmée.
abstract class SubscriptionPaymentGatewayAdapter {
  PrestatairePaiement get prestataire;

  /// Vérifie si l'API officielle est configurée côté serveur.
  Future<DisponibilitePrestataire> verifierDisponibilite();

  /// Initialise une transaction d'abonnement.
  Future<TransactionAbonnement> initialiserPaiement({
    required String entrepriseId,
    required String planCode,
    required int dureeMois,
    String? idempotencyKey,
    bool estDemo = false,
  });
}

/// Adaptateur dédié à LigdiCash (Payin avec Redirection).
class LigdiCashGatewayAdapter implements SubscriptionPaymentGatewayAdapter {
  LigdiCashGatewayAdapter({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _activeClient => _client ?? Supabase.instance.client;

  @override
  PrestatairePaiement get prestataire => PrestatairePaiement.ligdiCash;

  @override
  Future<DisponibilitePrestataire> verifierDisponibilite() async {
    if (_client == null) {
      return const DisponibilitePrestataire(
        prestataire: PrestatairePaiement.ligdiCash,
        estConfigure: false,
        message: DisponibilitePrestataire.messageNonConfigure,
      );
    }

    try {
      final res = await _activeClient.functions.invoke(
        'abonnement-paiement',
        body: {
          'action': 'verifier_disponibilite',
          'prestataire': 'LIGDICASH',
        },
      );
      if (res.status == 200 && res.data is Map) {
        final data = res.data as Map;
        final estConfigure = data['est_configure'] as bool? ?? false;
        final message = data['message'] as String? ?? DisponibilitePrestataire.messageNonConfigure;
        return DisponibilitePrestataire(
          prestataire: PrestatairePaiement.ligdiCash,
          estConfigure: estConfigure,
          message: message,
        );
      }
    } catch (_) {
      // Ignorer l'erreur réseau et continuer
    }

    return const DisponibilitePrestataire(
      prestataire: PrestatairePaiement.ligdiCash,
      estConfigure: false,
      message: DisponibilitePrestataire.messageNonConfigure,
    );
  }

  @override
  Future<TransactionAbonnement> initialiserPaiement({
    required String entrepriseId,
    required String planCode,
    required int dureeMois,
    String? idempotencyKey,
    bool estDemo = false,
  }) async {
    // 1. Tenter d'abord via l'Edge Function officielle abonnement-paiement
    try {
      final res = await _activeClient.functions.invoke(
        'abonnement-paiement',
        body: {
          'action': 'initialiser_paiement',
          'entreprise_id': entrepriseId,
          'plan_code': planCode,
          'duree_mois': dureeMois,
          'prestataire': 'LIGDICASH',
          'idempotency_key': idempotencyKey,
          'est_demo': estDemo,
        },
      );

      if (res.status == 200 && res.data is Map) {
        final data = Map<String, dynamic>.from(res.data as Map);
        if (data['succes'] == true && data['transaction'] is Map) {
          final txMap = Map<String, dynamic>.from(data['transaction'] as Map);
          if (data['url_paiement'] != null) {
            txMap['url_paiement'] = data['url_paiement'];
          }
          if (data['token'] != null) {
            txMap['token_transaction'] = data['token'];
          }
          return TransactionAbonnement.fromJson(txMap);
        }
      }
    } catch (_) {
      // Repli sur la procédure PostgreSQL directe si Edge Function non disponible
    }

    // 2. Repli direct RPC PostgreSQL
    final response = await _activeClient.rpc(
      'initialiser_paiement_abonnement',
      params: {
        'p_entreprise_id': entrepriseId,
        'p_plan_code': planCode,
        'p_duree_mois': dureeMois,
        'p_prestataire': 'LIGDICASH',
        'p_idempotency_key': idempotencyKey,
        'p_est_demo': estDemo,
      },
    );

    final data = Map<String, dynamic>.from(response as Map);
    final txMap = Map<String, dynamic>.from(data['transaction'] as Map);
    return TransactionAbonnement.fromJson(txMap);
  }
}

/// Adaptateur dédié à Orange Money.
class OrangeMoneyGatewayAdapter implements SubscriptionPaymentGatewayAdapter {
  OrangeMoneyGatewayAdapter({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _activeClient => _client ?? Supabase.instance.client;

  @override
  PrestatairePaiement get prestataire => PrestatairePaiement.orangeMoney;

  @override
  Future<DisponibilitePrestataire> verifierDisponibilite() async {
    // Par défaut avant configuration officielle des identifiants marchands Orange Money
    return const DisponibilitePrestataire(
      prestataire: PrestatairePaiement.orangeMoney,
      estConfigure: false,
      message: DisponibilitePrestataire.messageNonConfigure,
    );
  }

  @override
  Future<TransactionAbonnement> initialiserPaiement({
    required String entrepriseId,
    required String planCode,
    required int dureeMois,
    String? idempotencyKey,
    bool estDemo = false,
  }) async {
    final response = await _activeClient.rpc(
      'initialiser_paiement_abonnement',
      params: {
        'p_entreprise_id': entrepriseId,
        'p_plan_code': planCode,
        'p_duree_mois': dureeMois,
        'p_prestataire': 'ORANGE_MONEY',
        'p_idempotency_key': idempotencyKey,
        'p_est_demo': estDemo,
      },
    );

    final data = Map<String, dynamic>.from(response as Map);
    final txMap = Map<String, dynamic>.from(data['transaction'] as Map);
    return TransactionAbonnement.fromJson(txMap);
  }
}

