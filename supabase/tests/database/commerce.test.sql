-- Commerce : catalogue, stock par boutique, transferts, achats, ventes (pgTAP).
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(44);

create function pg_temp.en_tant_que(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;

-- Repères (seed)
--   Alpha          aaaaaaaa-0000-0000-0000-000000000001
--   Boutique Centre …0001-000000000001 (superviseur 102) · Boutique Marché …0001-000000000002 (vendeur 103)
--   Fournisseur    aaaaaaaa-0000-0000-0003-000000000001
--   Produit        aaaaaaaa-0000-0000-0010-000000000001 (carreaux : pièce, carton de 4)

-- ============================== Superviseur ==============================
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111102');
set local role authenticated;

select lives_ok($$ insert into public.categories_produits (id, entreprise_id, nom, icone, couleur)
                   values ('aaaaaaaa-0000-0000-0011-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'Carrelage', 'grid', '#1E7E4E') $$,
  'superviseur : création d''une catégorie');
select lives_ok($$ insert into public.categories_produits (id, entreprise_id, parent_id, nom)
                   values ('aaaaaaaa-0000-0000-0011-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'aaaaaaaa-0000-0000-0011-000000000001', 'Carrelage sol') $$,
  'sous-catégorie');
select throws_ok($$ insert into public.categories_produits (entreprise_id, parent_id, nom)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0011-000000000002', 'Trop') $$,
  'DGL01', 'CATEGORIE_INVALIDE', 'pas de troisième niveau');

select lives_ok($$ insert into public.produits (id, entreprise_id, categorie_id, nom, unite_base, prix_detail,
                                                unites, seuil_alerte, photos)
                   values ('aaaaaaaa-0000-0000-0010-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'aaaaaaaa-0000-0000-0011-000000000002', 'Carreaux 40×40', 'Pièce', 300,
                           '[{"id":"aaaaaaaa-0000-0000-0012-000000000001","nom":"Carton","facteur":4,"prix_detail":1100}]',
                           20,
                           array['aaaaaaaa-0000-0000-0000-000000000001/produits/aaaaaaaa-0000-0000-0010-000000000001/p1.jpg']) $$,
  'superviseur : création d''un produit avec unité et photo');
select throws_ok($$ insert into public.produits (entreprise_id, nom, unites)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'X', '[{"id":"aaaaaaaa-0000-0000-0012-000000000009","nom":"Carton","facteur":0}]') $$,
  'DGL01', 'UNITE_INVALIDE', 'facteur nul refusé');
select throws_ok($$ insert into public.produits (entreprise_id, nom, photos)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'X', array['autre/chemin.jpg']) $$,
  'DGL01', 'CHEMIN_INVALIDE', 'photo hors de la fiche refusée');

-- Entrée : 25 cartons = 100 pièces.
select lives_ok($$ insert into public.mouvements_stock (id, entreprise_id, perimetre_id, produit_id, type, motif,
                                                        quantite, quantite_saisie, unite_saisie, facteur)
                   values ('aaaaaaaa-0000-0000-0013-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'aaaaaaaa-0000-0000-0001-000000000001', 'aaaaaaaa-0000-0000-0010-000000000001',
                           'ENTREE', 'ACHAT', 100, 25, 'Carton', 4) $$,
  'superviseur : entrée dans sa boutique');
select is((select (stock_avant, stock_apres, delta)::text from public.mouvements_stock
           where id = 'aaaaaaaa-0000-0000-0013-000000000001'),
  '(0.0000,100.0000,100.0000)', 'stock avant / après calculés par le serveur');
select is((select quantite from public.stocks where perimetre_id = 'aaaaaaaa-0000-0000-0001-000000000001'
           and produit_id = 'aaaaaaaa-0000-0000-0010-000000000001'), 100.0000::numeric, 'stock Centre : 100');

select throws_ok($$ insert into public.mouvements_stock (entreprise_id, perimetre_id, produit_id, type, motif,
                                                         quantite, quantite_saisie, unite_saisie)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0001-000000000002',
                            'aaaaaaaa-0000-0000-0010-000000000001', 'ENTREE', 'ACHAT', 10, 10, 'Pièce') $$,
  '42501', null, 'superviseur : aucune écriture dans une boutique non affectée');

