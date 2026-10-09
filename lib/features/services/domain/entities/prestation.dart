import '../../../../core/sync/sync_models.dart';
import 'metier_template.dart';

/// Statut du travail d'une prestation.
enum StatutPrestation {
  aFaire('A_FAIRE', 'À faire'),
  planifiee('PLANIFIEE', 'Planifiée'),
  enCours('EN_COURS', 'En cours'),
  terminee('TERMINEE', 'Terminée'),
  livree('LIVREE', 'Livrée'),
  annulee('ANNULEE', 'Annulée');

  const StatutPrestation(this.code, this.libelle);
  final String code;
  final String libelle;

  static StatutPrestation parse(String? code) =>
      values.firstWhere((s) => s.code == code, orElse: () => aFaire);

  bool get estActive => this == aFaire || this == planifiee || this == enCours;
  bool get estFinie => this == terminee || this == livree;
}

/// Priorité déclarée (métier) de la prestation.
enum PrioritePrestation {
  normale('NORMALE', 'Normale'),
  haute('HAUTE', 'Haute');

  const PrioritePrestation(this.code, this.libelle);
  final String code;
  final String libelle;

  static PrioritePrestation parse(String? code) =>
      values.firstWhere((p) => p.code == code, orElse: () => normale);
}

/// Priorité calculée de l'échéance temporelle (moteur intelligent).
enum PrioriteEcheance {
  /// Plus de 48h restantes avant l'échéance.
  faible('Faible / À venir'),

  /// Échéance dans 48h (J-2).
  attention('Attention (J-2)'),

  /// Échéance dans 24h (J-1).
  urgent('Urgent (J-1)'),

  /// Échéance le jour même.
  aujourdhui('À faire aujourd\'hui'),

  /// Date limite dépassée et travail non terminé.
  enRetard('En retard');

  const PrioriteEcheance(this.libelle);
  final String libelle;
}

/// Catégories de photographies pour un dossier de prestation.
enum CategoriePhoto {
  reception('RECEPTION', 'État à la réception', '📸'),
  objet('OBJET', 'Objet ou lot confié', '📦'),
  constat('CONSTAT', 'Détail ou défaut constaté', '🔍'),
  progression('PROGRESSION', 'Progression du travail', '⚙️'),
  resultat('RESULTAT', 'Résultat final / Terminé', '✨'),
  prete('PRETE', 'Objet prêt à remettre', '🏷️'),
  remise('REMISE', 'Preuve de remise au client', '🤝');

  const CategoriePhoto(this.code, this.libelle, this.emoji);
  final String code;
  final String libelle;
  final String emoji;

  static CategoriePhoto parse(String? code) =>
      values.firstWhere((c) => c.code == code, orElse: () => reception);
}

/// Photographie attachée à un dossier de prestation.
class PhotoPrestation {
  const PhotoPrestation({
    required this.id,
    required this.prestationId,
    required this.categorie,
    this.cheminLocal,
    this.cheminDistant,
    this.legende,
    this.auteurNom,
    this.createdBy,
    required this.createdAt,
    this.taille,
    this.syncStatus = RecordSyncStatus.synced,
  });

  final String id;
  final String prestationId;
  final CategoriePhoto categorie;
  final String? cheminLocal;
  final String? cheminDistant;
  final String? legende;
  final String? auteurNom;
  final String? createdBy;
  final DateTime createdAt;
  final int? taille;
  final RecordSyncStatus syncStatus;

  bool get estLocale => cheminLocal != null && cheminLocal!.isNotEmpty;
  bool get estDistante => cheminDistant != null && cheminDistant!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'prestation_id': prestationId,
        'categorie': categorie.code,
        if (cheminLocal != null) 'chemin_local': cheminLocal,
        if (cheminDistant != null) 'chemin_distant': cheminDistant,
        if (legende != null) 'legende': legende,
        if (auteurNom != null) 'auteur_nom': auteurNom,
        if (createdBy != null) 'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        if (taille != null) 'taille': taille,
        'sync_status': syncStatus.name,
      };

  factory PhotoPrestation.fromJson(Map<String, dynamic> json) => PhotoPrestation(
        id: json['id'] as String,
        prestationId: json['prestation_id'] as String? ?? '',
        categorie: CategoriePhoto.parse(json['categorie'] as String?),
        cheminLocal: json['chemin_local'] as String?,
        cheminDistant: json['chemin_distant'] as String?,
        legende: json['legende'] as String?,
        auteurNom: json['auteur_nom'] as String?,
        createdBy: json['created_by'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
        taille: (json['taille'] as num?)?.toInt(),
        syncStatus: RecordSyncStatus.values.firstWhere(
          (s) => s.name == json['sync_status'],
          orElse: () => RecordSyncStatus.synced,
        ),
      );

  PhotoPrestation copyWith({
    CategoriePhoto? categorie,
    String? cheminLocal,
    String? cheminDistant,
    String? legende,
    String? auteurNom,
    RecordSyncStatus? syncStatus,
  }) =>
      PhotoPrestation(
        id: id,
        prestationId: prestationId,
        categorie: categorie ?? this.categorie,
        cheminLocal: cheminLocal ?? this.cheminLocal,
        cheminDistant: cheminDistant ?? this.cheminDistant,
        legende: legende ?? this.legende,
        auteurNom: auteurNom ?? this.auteurNom,
        createdBy: createdBy,
        createdAt: createdAt,
        taille: taille,
        syncStatus: syncStatus ?? this.syncStatus,
      );
}

