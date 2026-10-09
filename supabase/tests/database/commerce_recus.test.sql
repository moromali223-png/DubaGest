-- Reçus de vente : numérotation par boutique, poste et jour ; acompte ; annulation tracée (pgTAP).
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(23);

create function pg_temp.en_tant_que(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;

create function pg_temp.ligne(p_id text) returns jsonb language sql as $$
  select jsonb_build_array(jsonb_build_object('id', p_id, 'produit_id', 'aaaaaaaa-0000-0000-0010-000000000091',
    'unite', 'Carton', 'facteur', 4, 'quantite', 2, 'prix_unitaire', 25000));
$$;

-- Repères (seed) : Alpha …0000-000000000001 ; Boutique Centre …0001-…01 ; Boutique Marché …0001-…02
--   admin 101 · superviseur 102 (Centre) · vendeur 103 (Marché) ; client Amadou …0003-…01

-- Produit de test (admin).
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111101');
set local role authenticated;
insert into public.produits (id, entreprise_id, nom, unite_base, prix_detail)
values ('aaaaaaaa-0000-0000-0010-000000000091', 'aaaaaaaa-0000-0000-0000-000000000001', 'Carreau 40×40', 'Pièce', 6000);

-- ============================== Postes ==============================
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111103');

select is((public.attribuer_poste_vente('aaaaaaaa-0000-0000-0000-000000000001',
            'aaaaaaaa-0000-0000-0001-000000000002', 'telephone-vendeur-1')) ->> 'code',
  'A', 'premier appareil de la boutique : poste A');
select is((public.attribuer_poste_vente('aaaaaaaa-0000-0000-0000-000000000001',
            'aaaaaaaa-0000-0000-0001-000000000002', 'telephone-vendeur-1')) ->> 'code',
  'A', 'même appareil : même lettre');
select is((public.attribuer_poste_vente('aaaaaaaa-0000-0000-0000-000000000001',
            'aaaaaaaa-0000-0000-0001-000000000002', 'tablette-comptoir-2')) ->> 'code',
  'B', 'second appareil : lettre suivante');
select throws_ok($$ select public.attribuer_poste_vente('aaaaaaaa-0000-0000-0000-000000000001',
                    'aaaaaaaa-0000-0000-0001-000000000001', 'telephone-vendeur-1') $$,
  '42501', null, 'vendeur : pas de poste dans une autre boutique');

-- Le superviseur du Centre : la numérotation de chaque boutique est indépendante.
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111102');
select is((public.attribuer_poste_vente('aaaaaaaa-0000-0000-0000-000000000001',
            'aaaaaaaa-0000-0000-0001-000000000001', 'telephone-superviseur')) ->> 'code',
  'A', 'autre boutique : la lettre A est de nouveau disponible');

-- ============================== Numéros ==============================
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111103');

select lives_ok($$ insert into public.ventes (id, entreprise_id, perimetre_id, lignes, reglement, mode_code,
                                              paiement_id, date_vente, date_commerciale, poste, sequence)
                   values ('aaaaaaaa-0000-0000-0018-000000000091', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'aaaaaaaa-0000-0000-0001-000000000002', pg_temp.ligne('aaaaaaaa-0000-0000-0013-000000000091'),
                           'IMMEDIAT', 'ESPECES', gen_random_uuid(), '2026-10-07 14:36+00', '2026-10-07', 'A', 1) $$,
  'vente numérotée par l''appareil (poste A, n° 1)');
select is((select numero from public.ventes where id = 'aaaaaaaa-0000-0000-0018-000000000091'),
  'REC-20261007-A001', 'numéro commercial lisible');
select is((select montant_paye from public.ventes where id = 'aaaaaaaa-0000-0000-0018-000000000091'),
  50000::bigint, 'payé comptant : montant payé = total');

select lives_ok($$ insert into public.ventes (id, entreprise_id, perimetre_id, lignes, reglement, mode_code,
                                              paiement_id, date_vente, date_commerciale, poste, sequence)
                   values ('aaaaaaaa-0000-0000-0018-000000000092', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'aaaaaaaa-0000-0000-0001-000000000002', pg_temp.ligne('aaaaaaaa-0000-0000-0013-000000000092'),
                           'IMMEDIAT', 'ESPECES', gen_random_uuid(), '2026-10-07 15:00+00', '2026-10-07', 'B', 1) $$,
  'second appareil, même jour, même séquence');
select is((select numero from public.ventes where id = 'aaaaaaaa-0000-0000-0018-000000000092'),
  'REC-20261007-B001', 'pas de collision entre appareils');

-- Même poste, même séquence (anomalie) : jamais refusée, numérotée par le serveur.
select lives_ok($$ insert into public.ventes (id, entreprise_id, perimetre_id, lignes, reglement, mode_code,
                                              paiement_id, date_vente, date_commerciale, poste, sequence)
                   values ('aaaaaaaa-0000-0000-0018-000000000093', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'aaaaaaaa-0000-0000-0001-000000000002', pg_temp.ligne('aaaaaaaa-0000-0000-0013-000000000093'),
                           'IMMEDIAT', 'ESPECES', gen_random_uuid(), '2026-10-07 15:10+00', '2026-10-07', 'A', 1) $$,
  'doublon de numéro : la vente est gardée');
select is((select numero from public.ventes where id = 'aaaaaaaa-0000-0000-0018-000000000093'),
  'REC-20261007-0001', 'doublon : renuméroté par le serveur (poste 0)');

-- Poste inventé : numéroté par le serveur.
select lives_ok($$ insert into public.ventes (id, entreprise_id, perimetre_id, lignes, reglement, mode_code,
                                              paiement_id, date_vente, date_commerciale, poste, sequence)
                   values ('aaaaaaaa-0000-0000-0018-000000000094', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'aaaaaaaa-0000-0000-0001-000000000002', pg_temp.ligne('aaaaaaaa-0000-0000-0013-000000000094'),
                           'IMMEDIAT', 'ESPECES', gen_random_uuid(), '2026-10-07 15:20+00', '2026-10-07', 'Q', 7) $$,
  'poste non attribué : vente gardée');
select is((select numero from public.ventes where id = 'aaaaaaaa-0000-0000-0018-000000000094'),
  'REC-20261007-0002', 'compteur serveur : suivant, sans doublon');

-- Le lendemain, le compteur repart à 1.
select lives_ok($$ insert into public.ventes (id, entreprise_id, perimetre_id, lignes, reglement, mode_code,
                                              paiement_id, date_vente, date_commerciale, poste, sequence)
                   values ('aaaaaaaa-0000-0000-0018-000000000095', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'aaaaaaaa-0000-0000-0001-000000000002', pg_temp.ligne('aaaaaaaa-0000-0000-0013-000000000095'),
                           'IMMEDIAT', 'ESPECES', gen_random_uuid(), '2026-10-08 09:00+00', '2026-10-08', 'A', 1) $$,
  'vente du lendemain');
select is((select numero from public.ventes where id = 'aaaaaaaa-0000-0000-0018-000000000095'),
  'REC-20261008-A001', 'nouveau jour : 001');

-- Appareil réinstallé : le serveur lui rend ses derniers numéros du jour.
select lives_ok($$ insert into public.ventes (entreprise_id, perimetre_id, lignes, reglement, mode_code,
                                              paiement_id, date_commerciale, poste, sequence)
                   values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0001-000000000002',
                           pg_temp.ligne('aaaaaaaa-0000-0000-0013-000000000099'),
                           'IMMEDIAT', 'ESPECES', gen_random_uuid(), (now() at time zone 'UTC')::date, 'A', 7) $$,
  'vente du jour, n° 7');
