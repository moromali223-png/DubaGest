-- Socle commun — étape 3 : noyau financier (pgTAP).
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(46);

create function pg_temp.en_tant_que(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;

-- Repères du seed
--   Alpha                 aaaaaaaa-0000-0000-0000-000000000001
--   Boutique Marché (BM)  aaaaaaaa-0000-0000-0001-000000000002   (vendeur)
--   Caisse Centre / Marché aaaaaaaa-0000-0000-0004-00000000000{1,2}
--   Créance Amadou 50 000 aaaaaaaa-0000-0000-0005-000000000001   (sur BM)

-- Catalogue
select is((select count(*)::int from public.modules where categorie = 'FINANCES'
           and code in ('finances.creances', 'finances.paiements', 'finances.caisse')), 3,
  'modules Finances : créances, paiements, caisse');
select is_empty($$ select 1 from public.modules where code = 'commerce.caisse' $$,
  'la caisse n''est plus réservée au Commerce');
select is((select mouvement_caisse from public.modes_paiement where code = 'ESPECES'), true,
  'les espèces passent par la caisse');

-- =========================== Vendeur (Boutique Marché) ===========================
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111103');
set local role authenticated;

select is((select array_agg(nom)::text from public.caisses), '{"Caisse Marché"}',
  'vendeur : seulement la caisse de sa boutique');
select lives_ok($$ insert into public.caisse_sessions (id, entreprise_id, caisse_id, solde_initial)
                   values ('aaaaaaaa-0000-0000-0007-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'aaaaaaaa-0000-0000-0004-000000000002', 10000) $$,
  'vendeur : ouverture de sa caisse');
select throws_ok($$ insert into public.caisse_sessions (entreprise_id, caisse_id)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0004-000000000001') $$,
  '42501', null, 'vendeur : caisse d''une autre boutique refusée');
select throws_ok($$ insert into public.caisse_sessions (entreprise_id, caisse_id)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0004-000000000002') $$,
  'DGL01', 'CAISSE_DEJA_OUVERTE', 'une seule session ouverte par caisse');

select is((select count(*)::int from public.engagements), 1, 'vendeur : voit les créances de sa boutique');
select throws_ok($$ insert into public.engagements (entreprise_id, sens, libelle, montant_total)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'A_RECEVOIR', 'X', 100) $$,
  '42501', null, 'vendeur : création de créance refusée (receivables.manage)');

-- Paiement en espèces affecté à la créance : un seul INSERT, tout le reste par trigger.
select lives_ok($$ insert into public.paiements (id, entreprise_id, sens, montant, mode_code, contact_id,
                                                 session_id, affectations)
                   values ('aaaaaaaa-0000-0000-0006-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'ENTREE', 20000, 'ESPECES', 'aaaaaaaa-0000-0000-0003-000000000001',
                           'aaaaaaaa-0000-0000-0007-000000000001',
                           '[{"id":"aaaaaaaa-0000-0000-0009-000000000001","engagement_id":"aaaaaaaa-0000-0000-0005-000000000001","montant":20000}]') $$,
  'vendeur : encaissement de 20 000 sur la créance');
select is((select montant_regle from public.engagements where id = 'aaaaaaaa-0000-0000-0005-000000000001'),
  20000::bigint, 'réglé recalculé par le serveur');
select is((select perimetre_id from public.paiements where id = 'aaaaaaaa-0000-0000-0006-000000000001'),
  'aaaaaaaa-0000-0000-0001-000000000002'::uuid, 'site du paiement déduit de la caisse');
select is((select type from public.caisse_mouvements where id = 'aaaaaaaa-0000-0000-0006-000000000001'),
  'ENCAISSEMENT', 'mouvement de caisse créé avec l''identifiant du paiement');
select is(app.solde_session('aaaaaaaa-0000-0000-0007-000000000001'), 30000::bigint,
  'solde de caisse : 10 000 + 20 000');

select throws_ok($$ insert into public.paiements (entreprise_id, sens, montant, mode_code, affectations)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'ENTREE', 40000, 'MOBILE_MONEY',
                            '[{"engagement_id":"aaaaaaaa-0000-0000-0005-000000000001","montant":40000}]') $$,
  'DGL01', 'MONTANT_SUPERIEUR_RESTE', 'pas de paiement au-delà du reste dû');
select throws_ok($$ insert into public.paiements (entreprise_id, sens, montant, mode_code, affectations)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'ENTREE', 1000, 'MOBILE_MONEY',
                            '[{"engagement_id":"aaaaaaaa-0000-0000-0005-000000000001","montant":2000}]') $$,
  'DGL01', 'AFFECTATION_SUPERIEURE_PAIEMENT', 'affectations limitées au montant du paiement');
