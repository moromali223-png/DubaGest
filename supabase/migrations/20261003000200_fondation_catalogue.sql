-- =============================================================================
-- FONDATION V1 — CATALOGUE DE RÉFÉRENCE
-- Données nécessaires en production (et non des données de démo).
-- Les règles FAIBLE / MOYEN sont ici : aucune limite n'est codée en dur ailleurs.
-- =============================================================================

insert into public.activites (code, libelle, type_perimetre_defaut, ordre) values
  ('COMMERCE',   'Commerce',   'BOUTIQUE', 1),
  ('SERVICES',   'Services',   'AGENCE',   2),
  ('IMMOBILIER', 'Immobilier', 'AGENCE',   3);

-- FAIBLE : une seule activité. MOYEN : deux activités (jamais les trois).
insert into public.plans (code, nom, description, max_activites, ordre) values
  ('FAIBLE', 'Faible', 'Une activité, petite équipe.', 1, 1),
  ('MOYEN',  'Moyen',  'Deux activités combinables, jusqu''à 2 boutiques.', 2, 2);

insert into public.plan_activites (plan_code, activite_code, max_utilisateurs, max_perimetres) values
  ('FAIBLE', 'COMMERCE',   3, 1),
  ('FAIBLE', 'SERVICES',   1, 1),
  ('FAIBLE', 'IMMOBILIER', 1, 1),
  ('MOYEN',  'COMMERCE',   7, 2),
  ('MOYEN',  'SERVICES',   1, 1),
  ('MOYEN',  'IMMOBILIER', 1, 1);

-- -----------------------------------------------------------------------------
-- Permissions : <ressource>.<action>
-- -----------------------------------------------------------------------------

insert into public.permissions (code, description)
select r || '.' || a, null
from (values
  -- Administration
  ('entreprise', array['view', 'manage']),
  ('users',      array['view', 'manage']),
  ('perimetres', array['view', 'manage', 'access_all']),
  ('subscription', array['view']),
  -- Commerce
  ('products',   array['view', 'create', 'update', 'delete']),
  ('stock',      array['view', 'create', 'update']),
  ('sales',      array['view', 'create', 'update', 'delete']),
  ('purchases',  array['view', 'create', 'update', 'delete']),
  ('customers',  array['view', 'create', 'update', 'delete']),
  ('suppliers',  array['view', 'create', 'update', 'delete']),
  ('cash',       array['view', 'create', 'update']),
  -- Services
  ('services',   array['view', 'create', 'update', 'delete']),
  ('prestations', array['view', 'create', 'update', 'delete']),
  ('quotes',     array['view', 'create', 'update', 'delete']),
  ('invoices',   array['view', 'create', 'update', 'delete']),
  -- Immobilier
  ('properties', array['view', 'create', 'update', 'delete']),
  ('owners',     array['view', 'create', 'update', 'delete']),
  ('tenants',    array['view', 'create', 'update', 'delete']),
  ('rentals',    array['view', 'create', 'update', 'delete']),
  ('contracts',  array['view', 'create', 'update', 'delete']),
  ('rents',      array['view', 'create', 'update', 'delete'])
) as p(r, actions), unnest(p.actions) as a;

-- -----------------------------------------------------------------------------
-- Rôles V1 (aucun rôle supplémentaire pour Services / Immobilier)
-- -----------------------------------------------------------------------------

insert into public.roles (code, libelle, activite_code, ordre) values
  ('ADMINISTRATEUR',     'Administrateur',     null,       1),
  ('SUPERVISEUR',        'Superviseur',        'COMMERCE', 2),
  ('GESTIONNAIRE_STOCK', 'Gestionnaire stock', 'COMMERCE', 3),
  ('VENDEUR',            'Vendeur',            'COMMERCE', 4);

-- L'administrateur possède toutes les permissions.
insert into public.roles_permissions (role_code, permission_code)
select 'ADMINISTRATEUR', code from public.permissions;

