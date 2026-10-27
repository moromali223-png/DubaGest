import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/super_admin_entities.dart';

class SuperAdminRemoteDataSource {
  SuperAdminRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<bool> estSuperAdmin() async {
    try {
      final res = await _client.rpc('est_super_admin');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<SuperAdminDashboard> getTableauDeBord() async {
    final res = await _client.rpc('admin_get_tableau_de_bord');
    if (res is Map<String, dynamic>) {
      return SuperAdminDashboard.fromJson(res);
    }
    throw Exception('Réponse invalide du serveur pour le tableau de bord Super Admin');
  }

  Future<List<AdminEntreprise>> listerEntreprises({
    String? recherche,
    String? statut,
    String? plan,
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await _client.rpc(
      'admin_lister_entreprises',
      params: {
        'p_recherche': recherche?.trim().isEmpty == true ? null : recherche?.trim(),
        'p_statut': statut,
        'p_plan': plan,
        'p_limit': limit,
        'p_offset': offset,
      },
    );

    if (res is Map<String, dynamic> && res['entreprises'] is List) {
      final list = res['entreprises'] as List;
      return list.map((e) => AdminEntreprise.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> detailEntreprise(String entrepriseId) async {
    final res = await _client.rpc(
      'admin_detail_entreprise',
      params: {'p_entreprise_id': entrepriseId},
    );
    if (res is Map<String, dynamic>) {
      return res;
    }
    throw Exception('Détails de l\'entreprise introuvables');
  }

  Future<void> suspendreEntreprise(String entrepriseId, String motif) async {
    await _client.rpc(
      'admin_suspendre_entreprise',
      params: {
        'p_entreprise_id': entrepriseId,
        'p_motif': motif,
      },
    );
  }

  Future<void> reactiverEntreprise(String entrepriseId, {String? motif}) async {
    await _client.rpc(
      'admin_reactiver_entreprise',
      params: {
        'p_entreprise_id': entrepriseId,
        'p_motif': motif,
      },
    );
  }

  Future<void> accorderAccesSponsorise({
    required String entrepriseId,
    required String planCode,
    required String motif,
  }) async {
    await _client.rpc(
      'admin_accorder_acces_sponsorise',
      params: {
        'p_entreprise_id': entrepriseId,
        'p_plan_code': planCode,
        'p_motif': motif,
      },
    );
  }

  Future<void> revoquerAccesSponsorise({
    required String entrepriseId,
    required String motif,
  }) async {
    await _client.rpc(
      'admin_revoquer_acces_sponsorise',
      params: {
        'p_entreprise_id': entrepriseId,
        'p_motif': motif,
      },
    );
  }

  Future<List<AdminAuditLog>> listerAuditLogs({int limit = 50, int offset = 0}) async {
    final res = await _client.rpc(
      'admin_lister_audit_logs',
      params: {
        'p_limit': limit,
        'p_offset': offset,
      },
    );

    if (res is Map<String, dynamic> && res['logs'] is List) {
      final list = res['logs'] as List;
      return list.map((e) => AdminAuditLog.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<void> bootstrapSuperAdmin({required String email, required String motif}) async {
    await _client.rpc(
      'admin_bootstrap_super_admin',
      params: {
        'p_email': email,
        'p_motif': motif,
      },
    );
  }
}
