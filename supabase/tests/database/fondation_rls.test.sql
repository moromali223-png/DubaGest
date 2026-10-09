-- Tests de sécurité et de règles de la fondation (pgTAP).
-- Exécution : supabase test db   (s'appuie sur les données de supabase/seed.sql)
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(33);

create function pg_temp.se_connecter(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;

-- -----------------------------------------------------------------------------
-- Anonyme : aucun accès
-- -----------------------------------------------------------------------------
set local role anon;
select throws_ok($$ select count(*) from public.entreprises $$, '42501', null,
  'anon : aucun accès aux entreprises');
select throws_ok($$ select public.get_contexte_session() $$, '42501', null,
  'anon : contexte de session refusé');
reset role;

-- -----------------------------------------------------------------------------
-- Isolation multi-tenant : admin Beta
-- -----------------------------------------------------------------------------
select pg_temp.se_connecter('22222222-2222-2222-2222-222222222201');
set local role authenticated;

select results_eq($$ select nom from public.entreprises $$, array['Beta Immobilier'],
  'Beta ne voit que sa propre entreprise');
select is_empty($$ select 1 from public.perimetres where entreprise_id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  'Beta ne voit aucun périmètre Alpha');
select is_empty($$ select 1 from public.membres_entreprise where entreprise_id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  'Beta ne voit aucun membre Alpha');
select is_empty($$ select 1 from public.profiles where id = '11111111-1111-1111-1111-111111111101' $$,
  'Beta ne voit aucun profil Alpha');
select is_empty($$ select 1 from public.abonnements where entreprise_id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  'Beta ne voit pas l''abonnement Alpha');
select is_empty($$ update public.perimetres set nom = 'pirate'
                   where entreprise_id = 'aaaaaaaa-0000-0000-0000-000000000001' returning id $$,
  'Beta ne peut modifier aucun périmètre Alpha');
select throws_ok($$ insert into public.perimetres (entreprise_id, activite_code, type, nom)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'COMMERCE', 'BOUTIQUE', 'X') $$,
  '42501', null, 'Beta ne peut pas créer de périmètre chez Alpha');
select throws_ok($$ insert into public.membres_entreprise (entreprise_id, user_id, role_code)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222201', 'ADMINISTRATEUR') $$,
  '42501', null, 'Beta ne peut pas s''ajouter comme membre d''Alpha');
select is((public.get_contexte_session('aaaaaaaa-0000-0000-0000-000000000001') -> 'membre'), 'null'::jsonb,
  'Beta ne peut pas charger le contexte d''Alpha');

-- -----------------------------------------------------------------------------
-- Périmètre : le vendeur Alpha ne voit que sa boutique
-- -----------------------------------------------------------------------------
reset role;
select pg_temp.se_connecter('11111111-1111-1111-1111-111111111103');
set local role authenticated;

select results_eq($$ select nom from public.perimetres $$, array['Boutique Marché'],
  'Vendeur : uniquement son périmètre affecté');
select throws_ok($$ insert into public.perimetres (entreprise_id, activite_code, type, nom)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'COMMERCE', 'BOUTIQUE', 'X') $$,
  '42501', null, 'Vendeur : création de périmètre refusée par la RLS (pas par la limite)');
select ok(not (public.get_contexte_session() -> 'permissions') ? 'users.manage',
  'Vendeur : pas de permission users.manage');
select is(jsonb_array_length(public.get_contexte_session() -> 'perimetres'), 1,
  'Vendeur : contexte avec un seul périmètre');

-- Superviseur : Boutique Centre uniquement
reset role;
select pg_temp.se_connecter('11111111-1111-1111-1111-111111111102');
set local role authenticated;
select results_eq($$ select nom from public.perimetres $$, array['Boutique Centre'],
  'Superviseur : uniquement Boutique Centre');

-- -----------------------------------------------------------------------------
-- Administrateur Alpha : limites d'abonnement (MOYEN)
-- -----------------------------------------------------------------------------
reset role;
select pg_temp.se_connecter('11111111-1111-1111-1111-111111111101');
set local role authenticated;

select is((select count(*)::int from public.perimetres), 3, 'Admin : accès à tous les périmètres');
select throws_ok($$ insert into public.perimetres (entreprise_id, activite_code, type, nom)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'COMMERCE', 'BOUTIQUE', 'Boutique 3') $$,
  'DGL01', 'LIMITE_PERIMETRES', 'MOYEN : maximum 2 boutiques');
