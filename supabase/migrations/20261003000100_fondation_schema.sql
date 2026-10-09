-- =============================================================================
-- FONDATION V1 — SCHÉMA
-- Multi-tenant : toute donnée métier est rattachée à une entreprise.
-- Catalogues (plans, activités, rôles, permissions, modules) identifiés par un
-- code stable : ce sont des données de référence partagées par tous les tenants.
-- =============================================================================

-- Schéma interne non exposé par l'API (helpers, triggers, configuration).
create schema if not exists app;
revoke all on schema app from public;
grant usage on schema app to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- Triggers génériques
-- -----------------------------------------------------------------------------

-- Horodatage simple pour les tables de référence.
create or replace function app.tg_set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Versionnement optimiste pour les tables synchronisées hors-ligne :
-- la version est gérée exclusivement par le serveur (détection de conflits).
create or replace function app.tg_versionnement()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.version := 1;
    new.created_at := now();
  else
    new.version := old.version + 1;
    new.created_at := old.created_at;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- Catalogues de référence
-- -----------------------------------------------------------------------------

create table public.activites (
  code text primary key check (code ~ '^[A-Z][A-Z0-9_]*$'),
  libelle text not null,
  type_perimetre_defaut text not null,
  ordre smallint not null default 0,
  est_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.plans (
  code text primary key check (code ~ '^[A-Z][A-Z0-9_]*$'),
  nom text not null,
  description text,
  max_activites smallint not null check (max_activites > 0),
  ordre smallint not null default 0,
  est_actif boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Activités autorisées par un plan et limites propres à chaque activité.
-- La limite d'utilisateurs de l'entreprise = max des activités actives
-- (ex. MOYEN Commerce + Services → 7 ; Services + Immobilier → 1).
create table public.plan_activites (
  plan_code text not null references public.plans (code) on delete cascade,
  activite_code text not null references public.activites (code) on delete restrict,
  max_utilisateurs smallint not null check (max_utilisateurs > 0),
  max_perimetres smallint not null check (max_perimetres > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (plan_code, activite_code)
);

create table public.permissions (
  code text primary key check (code ~ '^[a-z][a-z_]*\.[a-z][a-z_]*$'),
  description text,
  created_at timestamptz not null default now()
);

-- activite_code NULL = rôle transverse à l'entreprise (ADMINISTRATEUR).
create table public.roles (
  code text primary key check (code ~ '^[A-Z][A-Z0-9_]*$'),
  libelle text not null,
  activite_code text references public.activites (code) on delete restrict,
  ordre smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.roles_permissions (
  role_code text not null references public.roles (code) on delete cascade,
  permission_code text not null references public.permissions (code) on delete cascade,
  primary key (role_code, permission_code)
);
create index roles_permissions_permission_idx on public.roles_permissions (permission_code);

-- Quotas de membres par rôle autorisés par un plan (organisation prévue).
create table public.plan_roles (
  plan_code text not null references public.plans (code) on delete cascade,
  role_code text not null references public.roles (code) on delete restrict,
  max_membres smallint not null check (max_membres > 0),
  primary key (plan_code, role_code)
);

-- activite_code NULL = module transverse (administration).
create table public.modules (
  code text primary key check (code ~ '^[a-z][a-z_]*\.[a-z][a-z_]*$'),
  libelle text not null,
  activite_code text references public.activites (code) on delete restrict,
  permission_acces text not null references public.permissions (code) on delete restrict,
  ordre smallint not null default 0,
  est_actif boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index modules_activite_idx on public.modules (activite_code);

create table public.plan_modules (
  plan_code text not null references public.plans (code) on delete cascade,
  module_code text not null references public.modules (code) on delete cascade,
  primary key (plan_code, module_code)
);

create trigger activites_updated_at before update on public.activites
  for each row execute function app.tg_set_updated_at();
create trigger plans_updated_at before update on public.plans
  for each row execute function app.tg_set_updated_at();
create trigger plan_activites_updated_at before update on public.plan_activites
  for each row execute function app.tg_set_updated_at();
create trigger roles_updated_at before update on public.roles
  for each row execute function app.tg_set_updated_at();
create trigger modules_updated_at before update on public.modules
  for each row execute function app.tg_set_updated_at();

-- -----------------------------------------------------------------------------
-- Identité : auth.users → profiles (aucun mot de passe ici)
-- -----------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nom_complet text check (char_length(nom_complet) <= 120),
  telephone text check (char_length(telephone) <= 30),
  langue text not null default 'fr' check (langue in ('fr', 'ar', 'en')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger profiles_updated_at before update on public.profiles
  for each row execute function app.tg_set_updated_at();

create or replace function app.tg_creer_profil()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, nom_complet, langue)
  values (
    new.id,
    nullif(trim(new.raw_user_meta_data ->> 'nom_complet'), ''),
    coalesce(nullif(new.raw_user_meta_data ->> 'langue', ''), 'fr')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function app.tg_creer_profil();

-- -----------------------------------------------------------------------------
-- Tenant : entreprises
-- -----------------------------------------------------------------------------

create table public.entreprises (
  id uuid primary key default gen_random_uuid(),
  nom text not null check (char_length(trim(nom)) between 2 and 120),
  statut text not null default 'ACTIVE' check (statut in ('ACTIVE', 'SUSPENDUE', 'ARCHIVEE')),
  pays text check (char_length(pays) = 2),
  devise text check (char_length(devise) = 3),
  langue_defaut text not null default 'fr' check (langue_defaut in ('fr', 'ar', 'en')),
  created_by uuid references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger entreprises_versionnement before insert or update on public.entreprises
  for each row execute function app.tg_versionnement();

create table public.entreprise_activites (
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  activite_code text not null references public.activites (code) on delete restrict,
  est_active boolean not null default true,
  activee_le timestamptz not null default now(),
  desactivee_le timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (entreprise_id, activite_code)
);

create trigger entreprise_activites_updated_at before update on public.entreprise_activites
  for each row execute function app.tg_set_updated_at();

-- Plan (formule) ≠ abonnement (utilisation de la formule par une entreprise).
-- Les lignes passées restent comme historique ; une seule ligne courante.
create table public.abonnements (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  plan_code text not null references public.plans (code) on delete restrict,
  statut text not null default 'ACTIF'
    check (statut in ('ESSAI', 'ACTIF', 'SUSPENDU', 'EXPIRE', 'ANNULE')),
  date_debut timestamptz not null default now(),
  date_fin timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (date_fin is null or date_fin > date_debut)
);

create unique index abonnements_un_courant_par_entreprise
  on public.abonnements (entreprise_id)
  where statut in ('ESSAI', 'ACTIF', 'SUSPENDU');
create index abonnements_entreprise_idx on public.abonnements (entreprise_id, date_debut desc);

create trigger abonnements_updated_at before update on public.abonnements
  for each row execute function app.tg_set_updated_at();

-- -----------------------------------------------------------------------------
-- Membres : utilisateur ↔ entreprise ↔ rôle
-- -----------------------------------------------------------------------------

create table public.membres_entreprise (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role_code text not null references public.roles (code) on delete restrict,
  statut text not null default 'ACTIF' check (statut in ('ACTIF', 'SUSPENDU')),
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (entreprise_id, user_id),
  unique (id, entreprise_id)
);
create index membres_entreprise_user_idx on public.membres_entreprise (user_id);
create index membres_entreprise_role_idx on public.membres_entreprise (entreprise_id, role_code);

create trigger membres_entreprise_versionnement before insert or update on public.membres_entreprise
  for each row execute function app.tg_versionnement();

-- -----------------------------------------------------------------------------
-- Périmètres opérationnels (boutique, agence, site…) — synchronisés hors-ligne
-- -----------------------------------------------------------------------------

create table public.perimetres (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  activite_code text not null,
  type text not null check (type in ('BOUTIQUE', 'AGENCE', 'SITE', 'UNITE')),
  nom text not null check (char_length(trim(nom)) between 1 and 120),
  code text check (char_length(code) <= 30),
  est_actif boolean not null default true,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id),
  -- Un périmètre ne peut exister que pour une activité de l'entreprise.
  foreign key (entreprise_id, activite_code)
    references public.entreprise_activites (entreprise_id, activite_code) on delete restrict
);
create unique index perimetres_nom_unique
  on public.perimetres (entreprise_id, lower(nom)) where deleted_at is null;
create index perimetres_sync_idx on public.perimetres (entreprise_id, updated_at);

create trigger perimetres_versionnement before insert or update on public.perimetres
  for each row execute function app.tg_versionnement();

-- Affectation membre ↔ périmètre. Les clés composites garantissent que
-- membre et périmètre appartiennent à la même entreprise.
create table public.membre_perimetres (
  entreprise_id uuid not null,
  membre_id uuid not null,
  perimetre_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (membre_id, perimetre_id),
  foreign key (membre_id, entreprise_id)
    references public.membres_entreprise (id, entreprise_id) on delete cascade,
  foreign key (perimetre_id, entreprise_id)
    references public.perimetres (id, entreprise_id) on delete cascade
);
create index membre_perimetres_perimetre_idx on public.membre_perimetres (perimetre_id);
create index membre_perimetres_entreprise_idx on public.membre_perimetres (entreprise_id);
