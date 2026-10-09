import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class ContexteRemoteDataSource {
  Future<Map<String, dynamic>> fetch({String? entrepriseId});
}

class SupabaseContexteRemoteDataSource implements ContexteRemoteDataSource {
  SupabaseContexteRemoteDataSource(this._client);
  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> fetch({String? entrepriseId}) =>
      _client.rpc<Map<String, dynamic>>(
        'get_contexte_session',
        params: {'p_entreprise_id': entrepriseId},
      );
}
