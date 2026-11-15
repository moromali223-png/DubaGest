-- =============================================================================
-- MIGRATION : Intégration du Module Professionnel DUBAGEST MICROFINANCE
-- Version : 20261114000100_microfinance_fondation.sql
-- Description :
--   1. Déclaration officielle du module 'commerce.microfinance' dans public.modules
--   2. Verrouillage strict d'accès par abonnement :
--      - Formule NORMAL / FAIBLE (1 000 FCFA) : ACCÈS INTERDIT
--      - Formule MOYEN (2 000 FCFA)           : ACCÈS INTERDIT
--      - Formule PRO (5 000 FCFA)             : ACCÈS AUTORISÉ (si abonnement actif)
--   3. Création des 8 tables métier Microfinance multi-tenant (entreprise_id) :
--      - public.microfinance_accounts     (Comptes & Caisses de trésorerie)
--      - public.microfinance_funds        (Apports capital, retraits, dépenses, transferts)
--      - public.microfinance_borrowers    (Emprunteurs liés optionnellement à contacts)
--      - public.microfinance_loans        (Prêts : Pourcentage fixe, Montant fixe, Dégressif)
--      - public.microfinance_installments (Échéanciers : Quotidienne, Hebdomadaire, Mensuelle)
--      - public.microfinance_repayments   (Remboursements : ventilation Capital / Intérêts)
--      - public.microfinance_transactions (Grand-livre financier central immuable)
--      - public.microfinance_audit_logs   (Journal d'audit complet des opérations)
--   4. Triggers d'intégrité comptable, RLS stricte et synchronisation Offline-First
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Permissions & Catalogue du module Microfinance (Exclusivité Formule PRO)
-- -----------------------------------------------------------------------------
insert into public.permissions (code, description)
values
  ('microfinance.view',   'Consulter les données du module Microfinance'),
  ('microfinance.create', 'Créer des comptes, emprunteurs, prêts et remboursements'),
  ('microfinance.update', 'Modifier les informations et statuts de microfinance'),
  ('microfinance.delete', 'Supprimer ou annuler des opérations de microfinance')
on conflict (code) do nothing;

insert into public.roles_permissions (role_code, permission_code)
values
  ('ADMINISTRATEUR', 'microfinance.view'),
  ('ADMINISTRATEUR', 'microfinance.create'),
  ('ADMINISTRATEUR', 'microfinance.update'),
  ('ADMINISTRATEUR', 'microfinance.delete'),
  ('SUPERVISEUR',    'microfinance.view'),
  ('SUPERVISEUR',    'microfinance.create'),
  ('SUPERVISEUR',    'microfinance.update')
on conflict (role_code, permission_code) do nothing;

insert into public.modules (code, libelle, activite_code, permission_acces, ordre, categorie, est_actif)
values (
  'commerce.microfinance',
  'Microfinance',
  'COMMERCE',
  'sales.view',
  17,
  'METIER',
  true
)
on conflict (code) do update set
  libelle = excluded.libelle,
  activite_code = excluded.activite_code,
  permission_acces = excluded.permission_acces,
  ordre = excluded.ordre,
  categorie = excluded.categorie,
  est_actif = true,
  updated_at = now();

-- Règle obligatoire d'accès par abonnement :
-- Supprimer tout accès pour NORMAL/FAIBLE (1 000 FCFA) et MOYEN (2 000 FCFA).
-- Autoriser exclusivement la formule PRO (5 000 FCFA).
delete from public.plan_modules
where module_code = 'commerce.microfinance';

insert into public.plan_modules (plan_code, module_code)
select code, 'commerce.microfinance'
from public.plans
where code = 'PRO'
on conflict (plan_code, module_code) do nothing;

-- -----------------------------------------------------------------------------
-- 2. Table : public.microfinance_accounts (Comptes & Caisses de trésorerie)
-- -----------------------------------------------------------------------------
create table if not exists public.microfinance_accounts (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  perimetre_id uuid references public.perimetres (id) on delete set null,
  nom text not null check (char_length(trim(nom)) between 1 and 120),
  type_compte text not null default 'CAISSE_PHYSIQUE'
    check (type_compte in ('CAISSE_PHYSIQUE', 'BANQUE', 'ORANGE_MONEY', 'MOBILE_MONEY', 'AUTRE')),
  source_fonds_defaut text not null default 'CAPITAL_PERSONNEL'
    check (source_fonds_defaut in ('CAPITAL_PERSONNEL', 'APPORT_ASSOCIES', 'AUTRE_FINANCEMENT')),
  caisse_id uuid references public.caisses (id) on delete set null,
  numero_compte text check (char_length(numero_compte) <= 80),
  solde_initial bigint not null default 0 check (solde_initial >= 0),
  solde_actuel bigint not null default 0,
  devise text not null default 'XOF' check (char_length(devise) between 2 and 10),
  est_actif boolean not null default true,
  observations text check (char_length(observations) <= 1000),
  cree_par uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id)
);

