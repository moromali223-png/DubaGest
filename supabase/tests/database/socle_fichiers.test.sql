-- Socle commun — étape 8 : notes, pièces jointes, fichiers, rapports (pgTAP).
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(19);

create function pg_temp.en_tant_que(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;

-- Repères : Alpha aaaaaaaa-…-000000000001 ; contact Amadou …0003-000000000001 ;
-- créance (Boutique Marché) …0005-000000000001.

select is((select categorie from public.modules where code = 'commun.rapports'), 'COMMUN', 'module Rapports commun');
select is((select public from storage.buckets where id = 'fichiers'), false, 'bucket de fichiers privé');

-- ================================ Vendeur ================================
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111103');
set local role authenticated;

select lives_ok($$ insert into public.notes (id, entreprise_id, cible_type, cible_id, texte)
                   values ('aaaaaaaa-0000-0000-000c-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
                           'CONTACT', 'aaaaaaaa-0000-0000-0003-000000000001', 'Préfère être appelé le matin') $$,
  'vendeur : note sur un contact (contacts.update)');
select is((select auteur_nom from public.notes where id = 'aaaaaaaa-0000-0000-000c-000000000001'),
  'Fatou Keita', 'auteur copié par le serveur');
select throws_ok($$ insert into public.notes (entreprise_id, cible_type, cible_id, texte)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'ENGAGEMENT',
                            'aaaaaaaa-0000-0000-0005-000000000001', 'X') $$,
  '42501', null, 'vendeur : pas de note sur une créance (receivables.manage)');
select is((select count(*)::int from public.notes), 1, 'vendeur : voit ses notes de contact');
select throws_ok($$ insert into public.notes (entreprise_id, cible_type, cible_id, texte)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'CONTACT', gen_random_uuid(), 'X') $$,
  'DGL01', 'CIBLE_INVALIDE', 'fiche inexistante refusée');

select lives_ok($$ insert into storage.objects (bucket_id, name)
                   values ('fichiers', 'aaaaaaaa-0000-0000-0000-000000000001/pj/CONTACT/aaaaaaaa-0000-0000-0003-000000000001/piece.jpg') $$,
  'vendeur : fichier rangé sous le contact');
select lives_ok($$ insert into public.pieces_jointes (id, entreprise_id, cible_type, cible_id, chemin, nom_fichier, type_mime, taille)
                   values ('aaaaaaaa-0000-0000-000d-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'CONTACT',
                           'aaaaaaaa-0000-0000-0003-000000000001',
                           'aaaaaaaa-0000-0000-0000-000000000001/pj/CONTACT/aaaaaaaa-0000-0000-0003-000000000001/piece.jpg',
                           'carte.jpg', 'image/jpeg', 1200) $$,
  'vendeur : pièce jointe enregistrée');
select throws_ok($$ insert into public.pieces_jointes (entreprise_id, cible_type, cible_id, chemin, nom_fichier, type_mime, taille)
                    values ('aaaaaaaa-0000-0000-0000-000000000001', 'CONTACT', 'aaaaaaaa-0000-0000-0003-000000000001',
                            'bbbbbbbb-0000-0000-0000-000000000001/pj/x.jpg', 'x.jpg', 'image/jpeg', 10) $$,
  'DGL01', 'CHEMIN_INVALIDE', 'fichier hors de la fiche refusé');
select throws_ok($$ insert into storage.objects (bucket_id, name)
                    values ('fichiers', 'aaaaaaaa-0000-0000-0000-000000000001/logo/logo.png') $$,
  '42501', null, 'vendeur : logo réservé à l''administration');
select throws_ok($$ insert into storage.objects (bucket_id, name)
                    values ('fichiers', 'aaaaaaaa-0000-0000-0000-000000000001/pj/ENGAGEMENT/aaaaaaaa-0000-0000-0005-000000000001/x.pdf') $$,
  '42501', null, 'vendeur : pas de fichier sur une créance');

-- ============================== Superviseur ==============================
reset role;
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111102');
set local role authenticated;
-- La RLS masque la note des autres à la mise à jour : rien n'est modifié.
update public.notes set texte = 'Modifié' where id = 'aaaaaaaa-0000-0000-000c-000000000001';
select is((select texte from public.notes where id = 'aaaaaaaa-0000-0000-000c-000000000001'),
  'Préfère être appelé le matin', 'seul l''auteur modifie sa note');
select is((select count(*)::int from public.pieces_jointes), 1, 'superviseur : voit la pièce jointe du contact');

-- ============================ Administrateur ============================
reset role;
select pg_temp.en_tant_que('11111111-1111-1111-1111-111111111101');
set local role authenticated;
select lives_ok($$ insert into storage.objects (bucket_id, name)
                   values ('fichiers', 'aaaaaaaa-0000-0000-0000-000000000001/logo/logo.png') $$,
  'admin : logo de l''entreprise');
select lives_ok($$ update public.notes set deleted_at = now() where id = 'aaaaaaaa-0000-0000-000c-000000000001' $$,
  'admin : retire une note');
select ok(public.sync_push('00000000-0000-0000-0000-0000000000b1', 'pieces_jointes', 'DELETE',
            'aaaaaaaa-0000-0000-000d-000000000001', 1, '{}') ->> 'statut' = 'APPLIQUE',
  'sync : pièce jointe retirée hors-ligne');

-- ========================= Isolation entre entreprises =========================
reset role;
select pg_temp.en_tant_que('22222222-2222-2222-2222-222222222201');
set local role authenticated;
select is_empty($$ select 1 from storage.objects where bucket_id = 'fichiers' $$,
  'Beta : aucun fichier d''Alpha visible');
select is_empty($$ select 1 from public.notes union all select 1 from public.pieces_jointes $$,
  'Beta : ni notes ni pièces jointes d''Alpha');

select * from finish();
rollback;
