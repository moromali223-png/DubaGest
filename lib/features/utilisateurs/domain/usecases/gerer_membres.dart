import '../../../../core/permissions/access_decision.dart';
import '../../../../core/permissions/permission_codes.dart';
import '../../../entreprise/domain/entities/contexte_session.dart';
import '../../../perimetres/domain/entities/perimetre.dart';
import '../../../perimetres/domain/services/affectation_policy.dart';
import '../entities/membre.dart';
import '../repositories/membre_repository.dart';

class ListerMembres {
  const ListerMembres(this._repository);
  final MembreRepository _repository;

  Future<List<Membre>> call(ContexteSession ctx) {
    _verifier(ctx.permissionEngine.check(PermissionCodes.usersView));
    return _repository.lister(ctx.entreprise!.id);
  }
}

/// « Peut-on ajouter un utilisateur ? » : permission ET limite d'abonnement.
class VerifierAjoutMembre {
  const VerifierAjoutMembre();

  AccessDecision call(ContexteSession ctx) => ctx.permissionEngine
      .check(PermissionCodes.usersInvite)
      .and(() => ctx.limites().canAddUser());
}

class AffecterPerimetre {
  const AffecterPerimetre(this._repository, [this._policy = const AffectationPolicy()]);
  final MembreRepository _repository;
  final AffectationPolicy _policy;

  AccessDecision verifier(ContexteSession ctx, Membre membre, Perimetre perimetre) {
    final role = ctx.roles[membre.roleCode];
    return ctx.permissionEngine.check(PermissionCodes.usersManage).and(() => role == null
        ? const AccessDenied(RuleCodes.roleNotAllowed)
        : _policy.peutAffecter(role: role, perimetre: perimetre));
  }

  Future<void> call(ContexteSession ctx, Membre membre, Perimetre perimetre) {
    _verifier(verifier(ctx, membre, perimetre));
    return _repository.affecter(
      entrepriseId: ctx.entreprise!.id,
      membreId: membre.id,
      perimetreId: perimetre.id,
    );
  }
}

class RetirerPerimetre {
  const RetirerPerimetre(this._repository);
  final MembreRepository _repository;

  Future<void> call(ContexteSession ctx, Membre membre, Perimetre perimetre) {
    _verifier(ctx.permissionEngine.check(PermissionCodes.usersManage));
    return _repository.retirer(membreId: membre.id, perimetreId: perimetre.id);
  }
}

class ModifierRoleMembre {
  const ModifierRoleMembre(this._repository);
  final MembreRepository _repository;

  Future<void> call(ContexteSession ctx, Membre membre, String nouveauRoleCode) {
    _verifier(ctx.permissionEngine.check(PermissionCodes.usersManage));
    return _repository.modifierRole(
      entrepriseId: ctx.entreprise!.id,
      membreId: membre.id,
      roleCode: nouveauRoleCode,
    );
  }
}

class ModifierStatutMembre {
  const ModifierStatutMembre(this._repository);
  final MembreRepository _repository;

  Future<void> call(ContexteSession ctx, Membre membre, MembreStatut nouveauStatut) {
    _verifier(ctx.permissionEngine.check(PermissionCodes.usersManage));
    return _repository.modifierStatut(
      entrepriseId: ctx.entreprise!.id,
      membreId: membre.id,
      statut: nouveauStatut.code,
    );
  }
}

class SupprimerMembre {
  const SupprimerMembre(this._repository);
  final MembreRepository _repository;

  Future<void> call(ContexteSession ctx, Membre membre) {
    _verifier(ctx.permissionEngine.check(PermissionCodes.usersManage));
    return _repository.supprimer(
      entrepriseId: ctx.entreprise!.id,
      membreId: membre.id,
    );
  }
}

void _verifier(AccessDecision decision) {
  if (decision case AccessDenied()) throw decision.toFailure();
}
