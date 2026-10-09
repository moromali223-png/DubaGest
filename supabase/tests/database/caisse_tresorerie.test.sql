-- Caisse — trésorerie : nature, transferts, ajustements, écarts (pgTAP).
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(28);

create function pg_temp.en_tant_que(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;

-- Repères (Alpha)
--   Boutique Centre …0001-000000000001 / Caisse Centre …0004-000000000001
--   Boutique Marché …0001-000000000002 / Caisse Marché …0004-000000000002
--   admin …101 ; superviseur …102 (Centre seulement) ; vendeur …103 (Marché)

-- ============================ Administrateur ============================
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111101');
set local role authenticated;

select lives_ok($$ insert into public.caisse_sessions (id, entreprise_id, caisse_id, solde_initial) values
                     ('aaaaaaaa-0000-0000-0007-000000000101', 'aaaaaaaa-0000-0000-0000-000000000001',
                      'aaaaaaaa-0000-0000-0004-000000000001', 200000),
                     ('aaaaaaaa-0000-0000-0007-000000000102', 'aaaaaaaa-0000-0000-0000-000000000001',
                      'aaaaaaaa-0000-0000-0004-000000000002', 0) $$,
  'admin : ouverture des caisses Centre (200 000) et Marché (0)');

-- Apport du propriétaire (entrée manuelle avec nature).
select lives_ok($$ insert into public.paiements (id, entreprise_id, perimetre_id, sens, montant, mode_code, note,
                                                 session_id, nature)
                   values ('aaaaaaaa-0000-0000-0006-000000000101', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'aaaaaaaa-0000-0000-0001-000000000001', 'ENTREE', 100000, 'ESPECES',
                           'Apport du propriétaire', 'aaaaaaaa-0000-0000-0007-000000000101', 'APPORT') $$,
  'admin : apport en espèces');
select is(app.solde_session('aaaaaaaa-0000-0000-0007-000000000101'), 300000::bigint,
  'caisse Centre : 200 000 + 100 000');
select throws_ok($$ insert into public.paiements (entreprise_id, sens, montant, mode_code, nature, affectations)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'ENTREE', 10, 'VIREMENT', 'APPORT',
                            '[{"engagement_id":"aaaaaaaa-0000-0000-0005-000000000001","montant":10}]') $$,
  'DGL01', 'NATURE_INCOMPATIBLE', 'un paiement qui règle une somme due n''a pas de nature');
select throws_ok($$ insert into public.paiements (entreprise_id, sens, montant, mode_code, nature)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'ENTREE', 10, 'VIREMENT', 'TRANSFERT') $$,
  'DGL01', 'TRANSFERT_DIRECT_INTERDIT', 'une jambe de transfert ne se crée pas seule');

-- Ajustement : motif obligatoire.
select throws_ok($$ insert into public.paiements (entreprise_id, perimetre_id, sens, montant, mode_code, nature)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0001-000000000001',
                            'ENTREE', 5000, 'MOBILE_MONEY', 'AJUSTEMENT') $$,
  'DGL01', 'MOTIF_REQUIS', 'ajustement sans motif refusé');
select lives_ok($$ insert into public.paiements (entreprise_id, perimetre_id, sens, montant, mode_code, nature, note)
                   values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0001-000000000001',
                           'ENTREE', 275000, 'MOBILE_MONEY', 'SOLDE_INITIAL', 'Solde Orange Money au 07/10') $$,
  'admin : solde initial Mobile Money, avec motif');

-- Transfert boutique → boutique (espèces) : une ligne, deux jambes.
select lives_ok($$ insert into public.transferts_tresorerie
                     (id, entreprise_id, perimetre_source_id, perimetre_dest_id, mode_source, mode_dest, montant,
                      session_source_id, session_dest_id, sortie_id, entree_id, motif)
                   values ('aaaaaaaa-0000-0000-000a-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'aaaaaaaa-0000-0000-0001-000000000001', 'aaaaaaaa-0000-0000-0001-000000000002',
                           'ESPECES', 'ESPECES', 100000,
                           'aaaaaaaa-0000-0000-0007-000000000101', 'aaaaaaaa-0000-0000-0007-000000000102',
                           'aaaaaaaa-0000-0000-0006-000000000111', 'aaaaaaaa-0000-0000-0006-000000000112',
                           'Fond de caisse Marché') $$,
  'admin : transfert Centre → Marché');
select is((select (app.solde_session('aaaaaaaa-0000-0000-0007-000000000101'),
                   app.solde_session('aaaaaaaa-0000-0000-0007-000000000102'))::text),
  '(200000,100000)', 'Centre −100 000, Marché +100 000');
select is((select string_agg(sens || ':' || nature, ',' order by sens) from public.paiements
           where transfert_id = 'aaaaaaaa-0000-0000-000a-000000000001'),
  'ENTREE:TRANSFERT,SORTIE:TRANSFERT', 'deux jambes de nature TRANSFERT, liées au transfert');
select is((select sum(case sens when 'ENTREE' then montant else -montant end)::bigint from public.paiements
           where transfert_id = 'aaaaaaaa-0000-0000-000a-000000000001'),
  0::bigint, 'total de l''entreprise inchangé');
select throws_ok($$ insert into public.paiements (entreprise_id, sens, montant, mode_code, annule_paiement_id)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'ENTREE', 1, 'ESPECES',
                            'aaaaaaaa-0000-0000-0006-000000000111') $$,
  'DGL01', 'TRANSFERT_LIE', 'une jambe ne s''annule pas seule');

