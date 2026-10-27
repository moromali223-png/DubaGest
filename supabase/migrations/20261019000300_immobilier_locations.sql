-- =============================================================================
-- IMMOBILIER — ÉTAPE 5 : GESTION DES LOCATIONS (OCCUPATION ET STATUTS)
--
-- Table des locations reliant un bien à un locataire sur une période donnée.
-- Suivi de l'occupation, loyer convenu, charges, dépôt de garantie et états des lieux.
-- =============================================================================

create table if not exists public.immobilier_locations (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  bien_id uuid not null references public.immobilier_biens (id) on delete restrict,
  locataire_id uuid not null references public.contacts (id) on delete restrict,
  contrat_id uuid,
  date_debut date not null,
  date_fin_prevue date,
  date_fin_reelle date,
  loyer_mensuel bigint not null default 0 check (loyer_mensuel >= 0),
  charges_mensuelles bigint not null default 0 check (charges_mensuelles >= 0),
  depot_garantie bigint not null default 0 check (depot_garantie >= 0),
  statut text not null default 'ACTIVE' check (statut in ('EN_ATTENTE', 'ACTIVE', 'RESILIEE', 'TERMINEE')),
  motif_cloture text check (char_length(motif_cloture) <= 500),
  etat_lieux_entree boolean not null default false,
  etat_lieux_sortie boolean not null default false,
  remarques text check (char_length(remarques) <= 2000),
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, entreprise_id)
);

create index if not exists immobilier_locations_sync_idx on public.immobilier_locations (entreprise_id, updated_at);
create index if not exists immobilier_locations_bien_idx on public.immobilier_locations (entreprise_id, bien_id);
create index if not exists immobilier_locations_locataire_idx on public.immobilier_locations (entreprise_id, locataire_id);
create index if not exists immobilier_locations_statut_idx on public.immobilier_locations (entreprise_id, statut);

-- Triggers de mise à jour des versions et des règles
create or replace function app.tg_immobilier_locations_regles()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.exiger(app.peut(new.entreprise_id, 'immobilier.locations',
                              case when tg_op = 'INSERT' then 'rentals.create' else 'rentals.update' end));
  return new;
end;
$$;

drop trigger if exists immobilier_locations_regles on public.immobilier_locations;
create trigger immobilier_locations_regles before insert or update on public.immobilier_locations
  for each row execute function app.tg_immobilier_locations_regles();

drop trigger if exists immobilier_locations_versionnement on public.immobilier_locations;
create trigger immobilier_locations_versionnement before insert or update on public.immobilier_locations
  for each row execute function app.tg_versionnement();

drop trigger if exists audit_immobilier_locations on public.immobilier_locations;
create trigger audit_immobilier_locations after insert or update or delete on public.immobilier_locations
  for each row execute function app.tg_audit();

-- RLS
alter table public.immobilier_locations enable row level security;

drop policy if exists immobilier_locations_lecture on public.immobilier_locations;
create policy immobilier_locations_lecture on public.immobilier_locations for select to authenticated
  using (app.peut(entreprise_id, 'immobilier.locations', 'rentals.view'));

drop policy if exists immobilier_locations_ajout on public.immobilier_locations;
create policy immobilier_locations_ajout on public.immobilier_locations for insert to authenticated
  with check (app.peut(entreprise_id, 'immobilier.locations', 'rentals.create'));

drop policy if exists immobilier_locations_modification on public.immobilier_locations;
create policy immobilier_locations_modification on public.immobilier_locations for update to authenticated
  using (app.peut(entreprise_id, 'immobilier.locations', 'rentals.update'))
  with check (app.peut(entreprise_id, 'immobilier.locations', 'rentals.update'));

drop policy if exists immobilier_locations_suppression on public.immobilier_locations;
create policy immobilier_locations_suppression on public.immobilier_locations for delete to authenticated
  using (app.peut(entreprise_id, 'immobilier.locations', 'rentals.delete'));

revoke all on public.immobilier_locations from anon, authenticated;
grant select on public.immobilier_locations to authenticated;
grant insert (id, entreprise_id, bien_id, locataire_id, contrat_id, date_debut, date_fin_prevue, date_fin_reelle, loyer_mensuel, charges_mensuelles, depot_garantie, statut, motif_cloture, etat_lieux_entree, etat_lieux_sortie, remarques)
  on public.immobilier_locations to authenticated;
grant update (bien_id, locataire_id, contrat_id, date_debut, date_fin_prevue, date_fin_reelle, loyer_mensuel, charges_mensuelles, depot_garantie, statut, motif_cloture, etat_lieux_entree, etat_lieux_sortie, remarques)
  on public.immobilier_locations to authenticated;
grant delete on public.immobilier_locations to authenticated;
grant all on public.immobilier_locations to service_role;
