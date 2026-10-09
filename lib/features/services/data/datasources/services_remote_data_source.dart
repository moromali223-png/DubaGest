import 'package:supabase_flutter/supabase_flutter.dart';

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

    // Récupérer les montants réglés des engagements associés
    final prestationIds = (response as List<dynamic>).map((p) => p['id'] as String).toList();
    final montantsRegles = <String, int>{};
    if (prestationIds.isNotEmpty) {
      final engagements = await _client
          .from('engagements')
          .select('id, montant_regle')
          .inFilter('id', prestationIds);
      for (final e in engagements as List<dynamic>) {
        montantsRegles[e['id'] as String] = (e['montant_regle'] as num?)?.toInt() ?? 0;
      }
    }

    return response
        .map((j) => _mapPrestation(j, montantsRegles[j['id'] as String] ?? 0))
        .toList();
  }

  Future<Prestation?> getPrestation(String prestationId) async {
    final response = await _client.from('prestations').select().eq('id', prestationId).maybeSingle();
    if (response == null) return null;

    final engagement = await _client.from('engagements').select('montant_regle').eq('id', prestationId).maybeSingle();
    final regle = (engagement?['montant_regle'] as num?)?.toInt() ?? 0;

    return _mapPrestation(response, regle);
  }

  Future<Prestation> creerPrestation(Prestation prestation) async {
    final payload = {
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
    return _mapPrestation(response, 0);
  }

  Future<Prestation> modifierPrestation(Prestation prestation) async {
    final payload = {
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

    final response = await _client.from('prestations').update(payload).eq('id', prestation.id).select().single();
    return _mapPrestation(response, prestation.montantRegle);
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

  static Prestation _mapPrestation(Map<String, dynamic> j, int montantRegle) {
    final lignesRaw = j['lignes'];
    final lignesList = lignesRaw is List
        ? lignesRaw.map((x) => LignePrestation.fromJson(x as Map<String, dynamic>)).toList()
        : <LignePrestation>[];

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
