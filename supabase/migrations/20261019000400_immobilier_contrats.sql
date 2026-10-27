-- =============================================================================
-- IMMOBILIER — ÉTAPE 6 : CONTRATS DE BAIL & SÉCURISATION JURIDIQUE
--
-- Table des contrats de bail formalisant l'accord juridique et financier
-- entre le bailleur et le locataire (termes, dépôt de garantie, signatures, document).
-- =============================================================================

create table if not exists public.immobilier_contrats (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  reference text not null,
  bien_id uuid not null references public.immobilier_biens (id) on delete restrict,
  proprietaire_id uuid not null references public.contacts (id) on delete restrict,
  locataire_id uuid not null references public.contacts (id) on delete restrict,
  location_id uuid references public.immobilier_locations (id) on delete set null,
  document_id uuid references public.documents (id) on delete set null,
  type_bail text not null default 'HABITATION_NUE' check (type_bail in ('HABITATION_NUE', 'HABITATION_MEUBLEE', 'COMMERCIAL', 'PROFESSIONNEL', 'SAISONNIER', 'PRECAIRE')),
  statut text not null default 'BROUILLON' check (statut in ('BROUILLON', 'ACTIF', 'EN_PREAVIS', 'TERMINE', 'RESILIE')),
  date_debut date not null,
  date_fin_prevue date,
  date_fin_reelle date,
  reconduction_tacite boolean not null default true,
  preavis_mois integer not null default 1 check (preavis_mois >= 0),
  loyer_mensuel bigint not null default 0 check (loyer_mensuel >= 0),
  charges_mensuelles bigint not null default 0 check (charges_mensuelles >= 0),
  terme_paiement_jour integer not null default 5 check (terme_paiement_jour between 1 and 31),
  terme_type text not null default 'A_ECHOIR' check (terme_type in ('A_ECHOIR', 'ECHU')),
  depot_garantie bigint not null default 0 check (depot_garantie >= 0),
  penalite_retard_pourcent numeric(5,2) check (penalite_retard_pourcent >= 0),
  clauses_particulieres text check (char_length(clauses_particulieres) <= 5000),
  date_signature date,
  signe_par_bailleur boolean not null default false,
  signe_par_locataire boolean not null default false,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, entreprise_id),
  unique (reference, entreprise_id)
);

create index if not exists immobilier_contrats_sync_idx on public.immobilier_contrats (entreprise_id, updated_at);
create index if not exists immobilier_contrats_bien_idx on public.immobilier_contrats (entreprise_id, bien_id);
create index if not exists immobilier_contrats_proprietaire_idx on public.immobilier_contrats (entreprise_id, proprietaire_id);
create index if not exists immobilier_contrats_locataire_idx on public.immobilier_contrats (entreprise_id, locataire_id);
create index if not exists immobilier_contrats_statut_idx on public.immobilier_contrats (entreprise_id, statut);

-- Triggers de mise à jour des versions et des règles
create or replace function app.tg_immobilier_contrats_regles()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.exiger(app.peut(new.entreprise_id, 'immobilier.contrats',
                              case when tg_op = 'INSERT' then 'contracts.create' else 'contracts.update' end));
  return new;
end;
$$;

drop trigger if exists immobilier_contrats_regles on public.immobilier_contrats;
create trigger immobilier_contrats_regles before insert or update on public.immobilier_contrats
  for each row execute function app.tg_immobilier_contrats_regles();

drop trigger if exists immobilier_contrats_versionnement on public.immobilier_contrats;
create trigger immobilier_contrats_versionnement before insert or update on public.immobilier_contrats
  for each row execute function app.tg_versionnement();

drop trigger if exists audit_immobilier_contrats on public.immobilier_contrats;
create trigger audit_immobilier_contrats after insert or update or delete on public.immobilier_contrats
  for each row execute function app.tg_audit();

-- RLS
alter table public.immobilier_contrats enable row level security;

drop policy if exists immobilier_contrats_lecture on public.immobilier_contrats;
create policy immobilier_contrats_lecture on public.immobilier_contrats for select to authenticated
  using (app.peut(entreprise_id, 'immobilier.contrats', 'contracts.view'));

drop policy if exists immobilier_contrats_ajout on public.immobilier_contrats;
create policy immobilier_contrats_ajout on public.immobilier_contrats for insert to authenticated
  with check (app.peut(entreprise_id, 'immobilier.contrats', 'contracts.create'));

drop policy if exists immobilier_contrats_modification on public.immobilier_contrats;
create policy immobilier_contrats_modification on public.immobilier_contrats for update to authenticated
  using (app.peut(entreprise_id, 'immobilier.contrats', 'contracts.update'))
  with check (app.peut(entreprise_id, 'immobilier.contrats', 'contracts.update'));

drop policy if exists immobilier_contrats_suppression on public.immobilier_contrats;
create policy immobilier_contrats_suppression on public.immobilier_contrats for delete to authenticated
  using (app.peut(entreprise_id, 'immobilier.contrats', 'contracts.delete'));

revoke all on public.immobilier_contrats from anon, authenticated;
grant select on public.immobilier_contrats to authenticated;
grant insert (id, entreprise_id, reference, bien_id, proprietaire_id, locataire_id, location_id, document_id, type_bail, statut, date_debut, date_fin_prevue, date_fin_reelle, reconduction_tacite, preavis_mois, loyer_mensuel, charges_mensuelles, terme_paiement_jour, terme_type, depot_garantie, penalite_retard_pourcent, clauses_particulieres, date_signature, signe_par_bailleur, signe_par_locataire)
  on public.immobilier_contrats to authenticated;
grant update (bien_id, proprietaire_id, locataire_id, location_id, document_id, type_bail, statut, date_debut, date_fin_prevue, date_fin_reelle, reconduction_tacite, preavis_mois, loyer_mensuel, charges_mensuelles, terme_paiement_jour, terme_type, depot_garantie, penalite_retard_pourcent, clauses_particulieres, date_signature, signe_par_bailleur, signe_par_locataire)
  on public.immobilier_contrats to authenticated;
grant delete on public.immobilier_contrats to authenticated;
grant all on public.immobilier_contrats to service_role;
