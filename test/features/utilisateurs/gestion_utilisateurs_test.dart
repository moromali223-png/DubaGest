import 'package:dubagest/features/activites/domain/entities/activite.dart';
import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import 'package:dubagest/features/perimetres/domain/entities/perimetre.dart';
import 'package:dubagest/features/perimetres/presentation/providers/perimetres_providers.dart';
import 'package:dubagest/features/utilisateurs/domain/entities/membre.dart';
import 'package:dubagest/features/utilisateurs/domain/repositories/membre_repository.dart';
import 'package:dubagest/features/utilisateurs/presentation/providers/membres_providers.dart';
import 'package:dubagest/features/utilisateurs/presentation/widgets/affectations_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/contexte_fixtures.dart';
import '../../helpers/fake_entreprise_repository.dart';
import '../../helpers/pump_app.dart';

class FakeMembreRepository implements MembreRepository {
  String? dernierRoleModifie;
  String? dernierStatutModifie;
  String? dernierMembreSupprime;
  final List<String> affectations = [];
  final List<String> retraits = [];

  @override
  Future<List<Membre>> lister(String entrepriseId) async => const [];

  @override
  Future<void> affecter({
    required String entrepriseId,
    required String membreId,
    required String perimetreId,
  }) async {
    affectations.add(perimetreId);
  }

  @override
  Future<void> retirer({required String membreId, required String perimetreId}) async {
    retraits.add(perimetreId);
  }

  @override
  Future<void> modifierRole({
    required String entrepriseId,
    required String membreId,
    required String roleCode,
  }) async {
    dernierRoleModifie = roleCode;
  }

  @override
  Future<void> modifierStatut({
    required String entrepriseId,
    required String membreId,
    required String statut,
  }) async {
    dernierStatutModifie = statut;
  }

  @override
  Future<void> supprimer({
    required String entrepriseId,
    required String membreId,
  }) async {
    dernierMembreSupprime = membreId;
  }
}

void main() {
  late FakeMembreRepository repo;

  setUp(() {
    repo = FakeMembreRepository();
  });

  final List<Perimetre> perimetresTest = [
    const Perimetre(id: 'p-1', entrepriseId: 'e-1', activite: ActiviteCode.commerce, type: PerimetreType.boutique, nom: 'Boutique A'),
    const Perimetre(id: 'p-2', entrepriseId: 'e-1', activite: ActiviteCode.commerce, type: PerimetreType.boutique, nom: 'Boutique B'),
  ];

  const membreVendeur = Membre(
    id: 'm-123',
    userId: 'u-456',
    roleCode: 'VENDEUR',
    statut: MembreStatut.actif,
    nomComplet: 'Ibrahim Traoré',
    perimetreIds: {'p-1'},
  );

  testWidgets('Fiche membre : affiche le nom, le statut, le rôle et les périmètres', (tester) async {
    final ctx = contexte(
      role: 'ADMINISTRATEUR',
      permissions: {'users.view', 'users.manage'},
      perimetres: [perimetreJson('p-1', nom: 'Boutique A'), perimetreJson('p-2', nom: 'Boutique B')],
    );

    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAffectationsSheet(context, membreVendeur),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
      overrides: [
        contexteActifProvider.overrideWithValue(ctx),
        entrepriseRepositoryProvider.overrideWithValue(FakeEntrepriseRepository()),
        membreRepositoryProvider.overrideWithValue(repo),
        perimetresProvider.overrideWith((ref) => Stream.value(perimetresTest)),
      ],
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ibrahim Traoré'), findsOneWidget);
    expect(find.text('Actif'), findsOneWidget);
    expect(find.byKey(const Key('select-membre-role')), findsOneWidget);
    expect(find.byKey(const Key('switch-membre-statut')), findsOneWidget);
    expect(find.byKey(const Key('btn-supprimer-membre')), findsOneWidget);
    expect(find.text('Boutique A'), findsOneWidget);
    expect(find.text('Boutique B'), findsOneWidget);
  });

  testWidgets('Fiche membre : basculer le statut suspend/active le compte', (tester) async {
    final ctx = contexte(
      role: 'ADMINISTRATEUR',
      permissions: {'users.view', 'users.manage'},
    );

    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAffectationsSheet(context, membreVendeur),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
      overrides: [
        contexteActifProvider.overrideWithValue(ctx),
        entrepriseRepositoryProvider.overrideWithValue(FakeEntrepriseRepository()),
        membreRepositoryProvider.overrideWithValue(repo),
        perimetresProvider.overrideWith((ref) => Stream.value(perimetresTest)),
      ],
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('switch-membre-statut')));
    await tester.pumpAndSettle();

    expect(repo.dernierStatutModifie, 'SUSPENDU');
  });

  testWidgets('Fiche membre : suppression avec confirmation supprime le membre', (tester) async {
    final ctx = contexte(
      role: 'ADMINISTRATEUR',
      permissions: {'users.view', 'users.manage'},
    );

    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAffectationsSheet(context, membreVendeur),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
      overrides: [
        contexteActifProvider.overrideWithValue(ctx),
        entrepriseRepositoryProvider.overrideWithValue(FakeEntrepriseRepository()),
        membreRepositoryProvider.overrideWithValue(repo),
        perimetresProvider.overrideWith((ref) => Stream.value(perimetresTest)),
      ],
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('btn-supprimer-membre')));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer cet utilisateur ?'), findsOneWidget);
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(repo.dernierMembreSupprime, 'm-123');
  });
}
