-- =============================================================================
-- IMMOBILIER — ÉTAPE 3 : BIENS IMMOBILIERS
--
-- Table de gestion des biens (appartements, villas, magasins, bureaux, terrains).
-- Sécurisée par RLS multi-entreprises, versionnée pour la synchronisation
-- descendante, et tracée dans le journal d'audit.
-- =============================================================================

create table if not exists public.immobilier_biens (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  reference text not null check (char_length(trim(reference)) between 1 and 50),
  nom text not null check (char_length(trim(nom)) between 1 and 150),
  description text check (char_length(description) <= 1000),
  type text not null default 'APPARTEMENT' check (type in ('APPARTEMENT', 'MAISON', 'CHAMBRE', 'MAGASIN', 'BUREAU', 'ENTREPOT', 'TERRAIN', 'AUTRE')),
  statut text not null default 'DISPONIBLE' check (statut in ('DISPONIBLE', 'RESERVE', 'OCCUPE', 'EN_TRAVAUX', 'ARCHIVE')),
  proprietaire_id uuid not null references public.contacts (id) on delete restrict,
  loyer_reference bigint not null default 0 check (loyer_reference >= 0),
  periodicite text not null default 'MENSUELLE' check (periodicite in ('MENSUELLE', 'TRIMESTRIELLE', 'SEMESTRIELLE', 'ANNUELLE', 'PONCTUELLE')),
  depot_garantie_prevu bigint not null default 0 check (depot_garantie_prevu >= 0),
  adresse text check (char_length(adresse) <= 250),
  ville text check (char_length(ville) <= 100),
  quartier text check (char_length(quartier) <= 100),
  complement_adresse text check (char_length(complement_adresse) <= 250),
  photos jsonb not null default '[]'::jsonb,
  caracteristiques jsonb not null default '{}'::jsonb,
  notes text check (char_length(notes) <= 1000),
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id),
  unique (entreprise_id, reference)
);

create index if not exists immobilier_biens_sync_idx on public.immobilier_biens (entreprise_id, updated_at);
create index if not exists immobilier_biens_proprio_idx on public.immobilier_biens (entreprise_id, proprietaire_id);
create index if not exists immobilier_biens_statut_idx on public.immobilier_biens (entreprise_id, statut);

create or replace function app.tg_immobilier_biens_regles()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.exiger(app.peut(new.entreprise_id, 'immobilier.biens',
                              case when tg_op = 'INSERT' then 'properties.create' else 'properties.update' end));
  if tg_op = 'INSERT' then
    new.created_by := coalesce(auth.uid(), new.created_by);
  end if;
  return new;
end;
$$;

drop trigger if exists immobilier_biens_regles on public.immobilier_biens;
create trigger immobilier_biens_regles before insert or update on public.immobilier_biens
  for each row execute function app.tg_immobilier_biens_regles();

drop trigger if exists immobilier_biens_versionnement on public.immobilier_biens;
create trigger immobilier_biens_versionnement before insert or update on public.immobilier_biens
  for each row execute function app.tg_versionnement();

drop trigger if exists audit_immobilier_biens on public.immobilier_biens;
create trigger audit_immobilier_biens after insert or update or delete on public.immobilier_biens
  for each row execute function app.tg_audit();

alter table public.immobilier_biens enable row level security;

drop policy if exists immobilier_biens_lecture on public.immobilier_biens;
create policy immobilier_biens_lecture on public.immobilier_biens for select to authenticated
  using (app.peut(entreprise_id, 'immobilier.biens', 'properties.view'));

drop policy if exists immobilier_biens_ajout on public.immobilier_biens;
create policy immobilier_biens_ajout on public.immobilier_biens for insert to authenticated
  with check (app.peut(entreprise_id, 'immobilier.biens', 'properties.create'));

drop policy if exists immobilier_biens_modification on public.immobilier_biens;
create policy immobilier_biens_modification on public.immobilier_biens for update to authenticated
  using (app.peut(entreprise_id, 'immobilier.biens', 'properties.update'))
  with check (app.peut(entreprise_id, 'immobilier.biens', 'properties.update'));

revoke all on public.immobilier_biens from anon, authenticated;
grant select on public.immobilier_biens to authenticated;
grant insert (id, entreprise_id, reference, nom, description, type, statut, proprietaire_id, loyer_reference, periodicite, depot_garantie_prevu, adresse, ville, quartier, complement_adresse, photos, caracteristiques, notes)
  on public.immobilier_biens to authenticated;
grant update (reference, nom, description, type, statut, proprietaire_id, loyer_reference, periodicite, depot_garantie_prevu, adresse, ville, quartier, complement_adresse, photos, caracteristiques, notes, deleted_at)
  on public.immobilier_biens to authenticated;
grant all on public.immobilier_biens to service_role;
