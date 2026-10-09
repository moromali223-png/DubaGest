-- Dépenses — étape 2 : dépenses courantes, bénéficiaire, permissions (pgTAP).
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(22);

create function pg_temp.en_tant_que(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;

-- Repères
--   Alpha aaaaaaaa-0000-0000-0000-000000000001 ; Boutique Centre …0001-000000000001
--   admin …101, superviseur …102 (Centre, expenses.view/create), vendeur …103
create temp table cat as
  select id from public.depense_categories
  where entreprise_id = 'aaaaaaaa-0000-0000-0000-000000000001' and code = 'ENERGIE';
grant select on cat to authenticated;

-- ============================== Calcul des échéances ==============================
select is(app.echeance_suivante('2026-01-31', 'MOIS', 1, '2026-01-31'), '2026-02-28'::date,
  'mensuel du 31 : février au 28');
select is(app.echeance_suivante('2026-01-31', 'MOIS', 1, '2026-02-28'), '2026-03-31'::date,
  'mensuel du 31 : retour au 31 en mars (pas de dérive)');
select is(app.echeance_suivante('2026-10-01', 'SEMAINE', 2, '2026-10-01'), '2026-10-15'::date,
  'toutes les 2 semaines');
select is(app.echeance_suivante('2026-10-07', 'JOUR', 1, '2026-10-20'), '2026-10-21'::date, 'quotidien');
select is(app.echeance_suivante('2026-10-01', 'MOIS', 3, '2026-10-01'), '2027-01-01'::date, 'trimestriel');
select is(app.echeance_suivante('2026-03-15', 'AN', 1, '2026-12-31'), '2027-03-15'::date, 'annuel');
select is(app.echeance_suivante('2026-11-01', 'MOIS', 1, '2026-10-07'), '2026-11-01'::date,
  'avant le début : première échéance = début');

select is((select count(*)::int from public.depense_categories
           where entreprise_id = 'aaaaaaaa-0000-0000-0000-000000000001'
             and code in ('CARBURANT', 'EAU', 'INTERNET', 'REPARATION', 'GARDIENNAGE')), 5,
  'nouvelles catégories pour toutes les activités');

-- ================================ Superviseur ================================
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111102');
set local role authenticated;
select throws_ok($$ insert into public.depenses_courantes (entreprise_id, perimetre_id, categorie_id, nom,
                                                            montant_prevu, periode, date_debut, prochaine_echeance)
                    select 'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0001-000000000001', id,
                           'Électricité', 75000, 'MOIS', '2026-10-10', '2026-10-10' from cat $$,
  '42501', null, 'superviseur : dépenses courantes refusées (expenses.recurring)');

-- ============================ Administrateur ============================
reset role;
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111101');
set local role authenticated;

select lives_ok($$ insert into public.depenses_courantes (id, entreprise_id, perimetre_id, categorie_id, nom,
                                                           montant_prevu, type_montant, periode, date_debut,
                                                           prochaine_echeance, mode_code)
                   select 'aaaaaaaa-0000-0000-0009-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
                          'aaaaaaaa-0000-0000-0001-000000000001', id, 'Électricité', 75000, 'VARIABLE', 'MOIS',
                          '2026-10-10', '2026-10-10', 'VIREMENT' from cat $$,
  'admin : dépense courante créée');
select is((select (activite_code, version)::text from public.depenses_courantes
           where id = 'aaaaaaaa-0000-0000-0009-000000000001'),
  '(COMMERCE,1)', 'activité déduite de la boutique');
select is_empty($$ select 1 from public.engagements where libelle = 'Électricité' $$,
  'une dépense courante n''est pas une dépense : rien à payer, rien compté');

-- Échéance du 10 octobre payée 68 500 (montant réel) : la courante passe au 10 novembre.
select lives_ok($$ insert into public.depenses (id, entreprise_id, perimetre_id, categorie_id, libelle, montant,
                                                reglement, courante_id, echeance_prevue, beneficiaire)
                   select 'aaaaaaaa-0000-0000-0008-000000000101', 'aaaaaaaa-0000-0000-0000-000000000001',
                          'aaaaaaaa-0000-0000-0001-000000000001', id, 'Électricité', 68500, 'DIFFERE',
                          'aaaaaaaa-0000-0000-0009-000000000001', '2026-10-10', 'EDM' from cat $$,
  'admin : paiement de l''échéance avec le montant réel');
select is((select prochaine_echeance from public.depenses_courantes
           where id = 'aaaaaaaa-0000-0000-0009-000000000001'),
  '2026-11-10'::date, 'prochaine échéance avancée d''une période');
select is((select (montant, beneficiaire)::text from public.depenses
           where id = 'aaaaaaaa-0000-0000-0008-000000000101'),
  '(68500,EDM)', 'dépense réelle avec bénéficiaire libre');
select throws_ok($$ insert into public.depenses (entreprise_id, perimetre_id, categorie_id, libelle, montant,
                                                 reglement, courante_id, echeance_prevue)
                    select 'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0001-000000000001', id,
                           'Électricité', 1000, 'DIFFERE', 'aaaaaaaa-0000-0000-0009-000000000001', '2026-10-10'
                    from cat $$,
  '23505', null, 'une échéance ne se paie qu''une fois');

-- Annulée : l'échéance redevient à payer, et peut être payée à nouveau.
select lives_ok($$ update public.depenses set statut = 'ANNULEE', motif_annulation = 'Erreur de montant'
                   where id = 'aaaaaaaa-0000-0000-0008-000000000101' $$,
  'admin : annulation de la dépense de l''échéance');
select is((select prochaine_echeance from public.depenses_courantes
           where id = 'aaaaaaaa-0000-0000-0009-000000000001'),
  '2026-10-10'::date, 'échéance de nouveau à payer');
select lives_ok($$ insert into public.depenses (entreprise_id, perimetre_id, categorie_id, libelle, montant,
                                                reglement, courante_id, echeance_prevue)
                   select 'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0001-000000000001', id,
                          'Électricité', 69000, 'DIFFERE', 'aaaaaaaa-0000-0000-0009-000000000001', '2026-10-10'
                   from cat $$,
  'échéance libérée : nouveau paiement accepté');

-- Changement de rythme : il repart de la prochaine échéance.
select lives_ok($$ update public.depenses_courantes set periode = 'MOIS', intervalle = 2
                   where id = 'aaaaaaaa-0000-0000-0009-000000000001' $$,
  'admin : passage à tous les 2 mois');
select is((select (date_debut, prochaine_echeance)::text from public.depenses_courantes
           where id = 'aaaaaaaa-0000-0000-0009-000000000001'),
  '(2026-11-10,2026-11-10)', 'nouveau rythme ancré sur la prochaine échéance');

-- ================================= Vendeur =================================
reset role;
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111103');
set local role authenticated;
select is_empty($$ select 1 from public.depenses_courantes $$, 'vendeur : aucune dépense courante visible');

select * from finish();
rollback;