create index if not exists mf_accounts_sync_idx on public.microfinance_accounts (entreprise_id, updated_at);
create index if not exists mf_accounts_actif_idx on public.microfinance_accounts (entreprise_id, est_actif);

-- -----------------------------------------------------------------------------
-- 3. Table : public.microfinance_funds (Capitaux, Apports, Retraits, Dépenses, Transferts)
-- -----------------------------------------------------------------------------
create table if not exists public.microfinance_funds (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  perimetre_id uuid references public.perimetres (id) on delete set null,
  reference text not null check (char_length(trim(reference)) between 1 and 60),
  account_id uuid not null references public.microfinance_accounts (id) on delete restrict,
  account_destination_id uuid references public.microfinance_accounts (id) on delete restrict,
  type_mouvement text not null
    check (type_mouvement in ('APPORT_INITIAL', 'APPORT_SUPPLEMENTAIRE', 'RETRAIT_CAPITAL', 'DEPENSE_FONCTIONNEMENT', 'TRANSFERT_INTERNE')),
  source_fonds text not null default 'CAPITAL_PERSONNEL'
    check (source_fonds in ('CAPITAL_PERSONNEL', 'APPORT_ASSOCIES', 'AUTRE_FINANCEMENT')),
  montant bigint not null check (montant > 0),
  mode_paiement text not null default 'ESPECES'
    check (mode_paiement in ('ESPECES', 'MOBILE_MONEY', 'ORANGE_MONEY', 'VIREMENT', 'CHEQUE', 'CARTE', 'AUTRE')),
  date_mouvement timestamptz not null default now(),
  libelle text not null check (char_length(trim(libelle)) between 1 and 200),
  observations text check (char_length(observations) <= 1000),
  est_annule boolean not null default false,
  motif_annulation text check (char_length(motif_annulation) <= 500),
  cree_par uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id),
  unique (entreprise_id, reference)
);

create index if not exists mf_funds_sync_idx on public.microfinance_funds (entreprise_id, updated_at);
create index if not exists mf_funds_account_idx on public.microfinance_funds (entreprise_id, account_id);
create index if not exists mf_funds_date_idx on public.microfinance_funds (entreprise_id, date_mouvement desc);

-- -----------------------------------------------------------------------------
-- 4. Table : public.microfinance_borrowers (Emprunteurs)
-- -----------------------------------------------------------------------------
create table if not exists public.microfinance_borrowers (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  perimetre_id uuid references public.perimetres (id) on delete set null,
  code_emprunteur text not null check (char_length(trim(code_emprunteur)) between 1 and 50),
  contact_id uuid references public.contacts (id) on delete set null,
  nom_complet text not null check (char_length(trim(nom_complet)) between 1 and 160),
  telephone text not null check (char_length(trim(telephone)) between 1 and 40),
  whatsapp text check (char_length(whatsapp) <= 40),
  adresse text check (char_length(adresse) <= 250),
  localisation text check (char_length(localisation) <= 200),
  profession text check (char_length(profession) <= 120),
  activite text check (char_length(activite) <= 150),
  type_piece text check (char_length(type_piece) <= 60),
  reference_piece text check (char_length(reference_piece) <= 80),
  photo_url text check (char_length(photo_url) <= 500),
  infos_complementaires text check (char_length(infos_complementaires) <= 1000),
  date_inscription timestamptz not null default now(),
  observations text check (char_length(observations) <= 1500),
  est_actif boolean not null default true,
  cree_par uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id),
  unique (entreprise_id, code_emprunteur)
);

