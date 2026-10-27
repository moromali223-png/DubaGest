import '../../../activites/domain/entities/activite.dart';

class PlanActiviteLimites {
  const PlanActiviteLimites({
    required this.activite,
    required this.maxUtilisateurs,
    required this.maxPerimetres,
  });

  final ActiviteCode activite;

  /// `null` = illimité (formule PRO).
  final int? maxUtilisateurs;
  final int? maxPerimetres;
}

/// Formule d'abonnement (NORMAL, MOYEN…) et ses règles, définies en base.
class Plan {
  const Plan({
    required this.code,
    required this.nom,
    required this.maxActivites,
    required this.activites,
    required this.quotasRoles,
    required this.modules,
  });

  final String code;
  final String nom;
  final int maxActivites;
  final Map<ActiviteCode, PlanActiviteLimites> activites;

  /// Rôles inclus et nombre maximum de membres actifs (`null` = sans quota).
  final Map<String, int?> quotasRoles;
  final Set<String> modules;
}

enum AbonnementStatut {
  essai('ESSAI'),
  actif('ACTIF'),
  suspendu('SUSPENDU'),
  expire('EXPIRE'),
  annule('ANNULE');

  const AbonnementStatut(this.code);
  final String code;

  static AbonnementStatut parse(String code) =>
      values.firstWhere((s) => s.code == code, orElse: () => AbonnementStatut.expire);
}

/// Utilisation réelle d'un plan par une entreprise.
class Abonnement {
  const Abonnement({
    required this.id,
    required this.planCode,
    required this.statut,
    required this.dateDebut,
    this.dateFin,
    this.typeFacturation = 'COMMERCIAL',
  });

  final String id;
  final String planCode;
  final AbonnementStatut statut;
  final DateTime dateDebut;
  final DateTime? dateFin;
  final String typeFacturation; // 'COMMERCIAL' ou 'SPONSORISE'

  bool get estSponsorise => typeFacturation.toUpperCase() == 'SPONSORISE';

  bool estEnVigueur(DateTime now) =>
      (statut == AbonnementStatut.essai || statut == AbonnementStatut.actif) &&
      !now.isBefore(dateDebut) &&
      (dateFin == null || now.isBefore(dateFin!));
}

/// Consommation actuelle des limites par l'entreprise.
class ConsommationAbonnement {
  const ConsommationAbonnement({
    required this.utilisateurs,
    this.utilisateursActifs,
    this.invitationsEnAttente,
    this.utilisateursMax,
    required this.membresParRole,
    required this.perimetresParActivite,
  });

  static const vide = ConsommationAbonnement(
    utilisateurs: 0,
    membresParRole: {},
    perimetresParActivite: {},
  );

  final int utilisateurs;
  final int? utilisateursActifs;
  final int? invitationsEnAttente;
  final int? utilisateursMax;
  final Map<String, int> membresParRole;
  final Map<ActiviteCode, int> perimetresParActivite;

  int get actifs => utilisateursActifs ?? utilisateurs;
  int get enAttente => invitationsEnAttente ?? 0;
  int get totalOccupes => utilisateurs;
}
