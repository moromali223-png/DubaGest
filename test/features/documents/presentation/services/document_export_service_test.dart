import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dubagest/features/documents/domain/entities/document.dart';
import 'package:dubagest/features/documents/presentation/pdf/document_pdf_generator.dart';
import 'package:dubagest/features/documents/presentation/services/document_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocumentExportService & PDF Generation across all 6 document types', () {
    final typesToTest = [
      (TypeDocument.facture, 'FACTURE'),
      (TypeDocument.devis, 'DEVIS'),
      (TypeDocument.bonCommande, 'BON DE COMMANDE'),
      (TypeDocument.bonTravail, 'ORDRE DE TRAVAIL'),
      (TypeDocument.avoir, 'NOTE D\'AVOIR'),
      (TypeDocument.recu, 'REÇU DE RÈGLEMENT'),
    ];

    for (final (type, libelle) in typesToTest) {
      test('Génération PDF et message pour type: $libelle ($type)', () async {
        final doc = Document(
          id: 'doc-${type.name}-1',
          entrepriseId: 'ent-1',
          type: type,
          numero: '${type.name.toUpperCase()}-2026-001',
          blocId: 'bloc-1',
          sequence: 1,
          date: DateTime(2026, 11, 24),
          montant: 125000,
          langue: 'fr',
          origineType: 'VENTE',
          contactId: 'ct-1',
          contenu: {
            'entreprise': {
              'nom': 'DubaGest SARL',
              'adresse': 'Dakar Plateau',
              'telephone': '+221338000000',
              'identifiant_fiscal': 'SN-NIF-987654',
              'registre_commerce': 'SN-DKR-2024-B-1234',
              'devise': 'XOF',
            },
            'contact': {
              'nom': 'Mamadou Diallo',
              'telephone': '+221770000000',
              'adresse': 'Médina, Dakar',
            },
            'lignes': [
              {
                'libelle': 'Article ou prestation de test 1',
                'quantite': 5,
                'prix_unitaire': 15000,
                'montant': 75000,
              },
              {
                'libelle': 'Article ou prestation de test 2',
                'quantite': 2,
                'prix_unitaire': 25000,
                'montant': 50000,
              },
            ],
            'montant_lettres': 'Cent vingt-cinq mille francs CFA',
            'statut': 'EMIS',
            'sous_total': 125000,
            'paye': 50000,
            'reste': 75000,
          },
        );

        // 1. Vérification du formatage du message WhatsApp
        final message = DocumentExportService.preparerMessageDocument(doc, devise: 'FCFA');
        expect(message, contains('DubaGest'));
        expect(message, contains(doc.numero));
        expect(message, contains('125000 FCFA'));

        // 2. Génération PDF réelle
        final pdfBytes = await genererDocumentPdf(doc);
        expect(pdfBytes, isNotNull);
        expect(pdfBytes.length, greaterThan(1000));
        // Signature magique d'un fichier PDF (%PDF-)
        expect(pdfBytes.sublist(0, 4), equals(Uint8List.fromList([0x25, 0x50, 0x44, 0x46])));
      });
    }

    test('Support du format RTL / Arabe dans la génération PDF', () async {
      final docArabe = Document(
        id: 'doc-ar-1',
        entrepriseId: 'ent-1',
        type: TypeDocument.facture,
        numero: 'FAC-AR-001',
        blocId: 'bloc-1',
        sequence: 2,
        date: DateTime(2026, 11, 24),
        montant: 50000,
        langue: 'ar',
        origineType: 'VENTE',
        contenu: {
          'entreprise': {'nom': 'دوباجست', 'devise': 'XOF'},
          'contact': {'nom': 'محمد علي'},
          'lignes': [
            {'libelle': 'سلعة تجارية', 'quantite': 1, 'prix_unitaire': 50000, 'montant': 50000}
          ],
          'montant_lettres': 'خمسون ألف فرنك',
          'statut': 'PAYE',
          'paye': 50000,
          'reste': 0,
        },
      );

      final pdfBytes = await genererDocumentPdf(docArabe);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.sublist(0, 4), equals(Uint8List.fromList([0x25, 0x50, 0x44, 0x46])));
    });
  });
}