create index if not exists mf_borrowers_sync_idx on public.microfinance_borrowers (entreprise_id, updated_at);
create index if not exists mf_borrowers_nom_idx on public.microfinance_borrowers (entreprise_id, nom_complet);
create index if not exists mf_borrowers_contact_idx on public.microfinance_borrowers (entreprise_id, contact_id);

-- -----------------------------------------------------------------------------
-- 5. Table : public.microfinance_loans (Prêts d'argent)
-- -----------------------------------------------------------------------------
create table if not exists public.microfinance_loans (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  perimetre_id uuid references public.perimetres (id) on delete set null,
  reference text not null check (char_length(trim(reference)) between 1 and 60),
  borrower_id uuid not null references public.microfinance_borrowers (id) on delete restrict,
  account_id uuid not null references public.microfinance_accounts (id) on delete restrict,
  montant_accorde bigint not null check (montant_accorde > 0),
  methode_interet text not null
    check (methode_interet in ('POURCENTAGE_FIXE', 'MONTANT_FIXE', 'DEGRESSIF')),
  taux_interet numeric(10, 4) not null default 0 check (taux_interet >= 0),
  montant_interet_fixe bigint not null default 0 check (montant_interet_fixe >= 0),
  montant_interet_total bigint not null default 0 check (montant_interet_total >= 0),
  montant_total_a_rembourser bigint not null check (montant_total_a_rembourser >= montant_accorde),
  capital_rembourse bigint not null default 0 check (capital_rembourse >= 0),
  interet_rembourse bigint not null default 0 check (interet_rembourse >= 0),
  frequence text not null
    check (frequence in ('QUOTIDIENNE', 'HEBDOMADAIRE', 'MENSUELLE')),
  duree_valeur integer not null check (duree_valeur > 0),
  nombre_echeances integer not null check (nombre_echeances > 0),
  montant_echeance_indicatif bigint not null default 0 check (montant_echeance_indicatif >= 0),
  mode_decaissement text not null default 'ESPECES'
    check (mode_decaissement in ('ESPECES', 'MOBILE_MONEY', 'ORANGE_MONEY', 'VIREMENT', 'CHEQUE', 'CARTE', 'AUTRE')),
  date_octroi timestamptz not null default now(),
  date_decaissement timestamptz,
  date_debut timestamptz not null,
  date_fin_prevue timestamptz not null,
  date_solde timestamptz,
  statut text not null default 'EN_COURS'
    check (statut in ('BROUILLON', 'EN_COURS', 'PARTIELLEMENT_REMBOURSE', 'SOLDE', 'EN_RETARD', 'CONTENTIEUX', 'ANNULE')),
  conditions_particulieres text check (char_length(conditions_particulieres) <= 2000),
  observations text check (char_length(observations) <= 2000),
  motif_annulation text check (char_length(motif_annulation) <= 500),
  cree_par uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id),
  unique (entreprise_id, reference)
);

create index if not exists mf_loans_sync_idx on public.microfinance_loans (entreprise_id, updated_at);
create index if not exists mf_loans_borrower_idx on public.microfinance_loans (entreprise_id, borrower_id);
create index if not exists mf_loans_statut_idx on public.microfinance_loans (entreprise_id, statut);
create index if not exists mf_loans_octroi_idx on public.microfinance_loans (entreprise_id, date_octroi desc);

-- -----------------------------------------------------------------------------
-- 6. Table : public.microfinance_installments (Échéances de prêt)
-- -----------------------------------------------------------------------------
create table if not exists public.microfinance_installments (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  perimetre_id uuid references public.perimetres (id) on delete set null,
  loan_id uuid not null references public.microfinance_loans (id) on delete cascade,
  borrower_id uuid not null references public.microfinance_borrowers (id) on delete restrict,
  numero_echeance integer not null check (numero_echeance > 0),
  date_prevue timestamptz not null,
  capital_prevu bigint not null check (capital_prevu >= 0),
  interet_prevu bigint not null check (interet_prevu >= 0),
  montant_total_attendu bigint not null check (montant_total_attendu >= 0),
  capital_paye bigint not null default 0 check (capital_paye >= 0),
  interet_paye bigint not null default 0 check (interet_paye >= 0),
  montant_deja_paye bigint not null default 0 check (montant_deja_paye >= 0),
  reste_a_payer bigint not null default 0 check (reste_a_payer >= 0),
  statut text not null default 'A_VENIR'
    check (statut in ('A_VENIR', 'AUJOURD_HUI', 'PARTIEL', 'PAYE', 'EN_RETARD', 'ANNULE')),
  date_dernier_paiement timestamptz,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id),
  unique (loan_id, numero_echeance)
);

