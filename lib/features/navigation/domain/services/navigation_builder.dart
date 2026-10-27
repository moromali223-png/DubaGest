import '../../../../core/permissions/permission_codes.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../../modules/domain/entities/app_module.dart';
import '../../../entreprise/domain/entities/contexte_session.dart';
import '../../../roles/domain/entities/role.dart';
import '../entities/navigation_model.dart';

/// Construit la navigation à partir de : utilisateur + entreprise + activités
/// + abonnement + modules + permissions (via ModuleAccessPolicy), restreinte
/// à l'activité de travail choisie ([activite], `null` = vue globale).
class NavigationBuilder {
  const NavigationBuilder();

  NavigationModel build(ContexteSession ctx, {DateTime? now, ActiviteCode? activite}) {
    final policy = ctx.accessPolicy(now);
    final abonnementActif = ctx.limites(now).abonnementActif;
    final isVendeur = ctx.membre?.roleCode == RoleCodes.vendeur &&
        policy.canPerform(moduleCode: ModuleCodes.commerceVentes, permission: PermissionCodes.salesCreate).isAllowed;
    final isGestionnaireStock = ctx.membre?.roleCode == RoleCodes.gestionnaireStock &&
        policy.canPerform(moduleCode: ModuleCodes.commerceStock, permission: PermissionCodes.stockView).isAllowed;
    final isSuperviseur = ctx.membre?.roleCode == RoleCodes.superviseur;
    final accessibles = policy.accessibleModules();
    bool dansLEspace(ActiviteCode a) => activite == null || activite == a;

    final sections = <ModuleSection>[];
    for (final a in ctx.activites.where((a) => a.estActive && dansLEspace(a.activite))) {
      final modules = accessibles.where((m) => m.activite == a.activite).toList();
      if (modules.isNotEmpty) sections.add(ModuleSection(activite: a.activite, modules: modules));
    }
    final admin = accessibles.where((m) => m.estAdministration).toList();

    final actives = ctx.activites.where((a) => a.estActive).map((a) => a.activite).toList();
    final isMulti = activite == null && actives.length > 1;
    final targetActivite = activite ?? (actives.length == 1 ? actives.first : null);

    // Position 2 : Module principal dynamique selon l'activité
    NavDestination? pos2;
    if (targetActivite == ActiviteCode.commerce) {
      if (policy.canAccessModule(ModuleCodes.commerceStock).isAllowed) {
        pos2 = NavDestination.stock;
      }
    } else if (targetActivite == ActiviteCode.services) {
      if (policy.canAccessModule('services.prestations').isAllowed ||
          policy.canAccessModule('services.services').isAllowed) {
        pos2 = NavDestination.prestations;
      }
    } else if (targetActivite == ActiviteCode.immobilier) {
      if (policy.canAccessModule('immobilier.loyers').isAllowed ||
          policy.canAccessModule('immobilier.biens').isAllowed) {
        pos2 = NavDestination.loyers;
      }
    } else if (isMulti) {
      // Multi-activités : Module phare accessible (Stock ou Ventes ou Prestations ou Loyers)
      if (policy.canAccessModule(ModuleCodes.commerceStock).isAllowed) {
        pos2 = NavDestination.stock;
      } else if (policy.canAccessModule('services.prestations').isAllowed) {
        pos2 = NavDestination.prestations;
      } else if (policy.canAccessModule('immobilier.loyers').isAllowed) {
        pos2 = NavDestination.loyers;
      }
    }

    // Position 3 : Action principale contextuelle (Bouton central ＋)
    QuickActionType? actionCentrale;
    final canSell = dansLEspace(ActiviteCode.commerce) &&
        policy
            .canPerform(moduleCode: ModuleCodes.commerceVentes, permission: PermissionCodes.salesCreate)
            .isAllowed;
    final canPrester = policy
        .canPerform(moduleCode: 'services.prestations', permission: 'prestations.create')
        .isAllowed;
    final canEncaisser = policy
        .canPerform(moduleCode: 'immobilier.loyers', permission: 'rents.create')
        .isAllowed || policy.canPerform(moduleCode: ModuleCodes.financesPaiements, permission: PermissionCodes.paymentsCreate).isAllowed;

    if (isMulti && (canSell || canPrester || canEncaisser)) {
      actionCentrale = QuickActionType.multi;
    } else if (targetActivite == ActiviteCode.commerce && canSell) {
      actionCentrale = QuickActionType.vendre;
    } else if (targetActivite == ActiviteCode.services && canPrester) {
      actionCentrale = QuickActionType.prester;
    } else if (targetActivite == ActiviteCode.immobilier && canEncaisser) {
      actionCentrale = QuickActionType.encaisser;
    } else if (canSell) {
      actionCentrale = QuickActionType.vendre;
    }

    final modulesFinances = accessibles.where((m) => m.estFinances).toList();
    final finances = modulesFinances.isNotEmpty;

    return NavigationModel(
      // 5 positions : Accueil · Module principal · (Action +) · Finances · Compte
      destinations: [
        NavDestination.accueil,
        if (pos2 != null) pos2,
        if (finances) NavDestination.finances,
        NavDestination.compte,
      ],
      sections: sections,
      modulesCommuns: accessibles.where((m) => m.estCommun).toList(),
      modulesFinances: modulesFinances,
      modulesAdministration: admin,
      abonnementActif: abonnementActif,
      venteDisponible: canSell,
      actionCentrale: actionCentrale,
      activiteActive: targetActivite,
      isWorkspaceVendeur: isVendeur,
      isWorkspaceGestionnaireStock: isGestionnaireStock,
      isWorkspaceSuperviseur: isSuperviseur,
    );
  }
}
