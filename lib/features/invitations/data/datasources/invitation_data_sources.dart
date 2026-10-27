import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InvitationRemoteDataSource {
  InvitationRemoteDataSource(this._client);
  final SupabaseClient _client;

  Future<Map<String, dynamic>> creer({
    required String entrepriseId,
    required String email,
    required String roleCode,
    required List<String> perimetreIds,
  }) =>
      _client.rpc<Map<String, dynamic>>('creer_invitation', params: {
        'p_entreprise_id': entrepriseId,
        'p_email': email,
        'p_role_code': roleCode,
        'p_perimetre_ids': perimetreIds,
      });

  Future<List<Map<String, dynamic>>> lister(String entrepriseId) async {
    final rows = await _client
        .from('invitations')
        .select('id, email, role_code, statut, expires_at, created_at, invitation_perimetres(perimetre_id)')
        .eq('entreprise_id', entrepriseId)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> renvoyer(String invitationId) =>
      _client.rpc<Map<String, dynamic>>('renvoyer_invitation', params: {'p_invitation_id': invitationId});

  Future<void> supprimer(String invitationId) =>
      _client.rpc<void>('supprimer_invitation', params: {'p_invitation_id': invitationId});

  Future<void> annuler(String invitationId) =>
      _client.rpc<void>('annuler_invitation', params: {'p_invitation_id': invitationId});

  Future<Map<String, dynamic>> verifier(String token) =>
      _client.rpc<Map<String, dynamic>>('verifier_invitation', params: {'p_token': token});

  Future<String> accepter(String token) =>
      _client.rpc<String>('accepter_invitation', params: {'p_token': token});
}

/// Jeton d'invitation en attente (lien ouvert avant connexion / inscription).
/// Il donne seulement le droit de demander l'acceptation : le serveur
/// vérifie l'adresse, l'expiration et l'usage unique.
class InvitationLocalDataSource {
  InvitationLocalDataSource(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'invitation_en_attente';

  String? get jeton => _prefs.getString(_key);
  Future<void> memoriser(String token) => _prefs.setString(_key, token);
  Future<void> oublier() => _prefs.remove(_key);
}
