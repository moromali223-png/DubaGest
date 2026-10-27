import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dubagest/features/immobilier/presentation/pages/bien_form_page.dart';

void main() {
  testWidgets('BienFormPage se rend avec toutes ses sections ouvertes et fonctionnelles', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: BienFormPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Vérifier que le formulaire et l'AppBar sont bien affichés
    expect(find.byType(BienFormPage), findsOneWidget);
    expect(find.text('Nouveau bien'), findsOneWidget);

    // Vérifier que les 6 sections sont présentes
    expect(find.text('1. Désignation & Type'), findsOneWidget);
    expect(find.text('2. Propriétaire du bien *'), findsOneWidget);
    expect(find.text('3. Conditions Financières Indicatives'), findsOneWidget);
    expect(find.text('4. Localisation & Adresse'), findsOneWidget);
    expect(find.text('5. Caractéristiques du Bien'), findsOneWidget);
    expect(find.text('6. Notes & Remarques Internes'), findsOneWidget);

    // Vérifier que les champs clés sont visibles dans le formulaire
    expect(find.text('Nom ou Désignation du bien *'), findsOneWidget);
    expect(find.text('Sélectionner ou Créer le propriétaire'), findsOneWidget);
    expect(find.text('Enregistrer le bien'), findsOneWidget);
  });
}
