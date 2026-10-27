enum TypeAnomalieDeclassement {
  activitesExcedentaires('ACTIVITES_EXCEDENTAIRES'),
  activiteNonAutorisee('ACTIVITE_NON_AUTORISEE'),
  utilisateursExcedentaires('UTILISATEURS_EXCEDENTAIRES'),
  roleLimite('ROLE_LIMITE'),
  roleNonAutorise('ROLE_NON_AUTORISE'),
  perimetresExcedentaires('PERIMETRES_EXCEDENTAIRES'),
  dernierAdministrateur('DERNIER_ADMINISTRATEUR'),
  autre('AUTRE');

  const TypeAnomalieDeclassement(this.code);
  final String code;

  static TypeAnomalieDeclassement fromCode(String code) {
    return values.firstWhere(
      (v) => v.code == code,
      orElse: () => TypeAnomalieDeclassement.autre,
    );
  }
}

class AnomalieDeclassement {
  const AnomalieDeclassement({
    required this.type,
    required this.message,
    this.activiteCode,
    this.roleCode,
    this.actuel = 0,
    this.max = 0,
    this.exces = 0,
  });

  final TypeAnomalieDeclassement type;
  final String message;
  final String? activiteCode;
  final String? roleCode;
  final int actuel;
  final int max;
  final int exces;