insert into public.roles_permissions (role_code, permission_code)
select 'SUPERVISEUR', unnest(array[
  'entreprise.view', 'users.view', 'perimetres.view',
  'products.view', 'products.create', 'products.update',
  'stock.view', 'stock.create', 'stock.update',
  'sales.view', 'sales.create', 'sales.update',
  'purchases.view', 'purchases.create', 'purchases.update',
  'customers.view', 'customers.create', 'customers.update',
  'suppliers.view', 'suppliers.create', 'suppliers.update',
  'cash.view', 'cash.create', 'cash.update'
]);

insert into public.roles_permissions (role_code, permission_code)
select 'GESTIONNAIRE_STOCK', unnest(array[
  'perimetres.view',
  'products.view', 'products.create', 'products.update',
  'stock.view', 'stock.create', 'stock.update',
  'purchases.view', 'purchases.create', 'purchases.update',
  'suppliers.view', 'suppliers.create', 'suppliers.update'
]);

insert into public.roles_permissions (role_code, permission_code)
select 'VENDEUR', unnest(array[
  'perimetres.view',
  'products.view', 'stock.view',
  'sales.view', 'sales.create',
  'customers.view', 'customers.create', 'customers.update',
  'cash.view', 'cash.create'
]);

-- Organisation prévue par plan (le total = max_utilisateurs Commerce).
insert into public.plan_roles (plan_code, role_code, max_membres) values
  ('FAIBLE', 'ADMINISTRATEUR',     1),
  ('FAIBLE', 'GESTIONNAIRE_STOCK', 1),
  ('FAIBLE', 'VENDEUR',            1),
  ('MOYEN',  'ADMINISTRATEUR',     1),
  ('MOYEN',  'SUPERVISEUR',        2),
  ('MOYEN',  'GESTIONNAIRE_STOCK', 2),
  ('MOYEN',  'VENDEUR',            2);

-- -----------------------------------------------------------------------------
-- Modules (moteur seulement : aucune fonctionnalité métier développée ici)
-- -----------------------------------------------------------------------------

insert into public.modules (code, libelle, activite_code, permission_acces, ordre) values
  ('admin.entreprise',     'Entreprise',    null, 'entreprise.view',   1),
  ('admin.utilisateurs',   'Utilisateurs',  null, 'users.view',        2),
  ('admin.perimetres',     'Périmètres',    null, 'perimetres.view',   3),
  ('admin.abonnement',     'Abonnement',    null, 'subscription.view', 4),

  ('commerce.produits',     'Produits',     'COMMERCE', 'products.view',  10),
  ('commerce.stock',        'Stock',        'COMMERCE', 'stock.view',     11),
  ('commerce.ventes',       'Ventes',       'COMMERCE', 'sales.view',     12),
  ('commerce.achats',       'Achats',       'COMMERCE', 'purchases.view', 13),
  ('commerce.clients',      'Clients',      'COMMERCE', 'customers.view', 14),
  ('commerce.fournisseurs', 'Fournisseurs', 'COMMERCE', 'suppliers.view', 15),
  ('commerce.caisse',       'Caisse',       'COMMERCE', 'cash.view',      16),

  ('services.services',    'Services',    'SERVICES', 'services.view',    20),
  ('services.clients',     'Clients',     'SERVICES', 'customers.view',   21),
  ('services.prestations', 'Prestations', 'SERVICES', 'prestations.view', 22),
  ('services.devis',       'Devis',       'SERVICES', 'quotes.view',      23),
  ('services.facturation', 'Facturation', 'SERVICES', 'invoices.view',    24),

  ('immobilier.biens',         'Biens',         'IMMOBILIER', 'properties.view', 30),
  ('immobilier.proprietaires', 'Propriétaires', 'IMMOBILIER', 'owners.view',     31),
  ('immobilier.locataires',    'Locataires',    'IMMOBILIER', 'tenants.view',    32),
  ('immobilier.locations',     'Locations',     'IMMOBILIER', 'rentals.view',    33),
  ('immobilier.contrats',      'Contrats',      'IMMOBILIER', 'contracts.view',  34),
  ('immobilier.loyers',        'Loyers',        'IMMOBILIER', 'rents.view',      35);

-- V1 : les deux plans incluent tous les modules ; la différenciation se fait
-- sur les activités et les limites. Ajuster ici sans toucher au code.
insert into public.plan_modules (plan_code, module_code)
select p.code, m.code from public.plans p cross join public.modules m;
