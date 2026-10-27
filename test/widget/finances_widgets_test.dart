import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import 'package:dubagest/features/finances/domain/entities/finances.dart';
import 'package:dubagest/features/finances/domain/repositories/finances_repository.dart';
import 'package:dubagest/features/finances/domain/services/etat_finances.dart';
import 'package:dubagest/features/finances/presentation/pages/caisse_page.dart';
import 'package:dubagest/features/finances/presentation/pages/finances_page.dart';
import 'package:dubagest/features/finances/presentation/pages/paiement_form_page.dart';
import 'package:dubagest/features/finances/presentation/providers/finances_providers.dart';
import 'package:dubagest/features/finances/presentation/widgets/carte_dossier_dette.dart';
import 'package:dubagest/features/finances/presentation/widgets/finances_widgets.dart';
import 'package:dubagest/features/finances/presentation/widgets/workspace_finances_vendeur.dart';
import 'package:dubagest/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:dubagest/features/navigation/domain/services/navigation_builder.dart';
import 'package:dubagest/features/perimetres/presentation/providers/perimetres_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../helpers/contexte_fixtures.dart';
import '../helpers/pump_app.dart';

final _jour = DateTime(2026, 9, 1);

final _etat = EtatFinances(
  engagements: [
    Engagement(id: 'e-ancien', entrepriseId: entrepriseId, sens: SensEngagement.aRecevoir, libelle: 'Septembre',
        contactId: 'c-1', montantTotal: 8000, dateEngagement: _jour),
    Engagement(id: 'e-recent', entrepriseId: entrepriseId, sens: SensEngagement.aRecevoir, libelle: 'Octobre',
        contactId: 'c-1', montantTotal: 10000, dateEngagement: DateTime(2026, 10, 1)),
  ],
  caisses: const [Caisse(id: 'k1', entrepriseId: entrepriseId, perimetreId: 'b1', nom: 'Caisse Marché')],
  sessions: [
    SessionCaisse(id: 's1', entrepriseId: entrepriseId, caisseId: 'k1', perimetreId: 'b1', ouverte: true,
        soldeInitial: 15000, ouverteLe: DateTime(2026, 10, 5, 8)),
  ],
);

class _Repo implements FinancesRepository {
  final paiements = <Paiement>[];

  @override
  Stream<EtatFinances> watch(String entrepriseId) => Stream.value(_etat);
  @override
  Future<void> enregistrerPaiement(Paiement paiement, {MouvementCaisse? mouvement}) async => paiements.add(paiement);
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  final nombre = NumberFormat.decimalPattern('fr');

  List<Object> overrides(_Repo repo, {String role = 'ADMINISTRATEUR', Set<String>? permissions}) {
    final ctx = contexte(role: role, permissions: permissions, perimetres: [perimetreJson('b1')]);
    return [
      contexteActifProvider.overrideWithValue(ctx),
      navigationModelProvider.overrideWithValue(const NavigationBuilder().build(ctx)),
      financesRepositoryProvider.overrideWithValue(repo),
      contactsParIdProvider.overrideWith((ref) => Stream.value(const {})),
      perimetresProvider.overrideWith((ref) => Stream.value(const [])),
    ];
  }

  testWidgets('Finances : pas d\'onglets en haut, une carte par module autorisé, chiffres réels', (tester) async {
    await pumpApp(tester, const FinancesPage(), overrides: overrides(_Repo()).cast(), size: const Size(420, 2400));
    expect(find.byType(TabBar), findsNothing);
    expect(find.byKey(const Key('onglet-finances.creances')), findsOneWidget);
    expect(find.byKey(const Key('onglet-finances.caisse')), findsOneWidget);
    expect(find.textContaining(nombre.format(18000)), findsWidgets, reason: 'à recevoir');
    expect(find.textContaining(nombre.format(15000)), findsWidgets, reason: 'en caisse');
  });

