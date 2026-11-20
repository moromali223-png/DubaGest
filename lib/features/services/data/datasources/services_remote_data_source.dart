import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/sync/sync_models.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../fichiers/data/fichiers_repository_impl.dart' show bucketFichiers;
import '../../domain/entities/prestation.dart';
import '../../domain/entities/service_catalogue.dart';

class ServicesRemoteDataSource {
  const ServicesRemoteDataSource(this._client);
  final SupabaseClient _client;

  // --- CATALOGUE ---

  Future<List<ServiceCatalogue>> chargerCatalogue(String entrepriseId) async {
    final response = await _client
        .from('services_catalogue')
        .select()
        .eq('entreprise_id', entrepriseId)
        .eq('est_actif', true)
        .order('ordre', ascending: true);

    return (response as List<dynamic>)
        .map((j) => _mapServiceCatalogue(j as Map<String, dynamic>))
        .toList();
  }

  Future<ServiceCatalogue> sauvegarderServiceCatalogue(ServiceCatalogue service) async {
    final payload = {
      'id': service.id,
      'entreprise_id': service.entrepriseId,
      'nom': service.nom,
      'categorie': service.categorie,
      'description': service.description,
      'prix': service.prix,
      'unite': service.unite.code,
      'duree_minutes': service.dureeMinutes,
      'icone': service.icone,
      'est_actif': service.estActif,
      'ordre': service.ordre,
    };

    final response = await _client
        .from('services_catalogue')
        .upsert(payload)
        .select()
        .single();

    return _mapServiceCatalogue(response);
  }

  Future<void> archiverServiceCatalogue(String serviceId) async {
    await _client.from('services_catalogue').update({'est_actif': false}).eq('id', serviceId);
  }

  // --- PRESTATIONS ---

  Future<List<Prestation>> chargerPrestations(String entrepriseId, {String? perimetreId}) async {
    var query = _client.from('prestations').select().eq('entreprise_id', entrepriseId);
    if (perimetreId != null) {
      query = query.eq('perimetre_id', perimetreId);
    }
    final response = await query.order('created_at', ascending: false);

    final rows = response as List<dynamic>;
    final prestationIds = rows.map((p) => p['id'] as String).toList();
    final montantsRegles = <String, int>{};
    final photosParPrestation = <String, List<PhotoPrestation>>{};

    if (prestationIds.isNotEmpty) {
      // 1. Récupérer les montants réglés des engagements associés
      try {
        final engagements = await _client
            .from('engagements')
            .select('id, montant_regle')
            .inFilter('id', prestationIds);
        for (final e in engagements as List<dynamic>) {
          montantsRegles[e['id'] as String] = (e['montant_regle'] as num?)?.toInt() ?? 0;
        }
      } catch (_) {}

      // 2. Récupérer les photos stockées dans pieces_jointes (compatibilité universelle)
      try {
        final pjs = await _client
            .from('pieces_jointes')
            .select()
            .eq('cible_type', 'ENGAGEMENT')
            .inFilter('cible_id', prestationIds)
            .isFilter('deleted_at', null)
            .order('created_at', ascending: true);
        for (final pj in pjs as List<dynamic>) {
          final map = pj as Map<String, dynamic>;
          final mime = map['type_mime'] as String? ?? '';
          if (!mime.startsWith('image/')) continue;
          final cibleId = map['cible_id'] as String;
          photosParPrestation.putIfAbsent(cibleId, () => []).add(_photoDepuisPieceJointe(map));
        }
      } catch (_) {}
    }

    return rows.map((j) {
      final map = j as Map<String, dynamic>;
      final id = map['id'] as String;
      return _mapPrestation(
        map,
        montantsRegles[id] ?? 0,
        photosPiecesJointes: photosParPrestation[id] ?? const [],
      );
    }).toList();
  }