create index if not exists mf_installments_sync_idx on public.microfinance_installments (entreprise_id, updated_at);
create index if not exists mf_installments_loan_idx on public.microfinance_installments (entreprise_id, loan_id, numero_echeance);
create index if not exists mf_installments_date_idx on public.microfinance_installments (entreprise_id, date_prevue);
create index if not exists mf_installments_statut_idx on public.microfinance_installments (entreprise_id, statut);

-- -----------------------------------------------------------------------------
-- 7. Table : public.microfinance_repayments (Remboursements encaissés)
-- -----------------------------------------------------------------------------
create table if not exists public.microfinance_repayments (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  perimetre_id uuid references public.perimetres (id) on delete set null,
  reference text not null check (char_length(trim(reference)) between 1 and 60),
  loan_id uuid not null references public.microfinance_loans (id) on delete restrict,
  borrower_id uuid not null references public.microfinance_borrowers (id) on delete restrict,
  account_id uuid not null references public.microfinance_accounts (id) on delete restrict,
  date_paiement timestamptz not null default now(),
  montant_encaisse bigint not null check (montant_encaisse > 0),
  part_capital bigint not null default 0 check (part_capital >= 0),
  part_interet bigint not null default 0 check (part_interet >= 0),
  type_remboursement text not null default 'COMPLET'
    check (type_remboursement in ('COMPLET', 'PARTIEL', 'ANTICIPE', 'EXCEPTIONNEL', 'MULTI_ECHEANCES')),
  mode_paiement text not null default 'ESPECES'
    check (mode_paiement in ('ESPECES', 'MOBILE_MONEY', 'ORANGE_MONEY', 'VIREMENT', 'CHEQUE', 'CARTE', 'AUTRE')),
  justificatif_url text check (char_length(justificatif_url) <= 500),
  observations text check (char_length(observations) <= 1000),
  details_affectation jsonb not null default '[]'::jsonb,
  est_annule boolean not null default false,
  motif_annulation text check (char_length(motif_annulation) <= 500),
  cree_par uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id),
  unique (entreprise_id, reference),
  check (part_capital + part_interet = montant_encaisse)
);

create index if not exists mf_repayments_sync_idx on public.microfinance_repayments (entreprise_id, updated_at);
create index if not exists mf_repayments_loan_idx on public.microfinance_repayments (entreprise_id, loan_id);
create index if not exists mf_repayments_borrower_idx on public.microfinance_repayments (entreprise_id, borrower_id);
create index if not exists mf_repayments_date_idx on public.microfinance_repayments (entreprise_id, date_paiement desc);

