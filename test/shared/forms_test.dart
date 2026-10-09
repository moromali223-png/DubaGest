import 'package:dubagest/app/theme/app_theme.dart';
import 'package:dubagest/shared/forms/forms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FormSectionStatus', () {
    test('statuts possèdent des icônes, couleurs et libellés cohérents', () {
      expect(FormSectionStatus.complete.icon, Icons.check_circle_rounded);
      expect(FormSectionStatus.complete.color, AppColors.positive);
      expect(FormSectionStatus.complete.label, 'Complété');

      expect(FormSectionStatus.error.icon, Icons.error_rounded);
      expect(FormSectionStatus.error.color, AppColors.negative);

      expect(FormSectionStatus.partial.color, AppColors.gold);
      expect(FormSectionStatus.emptyOptional.label, 'Facultatif');
    });
  });

  group('SmartFormController', () {
    test('mode single-open par défaut : ouvrir une section ferme la précédente', () {
      final controller = SmartFormController(initialOpenIndex: 0);

      expect(controller.isSectionOpen(0), isTrue);
      expect(controller.isSectionOpen(1), isFalse);

      controller.openSection(1);
      expect(controller.isSectionOpen(0), isFalse);
      expect(controller.isSectionOpen(1), isTrue);

      controller.toggleSection(1);
      expect(controller.isSectionOpen(1), isFalse);
      expect(controller.openIndices.isEmpty, isTrue);
    });

    test('mode multi-open : conserve les multiples sections ouvertes', () {
      final controller = SmartFormController(initialOpenIndex: 0, allowMultipleOpen: true);

      controller.openSection(1);
      expect(controller.isSectionOpen(0), isTrue);
      expect(controller.isSectionOpen(1), isTrue);

      controller.openAll(4);
      expect(controller.openIndices.length, 4);

      controller.closeAll();
      expect(controller.openIndices.isEmpty, isTrue);
    });
  });

  group('CollapsibleFormSection Widget', () {
    testWidgets('affiche l\'en-tête, le statut et masque/affiche le contenu selon isExpanded', (tester) async {
      var isExpanded = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => CollapsibleFormSection(
                title: 'Informations principales',
                icon: Icons.info_outline_rounded,
                summary: 'Tuyau PVC • Plomberie',
                status: FormSectionStatus.complete,
                isExpanded: isExpanded,
                onToggle: () => setState(() => isExpanded = !isExpanded),
                child: const Text('Contenu du formulaire'),
              ),
            ),
          ),
        ),
      );

      // Section fermée : le résumé est visible
      expect(find.text('Informations principales'), findsOneWidget);
      expect(find.text('Tuyau PVC • Plomberie'), findsOneWidget);

      // Clic sur l'en-tête pour ouvrir
      await tester.tap(find.text('Informations principales'));
      await tester.pumpAndSettle();

      // Section ouverte : le contenu est visible
      expect(find.text('Contenu du formulaire'), findsOneWidget);
    });
  });

  group('StickyFormActions Widget', () {
    testWidgets('affiche les boutons de soumission et le résumé', (tester) async {
      var submitted = false;
      var cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StickyFormActions(
              onSubmit: () => submitted = true,
              onCancel: () => cancelled = true,
              submitLabel: 'Enregistrer',
              cancelLabel: 'Annuler',
              summaryWidget: const Text('Total : 50 000 FCFA'),
            ),
          ),
        ),
      );

      expect(find.text('Total : 50 000 FCFA'), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);

      await tester.tap(find.text('Enregistrer'));
      expect(submitted, isTrue);

      await tester.tap(find.text('Annuler'));
      expect(cancelled, isTrue);
    });
  });

  group('QuickAddDialog Widget', () {
    testWidgets('permet la saisie rapide et retourne les valeurs', (tester) async {
      (String, String?)? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await QuickAddDialog.show(
                    context,
                    title: 'Ajout rapide client',
                    primaryLabel: 'Nom',
                    secondaryLabel: 'Téléphone',
                  );
                },
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Ajout rapide client'), findsOneWidget);

      // Saisie du nom
      await tester.enterText(find.byType(TextField).first, 'Moussa Diarra');
      // Saisie du téléphone
      await tester.enterText(find.byType(TextField).last, '+223 70 00 00 00');
      await tester.pump();

      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();

      expect(result?.$1, 'Moussa Diarra');
      expect(result?.$2, '+223 70 00 00 00');
    });
  });
}
