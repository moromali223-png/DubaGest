import 'package:dubagest/core/permissions/access_decision.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/contexte_fixtures.dart';

String? refus(AccessDecision d) => d is AccessDenied ? d.ruleCode : null;

void main() {
  group('ACCÈS FINAL = abonnement ET activité ET module ET permission ET périmètre', () {
    final vendeur = contexte(
      role: 'VENDEUR',
      membresParRole: {'ADMINISTRATEUR': 1, 'VENDEUR': 1},
      perimetres: [perimetreJson('boutique-a')],
    );

    test('tout est satisfait', () {
      final policy = vendeur.accessPolicy();
      expect(policy.canAccessModule('commerce.ventes').isAllowed, isTrue);
      expect(
        policy.canPerform(moduleCode: 'commerce.ventes', permission: 'sales.create', perimetreId: 'boutique-a')
            .isAllowed,
        isTrue,
      );
    });

    test('permission manquante', () {
      final policy = vendeur.accessPolicy();
      expect(refus(policy.canAccessModule('commerce.achats')), RuleCodes.permissionDenied);
      expect(refus(policy.canPerform(moduleCode: 'commerce.ventes', permission: 'sales.delete')),
          RuleCodes.permissionDenied);
    });

    test('périmètre non affecté', () {
      expect(
        refus(vendeur.accessPolicy().canPerform(
            moduleCode: 'commerce.ventes', permission: 'sales.create', perimetreId: 'boutique-b')),
        RuleCodes.perimetreDenied,
      );
    });

    test('activité non active : même un administrateur est refusé', () {
      final admin = contexte();
      expect(refus(admin.accessPolicy().canAccessModule('immobilier.biens')), RuleCodes.activityInactive);
    });

    test('abonnement inactif : modules fermés, sauf la page abonnement', () {
      final admin = contexte(abonnementStatut: 'SUSPENDU');
      final policy = admin.accessPolicy();
      expect(refus(policy.canAccessModule('commerce.ventes')), RuleCodes.subscriptionInactive);
      expect(policy.canAccessModule('admin.abonnement').isAllowed, isTrue);
    });

    test('module inconnu', () {
      expect(refus(contexte().accessPolicy().canAccessModule('commerce.inexistant')),
          RuleCodes.moduleNotInPlan);
    });
  });
}