  Future<Prestation?> getPrestation(String prestationId) async {
    final response = await _client.from('prestations').select().eq('id', prestationId).maybeSingle();
    if (response == null) return null;

    int regle = 0;
    try {
      final engagement = await _client.from('engagements').select('montant_regle').eq('id', prestationId).maybeSingle();
      regle = (engagement?['montant_regle'] as num?)?.toInt() ?? 0;
    } catch (_) {}

    final photosPj = <PhotoPrestation>[];
    try {
      final pjs = await _client
          .from('pieces_jointes')
          .select()
          .eq('cible_type', 'ENGAGEMENT')
          .eq('cible_id', prestationId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: true);
      for (final pj in pjs as List<dynamic>) {
        final map = pj as Map<String, dynamic>;
        final mime = map['type_mime'] as String? ?? '';
        if (mime.startsWith('image/')) {
          photosPj.add(_photoDepuisPieceJointe(map));
        }
      }
    } catch (_) {}

    return _mapPrestation(response, regle, photosPiecesJointes: photosPj);
  }

  /// Extrait les octets d'une photo locale (data URI base64 sur Web ou fichier local sur Mobile).
  Future<Uint8List?> _lireOctetsLocaux(String? cheminLocal) async {
    if (cheminLocal == null || cheminLocal.isEmpty) return null;
    if (cheminLocal.startsWith('data:')) {
      final idx = cheminLocal.indexOf(',');
      if (idx > 0 && idx < cheminLocal.length - 1) {
        return base64Decode(cheminLocal.substring(idx + 1));
      }
      return null;
    }
    if (!kIsWeb && !cheminLocal.startsWith('http')) {
      final file = File(cheminLocal);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    }
    return null;
  }

