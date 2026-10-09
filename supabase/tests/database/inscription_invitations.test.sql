-- Inscription, création d'entreprise et invitations (pgTAP).
-- AUTHENTIFICATION ≠ RÔLE : un compte seul n'a aucun droit métier.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(35);

-- Comptes de test (créés comme le ferait Supabase Auth).
create function pg_temp.creer_compte(p_id uuid, p_email text, p_confirme boolean, p_meta jsonb default '{}')
returns void language sql as $$
  insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at, raw_user_meta_data)
  values (p_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          p_email, case when p_confirme then now() end, p_meta);
$$;

select pg_temp.creer_compte('c0000000-0000-0000-0000-000000000001', 'createur@test.local', true,
  '{"prenom":"Moussa","nom":"Traoré"}');
select pg_temp.creer_compte('c0000000-0000-0000-0000-000000000002', 'invite@test.local', true);
select pg_temp.creer_compte('c0000000-0000-0000-0000-000000000003', 'autre@test.local', true);
select pg_temp.creer_compte('c0000000-0000-0000-0000-000000000004', 'nonconfirme@test.local', false);
select pg_temp.creer_compte('c0000000-0000-0000-0000-000000000005', 'expire@test.local', true);
select pg_temp.creer_compte('c0000000-0000-0000-0000-000000000006', 'google@gmail.com', true,
  '{"full_name":"Awa Google","name":"Awa Google","email":"google@gmail.com"}');

create temp table t_val (cle text primary key, val text);
grant all on t_val to authenticated, anon;

create function pg_temp.en_tant_que(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;

-- -----------------------------------------------------------------------------
-- Compte sans entreprise : aucun rôle, aucune permission
-- -----------------------------------------------------------------------------
select is((select nom_complet from public.profiles where id = 'c0000000-0000-0000-0000-000000000001'),
  'Moussa Traoré', 'profil créé avec prénom + nom');
select is((select nom_complet from public.profiles where id = 'c0000000-0000-0000-0000-000000000006'),
  'Awa Google', 'profil Google créé depuis full_name');
select is((select count(*)::int from public.membres_entreprise
           where user_id = 'c0000000-0000-0000-0000-000000000006'), 0,
  'inscription Google : aucun rôle métier attribué');

select pg_temp.en_tant_que('c0000000-0000-0000-0000-000000000001');
set local role authenticated;

select is(public.get_contexte_session() -> 'membre', 'null'::jsonb, 'sans entreprise : contexte vide');
select is_empty($$ select 1 from public.entreprises $$, 'sans entreprise : aucune entreprise visible');
select throws_ok($$ insert into public.membres_entreprise (entreprise_id, user_id, role_code)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'ADMINISTRATEUR') $$,
  '42501', null, 'impossible de s''attribuer un rôle dans une entreprise');
select throws_ok($$ insert into public.invitations (entreprise_id, email, role_code, token_hash, expires_at)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'x@x.io', 'ADMINISTRATEUR', '\x00', now() + interval '1 day') $$,
  '42501', null, 'impossible de créer une invitation directement');

-- -----------------------------------------------------------------------------
-- Créer mon entreprise
-- -----------------------------------------------------------------------------
select throws_ok($$ select public.creer_entreprise('Gamma', 'INCONNU', '{COMMERCE}') $$,
  'DGL01', 'PLAN_INVALIDE', 'formule inexistante refusée');
select throws_ok($$ select public.creer_entreprise('Gamma', 'NORMAL', '{COMMERCE,SERVICES}') $$,
  'DGL01', 'LIMITE_ACTIVITES', 'NORMAL : une seule activité');
select lives_ok($$ insert into t_val select 'gamma', public.creer_entreprise('Gamma Commerce', 'MOYEN', '{COMMERCE}') $$,
  'création transactionnelle de l''entreprise');
select is(public.get_contexte_session() -> 'membre' ->> 'role_code', 'ADMINISTRATEUR',
  'le créateur devient administrateur');
select is(public.get_contexte_session() -> 'abonnement' ->> 'statut', 'ESSAI', 'abonnement d''essai');
select results_eq($$ select nom from public.perimetres $$, array['Boutique principale'],
  'premier périmètre créé');
select throws_ok($$ select public.creer_entreprise('Gamma 2', 'MOYEN', '{SERVICES}') $$,
  'DGL01', 'ENTREPRISE_DEJA_CREEE', 'une entreprise créée par compte');

insert into public.perimetres (entreprise_id, activite_code, type, nom)
select val::uuid, 'COMMERCE', 'BOUTIQUE', 'Boutique B' from t_val where cle = 'gamma';

-- -----------------------------------------------------------------------------
-- Inviter (administrateur de Gamma)
-- -----------------------------------------------------------------------------
select lives_ok($$
  insert into t_val select 'jeton', public.creer_invitation(
    (select val::uuid from t_val where cle = 'gamma'), ' Invite@Test.local ', 'VENDEUR',
    array(select id from public.perimetres where nom = 'Boutique principale')) ->> 'token' $$,
  'invitation vendeur limitée à la Boutique principale');
select throws_ok($$ select token_hash from public.invitations $$, '42501', null,
  'l''empreinte du jeton n''est pas lisible');
select is((select email from public.invitations), 'invite@test.local', 'e-mail normalisé');
select throws_ok($$ select public.creer_invitation((select val::uuid from t_val where cle = 'gamma'),
                    'v2@test.local', 'VENDEUR', '{}') $$,
  'DGL01', 'PERIMETRE_REQUIS', 'un rôle restreint exige un périmètre');
