import 'dart:math' as math;

import '../../../../core/permissions/access_decision.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../../modules/domain/entities/app_module.dart';
import '../../../roles/domain/entities/role.dart';
import '../entities/abonnement.dart';

/// Moteur de limites : « l'entreprise a-t-elle le droit d'utiliser cette
/// fonctionnalité ? ». Seul endroit (côté Flutter) où les règles du plan sont
/// interprétées ; les mêmes règles sont appliquées par les triggers PostgreSQL.
/// Il ne connaît pas l'utilisateur : voir PermissionEngine.
class LimitesEngine {
  const LimitesEngine({
    required this.plan,
    required this.abonnement,
    required this.activites,
    required this.roles,
    required this.consommation,
    required this.entrepriseActive,
    required this.now,
  });

  final Plan? plan;
  final Abonnement? abonnement;
  final List<EntrepriseActivite> activites;
  final Map<String, Role> roles;
  final ConsommationAbonnement consommation;
  final bool entrepriseActive;
  final DateTime now;

  bool get abonnementActif =>
      entrepriseActive && plan != null && abonnement != null && abonnement!.estEnVigueur(now);

  Set<ActiviteCode> get activitesActives =>
      {for (final a in activites) if (a.estActive) a.activite};

  /// Limite d'utilisateurs = maximum des limites des activités actives ;
  /// `null` = illimité (une activité sans limite suffit, formule PRO).
  int? get maxUtilisateurs {
    final limites = [
      for (final a in activitesActives)
        if (plan?.activites[a] case final l?) l.maxUtilisateurs,
    ];
    if (limites.isEmpty) return 1;
    if (limites.contains(null)) return null;
    return limites.whereType<int>().reduce(math.max);
  }

  /// `null` = illimité. Une activité absente du plan est refusée ailleurs.
  int? maxPerimetres(ActiviteCode activite) => plan?.activites[activite]?.maxPerimetres;

  bool roleInclus(String roleCode) => plan?.quotasRoles.containsKey(roleCode) ?? false;

  /// `null` = sans quota.
  int? quotaRole(String roleCode) => plan?.quotasRoles[roleCode];

  bool get utilisateursIllimites => maxUtilisateurs == null;

  AccessDecision verifierAbonnement() => abonnementActif
      ? AccessDecision.allowed
      : const AccessDenied(RuleCodes.subscriptionInactive);

  /// Reste-t-il au moins une place d'utilisateur, tous rôles confondus ?
  AccessDecision canAddUser() => verifierAbonnement().and(() {
        final max = maxUtilisateurs;
        if (max != null && consommation.utilisateurs >= max) {
          return AccessDenied(RuleCodes.usersLimit, {..._plan, 'max': max});
        }
        return AccessDecision.allowed;
      });

  /// Ordre des vérifications identique au trigger `app.tg_verifier_membre`.
  AccessDecision canCreateUser({required String roleCode}) => verifierAbonnement().and(() {
        final role = roles[roleCode];
        final quota = quotaRole(roleCode);
        if (role == null || !roleInclus(roleCode)) {
          return AccessDenied(RuleCodes.roleNotAllowed, {..._plan, 'role': roleCode});
        }
        if (role.activite != null && !activitesActives.contains(role.activite)) {
          return AccessDenied(RuleCodes.roleActivityInactive, {'role': roleCode});
        }
        if (quota != null && (consommation.membresParRole[roleCode] ?? 0) >= quota) {
          return AccessDenied(RuleCodes.roleLimit, {..._plan, 'role': roleCode, 'max': quota});
        }
        final max = maxUtilisateurs;
        if (max != null && consommation.utilisateurs >= max) {
          return AccessDenied(RuleCodes.usersLimit, {..._plan, 'max': max});
        }
        return AccessDecision.allowed;
      });

  /// [existants] : nombre réel de périmètres non supprimés (base locale à jour),
  /// à défaut la consommation reçue au chargement du contexte.
  AccessDecision canCreatePerimetre(ActiviteCode activite, {int? existants}) =>
      verifierAbonnement().and(() {
        if (!activitesActives.contains(activite)) {
          return AccessDenied(RuleCodes.activityInactive, {'activite': activite.code});
        }
        if (plan?.activites[activite] == null) {
          return AccessDenied(RuleCodes.activityNotAllowed, {..._plan, 'activite': activite.code});
        }
        final max = maxPerimetres(activite);
        final count = existants ?? consommation.perimetresParActivite[activite] ?? 0;
        if (max != null && count >= max) {
          return AccessDenied(
              RuleCodes.perimetresLimit, {..._plan, 'activite': activite.code, 'max': max});
        }
        return AccessDecision.allowed;
      });

  AccessDecision canActivateActivity(ActiviteCode activite) => verifierAbonnement().and(() {
        if (activitesActives.contains(activite)) return AccessDecision.allowed;
        if (plan!.activites[activite] == null) {
          return AccessDenied(RuleCodes.activityNotAllowed, {..._plan, 'activite': activite.code});
        }
        if (activitesActives.length >= plan!.maxActivites) {
          return AccessDenied(RuleCodes.activitiesLimit, {..._plan, 'max': plan!.maxActivites});
        }
        return AccessDecision.allowed;
      });

  /// Le module est-il fourni à l'entreprise (plan + activité active) ?
  AccessDecision canActivateModule(AppModule module) => verifierAbonnement().and(() {
        if (module.activite != null && !activitesActives.contains(module.activite)) {
          return AccessDenied(RuleCodes.activityInactive, {'activite': module.activite!.code});
        }
        if (!plan!.modules.contains(module.code)) {
          return AccessDenied(RuleCodes.moduleNotInPlan, {..._plan, 'module': module.code});
        }
        return AccessDecision.allowed;
      });

  Map<String, Object?> get _plan => {'plan': plan?.code};
}