select is((public.attribuer_poste_vente('aaaaaaaa-0000-0000-0000-000000000001',
            'aaaaaaaa-0000-0000-0001-000000000002', 'telephone-vendeur-1'))
            -> 'derniers' ->> to_char((now() at time zone 'UTC')::date, 'YYYY-MM-DD'),
  '7', 'derniers numéros du poste renvoyés à l''appareil');

-- ============================== Acompte ==============================
select lives_ok($$ insert into public.ventes (id, entreprise_id, perimetre_id, contact_id, lignes, reglement,
                                              montant_paye, mode_code, paiement_id)
                   values ('aaaaaaaa-0000-0000-0018-000000000096', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'aaaaaaaa-0000-0000-0001-000000000002', 'aaaaaaaa-0000-0000-0003-000000000001',
                           pg_temp.ligne('aaaaaaaa-0000-0000-0013-000000000096'), 'CREDIT', 20000, 'ESPECES',
                           'aaaaaaaa-0000-0000-0006-000000000096') $$,
  'vente à crédit avec acompte');
select is((select (e.montant_total, p.montant)::text from public.engagements e
           join public.paiements p on p.id = 'aaaaaaaa-0000-0000-0006-000000000096'
           where e.id = 'aaaaaaaa-0000-0000-0018-000000000096'),
  '(50000,20000)', 'dette du client : total 50 000, acompte 20 000 encaissé');
select throws_ok($$ insert into public.ventes (entreprise_id, perimetre_id, contact_id, lignes, reglement,
                                               montant_paye, mode_code, paiement_id)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0001-000000000002',
                            'aaaaaaaa-0000-0000-0003-000000000001',
                            pg_temp.ligne('aaaaaaaa-0000-0000-0013-000000000097'), 'CREDIT', 50000, 'ESPECES',
                            gen_random_uuid()) $$,
  'DGL01', 'MONTANT_INVALIDE', 'acompte égal au total : ce n''est pas un crédit');

-- ============================== Annulation ==============================
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111101');
select lives_ok($$ insert into public.ventes (id, entreprise_id, perimetre_id, contact_id, lignes, reglement)
                   values ('aaaaaaaa-0000-0000-0018-000000000098', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'aaaaaaaa-0000-0000-0001-000000000002', 'aaaaaaaa-0000-0000-0003-000000000001',
                           pg_temp.ligne('aaaaaaaa-0000-0000-0013-000000000098'), 'CREDIT');
                   update public.ventes set statut = 'ANNULEE', motif_annulation = 'Erreur de saisie'
                   where id = 'aaaaaaaa-0000-0000-0018-000000000098' $$,
  'admin : annulation d''une vente non encaissée');
select ok((select annulee_le is not null and annulee_par_nom = 'Awa Diallo' and numero like 'REC-%'
           from public.ventes where id = 'aaaaaaaa-0000-0000-0018-000000000098'),
  'reçu conservé : annulé le, par qui, numéro inchangé');

select * from finish();
rollback;
