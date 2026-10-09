import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/core/permissions/access_decision.dart';
import 'package:dubagest/features/activites/domain/entities/activite.dart';
import 'package:dubagest/features/activites/domain/usecases/activer_activite.dart';
import 'package:dubagest/features/entreprise/domain/entities/offre_plan.dart';
import 'package:dubagest/features/entreprise/domain/usecases/creer_entreprise.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/contexte_fixtures.dart';
import '../../helpers/fake_entreprise_repository.dart';

void main() {
  const tous = [ActiviteCode.commerce, ActiviteCode.services, ActiviteCode.immobilier];
  const faible = OffrePlan(code: 'NORMAL', maxActivites: 1, activites: tous);
  const moyen = OffrePlan(code: 'MOYEN', maxActivites: 2, activites: tous);
  late FakeEntrepriseRepository repo;
  late CreerEntreprise creer;

  setUp(() {
    repo = FakeEntrepriseRepository();
    creer = CreerEntreprise(repo);
  });

  String? refus(AccessDecision d) => d is AccessDenied ? d.ruleCode : null;

  test('NORMAL : une activité ; MOYEN : deux combinables, jamais trois', () {
    expect(creer.verifier(faible, {ActiviteCode.commerce}).isAllowed, isTrue);
    expect(refus(creer.verifier(faible, {ActiviteCode.commerce, ActiviteCode.services})),
        RuleCodes.activitiesLimit);
    expect(creer.verifier(moyen, {ActiviteCode.services, ActiviteCode.immobilier}).isAllowed, isTrue);
    expect(refus(creer.verifier(moyen, tous.toSet())), RuleCodes.activitiesLimit);
    expect(refus(creer.verifier(moyen, {})), RuleCodes.activityRequired);
  });

  test('création transmise au serveur (le rôle n\'est jamais envoyé par le client)', () async {
    await creer(nom: ' Gamma ', offre: moyen, activites: {ActiviteCode.services, ActiviteCode.commerce});
    expect(repo.activitesCreees, [ActiviteCode.commerce, ActiviteCode.services]);
  });

  group('Activer une activité (ex. Immobilier plus tard)', () {
    test('MOYEN avec une seule activité : l\'admin peut en ajouter une seconde', () async {
      final ctx = contexte();
      final activer = ActiverActivite(repo);
      expect(activer.verifier(ctx, ActiviteCode.immobilier).isAllowed, isTrue);
      await activer(ctx, ActiviteCode.immobilier);
      expect(repo.activation, (activite: ActiviteCode.immobilier, dejaRattachee: false));
    });

    test('MOYEN déjà à deux activités : refus avec la limite de la formule', () {
      final d = ActiverActivite(repo)
          .verifier(contexte(activites: ['COMMERCE', 'SERVICES']), ActiviteCode.immobilier);
      expect(refus(d), RuleCodes.activitiesLimit);
    });

    test('un vendeur ne peut pas activer d\'activité', () {
      expect(refus(ActiverActivite(repo).verifier(contexte(role: 'VENDEUR'), ActiviteCode.services)),
          RuleCodes.permissionDenied);
      expect(() => ActiverActivite(repo).call(contexte(role: 'VENDEUR'), ActiviteCode.services),
          throwsA(isA<Failure>()));
      expect(repo.activation, isNull);
    });
  });

  test('nom trop court refusé avant tout appel', () {
    expect(() => creer(nom: 'G', offre: faible, activites: {ActiviteCode.commerce}),
        throwsA(isA<Failure>()));
    expect(repo.activitesCreees, isNull);
  });
}
