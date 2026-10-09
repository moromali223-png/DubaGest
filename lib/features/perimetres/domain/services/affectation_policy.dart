import '../../../../core/permissions/access_decision.dart';
import '../../../roles/domain/entities/role.dart';
import '../entities/perimetre.dart';

/// Règles d'affectation membre ↔ périmètre (miroir du trigger serveur).
class AffectationPolicy {
  const AffectationPolicy();

  AccessDecision peutAffecter({required Role role, required Perimetre perimetre}) {
    if (role.accesTousPerimetres) {
      return const AccessDenied(RuleCodes.assignmentNotNeeded);
    }
    if (role.activite != null && role.activite != perimetre.activite) {
      return AccessDenied(RuleCodes.assignmentActivityMismatch, {
        'role': role.code,
        'activite': perimetre.activite.code,
      });
    }
    return AccessDecision.allowed;
  }
}
