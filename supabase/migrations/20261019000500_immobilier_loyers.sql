-- =============================================================================
-- IMMOBILIER — ÉTAPE 7 : GESTION DES LOYERS ET ENCAISSEMENTS
--
-- Table des échéances de loyers mensuelles (appels de loyer).
-- Règle d'idempotence stricte : un seul appel de loyer par contrat pour un mois donné.
-- Relié au module comptable transversal via engagement_id.
-- =============================================================================

create table if not exists public.immobilier_echeances_loyers (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  reference text not null,
  contrat_id uuid not null references public.immobilier_contrats (id) on delete restrict,
  bien_id uuid not null references public.immobilier_biens (id) on delete restrict,
  locataire_id uuid not null references public.contacts (id) on delete restrict,
  proprietaire_id uuid references public.contacts (id) on delete restrict,
  engagement_id uuid not null references public.engagements (id) on delete restrict,
  periode_mois integer not null check (periode_mois between 1 and 12),
  periode_annee integer not null check (periode_annee between 2000 and 2100),
  date_emission date not null,
  date_exigibilite date not null,
  loyer_net bigint not null default 0 check (loyer_net >= 0),
  charges bigint not null default 0 check (charges >= 0),
  total_du bigint not null default 0 check (total_du >= 0),
  montant_regle bigint not null default 0 check (montant_regle >= 0),
  statut text not null default 'A_PAYER' check (statut in ('A_PAYER', 'PARTIEL', 'SOLDE', 'EN_RETARD', 'ANNULE')),
  quittance_document_id uuid references public.documents (id) on delete set null,
  recu_document_ids jsonb not null default '[]'::jsonb,
  derniere_date_paiement timestamptz,
  remarques text check (char_length(remarques) <= 2000),
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, entreprise_id),
  unique (reference, entreprise_id),
  unique (contrat_id, periode_annee, periode_mois)
);

create index if not exists immobilier_echeances_sync_idx on public.immobilier_echeances_loyers (entreprise_id, updated_at);
create index if not exists immobilier_echeances_contrat_idx on public.immobilier_echeances_loyers (entreprise_id, contrat_id);
create index if not exists immobilier_echeances_locataire_idx on public.immobilier_echeances_loyers (entreprise_id, locataire_id);
create index if not exists immobilier_echeances_bien_idx on public.immobilier_echeances_loyers (entreprise_id, bien_id);
create index if not exists immobilier_echeances_periode_idx on public.immobilier_echeances_loyers (entreprise_id, periode_annee, periode_mois);
create index if not exists immobilier_echeances_statut_idx on public.immobilier_echeances_loyers (entreprise_id, statut);

-- Triggers de mise à jour des versions et des règles
create or replace function app.tg_immobilier_loyers_regles()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.exiger(app.peut(new.entreprise_id, 'immobilier.loyers',
                              case when tg_op = 'INSERT' then 'rents.create' else 'rents.update' end));
  return new;
end;
$$;

drop trigger if exists immobilier_loyers_regles on public.immobilier_echeances_loyers;
create trigger immobilier_loyers_regles before insert or update on public.immobilier_echeances_loyers
  for each row execute function app.tg_immobilier_loyers_regles();

drop trigger if exists immobilier_loyers_versionnement on public.immobilier_echeances_loyers;
create trigger immobilier_loyers_versionnement before insert or update on public.immobilier_echeances_loyers
  for each row execute function app.tg_versionnement();

drop trigger if exists audit_immobilier_loyers on public.immobilier_echeances_loyers;
create trigger audit_immobilier_loyers after insert or update or delete on public.immobilier_echeances_loyers
  for each row execute function app.tg_audit();

-- RLS
alter table public.immobilier_echeances_loyers enable row level security;

drop policy if exists immobilier_loyers_lecture on public.immobilier_echeances_loyers;
create policy immobilier_loyers_lecture on public.immobilier_echeances_loyers for select to authenticated
  using (app.peut(entreprise_id, 'immobilier.loyers', 'rents.view'));

drop policy if exists immobilier_loyers_ajout on public.immobilier_echeances_loyers;
create policy immobilier_loyers_ajout on public.immobilier_echeances_loyers for insert to authenticated
  with check (app.peut(entreprise_id, 'immobilier.loyers', 'rents.create'));

drop policy if exists immobilier_loyers_modification on public.immobilier_echeances_loyers;
create policy immobilier_loyers_modification on public.immobilier_echeances_loyers for update to authenticated
  using (app.peut(entreprise_id, 'immobilier.loyers', 'rents.update'))
  with check (app.peut(entreprise_id, 'immobilier.loyers', 'rents.update'));

drop policy if exists immobilier_loyers_suppression on public.immobilier_echeances_loyers;
create policy immobilier_loyers_suppression on public.immobilier_echeances_loyers for delete to authenticated
  using (app.peut(entreprise_id, 'immobilier.loyers', 'rents.delete'));

revoke all on public.immobilier_echeances_loyers from anon, authenticated;
grant select on public.immobilier_echeances_loyers to authenticated;
grant insert (id, entreprise_id, reference, contrat_id, bien_id, locataire_id, proprietaire_id, engagement_id, periode_mois, periode_annee, date_emission, date_exigibilite, loyer_net, charges, total_du, montant_regle, statut, quittance_document_id, recu_document_ids, derniere_date_paiement, remarques)
  on public.immobilier_echeances_loyers to authenticated;
grant update (loyer_net, charges, total_du, montant_regle, statut, quittance_document_id, recu_document_ids, derniere_date_paiement, remarques)
  on public.immobilier_echeances_loyers to authenticated;
grant delete on public.immobilier_echeances_loyers to authenticated;
grant all on public.immobilier_echeances_loyers to service_role;
