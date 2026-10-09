-- Socle commun — étape 6 : agenda et notifications (pgTAP).
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(17);

create function pg_temp.en_tant_que(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;

-- Repères : superviseur …102 (Moussa Traoré), vendeur …103 (Fatou Keita),
-- contact Amadou aaaaaaaa-0000-0000-0003-000000000001.

select is((select categorie from public.modules where code = 'commun.agenda'), 'COMMUN', 'module Agenda commun');

-- ============================== Superviseur ==============================
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111102');
set local role authenticated;

select lives_ok($$ insert into public.echeances (id, entreprise_id, type, titre, date_heure, rappel_minutes,
                                                 responsable_id, cible_type, cible_id)
                   values ('aaaaaaaa-0000-0000-000b-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'RELANCE', 'Relancer Amadou', now() + interval '1 day', 60,
                           '11111111-1111-1111-1111-111111111103', 'CONTACT',
                           'aaaaaaaa-0000-0000-0003-000000000001') $$,
  'superviseur : relance confiée au vendeur');
select is((select responsable_nom from public.echeances where id = 'aaaaaaaa-0000-0000-000b-000000000001'),
  'Fatou Keita', 'nom du responsable copié par le serveur');
select is_empty($$ select 1 from public.notifications $$,
  'superviseur : ne voit pas la notification du vendeur');
select throws_ok($$ insert into public.echeances (entreprise_id, type, titre, date_heure, responsable_id)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'TACHE', 'X', now(),
                            '22222222-2222-2222-2222-222222222201') $$,
  'DGL01', 'RESPONSABLE_INVALIDE', 'responsable hors de l''entreprise refusé');
select throws_ok($$ insert into public.echeances (entreprise_id, type, titre, date_heure, cible_type, cible_id)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'TACHE', 'X', now(), 'CONTACT', gen_random_uuid()) $$,
  'DGL01', 'CIBLE_INVALIDE', 'fiche inexistante refusée');

-- ================================ Vendeur ================================
reset role;
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111103');
set local role authenticated;

select is((select count(*)::int from public.echeances), 1, 'vendeur : voit la relance');
select throws_ok($$ insert into public.echeances (entreprise_id, type, titre, date_heure)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'TACHE', 'X', now()) $$,
  '42501', null, 'vendeur : création refusée (agenda.manage)');
select is((select (type, auteur_nom, parametres ->> 'titre')::text from public.notifications),
  '(ECHEANCE_CONFIEE,"Moussa Traoré","Relancer Amadou")', 'vendeur : notifié de la tâche confiée');
select throws_ok($$ update public.echeances set titre = 'Autre' where id = 'aaaaaaaa-0000-0000-000b-000000000001' $$,
  '42501', null, 'responsable : ne modifie pas le contenu');
select lives_ok($$ update public.echeances set statut = 'FAIT' where id = 'aaaaaaaa-0000-0000-000b-000000000001' $$,
  'responsable : marque la tâche faite');
select is((select fait_par from public.echeances where id = 'aaaaaaaa-0000-0000-000b-000000000001'),
  '11111111-1111-1111-1111-111111111103'::uuid, 'fait par le vendeur');
select lives_ok($$ update public.notifications set lue_le = now() $$, 'vendeur : notification lue');
select throws_ok($$ update public.notifications set type = 'ECHEANCE_FAITE' $$,
  '42501', null, 'une notification ne se modifie pas (sauf « lue »)');

-- ============================== Superviseur ==============================
reset role;
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111102');
set local role authenticated;
select is((select type from public.notifications), 'ECHEANCE_FAITE', 'auteur notifié de la tâche terminée');
select ok(public.sync_push('00000000-0000-0000-0000-0000000000a1', 'notifications', 'UPDATE',
            (select id from public.notifications), 1, jsonb_build_object('lue_le', now())) ->> 'statut' = 'APPLIQUE',
  'sync : notification marquée lue hors-ligne');

-- ========================= Isolation entre entreprises =========================
reset role;
select pg_temp.en_tant_que('22222222-2222-2222-2222-222222222201');
set local role authenticated;
select is_empty($$ select 1 from public.echeances $$, 'Beta : aucune échéance d''Alpha visible');

select * from finish();
rollback;
