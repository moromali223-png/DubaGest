import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/di/app_composition.dart';
import '../../../../core/errors/error_mapper.dart';
import '../domain/entities/catalogue_public_data.dart';

abstract class CatalogueRepository {
  Future<BoutiquePubliqueData> chargerBoutiquePublique(String slugOuId);
}

class CatalogueRepositoryImpl implements CatalogueRepository {
  CatalogueRepositoryImpl(this._client);
  final SupabaseClient _client;

  @override
  Future<BoutiquePubliqueData> chargerBoutiquePublique(String slugOuId) async {
    try {
      final res = await _client.rpc('consulter_catalogue_public', params: {
        'p_slug_ou_id': slugOuId.trim(),
      });
      if (res == null) {
        throw Exception('Boutique introuvable ou inactive');
      }
      final map = (res as Map).cast<String, dynamic>();
      return BoutiquePubliqueData.fromJson(map);
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
  }
}

final catalogueRepositoryProvider = Provider<CatalogueRepository>((ref) {
  return CatalogueRepositoryImpl(ref.watch(supabaseClientProvider));
});

final boutiquePubliqueProvider = FutureProvider.family<BoutiquePubliqueData, String>((ref, slugOuId) {
  return ref.watch(catalogueRepositoryProvider).chargerBoutiquePublique(slugOuId);
});
