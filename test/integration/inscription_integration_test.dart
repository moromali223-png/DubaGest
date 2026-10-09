@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/core/permissions/access_decision.dart';
import 'package:dubagest/features/activites/domain/entities/activite.dart';
import 'package:dubagest/features/activites/domain/usecases/activer_activite.dart';
import 'package:dubagest/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:dubagest/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:dubagest/features/authentication/domain/repositories/auth_repository.dart';
import 'package:dubagest/features/entreprise/data/datasources/contexte_remote_data_source.dart';
import 'package:dubagest/features/entreprise/data/models/contexte_session_model.dart';
import 'package:dubagest/features/entreprise/data/repositories/entreprise_repository_impl.dart';
import 'package:dubagest/features/entreprise/domain/entities/contexte_session.dart';
import 'package:dubagest/features/entreprise/domain/usecases/creer_entreprise.dart';
import 'package:dubagest/features/invitations/data/datasources/invitation_data_sources.dart';
import 'package:dubagest/features/invitations/data/repositories/invitation_repository_impl.dart';
import 'package:dubagest/features/invitations/domain/entities/invitation.dart';
import 'package:dubagest/features/invitations/domain/usecases/gerer_invitations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Parcours complet contre Supabase Local, confirmation d'e-mail via Mailpit.
///   flutter test --tags integration
const _url = 'http://127.0.0.1:54321';
const _mailpit = 'http://127.0.0.1:54324';
const _key = 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH';
const _password = 'MotDePasse123!';

final _run = DateTime.now().millisecondsSinceEpoch;
String email(String nom) => '$nom.$_run@test.local';
bool _available = false;

/// Stockage du vérificateur PKCE (fourni par supabase_flutter dans l'app).
class _MemoryStorage extends GotrueAsyncStorage {
  final _values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _values[key];
  @override
  Future<void> setItem({required String key, required String value}) async => _values[key] = value;
  @override
  Future<void> removeItem({required String key}) async => _values.remove(key);
}

SupabaseClient nouveauClient() => SupabaseClient(_url, _key,
    authOptions: AuthClientOptions(autoRefreshToken: false, pkceAsyncStorage: _MemoryStorage()));

AuthRepository authDe(SupabaseClient c) =>
    AuthRepositoryImpl(SupabaseAuthDataSource(c.auth, redirectUrl: 'http://127.0.0.1:3000'));

Future<Map<String, dynamic>> _getJson(String url) async {
  final http = HttpClient();
  try {
    final res = await (await http.getUrl(Uri.parse(url))).close();
    return jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
  } finally {
    http.close();
  }
}