select throws_ok($$ select public.creer_invitation((select val::uuid from t_val where cle = 'gamma'),
                    'boss@test.local', 'ADMINISTRATEUR', '{}') $$,
  'DGL01', 'LIMITE_ROLE', 'pas de second administrateur');
select throws_ok($$ select public.creer_invitation((select val::uuid from t_val where cle = 'gamma'),
                    'v2@test.local', 'VENDEUR', array['aaaaaaaa-0000-0000-0001-000000000001'::uuid]) $$,
  'DGL01', 'PERIMETRE_NON_AUTORISE', 'pas de périmètre d''une autre entreprise');

insert into t_val select 'jeton_nc', public.creer_invitation((select val::uuid from t_val where cle = 'gamma'),
  'nonconfirme@test.local', 'VENDEUR', array(select id from public.perimetres where nom = 'Boutique B')) ->> 'token';
select throws_ok($$ select public.creer_invitation((select val::uuid from t_val where cle = 'gamma'),
                    'v3@test.local', 'VENDEUR', array(select id from public.perimetres where nom = 'Boutique B')) $$,
  'DGL01', 'LIMITE_ROLE', 'quota vendeurs (MOYEN = 2) incluant les invitations en attente');

insert into t_val select 'jeton_exp', public.creer_invitation((select val::uuid from t_val where cle = 'gamma'),
  'expire@test.local', 'GESTIONNAIRE_STOCK', array(select id from public.perimetres where nom = 'Boutique B')) ->> 'token';
insert into t_val select 'jeton_annule', public.creer_invitation((select val::uuid from t_val where cle = 'gamma'),
  'autre@test.local', 'SUPERVISEUR', array(select id from public.perimetres where nom = 'Boutique B')) ->> 'token';
select lives_ok($$ select public.annuler_invitation((select id from public.invitations where email = 'autre@test.local')) $$,
  'annulation d''une invitation');

-- Personnes non autorisées
reset role;
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111103');
set local role authenticated;
select throws_ok($$ select public.creer_invitation((select val::uuid from t_val where cle = 'gamma'),
                    'x@test.local', 'VENDEUR', '{}') $$, '42501', null, 'un vendeur ne peut pas inviter');
reset role;
select pg_temp.en_tant_que('22222222-2222-2222-2222-222222222201');
set local role authenticated;
select throws_ok($$ select public.creer_invitation((select val::uuid from t_val where cle = 'gamma'),
                    'x@test.local', 'VENDEUR', '{}') $$, '42501', null,
  'l''admin d''une autre entreprise ne peut pas inviter chez Gamma');

-- Expiration simulée
reset role;
update public.invitations set expires_at = now() - interval '1 day' where email = 'expire@test.local';

-- -----------------------------------------------------------------------------
-- Vérifier (avant connexion) puis accepter
-- -----------------------------------------------------------------------------
set local role anon;
select is(public.verifier_invitation((select val from t_val where cle = 'jeton')) ->> 'email_masque',
  'i***@test.local', 'aperçu anonyme avec e-mail masqué');
select is(public.verifier_invitation('jeton-bidon') ->> 'statut', 'INVALIDE', 'jeton inconnu');
select is(public.verifier_invitation((select val from t_val where cle = 'jeton_exp')) ->> 'statut', 'EXPIRED',
  'invitation expirée signalée');
reset role;

select pg_temp.en_tant_que('c0000000-0000-0000-0000-000000000003');
set local role authenticated;
select throws_ok($$ select public.accepter_invitation((select val from t_val where cle = 'jeton')) $$,
  'DGL01', 'INVITATION_EMAIL_DIFFERENT', 'réservée à l''adresse invitée');
select throws_ok($$ select public.accepter_invitation((select val from t_val where cle = 'jeton_annule')) $$,
  'DGL01', 'INVITATION_ANNULEE', 'invitation annulée');

reset role;
select pg_temp.en_tant_que('c0000000-0000-0000-0000-000000000004');
set local role authenticated;
select throws_ok($$ select public.accepter_invitation((select val from t_val where cle = 'jeton_nc')) $$,
  'DGL01', 'EMAIL_NON_CONFIRME', 'e-mail non confirmé refusé');

reset role;
select pg_temp.en_tant_que('c0000000-0000-0000-0000-000000000005');
set local role authenticated;
select throws_ok($$ select public.accepter_invitation((select val from t_val where cle = 'jeton_exp')) $$,
  'DGL01', 'INVITATION_EXPIREE', 'invitation expirée refusée');

reset role;
select pg_temp.en_tant_que('c0000000-0000-0000-0000-000000000002');
set local role authenticated;
select lives_ok($$ select public.accepter_invitation((select val from t_val where cle = 'jeton')) $$,
  'acceptation par l''invité');
select is(public.get_contexte_session() -> 'membre' ->> 'role_code', 'VENDEUR',
  'rôle provenant de l''invitation');
select results_eq($$ select nom from public.perimetres $$, array['Boutique principale'],
  'restreint au périmètre de l''invitation (pas la Boutique B)');
select throws_ok($$ select public.accepter_invitation((select val from t_val where cle = 'jeton')) $$,
  'DGL01', 'INVITATION_DEJA_UTILISEE', 'usage unique');

select * from finish();
rollback;