select throws_ok($$ insert into public.entreprise_activites (entreprise_id, activite_code)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'IMMOBILIER') $$,
  'DGL01', 'LIMITE_ACTIVITES', 'MOYEN : jamais trois activités');
select throws_ok($$ update public.membres_entreprise set role_code = 'VENDEUR'
                    where id = 'aaaaaaaa-0000-0000-0002-000000000001' $$,
  'DGL01', 'DERNIER_ADMINISTRATEUR', 'Le dernier administrateur est protégé');
select throws_ok($$ update public.entreprises set statut = 'SUSPENDUE' $$,
  '42501', null, 'Admin : statut entreprise non modifiable via l''API');
select throws_ok($$ update public.membres_entreprise set entreprise_id = 'bbbbbbbb-0000-0000-0000-000000000001'
                    where id = 'aaaaaaaa-0000-0000-0002-000000000003' $$,
  '42501', null, 'Admin : rattachement tenant d''un membre non modifiable');

-- Quota de rôle : superviseur → vendeur OK (2/2), le suivant est refusé
select lives_ok($$ update public.membres_entreprise set role_code = 'VENDEUR'
                   where id = 'aaaaaaaa-0000-0000-0002-000000000002' $$,
  'MOYEN : 2 vendeurs autorisés');
select throws_ok($$ insert into public.membres_entreprise (entreprise_id, user_id, role_code)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222201', 'VENDEUR') $$,
  'DGL01', 'LIMITE_ROLE', 'MOYEN : pas de 3e vendeur');

-- Affectations utilisateur ↔ périmètre
select throws_ok($$ insert into public.membre_perimetres (entreprise_id, membre_id, perimetre_id)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0002-000000000003',
                            'aaaaaaaa-0000-0000-0001-000000000003') $$,
  'DGL01', 'AFFECTATION_ACTIVITE_INCOMPATIBLE', 'Un vendeur ne peut pas être affecté à une agence Services');
select throws_ok($$ insert into public.membre_perimetres (entreprise_id, membre_id, perimetre_id)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0002-000000000001',
                            'aaaaaaaa-0000-0000-0001-000000000001') $$,
  'DGL01', 'AFFECTATION_INUTILE', 'L''administrateur accède déjà à tous les périmètres');
select lives_ok($$ insert into public.membre_perimetres (entreprise_id, membre_id, perimetre_id)
                   values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0002-000000000003',
                           'aaaaaaaa-0000-0000-0001-000000000001') $$,
  'Un vendeur peut être affecté à une seconde boutique');

-- -----------------------------------------------------------------------------
-- Synchronisation : idempotence et conflits
-- -----------------------------------------------------------------------------
select is(public.sync_push('00000000-0000-0000-0000-0000000000a1', 'perimetres', 'UPDATE',
            'aaaaaaaa-0000-0000-0001-000000000001', 1, '{"nom":"Boutique Centre Ville"}') ->> 'statut',
  'APPLIQUE', 'sync : mise à jour appliquée');
select ok(public.sync_push('00000000-0000-0000-0000-0000000000a1', 'perimetres', 'UPDATE',
            'aaaaaaaa-0000-0000-0001-000000000001', 1, '{"nom":"Boutique Centre Ville"}') ? 'rejoue',
  'sync : opération rejouée sans double application');
select is(public.sync_push(gen_random_uuid(), 'perimetres', 'UPDATE',
            'aaaaaaaa-0000-0000-0001-000000000001', 1, '{"nom":"Autre"}') ->> 'statut',
  'CONFLIT', 'sync : version périmée → conflit');
select is(public.sync_push(gen_random_uuid(), 'perimetres', 'DELETE',
            'aaaaaaaa-0000-0000-0001-000000000002', 1, '{}') ->> 'statut',
  'APPLIQUE', 'sync : suppression logique');
select is(public.sync_push(gen_random_uuid(), 'perimetres', 'INSERT', gen_random_uuid(), null,
            '{"entreprise_id":"aaaaaaaa-0000-0000-0000-000000000001","activite_code":"COMMERCE","type":"BOUTIQUE","nom":"Boutique Gare","version":99}'
          ) -> 'ligne' ->> 'version',
  '1', 'sync : création après libération d''une place, version imposée par le serveur');
select throws_ok($$ select public.sync_push(gen_random_uuid(), 'membres_entreprise', 'DELETE',
                    gen_random_uuid(), 1, '{}') $$,
  'DGL01', 'SYNC_TABLE_INCONNUE', 'sync : seules les tables déclarées sont synchronisables');

select * from finish();
rollback;
