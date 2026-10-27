import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dubagest/features/contacts/domain/entities/contact.dart';
import 'package:dubagest/features/contacts/domain/repositories/contact_repository.dart';
import 'package:dubagest/features/contacts/presentation/providers/contacts_providers.dart';
import 'package:dubagest/features/services/domain/entities/metier_template.dart';
import 'package:dubagest/features/services/presentation/pages/devis_form_page.dart';
import 'package:dubagest/features/services/presentation/services_providers.dart';
import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import '../../helpers/contexte_fixtures.dart';
import '../../helpers/pump_app.dart';
import 'services_test.dart';

void main() {
  testWidgets('DevisFormPage s\'affiche sans section photos et avec un sélecteur de métier', (tester) async {
    final repo = InMemoryServicesRepository();
    final ctx = contexte(
      role: 'GESTIONNAIRE_SERVICES',
      permissions: {'devis.view', 'devis.create'},
    );

    await pumpApp(
      tester,
      const DevisFormPage(),
      overrides: [
        contexteActifProvider.overrideWithValue(ctx),
        servicesRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(DevisFormPage), findsOneWidget);
    expect(find.text('Nouveau devis'), findsOneWidget);

    // Vérifie la présence du sélecteur "Type de prestation"
    expect(find.text('Type de prestation'), findsOneWidget);

    // Vérifie que les photos sont ABSENTES du formulaire
    expect(find.text('Photographies du devis'), findsNothing);
    expect(find.text('Photos & croquis'), findsNothing);

    // Vérifie l'objet du devis prérempli
    expect(find.text('Devis — Prestation de services'), findsOneWidget);

    // Vérifie la barre inférieure et le bouton de création
    expect(find.text('Créer le devis'), findsOneWidget);
  });

  testWidgets('DevisFormPage permet de changer de métier et met à jour l\'objet du devis', (tester) async {
    final repo = InMemoryServicesRepository();
    final ctx = contexte(
      role: 'GESTIONNAIRE_SERVICES',
      permissions: {'devis.view', 'devis.create'},
    );

    await pumpApp(
      tester,
      const DevisFormPage(),
      overrides: [
        contexteActifProvider.overrideWithValue(ctx),
        servicesRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await tester.pumpAndSettle();

    // Changer le type de prestation vers "Plomberie"
    final formField = tester.widget<DropdownButtonFormField<MetierCode>>(
      find.byType(DropdownButtonFormField<MetierCode>),
    );
    formField.onChanged!(MetierCode.plomberie);
    await tester.pumpAndSettle();

    // Le titre doit s'adapter automatiquement
    expect(find.text('Devis — Travaux de plomberie'), findsOneWidget);
  });

  testWidgets('DevisFormPage permet d\'ajouter une ligne et calcule le total', (tester) async {
    final repo = InMemoryServicesRepository();
    final ctx = contexte(
      role: 'GESTIONNAIRE_SERVICES',
      permissions: {'devis.view', 'devis.create'},
    );

    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpApp(
      tester,
      const DevisFormPage(),
      overrides: [
        contexteActifProvider.overrideWithValue(ctx),
        servicesRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await tester.pumpAndSettle();

    // Cliquer sur "Ajouter une ligne"
    final btnAjouter = find.text('Ajouter une ligne').first;
    await tester.tap(btnAjouter);
    await tester.pumpAndSettle();

    // Saisir la désignation, quantité et prix
    final designationInput = find.widgetWithText(TextFormField, 'Désignation *');
    await tester.enterText(designationInput, 'Remplacement robinet mitigeur');
    await tester.pumpAndSettle();

    final prixInput = find.widgetWithText(TextFormField, 'Prix unitaire *');
    await tester.enterText(prixInput, '25000');
    await tester.pumpAndSettle();

    // Valider la modale
    final btnValiderModal = find.text('Ajouter au devis');
    await tester.tap(btnValiderModal);
    await tester.pumpAndSettle();

    expect(find.text('Remplacement robinet mitigeur'), findsOneWidget);
    expect(find.text('Prestations chiffrées (1)'), findsOneWidget);
  });

  testWidgets('DevisFormPage permet de sélectionner un client/prospect existant et de le détacher', (tester) async {
    final repo = InMemoryServicesRepository();
    final contactsRepo = _FakeContactsRepo();
    final ctx = contexte(
      role: 'GESTIONNAIRE_SERVICES',
      permissions: {'devis.view', 'devis.create', 'contacts.view'},
    );

    await pumpApp(
      tester,
      const DevisFormPage(),
      overrides: [
        contexteActifProvider.overrideWithValue(ctx),
        servicesRepositoryProvider.overrideWithValue(repo),
        contactRepositoryProvider.overrideWithValue(contactsRepo),
      ],
    );
    await tester.pumpAndSettle();

    // Au départ, aucun contact n'est sélectionné
    expect(find.text('Client ou Prospect'), findsOneWidget);
    expect(find.text('Sélectionner ou créer un contact'), findsOneWidget);

    // Ouvrir le sélecteur
    await tester.tap(find.byKey(const Key('btn-choisir-contact-devis')));
    await tester.pumpAndSettle();

    // La modale affiche les contacts avec leurs badges
    expect(find.text('Moussa Diarra'), findsOneWidget);
    expect(find.text('Fatoumata Sangaré'), findsOneWidget);
    expect(find.text('Client'), findsOneWidget);
    expect(find.text('Prospect'), findsOneWidget);

    // Sélectionner Moussa Diarra
    await tester.tap(find.text('Moussa Diarra'));
    await tester.pumpAndSettle();

    // Vérifier que Moussa Diarra est maintenant affiché sur la page principale
    expect(find.text('Moussa Diarra'), findsOneWidget);
    expect(find.text('70112233'), findsOneWidget);
    expect(find.byKey(const Key('btn-changer-contact-devis')), findsOneWidget);
    expect(find.byKey(const Key('btn-retirer-contact-devis')), findsOneWidget);

    // Détacher le client
    await tester.tap(find.byKey(const Key('btn-retirer-contact-devis')));
    await tester.pumpAndSettle();

    // Retour à l'état non sélectionné
    expect(find.text('Sélectionner ou créer un contact'), findsOneWidget);
  });

  testWidgets('DevisFormPage permet de créer un nouveau prospect rapidement sans quitter le devis', (tester) async {
    final repo = InMemoryServicesRepository();
    final contactsRepo = _FakeContactsRepo();
    final ctx = contexte(
      role: 'GESTIONNAIRE_SERVICES',
      permissions: {'devis.view', 'devis.create', 'contacts.view', 'contacts.create'},
    );

    await pumpApp(
      tester,
      const DevisFormPage(),
      overrides: [
        contexteActifProvider.overrideWithValue(ctx),
        servicesRepositoryProvider.overrideWithValue(repo),
        contactRepositoryProvider.overrideWithValue(contactsRepo),
      ],
    );
    await tester.pumpAndSettle();

    // Cliquer sur le bouton Nouveau
    await tester.tap(find.byKey(const Key('btn-nouveau-contact-devis')));
    await tester.pumpAndSettle();

    // Le dialogue s'affiche
    expect(find.text('Nouveau contact'), findsOneWidget);
    expect(find.text('Client ou prospect pour ce devis'), findsOneWidget);

    // Saisir le nom et téléphone
    await tester.enterText(find.byKey(const Key('champ-nouveau-contact-nom')), 'Keita');
    await tester.enterText(find.byKey(const Key('champ-nouveau-contact-prenom')), 'Ousmane');
    await tester.enterText(find.byKey(const Key('champ-nouveau-contact-tel')), '77889900');
    await tester.pumpAndSettle();

    // Valider la création
    await tester.tap(find.byKey(const Key('btn-creer-contact-rapide-valider')));
    await tester.pumpAndSettle();

    // Vérifier que le contact créé est automatiquement sélectionné dans le devis
    expect(find.text('Ousmane Keita'), findsOneWidget);
    expect(find.text('77889900'), findsOneWidget);
    expect(find.text('Prospect'), findsOneWidget);
  });
}

class _FakeContactsRepo implements ContactRepository {
  _FakeContactsRepo([List<Contact>? init])
      : contacts = init ??
            [
              const Contact(
                id: 'c-1',
                entrepriseId: 'e-1',
                nom: 'Diarra',
                prenom: 'Moussa',
                telephone: '70112233',
                relations: {RelationContact.client},
              ),
              const Contact(
                id: 'c-2',
                entrepriseId: 'e-1',
                nom: 'Sangaré',
                prenom: 'Fatoumata',
                telephone: '65443322',
                relations: {},
              ),
            ];

  final List<Contact> contacts;

  @override
  Stream<List<Contact>> watch(String entrepriseId, FiltreContacts filtre) => Stream.value(contacts);

  @override
  Stream<Contact?> watchUn(String id) => Stream.value(contacts.where((c) => c.id == id).firstOrNull);

  @override
  Future<List<Contact>> doublonsPotentiels(
    String entrepriseId, {
    String? telephone,
    required String nom,
    String? prenom,
    String? saufId,
  }) async =>
      [];

  @override
  Future<Contact> creer(Contact contact) async {
    contacts.add(contact);
    return contact;
  }

  @override
  Future<void> modifier(Contact avant, Contact apres) async {}
}
