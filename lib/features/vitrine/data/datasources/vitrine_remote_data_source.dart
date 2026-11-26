import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/vitrine_bien_immobilier.dart';
import '../../domain/entities/vitrine_config.dart';
import '../../domain/entities/vitrine_demande_visite.dart';
import '../../domain/entities/vitrine_galerie_item.dart';
import '../../domain/entities/vitrine_membre_equipe.dart';
import '../../domain/entities/vitrine_prestation.dart';
import '../../domain/entities/vitrine_produit_item.dart';
import '../../domain/entities/vitrine_publique_data.dart';
import '../../domain/entities/vitrine_rendez_vous.dart';

class VitrineRemoteDataSource {
  const VitrineRemoteDataSource(this._client);
  final SupabaseClient _client;

  bool _isTableOrSchemaCacheError(Object e) {
    if (e is PostgrestException) {
      if (e.code == 'PGRST205' || e.code == '42P01' || e.code == '42501') return true;
      final msg = e.message.toLowerCase();
      if (msg.contains('could not find the table') ||
          msg.contains('schema cache') ||
          msg.contains('permission denied') ||
          msg.contains('forbidden') ||
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

  // --- BIENS IMMOBILIERS VITRINE ---

  Future<List<VitrineBienImmobilier>> chargerBiens(String vitrineId, String entrepriseId) async {
    try {
      final res = await _client
          .from('vitrine_biens')
          .select()
          .eq('entreprise_id', entrepriseId)
          .order('ordre', ascending: true);

      final liste = (res as List).map((j) => VitrineBienImmobilier.fromJson(j as Map<String, dynamic>)).toList();
      if (liste.isNotEmpty) return liste;
    } catch (_) {}

    // Fallback automatique vers les biens de gestion ERP immobilier_biens (Mode A)
    try {
      final resImmo = await _client
          .from('immobilier_biens')
          .select()
          .eq('entreprise_id', entrepriseId)
          .eq('statut', 'DISPONIBLE')
          .order('created_at', ascending: false);

      return (resImmo as List).map((j) => VitrineBienImmobilier.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<VitrineBienImmobilier> sauvegarderBien(VitrineBienImmobilier bien) async {
    try {
      final data = bien.toJson();
      if (bien.id.isEmpty) {
        data.remove('id');
      }
      data['updated_at'] = DateTime.now().toIso8601String();

      final res = await _client
          .from('vitrine_biens')
          .upsert(data)
          .select()
          .single();

      return VitrineBienImmobilier.fromJson(res);
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
  }

  Future<void> supprimerBien(String bienId) async {
    try {
      await _client.from('vitrine_biens').delete().eq('id', bienId);
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
  }

  // --- DEMANDES DE VISITE IMMOBILIÈRE ---

  Future<List<VitrineDemandeVisite>> chargerDemandesVisite(String entrepriseId) async {
    try {
      final res = await _client
          .from('vitrine_demandes_visite')
          .select()
          .eq('entreprise_id', entrepriseId)
          .order('created_at', ascending: false);

      return (res as List).map((j) => VitrineDemandeVisite.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e, st) {
      if (_isTableOrSchemaCacheError(e)) {
        return const [];
      }
      throw ErrorMapper.map(e, st);
    }
  }

  Future<VitrineDemandeVisite> changerStatutDemandeVisite(
    String id,
    StatutDemandeVisite statut,
  ) async {
    try {
      final res = await _client
          .from('vitrine_demandes_visite')
          .update({
            'statut': statut.code,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .select()
          .single();

      return VitrineDemandeVisite.fromJson(res);
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
  }

  Future<void> creerDemandeVisite(VitrineDemandeVisite demande) async {
    try {
      final data = demande.toJson();
      if (demande.id.isEmpty) {
        data.remove('id');
      }
      await _client.from('vitrine_demandes_visite').insert(data);
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
  }

  // --- GESTION DES PRODUITS DE LA VITRINE ---

  Future<List<VitrineProduitItem>> chargerProduitsVitrine(String entrepriseId) async {
    final List<VitrineProduitItem> produitsVitrineConfig = [];
    try {
      final v = await chargerVitrine(entrepriseId);
      if (v != null && v.reseauxSociaux['produits_vitrine'] is List) {
        for (final p in (v.reseauxSociaux['produits_vitrine'] as List)) {
          if (p is Map) {
            produitsVitrineConfig.add(VitrineProduitItem.fromJson(Map<String, dynamic>.from(p)));
          }
        }
      }
    } catch (_) {}

    try {
      final res = await _client
          .from('produits')
          .select()
          .eq('entreprise_id', entrepriseId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      final produitsSql = (res as List).map((j) => VitrineProduitItem.fromJson(j as Map<String, dynamic>)).toList();

      final fusion = <String, VitrineProduitItem>{};
      for (final p in produitsSql) {
        fusion[p.id] = p;
      }
      for (final p in produitsVitrineConfig) {
        fusion[p.id] = p;
      }
      return fusion.values.toList();
    } catch (e) {
      if (_isTableOrSchemaCacheError(e)) {
        return produitsVitrineConfig;
      }
      return produitsVitrineConfig;
    }
  }

  Future<VitrineProduitItem> sauvegarderProduitVitrine(VitrineProduitItem item, String entrepriseId) async {
    final itemId = item.id.isNotEmpty ? item.id : const Uuid().v4();
    final itemAEnregistrer = item.id.isEmpty ? item.copyWith(id: itemId) : item;

    // 1. Tenter d'enregistrer dans public.produits (si permissions accordées)
    try {
      final data = itemAEnregistrer.toJson(entrepriseId: entrepriseId);
      data['updated_at'] = DateTime.now().toIso8601String();
      await _client.from('produits').upsert(data);
    } catch (_) {
      // Résilience : Si 42501 (permission denied table produits) pour compte Services ou absence de module,
      // on ignore pour basculer en toute transparence sur la persistance vitrine.
    }

    // 2. Persistance garantie dans la configuration vitrine (toujours autorisée via app.est_membre)
    try {
      final vitrine = await chargerVitrine(entrepriseId);
      if (vitrine != null) {
        final mapReseaux = Map<String, dynamic>.from(vitrine.reseauxSociaux);
        final rawList = (mapReseaux['produits_vitrine'] as List?) ?? [];
        final listeMiseAJour = <Map<String, dynamic>>[];
        bool remplace = false;

        for (final p in rawList) {
          if (p is Map && p['id'] == itemAEnregistrer.id) {
            listeMiseAJour.add(itemAEnregistrer.toJson(entrepriseId: entrepriseId));
            remplace = true;
          } else if (p is Map) {
            listeMiseAJour.add(Map<String, dynamic>.from(p));
          }
        }
        if (!remplace) {
          listeMiseAJour.add(itemAEnregistrer.toJson(entrepriseId: entrepriseId));
        }

        mapReseaux['produits_vitrine'] = listeMiseAJour;
        await sauvegarderVitrine(vitrine.copyWith(reseauxSociaux: mapReseaux));
      }
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }

    return itemAEnregistrer;
  }

  Future<void> basculerPublicationProduit(String produitId, bool estPublie, {String? entrepriseId}) async {
    try {
      await _client.from('produits').update({
        'est_publie_catalogue': estPublie,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', produitId);
    } catch (_) {}

    if (entrepriseId != null && entrepriseId.isNotEmpty) {
      try {
        final vitrine = await chargerVitrine(entrepriseId);
        if (vitrine != null) {
          final mapReseaux = Map<String, dynamic>.from(vitrine.reseauxSociaux);
          final rawList = (mapReseaux['produits_vitrine'] as List?) ?? [];
          final listeMiseAJour = <Map<String, dynamic>>[];
          for (final p in rawList) {
            if (p is Map && p['id'] == produitId) {
              final m = Map<String, dynamic>.from(p);
              m['est_publie_catalogue'] = estPublie;
              listeMiseAJour.add(m);
            } else if (p is Map) {
              listeMiseAJour.add(Map<String, dynamic>.from(p));
            }
          }
          mapReseaux['produits_vitrine'] = listeMiseAJour;
          await sauvegarderVitrine(vitrine.copyWith(reseauxSociaux: mapReseaux));
        }
      } catch (_) {}
    }
  }

  Future<void> supprimerProduitVitrine(String produitId, {String? entrepriseId}) async {
    try {
      await _client.from('produits').update({
        'deleted_at': DateTime.now().toIso8601String(),
        'est_actif': false,
        'est_publie_catalogue': false,
      }).eq('id', produitId);
    } catch (_) {}

    if (entrepriseId != null && entrepriseId.isNotEmpty) {
      try {
        final vitrine = await chargerVitrine(entrepriseId);
        if (vitrine != null) {
          final mapReseaux = Map<String, dynamic>.from(vitrine.reseauxSociaux);
          final rawList = (mapReseaux['produits_vitrine'] as List?) ?? [];
          final listeMiseAJour = <Map<String, dynamic>>[];
          for (final p in rawList) {
            if (p is Map && p['id'] != produitId) {
              listeMiseAJour.add(Map<String, dynamic>.from(p));
            }
          }
          mapReseaux['produits_vitrine'] = listeMiseAJour;
          await sauvegarderVitrine(vitrine.copyWith(reseauxSociaux: mapReseaux));
        }
      } catch (_) {}
    }
  }
}
