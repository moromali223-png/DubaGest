import '../../../../core/permissions/access_decision.dart';
import '../../../../core/permissions/permission_codes.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../../entreprise/domain/entities/contexte_session.dart';
import '../entities/perimetre.dart';
import '../repositories/perimetre_repository.dart';

class ObserverPerimetres {
  const ObserverPerimetres(this._repository);
  final PerimetreRepository _repository;

  /// Uniquement les périmètres auxquels l'utilisateur a accès.
  Stream<List<Perimetre>> call(ContexteSession ctx) {
    final engine = ctx.permissionEngine;
    return _repository
        .watch(ctx.entreprise!.id)
        .map((list) => list.where((p) => engine.canAccessPerimetre(p.id)).toList());
  }
}

class CreerPerimetre {
  const CreerPerimetre(this._repository);
  final PerimetreRepository _repository;

  /// Activités pour lesquelles un nouveau périmètre est autorisé maintenant.
  Future<Map<ActiviteCode, AccessDecision>> decisionsParActivite(ContexteSession ctx) async {
    final limites = ctx.limites();
    return {
      for (final a in limites.activitesActives)
        a: limites.canCreatePerimetre(a,
            existants: await _repository.compter(ctx.entreprise!.id, a)),
    };
  }

  Future<Perimetre> call(
    ContexteSession ctx, {
    required ActiviteCode activite,
    required PerimetreType type,
    required String nom,
    String? code,
  }) async {
    _verifier(ctx.permissionEngine.check(PermissionCodes.perimetresManage));
    final existants = await _repository.compter(ctx.entreprise!.id, activite);
    _verifier(ctx.limites().canCreatePerimetre(activite, existants: existants));
    return _repository.creer(
      entrepriseId: ctx.entreprise!.id,
      activite: activite,
      type: type,
      nom: nom.trim(),
      code: _nullIfBlank(code),
    );
  }
}

class ModifierPerimetre {
  const ModifierPerimetre(this._repository);
  final PerimetreRepository _repository;

  Future<void> call(
    ContexteSession ctx,
    Perimetre perimetre, {
    required String nom,
    required String? code,
    required PerimetreType type,
    required bool estActif,
  }) {
    _verifier(ctx.permissionEngine.check(PermissionCodes.perimetresManage));
    return _repository.modifier(perimetre,
        nom: nom.trim(), code: _nullIfBlank(code), type: type, estActif: estActif);
  }
}

class SupprimerPerimetre {
  const SupprimerPerimetre(this._repository);
  final PerimetreRepository _repository;

  Future<void> call(ContexteSession ctx, Perimetre perimetre) {
    _verifier(ctx.permissionEngine.check(PermissionCodes.perimetresManage));
    return _repository.supprimer(perimetre);
  }
}

void _verifier(AccessDecision decision) {
  if (decision case AccessDenied()) throw decision.toFailure();
}

String? _nullIfBlank(String? value) {
  final v = value?.trim();
  return v == null || v.isEmpty ? null : v;
}