  factory AnomalieDeclassement.fromJson(Map<String, dynamic> json) {
    return AnomalieDeclassement(
      type: TypeAnomalieDeclassement.fromCode(json['type'] as String? ?? ''),
      message: json['message'] as String? ?? '',
      activiteCode: json['activite_code'] as String?,
      roleCode: json['role_code'] as String?,
      actuel: (json['actuel'] as num?)?.toInt() ?? 0,
      max: (json['max'] as num?)?.toInt() ?? 0,
      exces: (json['exces'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.code,
        'message': message,
        if (activiteCode != null) 'activite_code': activiteCode,
        if (roleCode != null) 'role_code': roleCode,
        'actuel': actuel,
        'max': max,
        'exces': exces,
      };
}

class PlanTarifInfo {
  const PlanTarifInfo({
    required this.code,
    required this.nom,
    required this.prixMensuel,
    required this.maxActivites,
  });

  final String code;
  final String nom;
  final int prixMensuel;
  final int maxActivites;

  factory PlanTarifInfo.fromJson(Map<String, dynamic> json) {
    return PlanTarifInfo(
      code: json['code'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      prixMensuel: (json['prix_mensuel'] as num?)?.toInt() ?? 0,
      maxActivites: (json['max_activites'] as num?)?.toInt() ?? 1,
    );
  }
}

class AnalyseDeclassement {
  const AnalyseDeclassement({
    required this.conforme,
    required this.entrepriseId,
    required this.planActuel,
    required this.planCible,
    required this.typeFacturation,
    this.sponsorMotif,
    required this.valeurCommercialeReference,
    required this.montantDu,
    required this.utilisateursActifs,
    this.maxUtilisateursCible,
    this.utilisateursIllimites = false,
    required this.nbActivitesActives,
    required this.activitesActives,
    required this.perimetresActifsParActivite,
    required this.anomalies,
    this.estSurclassement = false,
    this.typeChangement = 'DECLASSEMENT',
  });

  final bool conforme;
  final String entrepriseId;
  final PlanTarifInfo planActuel;
  final PlanTarifInfo planCible;
  final String typeFacturation; // 'COMMERCIAL' ou 'SPONSORISE'
  final String? sponsorMotif;
  final int valeurCommercialeReference;
  final int montantDu; // 0 si SPONSORISE
  final int utilisateursActifs;
  final int? maxUtilisateursCible;
  final bool utilisateursIllimites;
  final int nbActivitesActives;
  final List<String> activitesActives;
  final Map<String, int> perimetresActifsParActivite;
  final List<AnomalieDeclassement> anomalies;
  final bool estSurclassement;
  final String typeChangement; // 'SURCLASSEMENT' ou 'DECLASSEMENT'

  bool get estSponsorise => typeFacturation == 'SPONSORISE';

  factory AnalyseDeclassement.fromJson(Map<String, dynamic> json) {
    final usage = json['usage_actuel'] is Map
        ? Map<String, dynamic>.from(json['usage_actuel'] as Map)
        : <String, dynamic>{};
    final limites = json['limites_cible'] is Map
        ? Map<String, dynamic>.from(json['limites_cible'] as Map)
        : <String, dynamic>{};
    final perimJson = usage['perimetres_actifs_par_activite'] is Map
        ? Map<String, dynamic>.from(usage['perimetres_actifs_par_activite'] as Map)
        : <String, dynamic>{};

    final estSurclassement = json['est_surclassement'] as bool? ??
        (json['type_changement'] == 'SURCLASSEMENT');

    return AnalyseDeclassement(
      conforme: json['conforme'] as bool? ?? false,
      entrepriseId: json['entreprise_id']?.toString() ?? '',
      planActuel: PlanTarifInfo.fromJson(
        json['plan_actuel'] is Map ? Map<String, dynamic>.from(json['plan_actuel'] as Map) : {},
      ),
      planCible: PlanTarifInfo.fromJson(
        json['plan_cible'] is Map ? Map<String, dynamic>.from(json['plan_cible'] as Map) : {},
      ),
      typeFacturation: json['type_facturation']?.toString() ?? 'COMMERCIAL',
      sponsorMotif: json['sponsor_motif'] as String?,
      valeurCommercialeReference: (json['valeur_commerciale_reference'] as num?)?.toInt() ?? 0,
      montantDu: (json['montant_du'] as num?)?.toInt() ?? 0,
      utilisateursActifs: (usage['utilisateurs_actifs'] as num?)?.toInt() ?? 0,
      maxUtilisateursCible: (limites['max_utilisateurs'] as num?)?.toInt(),
      utilisateursIllimites: limites['utilisateurs_illimites'] as bool? ?? false,
      nbActivitesActives: (usage['nb_activites_actives'] as num?)?.toInt() ?? 0,
      activitesActives: (usage['activites_actives'] as List<dynamic>?)
              ?.map((e) => e?.toString() ?? '')
              .where((e) => e.isNotEmpty)
              .toList() ??
          [],
      perimetresActifsParActivite: perimJson.map(
        (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
      ),
      anomalies: (json['anomalies'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) => AnomalieDeclassement.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      estSurclassement: estSurclassement,
      typeChangement: json['type_changement'] as String? ??
          (estSurclassement ? 'SURCLASSEMENT' : 'DECLASSEMENT'),
    );
  }
}

class DemandeDeclassement {
  const DemandeDeclassement({
    required this.id,
    required this.entrepriseId,
    required this.planActuelCode,
    required this.planCibleCode,
    required this.statut,
    required this.conforme,
    this.dateEffectivePrevue,
    this.analyse,
    required this.anomalies,
    required this.createdAt,
    this.appliqueLe,
  });

  final String id;
  final String entrepriseId;
  final String planActuelCode;
  final String planCibleCode;
  final String statut; // pending_preparation, ready, scheduled, applied, cancelled, blocked
  final bool conforme;
  final DateTime? dateEffectivePrevue;
  final AnalyseDeclassement? analyse;
  final List<AnomalieDeclassement> anomalies;
  final DateTime createdAt;
  final DateTime? appliqueLe;

  bool get estPrete => statut == 'ready' && conforme;
  bool get estAppliquee => statut == 'applied';
  bool get estAnnulee => statut == 'cancelled';
  bool get necessitePreparation => statut == 'pending_preparation' || !conforme;

  factory DemandeDeclassement.fromJson(Map<String, dynamic> json) {
    AnalyseDeclassement? parsedAnalyse;
    if (json['details_analyse'] is Map && (json['details_analyse'] as Map).isNotEmpty) {
      parsedAnalyse = AnalyseDeclassement.fromJson(Map<String, dynamic>.from(json['details_analyse'] as Map));
    } else if (json['analyse'] is Map && (json['analyse'] as Map).isNotEmpty) {
      parsedAnalyse = AnalyseDeclassement.fromJson(Map<String, dynamic>.from(json['analyse'] as Map));
    }

    return DemandeDeclassement(
      id: json['id'] as String? ?? json['demande_id'] as String? ?? '',
      entrepriseId: json['entreprise_id'] as String? ?? '',
      planActuelCode: json['plan_actuel_code'] as String? ?? '',
      planCibleCode: json['plan_cible_code'] as String? ?? '',
      statut: json['statut'] as String? ?? 'pending_preparation',
      conforme: json['conforme'] as bool? ?? false,
      dateEffectivePrevue: json['date_effective_prevue'] != null
          ? DateTime.tryParse(json['date_effective_prevue'] as String)
          : null,
      analyse: parsedAnalyse,
      anomalies: (json['anomalies'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) => AnomalieDeclassement.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      appliqueLe: json['applique_le'] != null
          ? DateTime.tryParse(json['applique_le'] as String)
          : null,
    );
  }
}
