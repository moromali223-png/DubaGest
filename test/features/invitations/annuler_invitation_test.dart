import 'package:dubagest/features/activites/domain/entities/activite.dart';
import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import 'package:dubagest/features/invitations/domain/entities/invitation.dart';
import 'package:dubagest/features/invitations/domain/repositories/invitation_repository.dart';
import 'package:dubagest/features/invitations/presentation/providers/invitations_providers.dart';
import 'package:dubagest/features/invitations/presentation/widgets/invitations_section.dart';
import 'package:dubagest/features/invitations/presentation/widgets/inviter_sheet.dart';
import 'package:dubagest/features/perimetres/domain/entities/perimetre.dart';
import 'package:dubagest/features/perimetres/presentation/providers/perimetres_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/contexte_fixtures.dart';
import '../../helpers/fake_entreprise_repository.dart';
import '../../helpers/pump_app.dart';

class FakeInvitationRepository implements InvitationRepository {
  String? derniereInvitationAnnuleeId;
  String? derniereInvitationCreeeEmail;

  @override
  String? get jetonEnAttente => null;

  @override
  Future<void> memoriserJeton(String token) async {}

  @override
  Future<void> oublierJeton() async {}

  @override
  Future<InvitationCreee> creer({
    required String entrepriseId,
    required String email,
    required String roleCode,
    required List<String> perimetreIds,
  }) async {
    derniereInvitationCreeeEmail = email;
    return InvitationCreee(id: 'inv-new', token: 'token-fresh-123', expiresAt: DateTime.now().add(const Duration(days: 7)));
  }

  @override
  Future<List<Invitation>> lister(String entrepriseId) async => [
        Invitation(
          id: 'inv-1',
          email: 'vendeur@dubagest.com',
          roleCode: 'VENDEUR',
          statut: InvitationStatut.pending,
          expiresAt: DateTime.now().add(const Duration(days: 7)),
          createdAt: DateTime.now(),
        ),
      ];

  @override
  Future<void> annuler(String invitationId) async {
    derniereInvitationAnnuleeId = invitationId;
  }

  @override
  Future<InvitationCreee> renvoyer(String invitationId) async {
    derniereInvitationCreeeEmail = 'vendeur@dubagest.com';
    return InvitationCreee(id: invitationId, token: 'renewed-token', expiresAt: DateTime.now().add(const Duration(days: 7)));
  }

  @override
  Future<void> supprimer(String invitationId) async {}

  @override
  Future<InvitationApercu> verifier(String token) async {
    return const InvitationApercu(statut: InvitationStatut.pending, entrepriseNom: 'Entreprise ABC', roleCode: 'VENDEUR');
  }

  @override
  Future<String> accepter(String token) async => 'e-1';
}

void main() {
  late FakeInvitationRepository repo;

  setUp(() {
    repo = FakeInvitationRepository();
  });

  final List<Perimetre> perimetresTest = [
    const Perimetre(id: 'p-1', entrepriseId: 'e-1', activite: ActiviteCode.commerce, type: PerimetreType.boutique, nom: 'Boutique A'),
  ];

  testWidgets('InvitationsSection : affiche l\'invitation en attente et permet de copier le lien', (tester) async {
    final ctx = contexte(
      role: 'ADMINISTRATEUR',
      permissions: {'users.view', 'users.invite'},
      perimetres: [perimetreJson('p-1', nom: 'Boutique A')],
    );

    await pumpApp(
      tester,
      const Scaffold(
        body: SingleChildScrollView(
          child: InvitationsSection(),
        ),
      ),
      overrides: [
        contexteActifProvider.overrideWithValue(ctx),
        entrepriseRepositoryProvider.overrideWithValue(FakeEntrepriseRepository()),
        invitationRepositoryProvider.overrideWithValue(repo),
        perimetresProvider.overrideWith((ref) => Stream.value(perimetresTest)),
      ],
    );

    expect(find.text('vendeur@dubagest.com'), findsOneWidget);
    expect(find.text('En attente'), findsOneWidget);
    expect(find.byKey(const Key('btn-copy-invitation-inv-1')), findsOneWidget);
    expect(find.byKey(const Key('btn-cancel-invitation-inv-1')), findsOneWidget);

    // Cliquer sur le bouton copier / renvoyer le lien
    await tester.tap(find.byKey(const Key('btn-copy-invitation-inv-1')));
    await tester.pumpAndSettle();

    expect(repo.derniereInvitationCreeeEmail, 'vendeur@dubagest.com');
  });

  testWidgets('InvitationsSection : permet d\'annuler une invitation avec confirmation', (tester) async {
    final ctx = contexte(
      role: 'ADMINISTRATEUR',
      permissions: {'users.view', 'users.invite'},
      perimetres: [perimetreJson('p-1', nom: 'Boutique A')],
    );

    await pumpApp(
      tester,
      const Scaffold(
        body: SingleChildScrollView(
          child: InvitationsSection(),
        ),
      ),
      overrides: [
        contexteActifProvider.overrideWithValue(ctx),
        entrepriseRepositoryProvider.overrideWithValue(FakeEntrepriseRepository()),
        invitationRepositoryProvider.overrideWithValue(repo),
        perimetresProvider.overrideWith((ref) => Stream.value(perimetresTest)),
      ],
    );

    // Cliquer sur le bouton annuler
    await tester.tap(find.byKey(const Key('btn-cancel-invitation-inv-1')));
    await tester.pumpAndSettle();

    // Dialogue de confirmation
    expect(find.text('Annuler l\'invitation ?'), findsOneWidget);
    await tester.tap(find.text('Annuler l\'invitation'));
    await tester.pumpAndSettle();

    expect(repo.derniereInvitationAnnuleeId, 'inv-1');
  });
}
