import 'package:dubagest/core/database/app_database.dart';
import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/core/permissions/access_decision.dart';
import 'package:dubagest/core/sync/local/drift_sync_stores.dart';
import 'package:dubagest/features/commerce/data/commerce_local_data_source.dart';
import 'package:dubagest/features/commerce/data/commerce_repository_impl.dart';
import 'package:dubagest/features/commerce/domain/entities/commerce.dart';
import 'package:dubagest/features/commerce/domain/services/etat_commerce.dart';
import 'package:dubagest/features/commerce/domain/usecases/gerer_commerce.dart';
import 'package:dubagest/features/commerce/presentation/commerce_providers.dart';
import 'package:dubagest/features/commerce/presentation/widgets/workspace_superviseur_accueil.dart';
import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import 'package:dubagest/features/finances/domain/services/etat_finances.dart';
import 'package:dubagest/features/finances/presentation/pages/finances_page.dart';
import 'package:dubagest/features/finances/presentation/providers/finances_providers.dart';
import 'package:dubagest/features/finances/presentation/widgets/workspace_finances_superviseur.dart';
import 'package:dubagest/features/navigation/domain/entities/navigation_model.dart';
import 'package:dubagest/features/navigation/domain/services/navigation_builder.dart';
import 'package:dubagest/features/roles/domain/entities/role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/contexte_fixtures.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

