import 'package:flutter/foundation.dart';

@immutable
class SuperAdminDashboard {
  const SuperAdminDashboard({
    required this.totalEntreprises,
    required this.entreprisesActives,
    required this.entreprisesSuspendues,
    required this.totalUtilisateurs,
    required this.abonnementsActifs,
    required this.abonnementsSponsorises,
    required this.abonnementsExpires,
    required this.activitesRecentes,
    this.abonnementsParPlan = const {},
  });

  factory SuperAdminDashboard.fromJson(Map<String, dynamic> json) {
    return SuperAdminDashboard(
      totalEntreprises: (json['total_entreprises'] as num?)?.toInt() ?? 0,
      entreprisesActives: (json['entreprises_actives'] as num?)?.toInt() ?? 0,
      entreprisesSuspendues: (json['entreprises_suspendues'] as num?)?.toInt() ?? 0,
      totalUtilisateurs: (json['total_utilisateurs'] as num?)?.toInt() ?? 0,
      abonnementsActifs: (json['abonnements_actifs'] as num?)?.toInt() ?? 0,
      abonnementsSponsorises: (json['abonnements_sponsorises'] as num?)?.toInt() ?? (json['total_sponsorises'] as num?)?.toInt() ?? 0,
      abonnementsExpires: (json['abonnements_expires'] as num?)?.toInt() ?? 0,
      abonnementsParPlan: (json['abonnements_par_plan'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ) ??
          const {},
      activitesRecentes: (json['activites_recentes'] as List<dynamic>?)
              ?.map((e) => AdminAuditLog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  final int totalEntreprises;
  final int entreprisesActives;
  final int entreprisesSuspendues;
  final int totalUtilisateurs;
  final int abonnementsActifs;
  final int abonnementsSponsorises;
  final int abonnementsExpires;
  final Map<String, int> abonnementsParPlan;
  final List<AdminAuditLog> activitesRecentes;

  int get totalSponsorises => abonnementsSponsorises;
}

@immutable
class AdminEntreprise {
  const AdminEntreprise({
    required this.id,
    required this.nom,
    required this.statut,
    required this.createdAt,
    this.pays,
    this.devise,
    this.telephone,
    this.ville,
    this.createurNom,
    this.createurEmail,
    this.planCode,
    this.abonnementStatut,
    this.typeFacturation = 'COMMERCIAL',
    this.sponsorMotif,
    this.valeurCommercialeReference = 0,
    this.nbUtilisateurs = 0,
    this.nbPerimetres = 0,
    this.activites = const [],
  });

  factory AdminEntreprise.fromJson(Map<String, dynamic> json) {
    return AdminEntreprise(
      id: json['id'] as String,
      nom: json['nom'] as String,
      statut: json['statut'] as String? ?? 'ACTIVE',
      pays: json['pays'] as String?,
      devise: json['devise'] as String?,
      telephone: json['telephone'] as String?,
      ville: json['ville'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      createurNom: json['createur_nom'] as String?,
      createurEmail: json['createur_email'] as String?,
      planCode: json['plan_code'] as String?,
      abonnementStatut: json['abonnement_statut'] as String?,
      typeFacturation: json['type_facturation'] as String? ?? 'COMMERCIAL',
      sponsorMotif: json['sponsor_motif'] as String?,
      valeurCommercialeReference: (json['valeur_commerciale_reference'] as num?)?.toInt() ?? 0,
      nbUtilisateurs: (json['nb_utilisateurs'] as num?)?.toInt() ?? 0,
      nbPerimetres: (json['nb_perimetres'] as num?)?.toInt() ?? 0,
      activites: (json['activites'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  final String id;
  final String nom;
  final String statut;
  final String? pays;
  final String? devise;
  final String? telephone;
  final String? ville;
  final DateTime createdAt;
  final String? createurNom;
  final String? createurEmail;
  final String? planCode;
  final String? abonnementStatut;
  final String typeFacturation;
  final String? sponsorMotif;
  final int valeurCommercialeReference;
  final int nbUtilisateurs;
  final int nbPerimetres;
  final List<String> activites;

  bool get estSponsorise => typeFacturation == 'SPONSORISE';
  bool get estActive => statut == 'ACTIVE';
}

@immutable
class AdminAuditLog {
  const AdminAuditLog({
    required this.id,
    required this.action,
    required this.cibleType,
    required this.cibleId,
    required this.createdAt,
    this.adminId,
    this.adminNom,
    this.adminEmail,
    this.ipAddress,
    this.details = const {},
  });

  factory AdminAuditLog.fromJson(Map<String, dynamic> json) {
    return AdminAuditLog(
      id: json['id'] as String,
      action: json['action'] as String,
      cibleType: json['cible_type'] as String,
      cibleId: json['cible_id'] as String,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      adminId: json['admin_id'] as String?,
      adminNom: json['admin_nom'] as String?,
      adminEmail: json['admin_email'] as String?,
      ipAddress: json['ip_address'] as String?,
      details: (json['details'] as Map<String, dynamic>?) ?? const {},
    );
  }

  final String id;
  final String action;
  final String cibleType;
  final String cibleId;
  final DateTime createdAt;
  final String? adminId;
  final String? adminNom;
  final String? adminEmail;
  final String? ipAddress;
  final Map<String, dynamic> details;
}
