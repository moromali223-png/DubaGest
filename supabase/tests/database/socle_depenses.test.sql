-- Socle commun — étape 4 : dépenses (pgTAP).
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(26);

create function pg_temp.en_tant_que(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;

-- Repères
--   Alpha  aaaaaaaa-0000-0000-0000-000000000001 ; Boutique Centre …0001-000000000001 (superviseur)
--   Caisse Centre aaaaaaaa-0000-0000-0004-000000000001
create temp table cat as
  select id from public.depense_categories
  where entreprise_id = 'aaaaaaaa-0000-0000-0000-000000000001' and code = 'TRANSPORT';
grant select on cat to authenticated;
create temp table cat_beta as
  select id from public.depense_categories
  where entreprise_id = 'bbbbbbbb-0000-0000-0000-000000000001' and code = 'TRANSPORT';
grant select on cat_beta to authenticated;

select is((select categorie from public.modules where code = 'finances.depenses'), 'FINANCES',
  'module Dépenses dans Finances');
select is((select count(*)::int from public.depense_categories
           where entreprise_id = 'aaaaaaaa-0000-0000-0000-000000000001' and code is not null), 18,
  'catégories par défaut créées pour chaque entreprise');

-- ================================ Vendeur ================================
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111103');
set local role authenticated;
select is_empty($$ select 1 from public.depenses $$, 'vendeur : aucune dépense visible (expenses.view)');
select throws_ok($$ insert into public.depenses (entreprise_id, categorie_id, libelle, montant, reglement)
                    select 'aaaaaaaa-0000-0000-0000-000000000001', id, 'X', 100, 'DIFFERE' from cat $$,
  '42501', null, 'vendeur : saisie refusée (expenses.create)');

-- ============================== Superviseur ==============================
reset role;
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111102');
set local role authenticated;

select lives_ok($$ insert into public.caisse_sessions (id, entreprise_id, caisse_id, solde_initial)
                   values ('aaaaaaaa-0000-0000-0007-000000000011', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'aaaaaaaa-0000-0000-0004-000000000001', 20000) $$,
  'superviseur : ouverture de la caisse Centre');

-- Payée en espèces : une ligne → somme à payer + paiement + sortie de caisse.
select lives_ok($$ insert into public.depenses (id, entreprise_id, categorie_id, libelle, montant, reglement,
                                                mode_code, session_id, paiement_id)
                   select 'aaaaaaaa-0000-0000-0008-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', id,
                          'Taxi livraison', 5000, 'IMMEDIAT', 'ESPECES',
                          'aaaaaaaa-0000-0000-0007-000000000011', 'aaaaaaaa-0000-0000-0006-000000000011'
                   from cat $$,
  'superviseur : dépense payée en espèces');
select is((select (sens, origine_type, montant_total, montant_regle)::text from public.engagements
           where id = 'aaaaaaaa-0000-0000-0008-000000000001'),
  '(A_PAYER,DEPENSE,5000,5000)', 'somme à payer liée, déjà réglée');
select is((select (sens, montant, perimetre_id)::text from public.paiements
           where id = 'aaaaaaaa-0000-0000-0006-000000000011'),
  '(SORTIE,5000,aaaaaaaa-0000-0000-0001-000000000001)', 'paiement créé avec l''identifiant fourni');
select is((select type from public.caisse_mouvements where id = 'aaaaaaaa-0000-0000-0006-000000000011'),
  'DECAISSEMENT', 'sortie de caisse créée');
select is(app.solde_session('aaaaaaaa-0000-0000-0007-000000000011'), 15000::bigint, 'caisse : 20 000 − 5 000');
select is((select perimetre_id from public.depenses where id = 'aaaaaaaa-0000-0000-0008-000000000001'),
  'aaaaaaaa-0000-0000-0001-000000000001'::uuid, 'site déduit de la caisse');

-- Payée plus tard : seulement une somme à payer.
select lives_ok($$ insert into public.depenses (id, entreprise_id, perimetre_id, categorie_id, libelle, montant,
                                                reglement, echeance)
                   select 'aaaaaaaa-0000-0000-0008-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001',
                          'aaaaaaaa-0000-0000-0001-000000000001', id, 'Facture électricité', 30000, 'DIFFERE',
                          current_date + 15
                   from cat $$,
  'superviseur : dépense à payer plus tard');
select is((select (montant_total - montant_regle, echeance = current_date + 15)::text from public.engagements
           where id = 'aaaaaaaa-0000-0000-0008-000000000002'),
  '(30000,t)', 'reste à payer 30 000, avec échéance');
select is_empty($$ select 1 from public.paiements where note = 'Facture électricité' $$,
  'aucun paiement pour une dépense différée');

select throws_ok($$ insert into public.depenses (entreprise_id, categorie_id, libelle, montant, reglement,
                                                 mode_code, session_id, paiement_id)
                    select 'aaaaaaaa-0000-0000-0000-000000000001', id, 'Trop cher', 50000, 'IMMEDIAT', 'ESPECES',
                           'aaaaaaaa-0000-0000-0007-000000000011', gen_random_uuid() from cat $$,
  'DGL01', 'SOLDE_CAISSE_INSUFFISANT', 'pas de dépense en espèces au-delà de la caisse');
select is((select count(*)::int from public.depenses), 2, 'dépense refusée : rien n''est créé');
select throws_ok($$ insert into public.depenses (entreprise_id, categorie_id, libelle, montant, reglement)
                    select 'aaaaaaaa-0000-0000-0000-000000000001', id, 'X', 100, 'DIFFERE' from cat_beta $$,
  'DGL01', 'CATEGORIE_INVALIDE', 'catégorie d''une autre entreprise refusée');
select throws_ok($$ update public.engagements set montant_total = 1
                    where id = 'aaaaaaaa-0000-0000-0008-000000000002' $$,
  'DGL01', 'ENGAGEMENT_LIE', 'la somme liée se modifie depuis la dépense');
update public.depenses set statut = 'ANNULEE' where id = 'aaaaaaaa-0000-0000-0008-000000000002';
select is((select statut from public.depenses where id = 'aaaaaaaa-0000-0000-0008-000000000002'),
  'ENREGISTREE', 'superviseur : annulation sans effet (expenses.update)');
select throws_ok($$ insert into public.depense_categories (entreprise_id, nom)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'Perso') $$,
  '42501', null, 'superviseur : catégories gérées par l''administrateur');