/// Ligne facturée dans une prestation ou un ordre de travail (service ou pièce/consommable).
class LignePrestation {
  const LignePrestation({
    required this.id,
    this.serviceId,
    this.produitId,
    required this.libelle,
    this.quantite = 1.0,
    required this.prixUnitaire,
  });

  final String id;
  final String? serviceId;
  final String? produitId;
  final String libelle;
  final double quantite;
  final int prixUnitaire;

  bool get estConsommable => produitId != null;
  int get totalLigne => (quantite * prixUnitaire).round();

  Map<String, dynamic> toJson() => {
        'id': id,
        if (serviceId != null) 'service_id': serviceId,
        if (produitId != null) 'produit_id': produitId,
        'libelle': libelle,
        'quantite': quantite,
        'prix_unitaire': prixUnitaire,
      };

  factory LignePrestation.fromJson(Map<String, dynamic> json) => LignePrestation(
        id: json['id'] as String,
        serviceId: json['service_id'] as String?,
        produitId: json['produit_id'] as String?,
        libelle: json['libelle'] as String? ?? 'Prestation',
        quantite: (json['quantite'] as num?)?.toDouble() ?? 1.0,
        prixUnitaire: (json['prix_unitaire'] as num?)?.toInt() ?? 0,
      );
}

/// Ordre de travail / Prestation de services configurable multi-métiers.
class Prestation {
  const Prestation({
    required this.id,
    required this.entrepriseId,
    this.activiteCode = 'SERVICES',
    this.metierCode = MetierCode.generique,
    this.champsMetier = const {},
    this.perimetreId,
    this.contactId,
    required this.titre,
    this.description,
    required this.lignes,
    this.remise = 0,
    required this.total,
    this.statut = StatutPrestation.aFaire,
    this.priorite = PrioritePrestation.normale,
    this.debutPrevu,
    this.echeanceJour,
    this.echeanceHeure,
    this.dureeEstimee,
    this.uniteDuree = UniteDuree.jours,
    this.dateRemisePrevue,
    this.dateTerminaisonReelle,
    this.dateRemiseReelle,
    this.livraisonRequise = false,
    this.dureeMinutes,
    this.responsableId,
    this.responsableNom,
    this.lieu,
    this.note,
    this.motifReport,
    this.termineLe,
    this.livreLe,
    this.motifAnnulation,
    this.annulePar,
    this.annuleLe,
    this.createdBy,
    this.montantRegle = 0,
    this.photos = const [],
    this.version,
    this.syncStatus = RecordSyncStatus.synced,
  });

  final String id;
  final String entrepriseId;
  final String activiteCode;
  final MetierCode metierCode;
  final Map<String, dynamic> champsMetier;
  final String? perimetreId;
  final String? contactId;
  final String titre;
  final String? description;
  final List<LignePrestation> lignes;
  final int remise;
  final int total;
  final StatutPrestation statut;
  final PrioritePrestation priorite;
  final DateTime? debutPrevu;
  final DateTime? echeanceJour;
  final String? echeanceHeure;
  final int? dureeEstimee;
  final UniteDuree uniteDuree;
  final DateTime? dateRemisePrevue;
  final DateTime? dateTerminaisonReelle;
  final DateTime? dateRemiseReelle;
  final bool livraisonRequise;
  final int? dureeMinutes;
  final String? responsableId;
  final String? responsableNom;
  final String? lieu;
  final String? note;
  final String? motifReport;
  final DateTime? termineLe;
  final DateTime? livreLe;
  final String? motifAnnulation;
  final String? annulePar;
  final DateTime? annuleLe;
  final String? createdBy;

