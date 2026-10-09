import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/core/permissions/access_decision.dart';
import 'package:dubagest/features/activites/domain/entities/activite.dart';
import 'package:dubagest/features/invitations/domain/entities/invitation.dart';
import 'package:dubagest/features/invitations/domain/repositories/invitation_repository.dart';
import 'package:dubagest/features/invitations/domain/usecases/gerer_invitations.dart';
import 'package:dubagest/features/perimetres/domain/entities/perimetre.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/contexte_fixtures.dart';

class _Repo implements InvitationRepository {
  ({String email, String role, List<String> perimetres})? creee;
  String? jeton = 'abc';

  @override
  Future<InvitationCreee> creer({
    required String entrepriseId,
    required String email,
    required String roleCode,
    required List<String> perimetreIds,
  }) async {
    creee = (email: email, role: roleCode, perimetres: perimetreIds);
    return InvitationCreee(id: 'i', token: 't', expiresAt: DateTime(2026, 10, 10));
  }

  @override
  Future<String> accepter(String token) async => entrepriseId;
  @override
  Future<void> annuler(String invitationId) async {}
  @override
  Future<List<Invitation>> lister(String entrepriseId) async => const [];
  @override
  Future<InvitationApercu> verifier(String token) async =>
      const InvitationApercu(statut: InvitationStatut.pending);
  @override
  String? get jetonEnAttente => jeton;
  @override
  Future<void> memoriserJeton(String token) async => jeton = token;
  @override
  Future<void> oublierJeton() async => jeton = null;
}

void main() {
  late _Repo repo;
  setUp(() => repo = _Repo());

  const boutiqueA = Perimetre(
    id: 'b-a', entrepriseId: entrepriseId, activite: ActiviteCode.commerce,
    type: PerimetreType.boutique, nom: 'A');
  const agence = Perimetre(
    id: 'ag', entrepriseId: entrepriseId, activite: ActiviteCode.services,
    type: PerimetreType.agence, nom: 'Agence');

  test('rôles proposés = rôles du plan ; quota atteint signalé', () {
    final ctx = contexte(
      plan: 'NORMAL',
      utilisateurs: 2,
      membresParRole: {'ADMINISTRATEUR': 1, 'VENDEUR': 1},
    );
    final roles = CreerInvitation(repo).rolesProposables(ctx);
    expect(roles.keys, containsAll(['ADMINISTRATEUR', 'GESTIONNAIRE_STOCK', 'VENDEUR']));
    expect(roles.keys, isNot(contains('SUPERVISEUR')), reason: 'pas de superviseur en NORMAL');
    expect(roles['GESTIONNAIRE_STOCK']!.isAllowed, isTrue);
    expect((roles['VENDEUR']! as AccessDenied).ruleCode, RuleCodes.roleLimit);
  });

  test('l\'invitation fixe le rôle et les périmètres (e-mail normalisé)', () async {
    await CreerInvitation(repo).call(contexte(),
        email: ' Vendeur@Gmail.com ', roleCode: 'VENDEUR', perimetres: [boutiqueA]);
    expect(repo.creee!.email, 'vendeur@gmail.com');
    expect(repo.creee!.role, 'VENDEUR');
    expect(repo.creee!.perimetres, ['b-a']);
  });

  test('rôle restreint sans périmètre → refus', () {
    expect(
      () => CreerInvitation(repo).call(contexte(), email: 'x@y.io', roleCode: 'VENDEUR', perimetres: []),
      throwsA(isA<Failure>().having((f) => f.ruleCode, 'règle', RuleCodes.perimetreRequired)),
    );
  });

  test('périmètre hors activité du rôle → refus', () {
    expect(
      () => CreerInvitation(repo).call(contexte(activites: ['COMMERCE', 'SERVICES']),
          email: 'x@y.io', roleCode: 'GESTIONNAIRE_STOCK', perimetres: [agence]),
      throwsA(isA<Failure>().having((f) => f.ruleCode, 'règle', RuleCodes.assignmentActivityMismatch)),
    );
  });

  test('sans users.invite : impossible d\'inviter', () {
    expect(
      () => CreerInvitation(repo).call(contexte(role: 'VENDEUR'),
          email: 'x@y.io', roleCode: 'VENDEUR', perimetres: [boutiqueA]),
      throwsA(isA<Failure>().having((f) => f.ruleCode, 'règle', RuleCodes.permissionDenied)),
    );
    expect(repo.creee, isNull);
  });

  test('acceptation : le jeton en attente est oublié', () async {
    await AccepterInvitation(repo).call('abc');
    expect(repo.jeton, isNull);
  });

  test('une invitation en attente dont la date est passée est expirée', () {
    final inv = Invitation(
      id: 'i', email: 'e', roleCode: 'VENDEUR', statut: InvitationStatut.pending,
      expiresAt: DateTime(2026, 10, 1), createdAt: DateTime(2026, 9, 24));
    expect(inv.statutEffectif(DateTime(2026, 10, 3)), InvitationStatut.expired);
    expect(inv.statutEffectif(DateTime(2026, 9, 30)), InvitationStatut.pending);
  });
}
