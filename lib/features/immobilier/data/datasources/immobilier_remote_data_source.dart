import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/bien_immobilier.dart';
import '../../domain/entities/contrat_bail.dart';
import '../../domain/entities/echeance_loyer.dart';
import '../../domain/entities/locataire_immobilier.dart';
import '../../domain/entities/location_immobilier.dart';
import '../models/bien_mappers.dart';

class ImmobilierRemoteDataSource {
  const ImmobilierRemoteDataSource(this._client);
  final SupabaseClient _client;

  Future<List<BienImmobilier>> chargerBiens(String entrepriseId) async {
    final response = await _client
        .from('immobilier_biens')
        .select()
        .eq('entreprise_id', entrepriseId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((j) => BienMappers.bienFromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<BienImmobilier> sauvegarderBien(BienImmobilier bien) async {
    final payload = BienMappers.bienToJson(bien);
    final response = await _client
        .from('immobilier_biens')
        .upsert(payload)
        .select()
        .single();

    return BienMappers.bienFromJson(response);
  }

  Future<void> changerStatutBien(String id, StatutBien nouveauStatut) async {
    await _client
        .from('immobilier_biens')
        .update({'statut': nouveauStatut.code})
        .eq('id', id);
  }

  Future<void> archiverBien(String id) async {
    await _client
        .from('immobilier_biens')
        .update({'statut': StatutBien.archive.code})
        .eq('id', id);
  }

  // --- LOCATAIRES (PROFILS) ---

  Future<List<ProfilLocataire>> chargerProfilsLocataires(String entrepriseId) async {
    final response = await _client
        .from('immobilier_locataires_profils')
        .select()
        .eq('entreprise_id', entrepriseId);

    return (response as List<dynamic>)
        .map((j) => ProfilLocataire.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<ProfilLocataire?> chargerProfilLocataire(String contactId) async {
    final response = await _client
        .from('immobilier_locataires_profils')
        .select()
        .eq('contact_id', contactId)
        .maybeSingle();

    if (response == null) return null;
    return ProfilLocataire.fromJson(response);
  }

  Future<ProfilLocataire> sauvegarderProfilLocataire(ProfilLocataire profil) async {
    final payload = profil.toJson();
    final response = await _client
        .from('immobilier_locataires_profils')
        .upsert(payload)
        .select()
        .single();

    return ProfilLocataire.fromJson(response);
  }

  // --- LOCATIONS ---

  Future<List<LocationImmobilier>> chargerLocations(String entrepriseId) async {
    final response = await _client
        .from('immobilier_locations')
        .select()
        .eq('entreprise_id', entrepriseId)
        .order('date_debut', ascending: false);

    return (response as List<dynamic>)
        .map((j) => LocationImmobilier.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<LocationImmobilier> sauvegarderLocation(LocationImmobilier location) async {
    final payload = location.toJson();
    final response = await _client
        .from('immobilier_locations')
        .upsert(payload)
        .select()
        .single();

    return LocationImmobilier.fromJson(response);
  }

  Future<void> cloturerLocation(
    String id, {
    required DateTime dateSortie,
    required String motif,
  }) async {
    await _client.from('immobilier_locations').update({
      'statut': StatutLocation.terminee.code,
      'date_fin_reelle': dateSortie.toIso8601String().split('T').first,
      'motif_cloture': motif,
      'etat_lieux_sortie': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // --- CONTRATS DE BAIL ---

  Future<List<ContratBail>> chargerContrats(String entrepriseId) async {
    final response = await _client
        .from('immobilier_contrats')
        .select()
        .eq('entreprise_id', entrepriseId)
        .order('date_debut', ascending: false);

    return (response as List<dynamic>)
        .map((j) => ContratBail.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<ContratBail> sauvegarderContrat(ContratBail contrat) async {
    final payload = contrat.toJson();
    final response = await _client
        .from('immobilier_contrats')
        .upsert(payload)
        .select()
        .single();

    return ContratBail.fromJson(response);
  }

  Future<void> changerStatutContrat(String id, StatutContratBail nouveauStatut) async {
    await _client.from('immobilier_contrats').update({
      'statut': nouveauStatut.code,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> signerContrat(String id, {bool bailleur = false, bool locataire = false}) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (bailleur) updates['signe_par_bailleur'] = true;
    if (locataire) updates['signe_par_locataire'] = true;
    updates['date_signature'] = DateTime.now().toIso8601String().split('T').first;

    await _client.from('immobilier_contrats').update(updates).eq('id', id);
  }

  // --- ÉCHÉANCES DE LOYERS ---

  Future<List<EcheanceLoyer>> chargerEcheancesLoyers(String entrepriseId) async {
    final response = await _client
        .from('immobilier_echeances_loyers')
        .select()
        .eq('entreprise_id', entrepriseId)
        .order('periode_annee', ascending: false)
        .order('periode_mois', ascending: false);

    return (response as List<dynamic>)
        .map((j) => EcheanceLoyer.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<EcheanceLoyer> sauvegarderEcheanceLoyer(EcheanceLoyer echeance) async {
    final payload = echeance.toJson();
    final response = await _client
        .from('immobilier_echeances_loyers')
        .upsert(payload)
        .select()
        .single();

    return EcheanceLoyer.fromJson(response);
  }

  Future<List<EcheanceLoyer>> sauvegarderEcheancesLoyers(List<EcheanceLoyer> echeances) async {
    if (echeances.isEmpty) return const [];
    final payloads = echeances.map((e) => e.toJson()).toList();
    final response = await _client
        .from('immobilier_echeances_loyers')
        .upsert(payloads)
        .select();

    return (response as List<dynamic>)
        .map((j) => EcheanceLoyer.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> mettreAJourStatutEcheance({
    required String id,
    required StatutEcheanceLoyer statut,
    required int montantRegle,
    DateTime? datePaiement,
    String? quittanceDocumentId,
    List<String>? recuDocumentIds,
  }) async {
    final updates = <String, dynamic>{
      'statut': statut.code,
      'montant_regle': montantRegle,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (datePaiement != null) {
      updates['derniere_date_paiement'] = datePaiement.toIso8601String();
    }
    if (quittanceDocumentId != null) {
      updates['quittance_document_id'] = quittanceDocumentId;
    }
    if (recuDocumentIds != null) {
      updates['recu_document_ids'] = recuDocumentIds;
    }

    await _client.from('immobilier_echeances_loyers').update(updates).eq('id', id);
  }
}
