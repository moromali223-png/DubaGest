-- =============================================================================
-- DONNÉES DE DÉMO (développement local uniquement)
-- Mot de passe de tous les comptes : Password123!
--
--   Alpha Distribution — plan MOYEN — COMMERCE + SERVICES
--     admin@alpha.test        ADMINISTRATEUR (tous périmètres)
--     superviseur@alpha.test  SUPERVISEUR → Boutique Centre
--     vendeur@alpha.test      VENDEUR     → Boutique Marché
--   Beta Immobilier — plan NORMAL — IMMOBILIER
--     admin@beta.test         ADMINISTRATEUR
-- =============================================================================

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  email_change_token_current, phone_change, phone_change_token, reauthentication_token
)
select
  '00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated', u.email,
  extensions.crypt('Password123!', extensions.gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  jsonb_build_object('nom_complet', u.nom), now(), now(),
  '', '', '', '', '', '', '', ''
from (values
  ('11111111-1111-1111-1111-111111111101'::uuid, 'admin@alpha.test',       'Awa Diallo'),
  ('11111111-1111-1111-1111-111111111102'::uuid, 'superviseur@alpha.test', 'Moussa Traoré'),
  ('11111111-1111-1111-1111-111111111103'::uuid, 'vendeur@alpha.test',     'Fatou Keita'),
  ('22222222-2222-2222-2222-222222222201'::uuid, 'admin@beta.test',        'Karim Benali')
) as u(id, email, nom);

insert into auth.identities (
  id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
)
select gen_random_uuid(), u.id, u.id::text,
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
       'email', now(), now(), now()
from auth.users u
where u.email like '%.test';

-- Entreprises
insert into public.entreprises (id, nom, pays, devise, created_by) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Alpha Distribution', 'ML', 'XOF',
   '11111111-1111-1111-1111-111111111101'),
  ('bbbbbbbb-0000-0000-0000-000000000001', 'Beta Immobilier', 'MA', 'MAD',
   '22222222-2222-2222-2222-222222222201');

insert into public.abonnements (entreprise_id, plan_code, statut) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'MOYEN',  'ACTIF'),
  ('bbbbbbbb-0000-0000-0000-000000000001', 'NORMAL', 'ACTIF');

insert into public.entreprise_activites (entreprise_id, activite_code) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'COMMERCE'),
  ('aaaaaaaa-0000-0000-0000-000000000001', 'SERVICES'),
  ('bbbbbbbb-0000-0000-0000-000000000001', 'IMMOBILIER');

insert into public.perimetres (id, entreprise_id, activite_code, type, nom, code) values
  ('aaaaaaaa-0000-0000-0001-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
   'COMMERCE', 'BOUTIQUE', 'Boutique Centre', 'BC'),
  ('aaaaaaaa-0000-0000-0001-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001',
   'COMMERCE', 'BOUTIQUE', 'Boutique Marché', 'BM'),
  ('aaaaaaaa-0000-0000-0001-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001',
   'SERVICES', 'AGENCE', 'Agence principale', 'AP'),
  ('bbbbbbbb-0000-0000-0001-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001',
   'IMMOBILIER', 'AGENCE', 'Agence Beta', 'AB');

insert into public.membres_entreprise (id, entreprise_id, user_id, role_code) values
  ('aaaaaaaa-0000-0000-0002-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111101', 'ADMINISTRATEUR'),
  ('aaaaaaaa-0000-0000-0002-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111102', 'SUPERVISEUR'),
  ('aaaaaaaa-0000-0000-0002-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111103', 'VENDEUR'),
  ('bbbbbbbb-0000-0000-0002-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222201', 'ADMINISTRATEUR');

-- Contacts de démo : une même personne peut avoir plusieurs relations.
insert into public.contacts (id, entreprise_id, nom, prenom, telephone, whatsapp, ville, relations) values
  ('aaaaaaaa-0000-0000-0003-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
   'Traoré', 'Amadou', '+223 70 11 22 33', '+223 70 11 22 33', 'Bamako', '{CLIENT,FOURNISSEUR}'),
  ('aaaaaaaa-0000-0000-0003-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001',
   'Sow', 'Mariam', '+223 76 44 55 66', null, 'Bamako', '{CLIENT}');

-- Finances : une caisse par boutique, une créance ouverte (aucun paiement).
insert into public.caisses (id, entreprise_id, perimetre_id, nom) values
  ('aaaaaaaa-0000-0000-0004-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
   'aaaaaaaa-0000-0000-0001-000000000001', 'Caisse Centre'),
  ('aaaaaaaa-0000-0000-0004-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001',
   'aaaaaaaa-0000-0000-0001-000000000002', 'Caisse Marché');

insert into public.engagements (id, entreprise_id, perimetre_id, sens, contact_id, libelle,
                                montant_total, echeance) values
  ('aaaaaaaa-0000-0000-0005-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
   'aaaaaaaa-0000-0000-0001-000000000002', 'A_RECEVOIR', 'aaaaaaaa-0000-0000-0003-000000000001',
   'Marchandises livrées à crédit', 50000, current_date + 30);

insert into public.membre_perimetres (entreprise_id, membre_id, perimetre_id) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0002-000000000002',
   'aaaaaaaa-0000-0000-0001-000000000001'),
  ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0002-000000000003',
   'aaaaaaaa-0000-0000-0001-000000000002');