-- -----------------------------------------------------------------------------
-- 8. Table : public.microfinance_transactions (Journal financier central immuable)
-- -----------------------------------------------------------------------------
create table if not exists public.microfinance_transactions (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  perimetre_id uuid references public.perimetres (id) on delete set null,
  reference text not null check (char_length(trim(reference)) between 1 and 60),
  date_transaction timestamptz not null default now(),
  type_transaction text not null
    check (type_transaction in (
      'APPORT_CAPITAL',
      'DECAISSEMENT_PRET',
      'REMBOURSEMENT_CAPITAL',
      'ENCAISSEMENT_INTERET',
      'DEPENSE_FONCTIONNEMENT',
      'RETRAIT_CAPITAL',
      'TRANSFERT_SORTANT',
      'TRANSFERT_ENTRANT',
      'REMBOURSEMENT_EXCEPTIONNEL',
      'ANNULATION_CORRECTION'
    )),
  montant bigint not null check (montant > 0),
  part_capital bigint not null default 0 check (part_capital >= 0),
  part_interet bigint not null default 0 check (part_interet >= 0),
  sens text not null check (sens in ('ENTREE', 'SORTIE', 'NEUTRE')),
  mode_paiement text not null default 'ESPECES'
    check (mode_paiement in ('ESPECES', 'MOBILE_MONEY', 'ORANGE_MONEY', 'VIREMENT', 'CHEQUE', 'CARTE', 'AUTRE')),
  account_id uuid not null references public.microfinance_accounts (id) on delete restrict,
  account_destination_id uuid references public.microfinance_accounts (id) on delete restrict,
  loan_id uuid references public.microfinance_loans (id) on delete set null,
  repayment_id uuid references public.microfinance_repayments (id) on delete set null,
  fund_id uuid references public.microfinance_funds (id) on delete set null,
  borrower_id uuid references public.microfinance_borrowers (id) on delete set null,
  transaction_origine_id uuid references public.microfinance_transactions (id) on delete set null,
  libelle text not null check (char_length(trim(libelle)) between 1 and 240),
  observations text check (char_length(observations) <= 1000),
  cree_par uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id),
  unique (entreprise_id, reference)
);

create index if not exists mf_transactions_sync_idx on public.microfinance_transactions (entreprise_id, updated_at);
create index if not exists mf_transactions_date_idx on public.microfinance_transactions (entreprise_id, date_transaction desc);
create index if not exists mf_transactions_type_idx on public.microfinance_transactions (entreprise_id, type_transaction);
create index if not exists mf_transactions_account_idx on public.microfinance_transactions (entreprise_id, account_id);

-- -----------------------------------------------------------------------------
-- 9. Table : public.microfinance_audit_logs (Journal d'audit immuable)
-- -----------------------------------------------------------------------------
create table if not exists public.microfinance_audit_logs (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  perimetre_id uuid references public.perimetres (id) on delete set null,
  action text not null check (char_length(trim(action)) between 1 and 80),
  entite_type text not null check (char_length(trim(entite_type)) between 1 and 60),
  entite_id uuid not null,
  reference_entite text check (char_length(reference_entite) <= 80),
  utilisateur_id uuid default auth.uid() references public.profiles (id) on delete set null,
  details_avant jsonb,
  details_apres jsonb,
  motif text check (char_length(motif) <= 500),
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id)
);

create index if not exists mf_audit_sync_idx on public.microfinance_audit_logs (entreprise_id, updated_at);
create index if not exists mf_audit_entite_idx on public.microfinance_audit_logs (entreprise_id, entite_type, entite_id);

-- -----------------------------------------------------------------------------
-- 10. Triggers de sécurité, d'intégrité comptable et de contrôle d'abonnement PRO
-- -----------------------------------------------------------------------------
create or replace function app.tg_microfinance_acces_pro()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not app.peut(
    new.entreprise_id,
    'commerce.microfinance',
    case when tg_op = 'INSERT' then 'sales.create' else 'sales.update' end,
    new.perimetre_id
  ) then
    perform app.refuser('MODULE_RESERVE_PRO', jsonb_build_object('module', 'commerce.microfinance'));
  end if;
  return new;
end;
$$;

-- Protection des prêts déjà décaissés : interdiction de modifier silencieusement
-- le capital accordé, la méthode d'intérêt, le taux ou le total à rembourser.
create or replace function app.tg_microfinance_loans_integrite()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and old.statut <> 'BROUILLON' then
    if new.montant_accorde <> old.montant_accorde
       or new.methode_interet <> old.methode_interet
       or new.taux_interet <> old.taux_interet
       or new.montant_interet_total <> old.montant_interet_total
       or new.montant_total_a_rembourser <> old.montant_total_a_rembourser then
      perform app.refuser('PRET_DECAISSE_IMMUABLE', jsonb_build_object('loan_id', old.id));
    end if;
  end if;
  return new;
end;
$$;

