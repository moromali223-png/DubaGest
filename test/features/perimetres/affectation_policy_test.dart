import 'package:dubagest/core/permissions/access_decision.dart';
import 'package:dubagest/features/activites/domain/entities/activite.dart';
import 'package:dubagest/features/perimetres/domain/entities/perimetre.dart';
import 'package:dubagest/features/perimetres/domain/services/affectation_policy.dart';
import 'package:dubagest/features/roles/domain/entities/role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = AffectationPolicy();
  const boutiqueA = Perimetre(
    id: 'a', entrepriseId: 'e', activite: ActiviteCode.commerce, type: PerimetreType.boutique, nom: 'A');
  const agence = Perimetre(
    id: 'g', entrepriseId: 'e', activite: ActiviteCode.services, type: PerimetreType.agence, nom: 'G');
  const superviseur = Role(code: 'SUPERVISEUR', activite: ActiviteCode.commerce, accesTousPerimetres: false);
  const admin = Role(code: 'ADMINISTRATEUR', activite: null, accesTousPerimetres: true);

  test('un superviseur Commerce peut être affecté à une boutique', () {
    expect(policy.peutAffecter(role: superviseur, perimetre: boutiqueA).isAllowed, isTrue);
  });

  test('pas d\'affectation hors de l\'activité du rôle', () {
    final d = policy.peutAffecter(role: superviseur, perimetre: agence);
    expect((d as AccessDenied).ruleCode, RuleCodes.assignmentActivityMismatch);
  });

  test('affectation inutile pour un rôle ayant accès à tout', () {
    final d = policy.peutAffecter(role: admin, perimetre: boutiqueA);
    expect((d as AccessDenied).ruleCode, RuleCodes.assignmentNotNeeded);
  });
}
