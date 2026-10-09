import '../../../abonnement/domain/entities/abonnement.dart';
import '../../../abonnement/domain/services/limites_engine.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../../modules/domain/entities/app_module.dart';
import '../../../modules/domain/services/module_access_policy.dart';
import '../../../perimetres/domain/entities/perimetre.dart';
import '../../../permissions/domain/services/permission_engine.dart';
import '../../../roles/domain/entities/role.dart';
import '../../../utilisateurs/domain/entities/membre.dart';
import 'entreprise.dart';

enum ContexteEtat { pret, aucuneEntreprise, membreSuspendu, entrepriseSuspendue }

/// Tout ce que l'application doit savoir après la connexion :
/// entreprise → abonnement/plan → activités → modules → rôle → permissions →
/// périmètres. Chargé en un appel, mis en cache pour le mode hors-ligne.
class ContexteSession {
  const ContexteSession({
    required this.userId,
    required this.nomComplet,
    required this.entreprises,
    required this.entreprise,
    required this.membre,
    required this.permissions,
    required this.abonnement,
    required this.plan,
    required this.activites,
    required this.roles,
    required this.modules,
    required this.perimetres,
    required this.consommation,
    required this.chargeLe,
    required this.depuisCache,
  });

  final String userId;
  final String? nomComplet;
  final List<EntrepriseResume> entreprises;
  final Entreprise? entreprise;
  final Membre? membre;
  final Set<String> permissions;
  final Abonnement? abonnement;
  final Plan? plan;
  final List<EntrepriseActivite> activites;
  final Map<String, Role> roles;
  final List<AppModule> modules;

  /// Périmètres auxquels l'utilisateur a accès.
  final List<Perimetre> perimetres;
  final ConsommationAbonnement consommation;
  final DateTime chargeLe;

  /// Chargé depuis l'appareil faute de connexion.
  final bool depuisCache;

  ContexteEtat get etat {
    if (entreprise == null || membre == null) return ContexteEtat.aucuneEntreprise;
    if (!membre!.estActif) return ContexteEtat.membreSuspendu;
    if (entreprise!.statut != EntrepriseStatut.active) return ContexteEtat.entrepriseSuspendue;
    return ContexteEtat.pret;
  }

  Role? get role => membre == null ? null : roles[membre!.roleCode];

  LimitesEngine limites([DateTime? now]) => LimitesEngine(
        plan: plan,
        abonnement: abonnement,
        activites: activites,
        roles: roles,
        consommation: consommation,
        entrepriseActive: entreprise?.statut == EntrepriseStatut.active,
        now: now ?? DateTime.now(),
      );

  PermissionEngine get permissionEngine => membre == null
      ? PermissionEngine.aucune
      : PermissionEngine(
          permissions: permissions,
          membreActif: membre!.estActif,
          perimetreIds: {for (final p in perimetres) p.id},
        );

  ModuleAccessPolicy accessPolicy([DateTime? now]) => ModuleAccessPolicy(
        limites: limites(now),
        permissions: permissionEngine,
        catalogue: modules,
      );
}
