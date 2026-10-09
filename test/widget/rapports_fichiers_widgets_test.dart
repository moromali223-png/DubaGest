import 'package:dubagest/features/agenda/domain/entities/agenda.dart';
import 'package:dubagest/features/contacts/domain/entities/contact.dart';
import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import 'package:dubagest/features/fichiers/domain/fichiers.dart';
import 'package:dubagest/features/fichiers/presentation/fichiers_providers.dart';
import 'package:dubagest/features/fichiers/presentation/section_notes_pieces.dart';
import 'package:dubagest/features/finances/domain/entities/finances.dart';
import 'package:dubagest/features/finances/domain/services/etat_finances.dart';
import 'package:dubagest/features/finances/presentation/providers/finances_providers.dart';
import 'package:dubagest/features/finances/presentation/widgets/finances_widgets.dart';
import 'package:dubagest/features/rapports/domain/rapports.dart';
import 'package:dubagest/features/rapports/presentation/rapports_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contexte_fixtures.dart';
import '../helpers/pump_app.dart';

void main() {
  final maintenant = DateTime.now();

  group('notes et pièces jointes', () {
    List<Object> overrides(String role) => [
          contexteActifProvider.overrideWithValue(contexte(role: role)),
          notesFicheProvider.overrideWith((ref, f) => Stream.value([
                Note(id: 'n1', cibleType: f.type, cibleId: f.id, texte: 'Préfère le matin', createdAt: maintenant,
                    auteurNom: 'Fatou Keita', createdBy: 'u-autre'),
              ])),
          piecesFicheProvider.overrideWith((ref, f) => Stream.value([
                PieceJointe(id: 'p1', cibleType: f.type, cibleId: f.id, chemin: 'x', nomFichier: 'carte.jpg',
                    typeMime: 'image/jpeg', taille: 2048, createdAt: maintenant),
              ])),
        ];

    testWidgets('lecture et ajout selon les droits de la fiche', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: SingleChildScrollView(child: SectionNotesPieces(type: CibleType.contact, cibleId: 'c-1'))),
        overrides: overrides('VENDEUR').cast(),
        size: const Size(420, 1000),
      );
      expect(find.text('Préfère le matin'), findsOneWidget);
      expect(find.text('carte.jpg'), findsOneWidget);
      expect(find.textContaining('2 Ko'), findsOneWidget);
      expect(find.byKey(const Key('note-saisie')), findsOneWidget, reason: 'contacts.update');
      expect(find.byType(PopupMenuButton<String>), findsNothing, reason: 'note d\'un autre, sans administration');
    });

    testWidgets('sans droit de lecture : rien n\'est affiché', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: SectionNotesPieces(type: CibleType.depense, cibleId: 'd-1')),
        overrides: overrides('VENDEUR').cast(),
      );
      expect(find.text('Préfère le matin'), findsNothing);
    });
  });

  group('rapports', () {
    final etat = EtatFinances(engagements: [
      Engagement(id: 'e1', entrepriseId: entrepriseId, sens: SensEngagement.aRecevoir, libelle: 'Crédit',
          montantTotal: 40000, dateEngagement: DateTime(2026, 1, 1), contactId: 'c-1',
          echeance: maintenant.subtract(const Duration(days: 45))),
    ]);
    List<Object> overrides({String role = 'ADMINISTRATEUR', Set<String>? permissions}) => [
          contexteActifProvider.overrideWithValue(contexte(role: role, permissions: permissions)),
          etatFinancesProvider.overrideWith((ref) => Stream.value(etat)),
          contactsParIdProvider.overrideWith(
              (ref) => Stream.value({'c-1': const Contact(id: 'c-1', entrepriseId: entrepriseId, nom: 'Traoré')})),
        ];

    testWidgets('liste : seulement les rapports dont on voit les données', (tester) async {
      await pumpApp(
        tester,
        const RapportsPage(),
        overrides: overrides(role: 'VENDEUR', permissions: {'reports.view', 'receivables.view'}).cast(),
        size: const Size(480, 1200),
      );
      expect(find.byKey(const Key('rapport-balanceAgee')), findsOneWidget);
      expect(find.byKey(const Key('rapport-tresorerie')), findsNothing);
      expect(find.byKey(const Key('rapport-caisses')), findsNothing);
    });

    testWidgets('balance âgée : tableau à l\'écran, export PDF proposé', (tester) async {
      await pumpApp(tester, const RapportPage(type: TypeRapport.balanceAgee),
          overrides: overrides().cast(), size: const Size(900, 1000));
      expect(find.byKey(const Key('rapport-tableau')), findsOneWidget);
      expect(find.text('Traoré'), findsOneWidget);
      expect(find.text('31 à 60 j'), findsOneWidget);
      expect(find.byKey(const Key('rapport-pdf')), findsOneWidget);
    });
  });
}
