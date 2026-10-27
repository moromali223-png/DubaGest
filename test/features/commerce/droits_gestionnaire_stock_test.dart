import 'package:dubagest/features/activites/domain/entities/activite.dart';
import 'package:dubagest/features/commerce/domain/entities/commerce.dart';
import 'package:dubagest/features/commerce/domain/services/etat_commerce.dart';
import 'package:dubagest/features/commerce/presentation/commerce_providers.dart';
import 'package:dubagest/features/commerce/presentation/pages/produit_form_page.dart';
import 'package:dubagest/features/commerce/presentation/pages/produit_page.dart';
import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import 'package:dubagest/features/perimetres/domain/entities/perimetre.dart';
import 'package:dubagest/features/roles/domain/entities/role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/contexte_fixtures.dart';
import '../../helpers/pump_app.dart';

void main() {
  group('DroitsCommerce - Ségrégation Administrateur vs Gestionnaire de Stock', () {
    const boutiqueA = Perimetre(
      id: 'b-1',
      entrepriseId: entrepriseId,
      nom: 'Boutique A',
      code: 'BA',
      activite: ActiviteCode.commerce,
      type: PerimetreType.boutique,
    );
    const boutiqueB = Perimetre(
      id: 'b-2',
      entrepriseId: entrepriseId,
      nom: 'Boutique B',
      code: 'BB',
      activite: ActiviteCode.commerce,
      type: PerimetreType.boutique,
    );

    test('Gestionnaire de Stock : a le droit d\'éditer prix de vente mais PAS prix d\'achat, ni gros, ni conversions, ni archiver', () {
      final ctxGestionnaire = contexte(
        role: RoleCodes.gestionnaireStock,
        permissions: {
          'products.view',
          'products.create',
          'products.update',
          'stock.view',
          'stock.create',
          'stock.update',
        },
        perimetres: [
          perimetreJson('b-1', nom: 'Boutique A'),
        ],
      );

      final droits = DroitsCommerce.de(ctxGestionnaire, [boutiqueA]);

      expect(droits.peutModifierPrixVente, isTrue, reason: 'Gestionnaire peut modifier prix de vente');
      expect(droits.peutModifierPrixAchat, isFalse, reason: 'Gestionnaire n\'a pas accès au prix d\'achat');
      expect(droits.peutModifierPrixGros, isFalse, reason: 'Gestionnaire n\'a pas accès au prix de gros');
      expect(droits.peutModifierConversions, isFalse, reason: 'Gestionnaire n\'a pas accès aux règles de conversion');
      expect(droits.peutArchiverProduits, isFalse, reason: 'Gestionnaire ne peut pas archiver un produit');
      expect(droits.peutDefinirPerimetreMultiBoutiques, isFalse, reason: 'Gestionnaire ne configure pas le catalogue multi-boutiques');
    });

    test('Administrateur : a tous les droits d\'écriture (achat, vente, gros, conversions, archivage, multi-boutiques)', () {
      final ctxAdmin = contexte(
        role: RoleCodes.administrateur,
        permissions: {
          'products.view',
          'products.create',
          'products.update',
          'products.delete',
          'stock.view',
          'stock.create',
          'stock.update',
        },
        perimetres: [
          perimetreJson('b-1', nom: 'Boutique A'),
          perimetreJson('b-2', nom: 'Boutique B'),
        ],
      );

      final droits = DroitsCommerce.de(ctxAdmin, [boutiqueA, boutiqueB]);

      expect(droits.peutModifierPrixVente, isTrue);
      expect(droits.peutModifierPrixAchat, isTrue);
      expect(droits.peutModifierPrixGros, isTrue);
      expect(droits.peutModifierConversions, isTrue);
      expect(droits.peutArchiverProduits, isTrue);
      expect(droits.peutDefinirPerimetreMultiBoutiques, isTrue);
    });
  });

  group('Produit Entity - Périmètres multi-boutiques', () {
    test('Produit sans périmètre est un produit global visible partout', () {
      const p = Produit(
        id: 'p-global',
        entrepriseId: entrepriseId,
        nom: 'Cahier 200p',
        uniteBase: 'pièce',
      );

      expect(p.estGlobal, isTrue);
      expect(p.estVisibleDansBoutique('b-1'), isTrue);
      expect(p.estVisibleDansBoutique('b-2'), isTrue);
    });

    test('Produit assigné à plusieurs boutiques spécifiques (perimetres_ids: b-1,b-2)', () {
      const p = Produit(
        id: 'p-multi',
        entrepriseId: entrepriseId,
        nom: 'Peinture Blanche',
        uniteBase: 'pot',
        attributs: {
          'perimetres_ids': 'b-1,b-2',
          'perimetre_id': 'b-1',
        },
      );

      expect(p.estGlobal, isFalse);
      expect(p.perimetresIds, equals(['b-1', 'b-2']));
      expect(p.estVisibleDansBoutique('b-1'), isTrue);
      expect(p.estVisibleDansBoutique('b-2'), isTrue);
      expect(p.estVisibleDansBoutique('b-3'), isFalse);
    });
  });

  group('ProduitFormPage UI - Adaptation selon le rôle', () {
    Future<void> toucher(WidgetTester tester, Finder f) async {
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    testWidgets('Gestionnaire de Stock : formulaire n\'affiche pas le prix d\'achat, ni gros, ni ajout d\'emballage', (tester) async {
      final ctxGestionnaire = contexte(
        role: RoleCodes.gestionnaireStock,
        permissions: {
          'products.view',
          'products.create',
          'products.update',
          'stock.view',
        },
        perimetres: [
          perimetreJson('b-1', nom: 'Boutique A'),
          perimetreJson('b-2', nom: 'Boutique B'),
        ],
      );

      await pumpApp(
        tester,
        const ProduitFormPage(),
        size: const Size(400, 1000),
        overrides: [
          contexteActifProvider.overrideWithValue(ctxGestionnaire),
          etatCommerceProvider.overrideWith((ref) => Stream.value(EtatCommerce())),
        ],
      );
      await tester.pumpAndSettle();

      // Étape 1 : Conversions verrouillées (pas de bouton ajouter unité)
      expect(find.byKey(const Key('unite-ajouter')), findsNothing, reason: 'Gestionnaire ne peut pas modifier conversions');

      // Renseigner nom et aller à l'étape 2
      await tester.enterText(find.byKey(const Key('produit-nom')), 'Huile 1L');
      await tester.pumpAndSettle();
      await toucher(tester, find.byKey(const Key('produit-suivant')));

      // Étape 2 : Prix de vente visible et modifiable
      expect(find.byKey(const Key('prix-detail')), findsOneWidget, reason: 'Prix de vente modifiable');

      // Prix d'achat, gros et configuration périmètre masqués
      expect(find.byKey(const Key('prix-achat')), findsNothing, reason: 'Prix d\'achat masqué au gestionnaire');
      expect(find.byKey(const Key('produit-gros')), findsNothing, reason: 'Vente en gros masquée au gestionnaire');
      expect(find.byKey(const Key('perimetre-global')), findsNothing, reason: 'Périmètre non configurable par le gestionnaire');
    });

    testWidgets('Administrateur : formulaire affiche le prix d\'achat, le gros, les conversions et le choix multi-boutiques', (tester) async {
      final ctxAdmin = contexte(
        role: RoleCodes.administrateur,
        permissions: {
          'products.view',
          'products.create',
          'products.update',
          'stock.view',
        },
        perimetres: [
          perimetreJson('b-1', nom: 'Boutique A'),
          perimetreJson('b-2', nom: 'Boutique B'),
        ],
      );

      await pumpApp(
        tester,
        const ProduitFormPage(),
        size: const Size(400, 1000),
        overrides: [
          contexteActifProvider.overrideWithValue(ctxAdmin),
          etatCommerceProvider.overrideWith((ref) => Stream.value(EtatCommerce())),
        ],
      );
      await tester.pumpAndSettle();

      // Étape 1 : Conversions accessibles
      expect(find.byKey(const Key('unite-ajouter')), findsOneWidget);

      // Renseigner nom et aller à l'étape 2
      await tester.enterText(find.byKey(const Key('produit-nom')), 'Huile 1L');
      await tester.pumpAndSettle();
      await toucher(tester, find.byKey(const Key('produit-suivant')));

      // Étape 2 : Tous les champs de prix et choix multi-boutiques sont présents
      expect(find.byKey(const Key('prix-detail')), findsOneWidget);
      expect(find.byKey(const Key('prix-achat')), findsOneWidget);
      expect(find.byKey(const Key('produit-gros')), findsOneWidget);
      expect(find.byKey(const Key('perimetre-global')), findsOneWidget);
      expect(find.byKey(const Key('perimetre-specifique')), findsOneWidget);
    });
  });

  group('ProduitPage UI - Droits d\'archivage', () {
    const produitExemple = Produit(
      id: 'p-test',
      entrepriseId: entrepriseId,
      nom: 'Article Exemple',
      uniteBase: 'pièce',
      prixDetail: 2500,
      prixAchat: 1800,
    );

    testWidgets('Gestionnaire de Stock : menu Archiver n\'est pas disponible', (tester) async {
      final ctxGestionnaire = contexte(
        role: RoleCodes.gestionnaireStock,
        permissions: {'products.view', 'products.update'},
        perimetres: [perimetreJson('b-1', nom: 'Boutique A')],
      );

      await pumpApp(
        tester,
        const ProduitPage(produitId: 'p-test'),
        size: const Size(400, 900),
        overrides: [
          contexteActifProvider.overrideWithValue(ctxGestionnaire),
          etatCommerceProvider.overrideWith((ref) => Stream.value(EtatCommerce(produits: const [produitExemple]))),
        ],
      );
      await tester.pumpAndSettle();

      // Le bouton plus_vert
      final menuMore = find.byType(PopupMenuButton<String>);
      if (menuMore.evaluate().isNotEmpty) {
        await tester.tap(menuMore);
        await tester.pumpAndSettle();
        expect(find.text('Archiver'), findsNothing);
      } else {
        expect(find.text('Archiver'), findsNothing);
      }
    });

    testWidgets('Administrateur : menu Archiver est disponible', (tester) async {
      final ctxAdmin = contexte(
        role: RoleCodes.administrateur,
        permissions: {'products.view', 'products.update', 'products.delete'},
        perimetres: [perimetreJson('b-1', nom: 'Boutique A')],
      );

      await pumpApp(
        tester,
        const ProduitPage(produitId: 'p-test'),
        size: const Size(400, 900),
        overrides: [
          contexteActifProvider.overrideWithValue(ctxAdmin),
          etatCommerceProvider.overrideWith((ref) => Stream.value(EtatCommerce(produits: const [produitExemple]))),
        ],
      );
      await tester.pumpAndSettle();

      final menuMore = find.byType(PopupMenuButton<String>);
      expect(menuMore, findsOneWidget);
      await tester.tap(menuMore);
      await tester.pumpAndSettle();

      expect(find.text('Archiver'), findsOneWidget);
    });
  });
}
