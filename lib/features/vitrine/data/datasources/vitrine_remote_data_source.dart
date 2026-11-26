import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/vitrine_config.dart';
import '../../domain/entities/vitrine_galerie_item.dart';
import '../../domain/entities/vitrine_membre_equipe.dart';
import '../../domain/entities/vitrine_prestation.dart';
import '../../domain/entities/vitrine_publique_data.dart';
import '../../domain/entities/vitrine_rendez_vous.dart';

class VitrineRemoteDataSource {
  const VitrineRemoteDataSource(this._client);
  final SupabaseClient _client;

  bool _isTableOrSchemaCacheError(Object e) {
    if (e is PostgrestException) {
      if (e.code == 'PGRST205' || e.code == '42P01') return true;
      final msg = e.message.toLowerCase();
      if (msg.contains('could not find the table') ||
          msg.contains('schema cache') ||
          (msg.contains('relation') && msg.contains('does not exist'))) {
        return true;
      }
    }
    return false;
  }

  // --- CONFIGURATION VITRINE ---

  Future<VitrineConfig?> chargerVitrine(String entrepriseId) async {
    try {
      final res = await _client
          .from('vitrines')
          .select()
          .eq('entreprise_id', entrepriseId)
          .maybeSingle();

      if (res == null) return null;
      return VitrineConfig.fromJson(res);
    } catch (e, st) {
      if (_isTableOrSchemaCacheError(e)) {
        return null;
      }
      throw ErrorMapper.map(e, st);
    }
  }

  Future<VitrineConfig> sauvegarderVitrine(VitrineConfig config) async {
    try {
      final data = config.toJson();
      if (config.id.isEmpty) {
        data.remove('id');
      }
      data['updated_at'] = DateTime.now().toIso8601String();

      final res = await _client
          .from('vitrines')
          .upsert(data, onConflict: 'entreprise_id')
          .select()
          .single();

      return VitrineConfig.fromJson(res);
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
  }

  Future<VitrinePubliqueData> chargerVitrinePublique(String slugOuId) async {
    try {
      final res = await _client.rpc('consulter_vitrine_publique', params: {
        'p_slug_ou_id': slugOuId.trim(),
      });

      if (res == null) {
        throw Exception('Vitrine introuvable ou inactive');
      }

      final map = (res as Map).cast<String, dynamic>();
      return VitrinePubliqueData.fromJson(map);
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
  }

  // --- PRESTATIONS ---

  Future<List<VitrinePrestation>> chargerPrestations(String vitrineId, String entrepriseId) async {
    try {
      final res = await _client
          .from('vitrine_prestations')
          .select()
          .eq('entreprise_id', entrepriseId)
          .order('ordre', ascending: true);

      return (res as List).map((j) => VitrinePrestation.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e, st) {
      if (_isTableOrSchemaCacheError(e)) {
        return const [];
      }
      throw ErrorMapper.map(e, st);
    }
  }

  Future<VitrinePrestation> sauvegarderPrestation(VitrinePrestation prestation) async {
    try {
      final data = prestation.toJson();
      if (prestation.id.isEmpty) {
        data.remove('id');
      }
      data['updated_at'] = DateTime.now().toIso8601String();

      final res = await _client.from('vitrine_prestations').upsert(data).select().single();
      return VitrinePrestation.fromJson(res);
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
  }

  Future<void> supprimerPrestation(String prestationId) async {
    try {
      await _client.from('vitrine_prestations').delete().eq('id', prestationId);
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
  }

  // --- GALERIE ---

  Future<List<VitrineGalerieItem>> chargerGalerie(String vitrineId, String entrepriseId) async {
    try {
      final res = await _client
          .from('vitrine_galerie')
          .select()
          .eq('entreprise_id', entrepriseId)
          .order('ordre', ascending: true);

      return (res as List).map((j) => VitrineGalerieItem.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e, st) {
      if (_isTableOrSchemaCacheError(e)) {
        return const [];
      }
      throw ErrorMapper.map(e, st);
    }
  }

  Future<VitrineGalerieItem> ajouterPhotoGalerie(VitrineGalerieItem item) async {
    try {
      final data = item.toJson();
      if (item.id.isEmpty) {
        data.remove('id');
      }

      final res = await _client.from('vitrine_galerie').insert(data).select().single();
      return VitrineGalerieItem.fromJson(res);
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
  }

  Future<void> supprimerPhotoGalerie(String photoId) async {
    try {
      await _client.from('vitrine_galerie').delete().eq('id', photoId);
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
  }

  // --- ÉQUIPE ---

  Future<List<VitrineMembreEquipe>> chargerEquipe(String vitrineId, String entrepriseId) async {
    try {
      final res = await _client
          .from('vitrine_equipe')
          .select()
          .eq('entreprise_id', entrepriseId)
          .order('ordre', ascending: true);

      return (res as List).map((j) => VitrineMembreEquipe.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e, st) {
      if (_isTableOrSchemaCacheError(e)) {
        return const [];
      }
      throw ErrorMapper.map(e, st);
    }
  }

  Future<VitrineMembreEquipe> sauvegarderMembreEquipe(VitrineMembreEquipe membre) async {
    try {
      final data = membre.toJson();
      if (membre.id.isEmpty) {
        data.remove('id');
      }

      final res = await _client.from('vitrine_equipe').upsert(data).select().single();
      return VitrineMembreEquipe.fromJson(res);
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
  }

  Future<void> supprimerMembreEquipe(String membreId) async {
    try {
      await _client.from('vitrine_equipe').delete().eq('id', membreId);
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
  }

  // --- RENDEZ-VOUS ---

  Future<List<VitrineRendezVous>> chargerRendezVous(String entrepriseId) async {
    try {
      final res = await _client
          .from('vitrine_rendez_vous')
          .select()
          .eq('entreprise_id', entrepriseId)
          .order('date_souhaitee', ascending: false)
          .order('created_at', ascending: false);

      return (res as List).map((j) => VitrineRendezVous.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e, st) {
      if (_isTableOrSchemaCacheError(e)) {
        return const [];
      }
      throw ErrorMapper.map(e, st);
    }
  }

  Future<VitrineRendezVous> changerStatutRendezVous(
    String rdvId,
    StatutRendezVous statut, {
    String? reponse,
  }) async {
    try {
      final payload = <String, dynamic>{
        'statut': statut.code,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (reponse != null) {
        payload['reponse_salon'] = reponse;
      }

      final res = await _client
          .from('vitrine_rendez_vous')
          .update(payload)
          .eq('id', rdvId)
          .select()
          .single();

      return VitrineRendezVous.fromJson(res);
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
  }

  Future<void> creerDemandeRendezVous(VitrineRendezVous rdv) async {
    try {
      final data = rdv.toJson();
      if (rdv.id.isEmpty) {
        data.remove('id');
      }
      await _client.from('vitrine_rendez_vous').insert(data);
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
  }
}
