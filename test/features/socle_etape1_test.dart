import 'package:dubagest/core/permissions/access_decision.dart';
import 'package:dubagest/features/activites/domain/entities/activite.dart';
import 'package:dubagest/features/entreprise/domain/entities/espace_courant.dart';
import 'package:dubagest/features/navigation/domain/entities/navigation_model.dart';
import 'package:dubagest/features/navigation/domain/services/navigation_builder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contexte_fixtures.dart';

void main() {
  group('Formule PRO (limites illimitées)', () {
    final limites = contexte(
      plan: 'PRO',
      activites: ['COMMERCE', 'SERVICES', 'IMMOBILIER'],
      utilisateurs: 40,
      membresParRole: {'ADMINISTRATEUR': 1, 'VENDEUR': 25},
      perimetresParActivite: {ActiviteCode.commerce.code: 12},
    ).limites();

    test('utilisateurs et rôles sans plafond', () {
      expect(limites.maxUtilisateurs, isNull);
      expect(limites.canAddUser().isAllowed, isTrue);
      expect(limites.canCreateUser(roleCode: 'VENDEUR').isAllowed, isTrue);
      expect(limites.canCreateUser(roleCode: 'CAISSIER').isAllowed, isTrue);
    });

    test('boutiques sans plafond, trois activités', () {
      expect(limites.canCreatePerimetre(ActiviteCode.commerce, existants: 12).isAllowed, isTrue);
      expect(limites.activitesActives, hasLength(3));
    });

    test('une seule activité limitée suffit à rester limité (MOYEN)', () {
      final moyen = contexte(activites: ['COMMERCE']).limites();
      expect(moyen.maxUtilisateurs, 7);
    });
  });

  test('NORMAL : le caissier compte dans les 3 utilisateurs', () {
    final limites = contexte(
      plan: 'NORMAL',
      utilisateurs: 3,
      membresParRole: {'ADMINISTRATEUR': 1, 'VENDEUR': 1, 'GESTIONNAIRE_STOCK': 1},
    ).limites();
    expect((limites.canCreateUser(roleCode: 'CAISSIER') as AccessDenied).ruleCode, RuleCodes.usersLimit);
  });

  group('Espace de travail (activité ▾ · site)', () {
    final multi = contexte(
      activites: ['COMMERCE', 'SERVICES'],
      perimetres: [
        perimetreJson('b-1', nom: 'Boutique Centre'),
        perimetreJson('b-2', nom: 'Boutique Marché'),
        perimetreJson('a-1', activite: 'SERVICES', nom: 'Agence'),
      ],
    );

    test('plusieurs activités : vue globale par défaut', () {
      final e = EspaceCourant.resoudre(multi, null);
      expect(e.activite, isNull);
      expect(e.perimetreId, isNull);
    });

    test('une activité choisie avec un seul site : ce site est retenu', () {
      final e = EspaceCourant.resoudre(multi, const EspaceCourant(activite: ActiviteCode.services));
      expect(e.activite, ActiviteCode.services);
      expect(e.perimetreId, 'a-1');
    });

    test('un choix devenu invalide est corrigé (site d\'une autre activité)', () {
      final e = EspaceCourant.resoudre(
          multi, const EspaceCourant(activite: ActiviteCode.services, perimetreId: 'b-1'));
      expect(e.perimetreId, 'a-1');
    });

    test('une seule activité : toujours celle-ci', () {
      final e = EspaceCourant.resoudre(contexte(), EspaceCourant.global);
      expect(e.activite, ActiviteCode.commerce);
    });

    test('mémorisation : encodage / décodage', () {
      const e = EspaceCourant(activite: ActiviteCode.commerce, perimetreId: 'b-2');
      expect(EspaceCourant.decoder(e.encoder()), e);
      expect(EspaceCourant.decoder(EspaceCourant.global.encoder()), EspaceCourant.global);
    });

    test('changer d\'activité change les modules et les onglets', () {
      const builder = NavigationBuilder();
      final global = builder.build(multi);
      final services = builder.build(multi, activite: ActiviteCode.services);

      expect(global.sections.map((s) => s.activite), [ActiviteCode.commerce, ActiviteCode.services]);
      expect(services.sections.map((s) => s.activite), [ActiviteCode.services]);
      expect(global.destinations, contains(NavDestination.stock));
      expect(services.destinations, isNot(contains(NavDestination.stock)), reason: 'Stock = Commerce');
      expect(services.venteDisponible, isFalse);
    });
  });
}
