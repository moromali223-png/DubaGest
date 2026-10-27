import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/core/permissions/access_decision.dart';
import 'package:dubagest/core/permissions/permission_codes.dart';
import 'package:dubagest/features/abonnement/domain/entities/abonnement.dart';
import 'package:dubagest/features/activites/domain/entities/activite.dart';
import 'package:dubagest/features/entreprise/domain/entities/contexte_session.dart';
import 'package:dubagest/features/invitations/domain/entities/invitation.dart';
import 'package:dubagest/features/invitations/domain/repositories/invitation_repository.dart';
import 'package:dubagest/features/invitations/domain/usecases/gerer_invitations.dart';
import 'package:dubagest/features/perimetres/domain/entities/perimetre.dart';
import 'package:dubagest/features/utilisateurs/domain/entities/membre.dart';
import 'package:dubagest/features/utilisateurs/domain/repositories/membre_repository.dart';
import 'package:dubagest/features/utilisateurs/domain/usecases/gerer_membres.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/contexte_fixtures.dart';

class _FakeMembreRepo implements MembreRepository {
  final List<Membre> membres = [];
  String? dernierRoleModifie;
  String? dernierStatutModifie;
  String? dernierMembreSupprimeId;

  @override
  Future<List<Membre>> lister(String entrepriseId) async => membres;

  @override
  Future<void> affecter({
    required String entrepriseId,
    required String membreId,
    required String perimetreId,
  }) async {}

  @override
  Future<void> retirer({required String membreId, required String perimetreId}) async {}

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
  Future<void> supprimer({required String entrepriseId, required String membreId}) async {
    dernierMembreSupprimeId = membreId;
  }
}

class _FakeInvitationRepo implements InvitationRepository {
  final List<Invitation> invitations = [];
  String? derniereSupprimeeId;
  String? derniereRenouveleeId;

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
  }) async =>
      InvitationCreee(id: 'new-inv', token: 'token-new', expiresAt: DateTime.now().add(const Duration(days: 7)));

  @override
  Future<InvitationCreee> renvoyer(String invitationId) async {
    derniereRenouveleeId = invitationId;
    return InvitationCreee(id: invitationId, token: 'token-fresh', expiresAt: DateTime.now().add(const Duration(days: 7)));
  }

  @override
  Future<void> supprimer(String invitationId) async {
    derniereSupprimeeId = invitationId;
    invitations.removeWhere((i) => i.id == invitationId);
  }

  @override
  Future<void> annuler(String invitationId) async {
    invitations.removeWhere((i) => i.id == invitationId);
  }

  @override
  Future<List<Invitation>> lister(String entrepriseId) async => invitations;

  @override
  Future<InvitationApercu> verifier(String token) async =>
      const InvitationApercu(statut: InvitationStatut.pending);

  @override
  Future<String> accepter(String token) async => 'e-1';
}

void main() {
  group('Gestion Sécurisée des Membres et Quotas', () {
    late _FakeMembreRepo membreRepo;
    late _FakeInvitationRepo invitationRepo;

    setUp(() {
      membreRepo = _FakeMembreRepo();
      invitationRepo = _FakeInvitationRepo();
    });

    test('ConsommationAbonnement décompte exactement les places actives, en attente et totales', () {
      const conso = ConsommationAbonnement(
        utilisateurs: 3,
        utilisateursActifs: 2,
        invitationsEnAttente: 1,
        utilisateursMax: 3,
        membresParRole: {'ADMINISTRATEUR': 1, 'VENDEUR': 1},
        perimetresParActivite: {},
      );

      expect(conso.actifs, 2);
      expect(conso.enAttente, 1);
      expect(conso.totalOccupes, 3);
      expect(conso.utilisateursMax, 3);
    });

    test('VerifierAjoutMembre autorise si le forfait n\'a pas atteint la limite', () {
      final ctx = contexte(
        plan: 'NORMAL', // max = 3
        utilisateurs: 2,
      );

      final decision = const VerifierAjoutMembre().call(ctx);
      expect(decision.isAllowed, isTrue);
    });

    test('VerifierAjoutMembre refuse avec LIMITE_UTILISATEURS si places pleines', () {
      final ctx = contexte(
        plan: 'NORMAL', // max = 3
        utilisateurs: 3,
      );

      final decision = const VerifierAjoutMembre().call(ctx);
      expect(decision.isAllowed, isFalse);
      expect((decision as AccessDenied).ruleCode, RuleCodes.usersLimit);
    });

    test('ModifierStatutMembre modifie le statut d\'un collaborateur', () async {
      final usecase = ModifierStatutMembre(membreRepo);
      final ctx = contexte();
      const membre = Membre(
        id: 'm-1',
        userId: 'u-1',
        roleCode: 'VENDEUR',
        statut: MembreStatut.actif,
      );

      await usecase.call(ctx, membre, MembreStatut.suspendu);
      expect(membreRepo.dernierStatutModifie, 'SUSPENDU');
    });

    test('SupprimerMembre révoque l\'utilisateur de l\'entreprise', () async {
      final usecase = SupprimerMembre(membreRepo);
      final ctx = contexte();
      const membre = Membre(
        id: 'm-1',
        userId: 'u-1',
        roleCode: 'VENDEUR',
        statut: MembreStatut.actif,
      );

      await usecase.call(ctx, membre);
      expect(membreRepo.dernierMembreSupprimeId, 'm-1');
    });

    test('RenvoyerInvitation régénère le jeton et prolonge la validité', () async {
      final usecase = RenvoyerInvitation(invitationRepo);
      final ctx = contexte();
      final inv = Invitation(
        id: 'inv-123',
        email: 'collaborateur@test.com',
        roleCode: 'VENDEUR',
        statut: InvitationStatut.pending,
        expiresAt: DateTime.now().add(const Duration(days: 1)),
        createdAt: DateTime.now(),
      );

      final resultat = await usecase.call(ctx, inv);
      expect(resultat.id, 'inv-123');
      expect(resultat.token, 'token-fresh');
      expect(invitationRepo.derniereRenouveleeId, 'inv-123');
    });

    test('SupprimerInvitation retire l\'invitation archivée ou expirée', () async {
      final usecase = SupprimerInvitation(invitationRepo);
      final ctx = contexte();
      final inv = Invitation(
        id: 'inv-exp',
        email: 'ancien@test.com',
        roleCode: 'VENDEUR',
        statut: InvitationStatut.expired,
        expiresAt: DateTime.now().subtract(const Duration(days: 2)),
        createdAt: DateTime.now().subtract(const Duration(days: 9)),
      );

      await usecase.call(ctx, inv);
      expect(invitationRepo.derniereSupprimeeId, 'inv-exp');
    });
  });
}
