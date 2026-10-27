import 'package:dubagest/features/commerce/domain/services/etat_commerce.dart';
import 'package:dubagest/features/commerce/presentation/commerce_providers.dart';
import 'package:dubagest/features/commerce/presentation/pages/produit_form_page.dart';
import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contexte_fixtures.dart';
import '../helpers/pump_app.dart';

void main() {
  /// Fait défiler jusqu'au bouton avant de le toucher (formulaire plus haut que l'écran).
  Future<void> toucher(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> saisir(WidgetTester tester, Finder f, String texte) async {
    await tester.ensureVisible(f);
    await tester.enterText(f, texte);
    await tester.pumpAndSettle();
  }

  Future<void> ouvrir(WidgetTester tester) => pumpApp(
        tester,
        const ProduitFormPage(),
        size: const Size(400, 900),
        overrides: [
          contexteActifProvider.overrideWithValue(contexte(perimetres: [perimetreJson('b-a', nom: 'Boutique A')])),
          etatCommerceProvider.overrideWith((ref) => Stream.value(EtatCommerce())),
        ],
      );

  testWidgets('libellés complets, jamais tronqués dans un champ étroit', (tester) async {
    await ouvrir(tester);
    expect(find.text('Comment comptez-vous ce produit ?'), findsOneWidget);
    expect(find.text('Vendez-vous aussi par carton, paquet, sac… ?'), findsOneWidget);
    await toucher(tester, find.byKey(const Key('unite-ajouter')));
    expect(find.text('Nombre de pièces dans 1 emballage'), findsOneWidget);
  });

  testWidgets('détail par pièce, gros par carton : les autres prix sont calculés', (tester) async {
    await ouvrir(tester);

    // Étape 1 : nom, unité de base « Pièce », emballage « 1 carton = 10 pièces ».
    await saisir(tester, find.byKey(const Key('produit-nom')), 'Carreaux 40×40');
    await toucher(tester, find.widgetWithText(ActionChip, 'Carton'));
    final facteur = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key! as ValueKey).value}'.startsWith('unite-facteur-'));
    await saisir(tester, facteur, '10');
    expect(find.text('1 Carton = 10 Pièces'), findsOneWidget);
    expect(find.text('Nombre de pièces dans 1 emballage'), findsOneWidget);

    await toucher(tester, find.byKey(const Key('produit-suivant')));

    // Étape 2 : 1 000 F la pièce au détail…
    await saisir(tester, find.byKey(const Key('prix-detail')), '1000');
    expect(find.textContaining('Soit 10 000 FCFA par Carton'), findsOneWidget);

    // … et 8 000 F le carton en gros.
    await toucher(tester, find.byKey(const Key('produit-gros')));
    expect(
      tester.widget<ChoiceChip>(find.byKey(const Key('prix-gros-unite-Carton'))).selected,
      isTrue,
      reason: 'le gros est proposé par carton',
    );
    await saisir(tester, find.byKey(const Key('prix-gros')), '8000');
    expect(find.textContaining('Soit 800 FCFA par Pièce'), findsOneWidget);

    // Tableau récapitulatif : détail 1 000 / 10 000, gros 800 / 8 000.
    for (final texte in ['1 000 FCFA', '10 000 FCFA', '800 FCFA', '8 000 FCFA']) {
      expect(find.text(texte), findsWidgets, reason: texte);
    }
  });
}
