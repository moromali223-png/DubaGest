import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import 'package:dubagest/features/finances/domain/entities/finances.dart';
import 'package:dubagest/features/finances/domain/services/etat_finances.dart';
import 'package:dubagest/features/finances/presentation/providers/finances_providers.dart';
import 'package:dubagest/features/finances/presentation/widgets/finances_widgets.dart';
import 'package:dubagest/features/agenda/presentation/providers/agenda_providers.dart';
import 'package:dubagest/features/documents/presentation/providers/documents_providers.dart';
import 'package:dubagest/features/contacts/domain/entities/contact.dart';
import 'package:dubagest/features/recherche/presentation/recherche_page.dart';
import 'package:dubagest/features/tableau_de_bord/presentation/tableau_de_bord_page.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../helpers/contexte_fixtures.dart';
import '../helpers/pump_app.dart';

void main() {
  final aujourdhui = DateTime.now();
  final etat = EtatFinances(
    paiements: [
      Paiement(id: 'p1', entrepriseId: entrepriseId, sens: SensPaiement.entree, montant: 20000,
          mode: ModePaiement.especes, datePaiement: aujourdhui, contactId: 'c-1'),
      Paiement(id: 'p2', entrepriseId: entrepriseId, sens: SensPaiement.sortie, montant: 5000,
          mode: ModePaiement.virement, datePaiement: aujourdhui),
    ],
    categories: const [CategorieDepense(id: 'k-t', entrepriseId: entrepriseId, code: 'TRANSPORT')],
    depenses: [
      Depense(id: 'd1', entrepriseId: entrepriseId, categorieId: 'k-t', libelle: 'Taxi', montant: 3000,
          dateDepense: aujourdhui, payeeImmediatement: true),
    ],
    engagements: [
      Engagement(id: 'e1', entrepriseId: entrepriseId, sens: SensEngagement.aRecevoir, libelle: 'Crédit',
          montantTotal: 30000, dateEngagement: aujourdhui, contactId: 'c-1'),
    ],
  );
  const amadou = Contact(id: 'c-1', entrepriseId: entrepriseId, nom: 'Traoré', prenom: 'Amadou');

  List<Object> overrides({String role = 'ADMINISTRATEUR', Set<String>? permissions}) => [
        contexteActifProvider.overrideWithValue(contexte(role: role, permissions: permissions)),
        etatFinancesProvider.overrideWith((ref) => Stream.value(etat)),
        contactsParIdProvider.overrideWith((ref) => Stream.value({'c-1': amadou})),
        documentsProvider.overrideWith((ref) => Stream.value(const [])),
        echeancesProvider.overrideWith((ref) => Stream.value(const [])),
      ];

  testWidgets('tableau de bord : indicateurs réels, graphique, catégories, débiteurs', (tester) async {
    await pumpApp(tester, const TableauDeBordPage(), overrides: overrides().cast(), size: const Size(480, 2200));
    final n = NumberFormat.decimalPattern('fr');
    expect(find.text(n.format(20000)), findsOneWidget, reason: 'encaissé');
    expect(find.text(n.format(15000)), findsOneWidget, reason: 'net = 20 000 − 5 000');
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.text('Encaissé'), findsWidgets, reason: 'légende : l\'identité ne repose pas sur la couleur seule');
    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('Amadou Traoré'), findsOneWidget);
  });

  testWidgets('tableau de bord : sections selon les droits', (tester) async {
    await pumpApp(
      tester,
      const TableauDeBordPage(),
      overrides: overrides(role: 'VENDEUR', permissions: {'receivables.view'}).cast(),
      size: const Size(480, 2200),
    );
    expect(find.byType(BarChart), findsNothing, reason: 'pas de payments.view');
    expect(find.text('Transport'), findsNothing, reason: 'pas d\'expenses.view');
    expect(find.text('Amadou Traoré'), findsOneWidget);
  });

  testWidgets('recherche globale : résultats regroupés, hors-ligne', (tester) async {
    await pumpApp(tester, const RecherchePage(), overrides: overrides().cast(), size: const Size(480, 1400));
    expect(find.textContaining('fonctionne aussi hors-ligne'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('recherche-champ')), 'amadou');
    await tester.pumpAndSettle();
    expect(find.text('Contacts'), findsOneWidget);
    expect(find.text('Sommes dues'), findsOneWidget);
    expect(find.text('Amadou Traoré'), findsWidgets);
    await tester.enterText(find.byKey(const Key('recherche-champ')), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('Aucun résultat.'), findsOneWidget);
  });
}
