import 'package:supabase_flutter/supabase_flutter.dart';

import '../../errors/error_mapper.dart';
import '../../errors/failure.dart';
import '../sync_contracts.dart';
import '../sync_models.dart';

/// Synchronisation via Supabase :
/// - montée : RPC `sync_push` (idempotente, contrôle de version, RLS appliquée) ;
/// - descente : lecture REST filtrée par RLS, pagination par clé.
class SupabaseSyncGateway implements SyncRemoteGateway {
  SupabaseSyncGateway(this._client);
  final SupabaseClient _client;

  /// Indique si l'erreur provient d'une table/colonne distante absente du schéma
  /// PostgREST ou non encore enregistrée dans `app.sync_tables`.
  static bool isMissingRemoteTableError(Object error) {
    if (error is PostgrestException) {
      if (error.code == 'PGRST205' ||
          error.code == '42P01' ||
          error.code == 'PGRST204' ||
          (error.code == ErrorMapper.businessRuleSqlState &&
              error.message == 'SYNC_TABLE_INCONNUE')) {
        return true;
      }
    }
    if (error is Failure) {
      if (error.ruleCode == 'SYNC_TABLE_INCONNUE') return true;
      if (error.cause case final c? when isMissingRemoteTableError(c)) return true;
    }
    final msg = error.toString().toLowerCase();
    return msg.contains('pgrst205') ||
        msg.contains('schema cache') ||
        msg.contains('could not find the table') ||
        msg.contains('sync_table_inconnue');
  }

  @override
  Future<PushResult> push(SyncOperation op) async {
    try {
      final response = await _client.rpc<Map<String, dynamic>>('sync_push', params: {
        'p_op_id': op.id,
        'p_table': op.entityTable,
        'p_operation': op.type.wire,
        'p_record_id': op.recordId,
        'p_base_version': op.baseVersion,
        'p_payload': op.payload,
      });
      final status = switch (response['statut']) {
        'APPLIQUE' => PushStatus.applied,
        'CONFLIT' => PushStatus.conflict,
        'INTROUVABLE' => PushStatus.notFound,
        'INTERDIT' => PushStatus.forbidden,
        final other => throw StateError('Statut sync_push inconnu : $other'),
      };
      return PushResult(
        status,
        (response['ligne'] as Map?)?.cast<String, dynamic>(),
        replayed: response['rejoue'] == true,
      );
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> pull({
    required String table,
    required String entrepriseId,
    required String? afterUpdatedAt,
    required String? afterId,
    required int limit,
  }) async {
    try {
      var query = _client.from(table).select().eq('entreprise_id', entrepriseId);
      if (afterUpdatedAt != null) {
        final ts = '"$afterUpdatedAt"';
        query = afterId == null
            ? query.gt('updated_at', afterUpdatedAt)
            : query.or('updated_at.gt.$ts,and(updated_at.eq.$ts,id.gt.$afterId)');
      }
      final rows = await query
          .order('updated_at', ascending: true)
          .order('id', ascending: true)
          .limit(limit);
      return List<Map<String, dynamic>>.from(rows);
    } on PostgrestException catch (e, st) {
      if (isMissingRemoteTableError(e) || e.code == '42501') {
        return const <Map<String, dynamic>>[];
      }
      throw ErrorMapper.map(e, st);
    } catch (e, st) {
      if (isMissingRemoteTableError(e)) {
        return const <Map<String, dynamic>>[];
      }
      throw ErrorMapper.map(e, st);
    }
  }
}