-- Transfert entre moyens : espèces → banque, même boutique.
select lives_ok($$ insert into public.transferts_tresorerie
                     (entreprise_id, perimetre_source_id, perimetre_dest_id, mode_source, mode_dest, montant,
                      session_source_id, sortie_id, entree_id)
                   values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0001-000000000001',
                           'aaaaaaaa-0000-0000-0001-000000000001', 'ESPECES', 'VIREMENT', 50000,
                           'aaaaaaaa-0000-0000-0007-000000000101',
                           'aaaaaaaa-0000-0000-0006-000000000121', 'aaaaaaaa-0000-0000-0006-000000000122') $$,
  'admin : dépôt espèces → banque');
select is(app.solde_session('aaaaaaaa-0000-0000-0007-000000000101'), 150000::bigint,
  'espèces Centre −50 000 (la banque n''est pas une caisse physique)');
select throws_ok($$ insert into public.transferts_tresorerie
                      (entreprise_id, perimetre_source_id, perimetre_dest_id, mode_source, mode_dest, montant,
                       sortie_id, entree_id)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0001-000000000001',
                            'aaaaaaaa-0000-0000-0001-000000000001', 'ESPECES', 'ESPECES', 1,
                            gen_random_uuid(), gen_random_uuid()) $$,
  '23514', null, 'transfert vers soi-même refusé');
select throws_ok($$ insert into public.transferts_tresorerie
                      (entreprise_id, perimetre_source_id, perimetre_dest_id, mode_source, mode_dest, montant,
                       session_source_id, sortie_id, entree_id)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0001-000000000001',
                            'aaaaaaaa-0000-0000-0001-000000000002', 'ESPECES', 'VIREMENT', 999999,
                            'aaaaaaaa-0000-0000-0007-000000000101', gen_random_uuid(), gen_random_uuid()) $$,
  'DGL01', 'SOLDE_CAISSE_INSUFFISANT', 'pas de transfert au-delà des espèces disponibles');
select is((select count(*)::int from public.transferts_tresorerie), 2, 'transfert refusé : rien n''est créé');

-- Annulation d'un transfert : motif, deux inverses, rien d'effacé.
select throws_ok($$ update public.transferts_tresorerie
                    set statut = 'ANNULE', annulation_sortie_id = gen_random_uuid(),
                        annulation_entree_id = gen_random_uuid()
                    where id = 'aaaaaaaa-0000-0000-000a-000000000001' $$,
  'DGL01', 'MOTIF_REQUIS', 'annulation sans motif refusée');
select lives_ok($$ update public.transferts_tresorerie
                   set statut = 'ANNULE', motif_annulation = 'Mauvaise boutique',
                       annulation_sortie_id = 'aaaaaaaa-0000-0000-0006-000000000113',
                       annulation_entree_id = 'aaaaaaaa-0000-0000-0006-000000000114'
                   where id = 'aaaaaaaa-0000-0000-000a-000000000001' $$,
  'admin : annulation du transfert');
select is((select (app.solde_session('aaaaaaaa-0000-0000-0007-000000000101'),
                   app.solde_session('aaaaaaaa-0000-0000-0007-000000000102'))::text),
  '(250000,0)', 'argent revenu à Centre, Marché à 0');
select is((select count(*)::int from public.paiements
           where transfert_id = 'aaaaaaaa-0000-0000-000a-000000000001'),
  4, 'jambes d''origine conservées + deux inverses');

-- Clôture : un écart se justifie.
select throws_ok($$ update public.caisse_sessions set statut = 'FERMEE', solde_reel = 245000
                    where id = 'aaaaaaaa-0000-0000-0007-000000000101' $$,
  'DGL01', 'JUSTIFICATION_ECART_REQUISE', 'écart sans justification refusé');
select lives_ok($$ update public.caisse_sessions
                   set statut = 'FERMEE', solde_reel = 245000, motif_ecart = 'RENDU_MONNAIE',
                       note_cloture = 'Erreur de rendu monnaie'
                   where id = 'aaaaaaaa-0000-0000-0007-000000000101' $$,
  'admin : clôture avec écart justifié');
select is((select (solde_theorique, ecart, motif_ecart)::text from public.caisse_sessions
           where id = 'aaaaaaaa-0000-0000-0007-000000000101'),
  '(250000,-5000,RENDU_MONNAIE)', 'écart conservé, jamais corrigé en silence');
select lives_ok($$ update public.caisse_sessions set statut = 'FERMEE', solde_reel = 0
                   where id = 'aaaaaaaa-0000-0000-0007-000000000102' $$,
  'caisse équilibrée : clôture sans justification');

-- ================================ Superviseur ================================
reset role;
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111102');
set local role authenticated;
select throws_ok($$ insert into public.paiements (entreprise_id, perimetre_id, sens, montant, mode_code, nature, note)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0001-000000000001',
                            'ENTREE', 1000, 'VIREMENT', 'AJUSTEMENT', 'Correction') $$,
  '42501', null, 'superviseur : pas d''ajustement (cash.adjust)');
select throws_ok($$ insert into public.transferts_tresorerie
                      (entreprise_id, perimetre_source_id, perimetre_dest_id, mode_source, mode_dest, montant,
                       sortie_id, entree_id)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0001-000000000001',
                            'aaaaaaaa-0000-0000-0001-000000000002', 'VIREMENT', 'VIREMENT', 1000,
                            gen_random_uuid(), gen_random_uuid()) $$,
  '42501', null, 'superviseur : jamais vers une boutique qu''il ne gère pas');

-- ================================= Vendeur =================================
reset role;
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111103');
set local role authenticated;
select is_empty($$ select 1 from public.transferts_tresorerie where perimetre_source_id =
                   'aaaaaaaa-0000-0000-0001-000000000001' and perimetre_dest_id = perimetre_source_id $$,
  'vendeur Marché : transfert interne de Centre invisible');

select * from finish();
rollback;
