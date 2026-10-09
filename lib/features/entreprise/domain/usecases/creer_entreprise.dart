import '../../../../core/errors/failure.dart';
import '../../../../core/permissions/access_decision.dart';
import '../../../activites/domain/entities/activite.dart';
import '../entities/offre_plan.dart';
import '../repositories/entreprise_repository.dart';

/// « Créer mon entreprise » : le créateur devient administrateur parce qu'il
/// crée l'entreprise — jamais à cause de son mode de connexion.
class CreerEntreprise {
  const CreerEntreprise(this._repository);
  final EntrepriseRepository _repository;

  Future<List<OffrePlan>> offres() => _repository.offres();

  /// Contrôle local (même règle que le serveur) : nombre d'activités du plan.
  AccessDecision verifier(OffrePlan offre, Set<ActiviteCode> activites) {
    if (activites.isEmpty) return const AccessDenied(RuleCodes.activityRequired);
    if (!activites.every(offre.activites.contains)) {
      return AccessDenied(RuleCodes.activityNotAllowed, {'plan': offre.code});
    }
    if (activites.length > offre.maxActivites) {
      return AccessDenied(RuleCodes.activitiesLimit, {'plan': offre.code, 'max': offre.maxActivites});
    }
    return AccessDecision.allowed;
  }

  Future<String> call({
    required String nom,
    required OffrePlan offre,
    required Set<ActiviteCode> activites,
  }) {
    if (nom.trim().length < 2) throw const Failure.rule(RuleCodes.nameInvalid);
    final decision = verifier(offre, activites);
    if (decision case AccessDenied()) throw decision.toFailure();
    return _repository.creer(
      nom: nom.trim(),
      planCode: offre.code,
      activites: activites.toList()..sort((a, b) => a.index.compareTo(b.index)),
    );
  }
}