select throws_ok($$ insert into public.paiements (entreprise_id, sens, montant, mode_code, contact_id, affectations)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'ENTREE', 1000, 'MOBILE_MONEY',
                            'aaaaaaaa-0000-0000-0003-000000000002',
                            '[{"engagement_id":"aaaaaaaa-0000-0000-0005-000000000001","montant":1000}]') $$,
  'DGL01', 'AFFECTATION_CONTACT_DIFFERENT', 'pas de paiement de Mariam sur la dette d''Amadou');
select is((select count(*)::int from public.paiements), 1, 'paiements refusés : rien n''est enregistré');
select throws_ok($$ insert into public.paiements (entreprise_id, sens, montant, mode_code, session_id)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'ENTREE', 1000, 'MOBILE_MONEY',
                            'aaaaaaaa-0000-0000-0007-000000000001') $$,
  'DGL01', 'MODE_SANS_CAISSE', 'seules les espèces passent par la caisse');
select throws_ok($$ insert into public.paiements (entreprise_id, perimetre_id, sens, montant, mode_code)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0001-000000000002',
                            'SORTIE', 1000, 'MOBILE_MONEY') $$,
  '42501', null, 'vendeur : verser de l''argent refusé (receivables.manage)');
select throws_ok($$ update public.paiements set montant = 1 where id = 'aaaaaaaa-0000-0000-0006-000000000001' $$,
  '42501', null, 'un paiement ne se modifie jamais');
select throws_ok($$ insert into public.paiements (entreprise_id, sens, montant, mode_code, annule_paiement_id)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'SORTIE', 20000, 'ESPECES',
                            'aaaaaaaa-0000-0000-0006-000000000001') $$,
  '42501', null, 'vendeur : annulation refusée (payments.cancel)');

select throws_ok($$ insert into public.caisse_mouvements (entreprise_id, session_id, type, montant)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0007-000000000001',
                            'RETRAIT', 50000) $$,
  'DGL01', 'SOLDE_CAISSE_INSUFFISANT', 'retrait limité au solde de la caisse');
select lives_ok($$ insert into public.caisse_mouvements (entreprise_id, session_id, type, montant, motif)
                   values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0007-000000000001',
                           'RETRAIT', 5000, 'Dépôt banque') $$,
  'vendeur : retrait de 5 000');
select throws_ok($$ insert into public.caisse_mouvements (entreprise_id, session_id, type, montant)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0007-000000000001',
                            'ENCAISSEMENT', 100) $$,
  'DGL01', 'TYPE_MOUVEMENT_INVALIDE', 'un encaissement vient toujours d''un paiement');

-- Hors-ligne : rejeu sans doublon (ni paiement, ni mouvement).
select is(public.sync_push('00000000-0000-0000-0000-0000000000f1', 'paiements', 'INSERT',
            'aaaaaaaa-0000-0000-0006-000000000002', null,
            '{"entreprise_id":"aaaaaaaa-0000-0000-0000-000000000001","sens":"ENTREE","montant":10000,
              "mode_code":"ESPECES","session_id":"aaaaaaaa-0000-0000-0007-000000000001"}') ->> 'statut',
  'APPLIQUE', 'sync : paiement hors-ligne appliqué');
select ok(public.sync_push('00000000-0000-0000-0000-0000000000f1', 'paiements', 'INSERT',
            'aaaaaaaa-0000-0000-0006-000000000002', null,
            '{"entreprise_id":"aaaaaaaa-0000-0000-0000-000000000001","sens":"ENTREE","montant":10000,
              "mode_code":"ESPECES","session_id":"aaaaaaaa-0000-0000-0007-000000000001"}') ? 'rejoue',
  'sync : rejeu reconnu');
select is(app.solde_session('aaaaaaaa-0000-0000-0007-000000000001'), 35000::bigint,
  'rejeu : la caisse n''est créditée qu''une fois');
-- Sans cash.close, la RLS masque la ligne à la mise à jour : rien n'est modifié
-- (sync_push le signale alors comme INTERDIT).
update public.caisse_sessions set statut = 'FERMEE', solde_reel = 0
where id = 'aaaaaaaa-0000-0000-0007-000000000001';
select is((select statut from public.caisse_sessions where id = 'aaaaaaaa-0000-0000-0007-000000000001'),
  'OUVERTE', 'vendeur : clôture sans effet (cash.close)');

-- ================================ Administrateur ================================
reset role;
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111101');
set local role authenticated;

