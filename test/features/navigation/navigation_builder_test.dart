import 'package:dubagest/features/activites/domain/entities/activite.dart';
import 'package:dubagest/features/navigation/domain/entities/navigation_model.dart';
import 'package:dubagest/features/navigation/domain/services/navigation_builder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/contexte_fixtures.dart';

void main() {
  const builder = NavigationBuilder();

  test('vendeur Commerce : uniquement ses modules, aucun menu Immobilier', () {
    final nav = builder.build(contexte(role: 'VENDEUR', activites: ['COMMERCE', 'SERVICES']));
    final codes = nav.sections.expand((s) => s.modules).map((m) => m.code).toSet();

    expect(codes, containsAll(['commerce.produits', 'commerce.stock', 'commerce.ventes']));
    expect(codes, isNot(contains('commerce.achats')), reason: 'pas de purchases.view');
    // Finances communes à toutes les activités, dans l'onglet Finances.
    expect(nav.modulesFinances.map((m) => m.code), ['finances.creances', 'finances.paiements', 'finances.caisse']);
    expect(nav.modulesCommuns.map((m) => m.code), ['commun.contacts', 'commun.documents', 'commun.agenda']);
    expect(codes.where((c) => c.startsWith('immobilier.')), isEmpty);
    expect(nav.modulesAdministration.map((m) => m.code), ['admin.perimetres']);
    expect(nav.modulesAdministration.map((m) => m.code), isNot(contains('admin.utilisateurs')));
  });

  test('sans stock.view, le module Stock n\'apparaît pas', () {
    final nav = builder.build(contexte(role: 'VENDEUR', permissions: {'sales.view'}));
    final codes = nav.sections.expand((s) => s.modules).map((m) => m.code);
    expect(codes, ['commerce.ventes']);
    expect(nav.destinations, [NavDestination.accueil, NavDestination.compte],
        reason: 'ni stock.view ni droit financier : ni Stock ni Finances');
  });

  test('barre du bas Commerce : Accueil · Stock · (Vendre) · Finances · Compte', () {
    final nav = builder.build(contexte());
    expect(nav.destinations, [
      NavDestination.accueil,
      NavDestination.stock,
      NavDestination.finances,
      NavDestination.compte,
    ]);
    expect(nav.venteDisponible, isTrue);
  });

  test('administrateur Immobilier (NORMAL) : pas de Stock, administration dans le menu', () {
    final nav = builder.build(contexte(plan: 'NORMAL', activites: ['IMMOBILIER']));
    expect(nav.sections.map((s) => s.activite), [ActiviteCode.immobilier]);
    expect(nav.destinations, isNot(contains(NavDestination.stock)));
    expect(nav.destinations, contains(NavDestination.finances), reason: 'caisse et créances communes');
    expect(nav.venteDisponible, isFalse);
    expect(nav.modulesAdministration.length, 5, reason: 'dont le journal d''activité');
  });

  test('abonnement inactif : aucune section métier', () {
    final nav = builder.build(contexte(abonnementStatut: 'EXPIRE'));
    expect(nav.sections, isEmpty);
    expect(nav.abonnementActif, isFalse);
    expect(nav.modulesAdministration.map((m) => m.code), ['admin.abonnement']);
  });
}