/// Récupère le dernier e-mail reçu par [adresse] dans Mailpit.
Future<String> dernierEmail(String adresse) async {
  for (var i = 0; i < 20; i++) {
    final res = await _getJson('$_mailpit/api/v1/search?query=${Uri.encodeQueryComponent('to:$adresse')}');
    final messages = (res['messages'] as List).cast<Map<String, dynamic>>();
    if (messages.isNotEmpty) {
      final msg = await _getJson('$_mailpit/api/v1/message/${messages.first['ID']}');
      return msg['Text'] as String;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw StateError('Aucun e-mail pour $adresse');
}

/// Simule le clic sur le lien de confirmation reçu par e-mail.
Future<void> confirmerEmail(String adresse) async {
  final texte = await dernierEmail(adresse);
  final lien = RegExp(r'http://127\.0\.0\.1:54321/auth/v1/verify\?[^\s)]+').firstMatch(texte)!.group(0)!;
  final http = HttpClient();
  try {
    final req = await http.getUrl(Uri.parse(lien));
    req.followRedirects = false;
    await (await req.close()).drain<void>();
  } finally {
    http.close();
  }
}

/// Inscription par e-mail + confirmation + connexion.
Future<SupabaseClient> compteConfirme(String adresse, {String prenom = 'Test', String nom = 'User'}) async {
  final client = nouveauClient();
  final auth = authDe(client);
  final result = await auth.signUp(prenom: prenom, nom: nom, email: adresse, password: _password);
  // Confirmation désactivée (dev local) : session ouverte directement.
  if (result == SignUpResult.confirmationRequired) {
    await confirmerEmail(adresse);
    await auth.signIn(email: adresse, password: _password);
  }
  return client;
}

Future<ContexteSession> contexteDe(SupabaseClient c) async => ContexteSessionModel.fromJson(
      await SupabaseContexteRemoteDataSource(c).fetch(),
      userId: c.auth.currentUser!.id,
      chargeLe: DateTime.now(),
      depuisCache: false,
    );

Future<InvitationRepositoryImpl> invitationsDe(SupabaseClient c) async {
  SharedPreferences.setMockInitialValues({});
  return InvitationRepositoryImpl(
    remote: InvitationRemoteDataSource(c),
    local: InvitationLocalDataSource(await SharedPreferences.getInstance()),
  );
}

Matcher regle(String code) =>
    throwsA(isA<Failure>().having((f) => f.ruleCode, 'règle', code));

void main() {
  late SupabaseClient createur;
  late ContexteSession ctxAdmin;

  setUpAll(() async {
    try {
      await _getJson('$_mailpit/api/v1/messages?limit=1');
      final c = nouveauClient();
      await c.auth.signInWithPassword(email: 'admin@alpha.test', password: 'Password123!');
      _available = true;
    } catch (_) {
      _available = false;
    }
  });

  void skipIfOffline() => markTestSkipped('Supabase Local / Mailpit indisponible');

  test('inscription e-mail puis connexion (avec ou sans confirmation selon la config)', () async {
    if (!_available) return skipIfOffline();
    final adresse = email('createur');
    final client = nouveauClient();
    final auth = authDe(client);

    final result =
        await auth.signUp(prenom: 'Moussa', nom: 'Traoré', email: adresse, password: _password);
    if (result == SignUpResult.confirmationRequired) {
      await expectLater(auth.signIn(email: adresse, password: _password),
          throwsA(isA<Failure>().having((f) => f.kind, 'kind', FailureKind.emailNotConfirmed)));
      await confirmerEmail(adresse);
    } else {
      await auth.signOut();
    }
    await auth.signIn(email: adresse, password: _password);
    expect(client.auth.currentUser?.email, adresse);
    createur = client;
  });

  test('compte existant → « Ce compte existe déjà »', () async {
    if (!_available) return skipIfOffline();
    await expectLater(
      authDe(nouveauClient()).signUp(prenom: 'A', nom: 'B', email: 'admin@alpha.test', password: _password),
      throwsA(isA<Failure>().having((f) => f.kind, 'kind', FailureKind.accountExists)),
    );
  });

  test('compte sans entreprise : aucun rôle, aucune permission', () async {
    if (!_available) return skipIfOffline();
    final ctx = await contexteDe(createur);
    expect(ctx.etat, ContexteEtat.aucuneEntreprise);
    expect(ctx.permissions, isEmpty);
    expect(ctx.nomComplet, 'Moussa Traoré');
  });

  test('créer mon entreprise → le créateur devient administrateur', () async {
    if (!_available) return skipIfOffline();
    final creer = CreerEntreprise(EntrepriseRepositoryImpl(createur));
    final offres = await creer.offres();
    expect(offres.map((o) => o.code), ['NORMAL', 'MOYEN', 'PRO']);
    expect(offres.map((o) => o.prixMensuel), [1000, 2000, 5000]);
    final moyen = offres.firstWhere((o) => o.code == 'MOYEN');

    await creer(nom: 'ABC Commerce $_run', offre: moyen, activites: {ActiviteCode.commerce});
    ctxAdmin = await contexteDe(createur);
    expect(ctxAdmin.etat, ContexteEtat.pret);
    expect(ctxAdmin.membre!.roleCode, 'ADMINISTRATEUR');
    expect(ctxAdmin.abonnement!.statut.code, 'ESSAI');
    expect(ctxAdmin.perimetres.map((p) => p.nom), ['Boutique principale']);

    await expectLater(
        creer(nom: 'Deuxième', offre: moyen, activites: {ActiviteCode.services}),
        regle(RuleCodes.companyAlreadyCreated));

    // Seconde boutique (MOYEN = 2 boutiques).
    await createur.from('perimetres').insert({
      'entreprise_id': ctxAdmin.entreprise!.id,
      'activite_code': 'COMMERCE',
      'type': 'BOUTIQUE',
      'nom': 'Boutique B',
    });
    ctxAdmin = await contexteDe(createur);
  });

  test('invitation Vendeur → Boutique principale uniquement', () async {
    if (!_available) return skipIfOffline();
    final principale = ctxAdmin.perimetres.firstWhere((p) => p.nom == 'Boutique principale');
    final adresse = email('vendeur');
    final creee = await CreerInvitation(await invitationsDe(createur))
        .call(ctxAdmin, email: adresse, roleCode: 'VENDEUR', perimetres: [principale]);

    final invite = await compteConfirme(adresse, prenom: 'Fatou', nom: 'Keita');
    final repoInvite = await invitationsDe(invite);

    final apercu = await VerifierInvitation(repoInvite).call(creee.token);
    expect(apercu.statut, InvitationStatut.pending);
    expect(apercu.roleCode, 'VENDEUR');

    await AccepterInvitation(repoInvite).call(creee.token);
    final ctx = await contexteDe(invite);
    expect(ctx.membre!.roleCode, 'VENDEUR');
    expect(ctx.permissions, contains('sales.create'));
    expect(ctx.permissions, isNot(contains('users.invite')));
    expect(ctx.perimetres.map((p) => p.nom), ['Boutique principale']);

    // RLS : la Boutique B et les autres entreprises restent invisibles.
    final visibles = await invite.from('perimetres').select('nom');
    expect(visibles.map((r) => r['nom']), ['Boutique principale']);
    expect(await invite.from('entreprises').select('id').eq('id', 'aaaaaaaa-0000-0000-0000-000000000001'),
        isEmpty);

    await expectLater(AccepterInvitation(repoInvite).call(creee.token), regle(RuleCodes.invitationUsed));
  });

  test('invitation Gestionnaire de stock → Boutique B ; autre adresse refusée', () async {
    if (!_available) return skipIfOffline();
    final boutiqueB = ctxAdmin.perimetres.firstWhere((p) => p.nom == 'Boutique B');
    final adresse = email('stock');
    final creee = await CreerInvitation(await invitationsDe(createur))
        .call(ctxAdmin, email: adresse, roleCode: 'GESTIONNAIRE_STOCK', perimetres: [boutiqueB]);

    final intrus = await compteConfirme(email('intrus'));
    await expectLater(AccepterInvitation(await invitationsDe(intrus)).call(creee.token),
        regle(RuleCodes.invitationOtherEmail));

    final gestionnaire = await compteConfirme(adresse);
    await AccepterInvitation(await invitationsDe(gestionnaire)).call(creee.token);
    final ctx = await contexteDe(gestionnaire);
    expect(ctx.membre!.roleCode, 'GESTIONNAIRE_STOCK');
    expect(ctx.permissions, containsAll(['stock.view', 'stock.update']));
    expect(ctx.permissions, isNot(contains('sales.create')));
    expect(ctx.perimetres.map((p) => p.nom), ['Boutique B']);
  });

  test('un invité ne peut pas inviter (ni se donner un rôle)', () async {
    if (!_available) return skipIfOffline();
    final ctx = await contexteDe(createur);
    final vendeur = await compteConfirme(email('vendeur2'));
    await expectLater(
      vendeur.rpc<dynamic>('creer_invitation', params: {
        'p_entreprise_id': ctx.entreprise!.id,
        'p_email': 'pirate@test.local',
        'p_role_code': 'ADMINISTRATEUR',
        'p_perimetre_ids': <String>[],
      }),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
  });

  test('ajouter une activité plus tard : 2e acceptée, 3e refusée par le serveur', () async {
    if (!_available) return skipIfOffline();
    final repo = EntrepriseRepositoryImpl(createur);
    final ctx = await contexteDe(createur);
    await ActiverActivite(repo).call(ctx, ActiviteCode.services);
    final apres = await contexteDe(createur);
    expect(apres.activites.where((a) => a.estActive).map((a) => a.activite),
        containsAll([ActiviteCode.commerce, ActiviteCode.services]));

    // Contournement du contrôle Flutter : le trigger PostgreSQL refuse.
    await expectLater(
      repo.activerActivite(
          entrepriseId: apres.entreprise!.id, activite: ActiviteCode.immobilier, dejaRattachee: false),
      regle(RuleCodes.activitiesLimit),
    );
  });

  test('mot de passe oublié : e-mail de réinitialisation envoyé', () async {
    if (!_available) return skipIfOffline();
    final adresse = createur.auth.currentUser!.email!;
    await authDe(nouveauClient()).requestPasswordReset(adresse);
    expect(await dernierEmail(adresse), contains('auth/v1/verify'));
  });
}
