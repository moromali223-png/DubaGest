import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/entree_audit.dart';
import '../../domain/repositories/audit_repository.dart';

/// Journal d'activité : lecture seule. La RLS ne renvoie rien sans `audit.view`.
class AuditRepositoryImpl implements AuditRepository {
  AuditRepositoryImpl(this._client);
  final SupabaseClient _client;

  @override
  Future<List<EntreeAudit>> lister(String entrepriseId, {int limite = 100, int? avantId}) async {
    try {
      var requete = _client
          .from('audit_logs')
          .select('id, user_id, action, entite_type, entite_id, anciennes_valeurs, nouvelles_valeurs, created_at')
          .eq('entreprise_id', entrepriseId);
      if (avantId != null) requete = requete.lt('id', avantId);
      final rows = List<Map<String, dynamic>>.from(await requete.order('id', ascending: false).limit(limite));

      // Noms des auteurs (profils visibles par les membres de l'entreprise).
      final ids = {for (final r in rows) if (r['user_id'] != null) r['user_id'] as String};
      final noms = <String, String?>{};
      if (ids.isNotEmpty) {
        final profils = await _client.from('profiles').select('id, nom_complet').inFilter('id', ids.toList());
        for (final p in profils) {
          noms[p['id'] as String] = p['nom_complet'] as String?;
        }
      }

      return [
        for (final r in rows)
          EntreeAudit(
            id: r['id'] as int,
            action: AuditAction.parse(r['action'] as String),
            entiteType: r['entite_type'] as String,
            entiteId: r['entite_id'] as String,
            date: DateTime.parse(r['created_at'] as String),
            auteurId: r['user_id'] as String?,
            auteurNom: noms[r['user_id']],
            avant: (r['anciennes_valeurs'] as Map?)?.cast<String, dynamic>() ?? const {},
            apres: (r['nouvelles_valeurs'] as Map?)?.cast<String, dynamic>() ?? const {},
          ),
      ];
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
  }
}