select lives_ok($$ insert into public.mouvements_stock (entreprise_id, perimetre_id, produit_id, type, motif,
                                                        quantite, quantite_saisie, unite_saisie)
                   values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0001-000000000001',
                           'aaaaaaaa-0000-0000-0010-000000000001', 'SORTIE', 'CASSE', 30, 30, 'Pièce') $$,
  'sortie (casse) de 30 pièces');
select throws_ok($$ insert into public.mouvements_stock (entreprise_id, perimetre_id, produit_id, type, motif,
                                                         quantite, quantite_saisie, unite_saisie)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0001-000000000001',
                            'aaaaaaaa-0000-0000-0010-000000000001', 'SORTIE', 'PERTE', 71, 71, 'Pièce') $$,
  'DGL01', 'STOCK_INSUFFISANT', 'stock négatif interdit');

select lives_ok($$ insert into public.mouvements_stock (id, entreprise_id, perimetre_id, produit_id, type, motif,
                                                        quantite, quantite_saisie, unite_saisie)
                   values ('aaaaaaaa-0000-0000-0013-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'aaaaaaaa-0000-0000-0001-000000000001', 'aaaaaaaa-0000-0000-0010-000000000001',
                           'INVENTAIRE', 'CASSE', 65, 65, 'Pièce') $$,
  'inventaire : 65 pièces comptées');
select is((select (delta, stock_apres)::text from public.mouvements_stock
           where id = 'aaaaaaaa-0000-0000-0013-000000000002'),
  '(-5.0000,65.0000)', 'écart de l''inventaire calculé sur le stock serveur');

select throws_ok($$ insert into public.mouvements_stock (entreprise_id, perimetre_id, produit_id, type, motif,
                                                         quantite, quantite_saisie, unite_saisie)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0001-000000000001',
                            'aaaaaaaa-0000-0000-0010-000000000001', 'TRANSFERT_ENTREE', 'TRANSFERT', 5, 5, 'Pièce') $$,
  'DGL01', 'MOUVEMENT_INVALIDE', 'un transfert ne se saisit pas comme un mouvement');
select throws_ok($$ update public.stocks set quantite = 1000 $$,
  '42501', null, 'le stock ne se modifie jamais directement');

select throws_ok($$ insert into public.transferts_stock (entreprise_id, produit_id, de_perimetre_id, vers_perimetre_id,
                                                         quantite, quantite_saisie, unite_saisie, mouvement_entree_id)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0010-000000000001',
                            'aaaaaaaa-0000-0000-0001-000000000001', 'aaaaaaaa-0000-0000-0001-000000000002',
                            8, 2, 'Carton', gen_random_uuid()) $$,
  '42501', null, 'superviseur : pas de transfert vers une boutique non gérée');

-- Achat : 10 cartons à 1 000 + 5 pièces à 300 = 11 500.
select lives_ok($$ insert into public.achats (id, entreprise_id, perimetre_id, fournisseur_id, reference, lignes)
                   values ('aaaaaaaa-0000-0000-0014-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'aaaaaaaa-0000-0000-0001-000000000001', 'aaaaaaaa-0000-0000-0003-000000000001', 'BL-12',
                           '[{"id":"aaaaaaaa-0000-0000-0015-000000000001","produit_id":"aaaaaaaa-0000-0000-0010-000000000001","unite":"Carton","facteur":4,"quantite":10,"prix_unitaire":1000},
                             {"id":"aaaaaaaa-0000-0000-0015-000000000002","produit_id":"aaaaaaaa-0000-0000-0010-000000000001","unite":"Pièce","facteur":1,"quantite":5,"prix_unitaire":300}]') $$,
  'superviseur : achat de plusieurs lignes');
select is((select (total, statut)::text from public.achats where id = 'aaaaaaaa-0000-0000-0014-000000000001'),
  '(11500,COMMANDE)', 'total calculé par le serveur');
select is((select (sens, origine_type, montant_total, contact_id)::text from public.engagements
           where id = 'aaaaaaaa-0000-0000-0014-000000000001'),
  '(A_PAYER,ACHAT,11500,aaaaaaaa-0000-0000-0003-000000000001)', 'dette fournisseur créée');
