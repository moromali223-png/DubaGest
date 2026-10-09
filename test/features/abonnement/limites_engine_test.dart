import 'package:dubagest/core/permissions/access_decision.dart';
import 'package:dubagest/features/activites/domain/entities/activite.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/contexte_fixtures.dart';

String? refus(AccessDecision d) => d is AccessDenied ? d.ruleCode : null;
Object? param(AccessDecision d, String key) => (d as AccessDenied).params[key];

void main() {
  group('Plan NORMAL', () {
    test('Commerce : 3 utilisateurs (1 admin, 1 gestionnaire stock, 1 vendeur), 1 boutique', () {
      final limites = contexte(plan: 'NORMAL').limites();

      expect(limites.maxUtilisateurs, 3);
      expect(limites.maxPerimetres(ActiviteCode.commerce), 1);
      expect(limites.canCreateUser(roleCode: 'VENDEUR').isAllowed, isTrue);
      expect(limites.canCreateUser(roleCode: 'GESTIONNAIRE_STOCK').isAllowed, isTrue);
      expect(refus(limites.canCreateUser(roleCode: 'SUPERVISEUR')), RuleCodes.roleNotAllowed,
          reason: 'pas de superviseur en NORMAL');
      expect(refus(limites.canCreateUser(roleCode: 'ADMINISTRATEUR')), RuleCodes.roleLimit);
    });

    test('Commerce : le 4e utilisateur est refusé avec la limite du plan', () {
      final limites = contexte(
        plan: 'NORMAL',
        utilisateurs: 3,
        membresParRole: {'ADMINISTRATEUR': 1, 'GESTIONNAIRE_STOCK': 1, 'VENDEUR': 1},
      ).limites();

      final d = limites.canAddUser();
      expect(refus(d), RuleCodes.usersLimit);
      expect(param(d, 'max'), 3);
      expect(param(d, 'plan'), 'NORMAL');
      expect(refus(limites.canCreateUser(roleCode: 'VENDEUR')), RuleCodes.roleLimit);
    });

    test('Commerce : une seule boutique', () {
      final limites = contexte(plan: 'NORMAL').limites();
      expect(limites.canCreatePerimetre(ActiviteCode.commerce, existants: 0).isAllowed, isTrue);
      final d = limites.canCreatePerimetre(ActiviteCode.commerce, existants: 1);
      expect(refus(d), RuleCodes.perimetresLimit);
      expect(param(d, 'max'), 1);
    });

    test('Services : un seul utilisateur, aucun rôle Commerce', () {
      final limites = contexte(plan: 'NORMAL', activites: ['SERVICES']).limites();
      expect(limites.maxUtilisateurs, 1);
      expect(refus(limites.canAddUser()), RuleCodes.usersLimit);
      expect(refus(limites.canCreateUser(roleCode: 'VENDEUR')), RuleCodes.roleActivityInactive);
    });

    test('Immobilier : un seul utilisateur', () {
      final limites = contexte(plan: 'NORMAL', activites: ['IMMOBILIER']).limites();
      expect(limites.maxUtilisateurs, 1);
      expect(refus(limites.canAddUser()), RuleCodes.usersLimit);
    });

    test('une seule activité', () {
      final limites = contexte(plan: 'NORMAL').limites();
      expect(limites.canActivateActivity(ActiviteCode.commerce).isAllowed, isTrue,
          reason: 'déjà active');
      final d = limites.canActivateActivity(ActiviteCode.services);
      expect(refus(d), RuleCodes.activitiesLimit);
      expect(param(d, 'max'), 1);
    });
  });

  group('Plan MOYEN', () {
    test('Commerce : jusqu\'à 7 utilisateurs et 2 boutiques', () {
      final limites = contexte().limites();
      expect(limites.maxUtilisateurs, 7);
      expect(limites.maxPerimetres(ActiviteCode.commerce), 2);
      expect(limites.canCreatePerimetre(ActiviteCode.commerce, existants: 1).isAllowed, isTrue);
      expect(refus(limites.canCreatePerimetre(ActiviteCode.commerce, existants: 2)),
          RuleCodes.perimetresLimit);
    });

    test('organisation : 2 superviseurs, 2 gestionnaires, 2 vendeurs, 1 admin', () {
      final limites = contexte(
        utilisateurs: 6,
        membresParRole: {'ADMINISTRATEUR': 1, 'SUPERVISEUR': 2, 'VENDEUR': 2, 'GESTIONNAIRE_STOCK': 1},
      ).limites();
      expect(refus(limites.canCreateUser(roleCode: 'SUPERVISEUR')), RuleCodes.roleLimit);
      expect(refus(limites.canCreateUser(roleCode: 'VENDEUR')), RuleCodes.roleLimit);
      expect(limites.canCreateUser(roleCode: 'GESTIONNAIRE_STOCK').isAllowed, isTrue);
    });

    test('Commerce + Services : les utilisateurs suivent la limite Commerce', () {
      final limites = contexte(activites: ['COMMERCE', 'SERVICES']).limites();
      expect(limites.maxUtilisateurs, 7);
      expect(limites.maxPerimetres(ActiviteCode.services), 1);
    });

    test('Services + Immobilier : un administrateur unique', () {
      final limites = contexte(activites: ['SERVICES', 'IMMOBILIER']).limites();
      expect(limites.maxUtilisateurs, 1);
      expect(refus(limites.canAddUser()), RuleCodes.usersLimit);
    });

    test('jamais les trois activités', () {
      final limites = contexte(activites: ['COMMERCE', 'SERVICES']).limites();
      expect(refus(limites.canActivateActivity(ActiviteCode.immobilier)), RuleCodes.activitiesLimit);
      expect(contexte().limites().canActivateActivity(ActiviteCode.immobilier).isAllowed, isTrue);
    });
  });

  group('Abonnement', () {
    test('expiré ou suspendu : tout est refusé', () {
      for (final ctx in [
        contexte(abonnementStatut: 'SUSPENDU'),
        contexte(dateFin: DateTime(2026, 2, 1)),
        contexte(entrepriseStatut: 'SUSPENDUE'),
      ]) {
        final limites = ctx.limites(DateTime(2026, 10, 3));
        expect(limites.abonnementActif, isFalse);
        expect(refus(limites.canAddUser()), RuleCodes.subscriptionInactive);
        expect(refus(limites.canCreatePerimetre(ActiviteCode.commerce)), RuleCodes.subscriptionInactive);
      }
    });

    test('essai en cours : autorisé', () {
      final limites = contexte(abonnementStatut: 'ESSAI', dateFin: DateTime(2027))
          .limites(DateTime(2026, 10, 3));
      expect(limites.abonnementActif, isTrue);
    });

    test('module : activité inactive ou hors plan', () {
      final ctx = contexte();
      final limites = ctx.limites();
      final biens = ctx.modules.firstWhere((m) => m.code == 'immobilier.biens');
      final ventes = ctx.modules.firstWhere((m) => m.code == 'commerce.ventes');
      expect(refus(limites.canActivateModule(biens)), RuleCodes.activityInactive);
      expect(limites.canActivateModule(ventes).isAllowed, isTrue);
    });
  });
}