select lives_ok($$ insert into public.paiements (id, entreprise_id, sens, montant, mode_code, annule_paiement_id)
                   values ('aaaaaaaa-0000-0000-0006-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'ENTREE', 1, 'CARTE', 'aaaaaaaa-0000-0000-0006-000000000001') $$,
  'admin : annulation par paiement inverse');
select is((select (statut, sens, montant, mode_code)::text from public.paiements
           where id = 'aaaaaaaa-0000-0000-0006-000000000003'),
  '(VALIDE,SORTIE,20000,ESPECES)', 'inverse : copie conforme forcée par le serveur');
select is((select statut from public.paiements where id = 'aaaaaaaa-0000-0000-0006-000000000001'),
  'ANNULE', 'paiement d''origine marqué annulé');
select is((select montant_regle from public.engagements where id = 'aaaaaaaa-0000-0000-0005-000000000001'),
  0::bigint, 'la créance redevient due');
select is(app.solde_session('aaaaaaaa-0000-0000-0007-000000000001'), 15000::bigint,
  'mouvement inverse en caisse : 35 000 − 20 000');
select throws_ok($$ insert into public.paiements (entreprise_id, sens, montant, mode_code, annule_paiement_id)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'SORTIE', 20000, 'ESPECES',
                            'aaaaaaaa-0000-0000-0006-000000000001') $$,
  'DGL01', 'PAIEMENT_DEJA_ANNULE', 'pas de double annulation');

select lives_ok($$ insert into public.engagements (id, entreprise_id, sens, libelle, montant_total)
                   values ('aaaaaaaa-0000-0000-0005-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'A_PAYER', 'Facture fournisseur', 10000) $$,
  'admin : dette fournisseur');
select lives_ok($$ insert into public.paiements (entreprise_id, sens, montant, mode_code, affectations)
                   values ('aaaaaaaa-0000-0000-0000-000000000001', 'SORTIE', 6000, 'VIREMENT',
                           '[{"engagement_id":"aaaaaaaa-0000-0000-0005-000000000002","montant":6000}]') $$,
  'admin : paiement partiel du fournisseur');
select throws_ok($$ update public.engagements set montant_total = 5000
                    where id = 'aaaaaaaa-0000-0000-0005-000000000002' $$,
  'DGL01', 'MONTANT_INFERIEUR_REGLE', 'total jamais inférieur au réglé');
select throws_ok($$ update public.engagements set statut = 'ANNULE'
                    where id = 'aaaaaaaa-0000-0000-0005-000000000002' $$,
  'DGL01', 'ENGAGEMENT_REGLE', 'annulation impossible tant que des paiements existent');
select throws_ok($$ insert into public.paiements (entreprise_id, sens, montant, mode_code, affectations)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'ENTREE', 100, 'VIREMENT',
                            '[{"engagement_id":"aaaaaaaa-0000-0000-0005-000000000002","montant":100}]') $$,
  'DGL01', 'AFFECTATION_SENS_INCOMPATIBLE', 'un encaissement ne règle pas une dette');

select lives_ok($$ update public.caisse_sessions set statut = 'FERMEE', solde_reel = 14000, note_cloture = 'Billet manquant'
                   where id = 'aaaaaaaa-0000-0000-0007-000000000001' $$,
  'admin : clôture de caisse');
select is((select (solde_theorique, ecart)::text from public.caisse_sessions
           where id = 'aaaaaaaa-0000-0000-0007-000000000001'),
  '(15000,-1000)', 'clôture : solde attendu et écart calculés par le serveur');
select throws_ok($$ insert into public.caisse_mouvements (entreprise_id, session_id, type, montant)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0007-000000000001',
                            'DEPOT', 100) $$,
  'DGL01', 'CAISSE_FERMEE', 'caisse clôturée : plus aucun mouvement');
select is((select user_id from public.audit_logs
           where entite_type = 'paiements' and entite_id = 'aaaaaaaa-0000-0000-0006-000000000001'
             and action = 'MODIFICATION'),
  '11111111-1111-1111-1111-111111111101'::uuid, 'audit : annulation tracée avec son auteur');

-- =========================== Isolation entre entreprises ===========================
reset role;
select pg_temp.en_tant_que('22222222-2222-2222-2222-222222222201');
set local role authenticated;
select is_empty($$ select 1 from public.paiements union all select 1 from public.engagements
                   union all select 1 from public.caisse_mouvements $$,
  'Beta : aucune donnée financière d''Alpha visible');
select throws_ok($$ insert into public.paiements (entreprise_id, sens, montant, mode_code)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'ENTREE', 1, 'CARTE') $$,
  '42501', null, 'Beta : paiement chez Alpha refusé');

select * from finish();
rollback;
