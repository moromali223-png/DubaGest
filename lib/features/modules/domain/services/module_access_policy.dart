import '../../../../core/permissions/access_decision.dart';
import '../../../abonnement/domain/services/limites_engine.dart';
import '../../../permissions/domain/services/permission_engine.dart';
import '../entities/app_module.dart';

/// ACCÈS FINAL =
///   abonnement en vigueur ET activité active ET module inclus dans le plan
///   ET permission utilisateur ET périmètre autorisé.
/// Miroir client de `app.peut()` côté PostgreSQL.
class ModuleAccessPolicy {
  ModuleAccessPolicy({
    required this.limites,
    required this.permissions,
    required List<AppModule> catalogue,
  }) : _catalogue = {for (final m in catalogue) m.code: m};

  final LimitesEngine limites;
  final PermissionEngine permissions;
  final Map<String, AppModule> _catalogue;

  /// Modules toujours consultables par qui en a la permission, même si
  /// l'abonnement n'est plus actif (pour comprendre et régulariser).
  static const _horsAbonnement = {ModuleCodes.adminAbonnement};

  AppModule? module(String code) => _catalogue[code];

  AccessDecision canAccessModule(String code) {
    final module = _catalogue[code];
    if (module == null) {
      return AccessDenied(RuleCodes.moduleNotInPlan, {'module': code});
    }
    final disponible = _horsAbonnement.contains(code)
        ? AccessDecision.allowed
        : limites.canActivateModule(module);
    return disponible.and(() => permissions.check(module.permissionAcces));
  }

  /// Vérifie une action précise dans un module, éventuellement sur un périmètre.
  AccessDecision canPerform({
    required String moduleCode,
    required String permission,
    String? perimetreId,
  }) =>
      canAccessModule(moduleCode)
          .and(() => permissions.check(permission))
          .and(() => perimetreId == null
              ? AccessDecision.allowed
              : permissions.checkPerimetre(perimetreId));

  List<AppModule> accessibleModules() {
    final modules = _catalogue.values.where((m) => canAccessModule(m.code).isAllowed).toList()
      ..sort((a, b) => a.ordre.compareTo(b.ordre));
    return modules;
  }
}