-- Interdiction absolue de suppression physique ou logique silencieuse du journal financier et de l'audit
create or replace function app.tg_microfinance_interdire_suppression()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    perform app.refuser('SUPPRESSION_TRANSACTION_INTERDITE');
  end if;
  if tg_op = 'UPDATE' and new.deleted_at is not null and old.deleted_at is null then
    perform app.refuser('SUPPRESSION_TRANSACTION_INTERDITE');
  end if;
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'microfinance_accounts',
    'microfinance_funds',
    'microfinance_borrowers',
    'microfinance_loans',
    'microfinance_installments',
    'microfinance_repayments',
    'microfinance_transactions',
    'microfinance_audit_logs'
  ] loop
    execute format('drop trigger if exists %I_acces_pro on public.%I', t, t);
    execute format(
      'create trigger %I_acces_pro before insert or update on public.%I '
      'for each row execute function app.tg_microfinance_acces_pro()',
      t, t
    );

    execute format('drop trigger if exists %I_versionnement on public.%I', t, t);
    execute format(
      'create trigger %I_versionnement before insert or update on public.%I '
      'for each row execute function app.tg_versionnement()',
      t, t
    );
  end loop;
end;
$$;

drop trigger if exists microfinance_loans_integrite on public.microfinance_loans;
create trigger microfinance_loans_integrite before update on public.microfinance_loans
  for each row execute function app.tg_microfinance_loans_integrite();

drop trigger if exists microfinance_transactions_immuable on public.microfinance_transactions;
create trigger microfinance_transactions_immuable before update or delete on public.microfinance_transactions
  for each row execute function app.tg_microfinance_interdire_suppression();

drop trigger if exists microfinance_audit_logs_immuable on public.microfinance_audit_logs;
create trigger microfinance_audit_logs_immuable before update or delete on public.microfinance_audit_logs
  for each row execute function app.tg_microfinance_interdire_suppression();

-- -----------------------------------------------------------------------------
-- 11. Politiques RLS multi-tenant & Contrôle serveur Formule PRO (5 000 FCFA)
-- -----------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'microfinance_accounts',
    'microfinance_funds',
    'microfinance_borrowers',
    'microfinance_loans',
    'microfinance_installments',
    'microfinance_repayments',
    'microfinance_transactions',
    'microfinance_audit_logs'
  ] loop
    execute format('alter table public.%I enable row level security', t);

    execute format('drop policy if exists %I_lecture on public.%I', t, t);
    execute format(
      'create policy %I_lecture on public.%I for select to authenticated '
      'using (app.peut(entreprise_id, ''commerce.microfinance'', ''sales.view'', perimetre_id))',
      t, t
    );

    execute format('drop policy if exists %I_ajout on public.%I', t, t);
    execute format(
      'create policy %I_ajout on public.%I for insert to authenticated '
      'with check (app.peut(entreprise_id, ''commerce.microfinance'', ''sales.create'', perimetre_id))',
      t, t
    );

    execute format('drop policy if exists %I_modification on public.%I', t, t);
    execute format(
      'create policy %I_modification on public.%I for update to authenticated '
      'using (app.peut(entreprise_id, ''commerce.microfinance'', ''sales.update'', perimetre_id)) '
      'with check (app.peut(entreprise_id, ''commerce.microfinance'', ''sales.update'', perimetre_id))',
      t, t
    );

    execute format('revoke all on public.%I from anon, authenticated', t);
    execute format('grant select, insert, update on public.%I to authenticated', t);
    execute format('grant all on public.%I to service_role', t);
  end loop;
end;
$$;