  /// Montant réglé (issu de l'engagement financier associé).
  final int montantRegle;

  /// Photos associées au dossier.
  final List<PhotoPrestation> photos;

  final int? version;
  final RecordSyncStatus syncStatus;

  int get soldeRestant => (total - montantRegle).clamp(0, total);
  bool get estPayeIntegralement => total > 0 && montantRegle >= total;
  bool get aAcomptePartiel => montantRegle > 0 && montantRegle < total;
  bool get estNonPaye => total > 0 && montantRegle == 0;

  DateTime? get dateEcheanceComplete {
    if (echeanceJour == null) return null;
    if (echeanceHeure == null || echeanceHeure!.isEmpty) {
      return DateTime(echeanceJour!.year, echeanceJour!.month, echeanceJour!.day, 23, 59, 59);
    }
    final parties = echeanceHeure!.split(':');
    final h = int.tryParse(parties.first) ?? 0;
    final m = parties.length > 1 ? int.tryParse(parties[1]) ?? 0 : 0;
    return DateTime(echeanceJour!.year, echeanceJour!.month, echeanceJour!.day, h, m);
  }

  Prestation copyWith({
    MetierCode? metierCode,
    Map<String, dynamic>? champsMetier,
    String? perimetreId,
    String? contactId,
    String? titre,
    String? description,
    List<LignePrestation>? lignes,
    int? remise,
    int? total,
    StatutPrestation? statut,
    PrioritePrestation? priorite,
    DateTime? debutPrevu,
    DateTime? echeanceJour,
    String? echeanceHeure,
    int? dureeEstimee,
    UniteDuree? uniteDuree,
    DateTime? dateRemisePrevue,
    DateTime? dateTerminaisonReelle,
    DateTime? dateRemiseReelle,
    bool? livraisonRequise,
    int? dureeMinutes,
    String? responsableId,
    String? responsableNom,
    String? lieu,
    String? note,
    String? motifReport,
    DateTime? termineLe,
    DateTime? livreLe,
    String? motifAnnulation,
    int? montantRegle,
    List<PhotoPrestation>? photos,
    RecordSyncStatus? syncStatus,
  }) =>
      Prestation(
        id: id,
        entrepriseId: entrepriseId,
        activiteCode: activiteCode,
        metierCode: metierCode ?? this.metierCode,
        champsMetier: champsMetier ?? this.champsMetier,
        perimetreId: perimetreId ?? this.perimetreId,
        contactId: contactId ?? this.contactId,
        titre: titre ?? this.titre,
        description: description ?? this.description,
        lignes: lignes ?? this.lignes,
        remise: remise ?? this.remise,
        total: total ?? this.total,
        statut: statut ?? this.statut,
        priorite: priorite ?? this.priorite,
        debutPrevu: debutPrevu ?? this.debutPrevu,
        echeanceJour: echeanceJour ?? this.echeanceJour,
        echeanceHeure: echeanceHeure ?? this.echeanceHeure,
        dureeEstimee: dureeEstimee ?? this.dureeEstimee,
        uniteDuree: uniteDuree ?? this.uniteDuree,
        dateRemisePrevue: dateRemisePrevue ?? this.dateRemisePrevue,
        dateTerminaisonReelle: dateTerminaisonReelle ?? this.dateTerminaisonReelle,
        dateRemiseReelle: dateRemiseReelle ?? this.dateRemiseReelle,
        livraisonRequise: livraisonRequise ?? this.livraisonRequise,
        dureeMinutes: dureeMinutes ?? this.dureeMinutes,
        responsableId: responsableId ?? this.responsableId,
        responsableNom: responsableNom ?? this.responsableNom,
        lieu: lieu ?? this.lieu,
        note: note ?? this.note,
        motifReport: motifReport ?? this.motifReport,
        termineLe: termineLe ?? this.termineLe,
        livreLe: livreLe ?? this.livreLe,
        motifAnnulation: motifAnnulation ?? this.motifAnnulation,
        annulePar: annulePar,
        annuleLe: annuleLe,
        createdBy: createdBy,
        montantRegle: montantRegle ?? this.montantRegle,
        photos: photos ?? this.photos,
        version: version,
        syncStatus: syncStatus ?? this.syncStatus,
      );
}

