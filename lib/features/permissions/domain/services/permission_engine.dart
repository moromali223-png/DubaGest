import '../../../../core/permissions/access_decision.dart';
import '../../../../core/permissions/permission_codes.dart';

/// Moteur de permissions : « cet utilisateur a-t-il le droit d'effectuer
/// cette action ? ». Repose sur ROLE → PERMISSIONS, jamais sur le code du rôle.
/// Côté serveur, la même règle est appliquée par `app.a_permission()`.
class PermissionEngine {
  const PermissionEngine({
    required this.permissions,
    required this.membreActif,
    required this.perimetreIds,
  });

  static const aucune = PermissionEngine(permissions: {}, membreActif: false, perimetreIds: {});

  final Set<String> permissions;
  final bool membreActif;

  /// Périmètres explicitement affectés au membre.
  final Set<String> perimetreIds;

  bool has(String permission) =>
      membreActif &&
      (permissions.contains(permission) ||
          permissions.contains(PermissionCodes.entrepriseManage));

  bool hasAll(Iterable<String> required) => required.every(has);

  bool hasAny(Iterable<String> candidates) => candidates.any(has);

  bool get accesTousPerimetres => has(PermissionCodes.perimetresAccessAll);

  bool canAccessPerimetre(String perimetreId) =>
      membreActif && (accesTousPerimetres || perimetreIds.contains(perimetreId));

  AccessDecision check(String permission) => has(permission)
      ? AccessDecision.allowed
      : AccessDenied(RuleCodes.permissionDenied, {'permission': permission});

  AccessDecision checkAll(Iterable<String> required) {
    for (final p in required) {
      final decision = check(p);
      if (!decision.isAllowed) return decision;
    }
    return AccessDecision.allowed;
  }

  AccessDecision checkPerimetre(String perimetreId) => canAccessPerimetre(perimetreId)
      ? AccessDecision.allowed
      : AccessDenied(RuleCodes.perimetreDenied, {'perimetre': perimetreId});
}
