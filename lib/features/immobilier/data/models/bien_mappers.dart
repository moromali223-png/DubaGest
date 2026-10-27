import 'dart:convert';

import '../../../../core/sync/sync_models.dart';
import '../../domain/entities/bien_immobilier.dart';

abstract final class BienMappers {
  static BienImmobilier bienFromJson(Map<String, dynamic> json) {
    List<String> photos = const [];
    final photosRaw = json['photos'];
    if (photosRaw is List) {
      photos = photosRaw.map((e) => e.toString()).toList();
    } else if (photosRaw is String && photosRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(photosRaw);
        if (decoded is List) {
          photos = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    CaracteristiquesBien carac = const CaracteristiquesBien();
    final caracRaw = json['caracteristiques'];
    if (caracRaw is Map<String, dynamic>) {
      carac = CaracteristiquesBien.fromJson(caracRaw);
    } else if (caracRaw is String && caracRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(caracRaw);
        if (decoded is Map<String, dynamic>) {
          carac = CaracteristiquesBien.fromJson(decoded);
        }
      } catch (_) {}
    }

    DateTime? creeLe;
    if (json['created_at'] != null) {
      creeLe = DateTime.tryParse(json['created_at'].toString())?.toLocal();
    }
    DateTime? misAJourLe;
    if (json['updated_at'] != null) {
      misAJourLe = DateTime.tryParse(json['updated_at'].toString())?.toLocal();
    }

    return BienImmobilier(
      id: json['id'] as String,
      entrepriseId: json['entreprise_id'] as String,
      reference: json['reference'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      type: TypeBien.parse(json['type'] as String?),
      proprietaireId: json['proprietaire_id'] as String? ?? '',
      statut: StatutBien.parse(json['statut'] as String?),
      loyerReference: (json['loyer_reference'] as num?)?.toInt() ?? 0,
      periodicite: PeriodiciteLoyer.parse(json['periodicite'] as String?),
      depotGarantiePrevu: (json['depot_garantie_prevu'] as num?)?.toInt() ?? 0,
      description: json['description'] as String?,
      adresse: json['adresse'] as String?,
      ville: json['ville'] as String?,
      quartier: json['quartier'] as String?,
      complementAdresse: json['complement_adresse'] as String?,
      photos: photos,
      caracteristiques: carac,
      notes: json['notes'] as String?,
      creeLe: creeLe,
      misAJourLe: misAJourLe,
      version: json['version'] as int?,
      syncStatus: RecordSyncStatus.synced,
    );
  }

  static Map<String, dynamic> bienToJson(BienImmobilier bien) => {
        'id': bien.id,
        'entreprise_id': bien.entrepriseId,
        'reference': bien.reference,
        'nom': bien.nom,
        'type': bien.type.code,
        'proprietaire_id': bien.proprietaireId,
        'statut': bien.statut.code,
        'loyer_reference': bien.loyerReference,
        'periodicite': bien.periodicite.code,
        'depot_garantie_prevu': bien.depotGarantiePrevu,
        'description': bien.description,
        'adresse': bien.adresse,
        'ville': bien.ville,
        'quartier': bien.quartier,
        'complement_adresse': bien.complementAdresse,
        'photos': bien.photos,
        'caracteristiques': bien.caracteristiques.toJson(),
        'notes': bien.notes,
        if (bien.creeLe != null) 'created_at': bien.creeLe!.toIso8601String(),
        if (bien.misAJourLe != null) 'updated_at': bien.misAJourLe!.toIso8601String(),
        if (bien.version != null) 'version': bien.version,
      };
}
