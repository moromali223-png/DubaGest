import 'package:flutter_test/flutter_test.dart';
import 'package:dubagest/app/router/app_router.dart';
import 'package:dubagest/app/router/routes.dart';
import 'package:dubagest/features/authentication/domain/entities/auth_state.dart';
import 'package:dubagest/features/super_admin/domain/entities/super_admin_entities.dart';

import '../../helpers/contexte_fixtures.dart';

void main() {
  group('Sécurité de la Navigation Super Admin (globalRedirect)', () {
    const dummyUser = AuthUser(id: 'usr-1', email: 'user@dubagest.com');
    const auth = Authenticated(dummyUser);
    final contextePret = contexte();
    final contexteSansEntreprise = contexte(avecEntreprise: false);

    test('Un utilisateur normal sans privilège Super Admin est refoulé de /super-admin', () {
      final redirection = globalRedirect(
        location: Routes.superAdmin,
        auth: auth,
        contexte: contextePret,
        estSuperAdmin: false,
      );
      expect(redirection, equals(Routes.accessDenied));
    });

    test('Un utilisateur normal est refoulé de toute sous-route /super-admin/*', () {
      final redirection = globalRedirect(
        location: '${Routes.superAdminEntreprises}/ent-123',
        auth: auth,
        contexte: contextePret,
        estSuperAdmin: false,
      );
      expect(redirection, equals(Routes.accessDenied));
    });

    test('Un Super Admin confirmé peut accéder à /super-admin même s\'il n\'a pas d\'entreprise', () {
      final redirection = globalRedirect(
        location: Routes.superAdmin,
        auth: auth,
        contexte: contexteSansEntreprise,
        estSuperAdmin: true,
      );
      // null signifie qu'il n'est pas redirigé et peut entrer sur l'écran
      expect(redirection, isNull);
    });

    test('Un Super Admin confirmé peut accéder aux sous-écrans sans être redirigé vers onboarding', () {
      final redirection = globalRedirect(
        location: Routes.superAdminSponsorises,
        auth: auth,
        contexte: contexteSansEntreprise,
        estSuperAdmin: true,
      );
      expect(redirection, isNull);
    });

    test('Un utilisateur non authentifié tentant d\'accéder à /super-admin est renvoyé vers login', () {
      final redirection = globalRedirect(
        location: Routes.superAdmin,
        auth: const Unauthenticated(),
        contexte: null,
        estSuperAdmin: false,
      );
      expect(redirection, equals(Routes.login));
    });
  });

  group('Entités & Sérialisation Super Admin', () {
    test('AdminEntreprise.fromJson gère les attributs d\'entreprise et le sponsoring', () {
      final json = {
        'id': 'ent-42',
        'nom': 'Société Alpha Test',
        'statut': 'ACTIVE',
        'pays': 'Mali',
        'devise': 'XOF',
        'telephone': '+223 70 00 00 00',
        'ville': 'Bamako',
        'created_at': '2026-10-15T10:00:00.000Z',
        'createur_nom': 'Moussa Diarra',
        'createur_email': 'moussa@alpha.ml',
        'plan_code': 'PRO',
        'abonnement_statut': 'ACTIF',
        'type_facturation': 'SPONSORISE',
        'sponsor_motif': 'Partenaire incubation officiel',
        'valeur_commerciale_reference': 5000,
        'nb_utilisateurs': 4,
        'nb_perimetres': 2,
        'activites': ['COMMERCE', 'SERVICES'],
      };

      final ent = AdminEntreprise.fromJson(json);

      expect(ent.id, equals('ent-42'));
      expect(ent.nom, equals('Société Alpha Test'));
      expect(ent.estSponsorise, isTrue);
      expect(ent.sponsorMotif, equals('Partenaire incubation officiel'));
      expect(ent.valeurCommercialeReference, equals(5000));
      expect(ent.nbUtilisateurs, equals(4));
      expect(ent.nbPerimetres, equals(2));
      expect(ent.activites, containsAll(['COMMERCE', 'SERVICES']));
    });

    test('SuperAdminDashboard.fromJson calcule correctement les métriques globales', () {
      final json = {
        'total_entreprises': 12,
        'entreprises_actives': 10,
        'entreprises_suspendues': 2,
        'abonnements_par_plan': {
          'NORMAL': 4,
          'MOYEN': 5,
          'PRO': 3,
        },
        'abonnements_par_statut': {
          'ACTIF': 9,
          'ESSAI': 3,
        },
        'total_sponsorises': 3,
        'activites_recentes': [
          {
            'id': 'log-1',
            'admin_id': 'adm-007',
            'action': 'ATTRIBUTION_ACCES_SPONSORISE',
            'cible_type': 'ENTREPRISE',
            'cible_id': 'ent-42',
            'details': {'plan': 'PRO', 'motif': 'Partenaire Test'},
            'created_at': '2026-10-17T12:00:00.000Z',
          }
        ]
      };

      final dash = SuperAdminDashboard.fromJson(json);

      expect(dash.totalEntreprises, equals(12));
      expect(dash.entreprisesActives, equals(10));
      expect(dash.entreprisesSuspendues, equals(2));
      expect(dash.totalSponsorises, equals(3));
      expect(dash.abonnementsParPlan['PRO'], equals(3));
      expect(dash.activitesRecentes.length, equals(1));
      expect(dash.activitesRecentes.first.action, equals('ATTRIBUTION_ACCES_SPONSORISE'));
      expect(dash.activitesRecentes.first.details['plan'], equals('PRO'));
    });

    test('AdminAuditLog.fromJson décode avec robustesse les détails non structurés', () {
      final json = {
        'id': 'log-99',
        'admin_id': 'adm-123',
        'admin_email': 'superadmin@dubagest.com',
        'action': 'SUSPENSION_ENTREPRISE',
        'cible_type': 'ENTREPRISE',
        'cible_id': 'ent-bad-actor',
        'details': {'motif': 'Non-respect des CGU', 'ip': '192.168.1.1'},
        'ip_address': '192.168.1.1',
        'created_at': '2026-10-17T14:30:00.000Z',
      };

      final log = AdminAuditLog.fromJson(json);

      expect(log.id, equals('log-99'));
      expect(log.adminEmail, equals('superadmin@dubagest.com'));
      expect(log.action, equals('SUSPENSION_ENTREPRISE'));
      expect(log.cibleType, equals('ENTREPRISE'));
      expect(log.cibleId, equals('ent-bad-actor'));
      expect(log.details['motif'], equals('Non-respect des CGU'));
      expect(log.ipAddress, equals('192.168.1.1'));
    });
  });
}
