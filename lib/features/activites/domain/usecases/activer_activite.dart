import '../../../../core/permissions/access_decision.dart';
import '../../../../core/permissions/permission_codes.dart';
import '../../../entreprise/domain/entities/contexte_session.dart';
import '../../../entreprise/domain/repositories/entreprise_repository.dart';
import '../entities/activite.dart';

/// Ajouter une activité à l'entreprise (ex. Immobilier plus tard) :
/// permission `entreprise.manage` ET formule qui l'autorise.
class ActiverActivite {
  const ActiverActivite(this._repository);
  final EntrepriseRepository _repository;

  AccessDecision verifier(ContexteSession ctx, ActiviteCode activite) => ctx.permissionEngine
      .check(PermissionCodes.entrepriseManage)
      .and(() => ctx.limites().canActivateActivity(activite));

  Future<void> call(ContexteSession ctx, ActiviteCode activite) {
    final decision = verifier(ctx, activite);
    if (decision case AccessDenied()) throw decision.toFailure();
    return _repository.activerActivite(
      entrepriseId: ctx.entreprise!.id,
      activite: activite,
      dejaRattachee: ctx.activites.any((a) => a.activite == activite),
    );
  }
}
