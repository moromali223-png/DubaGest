import 'package:dubagest/features/commerce/domain/entities/commerce.dart';
import 'package:dubagest/features/commerce/domain/services/etat_commerce.dart';
import 'package:dubagest/features/commerce/presentation/commerce_providers.dart';
import 'package:dubagest/features/commerce/presentation/widgets/workspace_vendeur_accueil.dart';
import 'package:dubagest/features/entreprise/domain/entities/contexte_session.dart';
import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import 'package:dubagest/features/navigation/domain/entities/navigation_model.dart';
import 'package:dubagest/features/navigation/domain/services/navigation_builder.dart';
import 'package:dubagest/features/navigation/presentation/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/contexte_fixtures.dart';
import '../../helpers/fake_entreprise_repository.dart';
import '../../helpers/pump_app.dart';

void main() {
  const builder = NavigationBuilder();

  group('Workspace Vendeur - Navigation & Permissions', () {
    test('NavigationBuilder identifie le profil VENDEUR et configure le workspace dédié', () {
      final ctx = contexte(
        role: 'VENDEUR',
        permissions: {'sales.create', 'sales.view'},
        perimetres: [perimetreJson('b-1', nom: 'Boutique A')],
      );

      final nav = builder.build(ctx);
      expect(nav.isWorkspaceVendeur, isTrue);
      expect(nav.venteDisponible, isTrue);
      expect(nav.actionCentrale, QuickActionType.vendre);
      expect(nav.destinations, contains(NavDestination.accueil));
      expect(nav.destinations, contains(NavDestination.compte));
      expect(nav.modulesFinances, isEmpty, reason: 'Pas d\'accès direct aux finances globales');
      expect(nav.modulesAdministration.where((m) => m.code == 'admin.utilisateurs'), isEmpty);
    });

    test('Sans droit de vente, le workspace vendeur n\'est pas activé', () {
      final ctx = contexte(role: 'VENDEUR', permissions: {'stock.view'});
      final nav = builder.build(ctx);
      expect(nav.isWorkspaceVendeur, isFalse);
    });
  });

  group('Workspace Vendeur - Interface Accueil & Statistiques', () {
    final aujourdhui = DateTime.now();
    const boutiqueId = 'b-1';

    final etatVentes = EtatCommerce(
      ventes: [
        Vente(
          id: 'v1',
          entrepriseId: entrepriseId,
          perimetreId: boutiqueId,
          date: aujourdhui,
          total: 25000,
          montantPaye: 25000,
          modePaiement: 'ESPECES',
          numero: 'REC-20261008-001',
          lignes: const [
            LigneOperation(id: 'l1', produitId: 'p1', unite: 'pièce', facteur: Qte.un, quantite: Qte(50000), prixUnitaire: 5000),
          ],
        ),
        Vente(
          id: 'v2',
          entrepriseId: entrepriseId,
          perimetreId: boutiqueId,
          date: aujourdhui,
          total: 40000,
          montantPaye: 40000,
          modePaiement: 'MOBILE_MONEY',
          numero: 'REC-20261008-002',
          lignes: const [
            LigneOperation(id: 'l2', produitId: 'p2', unite: 'pièce', facteur: Qte.un, quantite: Qte(20000), prixUnitaire: 20000),
          ],
        ),
        Vente(
          id: 'v3',
          entrepriseId: entrepriseId,
          perimetreId: boutiqueId,
          date: aujourdhui,
          total: 60000,
          montantPaye: 0,
          reglement: ReglementVente.credit,
          numero: 'REC-20261008-003',
          lignes: const [
            LigneOperation(id: 'l3', produitId: 'p1', unite: 'pièce', facteur: Qte.un, quantite: Qte(120000), prixUnitaire: 5000),
          ],
        ),
      ],
    );

    testWidgets('Accueil Vendeur affiche le prénom, la boutique, le bouton Nouvelle Vente et les KPIs', (tester) async {
      final ctx = contexte(
        role: 'VENDEUR',
        permissions: {'sales.create', 'sales.view'},
        perimetres: [perimetreJson(boutiqueId, nom: 'Boutique A')],
      );

      await pumpApp(
        tester,
        const HomePage(),
        overrides: [
          contexteActifProvider.overrideWithValue(ctx),
          entrepriseRepositoryProvider.overrideWithValue(FakeEntrepriseRepository()),
          etatCommerceProvider.overrideWith((ref) => Stream.value(etatVentes)),
        ],
        size: const Size(400, 1400),
      );

      expect(find.byType(WorkspaceVendeurAccueil), findsOneWidget);
      expect(find.text('Bonjour Awa'), findsOneWidget);
      expect(find.text('Boutique A'), findsOneWidget);
      expect(find.byKey(const Key('btn-nouvelle-vente-vendeur')), findsOneWidget);
      expect(find.text('NOUVELLE VENTE'), findsOneWidget);

      // KPIs
      expect(find.text('Ma journée'), findsOneWidget);
      expect(find.textContaining('125'), findsWidgets, reason: 'Total vendu calculé 25k + 40k + 60k');
      expect(find.text('3'), findsOneWidget, reason: '3 ventes');
      expect(find.text('19'), findsOneWidget, reason: '5 + 2 + 12 = 19 articles');
      expect(find.textContaining('41'), findsWidgets, reason: 'Panier moyen 125 000 / 3');

      // Modes de paiements
      expect(find.textContaining('Espèces'), findsWidgets);
      expect(find.textContaining('Mobile Money'), findsWidgets);
      expect(find.textContaining('crédit'), findsWidgets);

      // Ventes récentes
      expect(find.text('REC-20261008-001'), findsOneWidget);
      expect(find.text('REC-20261008-002'), findsOneWidget);
      expect(find.text('REC-20261008-003'), findsOneWidget);
    });

    testWidgets('Accueil Vendeur sans ventes : état vide clair avec CTA', (tester) async {
      final ctx = contexte(
        role: 'VENDEUR',
        permissions: {'sales.create', 'sales.view'},
        perimetres: [perimetreJson(boutiqueId, nom: 'Boutique A')],
      );

      await pumpApp(
        tester,
        const HomePage(),
        overrides: [
          contexteActifProvider.overrideWithValue(ctx),
          entrepriseRepositoryProvider.overrideWithValue(FakeEntrepriseRepository()),
          etatCommerceProvider.overrideWith((ref) => Stream.value(EtatCommerce())),
        ],
        size: const Size(400, 1400),
      );

      expect(find.text('Vous n\'avez pas encore effectué de vente aujourd\'hui.'), findsOneWidget);
      expect(find.text('0 FCFA'), findsWidgets);
    });
  });
}
