-- Socle commun — étape 2 : Contacts (pgTAP).
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(20);

create function pg_temp.en_tant_que(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;

-- Catalogue
select is((select categorie from public.modules where code = 'commun.contacts'), 'COMMUN',
  'module Contacts : catégorie commune');
select is_empty($$ select 1 from public.modules where code in ('commerce.clients', 'services.clients') $$,
  'anciens modules Clients retirés');
select is_empty($$ select 1 from public.permissions where code like 'customers.%' $$,
  'permissions customers.* remplacées par contacts.*');
select is((select telephone_normalise from public.contacts where id = 'aaaaaaaa-0000-0000-0003-000000000001'),
  '22370112233', 'téléphone normalisé pour détecter les doublons');

-- Vendeur Alpha : voir, créer, modifier ; pas archiver.
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111103');
set local role authenticated;

select is((select count(*)::int from public.contacts), 2, 'vendeur : contacts de son entreprise');
select ok((public.get_contexte_session() -> 'modules') @> '[{"code":"commun.contacts","categorie":"COMMUN"}]',
  'contexte : catégorie des modules transmise');
select lives_ok($$ insert into public.contacts (id, entreprise_id, nom, telephone, relations)
                   values ('aaaaaaaa-0000-0000-0003-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'Keita', '+223 66 00 00 00', '{CLIENT}') $$, 'vendeur : création');
select is((select created_by from public.contacts where id = 'aaaaaaaa-0000-0000-0003-000000000003'),
  '11111111-1111-1111-1111-111111111103'::uuid, 'auteur enregistré');
select lives_ok($$ update public.contacts set relations = '{CLIENT,FOURNISSEUR}'
                   where id = 'aaaaaaaa-0000-0000-0003-000000000003' $$,
  'vendeur : ajout d''une relation sans créer de doublon');
select throws_ok($$ update public.contacts set statut = 'ARCHIVE'
                    where id = 'aaaaaaaa-0000-0000-0003-000000000003' $$,
  '42501', null, 'vendeur : archivage refusé (contacts.archive)');
select throws_ok($$ insert into public.contacts (entreprise_id, nom, relations)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'X', '{AMI}') $$,
  '23514', null, 'relation inconnue refusée');
select ok(exists (select 1 from public.audit_logs) = false,
  'vendeur : journal d''audit toujours invisible');

-- Synchronisation idempotente
select is(public.sync_push('00000000-0000-0000-0000-0000000000c1', 'contacts', 'INSERT',
            'aaaaaaaa-0000-0000-0003-000000000004', null,
            '{"entreprise_id":"aaaaaaaa-0000-0000-0000-000000000001","nom":"Diarra","relations":["CLIENT"]}') ->> 'statut',
  'APPLIQUE', 'sync : création hors-ligne appliquée');
select ok(public.sync_push('00000000-0000-0000-0000-0000000000c1', 'contacts', 'INSERT',
            'aaaaaaaa-0000-0000-0003-000000000004', null,
            '{"entreprise_id":"aaaaaaaa-0000-0000-0000-000000000001","nom":"Diarra","relations":["CLIENT"]}') ? 'rejoue',
  'sync : rejeu sans doublon');
select is((select count(*)::int from public.contacts where nom = 'Diarra'), 1, 'un seul contact créé');

-- Administrateur : archivage et audit
reset role;
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111101');
set local role authenticated;
select lives_ok($$ update public.contacts set statut = 'ARCHIVE'
                   where id = 'aaaaaaaa-0000-0000-0003-000000000003' $$, 'admin : archivage');
select is((select user_id from public.audit_logs
           where entite_type = 'contacts' and entite_id = 'aaaaaaaa-0000-0000-0003-000000000003'
             and action = 'CREATION'),
  '11111111-1111-1111-1111-111111111103'::uuid, 'audit : création par le vendeur tracée');

-- Isolation entre entreprises
reset role;
select pg_temp.en_tant_que('22222222-2222-2222-2222-222222222201');
set local role authenticated;
select is_empty($$ select 1 from public.contacts where entreprise_id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  'Beta : aucun contact d''Alpha visible');
select throws_ok($$ insert into public.contacts (entreprise_id, nom)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'Intrus') $$,
  '42501', null, 'Beta : création chez Alpha refusée');

-- Abonnement suspendu : plus de création (module indisponible)
reset role;
update public.abonnements set statut = 'SUSPENDU' where entreprise_id = 'aaaaaaaa-0000-0000-0000-000000000001';
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111101');
set local role authenticated;
select throws_ok($$ insert into public.contacts (entreprise_id, nom)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'Après suspension') $$,
  '42501', null, 'abonnement suspendu : création refusée par le serveur');

select * from finish();
rollback;
