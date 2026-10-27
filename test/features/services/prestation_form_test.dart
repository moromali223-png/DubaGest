import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dubagest/features/contacts/domain/entities/contact.dart';
import 'package:dubagest/features/contacts/presentation/providers/contacts_providers.dart';
import 'package:dubagest/features/services/domain/entities/metier_template.dart';
import 'package:dubagest/features/services/domain/entities/prestation.dart';
import 'package:dubagest/features/services/presentation/pages/prestation_form_page.dart';
import 'package:dubagest/features/services/presentation/services_providers.dart';
import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import 'package:dubagest/shared/widgets/state_views.dart';
import '../../helpers/contexte_fixtures.dart';
import '../../helpers/pump_app.dart';
import 'services_test.dart';

void main() {
  testWidgets('PrestationFormPage s\'affiche correctement à la création', (tester) async {
    final repo = InMemoryServicesRepository();
    final ctx = contexte(
      role: 'GESTIONNAIRE_SERVICES',
      permissions: {'prestations.view', 'prestations.create'},
    );

    await pumpApp(
      tester,
      const PrestationFormPage(),
      overrides: [
        contexteActifProvider.overrideWithValue(ctx),
        servicesRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(PrestationFormPage), findsOneWidget);
    expect(find.text('Formulaire de nouveau contrat de service'), findsOneWidget);
    expect(find.text('Enregistrer le contrat de service'), findsOneWidget);
    expect(find.text('Type de service'), findsOneWidget);
  });

  testWidgets('PrestationFormPage gère une liste de contacts avec doublons d\'IDs sans planter', (tester) async {
    final repo = InMemoryServicesRepository();
    final ctx = contexte(
      role: 'GESTIONNAIRE_SERVICES',
      permissions: {'prestations.view', 'prestations.create'},
    );

    const contact1 = Contact(
      id: 'c-1',
      entrepriseId: entrepriseId,
      nom: 'Diallo',
      prenom: 'Mamadou',
      typePersonne: TypePersonne.personne,
      relations: {RelationContact.client},
    );
    const contactDoublon = Contact(
      id: 'c-1',
      entrepriseId: entrepriseId,
      nom: 'Diallo',
      prenom: 'Mamadou Bis',
      typePersonne: TypePersonne.personne,
      relations: {RelationContact.client},
    );

    await pumpApp(
      tester,
      const PrestationFormPage(),
      overrides: [
        contexteActifProvider.overrideWithValue(ctx),
        servicesRepositoryProvider.overrideWithValue(repo),
        contactsProvider.overrideWith((ref) => Stream.value([contact1, contactDoublon])),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(PrestationFormPage), findsOneWidget);
    expect(find.text('Client'), findsWidgets);
  });

  testWidgets('PrestationFormPage charge et affiche les données en modification', (tester) async {
    final repo = InMemoryServicesRepository();
    repo.prestations.add(
      const Prestation(
        id: 'p-123',
        entrepriseId: entrepriseId,
        titre: 'Réparation MacBook Pro',
        lignes: [],
        total: 75000,
        metierCode: MetierCode.reparation,
      ),
    );

    final ctx = contexte(
      role: 'GESTIONNAIRE_SERVICES',
      permissions: {'prestations.view', 'prestations.update'},
    );

    await pumpApp(
      tester,
      const PrestationFormPage(prestationId: 'p-123'),
      overrides: [
        contexteActifProvider.overrideWithValue(ctx),
        servicesRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(PrestationFormPage), findsOneWidget);
    expect(find.text('Modifier le contrat de service'), findsOneWidget);
    expect(find.text('Réparation MacBook Pro'), findsOneWidget);
  });

  testWidgets('PrestationFormPage affiche ErrorView quand le chargement échoue', (tester) async {
    final repo = InMemoryServicesRepository();
    final ctx = contexte(
      role: 'GESTIONNAIRE_SERVICES',
      permissions: {'prestations.view', 'prestations.update'},
    );

    await pumpApp(
      tester,
      const PrestationFormPage(prestationId: 'p-err'),
      overrides: [
        contexteActifProvider.overrideWithValue(ctx),
        servicesRepositoryProvider.overrideWithValue(repo),
        prestationDetailProvider('p-err').overrideWith((ref) => Future.error(Exception('Erreur réseau Supabase'))),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('PrestationFormPage affiche EmptyView quand la prestation est introuvable', (tester) async {
    final repo = InMemoryServicesRepository();
    final ctx = contexte(
      role: 'GESTIONNAIRE_SERVICES',
      permissions: {'prestations.view', 'prestations.update'},
    );

    await pumpApp(
      tester,
      const PrestationFormPage(prestationId: 'p-404'),
      overrides: [
        contexteActifProvider.overrideWithValue(ctx),
        servicesRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(EmptyView), findsOneWidget);
    expect(find.text('Contrat de service introuvable ou supprimé.'), findsOneWidget);
  });

  testWidgets('PrestationFormPage permet de changer de modèle métier et met à jour les presets', (tester) async {
    final repo = InMemoryServicesRepository();
    final ctx = contexte(
      role: 'GESTIONNAIRE_SERVICES',
      permissions: {'prestations.view', 'prestations.create'},
    );

    await pumpApp(
      tester,
      const PrestationFormPage(),
      overrides: [
        contexteActifProvider.overrideWithValue(ctx),
        servicesRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await tester.pumpAndSettle();

    // Cliquer sur le chip Incubation
    final chipIncubation = find.widgetWithText(FilterChip, MetierCode.incubation.libelle);
    expect(chipIncubation, findsOneWidget);
    await tester.ensureVisible(chipIncubation);
    await tester.pumpAndSettle();
    await tester.tap(chipIncubation);
    await tester.pumpAndSettle();

    // Le titre par défaut d'incubation doit être renseigné
    expect(find.text('Lot incubation d\'œufs'), findsOneWidget);
    // Les champs spécifiques doivent apparaître
    expect(find.text('Espèce / Type d\'œufs'), findsOneWidget);
    expect(find.text('Nombre d\'œufs déposés'), findsOneWidget);
  });

  testWidgets('PrestationFormPage enregistre une nouvelle prestation avec succès', (tester) async {
    final repo = InMemoryServicesRepository();
    final ctx = contexte(
      role: 'GESTIONNAIRE_SERVICES',
      permissions: {'prestations.view', 'prestations.create'},
    );

    await pumpApp(
      tester,
      const PrestationFormPage(),
      overrides: [
        contexteActifProvider.overrideWithValue(ctx),
        servicesRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await tester.pumpAndSettle();

    // Saisir un titre
    final titreInput = find.widgetWithText(TextFormField, 'Intitulé du contrat de service *');
    await tester.enterText(titreInput, 'Nettoyage 4 fauteuils velours');
    await tester.pumpAndSettle();

    // Enregistrer
    final btnEnregistrer = find.text('Enregistrer le contrat de service');
    await tester.tap(btnEnregistrer);
    await tester.pumpAndSettle();

    expect(repo.prestations.length, 1);
    expect(repo.prestations.first.titre, 'Nettoyage 4 fauteuils velours');
  });
}