/// Entrée du journal d'historique d'une prestation.
class PrestationHistorique {
  const PrestationHistorique({
    required this.id,
    required this.entrepriseId,
    required this.prestationId,
    this.perimetreId,
    required this.type,
    this.ancien,
    this.nouveau,
    this.motif,
    this.auteurId,
    this.auteurNom,
    required this.createdAt,
  });

  final String id;
  final String entrepriseId;
  final String prestationId;
  final String? perimetreId;
  final String type; // CREATION, STATUT, ECHEANCE, RESPONSABLE, PHOTO_AJOUT, PHOTO_SUPPRESSION, DATE_REMISE
  final String? ancien;
  final String? nouveau;
  final String? motif;
  final String? auteurId;
  final String? auteurNom;
  final DateTime createdAt;
}

/// Statut d'un devis de services.
enum StatutDevis {
  brouillon('BROUILLON', 'Brouillon'),
  envoye('ENVOYE', 'Envoyé'),
  accepte('ACCEPTE', 'Accepté'),
  refuse('REFUSE', 'Refusé'),
  expire('EXPIRE', 'Expiré'),
  converti('CONVERTI', 'Converti en prestation');

  const StatutDevis(this.code, this.libelle);
  final String code;
  final String libelle;

  static StatutDevis parse(String? code) =>
      values.firstWhere((s) => s.code == code, orElse: () => brouillon);
}

/// Devis de services / Proposition chiffrée.
class DevisPrestation {
  const DevisPrestation({
    required this.id,
    required this.entrepriseId,
    required this.numero,
    this.perimetreId,
    this.contactId,
    this.metierCode = MetierCode.generique,
    this.champsMetier = const {},
    required this.titre,
    this.description,
    required this.lignes,
    this.remise = 0,
    required this.total,
    this.statut = StatutDevis.brouillon,
    required this.dateEmission,
    this.dateValidite,
    this.acompteDemande,
    this.conditions,
    this.notes,
    this.prestationIdConvertie,
    String? prestationCreeeId,
    this.photos = const [],
    this.createdBy,
    this.version,
    this.syncStatus = RecordSyncStatus.synced,
  }) : _prestationCreeeId = prestationCreeeId;

  final String id;
  final String entrepriseId;
  final String numero;
  final String? perimetreId;
  final String? contactId;
  final MetierCode metierCode;
  final Map<String, dynamic> champsMetier;
  final String titre;
  final String? description;
  final List<LignePrestation> lignes;
  final int remise;
  final int total;
  final StatutDevis statut;
  final DateTime dateEmission;
  final DateTime? dateValidite;
  final int? acompteDemande;
  final String? conditions;
  final String? notes;
  final String? prestationIdConvertie;
  final String? _prestationCreeeId;
  String? get prestationCreeeId => prestationIdConvertie ?? _prestationCreeeId;
  final List<PhotoPrestation> photos;
  final String? createdBy;
  final int? version;
  final RecordSyncStatus syncStatus;

  DevisPrestation copyWith({
    String? perimetreId,
    String? contactId,
    MetierCode? metierCode,
    Map<String, dynamic>? champsMetier,
    String? titre,
    String? description,
    List<LignePrestation>? lignes,
    int? remise,
    int? total,
    StatutDevis? statut,
    DateTime? dateEmission,
    DateTime? dateValidite,
    int? acompteDemande,
    String? conditions,
    String? notes,
    String? prestationIdConvertie,
    List<PhotoPrestation>? photos,
    RecordSyncStatus? syncStatus,
  }) =>
      DevisPrestation(
        id: id,
        entrepriseId: entrepriseId,
        numero: numero,
        perimetreId: perimetreId ?? this.perimetreId,
        contactId: contactId ?? this.contactId,
        metierCode: metierCode ?? this.metierCode,
        champsMetier: champsMetier ?? this.champsMetier,
        titre: titre ?? this.titre,
        description: description ?? this.description,
        lignes: lignes ?? this.lignes,
        remise: remise ?? this.remise,
        total: total ?? this.total,
        statut: statut ?? this.statut,
        dateEmission: dateEmission ?? this.dateEmission,
        dateValidite: dateValidite ?? this.dateValidite,
        acompteDemande: acompteDemande ?? this.acompteDemande,
        conditions: conditions ?? this.conditions,
        notes: notes ?? this.notes,
        prestationIdConvertie: prestationIdConvertie ?? this.prestationIdConvertie,
        photos: photos ?? this.photos,
        createdBy: createdBy,
        version: version,
        syncStatus: syncStatus ?? this.syncStatus,
      );
}
