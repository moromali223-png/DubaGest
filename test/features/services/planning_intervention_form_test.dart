import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dubagest/features/contacts/domain/entities/contact.dart';
import 'package:dubagest/features/contacts/presentation/providers/contacts_providers.dart';
import 'package:dubagest/features/services/domain/entities/prestation.dart';
import 'package:dubagest/features/services/presentation/pages/planning_intervention_form_page.dart';
import 'package:dubagest/features/services/presentation/services_providers.dart';
import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import '../../helpers/contexte_fixtures.dart';
import '../../helpers/pump_app.dart';
import 'services_test.dart';

void main() {
  testWidgets('PlanningInterventionFormPage s\'affiche avec ses sections organisées en 2 étapes', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = InMemoryServicesRepository();
    final ctx = contexte(
      role: 'GESTIONNAIRE_SERVICES',
      permissions: {'prestations.view', 'prestations.create'},
    );

    await pumpApp(
      tester,
      const PlanningInterventionFormPage(
        initialDate: '2026-10-20T10:00:00.000',
      ),
      overrides: [
        contexteActifProvider.overrideWithValue(ctx),
        servicesRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(PlanningInterventionFormPage), findsOneWidget);
    expect(find.textContaining('Planifier une intervention'), findsOneWidget);
    // Étape 1 : Créneau et Client
    expect(find.text('Créneau & Programmation'), findsOneWidget);
    expect(find.text('Client & Localisation'), findsOneWidget);
    expect(find.text('Étape 2 : Détails'), findsOneWidget);

    // Clic pour passer à l'étape 2
    await tester.tap(find.text('Étape 2 : Détails'));
    await tester.pumpAndSettle();

    // Étape 2 : Objet, Attribution et bouton de validation
    expect(find.text('Objet de l\'intervention'), findsOneWidget);
    expect(find.text('Attribution & Urgence'), findsOneWidget);
    expect(find.text('Inscrire au planning'), findsOneWidget);
  });

  testWidgets('PlanningInterventionFormPage permet de naviguer à l\'étape 2, choisir un motif rapide et d\'inscrire au planning', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = InMemoryServicesRepository();
    final ctx = contexte(
      role: 'GESTIONNAIRE_SERVICES',
      permissions: {'prestations.view', 'prestations.create'},
    );

    const contactTest = Contact(
      id: 'c-test-1',
      entrepriseId: entrepriseId,
      nom: 'Traoré',
      prenom: 'Seydou',
      telephone: '+223 70 00 00 00',
      adresse: 'Hamdallaye ACI 2000',
      typePersonne: TypePersonne.personne,
      relations: {RelationContact.client},
    );

    await pumpApp(
      tester,
      const PlanningInterventionFormPage(
        initialDate: '2026-10-25T09:00:00.000',
        initialContactId: 'c-test-1',
      ),
      overrides: [
        contexteActifProvider.overrideWithValue(ctx),
        servicesRepositoryProvider.overrideWithValue(repo),
        contactsProvider.overrideWith((ref) => Stream.value([contactTest])),
      ],
    );
    await tester.pumpAndSettle();

    // Vérifie le client pré-sélectionné en étape 1
    expect(find.textContaining('Traoré'), findsWidgets);

    // Passage à l'étape 2
    await tester.tap(find.text('Étape 2 : Détails'));
    await tester.pumpAndSettle();

    // Clic sur un motif rapide
    final motifDiagnostic = find.text('🔍 Diagnostic / Panne');
    expect(motifDiagnostic, findsOneWidget);
    await tester.tap(motifDiagnostic);
    await tester.pumpAndSettle();

    // Le champ titre a été rempli
    expect(find.text('Diagnostic / Panne'), findsWidgets);

    // Clic sur Inscrire au planning
    final boutonValider = find.text('Inscrire au planning');
    await tester.ensureVisible(boutonValider);
    await tester.tap(boutonValider);
    await tester.pumpAndSettle();

    // Vérifie que l'intervention a été créée dans le repository avec le statut planifiee
    expect(repo.prestations.length, 1);
    final cree = repo.prestations.first;
    expect(cree.titre, 'Diagnostic / Panne');
    expect(cree.contactId, 'c-test-1');
    expect(cree.statut, StatutPrestation.planifiee);
  });

  testWidgets('PlanningInterventionFormPage permet de choisir une durée de 12h ou 24h et affiche la section Photos', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = InMemoryServicesRepository();
    final ctx = contexte(
      role: 'GESTIONNAIRE_SERVICES',
      permissions: {'prestations.view', 'prestations.create'},
    );

    await pumpApp(
      tester,
      const PlanningInterventionFormPage(
        initialDate: '2026-10-25T08:00:00.000',
      ),
      overrides: [
        contexteActifProvider.overrideWithValue(ctx),
        servicesRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await tester.pumpAndSettle();

    // Vérifie la présence des durées rapides 12h et 24h
    expect(find.text('12 h'), findsOneWidget);
    expect(find.text('24 h (1 j+)'), findsOneWidget);
    expect(find.text('Personnaliser'), findsOneWidget);

    // Clic sur 12 h
    await tester.tap(find.text('12 h'));
    await tester.pumpAndSettle();

    // Vérifie que l'heure de fin et le total affichent bien la durée 12h
    expect(find.text('Total : 12h'), findsOneWidget);

    // Passage à l'étape 2
    await tester.tap(find.text('Étape 2 : Détails'));
    await tester.pumpAndSettle();

    // Vérifie que la section Photos & Documents terrain est présente
    expect(find.text('Photos & Constat terrain (Facultatif)'), findsOneWidget);

    // Valide l'intervention
    final boutonValider = find.text('Inscrire au planning');
    await tester.ensureVisible(boutonValider);
    await tester.tap(boutonValider);
    await tester.pumpAndSettle();

    // Vérifie que la prestation enregistrée a une durée de 720 min (12h)
    expect(repo.prestations.length, 1);
    final cree = repo.prestations.first;
    expect(cree.dureeMinutes, 720);
  });
}
