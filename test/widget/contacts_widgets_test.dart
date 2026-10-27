import 'package:dubagest/core/sync/sync_models.dart';
import 'package:dubagest/core/utils/recherche.dart';
import 'package:dubagest/features/contacts/domain/entities/contact.dart';
import 'package:dubagest/features/contacts/domain/repositories/contact_repository.dart';
import 'package:dubagest/features/contacts/presentation/pages/contact_detail_page.dart';
import 'package:dubagest/features/contacts/presentation/pages/contact_form_page.dart';
import 'package:dubagest/features/contacts/presentation/pages/contacts_page.dart';
import 'package:dubagest/features/contacts/presentation/providers/contacts_providers.dart';
import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import 'package:dubagest/features/finances/domain/services/etat_finances.dart';
import 'package:dubagest/features/finances/presentation/providers/finances_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contexte_fixtures.dart';
import '../helpers/pump_app.dart';

const _amadou = Contact(
  id: 'c-1',
  entrepriseId: entrepriseId,
  nom: 'Traoré',
  prenom: 'Amadou',
  telephone: '+223 76 12 34 56',
  ville: 'Bamako',
  relations: {RelationContact.client, RelationContact.fournisseur},
  version: 1,
);
const _mariam = Contact(
  id: 'c-2',
  entrepriseId: entrepriseId,
  nom: 'Sow',
  prenom: 'Mariam',
  relations: {RelationContact.client},
  syncStatus: RecordSyncStatus.pendingSync,
);

class _FakeContacts implements ContactRepository {
  _FakeContacts([this.contacts = const [_amadou, _mariam]]);
  final List<Contact> contacts;
  final crees = <Contact>[];

  @override
  Stream<List<Contact>> watch(String entrepriseId, FiltreContacts filtre) => Stream.value([
        for (final c in contacts)
          if ((filtre.relation == null || c.relations.contains(filtre.relation)) &&
              normaliserRecherche('${c.prenom} ${c.nom}').contains(normaliserRecherche(filtre.recherche)))
            c,
      ]);

  @override
  Stream<Contact?> watchUn(String id) => Stream.value(contacts.where((c) => c.id == id).firstOrNull);

  @override
  Future<List<Contact>> doublonsPotentiels(String entrepriseId,
          {String? telephone, required String nom, String? prenom, String? saufId}) async =>
      [for (final c in contacts) if (normaliserRecherche(c.nom) == normaliserRecherche(nom)) c];

  @override
  Future<Contact> creer(Contact contact) async {
    crees.add(contact);
    return contact;
  }

  @override
  Future<void> modifier(Contact avant, Contact apres) async {}
}

void main() {
  testWidgets('liste : relations traduites, recherche et filtre', (tester) async {
    await pumpApp(tester, const ContactsPage(), overrides: [
      contexteActifProvider.overrideWithValue(contexte()),
      contactRepositoryProvider.overrideWithValue(_FakeContacts()),
    ]);

    expect(find.text('Amadou Traoré'), findsOneWidget);
    expect(find.text('Mariam Sow'), findsOneWidget);
    expect(find.textContaining('Client · Fournisseur'), findsOneWidget);
    expect(find.byKey(const Key('contact-add')), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Fournisseur'));
    await tester.pumpAndSettle();
    expect(find.text('Mariam Sow'), findsNothing);
    expect(find.text('Amadou Traoré'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Tous'));
    await tester.enterText(find.byKey(const Key('contacts-search')), 'mariam');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Amadou Traoré'), findsNothing);
    expect(find.text('Mariam Sow'), findsOneWidget);
  });

  testWidgets('liste vide : message d\'aide, pas de bouton sans contacts.create', (tester) async {
    await pumpApp(tester, const ContactsPage(), overrides: [
      contexteActifProvider.overrideWithValue(contexte(role: 'VENDEUR', permissions: {'contacts.view'})),
      contactRepositoryProvider.overrideWithValue(_FakeContacts(const [])),
    ]);
    expect(find.textContaining('Aucun contact pour le moment'), findsOneWidget);
    expect(find.byKey(const Key('contact-add')), findsNothing);
  });

  testWidgets('fiche en arabe (RTL) : actions rapides et historique honnête', (tester) async {
    await pumpApp(
      tester,
      const ContactDetailPage(contactId: 'c-1'),
      locale: const Locale('ar'),
      size: const Size(600, 1400),
      overrides: [
        contexteActifProvider.overrideWithValue(contexte()),
        contactRepositoryProvider.overrideWithValue(_FakeContacts()),
        etatFinancesProvider.overrideWith((ref) => Stream.value(EtatFinances())),
      ],
    );
    expect(Directionality.of(tester.element(find.text('Amadou Traoré'))), TextDirection.rtl);
    expect(find.text('عميل'), findsOneWidget);
    expect(find.text('مورّد'), findsOneWidget);
    // Historique réel : rien n'est dû et aucun paiement, sans chiffre inventé.
    expect(find.textContaining('لا توجد مبالغ مستحقة'), findsOneWidget);
    // Pas d'e-mail : action désactivée ; téléphone présent : appel possible.
    expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('contact-mail'))).onPressed, isNull);
    expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('contact-call'))).onPressed, isNotNull);
    expect(find.byKey(const Key('contact-edit')), findsOneWidget);
  });

  testWidgets('fiche : le vendeur ne peut pas archiver', (tester) async {
    await pumpApp(tester, const ContactDetailPage(contactId: 'c-1'), overrides: [
      contexteActifProvider.overrideWithValue(contexte(role: 'VENDEUR')),
      contactRepositoryProvider.overrideWithValue(_FakeContacts()),
    ]);
    expect(find.byKey(const Key('contact-edit')), findsOneWidget);
    expect(find.byType(PopupMenuButton<void>), findsNothing);
  });

  testWidgets('formulaire : doublon détecté avant création, rien n\'est créé si on annule', (tester) async {
    final repo = _FakeContacts();
    await pumpApp(tester, const ContactFormPage(), size: const Size(500, 1400), overrides: [
      contexteActifProvider.overrideWithValue(contexte()),
      contactRepositoryProvider.overrideWithValue(repo),
    ]);

    await tester.tap(find.byKey(const Key('contact-save')));
    await tester.pumpAndSettle();
    expect(find.text('Champ obligatoire'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('contact-nom')), 'TRAORE');
    await tester.tap(find.byKey(const Key('contact-relation-PROPRIETAIRE')));
    await tester.tap(find.byKey(const Key('contact-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('contact-duplicates')), findsOneWidget);
    expect(find.text('Amadou Traoré'), findsOneWidget);
    expect(find.byKey(const Key('contact-duplicate-add-c-1')), findsOneWidget);

    await tester.tap(find.text('Annuler').last);
    await tester.pumpAndSettle();
    expect(repo.crees, isEmpty);
  });

  testWidgets('formulaire : e-mail invalide signalé', (tester) async {
    await pumpApp(tester, const ContactFormPage(), size: const Size(500, 1400), overrides: [
      contexteActifProvider.overrideWithValue(contexte()),
      contactRepositoryProvider.overrideWithValue(_FakeContacts(const [])),
    ]);
    await tester.enterText(find.byKey(const Key('contact-nom')), 'Keïta');
    await tester.enterText(find.byKey(const Key('contact-email')), 'keita@');
    await tester.tap(find.byKey(const Key('contact-save')));
    await tester.pumpAndSettle();
    expect(find.text('Adresse e-mail invalide'), findsOneWidget);
  });
}
