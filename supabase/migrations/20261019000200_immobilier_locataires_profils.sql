-- =============================================================================
-- IMMOBILIER — ÉTAPE 4 : DOSSIERS ET PROFILS LOCATAIRES
--
-- Table complémentaire pour les informations locatives d'un contact locataire :
-- pièce d'identité, garant / cautionnaire, contact d'urgence, situation pro,
-- et suivi financier locatif.
-- =============================================================================

create table if not exists public.immobilier_locataires_profils (
  contact_id uuid primary key references public.contacts (id) on delete cascade,
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  type_piece text default 'CNI' check (type_piece in ('CNI', 'PASSEPORT', 'PERMIS', 'CARTE_SEJOUR', 'RCCM', 'NIF', 'AUTRE')),
  numero_piece text check (char_length(numero_piece) <= 100),
  date_delivrance_piece date,
  profession text check (char_length(profession) <= 150),
  employeur text check (char_length(employeur) <= 150),
  revenu_mensuel_estime numeric(15,2) check (revenu_mensuel_estime is null or revenu_mensuel_estime >= 0),
  nom_garant text check (char_length(nom_garant) <= 150),
  telephone_garant text check (char_length(telephone_garant) <= 50),
  lien_garant text check (char_length(lien_garant) <= 100),
  adresse_garant text check (char_length(adresse_garant) <= 250),
  nom_urgence text check (char_length(nom_urgence) <= 150),
  telephone_urgence text check (char_length(telephone_urgence) <= 50),
  lien_urgence text check (char_length(lien_urgence) <= 100),
  notes_locatives text check (char_length(notes_locatives) <= 2000),
  statut_financier text not null default 'A_JOUR' check (statut_financier in ('A_JOUR', 'EN_RETARD', 'CONTENTIEUX')),
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (contact_id, entreprise_id)
);

create index if not exists immobilier_locataires_sync_idx on public.immobilier_locataires_profils (entreprise_id, updated_at);
create index if not exists immobilier_locataires_statut_idx on public.immobilier_locataires_profils (entreprise_id, statut_financier);

-- Triggers de mise à jour des versions et des règles
create or replace function app.tg_immobilier_locataires_regles()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.exiger(app.peut(new.entreprise_id, 'immobilier.locataires',
                              case when tg_op = 'INSERT' then 'tenants.create' else 'tenants.update' end));
  return new;
end;
$$;

drop trigger if exists immobilier_locataires_regles on public.immobilier_locataires_profils;
create trigger immobilier_locataires_regles before insert or update on public.immobilier_locataires_profils
  for each row execute function app.tg_immobilier_locataires_regles();

drop trigger if exists immobilier_locataires_versionnement on public.immobilier_locataires_profils;
create trigger immobilier_locataires_versionnement before insert or update on public.immobilier_locataires_profils
  for each row execute function app.tg_versionnement();

drop trigger if exists audit_immobilier_locataires on public.immobilier_locataires_profils;
create trigger audit_immobilier_locataires after insert or update or delete on public.immobilier_locataires_profils
  for each row execute function app.tg_audit();

-- RLS
alter table public.immobilier_locataires_profils enable row level security;

drop policy if exists immobilier_locataires_lecture on public.immobilier_locataires_profils;
create policy immobilier_locataires_lecture on public.immobilier_locataires_profils for select to authenticated
  using (app.peut(entreprise_id, 'immobilier.locataires', 'tenants.view'));

drop policy if exists immobilier_locataires_ajout on public.immobilier_locataires_profils;
create policy immobilier_locataires_ajout on public.immobilier_locataires_profils for insert to authenticated
  with check (app.peut(entreprise_id, 'immobilier.locataires', 'tenants.create'));

drop policy if exists immobilier_locataires_modification on public.immobilier_locataires_profils;
create policy immobilier_locataires_modification on public.immobilier_locataires_profils for update to authenticated
  using (app.peut(entreprise_id, 'immobilier.locataires', 'tenants.update'))
  with check (app.peut(entreprise_id, 'immobilier.locataires', 'tenants.update'));

drop policy if exists immobilier_locataires_suppression on public.immobilier_locataires_profils;
create policy immobilier_locataires_suppression on public.immobilier_locataires_profils for delete to authenticated
  using (app.peut(entreprise_id, 'immobilier.locataires', 'tenants.delete'));

revoke all on public.immobilier_locataires_profils from anon, authenticated;
grant select on public.immobilier_locataires_profils to authenticated;
grant insert (contact_id, entreprise_id, type_piece, numero_piece, date_delivrance_piece, profession, employeur, revenu_mensuel_estime, nom_garant, telephone_garant, lien_garant, adresse_garant, nom_urgence, telephone_urgence, lien_urgence, notes_locatives, statut_financier)
  on public.immobilier_locataires_profils to authenticated;
grant update (type_piece, numero_piece, date_delivrance_piece, profession, employeur, revenu_mensuel_estime, nom_garant, telephone_garant, lien_garant, adresse_garant, nom_urgence, telephone_urgence, lien_urgence, notes_locatives, statut_financier)
  on public.immobilier_locataires_profils to authenticated;
grant delete on public.immobilier_locataires_profils to authenticated;
grant all on public.immobilier_locataires_profils to service_role;