  testWidgets('Finances : un module s\'ouvre seul, en plein écran', (tester) async {
    await pumpApp(tester, const FinancesPage(onglet: 'finances.creances'),
        overrides: overrides(_Repo()).cast(), size: const Size(420, 1200));
    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(CarteDossierDette), findsOneWidget);
    expect(find.byKey(const Key('engagement-add')), findsOneWidget);
  });

  testWidgets('Finances : sans droits financiers, ni onglet ni bouton', (tester) async {
    await pumpApp(
      tester,
      const FinancesPage(),
      overrides: overrides(_Repo(), role: 'VENDEUR', permissions: {'payments.view'}).cast(),
      size: const Size(420, 1200),
    );
    expect(find.byKey(const Key('onglet-finances.paiements')), findsOneWidget);
    expect(find.byKey(const Key('onglet-finances.caisse')), findsNothing);
    expect(find.byKey(const Key('paiement-add')), findsNothing, reason: 'pas de payments.create');
  });

  testWidgets('encaissement : répartition du plus ancien au plus récent, caisse proposée', (tester) async {
    final repo = _Repo();
    await pumpApp(
      tester,
      const PaiementFormPage(engagementId: 'e-ancien'),
      overrides: overrides(repo).cast(),
      size: const Size(420, 1600),
    );
    // Ouvert depuis la créance : montant = reste, caisse ouverte proposée (espèces).
    expect(find.text('Caisse Marché'), findsOneWidget);
    await tester.tap(find.byKey(const Key('affecter-e-recent')));
    await tester.enterText(find.byKey(const Key('paiement-montant')), '12000');
    await tester.pumpAndSettle();
    expect(find.text('+ ${nombre.format(8000)} FCFA'), findsOneWidget);
    expect(find.text('+ ${nombre.format(4000)} FCFA'), findsOneWidget);

    await tester.tap(find.byKey(const Key('paiement-enregistrer')));
    await tester.pump();
    final p = repo.paiements.single;
    expect((p.montant, p.mode, p.sessionId, p.contactId), (12000, ModePaiement.especes, 's1', 'c-1'));
    expect({for (final a in p.affectations) a.engagementId: a.montant}, {'e-ancien': 8000, 'e-recent': 4000});
  });

  testWidgets('clôture de caisse : écart affiché avant validation', (tester) async {
    await pumpApp(tester, const CaissePage(caisseId: 'k1'), overrides: overrides(_Repo()).cast(), size: const Size(420, 1400));
    await tester.tap(find.byKey(const Key('caisse-cloturer')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('cloture-compte')), '14000');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cloture-ecart')), findsOneWidget);
    expect(find.textContaining(nombre.format(-1000)), findsOneWidget);
    // Un écart se justifie : cause + explication avant de pouvoir clôturer.
    bool confirmable() => tester.widget<FilledButton>(find.byKey(const Key('cloture-confirmer'))).onPressed != null;
    expect(confirmable(), isFalse);
    await tester.tap(find.byKey(const Key('cloture-motif-RENDU_MONNAIE')));
    await tester.enterText(find.byKey(const Key('cloture-note')), 'Monnaie rendue en trop');
    await tester.pumpAndSettle();
    expect(confirmable(), isTrue);
  });

  testWidgets('dépenses : onglet, total du mois, catégories traduites', (tester) async {
    final etat = EtatFinances(
      categories: const [CategorieDepense(id: 'k-t', entrepriseId: entrepriseId, code: 'TRANSPORT')],
      depenses: [
        Depense(id: 'd1', entrepriseId: entrepriseId, categorieId: 'k-t', libelle: 'Taxi livraison',
            montant: 5000, dateDepense: DateTime.now(), payeeImmediatement: true, mode: ModePaiement.especes),
      ],
    );
    final repo = _Repo();
    await pumpApp(
      tester,
      const FinancesPage(onglet: 'finances.depenses'),
      overrides: [
        ...overrides(repo),
        etatFinancesProvider.overrideWith((ref) => Stream.value(etat)),
      ].cast(),
      size: const Size(420, 1200),
    );
    expect(find.text('Taxi livraison'), findsOneWidget);
    expect(find.textContaining('Transport'), findsWidgets);
    expect(find.text('− ${nombre.format(5000)} FCFA'), findsOneWidget);
    expect(find.byKey(const Key('depense-add')), findsOneWidget);
    expect(find.byKey(const Key('categories-gerer')), findsOneWidget);
  });

  testWidgets('dépenses : filtre par jour, mois, année, avec navigation', (tester) async {
    final maintenant = DateTime.now();
    final aujourdhui = DateTime(maintenant.year, maintenant.month, maintenant.day);
    Depense dep(String id, int montant, DateTime date) => Depense(
        id: id,
        entrepriseId: entrepriseId,
        categorieId: 'k-t',
        libelle: id,
        montant: montant,
        dateDepense: date,
        payeeImmediatement: false);
    final etat = EtatFinances(
      categories: const [CategorieDepense(id: 'k-t', entrepriseId: entrepriseId, code: 'TRANSPORT')],
      depenses: [
        dep('Carburant du jour', 5000, aujourdhui),
        dep('Loyer an dernier', 300000, DateTime(aujourdhui.year - 1, aujourdhui.month, aujourdhui.day)),
      ],
    );
    await pumpApp(
      tester,
      const FinancesPage(onglet: 'finances.depenses'),
      overrides: [...overrides(_Repo()), etatFinancesProvider.overrideWith((ref) => Stream.value(etat))].cast(),
      size: const Size(420, 1400),
    );
    String total() => (tester.widget<Text>(
          find.descendant(of: find.byKey(const Key('depenses-total')), matching: find.byType(Text)),
        )).data!;

    // Par défaut : le mois en cours.
    expect(find.text('Carburant du jour'), findsOneWidget);
    expect(find.text('Loyer an dernier'), findsNothing);
    expect(total(), contains(nombre.format(5000)));
    expect(tester.widget<IconButton>(find.byKey(const Key('depenses-suivant'))).onPressed, isNull,
        reason: 'pas de mois futur');

    // Année précédente : seulement le loyer.
    await tester.tap(find.text('Année'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('depenses-precedent')));
    await tester.pumpAndSettle();
    expect(find.text('Loyer an dernier'), findsOneWidget);
    expect(find.text('Carburant du jour'), findsNothing);
    expect(total(), contains(nombre.format(300000)));

    // Tout : les deux.
    await tester.tap(find.text('Tout'));
    await tester.pumpAndSettle();
    expect(total(), contains(nombre.format(305000)));

    // Jour : aujourd'hui seulement.
    await tester.tap(find.text('Jour'));
    await tester.pumpAndSettle();
    expect(find.text('Carburant du jour'), findsOneWidget);
    expect(total(), contains(nombre.format(5000)));
  });

  testWidgets('en arabe : page Finances RTL et traduite', (tester) async {
    await pumpApp(
      tester,
      const FinancesPage(onglet: 'finances.creances'),
      locale: const Locale('ar'),
      overrides: overrides(_Repo()).cast(),
      size: const Size(420, 1200),
    );
    expect(find.text('للتحصيل'), findsWidgets);
    expect(Directionality.of(tester.element(find.byType(CarteDossierDette))), TextDirection.rtl);
  });

  testWidgets('Finances vendeur : workspace adapté caisse & encaissements, sans tableau de bord DAF', (tester) async {
    await pumpApp(
      tester,
      const FinancesPage(),
      overrides: overrides(
        _Repo(),
        role: 'VENDEUR',
        permissions: {...vendeurPermissions, 'cash.close'},
      ).cast(),
      size: const Size(420, 1600),
    );

    expect(find.byType(WorkspaceFinancesVendeur), findsOneWidget);
    expect(find.text('Point de Caisse'), findsOneWidget);
    expect(find.text('Direction Financière'), findsNothing);
    expect(find.text('Score Santé Financière'), findsNothing);
    expect(find.text('Marge Nette'), findsNothing);
    expect(find.text('Caisse ouverte'), findsOneWidget);
    expect(find.text('Clôturer la caisse'), findsOneWidget);
    expect(find.byKey(const Key('onglet-finances.creances')), findsOneWidget);
    expect(find.byKey(const Key('onglet-finances.paiements')), findsOneWidget);
    expect(find.byKey(const Key('onglet-finances.depenses')), findsNothing);
  });

  testWidgets('Créances vendeur : les dettes fournisseurs ne sont pas affichées', (tester) async {
    await pumpApp(
      tester,
      const FinancesPage(onglet: 'finances.creances'),
      overrides: overrides(
        _Repo(),
        role: 'VENDEUR',
        permissions: vendeurPermissions,
      ).cast(),
      size: const Size(420, 1200),
    );

    expect(find.text('À payer'), findsNothing);
    expect(find.byKey(const Key('filtre-sens-dette')), findsNothing);
  });
}
