import '../../domain/entities/metier_template.dart';
import '../../domain/entities/prestation.dart';
import '../../domain/entities/service_catalogue.dart';

/// Mappeur JSON pour les entités du module Services (stockage local et synchronisation).
abstract final class ServicesMappers {
  // --- CATALOGUE ---
  static Map<String, dynamic> serviceToJson(ServiceCatalogue s) => {
        'id': s.id,
        'entreprise_id': s.entrepriseId,
        'nom': s.nom,
        'categorie': s.categorie,
        'description': s.description,
        'prix': s.prix,
        'unite': s.unite.code,
        'duree_minutes': s.dureeMinutes,
        'icone': s.icone,
        'est_actif': s.estActif,
        'ordre': s.ordre,
      };

  static ServiceCatalogue serviceFromJson(Map<String, dynamic> json) => ServiceCatalogue(
        id: json['id'] as String,
        entrepriseId: json['entreprise_id'] as String,
        nom: json['nom'] as String,
        categorie: json['categorie'] as String?,
        description: json['description'] as String?,
        prix: (json['prix'] as num?)?.toInt() ?? 0,
        unite: UniteFacturation.parse(json['unite'] as String?),
        dureeMinutes: (json['duree_minutes'] as num?)?.toInt(),
        icone: json['icone'] as String?,
        estActif: json['est_actif'] as bool? ?? true,
        ordre: (json['ordre'] as num?)?.toInt() ?? 100,
      );

  // --- LIGNES DE PRESTATION ---
  static Map<String, dynamic> ligneToJson(LignePrestation l) => {
        'id': l.id,
        if (l.serviceId != null) 'service_id': l.serviceId,
        if (l.produitId != null) 'produit_id': l.produitId,
        'libelle': l.libelle,
        'quantite': l.quantite,
        'prix_unitaire': l.prixUnitaire,
      };

  static LignePrestation ligneFromJson(Map<String, dynamic> json) => LignePrestation(
        id: json['id'] as String,
        serviceId: json['service_id'] as String?,
        produitId: json['produit_id'] as String?,
        libelle: json['libelle'] as String? ?? 'Prestation',
        quantite: (json['quantite'] as num?)?.toDouble() ?? 1.0,
        prixUnitaire: (json['prix_unitaire'] as num?)?.toInt() ?? 0,
      );

  // --- PHOTOS DE PRESTATION ---
  static Map<String, dynamic> photoToJson(PhotoPrestation p) => p.toJson();

  static PhotoPrestation photoFromJson(Map<String, dynamic> json) => PhotoPrestation.fromJson(json);

  // --- PRESTATIONS ---
  static Map<String, dynamic> prestationToJson(Prestation p) => {
        'id': p.id,
        'entreprise_id': p.entrepriseId,
        'activite_code': p.activiteCode,
        'metier_code': p.metierCode.code,
        'champs_metier': p.champsMetier,
        'perimetre_id': p.perimetreId,
        'contact_id': p.contactId,
        'titre': p.titre,
        'description': p.description,
        'lignes': p.lignes.map(ligneToJson).toList(),
        'remise': p.remise,
        'total': p.total,
        'statut': p.statut.code,
        'priorite': p.priorite.code,
        'debut_prevu': p.debutPrevu?.toIso8601String(),
        'echeance_jour': p.echeanceJour != null
            ? '${p.echeanceJour!.year}-${p.echeanceJour!.month.toString().padLeft(2, '0')}-${p.echeanceJour!.day.toString().padLeft(2, '0')}'
            : null,
        'echeance_heure': p.echeanceHeure,
        'duree_estimee': p.dureeEstimee,
        'unite_duree': p.uniteDuree.code,
        'date_remise_prevue': p.dateRemisePrevue?.toIso8601String(),
        'date_terminaison_reelle': p.dateTerminaisonReelle?.toIso8601String(),
        'date_remise_reelle': p.dateRemiseReelle?.toIso8601String(),
        'livraison_requise': p.livraisonRequise,
        'duree_minutes': p.dureeMinutes,
        'responsable_id': p.responsableId,
        'responsable_nom': p.responsableNom,
        'lieu': p.lieu,
        'note': p.note,
        'motif_report': p.motifReport,
        'termine_le': p.termineLe?.toIso8601String(),
        'livre_le': p.livreLe?.toIso8601String(),
        'motif_annulation': p.motifAnnulation,
        'annule_par': p.annulePar,
        'annule_le': p.annuleLe?.toIso8601String(),
        'created_by': p.createdBy,
        'montant_regle': p.montantRegle,
        'photos': p.photos.map(photoToJson).toList(),
      };