  /// Upload une photo dans le bucket Supabase Storage « fichiers » et l'associe au dossier.
  Future<PhotoPrestation> _synchroniserPhotoVersStorage({
    required String entrepriseId,
    required String prestationId,
    required PhotoPrestation photo,
  }) async {
    if (photo.estDistante) {
      return photo.copyWith(prestationId: prestationId, syncStatus: RecordSyncStatus.synced);
    }

    final octets = await _lireOctetsLocaux(photo.cheminLocal);
    if (octets == null || octets.isEmpty) {
      return photo.copyWith(prestationId: prestationId);
    }

    // 1. Tenter le chemin dédié prestations (si migration appliquée)
    final cheminPrestation = '$entrepriseId/prestations/$prestationId/${photo.id}.jpg';
    try {
      await _client.storage.from(bucketFichiers).uploadBinary(
            cheminPrestation,
            octets,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      return photo.copyWith(
        prestationId: prestationId,
        cheminDistant: cheminPrestation,
        syncStatus: RecordSyncStatus.synced,
      );
    } catch (_) {
      // Fallback automatique sur le stockage pieces_jointes / ENGAGEMENT déjà actif en production
    }

    // 2. Fallback sur pieces_jointes (ENGAGEMENT id == prestationId)
    final cheminPj = '$entrepriseId/pj/ENGAGEMENT/$prestationId/${photo.id}.jpg';
    try {
      await _client.storage.from(bucketFichiers).uploadBinary(
            cheminPj,
            octets,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      await _client.from('pieces_jointes').upsert({
        'id': photo.id,
        'entreprise_id': entrepriseId,
        'cible_type': 'ENGAGEMENT',
        'cible_id': prestationId,
        'chemin': cheminPj,
        'nom_fichier': 'photo_${photo.id.substring(0, 8)}.jpg',
        'type_mime': 'image/jpeg',
        'taille': octets.length,
      });
      return photo.copyWith(
        prestationId: prestationId,
        cheminDistant: cheminPj,
        syncStatus: RecordSyncStatus.synced,
      );
    } catch (e) {
      AppLogger.warning('Upload photo prestation reporté (${photo.id}) : $e', tag: 'services_photos');
      return photo.copyWith(prestationId: prestationId);
    }
  }

  Future<List<PhotoPrestation>> _synchroniserPhotosPrestation(Prestation prestation) async {
    if (prestation.photos.isEmpty) return const [];
    final resultat = <PhotoPrestation>[];
    for (final photo in prestation.photos) {
      final synced = await _synchroniserPhotoVersStorage(
        entrepriseId: prestation.entrepriseId,
        prestationId: prestation.id,
        photo: photo,
      );
      resultat.add(synced);
    }
    return resultat;
  }

  /// Synchronise les suppressions éventuelles de photos stockées dans pieces_jointes.
  Future<void> _nettoyerPhotosSupprimees(String prestationId, List<PhotoPrestation> photosActuelles) async {
    try {
      final idsActuels = photosActuelles.map((p) => p.id).toSet();
      final pjs = await _client
          .from('pieces_jointes')
          .select('id, chemin')
          .eq('cible_type', 'ENGAGEMENT')
          .eq('cible_id', prestationId)
          .isFilter('deleted_at', null);
      for (final pj in pjs as List<dynamic>) {
        final id = pj['id'] as String;
        if (!idsActuels.contains(id)) {
          await _client
              .from('pieces_jointes')
              .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
              .eq('id', id);
        }
      }
    } catch (_) {}
  }

  /// Transforme une liste de photos en JSON léger pour la colonne `prestations.photos`
  /// (sans inclure de data URI base64 lourde dès que `cheminDistant` existe).
  static List<Map<String, dynamic>> _photosPourServeur(List<PhotoPrestation> photos) => photos
      .map((p) => {
            'id': p.id,
            'prestation_id': p.prestationId,
            'categorie': p.categorie.code,
            if (p.cheminDistant != null) 'chemin_distant': p.cheminDistant,
            if (p.legende != null) 'legende': p.legende,
            if (p.auteurNom != null) 'auteur_nom': p.auteurNom,
            if (p.createdBy != null) 'created_by': p.createdBy,
            'created_at': p.createdAt.toIso8601String(),
            if (p.taille != null) 'taille': p.taille,
            'sync_status': p.syncStatus.name,
          })
      .toList();

  Future<Prestation> creerPrestation(Prestation prestation) async {
    final payload = <String, dynamic>{
      'id': prestation.id,
      'entreprise_id': prestation.entrepriseId,
      'activite_code': prestation.activiteCode,
      'perimetre_id': prestation.perimetreId,
      'contact_id': prestation.contactId,
      'titre': prestation.titre,
      'description': prestation.description,
      'lignes': prestation.lignes.map((l) => l.toJson()).toList(),
      'remise': prestation.remise,
      'statut': prestation.statut.code,
      'priorite': prestation.priorite.code,
      'debut_prevu': prestation.debutPrevu?.toIso8601String(),
      'echeance_jour': prestation.echeanceJour != null
          ? '${prestation.echeanceJour!.year.toString().padLeft(4, '0')}-${prestation.echeanceJour!.month.toString().padLeft(2, '0')}-${prestation.echeanceJour!.day.toString().padLeft(2, '0')}'
          : null,
      'echeance_heure': prestation.echeanceHeure,
      'livraison_requise': prestation.livraisonRequise,
      'duree_minutes': prestation.dureeMinutes,
      'responsable_id': prestation.responsableId,
      'lieu': prestation.lieu,
      'note': prestation.note,
    };

    final response = await _client.from('prestations').insert(payload).select().single();

    // Une fois la prestation (et son engagement trigger) créée, synchroniser les photos
    final photosSynced = await _synchroniserPhotosPrestation(prestation);
    if (photosSynced.isNotEmpty) {
      try {
        await _client
            .from('prestations')
            .update({'photos': _photosPourServeur(photosSynced)})
            .eq('id', prestation.id);
      } catch (_) {}
    }

    return _mapPrestation(response, 0).copyWith(photos: photosSynced);
  }

  Future<Prestation> modifierPrestation(Prestation prestation) async {
    final photosSynced = await _synchroniserPhotosPrestation(prestation);
    await _nettoyerPhotosSupprimees(prestation.id, photosSynced);

    final payload = <String, dynamic>{
      'perimetre_id': prestation.perimetreId,
      'contact_id': prestation.contactId,
      'titre': prestation.titre,
      'description': prestation.description,
      'lignes': prestation.lignes.map((l) => l.toJson()).toList(),
      'remise': prestation.remise,
      'statut': prestation.statut.code,
      'priorite': prestation.priorite.code,
      'debut_prevu': prestation.debutPrevu?.toIso8601String(),
      'echeance_jour': prestation.echeanceJour != null
          ? '${prestation.echeanceJour!.year.toString().padLeft(4, '0')}-${prestation.echeanceJour!.month.toString().padLeft(2, '0')}-${prestation.echeanceJour!.day.toString().padLeft(2, '0')}'
          : null,
      'echeance_heure': prestation.echeanceHeure,
      'livraison_requise': prestation.livraisonRequise,
      'duree_minutes': prestation.dureeMinutes,
      'responsable_id': prestation.responsableId,
      'lieu': prestation.lieu,
      'note': prestation.note,
      'photos': _photosPourServeur(photosSynced),
    };

    Map<String, dynamic> response;
    try {
      response = await _client.from('prestations').update(payload).eq('id', prestation.id).select().single();
    } catch (e) {
      // Compatibilité si la colonne `photos` n'est pas encore déployée côté DB distante
      if (e.toString().contains('photos')) {
        payload.remove('photos');
        response = await _client.from('prestations').update(payload).eq('id', prestation.id).select().single();
      } else {
        rethrow;
      }
    }
    return _mapPrestation(response, prestation.montantRegle, photosPiecesJointes: photosSynced)
        .copyWith(photos: photosSynced);
  }

  Future<void> changerStatutPrestation(String prestationId, StatutPrestation statut, {String? motif}) async {
    final payload = <String, dynamic>{'statut': statut.code};
    if (statut == StatutPrestation.annulee && motif != null) {
      payload['motif_annulation'] = motif;
    }
    await _client.from('prestations').update(payload).eq('id', prestationId);
  }

  Future<void> reporterPrestation(String prestationId, DateTime echeanceJour, String? echeanceHeure, String motif) async {
    final dateStr =
        '${echeanceJour.year.toString().padLeft(4, '0')}-${echeanceJour.month.toString().padLeft(2, '0')}-${echeanceJour.day.toString().padLeft(2, '0')}';
    await _client.from('prestations').update({
      'echeance_jour': dateStr,
      'echeance_heure': echeanceHeure,
      'motif_report': motif,
    }).eq('id', prestationId);
  }

  Future<void> annulerPrestation(String prestationId, String motif) async {
    await changerStatutPrestation(prestationId, StatutPrestation.annulee, motif: motif);
  }

  Future<List<PrestationHistorique>> chargerHistorique(String prestationId) async {
    final response = await _client
        .from('prestation_historique')
        .select()
        .eq('prestation_id', prestationId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>).map((j) => _mapHistorique(j as Map<String, dynamic>)).toList();
  }

  Stream<List<PrestationHistorique>> observerHistorique(String prestationId) {
    return _client
        .from('prestation_historique')
        .stream(primaryKey: ['id'])
        .eq('prestation_id', prestationId)
        .order('created_at', ascending: false)
        .map((list) => list.map(_mapHistorique).toList());
  }

  // --- DEVIS ---

  Future<List<DevisPrestation>> chargerDevis(String entrepriseId, {String? perimetreId}) async {
    var query = _client.from('devis_prestations').select().eq('entreprise_id', entrepriseId);
    if (perimetreId != null) {
      query = query.eq('perimetre_id', perimetreId);
    }
    final response = await query.order('created_at', ascending: false);
    return (response as List<dynamic>).map((j) => _mapDevis(j as Map<String, dynamic>)).toList();
  }

  Future<DevisPrestation> creerDevis(DevisPrestation devis) async {
    final payload = {
      'id': devis.id,
      'entreprise_id': devis.entrepriseId,
      'numero': devis.numero,
      'perimetre_id': devis.perimetreId,
      'contact_id': devis.contactId,
      'titre': devis.titre,
      'description': devis.description,
      'lignes': devis.lignes.map((l) => l.toJson()).toList(),
      'remise': devis.remise,
      'total': devis.total,
      'statut': devis.statut.code,
      'date_emission': devis.dateEmission.toIso8601String(),
      'date_validite': devis.dateValidite?.toIso8601String(),
      'acompte_demande': devis.acompteDemande,
      'conditions': devis.conditions,
      'notes': devis.notes,
    };

    final response = await _client.from('devis_prestations').insert(payload).select().single();
    return _mapDevis(response);
  }

  Future<DevisPrestation> modifierDevis(DevisPrestation devis) async {
    final payload = {
      'perimetre_id': devis.perimetreId,
      'contact_id': devis.contactId,
      'titre': devis.titre,
      'description': devis.description,
      'lignes': devis.lignes.map((l) => l.toJson()).toList(),
      'remise': devis.remise,
      'total': devis.total,
      'statut': devis.statut.code,
      'date_emission': devis.dateEmission.toIso8601String(),
      'date_validite': devis.dateValidite?.toIso8601String(),
      'acompte_demande': devis.acompteDemande,
      'conditions': devis.conditions,
      'notes': devis.notes,
    };

    final response = await _client.from('devis_prestations').update(payload).eq('id', devis.id).select().single();
    return _mapDevis(response);
  }

  Future<void> changerStatutDevis(String devisId, StatutDevis statut) async {
    await _client.from('devis_prestations').update({'statut': statut.code}).eq('id', devisId);
  }

  static DevisPrestation _mapDevis(Map<String, dynamic> j) {
    final lignesRaw = j['lignes'];
    final lignesList = lignesRaw is List
        ? lignesRaw.map((x) => LignePrestation.fromJson(x as Map<String, dynamic>)).toList()
        : <LignePrestation>[];

    return DevisPrestation(
      id: j['id'] as String,
      entrepriseId: j['entreprise_id'] as String,
      numero: j['numero'] as String? ?? 'DEV',
      perimetreId: j['perimetre_id'] as String?,
      contactId: j['contact_id'] as String?,
      titre: j['titre'] as String? ?? 'Devis',
      description: j['description'] as String?,
      lignes: lignesList,
      remise: (j['remise'] as num?)?.toInt() ?? 0,
      total: (j['total'] as num?)?.toInt() ?? 0,
      statut: StatutDevis.parse(j['statut'] as String?),
      dateEmission: DateTime.tryParse(j['date_emission'] as String? ?? '') ?? DateTime.now(),
      dateValidite: j['date_validite'] != null ? DateTime.tryParse(j['date_validite'] as String) : null,
      acompteDemande: (j['acompte_demande'] as num?)?.toInt(),
      conditions: j['conditions'] as String?,
      notes: j['notes'] as String?,
      prestationCreeeId: j['prestation_creee_id'] as String?,
      version: j['version'] as int?,
    );
  }

  // --- MAPPERS ---

  static ServiceCatalogue _mapServiceCatalogue(Map<String, dynamic> j) => ServiceCatalogue(
        id: j['id'] as String,
        entrepriseId: j['entreprise_id'] as String,
        nom: j['nom'] as String,
        categorie: j['categorie'] as String?,
        description: j['description'] as String?,
        prix: (j['prix'] as num?)?.toInt() ?? 0,
        unite: UniteFacturation.parse(j['unite'] as String?),
        dureeMinutes: (j['duree_minutes'] as num?)?.toInt(),
        icone: j['icone'] as String?,
        estActif: j['est_actif'] as bool? ?? true,
        ordre: (j['ordre'] as num?)?.toInt() ?? 100,
        version: j['version'] as int?,
      );

  static PhotoPrestation _photoDepuisPieceJointe(Map<String, dynamic> j) => PhotoPrestation(
        id: j['id'] as String,
        prestationId: j['cible_id'] as String? ?? '',
        categorie: CategoriePhoto.reception,
        cheminDistant: j['chemin'] as String?,
        auteurNom: j['auteur_nom'] as String?,
        createdBy: j['created_by'] as String?,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
        taille: (j['taille'] as num?)?.toInt(),
        syncStatus: RecordSyncStatus.synced,
      );

  static Prestation _mapPrestation(
    Map<String, dynamic> j,
    int montantRegle, {
    List<PhotoPrestation> photosPiecesJointes = const [],
  }) {
    final lignesRaw = j['lignes'];
    final lignesList = lignesRaw is List
        ? lignesRaw.map((x) => LignePrestation.fromJson(x as Map<String, dynamic>)).toList()
        : <LignePrestation>[];

    // Fusionner les photos de la colonne JSONB `photos` et de `pieces_jointes` sans doublons
    final photosMap = <String, PhotoPrestation>{};
    final photosRaw = j['photos'];
    if (photosRaw is List) {
      for (final x in photosRaw) {
        if (x is Map<String, dynamic>) {
          final p = PhotoPrestation.fromJson(x);
          photosMap[p.id] = p;
        }
      }
    }
    for (final p in photosPiecesJointes) {
      photosMap.putIfAbsent(p.id, () => p);
    }

    final echeanceStr = j['echeance_jour'] as String?;
    DateTime? echeance;
    if (echeanceStr != null && echeanceStr.isNotEmpty) {
      echeance = DateTime.tryParse(echeanceStr);
    }

    final debutStr = j['debut_prevu'] as String?;
    DateTime? debut;
    if (debutStr != null && debutStr.isNotEmpty) {
      debut = DateTime.tryParse(debutStr);
    }

    return Prestation(
      id: j['id'] as String,
      entrepriseId: j['entreprise_id'] as String,
      activiteCode: j['activite_code'] as String? ?? 'SERVICES',
      perimetreId: j['perimetre_id'] as String?,
      contactId: j['contact_id'] as String?,
      titre: j['titre'] as String? ?? 'Prestation',
      description: j['description'] as String?,
      lignes: lignesList,
      remise: (j['remise'] as num?)?.toInt() ?? 0,
      total: (j['total'] as num?)?.toInt() ?? 0,
      statut: StatutPrestation.parse(j['statut'] as String?),
      priorite: PrioritePrestation.parse(j['priorite'] as String?),
      debutPrevu: debut,
      echeanceJour: echeance,
      echeanceHeure: j['echeance_heure'] as String?,
      livraisonRequise: j['livraison_requise'] as bool? ?? false,
      dureeMinutes: (j['duree_minutes'] as num?)?.toInt(),
      responsableId: j['responsable_id'] as String?,
      responsableNom: j['responsable_nom'] as String?,
      lieu: j['lieu'] as String?,
      note: j['note'] as String?,
      motifReport: j['motif_report'] as String?,
      termineLe: j['termine_le'] != null ? DateTime.tryParse(j['termine_le'] as String) : null,
      livreLe: j['livre_le'] != null ? DateTime.tryParse(j['livre_le'] as String) : null,
      motifAnnulation: j['motif_annulation'] as String?,
      annulePar: j['annule_par'] as String?,
      annuleLe: j['annule_le'] != null ? DateTime.tryParse(j['annule_le'] as String) : null,
      createdBy: j['created_by'] as String?,
      montantRegle: montantRegle,
      photos: photosMap.values.toList(),
      version: j['version'] as int?,
    );
  }

  static PrestationHistorique _mapHistorique(Map<String, dynamic> j) => PrestationHistorique(
        id: j['id'] as String,
        entrepriseId: j['entreprise_id'] as String,
        prestationId: j['prestation_id'] as String,
        perimetreId: j['perimetre_id'] as String?,
        type: j['type'] as String? ?? 'STATUT',
        ancien: j['ancien'] as String?,
        nouveau: j['nouveau'] as String?,
        motif: j['motif'] as String?,
        auteurId: j['auteur_id'] as String?,
        auteurNom: j['auteur_nom'] as String?,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}
