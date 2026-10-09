import 'package:dubagest/features/entreprise/domain/entities/contexte_session.dart';
import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import 'package:dubagest/features/finances/domain/entities/finances.dart';
import 'package:dubagest/features/finances/domain/services/etat_finances.dart';
import 'package:dubagest/features/finances/presentation/providers/finances_providers.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:dubagest/features/navigation/presentation/pages/home_page.dart';
import 'package:dubagest/features/navigation/presentation/widgets/app_menu_drawer.dart';
import 'package:dubagest/features/navigation/presentation/widgets/app_shell.dart';
import 'package:dubagest/features/navigation/presentation/widgets/floating_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contexte_fixtures.dart';
import '../helpers/fake_entreprise_repository.dart';
import '../helpers/pump_app.dart';

void main() {
  group('AppShell', () {
    testWidgets('mobile : barre flottante, onglets selon les droits (sans vente)', (tester) async {
      await pumpApp(
        tester,
        const AppShell(location: '/', child: SizedBox()),
        overrides: [
          contexteActifProvider.overrideWithValue(contexte(role: 'VENDEUR', permissions: {'sales.view', 'payments.view'})),
        ],
        size: const Size(390, 844),
      );
      expect(find.byType(FloatingNavBar), findsOneWidget);
      expect(find.text('Accueil'), findsOneWidget);
      expect(find.text('Finances'), findsOneWidget);
      expect(find.text('Compte'), findsOneWidget);
      expect(find.text('Stock'), findsNothing, reason: 'pas de stock.view');
      expect(find.text('Administration'), findsNothing);
      expect(find.byKey(const Key('nav-center-action')), findsNothing,
          reason: 'sans sales.create, pas de bouton « Vendre »');
    });

    testWidgets('mobile : bouton central « Vendre » avec sales.create', (tester) async {
      await pumpApp(
        tester,
        const AppShell(location: '/', child: SizedBox()),
        overrides: [contexteActifProvider.overrideWithValue(contexte(role: 'VENDEUR'))],
        size: const Size(390, 844),
      );
      expect(find.byKey(const Key('nav-center-action')), findsOneWidget);
      // Ordre de la maquette : Accueil · Stock · Vendre · Finances · Compte.
      final xs = ['Accueil', 'Stock', 'Vendre', 'Finances', 'Compte']
          .map((t) => tester.getCenter(find.text(t)).dx)
          .toList();
      for (var i = 1; i < xs.length; i++) {
        expect(xs[i], greaterThan(xs[i - 1]));
      }
    });

    testWidgets('grand écran : rail latéral avec les mêmes onglets et « Vendre »', (tester) async {
      await pumpApp(
        tester,
        const AppShell(location: '/finances', child: SizedBox()),
        overrides: [contexteActifProvider.overrideWithValue(contexte())],
        size: const Size(1280, 800),
      );
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Stock'), findsOneWidget);
      expect(find.text('Finances'), findsOneWidget);
      expect(find.byKey(const Key('rail-sell')), findsOneWidget);
    });
  });

  group('Menu ☰', () {
    Future<void> ouvrir(WidgetTester tester, {required ContexteSession ctx}) async {
      await pumpApp(
        tester,
        const HomePage(),
        overrides: [
          contexteActifProvider.overrideWithValue(ctx),
          entrepriseRepositoryProvider.overrideWithValue(FakeEntrepriseRepository()),
        ],
        size: const Size(390, 1400),
      );
      await tester.tap(find.byTooltip('Ouvrir le menu de navigation'));
      await tester.pumpAndSettle();
      expect(find.byType(AppMenuDrawer), findsOneWidget);
    }

    testWidgets('admin MOYEN Commerce + Services : Immobilier verrouillé, avec la raison', (tester) async {
      await ouvrir(tester, ctx: contexte(activites: ['COMMERCE', 'SERVICES']));
      expect(find.text('Mes activités'.toUpperCase()), findsOneWidget);
      expect(find.byKey(const ValueKey('menu-activity-COMMERCE')), findsOneWidget);
      expect(find.byKey(const ValueKey('menu-activity-IMMOBILIER')), findsOneWidget);
      expect(find.text('Votre abonnement Moyen autorise au maximum 2 activités.'), findsOneWidget);
      expect(find.text('Voir l\'abonnement'), findsOneWidget);
    });

    testWidgets('admin MOYEN avec une seule activité : « Activer » proposé', (tester) async {
      await ouvrir(tester, ctx: contexte());
      expect(find.text('Activer'), findsNWidgets(2), reason: 'Services et Immobilier');
    });

    testWidgets('vendeur : seulement ses activités, aucune offre', (tester) async {
      await ouvrir(tester, ctx: contexte(role: 'VENDEUR'));
      expect(find.byKey(const ValueKey('menu-activity-COMMERCE')), findsOneWidget);
      expect(find.byKey(const ValueKey('menu-activity-IMMOBILIER')), findsNothing);
      expect(find.text('Activer'), findsNothing);
    });

    testWidgets('menu ☰ : propose « ❓ Aide » et ouvre le centre d\'aide', (tester) async {
      await ouvrir(tester, ctx: contexte());
      expect(find.byKey(const Key('menu-aide')), findsOneWidget);
      expect(find.text('❓ Aide'), findsOneWidget);

      await tester.tap(find.byKey(const Key('menu-aide')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dialog-aide-support')), findsOneWidget);
      expect(find.text('Centre d\'Aide & Support'), findsOneWidget);
      expect(find.text('Assistance WhatsApp Directe'), findsOneWidget);
    });

    testWidgets('menu ☰ : propose « 📜 Conditions / confidentialité » et ouvre les mentions légales', (tester) async {
      await ouvrir(tester, ctx: contexte());
      expect(find.byKey(const Key('menu-conditions')), findsOneWidget);
      expect(find.text('📜 Conditions / confidentialité'), findsOneWidget);

      await tester.tap(find.byKey(const Key('menu-conditions')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dialog-conditions-confidentialite')), findsOneWidget);
      expect(find.text('Conditions & Confidentialité'), findsOneWidget);
      expect(find.text('Objet et portée du service'), findsOneWidget);
      expect(find.text('CGU'), findsOneWidget);
    });
  });

  group('Accueil', () {
    testWidgets('modules autorisés uniquement, groupés par activité', (tester) async {
      await pumpApp(
        tester,
        const HomePage(),
        overrides: [
          contexteActifProvider.overrideWithValue(
            contexte(role: 'VENDEUR', activites: ['COMMERCE', 'SERVICES']),
          ),
        ],
        size: const Size(390, 1600),
      );
      expect(find.text('Bonjour Awa'), findsOneWidget);
      expect(find.byKey(const ValueKey('module-commerce.ventes')), findsOneWidget);
      expect(find.byKey(const ValueKey('module-commerce.achats')), findsNothing);
      expect(find.byKey(const ValueKey('module-immobilier.biens')), findsNothing);
    });

    testWidgets('indicateurs du jour : chiffres réels issus des paiements et créances', (tester) async {
      final aujourdhui = DateTime.now();
      final etat = EtatFinances(
        engagements: [
          Engagement(
            id: 'e1', entrepriseId: entrepriseId, sens: SensEngagement.aRecevoir, libelle: 'Crédit',
            montantTotal: 50000, montantRegle: 20000, dateEngagement: aujourdhui,
          ),
        ],
        paiements: [
          Paiement(
            id: 'p1', entrepriseId: entrepriseId, sens: SensPaiement.entree, montant: 20000,
            mode: ModePaiement.mobileMoney, datePaiement: aujourdhui,
            affectations: const [Affectation(id: 'a1', engagementId: 'e1', montant: 20000)],
          ),
        ],
      );
      await pumpApp(
        tester,
        const HomePage(),
        overrides: [
          contexteActifProvider.overrideWithValue(contexte()),
          etatFinancesProvider.overrideWith((ref) => Stream.value(etat)),
        ],
        size: const Size(390, 1600),
      );
      final nombre = NumberFormat.decimalPattern('fr');
      expect(find.byKey(const Key('app-menu-button')), findsOneWidget);
      expect(find.text('Aujourd\'hui'), findsOneWidget);
      expect(find.text('Encaissé'), findsOneWidget);
      expect(find.text(nombre.format(20000)), findsOneWidget, reason: 'encaissé aujourd\'hui');
      expect(find.text(nombre.format(30000)), findsOneWidget, reason: 'reste à recevoir');
      expect(find.text('Chiffre d\'affaires'), findsOneWidget, reason: 'chiffre d\'affaires du jour calculé');
    });

    testWidgets('sans accès aux ventes : pas de bloc d\'indicateurs', (tester) async {
      await pumpApp(
        tester,
        const HomePage(),
        overrides: [
          contexteActifProvider.overrideWithValue(contexte(role: 'VENDEUR', permissions: {'stock.view'})),
        ],
        size: const Size(390, 1600),
      );
      expect(find.text('Aujourd\'hui'), findsNothing);
    });

    testWidgets('en arabe : interface RTL et libellés traduits', (tester) async {
      await pumpApp(
        tester,
        const HomePage(),
        overrides: [contexteActifProvider.overrideWithValue(contexte())],
        locale: const Locale('ar'),
        size: const Size(390, 1600),
      );
      expect(Directionality.of(tester.element(find.byType(HomePage))), TextDirection.rtl);
      expect(find.text('المبيعات'), findsOneWidget);
    });

    testWidgets('abonnement inactif : état explicite', (tester) async {
      await pumpApp(
        tester,
        const HomePage(),
        overrides: [contexteActifProvider.overrideWithValue(contexte(abonnementStatut: 'EXPIRE'))],
      );
      expect(find.text('Les modules sont indisponibles tant que l\'abonnement n\'est pas actif.'),
          findsOneWidget);
    });
  });
}