  static Prestation prestationFromJson(Map<String, dynamic> json) {
    DateTime? echeanceJ;
    if (json['echeance_jour'] != null) {
      echeanceJ = DateTime.tryParse(json['echeance_jour'] as String);
    }
    return Prestation(
      id: json['id'] as String,
      entrepriseId: json['entreprise_id'] as String,
      activiteCode: json['activite_code'] as String? ?? 'SERVICES',
      metierCode: MetierCode.parse(json['metier_code'] as String?),
      champsMetier: json['champs_metier'] is Map
          ? Map<String, dynamic>.from(json['champs_metier'] as Map)
          : const {},
      perimetreId: json['perimetre_id'] as String?,
      contactId: json['contact_id'] as String?,
      titre: json['titre'] as String? ?? 'Prestation',
      description: json['description'] as String?,
      lignes: (json['lignes'] as List<dynamic>?)
              ?.map((e) => ligneFromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      remise: (json['remise'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      statut: StatutPrestation.parse(json['statut'] as String?),
      priorite: PrioritePrestation.parse(json['priorite'] as String?),
      debutPrevu: json['debut_prevu'] != null ? DateTime.tryParse(json['debut_prevu'] as String) : null,
      echeanceJour: echeanceJ,
      echeanceHeure: json['echeance_heure'] as String?,
      dureeEstimee: (json['duree_estimee'] as num?)?.toInt(),
      uniteDuree: UniteDuree.parse(json['unite_duree'] as String?),
      dateRemisePrevue: json['date_remise_prevue'] != null ? DateTime.tryParse(json['date_remise_prevue'] as String) : null,
      dateTerminaisonReelle: json['date_terminaison_reelle'] != null ? DateTime.tryParse(json['date_terminaison_reelle'] as String) : null,
      dateRemiseReelle: json['date_remise_reelle'] != null ? DateTime.tryParse(json['date_remise_reelle'] as String) : null,
      livraisonRequise: json['livraison_requise'] as bool? ?? false,
      dureeMinutes: (json['duree_minutes'] as num?)?.toInt(),
      responsableId: json['responsable_id'] as String?,
      responsableNom: json['responsable_nom'] as String?,
      lieu: json['lieu'] as String?,
      note: json['note'] as String?,
      motifReport: json['motif_report'] as String?,
      termineLe: json['termine_le'] != null ? DateTime.tryParse(json['termine_le'] as String) : null,
      livreLe: json['livre_le'] != null ? DateTime.tryParse(json['livre_le'] as String) : null,
      motifAnnulation: json['motif_annulation'] as String?,
      annulePar: json['annule_par'] as String?,
      annuleLe: json['annule_le'] != null ? DateTime.tryParse(json['annule_le'] as String) : null,
      createdBy: json['created_by'] as String?,
      montantRegle: (json['montant_regle'] as num?)?.toInt() ?? 0,
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => photoFromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  // --- DEVIS ---
  static Map<String, dynamic> devisToJson(DevisPrestation d) => {
        'id': d.id,
        'entreprise_id': d.entrepriseId,
        'numero': d.numero,
        'perimetre_id': d.perimetreId,
        'contact_id': d.contactId,
        'metier_code': d.metierCode.code,
        'champs_metier': d.champsMetier,
        'titre': d.titre,
        'description': d.description,
        'lignes': d.lignes.map(ligneToJson).toList(),
        'remise': d.remise,
        'total': d.total,
        'statut': d.statut.code,
        'date_emission': d.dateEmission.toIso8601String(),
        'date_validite': d.dateValidite?.toIso8601String(),
        'conditions': d.conditions,
        'prestation_id_convertie': d.prestationIdConvertie,
        'photos': d.photos.map(photoToJson).toList(),
        'created_by': d.createdBy,
      };

  static DevisPrestation devisFromJson(Map<String, dynamic> json) => DevisPrestation(
        id: json['id'] as String,
        entrepriseId: json['entreprise_id'] as String,
        numero: json['numero'] as String? ?? 'DEV',
        perimetreId: json['perimetre_id'] as String?,
        contactId: json['contact_id'] as String?,
        metierCode: MetierCode.parse(json['metier_code'] as String?),
        champsMetier: json['champs_metier'] is Map
            ? Map<String, dynamic>.from(json['champs_metier'] as Map)
            : const {},
        titre: json['titre'] as String? ?? 'Devis',
        description: json['description'] as String?,
        lignes: (json['lignes'] as List<dynamic>?)
                ?.map((e) => ligneFromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        remise: (json['remise'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        statut: StatutDevis.parse(json['statut'] as String?),
        dateEmission: DateTime.tryParse(json['date_emission'] as String? ?? '') ?? DateTime.now(),
        dateValidite: json['date_validite'] != null ? DateTime.tryParse(json['date_validite'] as String) : null,
        conditions: json['conditions'] as String?,
        prestationIdConvertie: json['prestation_id_convertie'] as String?,
        photos: (json['photos'] as List<dynamic>?)
                ?.map((e) => photoFromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        createdBy: json['created_by'] as String?,
      );

  // --- HISTORIQUE ---
  static Map<String, dynamic> historiqueToJson(PrestationHistorique h) => {
        'id': h.id,
        'entreprise_id': h.entrepriseId,
        'prestation_id': h.prestationId,
        'perimetre_id': h.perimetreId,
        'type': h.type,
        'ancien': h.ancien,
        'nouveau': h.nouveau,
        'motif': h.motif,
        'auteur_id': h.auteurId,
        'auteur_nom': h.auteurNom,
        'created_at': h.createdAt.toIso8601String(),
      };

  static PrestationHistorique historiqueFromJson(Map<String, dynamic> json) => PrestationHistorique(
        id: json['id'] as String,
        entrepriseId: json['entreprise_id'] as String,
        prestationId: json['prestation_id'] as String,
        perimetreId: json['perimetre_id'] as String?,
        type: json['type'] as String? ?? 'STATUT',
        ancien: json['ancien'] as String?,
        nouveau: json['nouveau'] as String?,
        motif: json['motif'] as String?,
        auteurId: json['auteur_id'] as String?,
        auteurNom: json['auteur_nom'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}
