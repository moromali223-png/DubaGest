import 'package:dubagest/features/audit/domain/entities/entree_audit.dart';
import 'package:dubagest/features/audit/domain/repositories/audit_repository.dart';
import 'package:dubagest/features/audit/presentation/pages/audit_page.dart';
import 'package:dubagest/features/audit/presentation/providers/audit_providers.dart';
import 'package:dubagest/features/entreprise/domain/entities/profil_entreprise.dart';
import 'package:dubagest/features/entreprise/presentation/pages/entreprise_page.dart';
import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import 'package:dubagest/features/navigation/presentation/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contexte_fixtures.dart';
import '../helpers/fake_entreprise_repository.dart';
import '../helpers/pump_app.dart';

class _Audit implements AuditRepository {
  @override
  Future<List<EntreeAudit>> lister(String entrepriseId, {int limite = 100, int? avantId, String? entiteId, String? entiteType}) async => [
        EntreeAudit(
          id: 2,
          action: AuditAction.modification,
          entiteType: 'perimetres',
          entiteId: 'b-1',
          date: DateTime(2026, 10, 5, 9, 30),
          auteurId: userId,
          auteurNom: 'Awa Diallo',
          avant: const {'nom': 'Boutique Centre', 'est_actif': true, 'entreprise_id': 'e-1'},
          apres: const {'nom': 'Boutique Centre-Ville', 'est_actif': false, 'entreprise_id': 'e-2'},
        ),
        EntreeAudit(
          id: 1,
          action: AuditAction.creation,
          entiteType: 'invitations',
          entiteId: 'i-1',
          date: DateTime(2026, 10, 4),
          apres: const {'email': 'vendeur@test.local'},
        ),
      ];
}

const _profil = ProfilEntreprise(id: entrepriseId, nom: 'Alpha', devise: 'XOF', langueDocuments: 'fr', pays: 'ML');

void main() {
  testWidgets('journal : actions et champs traduits, aucun nom technique', (tester) async {
    await pumpApp(
      tester,
      const AuditPage(),
      overrides: [
        contexteActifProvider.overrideWithValue(contexte()),
        auditRepositoryProvider.overrideWithValue(_Audit()),
      ],
      size: const Size(390, 900),
    );
    expect(find.text('Modification · Site'), findsOneWidget);
    expect(find.text('Nom : Boutique Centre → Boutique Centre-Ville'), findsOneWidget);
    expect(find.text('Statut : Actif → Inactif'), findsOneWidget);
    expect(find.text('1 autre information'), findsOneWidget, reason: 'entreprise_id masqué');
    expect(find.text('Création · Invitation'), findsOneWidget);
    expect(find.textContaining('Système'), findsOneWidget, reason: 'action sans auteur');
    expect(find.textContaining('perimetres'), findsNothing);
  });

  testWidgets('fiche entreprise : modifiable par l\'administrateur', (tester) async {
    await pumpApp(
      tester,
      const EntreprisePage(),
      overrides: [
        contexteActifProvider.overrideWithValue(contexte()),
        profilEntrepriseProvider.overrideWith((ref) async => _profil),
        entrepriseRepositoryProvider.overrideWithValue(FakeEntrepriseRepository()),
        logoEntrepriseProvider.overrideWith((ref) async => null),
      ],
      size: const Size(390, 1800),
    );
    expect(find.text('Informations légales'), findsOneWidget);
    expect(find.text('XOF (FCFA)'), findsOneWidget);
    expect(find.byKey(const Key('logo-changer')), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('entreprise-save')), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('entreprise-save')), findsOneWidget);
  });

  testWidgets('fiche entreprise : lecture seule sans entreprise.manage', (tester) async {
    await pumpApp(
      tester,
      const EntreprisePage(),
      overrides: [
        contexteActifProvider.overrideWithValue(contexte(role: 'VENDEUR', permissions: {'entreprise.view'})),
        profilEntrepriseProvider.overrideWith((ref) async => _profil),
        entrepriseRepositoryProvider.overrideWithValue(FakeEntrepriseRepository()),
        logoEntrepriseProvider.overrideWith((ref) async => null),
      ],
      size: const Size(390, 1800),
    );
    expect(find.byKey(const Key('entreprise-save')), findsNothing);
    expect(find.byKey(const Key('logo-changer')), findsNothing);
  });

  testWidgets('accueil : changer d\'activité filtre les modules', (tester) async {
    await pumpApp(
      tester,
      const HomePage(),
      overrides: [contexteActifProvider.overrideWithValue(contexte(activites: ['COMMERCE', 'SERVICES']))],
      size: const Size(390, 2000),
    );
    expect(find.textContaining('Vue globale', findRichText: true), findsOneWidget);
    expect(find.byKey(const ValueKey('module-commerce.ventes')), findsOneWidget);
    expect(find.byKey(const ValueKey('module-services.devis')), findsOneWidget);

    await tester.tap(find.byKey(const Key('espace-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('espace-SERVICES')));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byKey(const ValueKey('espace-SERVICES')))).pop();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('module-commerce.ventes')), findsNothing);
    expect(find.byKey(const ValueKey('module-services.devis')), findsOneWidget);
  });
}
