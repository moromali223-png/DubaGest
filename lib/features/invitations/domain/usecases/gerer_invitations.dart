import '../../../../core/errors/failure.dart';
import '../../../../core/permissions/access_decision.dart';
import '../../../../core/permissions/permission_codes.dart';
import '../../../entreprise/domain/entities/contexte_session.dart';
import '../../../perimetres/domain/entities/perimetre.dart';
import '../../../perimetres/domain/services/affectation_policy.dart';
import '../entities/invitation.dart';
import '../repositories/invitation_repository.dart';

/// Inviter : réservé à `users.invite`. Le rôle et les périmètres sont fixés
/// ici par la personne autorisée ; le serveur revérifie tout.
class CreerInvitation {
  const CreerInvitation(this._repository, [this._policy = const AffectationPolicy()]);
  final InvitationRepository _repository;
  final AffectationPolicy _policy;

  /// Rôles proposables avec la raison d'un éventuel refus (plan, quotas, activité).
  Map<String, AccessDecision> rolesProposables(ContexteSession ctx) {
    final limites = ctx.limites();
    final quotas = ctx.plan?.quotasRoles.keys ?? const <String>[];
    return {
      for (final code in ctx.roles.keys.where(quotas.contains))
        code: ctx.permissionEngine
            .check(PermissionCodes.usersInvite)
            .and(() => limites.canCreateUser(roleCode: code)),
    };
  }

  /// Le rôle doit-il être limité à des périmètres ? (pas pour un accès global)
  bool perimetresRequis(ContexteSession ctx, String roleCode) =>
      !(ctx.roles[roleCode]?.accesTousPerimetres ?? true);

  AccessDecision peutAffecter(ContexteSession ctx, String roleCode, Perimetre perimetre) {
    final role = ctx.roles[roleCode];
    return role == null
        ? const AccessDenied(RuleCodes.roleNotAllowed)
        : _policy.peutAffecter(role: role, perimetre: perimetre);
  }

  Future<InvitationCreee> call(
    ContexteSession ctx, {
    required String email,
    required String roleCode,
    required List<Perimetre> perimetres,
  }) {
    _verifier(ctx.permissionEngine.check(PermissionCodes.usersInvite));
    final requis = perimetresRequis(ctx, roleCode);
    if (requis && perimetres.isEmpty) {
      throw const Failure.rule(RuleCodes.perimetreRequired);
    }
    for (final p in perimetres) {
      _verifier(peutAffecter(ctx, roleCode, p));
    }
    return _repository.creer(
      entrepriseId: ctx.entreprise!.id,
      email: email.trim().toLowerCase(),
      roleCode: roleCode,
      perimetreIds: requis ? [for (final p in perimetres) p.id] : const [],
    );
  }
}

class ListerInvitations {
  const ListerInvitations(this._repository);
  final InvitationRepository _repository;

  Future<List<Invitation>> call(ContexteSession ctx) {
    if (!ctx.permissionEngine.has(PermissionCodes.usersInvite)) return Future.value(const []);
    return _repository.lister(ctx.entreprise!.id);
  }
}

class RenvoyerInvitation {
  const RenvoyerInvitation(this._repository);
  final InvitationRepository _repository;

  Future<InvitationCreee> call(ContexteSession ctx, Invitation invitation) {
    _verifier(ctx.permissionEngine.check(PermissionCodes.usersInvite));
    return _repository.renvoyer(invitation.id);
  }
}

class SupprimerInvitation {
  const SupprimerInvitation(this._repository);
  final InvitationRepository _repository;

  Future<void> call(ContexteSession ctx, Invitation invitation) {
    _verifier(ctx.permissionEngine.check(PermissionCodes.usersInvite));
    return _repository.supprimer(invitation.id);
  }
}

class AnnulerInvitation {
  const AnnulerInvitation(this._repository);
  final InvitationRepository _repository;

  Future<void> call(ContexteSession ctx, Invitation invitation) {
    _verifier(ctx.permissionEngine.check(PermissionCodes.usersInvite));
    return _repository.annuler(invitation.id);
  }
}

class VerifierInvitation {
  const VerifierInvitation(this._repository);
  final InvitationRepository _repository;

  Future<InvitationApercu> call(String token) => _repository.verifier(token.trim());
}

/// Rejoindre l'entreprise : le rôle obtenu est celui de l'invitation.
class AccepterInvitation {
  const AccepterInvitation(this._repository);
  final InvitationRepository _repository;

  Future<String> call(String token) async {
    final entrepriseId = await _repository.accepter(token.trim());
    await _repository.oublierJeton();
    return entrepriseId;
  }
}

void _verifier(AccessDecision decision) {
  if (decision case AccessDenied()) throw decision.toFailure();
}
