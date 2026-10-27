import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/declassement_models.dart';

class DeclassementRemoteDataSource {
  DeclassementRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<AnalyseDeclassement> analyserLimites({
    required String entrepriseId,
    required String planCibleCode,
  }) async {
    final res = await _client.rpc(
      'analyser_limites_declassement',
      params: {
        'p_entreprise_id': entrepriseId,
        'p_plan_cible': planCibleCode,
      },
    );

    if (res is Map) {
      return AnalyseDeclassement.fromJson(Map<String, dynamic>.from(res));
    }
    throw Exception('Réponse invalide du serveur pour l\'analyse du déclassement');
  }

  Future<DemandeDeclassement> demanderDeclassement({
    required String entrepriseId,
    required String planCibleCode,
  }) async {
    final res = await _client.rpc(
      'demander_declassement',
      params: {
        'p_entreprise_id': entrepriseId,
        'p_plan_cible': planCibleCode,
      },
    );

    if (res is Map) {
      return DemandeDeclassement.fromJson(Map<String, dynamic>.from(res));
    }
    throw Exception('Échec de création de la demande de déclassement');
  }

  Future<DemandeDeclassement?> getDemandeEnCours(String entrepriseId) async {
    final res = await _client
        .from('demandes_declassement')
        .select()
        .eq('entreprise_id', entrepriseId)
        .inFilter('statut', ['pending_preparation', 'ready', 'scheduled'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (res == null) return null;
    return DemandeDeclassement.fromJson(Map<String, dynamic>.from(res));
  }

  Future<void> ajusterRessource({
    required String entrepriseId,
    required String typeRessource,
    required String ressourceId,
    required String action,
  }) async {
    await _client.rpc(
      'ajuster_ressource_declassement',
      params: {
        'p_entreprise_id': entrepriseId,
        'p_type_ressource': typeRessource,
        'p_ressource_id': ressourceId,
        'p_action': action,
      },
    );
  }

  Future<Map<String, dynamic>> validerEtAppliquerDeclassement(String demandeId) async {
    final res = await _client.rpc(
      'valider_et_appliquer_declassement',
      params: {
        'p_demande_id': demandeId,
      },
    );

    if (res is Map<String, dynamic>) {
      return res;
    }
    throw Exception('Réponse inattendue lors de la validation du déclassement');
  }

  Future<void> annulerDemande(String demandeId) async {
    await _client.rpc(
      'annuler_demande_declassement',
      params: {
        'p_demande_id': demandeId,
      },
    );
  }
}
