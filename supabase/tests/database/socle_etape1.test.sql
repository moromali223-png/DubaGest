-- Socle commun — étape 1 : plans, rôles, permissions, profil, audit (pgTAP).
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(22);

create function pg_temp.en_tant_que(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;

-- -----------------------------------------------------------------------------
-- Plans
-- -----------------------------------------------------------------------------
select results_eq($$ select code, prix_mensuel from public.plans order by ordre $$,
  $$ values ('NORMAL'::text, 1000), ('MOYEN'::text, 2000), ('PRO'::text, 5000) $$,
  'trois formules et leurs prix (FCFA/mois)');
select is((select plan_code from public.abonnements
           where entreprise_id = 'bbbbbbbb-0000-0000-0000-000000000001'), 'NORMAL',
  'les abonnements FAIBLE sont devenus NORMAL');
select is((select max_activites from public.plans where code = 'PRO')::int, 3, 'PRO : trois activités');

-- PRO : limites illimitées (créé comme le ferait le back-office).
insert into public.entreprises (id, nom) values ('dddddddd-0000-0000-0000-000000000001', 'Delta Pro');
insert into public.abonnements (entreprise_id, plan_code) values ('dddddddd-0000-0000-0000-000000000001', 'PRO');
select lives_ok($$ insert into public.entreprise_activites (entreprise_id, activite_code) values
  ('dddddddd-0000-0000-0000-000000000001', 'COMMERCE'),
  ('dddddddd-0000-0000-0000-000000000001', 'SERVICES'),
  ('dddddddd-0000-0000-0000-000000000001', 'IMMOBILIER') $$, 'PRO : Commerce + Services + Immobilier');
select lives_ok($$ insert into public.perimetres (entreprise_id, activite_code, type, nom)
  select 'dddddddd-0000-0000-0000-000000000001', 'COMMERCE', 'BOUTIQUE', 'Boutique ' || g
  from generate_series(1, 5) g $$, 'PRO : boutiques illimitées');
select is(app.max_utilisateurs('dddddddd-0000-0000-0000-000000000001', 'PRO'), null::int,
  'PRO : utilisateurs illimités');
select is((select devise from public.entreprises where id = 'dddddddd-0000-0000-0000-000000000001'), 'XOF',
  'devise par défaut : XOF');

-- NORMAL reste limité.
select throws_ok($$ insert into public.perimetres (entreprise_id, activite_code, type, nom)
  values ('bbbbbbbb-0000-0000-0000-000000000001', 'IMMOBILIER', 'AGENCE', 'Agence 2') $$,
  'DGL01', 'LIMITE_PERIMETRES', 'NORMAL : un seul site');

-- -----------------------------------------------------------------------------
-- Rôles et permissions
-- -----------------------------------------------------------------------------
select ok(exists (select 1 from public.roles where code = 'CAISSIER' and activite_code = 'COMMERCE'),
  'rôle Caissier (Commerce)');
select ok(exists (select 1 from public.roles where code = 'GESTIONNAIRE_IMMOBILIER' and activite_code = 'IMMOBILIER'),
  'rôle Gestionnaire immobilier');
select set_eq($$ select permission_code from public.roles_permissions
                 where role_code = 'CAISSIER' and permission_code like 'cash.%' $$,
  array['cash.view', 'cash.open', 'cash.move', 'cash.close'], 'Caissier : ouvrir, mouvementer, clôturer');
select is_empty($$ select 1 from public.permissions where code in ('cash.create', 'cash.update') $$,
  'anciennes permissions de caisse remplacées');
select ok(not exists (select 1 from public.roles_permissions
                      where role_code = 'VENDEUR' and permission_code in ('payments.refund', 'audit.view')),
  'Vendeur : ni remboursement ni audit');
select ok(exists (select 1 from public.roles_permissions
                  where role_code = 'ADMINISTRATEUR' and permission_code = 'audit.view'),
  'Administrateur : audit.view');

-- -----------------------------------------------------------------------------
-- Profil d'entreprise et audit
-- -----------------------------------------------------------------------------
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111101');
set local role authenticated;

select lives_ok($$ update public.entreprises set telephone = '+223 70 00 00 00', adresse = 'Bamako'
                   where id = 'aaaaaaaa-0000-0000-0000-000000000001' $$, 'admin : profil modifiable');
select throws_ok($$ update public.entreprises set statut = 'ARCHIVEE' $$, '42501', null,
  'admin : statut non modifiable');

update public.perimetres set nom = 'Boutique Centre-Ville' where id = 'aaaaaaaa-0000-0000-0001-000000000001';
update public.perimetres set deleted_at = now() where id = 'aaaaaaaa-0000-0000-0001-000000000002';

select results_eq($$ select action, anciennes_valeurs ->> 'nom', nouvelles_valeurs ->> 'nom', user_id
                     from public.audit_logs
                     where entite_id = 'aaaaaaaa-0000-0000-0001-000000000001' and action = 'MODIFICATION' $$,
  $$ values ('MODIFICATION'::text, 'Boutique Centre'::text, 'Boutique Centre-Ville'::text,
             '11111111-1111-1111-1111-111111111101'::uuid) $$,
  'audit : qui, quoi, avant / après (champs modifiés seulement)');
select is((select action from public.audit_logs
           where entite_id = 'aaaaaaaa-0000-0000-0001-000000000002' order by id desc limit 1),
  'ARCHIVAGE', 'audit : suppression logique tracée');
select throws_ok($$ insert into public.audit_logs (entreprise_id, action, entite_type, entite_id)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'CREATION', 'x', 'y') $$,
  '42501', null, 'audit : écriture interdite');
select throws_ok($$ delete from public.audit_logs $$, '42501', null, 'audit : effacement interdit');

reset role;
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111103');
set local role authenticated;
select is_empty($$ select 1 from public.audit_logs $$, 'vendeur : journal invisible (pas audit.view)');

reset role;
select pg_temp.en_tant_que('22222222-2222-2222-2222-222222222201');
set local role authenticated;
select is_empty($$ select 1 from public.audit_logs where entreprise_id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  'admin Beta : journal d''Alpha invisible');

select * from finish();
rollback;
