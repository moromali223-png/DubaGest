import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/database/json_cache_store.dart';

class MembreRemoteDataSource {
  MembreRemoteDataSource(this._client);
  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> lister(String entrepriseId) async {
    final rows = await _client
        .from('membres_entreprise')
        .select('id, user_id, role_code, statut, profiles(nom_complet), membre_perimetres(perimetre_id)')
        .eq('entreprise_id', entrepriseId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> affecter({
    required String entrepriseId,
    required String membreId,
    required String perimetreId,
  }) =>
      _client.from('membre_perimetres').insert({
        'entreprise_id': entrepriseId,
        'membre_id': membreId,
        'perimetre_id': perimetreId,
      });

  Future<void> retirer({required String membreId, required String perimetreId}) => _client
      .from('membre_perimetres')
      .delete()
      .eq('membre_id', membreId)
      .eq('perimetre_id', perimetreId);

  Future<void> modifierRole({
    required String membreId,
    required String roleCode,
  }) =>
      _client.from('membres_entreprise').update({'role_code': roleCode}).eq('id', membreId);

  Future<void> modifierStatut({
    required String membreId,
    required String statut,
  }) =>
      _client.from('membres_entreprise').update({'statut': statut}).eq('id', membreId);

  Future<void> supprimer({required String membreId}) =>
      _client.from('membres_entreprise').delete().eq('id', membreId);
}

class MembreLocalDataSource {
  MembreLocalDataSource(this._store);
  final JsonCacheStore _store;

  static String _key(String entrepriseId) => 'membres:$entrepriseId';

  Future<List<Map<String, dynamic>>?> lire(String entrepriseId) async {
    final cached = await _store.read(_key(entrepriseId));
    return (cached?.data['items'] as List?)?.cast<Map<String, dynamic>>();
  }

  Future<void> ecrire(String entrepriseId, List<Map<String, dynamic>> items) =>
      _store.write(_key(entrepriseId), {'items': items});
}
