import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/core/permissions/access_decision.dart';
import 'package:dubagest/core/sync/local/drift_sync_stores.dart';
import 'package:dubagest/features/commerce/data/commerce_local_data_source.dart';
import 'package:dubagest/features/commerce/data/commerce_repository_impl.dart';
import 'package:dubagest/features/commerce/domain/entities/commerce.dart';
import 'package:dubagest/features/commerce/domain/services/etat_commerce.dart';
import 'package:dubagest/features/commerce/domain/usecases/gerer_commerce.dart';
import 'package:dubagest/features/commerce/presentation/commerce_providers.dart';
import 'package:dubagest/features/commerce/presentation/widgets/choix_produit.dart';
import 'package:dubagest/features/commerce/presentation/widgets/operation_stock.dart';
import 'package:dubagest/features/commerce/presentation/widgets/workspace_gestionnaire_stock_accueil.dart';
import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import 'package:dubagest/features/navigation/domain/entities/navigation_model.dart';
import 'package:dubagest/features/navigation/domain/services/navigation_builder.dart';
import 'package:dubagest/features/navigation/presentation/pages/home_page.dart';
import 'package:dubagest/features/finances/presentation/pages/finances_page.dart';
import 'package:dubagest/features/roles/domain/entities/role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/contexte_fixtures.dart';
import '../../helpers/fake_entreprise_repository.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

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
      expect(find.byKey(const Key('btn-action-alertes')), findsOneWidget);
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

    testWidgets('Étanchéité multi-boutiques : un produit exclusif à Boutique B ne pollue pas les alertes de Boutique A', (tester) async {
      const boutiqueA = 'b-1';
      const boutiqueB = 'b-2';

      const prodExclusifB = Produit(
        id: 'p-b',
        entrepriseId: entrepriseId,
        nom: 'Produit Spécial Boutique B',
        uniteBase: 'pièce',
        prixDetail: 10000,
        seuilAlerte: Qte(100000),
        attributs: {'perimetre_id': boutiqueB},
      );

      final etatMulti = EtatCommerce(
        produits: const [p1, prodExclusifB],
        stocks: const [
          StockBoutique(
            perimetreId: boutiqueA,
            produitId: 'p1',
            quantite: Qte(1000000), // En stock pour A
          ),
          StockBoutique(
            perimetreId: boutiqueB,
            produitId: 'p-b',
            quantite: Qte(0), // Rupture dans B
          ),
        ],
      );

      // Gestionnaire affecté uniquement à Boutique A
      final ctxA = contexte(
        role: RoleCodes.gestionnaireStock,
        permissions: {'stock.view', 'stock.create', 'stock.update'},
        perimetres: [perimetreJson(boutiqueA, nom: 'Boutique A')],
      );

      await pumpApp(
        tester,
        const HomePage(),
        overrides: [
          contexteActifProvider.overrideWithValue(ctxA),
          entrepriseRepositoryProvider.overrideWithValue(FakeEntrepriseRepository()),
          etatCommerceProvider.overrideWith((ref) => Stream.value(etatMulti)),
        ],
        size: const Size(400, 1400),
      );
      await tester.pumpAndSettle();

      // Dans Boutique A, aucun produit n'est en alerte (car p1 est sain, et prodExclusifB n'appartient pas à A)
      expect(find.text('Produit Spécial Boutique B'), findsNothing);
      expect(find.text('Tout va bien'), findsOneWidget);
    });

    testWidgets('Carte Valeur Totale du Stock affiche la valorisation marchande et les totaux', (tester) async {
      final ctx = contexte(
        role: RoleCodes.gestionnaireStock,
        permissions: {'stock.view', 'stock.create'},
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
        size: const Size(360, 1200),
      );
      await tester.pumpAndSettle();

      // Vérifie la carte de valorisation du stock
      expect(find.byKey(const Key('card-valeur-totale-stock')), findsOneWidget);
      expect(find.text('VALEUR TOTALE DU STOCK'), findsOneWidget);
      expect(find.text('Valorisation marchande immobilisée'), findsOneWidget);
      expect(find.textContaining('références gérées'), findsOneWidget);

      // Vérifie l'absence formelle de toute donnée financière sensible (dépenses / encaissements généraux)
      expect(find.text('Dépenses du mois'), findsNothing);
      expect(find.text('Encaissements du jour'), findsNothing);
      expect(find.text('Impayés clients'), findsNothing);
    });

    testWidgets('FinancesPage bloque formellement le Gestionnaire de Stock et masque les dépenses', (tester) async {
      final ctx = contexte(
        role: RoleCodes.gestionnaireStock,
        permissions: {'stock.view'},
      );

      await pumpApp(
        tester,
        const FinancesPage(),
        overrides: [
          contexteActifProvider.overrideWithValue(ctx),
          entrepriseRepositoryProvider.overrideWithValue(FakeEntrepriseRepository()),
        ],
        size: const Size(400, 800),
      );
      await tester.pumpAndSettle();

      // L'écran d'accès restreint est affiché sans aucune donnée financière
      expect(find.text('Accès Restreint — Espace Stock'), findsOneWidget);
      expect(find.textContaining('La consultation des dépenses'), findsOneWidget);
      expect(find.text('Retour à l\'accueil Stock'), findsOneWidget);
      expect(find.text('Dépenses'), findsNothing);
      expect(find.text('Trésorerie'), findsNothing);
    });

    testWidgets('Feuille de choix produit (actions rapides) ne présente aucun débordement (zéro overflow)', (tester) async {
      const p3 = Produit(
        id: 'p3',
        entrepriseId: entrepriseId,
        nom: 'Montre Luxe Sport Étanche',
        uniteBase: 'pièce',
        prixDetail: 25000,
        seuilAlerte: Qte(500000),
      );

      final etatTroisProduits = EtatCommerce(
        produits: const [p1, p2, p3],
        stocks: const [
          StockBoutique(perimetreId: boutiqueId, produitId: 'p1', quantite: Qte(600000)),
          StockBoutique(perimetreId: boutiqueId, produitId: 'p2', quantite: Qte(10000)),
          StockBoutique(perimetreId: boutiqueId, produitId: 'p3', quantite: Qte(50000)),
        ],
      );

      final ctx = contexte(
        role: RoleCodes.gestionnaireStock,
        permissions: {'stock.view', 'stock.create'},
        perimetres: [perimetreJson(boutiqueId, nom: 'Boutique A')],
      );

      await pumpApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => choisirProduit(
                  context,
                  titre: 'Choisir le produit à entrer',
                  boutiqueId: boutiqueId,
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
        overrides: [
          contexteActifProvider.overrideWithValue(ctx),
          entrepriseRepositoryProvider.overrideWithValue(FakeEntrepriseRepository()),
          etatCommerceProvider.overrideWith((ref) => Stream.value(etatTroisProduits)),
        ],
        size: const Size(360, 740),
      );
      await tester.pumpAndSettle();

      // Ouvre la feuille modale
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      // Vérifie que les produits sont bien visibles
      expect(find.text('Choisir le produit à entrer'), findsOneWidget);
      expect(find.text('Carreau Blanc 60x60'), findsOneWidget);
      expect(find.text('Ciment 50kg'), findsOneWidget);
      expect(find.text('Montre Luxe Sport Étanche'), findsOneWidget);

      // Vérifie l'absence absolue d'erreur de rendu / overflow
      expect(tester.takeException(), isNull);
    });
  });

  group('Contrôles Professionnels - Sorties & Inventaire Stock', () {
    const boutiqueId = 'b-1';
    const produitA = Produit(
      id: 'p-1',
      entrepriseId: entrepriseId,
      nom: 'Article Test',
      uniteBase: 'pièce',
      prixAchat: 1000,
      prixDetail: 1500,
    );

    final etatCommerce = EtatCommerce(
      produits: const [produitA],
      stocks: const [
        StockBoutique(perimetreId: boutiqueId, produitId: 'p-1', quantite: Qte(50000)), // 5 pièces
      ],
    );

    test('Le Gestionnaire de stock ne peut pas effectuer de sortie directe libre (SORTIE_DIRECTE_INTERDITE)', () async {
      final ctx = contexte(
        role: RoleCodes.gestionnaireStock,
        permissions: {'stock.view', 'stock.create', 'stock.update'},
        perimetres: [perimetreJson(boutiqueId, nom: 'Boutique A')],
      );
      final db = memoryDatabase();
      final local = CommerceLocalDataSource(db);
      final queue = DriftSyncQueueStore(db);
      final usecase = GererCommerce(CommerceRepositoryImpl(
        local: local,
        queue: queue,
        currentUserId: () => 'user-1',
        requestSync: () {},
      ));

      // 1. Entrée autorisée
      final mEntree = await usecase.mouvement(
        ctx,
        etatCommerce,
        produit: produitA,
        perimetreId: boutiqueId,
        entree: true,
        motif: MotifMouvement.achat,
        quantite: const Qte(20000),
        unite: produitA.uniteDeBase,
      );
      expect(mEntree.type, TypeMouvementStock.entree);

      // 2. Sortie libre directe INTERDITE pour gestionnaire de stock
      expect(
        () => usecase.mouvement(
          ctx,
          etatCommerce,
          produit: produitA,
          perimetreId: boutiqueId,
          entree: false,
          motif: MotifMouvement.perte,
          quantite: const Qte(10000),
          unite: produitA.uniteDeBase,
        ),
        throwsA(isA<Failure>().having((f) => f.ruleCode, 'ruleCode', RuleCodes.permissionDenied)),
      );

      await db.close();
    });

    test('L\'inventaire exige formellement une note explicative en cas d\'écart négatif', () async {
      final ctx = contexte(
        role: RoleCodes.gestionnaireStock,
        permissions: {'stock.view', 'stock.create', 'stock.update'},
        perimetres: [perimetreJson(boutiqueId, nom: 'Boutique A')],
      );
      final db = memoryDatabase();
      final local = CommerceLocalDataSource(db);
      final queue = DriftSyncQueueStore(db);
      final usecase = GererCommerce(CommerceRepositoryImpl(
        local: local,
        queue: queue,
        currentUserId: () => 'user-1',
        requestSync: () {},
      ));

      // Écart négatif sans justification -> refusé
      expect(
        () => usecase.inventaire(
          ctx,
          etatCommerce,
          produit: produitA,
          perimetreId: boutiqueId,
          compte: const Qte(20000), // 2 comptés au lieu de 5 -> écart -3
          unite: produitA.uniteDeBase,
          motif: MotifMouvement.perte,
          note: null,
        ),
        throwsA(isA<Failure>().having((f) => f.ruleCode, 'ruleCode', RuleCodes.discrepancyJustificationRequired)),
      );

      // Écart négatif avec justification -> validé
      final mInv = await usecase.inventaire(
        ctx,
        etatCommerce,
        produit: produitA,
        perimetreId: boutiqueId,
        compte: const Qte(20000),
        unite: produitA.uniteDeBase,
        motif: MotifMouvement.perte,
        note: 'Casse constatée lors du rangement en rayon',
      );
      expect(mInv.type, TypeMouvementStock.inventaire);
      expect(mInv.note, 'Casse constatée lors du rangement en rayon');

      await db.close();
    });

    testWidgets('Comptage à l\'aveugle activé pour Gestionnaire de Stock dans la feuille d\'inventaire', (tester) async {
      final ctxGestionnaire = contexte(
        role: RoleCodes.gestionnaireStock,
        permissions: {'stock.view', 'stock.create', 'stock.update'},
        perimetres: [perimetreJson(boutiqueId, nom: 'Boutique A')],
      );

      await pumpApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => ouvrirOperationStock(
                  context,
                  produit: produitA,
                  operation: OperationStock.inventaire,
                  perimetreId: boutiqueId,
                ),
                child: const Text('Inventaire'),
              ),
            ),
          ),
        ),
        overrides: [
          contexteActifProvider.overrideWithValue(ctxGestionnaire),
          entrepriseRepositoryProvider.overrideWithValue(FakeEntrepriseRepository()),
          etatCommerceProvider.overrideWith((ref) => Stream.value(etatCommerce)),
        ],
        size: const Size(400, 900),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Inventaire'));
      await tester.pumpAndSettle();

      // Vérifie l'activation du comptage à l'aveugle
      expect(find.text('Comptage à l\'aveugle'), findsOneWidget);
      expect(find.textContaining('En stock :'), findsNothing);
      expect(find.textContaining('Même stock'), findsNothing);
      expect(find.text('0 (Rupture)'), findsOneWidget);
    });
  });
}