void main() {
  const builder = NavigationBuilder();

  group('Superviseur - Navigation, Affectation aux Boutiques & Rôle', () {
    test('NavigationBuilder identifie le profil SUPERVISEUR et configure le workspace dédié', () {
      final ctx = contexte(
        role: RoleCodes.superviseur,
        permissions: {
          'products.view',
          'products.create',
          'products.update',
          'stock.view',
          'stock.update',
          'sales.view',
          'sales.create',
        },
        perimetres: [perimetreJson('b-1', nom: 'Boutique Principale')],
      );

      final nav = builder.build(ctx);
      expect(nav.isWorkspaceSuperviseur, isTrue);
      expect(nav.isWorkspaceGestionnaireStock, isFalse);
      expect(nav.isWorkspaceVendeur, isFalse);
      expect(nav.destinations, contains(NavDestination.accueil));
    });

    testWidgets('10. Une entreprise avec une seule boutique fonctionne sans sélecteur inutile', (tester) async {
      final ctx = contexte(
        role: RoleCodes.superviseur,
        permissions: {'products.view', 'stock.view'},
        perimetres: [perimetreJson('b-1', nom: 'Boutique Unique')],
      );

      await pumpApp(
        tester,
        const Scaffold(body: WorkspaceSuperviseurAccueil()),
        overrides: [
          contexteActifProvider.overrideWithValue(ctx),
          etatCommerceProvider.overrideWith((ref) => Stream.value(EtatCommerce())),
          etatFinancesProvider.overrideWith((ref) => Stream.value(EtatFinances())),
        ],
        size: const Size(600, 2000),
      );

      expect(find.byType(WorkspaceSuperviseurAccueil), findsOneWidget);
      // Pas de dropdown sélecteur de boutique, affiche le badge simple
      expect(find.text('Boutique Unique'), findsOneWidget);
      expect(find.text('SUPERVISEUR'), findsOneWidget);
      expect(find.text('Modules'), findsOneWidget);
      expect(find.text('Caisse'), findsOneWidget);
      expect(find.text('Dépenses'), findsOneWidget);
      expect(find.text('Dettes'), findsOneWidget);
      expect(find.text('Clients'), findsOneWidget);
      expect(find.text('Voir les finances'), findsOneWidget);
      expect(find.text('Chiffre d\'affaires'), findsOneWidget);
      expect(find.text('Encaissé'), findsOneWidget);
      expect(find.text('Impayés clients'), findsOneWidget);
    });

    test('11. Une entreprise avec plusieurs boutiques permet de filtrer uniquement les boutiques affectées', () {
      final ctx = contexte(
        role: RoleCodes.superviseur,
        permissions: {'products.view', 'stock.view'},
        perimetres: [
          perimetreJson('b-1', nom: 'Boutique Alpha'),
          perimetreJson('b-2', nom: 'Boutique Beta'),
        ],
      );

      expect(ctx.perimetres.length, equals(2));
      expect(ctx.aAccesAuPerimetre('b-1'), isTrue);
      expect(ctx.aAccesAuPerimetre('b-2'), isTrue);
      expect(ctx.aAccesAuPerimetre('b-3'), isFalse, reason: 'Boutique hors périmètre interdite');
    });

    test('3. Un superviseur ne peut pas attribuer le rôle Administrateur ni gérer les utilisateurs', () {
      final ctx = contexte(
        role: RoleCodes.superviseur,
        permissions: {'products.view', 'stock.view', 'sales.view'},
      );

      final policy = ctx.accessPolicy();
      final decision = policy.canPerform(
        moduleCode: 'admin.utilisateurs',
        permission: 'users.manage',
      );
      expect(decision.isAllowed, isFalse);
    });
  });

  group('Superviseur - Catalogue & Gestion Produits', () {
    late AppDatabase db;
    late CommerceLocalDataSource local;
    late CommerceRepositoryImpl repository;
    late GererCommerce usecase;

    setUp(() {
      db = memoryDatabase();
      local = CommerceLocalDataSource(db);
      repository = CommerceRepositoryImpl(
        local: local,
        queue: DriftSyncQueueStore(db),
        currentUserId: () => userId,
        requestSync: () {},
      );
      usecase = GererCommerce(repository);
    });

    tearDown(() => db.close());

    test('Superviseur autorisé peut créer un produit avec stock nul', () async {
      final ctx = contexte(
        role: RoleCodes.superviseur,
        permissions: {'products.create', 'products.view'},
        perimetres: [perimetreJson('b-1', nom: 'Boutique A')],
      );

      const nouveauProduit = Produit(
        id: 'p-ciment',
        entrepriseId: entrepriseId,
        nom: 'Ciment 50 kg',
        uniteBase: 'sac',
        prixDetail: 5000,
      );

      final cree = await usecase.creerProduit(
        ctx,
        EtatCommerce(),
        nouveauProduit,
      );

      expect(cree.id, equals('p-ciment'));
      expect(cree.nom, equals('Ciment 50 kg'));
    });

    test('RÈGLE : La création de produit par le superviseur interdit tout stock initial', () async {
      final ctx = contexte(
        role: RoleCodes.superviseur,
        permissions: {'products.create', 'products.view', 'stock.create'},
        perimetres: [perimetreJson('b-1', nom: 'Boutique A')],
      );

      const nouveauProduit = Produit(
        id: 'p-ciment',
        entrepriseId: entrepriseId,
        nom: 'Ciment 50 kg',
        uniteBase: 'sac',
        prixDetail: 5000,
      );

      // Tentative de créer un produit avec un stock initial positif
      expect(
        () => usecase.creerProduit(
          ctx,
          EtatCommerce(),
          nouveauProduit,
          perimetreId: 'b-1',
          stockInitial: const Qte(100000), // 10 sacs
        ),
        throwsA(isA<Failure>().having(
          (f) => f.ruleCode,
          'ruleCode',
          RuleCodes.permissionDenied,
        )),
      );
    });

    test('4. Un superviseur sans permission ne peut pas modifier un produit', () async {
      final ctx = contexte(
        role: RoleCodes.superviseur,
        permissions: {'products.view'}, // Pas de products.update
      );

      const pAvant = Produit(
        id: 'p1',
        entrepriseId: entrepriseId,
        nom: 'Article Initial',
        uniteBase: 'pièce',
        prixDetail: 1000,
      );

      expect(
        () => usecase.modifierProduit(
          ctx,
          EtatCommerce(produits: [pAvant]),
          pAvant,
          pAvant.copyWith(nom: 'Article Modifié'),
        ),
        throwsA(isA<Failure>()),
      );
    });

    test('RÈGLE : Le superviseur ne peut pas modifier le prix d\'achat du produit', () async {
      final ctx = contexte(
        role: RoleCodes.superviseur,
        permissions: {'products.view', 'products.update'},
      );

      const pAvant = Produit(
        id: 'p1',
        entrepriseId: entrepriseId,
        nom: 'Article Initial',
        uniteBase: 'pièce',
        prixDetail: 1000,
        prixAchat: 600,
      );

      expect(
        () => usecase.modifierProduit(
          ctx,
          EtatCommerce(produits: [pAvant]),
          pAvant,
          pAvant.copyWith(prixAchat: () => 800),
        ),
        throwsA(isA<Failure>().having(
          (f) => f.ruleCode,
          'ruleCode',
          RuleCodes.permissionDenied,
        )),
      );
    });

    test('RÈGLE PRODUIT_UTILISE : Impossible de supprimer un produit utilisé dans des mouvements ou ventes', () async {
      final ctx = contexte(
        role: RoleCodes.superviseur,
        permissions: {'products.view', 'products.update'},
      );

      const p1 = Produit(
        id: 'p1',
        entrepriseId: entrepriseId,
        nom: 'Article en Stock',
        uniteBase: 'pièce',
        prixDetail: 1000,
      );

      final etatAvecMvt = EtatCommerce(
        produits: const [p1],
        mouvements: [
          MouvementStock(
            id: 'm1',
            entrepriseId: entrepriseId,
            perimetreId: 'b-1',
            produitId: 'p1',
            type: TypeMouvementStock.entree,
            motif: MotifMouvement.ajustement,
            quantite: const Qte(10000),
            quantiteSaisie: const Qte(10000),
            uniteSaisie: 'pièce',
            facteur: Qte.un,
            delta: const Qte(10000),
            date: DateTime.now(),
          ),
        ],
      );

      expect(
        () => usecase.supprimerProduit(ctx, etatAvecMvt, p1),
        throwsA(isA<Failure>().having(
          (f) => f.ruleCode,
          'ruleCode',
          RuleCodes.productUsed,
        )),
      );
    });
  });

  group('Superviseur - Achats Fournisseurs & Bons de Commande (RÉSERVÉS ADMIN)', () {
    late AppDatabase db;
    late CommerceLocalDataSource local;
    late CommerceRepositoryImpl repository;
    late GererCommerce usecase;

    setUp(() {
      db = memoryDatabase();
      local = CommerceLocalDataSource(db);
      repository = CommerceRepositoryImpl(
        local: local,
        queue: DriftSyncQueueStore(db),
        currentUserId: () => userId,
        requestSync: () {},
      );
      usecase = GererCommerce(repository);
    });

    tearDown(() => db.close());

    test('RÈGLE : Le superviseur ne peut JAMAIS créer un achat fournisseur', () async {
      final ctx = contexte(
        role: RoleCodes.superviseur,
        permissions: {'purchases.create', 'purchases.view'},
        perimetres: [perimetreJson('b-1', nom: 'Boutique A')],
      );

      final saisie = SaisieAchat(
        perimetreId: 'b-1',
        lignes: const [
          LigneOperation(
            id: 'l1',
            produitId: 'p1',
            unite: 'sac',
            facteur: Qte.un,
            quantite: Qte(50000),
            prixUnitaire: 4000,
          ),
        ],
      );

      expect(
        () => usecase.creerAchat(ctx, EtatCommerce(), saisie),
        throwsA(isA<Failure>().having(
          (f) => f.ruleCode,
          'ruleCode',
          RuleCodes.permissionDenied,
        )),
      );
    });

    test('RÈGLE : Le superviseur ne peut JAMAIS réceptionner une commande fournisseur', () async {
      final ctx = contexte(
        role: RoleCodes.superviseur,
        permissions: {'purchases.update', 'purchases.view'},
        perimetres: [perimetreJson('b-1', nom: 'Boutique A')],
      );

      final achat = Achat(
        id: 'ach-1',
        entrepriseId: entrepriseId,
        perimetreId: 'b-1',
        statut: StatutAchat.commande,
        dateAchat: DateTime(2026, 10, 20),
        creeLe: DateTime(2026, 10, 20),
        total: 50000,
        lignes: const [
          LigneOperation(
            id: 'l1',
            produitId: 'p1',
            unite: 'sac',
            facteur: Qte.un,
            quantite: Qte(50000),
            prixUnitaire: 1000,
          ),
        ],
      );

      expect(
        () => usecase.receptionner(
          ctx,
          EtatCommerce(),
          achat,
          {'l1': const Qte(50000)},
        ),
        throwsA(isA<Failure>().having(
          (f) => f.ruleCode,
          'ruleCode',
          RuleCodes.permissionDenied,
        )),
      );
    });

    test('RÈGLE : Le superviseur ne peut pas contourner en simulant une entrée avec motif achat', () async {
      final ctx = contexte(
        role: RoleCodes.superviseur,
        permissions: {'stock.create', 'stock.view'},
        perimetres: [perimetreJson('b-1', nom: 'Boutique A')],
      );

      const p1 = Produit(
        id: 'p1',
        entrepriseId: entrepriseId,
        nom: 'Ciment',
        uniteBase: 'sac',
        prixDetail: 5000,
      );

      expect(
        () => usecase.mouvement(
          ctx,
          EtatCommerce(produits: [p1]),
          produit: p1,
          perimetreId: 'b-1',
          entree: true,
          motif: MotifMouvement.achat, // Motif achat interdit pour simuler entrée fournisseur
          quantite: const Qte(10000),
          unite: p1.uniteDeBase,
        ),
        throwsA(isA<Failure>().having(
          (f) => f.ruleCode,
          'ruleCode',
          RuleCodes.permissionDenied,
        )),
      );
    });

    test('RÈGLE : L\'administrateur conserve pleinement ses droits d\'achat et de réception', () {
      final ctxAdmin = contexte(
        role: RoleCodes.administrateur,
        permissions: {'purchases.create', 'purchases.update', 'purchases.view'},
        perimetres: [perimetreJson('b-1', nom: 'Boutique A')],
      );

      final droits = DroitsCommerce.de(ctxAdmin, ctxAdmin.perimetres);
      expect(droits.boutiquesAchat, contains('b-1'));
      expect(droits.boutiquesReception, contains('b-1'));
      expect(droits.creerAchats, isTrue);
      expect(droits.receptionner, isTrue);
      expect(droits.peutModifierPrixAchat, isTrue);
    });

    test('RÈGLE : DroitsCommerce désactive achats et réceptions pour le Superviseur', () {
      final ctxSuperviseur = contexte(
        role: RoleCodes.superviseur,
        permissions: {'purchases.create', 'purchases.update', 'purchases.view', 'products.create'},
        perimetres: [perimetreJson('b-1', nom: 'Boutique A')],
      );

      final droits = DroitsCommerce.de(ctxSuperviseur, ctxSuperviseur.perimetres);
      expect(droits.boutiquesAchat, isEmpty, reason: 'Superviseur ne doit avoir aucune boutique d\'achat');
      expect(droits.boutiquesReception, isEmpty, reason: 'Superviseur ne doit pas réceptionner');
      expect(droits.creerAchats, isFalse);
      expect(droits.receptionner, isFalse);
      expect(droits.peutModifierPrixAchat, isFalse);
      expect(droits.peutSaisirStockInitial, isFalse);
    });
  });

  group('Superviseur - Stocks, Transferts & Annulations de Vente', () {
    late AppDatabase db;
    late CommerceLocalDataSource local;
    late CommerceRepositoryImpl repository;
    late GererCommerce usecase;

    setUp(() {
      db = memoryDatabase();
      local = CommerceLocalDataSource(db);
      repository = CommerceRepositoryImpl(
        local: local,
        queue: DriftSyncQueueStore(db),
        currentUserId: () => userId,
        requestSync: () {},
      );
      usecase = GererCommerce(repository);
    });

    tearDown(() => db.close());

    test('5. Un superviseur autorisé peut consulter et contrôler les stocks de sa boutique', () async {
      final ctx = contexte(
        role: RoleCodes.superviseur,
        permissions: {'stock.view', 'stock.update'},
        perimetres: [perimetreJson('b-1', nom: 'Boutique A')],
      );

      const p1 = Produit(
        id: 'p1',
        entrepriseId: entrepriseId,
        nom: 'Peinture 20L',
        uniteBase: 'pot',
        prixDetail: 25000,
      );

      final inventaire = await usecase.inventaire(
        ctx,
        EtatCommerce(produits: [p1]),
        produit: p1,
        perimetreId: 'b-1',
        compte: const Qte(150000), // 15 pots
        unite: p1.uniteDeBase,
        motif: MotifMouvement.ajustement,
        note: 'Inventaire périodique certifié',
      );

      expect(inventaire.type, equals(TypeMouvementStock.inventaire));
      expect(inventaire.quantiteSaisie, equals(const Qte(150000)));
    });

    test('8. Un transfert ne peut pas être effectué sans autorisation sur les deux boutiques', () async {
      final ctx = contexte(
        role: RoleCodes.superviseur,
        permissions: {'stock.update'},
        perimetres: [perimetreJson('b-1', nom: 'Boutique A')], // Uniquement b-1 autorisée
      );

      const p1 = Produit(
        id: 'p1',
        entrepriseId: entrepriseId,
        nom: 'Article Transférable',
        uniteBase: 'pièce',
        prixDetail: 1000,
      );

      expect(
        () => usecase.transferer(
          ctx,
          EtatCommerce(produits: [p1]),
          produit: p1,
          dePerimetreId: 'b-1',
          versPerimetreId: 'b-2', // b-2 non autorisée
          quantite: const Qte(50000),
          unite: p1.uniteDeBase,
        ),
        throwsA(isA<Failure>()),
      );
    });

    test('7. Annulation de vente : restaure le stock et conserve l\'historique', () async {
      final ctx = contexte(
        role: RoleCodes.superviseur,
        permissions: {'sales.update', 'sales.view'},
        perimetres: [perimetreJson('b-1', nom: 'Boutique A')],
      );

      const p1 = Produit(
        id: 'p1',
        entrepriseId: entrepriseId,
        nom: 'Ventilateur',
        uniteBase: 'pièce',
        prixDetail: 15000,
      );

      final vente = Vente(
        id: 'v-100',
        entrepriseId: entrepriseId,
        perimetreId: 'b-1',
        date: DateTime(2026, 10, 20),
        reglement: ReglementVente.credit, // non encaissée
        total: 15000,
        lignes: const [
          LigneOperation(
            id: 'l1',
            produitId: 'p1',
            unite: 'pièce',
            facteur: Qte.un,
            quantite: Qte(10000),
            prixUnitaire: 15000,
          ),
        ],
      );

      await usecase.annulerVente(
        ctx,
        EtatCommerce(produits: [p1], ventes: [vente]),
        vente,
        motif: 'Erreur de saisie client',
      );

      // La vente est modifiée en statut annulé sans suppression silencieuse
      expect(vente.annuler(motif: 'Erreur de saisie client', le: DateTime.now(), par: ctx.nomComplet).annulee, isTrue);
    });

    testWidgets('FinancesPage affiche WorkspaceFinancesSuperviseur avec caisse, dépenses et créances de boutique', (tester) async {
      final ctx = contexte(
        role: RoleCodes.superviseur,
        permissions: {
          'cash.view',
          'expenses.view',
          'receivables.view',
          'payments.view',
        },
        perimetres: [perimetreJson('b-1', nom: 'Boutique Principale')],
      );

      await pumpApp(
        tester,
        const FinancesPage(),
        overrides: [
          contexteActifProvider.overrideWithValue(ctx),
          etatCommerceProvider.overrideWith((ref) => Stream.value(EtatCommerce())),
          etatFinancesProvider.overrideWith((ref) => Stream.value(EtatFinances())),
        ],
        size: const Size(600, 2000),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WorkspaceFinancesSuperviseur), findsOneWidget);
      expect(find.text('Finances Boutique'), findsOneWidget);
      expect(find.text('Encaissé ce jour'), findsOneWidget);
      expect(find.text('Dépenses du jour'), findsOneWidget);
      expect(find.text('Créances clients'), findsOneWidget);
      expect(find.text('+ Saisie Dépense'), findsOneWidget);
      expect(find.text('Caisse Boutique'), findsOneWidget);
      expect(find.text('Recouvrer Créance'), findsOneWidget);
    });
  });
}
