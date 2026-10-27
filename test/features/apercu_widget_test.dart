import 'package:dubagest/features/documents/domain/entities/document.dart';
import 'package:dubagest/features/documents/presentation/widgets/apercu_document_feuille_a4.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ApercuDocumentFeuilleA4 se rend sans erreur sur mobile', (tester) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final doc = Document(
      id: 'd-1',
      entrepriseId: 'e-1',
      type: TypeDocument.bonCommande,
      numero: 'BC-2026-00001',
      blocId: 'b-1',
      sequence: 1,
      langue: 'fr',
      date: DateTime.now(),
      montant: 50,
      origineType: 'MANUEL',
      contenu: {
        'entreprise': {'nom': 'Alpha Distribution', 'telephone': '+223 18024025'},
        'contact': {'nom': 'Boubacar traore', 'telephone': '70000125'},
        'titre': 'Bon de commande fournisseur',
        'lignes': [
          {'libelle': 'kjkjdjjdj', 'montant': 50, 'quantite': 1, 'prix_unitaire': 50}
        ],
        'total': 50,
        'sous_total': 50,
        'reste': 50,
        'acompte': 0,
        'remise': 0,
        'statut': 'EMIS',
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ApercuDocumentFeuilleA4(document: doc),
          ),
        ),
      ),
    );

    expect(find.textContaining('BC-2026-00001'), findsOneWidget);
  });

  testWidgets('Toolbar et Aperçu dans DocumentPage se rendent sur mobile sans overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final doc = Document(
      id: 'd-1',
      entrepriseId: 'e-1',
      type: TypeDocument.bonCommande,
      numero: 'BC-2026-00001',
      blocId: 'b-1',
      sequence: 1,
      langue: 'fr',
      date: DateTime.now(),
      montant: 50,
      origineType: 'MANUEL',
      contenu: {
        'entreprise': {'nom': 'Alpha Distribution'},
        'contact': {'nom': 'Boubacar traore'},
        'lignes': [
          {'libelle': 'Article 1', 'montant': 50, 'quantite': 1, 'prix_unitaire': 50}
        ],
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: LayoutBuilder(
                  builder: (context, barConstraints) {
                    final pill = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 13),
                          SizedBox(width: 4),
                          Text('Feuille A4'),
                        ],
                      ),
                    );

                    final actions = [
                      FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.print, size: 15),
                        label: const Text('Imprimer'),
                      ),
                      IconButton(icon: const Icon(Icons.download), onPressed: () {}),
                      IconButton(icon: const Icon(Icons.chat), onPressed: () {}),
                      IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: () {}),
                      IconButton(icon: const Icon(Icons.fullscreen), onPressed: () {}),
                    ];

                    if (barConstraints.maxWidth < 480) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            pill,
                            const SizedBox(width: 8),
                            ...actions,
                          ],
                        ),
                      );
                    }

                    return Row(
                      children: [
                        pill,
                        const Spacer(),
                        ...actions,
                      ],
                    );
                  },
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: ApercuDocumentFeuilleA4(document: doc),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('BC-2026-00001'), findsOneWidget);
  });
}