select is((select quantite from public.stocks where perimetre_id = 'aaaaaaaa-0000-0000-0001-000000000001'
           and produit_id = 'aaaaaaaa-0000-0000-0010-000000000001'), 65.0000::numeric,
  'une commande ne change pas le stock');

select lives_ok($$ insert into public.receptions (id, entreprise_id, achat_id, lignes)
                   values ('aaaaaaaa-0000-0000-0016-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'aaaaaaaa-0000-0000-0014-000000000001',
                           '[{"id":"aaaaaaaa-0000-0000-0013-000000000011","ligne_id":"aaaaaaaa-0000-0000-0015-000000000001","quantite":6}]') $$,
  'réception partielle : 6 cartons sur 10');
select is((select quantite from public.stocks where perimetre_id = 'aaaaaaaa-0000-0000-0001-000000000001'
           and produit_id = 'aaaaaaaa-0000-0000-0010-000000000001'), 89.0000::numeric, 'stock : 65 + 24 pièces');
select is((select (statut, lignes->0->>'recu')::text from public.achats where id = 'aaaaaaaa-0000-0000-0014-000000000001'),
  '(RECU_PARTIEL,6)', 'achat partiellement reçu');
select is((select (type, motif, origine_type, quantite_saisie, unite_saisie)::text from public.mouvements_stock
           where id = 'aaaaaaaa-0000-0000-0013-000000000011'),
  '(ENTREE,ACHAT,RECEPTION,6.0000,Carton)', 'mouvement d''entrée avec l''identifiant fourni');
select throws_ok($$ insert into public.receptions (entreprise_id, achat_id, lignes)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0014-000000000001',
                            '[{"id":"aaaaaaaa-0000-0000-0013-000000000012","ligne_id":"aaaaaaaa-0000-0000-0015-000000000001","quantite":5}]') $$,
  'DGL01', 'RECEPTION_SUPERIEURE', 'impossible de recevoir plus que commandé');
select throws_ok($$ update public.achats set statut = 'ANNULE' where id = 'aaaaaaaa-0000-0000-0014-000000000001' $$,
  'DGL01', 'ACHAT_RECU', 'un achat déjà reçu ne s''annule pas');
select lives_ok($$ insert into public.receptions (entreprise_id, achat_id, lignes)
                   values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0014-000000000001',
                           '[{"id":"aaaaaaaa-0000-0000-0013-000000000013","ligne_id":"aaaaaaaa-0000-0000-0015-000000000001","quantite":4},
                             {"id":"aaaaaaaa-0000-0000-0013-000000000014","ligne_id":"aaaaaaaa-0000-0000-0015-000000000002","quantite":5}]') $$,
  'réception du reste');
select is((select statut from public.achats where id = 'aaaaaaaa-0000-0000-0014-000000000001'), 'RECU',
  'achat entièrement reçu');

-- ============================ Administrateur =============================
reset role;
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111101');
set local role authenticated;

select lives_ok($$ insert into public.transferts_stock (id, entreprise_id, produit_id, de_perimetre_id,
                                                        vers_perimetre_id, quantite, quantite_saisie, unite_saisie,
                                                        facteur, mouvement_entree_id)
                   values ('aaaaaaaa-0000-0000-0017-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'aaaaaaaa-0000-0000-0010-000000000001', 'aaaaaaaa-0000-0000-0001-000000000001',
                           'aaaaaaaa-0000-0000-0001-000000000002', 40, 10, 'Carton', 4,
                           'aaaaaaaa-0000-0000-0013-000000000021') $$,
  'administrateur : transfert de 10 cartons Centre → Marché');
select is((select array_agg(quantite order by perimetre_id)::text from public.stocks
           where produit_id = 'aaaaaaaa-0000-0000-0010-000000000001'),
  '{70.0000,40.0000}', 'un transfert = une sortie et une entrée (110 − 40, 0 + 40)');
select is((select count(*)::int from public.mouvements_stock where origine_id = 'aaaaaaaa-0000-0000-0017-000000000001'),
  2, 'deux mouvements liés au transfert');
select is((select count(*)::int from public.stocks where produit_id = 'aaaaaaaa-0000-0000-0010-000000000001'),
  2, 'administrateur : voit le stock de toutes les boutiques');

