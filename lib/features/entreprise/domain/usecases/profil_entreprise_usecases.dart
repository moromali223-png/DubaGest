import '../../../../core/errors/failure.dart';
import '../../../../core/permissions/access_decision.dart';
import '../../../../core/permissions/permission_codes.dart';
import '../entities/contexte_session.dart';
import '../entities/profil_entreprise.dart';
import '../repositories/entreprise_repository.dart';

class ChargerProfilEntreprise {
  const ChargerProfilEntreprise(this._repository);
  final EntrepriseRepository _repository;

  Future<ProfilEntreprise> call(ContexteSession ctx) => _repository.profil(ctx.entreprise!.id);
}

/// Modifier la fiche : `entreprise.manage` ; statut, formule et rattachements
/// restent hors de portée (privilèges colonnes côté serveur).
class ModifierProfilEntreprise {
  const ModifierProfilEntreprise(this._repository);
  final EntrepriseRepository _repository;

  bool peutModifier(ContexteSession ctx) => ctx.permissionEngine.has(PermissionCodes.entrepriseManage);

  Future<void> call(ContexteSession ctx, ProfilEntreprise profil) {
    final decision = ctx.permissionEngine.check(PermissionCodes.entrepriseManage);
    if (decision case AccessDenied()) throw decision.toFailure();
    if (profil.nom.trim().length < 2) throw const Failure.rule(RuleCodes.nameInvalid);
    if (profil.id != ctx.entreprise!.id) throw const Failure(FailureKind.forbidden);
    return _repository.enregistrerProfil(profil);
  }
}

/// Paramètres d'encaissement : modes proposés (au moins un, pris dans le
/// catalogue) et mention en bas des reçus. `entreprise.manage`.
class ModifierParametresEntreprise {
  const ModifierParametresEntreprise(this._repository);
  final EntrepriseRepository _repository;

  Future<void> call(ContexteSession ctx, {required Set<String> modesPaiement, String? piedRecu}) async {
    final decision = ctx.permissionEngine.check(PermissionCodes.entrepriseManage);
    if (decision case AccessDenied()) throw decision.toFailure();
    final modes = [for (final m in ProfilEntreprise.tousLesModes) if (modesPaiement.contains(m)) m];
    if (modes.isEmpty) throw const Failure.rule(RuleCodes.paymentModesInvalid);
    if ((piedRecu?.trim().length ?? 0) > ProfilEntreprise.piedRecuMax) {
      throw const Failure.rule(RuleCodes.textTooLong, {'max': ProfilEntreprise.piedRecuMax});
    }
    return _repository.enregistrerParametres(ctx.entreprise!.id, modesPaiement: modes, piedRecu: piedRecu);
  }
}
