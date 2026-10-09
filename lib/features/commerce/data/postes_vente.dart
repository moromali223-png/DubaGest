import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/commerce.dart';
import 'commerce_local_data_source.dart';

/// Lettre de poste de cet appareil dans chaque boutique où l'utilisateur vend
/// (« A », « B »…), demandée au serveur quand le réseau est là. Elle permet
/// ensuite de numéroter les reçus seul, hors-ligne, sans collision possible.
class PostesVenteService {
  PostesVenteService(this._local, this._client);

  final CommerceLocalDataSource _local;
  final SupabaseClient? Function() _client;

  Future<void> assurer({
    required String entrepriseId,
    required List<String> boutiques,
    required String appareilId,
  }) async {
    final client = _client();
    if (client == null) return;
    for (final perimetreId in boutiques) {
      final r = await client.rpc<dynamic>('attribuer_poste_vente', params: {
        'p_entreprise_id': entrepriseId,
        'p_perimetre_id': perimetreId,
        'p_appareil_id': appareilId,
      });
      final j = (r as Map).cast<String, dynamic>();
      await _local.enregistrerPoste(
        entrepriseId: entrepriseId,
        perimetreId: perimetreId,
        code: j['code'] as String,
        derniers: {
          for (final MapEntry(:key, :value) in ((j['derniers'] as Map?) ?? const {}).entries)
            key as String: (value as num).toInt(),
        },
        jour: jourCommercial(DateTime.now()),
      );
    }
  }
}
