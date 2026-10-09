import 'package:dubagest/features/commerce/domain/entities/commerce.dart';
import 'package:dubagest/features/commerce/domain/entities/quantite.dart';
import 'package:dubagest/features/commerce/domain/services/etat_commerce.dart';
import 'package:dubagest/features/commerce/presentation/commerce_providers.dart';
import 'package:dubagest/features/commerce/presentation/widgets/workspace_gestionnaire_stock_accueil.dart';
import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import 'package:dubagest/features/navigation/domain/entities/navigation_model.dart';
import 'package:dubagest/features/navigation/domain/services/navigation_builder.dart';
import 'package:dubagest/features/navigation/presentation/pages/home_page.dart';
import 'package:dubagest/features/roles/domain/entities/role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/contexte_fixtures.dart';
import '../../helpers/fake_entreprise_repository.dart';
import '../../helpers/pump_app.dart';

void main() {
  const builder = NavigationBuilder();

  group('Workspace Gestionnaire de Stock - Navigation & Permissions', () {
    test('NavigationBuilder identifie le profil GESTIONNAIRE_STOCK et configure le workspace dédié', () {
      final ctx = contexte(
        role: RoleCodes.gestionnaireStock,
        permissions: {'stock.view', 'stock.create', 'stock.update', 'products.view'},
        perimetres: [perimetreJson('b-1', nom: 'Boutique A')],
      );

      final nav = builder.build(ctx);
      expect(nav.isWorkspaceGestionnaireStock, isTrue);
      expect(nav.isWorkspaceVendeur, isFalse);
      expect(nav.destinations, contains(NavDestination.accueil));
      expect(nav.destinations, contains(NavDestination.compte));
      expect(nav.modulesFinances, isEmpty, reason: 'Pas d\'accès direct aux finances globales pour le gestionnaire');
      expect(nav.modulesAdministration.where((m) => m.code == 'admin.utilisateurs'), isEmpty);
    });

    test('Sans droit de consultation stock, le workspace gestionnaire n\'est pas activé', () {
      final ctx = contexte(role: RoleCodes.gestionnaireStock, permissions: {'contacts.view'});
      final nav = builder.build(ctx);
      expect(nav.isWorkspaceGestionnaireStock, isFalse);
    });
  });

  group('Workspace Gestionnaire de Stock - Interface Accueil & KPIs', () {
    final aujourdhui = DateTime.now();
    const boutiqueId = 'b-1';

    const p1 = Produit(
      id: 'p1',
      entrepriseId: entrepriseId,
      nom: 'Carreau Blanc 60x60',
      uniteBase: 'pièce',
      reference: 'CAR-6060',
      prixAchat: 3500,
      prixDetail: 5000,
      seuilAlerte: Qte(500000), // Seuil 50
    );

    const p2 = Produit(
      id: 'p2',
      entrepriseId: entrepriseId,
      nom: 'Ciment 50kg',
      uniteBase: 'sac',
      reference: 'CIM-50',
      prixAchat: 4000,
      prixDetail: 4800,
      seuilAlerte: Qte(200000), // Seuil 20
    );

    final etatStock = EtatCommerce(
      produits: const [p1, p2],
      mouvements: [
        MouvementStock(
          id: 'm1',
          entrepriseId: entrepriseId,
          perimetreId: boutiqueId,
          produitId: 'p1',
          date: aujourdhui,
          type: TypeMouvementStock.entree,
          motif: MotifMouvement.achat,
          quantite: const Qte(600000),
          quantiteSaisie: const Qte(600000),
          uniteSaisie: 'pièce',
          facteur: Qte.un,
          delta: const Qte(600000), // +60
          stockAvant: Qte.zero,
          stockApres: const Qte(600000),
          auteurNom: 'Moussa',
        ),
        MouvementStock(
          id: 'm2',
          entrepriseId: entrepriseId,
          perimetreId: boutiqueId,
          produitId: 'p2',
          date: aujourdhui,
          type: TypeMouvementStock.sortie,
          motif: MotifMouvement.casse,
          quantite: const Qte(50000),
          quantiteSaisie: const Qte(50000),
          uniteSaisie: 'sac',
          facteur: Qte.un,
          delta: const Qte(-50000), // -5
          stockAvant: Qte.zero,
          stockApres: const Qte(-50000),
          auteurNom: 'Moussa',
        ),
      ],
      stocks: const [
        StockBoutique(
          perimetreId: boutiqueId,
          produitId: 'p1',
          quantite: Qte(600000), // 60 > 50 -> En stock
        ),
        StockBoutique(
          perimetreId: boutiqueId,
          produitId: 'p2',
          quantite: Qte(-50000), // <= 0 -> Rupture
        ),
      ],
    );

    testWidgets('Accueil Gestionnaire affiche la boutique, les 4 KPIs et les 4 actions rapides', (tester) async {
      final ctx = contexte(
        role: RoleCodes.gestionnaireStock,
        permissions: {'stock.view', 'stock.create', 'stock.update', 'products.view'},
        perimetres: [perimetreJson(boutiqueId, nom: 'Boutique A')],
      );

      await pumpApp(
        tester,
        const HomePage(),
        overrides: [
          contexteActifProvider.overrideWithValue(ctx),
          entrepriseRepositoryProvider.overrideWithValue(FakeEntrepriseRepository()),
          etatCommerceProvider.overrideWith((ref) => Stream.value(etatStock)),
        ],
        size: const Size(400, 1400),
      );
      await tester.pumpAndSettle();

      // Vérifie la présence du workspace dédié
      expect(find.byType(WorkspaceGestionnaireStockAccueil), findsOneWidget);
      expect(find.text('Boutique A'), findsOneWidget);

      // Vérifie les 4 KPIs
      expect(find.byKey(const Key('kpi-stock-faible')), findsOneWidget);
      expect(find.byKey(const Key('kpi-stock-rupture')), findsOneWidget);
      expect(find.byKey(const Key('kpi-stock-mouvements')), findsOneWidget);
      expect(find.byKey(const Key('kpi-stock-produits')), findsOneWidget);

      // Vérifie les 4 boutons d'action rapide
      expect(find.byKey(const Key('btn-action-entree')), findsOneWidget);
      expect(find.byKey(const Key('btn-action-sortie')), findsOneWidget);
      expect(find.byKey(const Key('btn-action-transfert')), findsOneWidget);
      expect(find.byKey(const Key('btn-action-inventaire')), findsOneWidget);

      // Vérifie la détection de rupture pour le Ciment
      expect(find.text('Ciment 50kg'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Rupture'), findsAtLeastNWidgets(1));
    });

    testWidgets('État rassurant affiché lorsque le stock est sain sans alerte', (tester) async {
      final ctx = contexte(
        role: RoleCodes.gestionnaireStock,
        permissions: {'stock.view', 'stock.create'},
        perimetres: [perimetreJson(boutiqueId, nom: 'Boutique A')],
      );

      final etatSain = EtatCommerce(
        produits: const [p1],
        stocks: const [
          StockBoutique(
            perimetreId: boutiqueId,
            produitId: 'p1',
            quantite: Qte(1000000), // 100 > seuil 50
          ),
        ],
      );

      await pumpApp(
        tester,
        const HomePage(),
        overrides: [
          contexteActifProvider.overrideWithValue(ctx),
          entrepriseRepositoryProvider.overrideWithValue(FakeEntrepriseRepository()),
          etatCommerceProvider.overrideWith((ref) => Stream.value(etatSain)),
        ],
        size: const Size(400, 1400),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tout va bien'), findsOneWidget);
      expect(find.text('Aucun produit n\'est actuellement sous son seuil minimum.'), findsOneWidget);
    });
  });
}