-- ================================ Vendeur ================================
reset role;
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111103');
set local role authenticated;

select is((select array_agg(perimetre_id)::text from public.stocks),
  '{aaaaaaaa-0000-0000-0001-000000000002}', 'vendeur : ne voit que le stock de sa boutique');
select is_empty($$ select 1 from public.achats $$, 'vendeur : aucun achat visible');
select throws_ok($$ insert into public.mouvements_stock (entreprise_id, perimetre_id, produit_id, type, motif,
                                                         quantite, quantite_saisie, unite_saisie)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0001-000000000002',
                            'aaaaaaaa-0000-0000-0010-000000000001', 'ENTREE', 'AUTRE', 1, 1, 'Pièce') $$,
  '42501', null, 'vendeur : pas d''entrée de stock');

-- Vente payée en espèces : 2 cartons à 1 200 (8 pièces).
select lives_ok($$ insert into public.ventes (id, entreprise_id, perimetre_id, lignes, reglement, mode_code, paiement_id)
                   values ('aaaaaaaa-0000-0000-0018-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'aaaaaaaa-0000-0000-0001-000000000002',
                           '[{"id":"aaaaaaaa-0000-0000-0013-000000000031","produit_id":"aaaaaaaa-0000-0000-0010-000000000001","unite":"Carton","facteur":4,"quantite":2,"prix_unitaire":1200}]',
                           'IMMEDIAT', 'ESPECES', 'aaaaaaaa-0000-0000-0006-000000000031') $$,
  'vendeur : vente payée');
select is((select quantite from public.stocks where perimetre_id = 'aaaaaaaa-0000-0000-0001-000000000002'),
  32.0000::numeric, 'stock Marché : 40 − 8 pièces');
select is((select (sens, origine_type, montant_total, montant_regle)::text from public.engagements
           where id = 'aaaaaaaa-0000-0000-0018-000000000001'),
  '(A_RECEVOIR,VENTE,2400,2400)', 'vente encaissée');
select is((select (sens, montant)::text from public.paiements where id = 'aaaaaaaa-0000-0000-0006-000000000031'),
  '(ENTREE,2400)', 'paiement créé avec l''identifiant fourni');
select throws_ok($$ insert into public.ventes (entreprise_id, perimetre_id, lignes, reglement)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0001-000000000002',
                            '[{"id":"aaaaaaaa-0000-0000-0013-000000000032","produit_id":"aaaaaaaa-0000-0000-0010-000000000001","unite":"Pièce","facteur":1,"quantite":1,"prix_unitaire":300}]',
                            'CREDIT') $$,
  'DGL01', 'CLIENT_REQUIS', 'vente à crédit : client obligatoire');
select throws_ok($$ insert into public.ventes (entreprise_id, perimetre_id, lignes, reglement, mode_code, paiement_id)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0001-000000000001',
                            '[{"id":"aaaaaaaa-0000-0000-0013-000000000033","produit_id":"aaaaaaaa-0000-0000-0010-000000000001","unite":"Pièce","facteur":1,"quantite":1,"prix_unitaire":300}]',
                            'IMMEDIAT', 'ESPECES', gen_random_uuid()) $$,
  '42501', null, 'vendeur : pas de vente dans une autre boutique');

-- Vente au comptoir enregistrée hors-ligne : acceptée même si le stock est dépassé.
select lives_ok($$ insert into public.ventes (entreprise_id, perimetre_id, lignes, reglement, mode_code, paiement_id)
                   values ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0001-000000000002',
                           '[{"id":"aaaaaaaa-0000-0000-0013-000000000034","produit_id":"aaaaaaaa-0000-0000-0010-000000000001","unite":"Pièce","facteur":1,"quantite":40,"prix_unitaire":300}]',
                           'IMMEDIAT', 'ESPECES', gen_random_uuid()) $$,
  'vente déjà faite : jamais refusée pour le stock');
select is((select quantite from public.stocks where perimetre_id = 'aaaaaaaa-0000-0000-0001-000000000002'),
  -8.0000::numeric, 'le stock devient négatif (à vérifier)');

select * from finish();
rollback;
