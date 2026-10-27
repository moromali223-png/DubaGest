import 'package:dubagest/features/documents/domain/entities/document.dart';
import 'package:dubagest/features/documents/presentation/providers/documents_providers.dart';
import 'package:dubagest/features/documents/presentation/pages/documents_page.dart';
import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import 'package:dubagest/features/finances/domain/entities/finances.dart';
import 'package:dubagest/features/finances/domain/services/etat_finances.dart';
import 'package:dubagest/features/finances/presentation/pages/paiement_page.dart';
import 'package:dubagest/features/finances/presentation/providers/finances_providers.dart';
import 'package:dubagest/features/finances/presentation/widgets/finances_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contexte_fixtures.dart';
import '../helpers/pump_app.dart';

final _etat = EtatFinances(paiements: [
  Paiement(id: 'p1', entrepriseId: entrepriseId, sens: SensPaiement.entree, montant: 7500,
      mode: ModePaiement.mobileMoney, datePaiement: DateTime(2026, 10, 5, 10)),
]);

List<Object> _overrides({Set<String>? permissions, List<Document> documents = const []}) => [
      contexteActifProvider.overrideWithValue(contexte(role: 'VENDEUR', permissions: permissions)),
      etatFinancesProvider.overrideWith((ref) => Stream.value(_etat)),
      documentsProvider.overrideWith((ref) => Stream.value(documents)),
      contactsParIdProvider.overrideWith((ref) => Stream.value(const {})),
    ];

void main() {
  testWidgets('encaissement : bouton « Émettre le reçu » avec documents.create', (tester) async {
    await pumpApp(tester, const PaiementPage(paiementId: 'p1'), overrides: _overrides().cast(), size: const Size(420, 1200));
    expect(find.byKey(const Key('paiement-emettre-recu')), findsOneWidget);
  });

  testWidgets('sans documents.create : pas de bouton', (tester) async {
    await pumpApp(
      tester,
      const PaiementPage(paiementId: 'p1'),
      overrides: _overrides(permissions: {'payments.view'}).cast(),
      size: const Size(420, 1200),
    );
    expect(find.byKey(const Key('paiement-emettre-recu')), findsNothing);
  });

  testWidgets('reçu déjà émis : « Voir le reçu » avec son numéro', (tester) async {
    final recu = Document(
      id: 'd1', entrepriseId: entrepriseId, type: TypeDocument.recu, numero: 'REC-2026-00051', blocId: 'b',
      sequence: 51, langue: 'fr', date: DateTime(2026, 10, 5), montant: 7500, origineType: 'PAIEMENT',
      origineId: 'p1', contenu: const {}, version: 1,
    );
    await pumpApp(
      tester,
      const PaiementPage(paiementId: 'p1'),
      overrides: _overrides(documents: [recu]).cast(),
      size: const Size(420, 1200),
    );
    expect(find.byKey(const Key('paiement-emettre-recu')), findsNothing);
    expect(find.text('Voir le reçu REC-2026-00051'), findsOneWidget);
  });

  testWidgets('DocumentsPage : affichage des documents multi-types et recherche', (tester) async {
    final docs = [
      Document(
        id: 'd1',
        entrepriseId: entrepriseId,
        type: TypeDocument.recu,
        numero: 'REC-2026-00001',
        blocId: 'b1',
        sequence: 1,
        langue: 'fr',
        date: DateTime.now(),
        montant: 5000,
        origineType: 'PAIEMENT',
        contenu: {
          'contact': {'nom': 'Samba Diarra'}
        },
      ),
      Document(
        id: 'd2',
        entrepriseId: entrepriseId,
        type: TypeDocument.facture,
        numero: 'FAC-2026-00002',
        blocId: 'b2',
        sequence: 2,
        langue: 'fr',
        date: DateTime.now(),
        montant: 120000,
        origineType: 'PRESTATION',
        contenu: {
          'contact': {'nom': 'Entreprise Moderne'},
          'titre': 'Rénovation électrique',
        },
      ),
    ];

    await pumpApp(
      tester,
      const DocumentsPage(),
      overrides: _overrides(
        permissions: {'documents.view', 'documents.create'},
        documents: docs,
      ).cast(),
      size: const Size(600, 1200),
    );

    expect(find.text('REC-2026-00001'), findsOneWidget);
    expect(find.text('FAC-2026-00002'), findsOneWidget);
    expect(find.textContaining('Samba Diarra'), findsOneWidget);
    expect(find.textContaining('Entreprise Moderne'), findsOneWidget);

    // Test de recherche par texte
    await tester.enterText(find.byKey(const Key('documents-recherche')), 'Samba');
    await tester.pumpAndSettle();

    expect(find.text('REC-2026-00001'), findsOneWidget);
    expect(find.text('FAC-2026-00002'), findsNothing);
  });
}
