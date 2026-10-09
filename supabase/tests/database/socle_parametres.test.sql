-- Socle commun — étape 9 : paramètres de l'entreprise (pgTAP).
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(11);

create function pg_temp.en_tant_que(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;

-- Repères : Alpha aaaaaaaa-…-000000000001 ; administrateur …101 ; vendeur …103.

select is((select modes_paiement from public.entreprises where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  array['ESPECES', 'MOBILE_MONEY', 'CARTE', 'VIREMENT', 'CHEQUE', 'AUTRE'], 'tous les modes proposés par défaut');

-- ================================ Vendeur ================================
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111103');
set local role authenticated;
-- La RLS (entreprise.manage) masque la ligne : rien n'est modifié.
update public.entreprises set modes_paiement = array['ESPECES'], pied_recu = 'X'
where id = 'aaaaaaaa-0000-0000-0000-000000000001';
select is((select cardinality(modes_paiement) from public.entreprises where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  6, 'vendeur : ne change pas les paramètres');

-- ============================ Administrateur ============================
reset role;
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111101');
set local role authenticated;

select throws_ok($$ update public.entreprises set modes_paiement = '{}'
                    where id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  'DGL01', 'MODES_PAIEMENT_INVALIDES', 'au moins un mode');
select throws_ok($$ update public.entreprises set modes_paiement = array['ESPECES', 'BITCOIN']
                    where id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  'DGL01', 'MODES_PAIEMENT_INVALIDES', 'mode hors catalogue refusé');
select lives_ok($$ update public.entreprises
                   set modes_paiement = array['MOBILE_MONEY', 'ESPECES', 'ESPECES'], pied_recu = '  Merci de votre confiance  '
                   where id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  'administrateur : modes et pied de reçu');
select is((select modes_paiement from public.entreprises where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  array['ESPECES', 'MOBILE_MONEY'], 'sans doublon, dans l''ordre du catalogue');
select is((select pied_recu from public.entreprises where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  'Merci de votre confiance', 'pied de reçu nettoyé');
select throws_ok($$ update public.entreprises set pied_recu = repeat('x', 301)
                    where id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  '23514', null, 'pied de reçu limité à 300 caractères');

-- Changement fait hier : un nouveau paiement par carte est refusé…
reset role;
update public.entreprises set modes_paiement_modifies_le = now() - interval '1 day'
where id = 'aaaaaaaa-0000-0000-0000-000000000001';
set local role authenticated;
select throws_ok($$ insert into public.paiements (entreprise_id, sens, montant, mode_code)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'ENTREE', 1000, 'CARTE') $$,
  'DGL01', 'MODE_PAIEMENT_DESACTIVE', 'mode retiré : nouveau paiement refusé');
-- … mais un paiement daté d'avant le changement (saisi hors-ligne) passe.
select lives_ok($$ insert into public.paiements (entreprise_id, sens, montant, mode_code, date_paiement)
                   values ('aaaaaaaa-0000-0000-0000-000000000001', 'ENTREE', 1000, 'CARTE', now() - interval '2 days') $$,
  'paiement saisi avant le changement accepté');
select lives_ok($$ insert into public.paiements (entreprise_id, sens, montant, mode_code)
                   values ('aaaaaaaa-0000-0000-0000-000000000001', 'ENTREE', 1000, 'MOBILE_MONEY') $$,
  'mode proposé : accepté');

select * from finish();
rollback;
