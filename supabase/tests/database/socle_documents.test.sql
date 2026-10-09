-- Socle commun — étape 5 : documents et numérotation par blocs (pgTAP).
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(17);

create function pg_temp.en_tant_que(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;

create temp table blocs (nom text primary key, id uuid, debut bigint, fin bigint);
grant all on blocs to authenticated;
create temp table annee as select extract(year from now())::int as a;
grant select on annee to authenticated;

-- ================================ Vendeur ================================
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111103');
set local role authenticated;

insert into blocs select 'v1', (b ->> 'id')::uuid, (b ->> 'debut')::bigint, (b ->> 'fin')::bigint
from public.reserver_bloc('aaaaaaaa-0000-0000-0000-000000000001', 'RECU', 'telephone-vendeur', 10) b;
insert into blocs select 'v2', (b ->> 'id')::uuid, (b ->> 'debut')::bigint, (b ->> 'fin')::bigint
from public.reserver_bloc('aaaaaaaa-0000-0000-0000-000000000001', 'RECU', 'tablette-vendeur', 10) b;

select is((select (debut, fin)::text from blocs where nom = 'v1'), '(1,10)', 'premier bloc : 1 à 10');
select is((select (debut, fin)::text from blocs where nom = 'v2'), '(11,20)',
  'second appareil : bloc suivant, jamais le même numéro');
select is((select count(*)::int from public.numero_blocs), 2, 'le vendeur voit ses propres blocs');

select lives_ok($$ insert into public.paiements (id, entreprise_id, perimetre_id, sens, montant, mode_code, contact_id)
                   values ('aaaaaaaa-0000-0000-0006-000000000021', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'aaaaaaaa-0000-0000-0001-000000000002', 'ENTREE', 7500, 'MOBILE_MONEY',
                           'aaaaaaaa-0000-0000-0003-000000000001') $$,
  'vendeur : encaissement');

select lives_ok($$ insert into public.documents (id, entreprise_id, type, bloc_id, sequence, langue, montant,
                                                 origine_type, origine_id, contenu)
                   select 'aaaaaaaa-0000-0000-000a-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'RECU',
                          id, 1, 'fr', 1, 'PAIEMENT', 'aaaaaaaa-0000-0000-0006-000000000021', '{"entreprise":{}}'
                   from blocs where nom = 'v1' $$,
  'vendeur : reçu émis avec un numéro de son bloc');
select is((select numero from public.documents where id = 'aaaaaaaa-0000-0000-000a-000000000001'),
  'REC-' || (select a from annee) || '-00001', 'numéro calculé par le serveur');
select is((select (montant, contact_id)::text from public.documents where id = 'aaaaaaaa-0000-0000-000a-000000000001'),
  '(7500,aaaaaaaa-0000-0000-0003-000000000001)', 'montant et contact repris du paiement');

select throws_ok($$ insert into public.documents (entreprise_id, type, bloc_id, sequence, langue, montant,
                                                  origine_type, origine_id, contenu)
                    select 'aaaaaaaa-0000-0000-0000-000000000001', 'RECU', id, 2, 'fr', 0, 'PAIEMENT',
                           'aaaaaaaa-0000-0000-0006-000000000021', '{}' from blocs where nom = 'v1' $$,
  'DGL01', 'DOCUMENT_EXISTANT', 'un seul reçu par paiement');
select throws_ok($$ insert into public.documents (entreprise_id, type, bloc_id, sequence, langue, montant,
                                                  origine_type, origine_id, contenu)
                    select 'aaaaaaaa-0000-0000-0000-000000000001', 'RECU', id, 11, 'fr', 0, 'MANUEL', null, '{}'
                    from blocs where nom = 'v1' $$,
  'DGL01', 'NUMERO_HORS_BLOC', 'numéro hors du bloc refusé');
select throws_ok($$ update public.documents set montant = 1 where id = 'aaaaaaaa-0000-0000-000a-000000000001' $$,
  '42501', null, 'un document émis ne se modifie pas');

-- Hors-ligne : rejeu sans doublon.
insert into public.paiements (id, entreprise_id, perimetre_id, sens, montant, mode_code)
values ('aaaaaaaa-0000-0000-0006-000000000023', 'aaaaaaaa-0000-0000-0000-000000000001',
        'aaaaaaaa-0000-0000-0001-000000000002', 'ENTREE', 2500, 'CARTE');
select ok(public.sync_push('00000000-0000-0000-0000-0000000000e1', 'documents', 'INSERT',
            'aaaaaaaa-0000-0000-000a-000000000002', null,
            jsonb_build_object('entreprise_id', 'aaaaaaaa-0000-0000-0000-000000000001', 'type', 'RECU',
              'bloc_id', (select id from blocs where nom = 'v2'), 'sequence', 11, 'langue', 'ar', 'montant', 0,
              'origine_type', 'PAIEMENT', 'origine_id', 'aaaaaaaa-0000-0000-0006-000000000023',
              'contenu', '{}'::jsonb)) ->> 'statut' = 'APPLIQUE'
          and public.sync_push('00000000-0000-0000-0000-0000000000e1', 'documents', 'INSERT',
            'aaaaaaaa-0000-0000-000a-000000000002', null, '{}') ? 'rejoue',
  'sync : document appliqué puis rejeu reconnu');

-- ============================ Administrateur ============================
reset role;
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111101');
set local role authenticated;
select is_empty($$ select 1 from public.numero_blocs $$, 'admin : ne voit pas les blocs du vendeur');
select lives_ok($$ insert into public.paiements (id, entreprise_id, sens, montant, mode_code)
                   values ('aaaaaaaa-0000-0000-0006-000000000022', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'SORTIE', 100, 'VIREMENT') $$, 'admin : paiement versé');
insert into blocs select 'a1', (b ->> 'id')::uuid, (b ->> 'debut')::bigint, (b ->> 'fin')::bigint
from public.reserver_bloc('aaaaaaaa-0000-0000-0000-000000000001', 'RECU', 'ordinateur-admin', 5) b;
select throws_ok($$ insert into public.documents (entreprise_id, type, bloc_id, sequence, langue, montant,
                                                  origine_type, origine_id, contenu)
                    select 'aaaaaaaa-0000-0000-0000-000000000001', 'RECU', id, debut, 'fr', 0, 'PAIEMENT',
                           'aaaaaaaa-0000-0000-0006-000000000022', '{}' from blocs where nom = 'a1' $$,
  'DGL01', 'ORIGINE_INVALIDE', 'pas de reçu pour un paiement versé');
select throws_ok($$ insert into public.documents (entreprise_id, type, bloc_id, sequence, langue, montant,
                                                  origine_type, origine_id, contenu)
                    select 'aaaaaaaa-0000-0000-0000-000000000001', 'RECU', id, 5, 'fr', 0, 'MANUEL', null, '{}'
                    from blocs where nom = 'v1' $$,
  'DGL01', 'BLOC_INVALIDE', 'impossible d''utiliser le bloc d''un autre utilisateur');

-- ========================= Isolation entre entreprises =========================
reset role;
select pg_temp.en_tant_que('22222222-2222-2222-2222-222222222201');
set local role authenticated;
select throws_ok($$ select public.reserver_bloc('aaaaaaaa-0000-0000-0000-000000000001', 'RECU', 'intrus-appareil', 10) $$,
  '42501', null, 'Beta : réservation chez Alpha refusée');
select is_empty($$ select 1 from public.documents $$, 'Beta : aucun document d''Alpha visible');

select * from finish();
rollback;