-- -----------------------------------------------------------------------------
-- 12. Enregistrement dans app.sync_tables (Synchronisation Offline-First)
-- -----------------------------------------------------------------------------
insert into app.sync_tables (table_name, colonnes_creation, colonnes_modification) values
  ('microfinance_accounts',
   array[
     'entreprise_id', 'perimetre_id', 'nom', 'type_compte', 'source_fonds_defaut',
     'caisse_id', 'numero_compte', 'solde_initial', 'solde_actuel', 'devise',
     'est_actif', 'observations', 'cree_par'
   ],
   array[
     'perimetre_id', 'nom', 'type_compte', 'source_fonds_defaut', 'caisse_id',
     'numero_compte', 'solde_initial', 'solde_actuel', 'devise', 'est_actif',
     'observations', 'deleted_at'
   ]),

  ('microfinance_funds',
   array[
     'entreprise_id', 'perimetre_id', 'reference', 'account_id', 'account_destination_id',
     'type_mouvement', 'source_fonds', 'montant', 'mode_paiement', 'date_mouvement',
     'libelle', 'observations', 'est_annule', 'motif_annulation', 'cree_par'
   ],
   array[
     'libelle', 'observations', 'est_annule', 'motif_annulation', 'deleted_at'
   ]),

  ('microfinance_borrowers',
   array[
     'entreprise_id', 'perimetre_id', 'code_emprunteur', 'contact_id', 'nom_complet',
     'telephone', 'whatsapp', 'adresse', 'localisation', 'profession', 'activite',
     'type_piece', 'reference_piece', 'photo_url', 'infos_complementaires',
     'date_inscription', 'observations', 'est_actif', 'cree_par'
   ],
   array[
     'perimetre_id', 'contact_id', 'nom_complet', 'telephone', 'whatsapp', 'adresse',
     'localisation', 'profession', 'activite', 'type_piece', 'reference_piece',
     'photo_url', 'infos_complementaires', 'observations', 'est_actif', 'deleted_at'
   ]),

  ('microfinance_loans',
   array[
     'entreprise_id', 'perimetre_id', 'reference', 'borrower_id', 'account_id',
     'montant_accorde', 'methode_interet', 'taux_interet', 'montant_interet_fixe',
     'montant_interet_total', 'montant_total_a_rembourser', 'capital_rembourse',
     'interet_rembourse', 'frequence', 'duree_valeur', 'nombre_echeances',
     'montant_echeance_indicatif', 'mode_decaissement', 'date_octroi',
     'date_decaissement', 'date_debut', 'date_fin_prevue', 'date_solde', 'statut',
     'conditions_particulieres', 'observations', 'motif_annulation', 'cree_par'
   ],
   array[
     'account_id', 'capital_rembourse', 'interet_rembourse', 'mode_decaissement',
     'date_decaissement', 'date_solde', 'statut', 'conditions_particulieres',
     'observations', 'motif_annulation', 'deleted_at'
   ]),

  ('microfinance_installments',
   array[
     'entreprise_id', 'perimetre_id', 'loan_id', 'borrower_id', 'numero_echeance',
     'date_prevue', 'capital_prevu', 'interet_prevu', 'montant_total_attendu',
     'capital_paye', 'interet_paye', 'montant_deja_paye', 'reste_a_payer',
     'statut', 'date_dernier_paiement'
   ],
   array[
     'capital_paye', 'interet_paye', 'montant_deja_paye', 'reste_a_payer',
     'statut', 'date_dernier_paiement', 'deleted_at'
   ]),

  ('microfinance_repayments',
   array[
     'entreprise_id', 'perimetre_id', 'reference', 'loan_id', 'borrower_id',
     'account_id', 'date_paiement', 'montant_encaisse', 'part_capital',
     'part_interet', 'type_remboursement', 'mode_paiement', 'justificatif_url',
     'observations', 'details_affectation', 'est_annule', 'motif_annulation', 'cree_par'
   ],
   array[
     'justificatif_url', 'observations', 'est_annule', 'motif_annulation', 'deleted_at'
   ]),

  ('microfinance_transactions',
   array[
     'entreprise_id', 'perimetre_id', 'reference', 'date_transaction', 'type_transaction',
     'montant', 'part_capital', 'part_interet', 'sens', 'mode_paiement', 'account_id',
     'account_destination_id', 'loan_id', 'repayment_id', 'fund_id', 'borrower_id',
     'transaction_origine_id', 'libelle', 'observations', 'cree_par'
   ],
   array[
     'observations'
   ]),

  ('microfinance_audit_logs',
   array[
     'entreprise_id', 'perimetre_id', 'action', 'entite_type', 'entite_id',
     'reference_entite', 'utilisateur_id', 'details_avant', 'details_apres', 'motif'
   ],
   array[
     'motif'
   ])
on conflict (table_name) do update set
  colonnes_creation = excluded.colonnes_creation,
  colonnes_modification = excluded.colonnes_modification;

notify pgrst, 'reload schema';