-- Hors-ligne : rejeu sans doublon.
select ok(public.sync_push('00000000-0000-0000-0000-0000000000d1', 'depenses', 'INSERT',
            'aaaaaaaa-0000-0000-0008-000000000003', null,
            jsonb_build_object('entreprise_id', 'aaaaaaaa-0000-0000-0000-000000000001',
                               'categorie_id', (select id from cat), 'libelle', 'Carburant', 'montant', 2000,
                               'reglement', 'DIFFERE')) ? 'statut'
          and public.sync_push('00000000-0000-0000-0000-0000000000d1', 'depenses', 'INSERT',
            'aaaaaaaa-0000-0000-0008-000000000003', null, '{}') ? 'rejoue',
  'sync : dépense appliquée puis rejeu reconnu');
select is((select count(*)::int from public.engagements where origine_id = 'aaaaaaaa-0000-0000-0008-000000000003'),
  1, 'une seule somme à payer créée');

-- ============================ Administrateur ============================
reset role;
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111101');
set local role authenticated;
select throws_ok($$ update public.depenses set statut = 'ANNULEE'
                    where id = 'aaaaaaaa-0000-0000-0008-000000000001' $$,
  'DGL01', 'DEPENSE_PAYEE', 'dépense payée : annuler d''abord le paiement');
select lives_ok($$
    insert into public.paiements (entreprise_id, sens, montant, mode_code, annule_paiement_id)
    values ('aaaaaaaa-0000-0000-0000-000000000001', 'ENTREE', 1, 'ESPECES', 'aaaaaaaa-0000-0000-0006-000000000011');
    update public.depenses set statut = 'ANNULEE', motif_annulation = 'Erreur'
    where id = 'aaaaaaaa-0000-0000-0008-000000000001' $$,
  'admin : paiement annulé puis dépense annulée');
select is((select (e.statut, app.solde_session('aaaaaaaa-0000-0000-0007-000000000011'))::text
           from public.engagements e where e.id = 'aaaaaaaa-0000-0000-0008-000000000001'),
  '(ANNULE,20000)', 'somme liée annulée, caisse revenue à 20 000');

-- ========================= Isolation entre entreprises =========================
reset role;
select pg_temp.en_tant_que('22222222-2222-2222-2222-222222222201');
set local role authenticated;
select is_empty($$ select 1 from public.depenses $$, 'Beta : aucune dépense d''Alpha visible');

select * from finish();
rollback;
