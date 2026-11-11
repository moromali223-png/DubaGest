-- =============================================================================
-- Migration: Préparation technique aux tests d'intégration agrégateur de paiement
-- Migration: 20261107000100_preparation_tests_agregateur_paiement.sql
-- Description:
--   1. Création de la table d'audit et traçabilité public.journal_webhooks_paiement
--   2. Évolution de transactions_abonnement :
--      - Colonne type_paiement ('REDIRECTION' | 'DIRECT_SANS_REDIRECTION')
--      - Extension de statut pour inclure 'EXPIRE'
--   3. Procédure sécurisée app.enregistrer_evenement_webhook (et exposition public)
--   4. Mise à jour de public.initialiser_paiement_abonnement :
--      - Support du montant de test de 10 FCFA (strictement réservé aux tests)
--      - Support du type de paiement (REDIRECTION ou DIRECT_SANS_REDIRECTION)
--   5. Sécurité, RLS et idempotence
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Table d'audit des webhooks et notifications de paiement
-- -----------------------------------------------------------------------------
create table if not exists public.journal_webhooks_paiement (
  id uuid primary key default gen_random_uuid(),
  prestataire text not null default 'LIGDICASH',
  methode_http text not null default 'POST',
  headers jsonb not null default '{}'::jsonb,
  payload jsonb not null default '{}'::jsonb,
  statut_traitement text not null default 'RECU', -- 'TEST_PING_RECU', 'RECU', 'CONFIRME', 'REFUSE', 'ERREUR'
  transaction_id uuid references public.transactions_abonnement(id) on delete set null,
  reference_interne text,
  reference_prestataire text,
  message text,
  ip_source text,
  created_at timestamptz not null default now()
);

create index if not exists idx_journal_webhooks_created_at
  on public.journal_webhooks_paiement (created_at desc);

create index if not exists idx_journal_webhooks_ref
  on public.journal_webhooks_paiement (reference_interne, reference_prestataire);

alter table public.journal_webhooks_paiement enable row level security;

-- Lecture autorisée uniquement aux super administrateurs pour analyse technique
create policy journal_webhooks_lecture on public.journal_webhooks_paiement
  for select to authenticated
  using (app.est_super_admin());

-- Insertion et gestion exclusive réservées au rôle de service serveur
revoke all on public.journal_webhooks_paiement from anon, authenticated;
grant select on public.journal_webhooks_paiement to authenticated;
grant all on public.journal_webhooks_paiement to service_role;

-- -----------------------------------------------------------------------------
-- 2. Procédure serveur d'enregistrement des événements de webhook
-- -----------------------------------------------------------------------------
create or replace function app.enregistrer_evenement_webhook(
  p_prestataire text,
  p_methode_http text,
  p_headers jsonb,
  p_payload jsonb,
  p_statut_traitement text,
  p_reference_interne text default null,
  p_reference_prestataire text default null,
  p_message text default null,
  p_ip_source text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_tx_id uuid;
begin
  if p_reference_interne is not null then
    select id into v_tx_id
    from public.transactions_abonnement
    where reference_interne = p_reference_interne;
  elsif p_reference_prestataire is not null then
    select id into v_tx_id
    from public.transactions_abonnement
    where token_transaction = p_reference_prestataire
       or reference_prestataire = p_reference_prestataire;
  end if;

  insert into public.journal_webhooks_paiement (
    prestataire,
    methode_http,
    headers,
    payload,
    statut_traitement,
    transaction_id,
    reference_interne,
    reference_prestataire,
    message,
    ip_source
  ) values (
    coalesce(p_prestataire, 'LIGDICASH'),
    coalesce(p_methode_http, 'POST'),
    coalesce(p_headers, '{}'::jsonb),
    coalesce(p_payload, '{}'::jsonb),
    coalesce(p_statut_traitement, 'RECU'),
    v_tx_id,
    p_reference_interne,
    p_reference_prestataire,
    p_message,
    p_ip_source
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function app.enregistrer_evenement_webhook from public, anon, authenticated;
grant execute on function app.enregistrer_evenement_webhook to service_role;

-- Exposition dans le schéma public pour invocation Supabase RPC par service_role
create or replace function public.enregistrer_evenement_webhook(
  p_prestataire text,
  p_methode_http text,
  p_headers jsonb,
  p_payload jsonb,
  p_statut_traitement text,
  p_reference_interne text default null,
  p_reference_prestataire text default null,
  p_message text default null,
  p_ip_source text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  return app.enregistrer_evenement_webhook(
    p_prestataire => p_prestataire,
    p_methode_http => p_methode_http,
    p_headers => p_headers,
    p_payload => p_payload,
    p_statut_traitement => p_statut_traitement,
    p_reference_interne => p_reference_interne,
    p_reference_prestataire => p_reference_prestataire,
    p_message => p_message,
    p_ip_source => p_ip_source
  );
end;
$$;

revoke all on function public.enregistrer_evenement_webhook from public, anon, authenticated;
grant execute on function public.enregistrer_evenement_webhook to service_role;

-- -----------------------------------------------------------------------------
-- 3. Évolution de transactions_abonnement (type_paiement et statut)
-- -----------------------------------------------------------------------------
alter table public.transactions_abonnement
  add column if not exists type_paiement text not null default 'REDIRECTION'
  check (type_paiement in ('REDIRECTION', 'DIRECT_SANS_REDIRECTION'));

alter table public.transactions_abonnement
  drop constraint if exists transactions_abonnement_statut_check;

alter table public.transactions_abonnement
  add constraint transactions_abonnement_statut_check
  check (statut in ('EN_ATTENTE', 'EN_COURS', 'CONFIRME', 'ECHOUE', 'ANNULE', 'REMBOURSE', 'EXPIRE'));

create index if not exists idx_transactions_abonnement_type
  on public.transactions_abonnement (type_paiement, statut);

-- -----------------------------------------------------------------------------
-- 4. Procédure mise à jour : public.initialiser_paiement_abonnement
--    Prend en charge le montant test (10 FCFA) et le type de paiement (Direct/Redirection)
-- -----------------------------------------------------------------------------
drop function if exists public.initialiser_paiement_abonnement(uuid, text, integer, text, text, boolean);
drop function if exists public.initialiser_paiement_abonnement(uuid, text, smallint, text, text, boolean);

create or replace function public.initialiser_paiement_abonnement(
  p_entreprise_id uuid,
  p_plan_code text,
  p_duree_mois integer,
  p_prestataire text,
  p_idempotency_key text default null,
  p_est_demo boolean default false,
  p_montant_test integer default null,
  p_type_paiement text default 'REDIRECTION'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_role text := coalesce(auth.role(), '');
  v_plan public.plans%rowtype;
  v_tarif public.tarifs_durees_plans%rowtype;
  v_montant_total integer;
  v_idempotency text;
  v_reference text;
  v_tx public.transactions_abonnement%rowtype;
  v_type_paiement text;
begin
  -- 1. Authentification & Autorisation
  if v_role <> 'service_role' then
    if v_uid is null then
      raise exception 'NON_AUTHENTIFIE' using errcode = '42501';
    end if;

    if not (app.a_permission(p_entreprise_id, 'entreprise.manage') or app.est_super_admin()) then
      raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
    end if;
  end if;

  -- 2. Validation des paramètres
  if p_duree_mois not in (1, 3, 6, 12) then
    raise exception 'DUREE_INVALIDE' using errcode = 'P0001';
  end if;

  if p_prestataire not in ('LIGDICASH', 'ORANGE_MONEY') then
    raise exception 'PRESTATAIRE_INVALIDE' using errcode = 'P0001';
  end if;

  v_type_paiement := coalesce(p_type_paiement, 'REDIRECTION');
  if v_type_paiement not in ('REDIRECTION', 'DIRECT_SANS_REDIRECTION') then
    v_type_paiement := 'REDIRECTION';
  end if;

  select * into v_plan from public.plans where code = p_plan_code and est_actif;
  if v_plan.code is null then
    raise exception 'PLAN_INVALIDE' using errcode = 'P0001';
  end if;

  -- 3. Détermination du montant
  -- CAS SPÉCIAL SÉCURISÉ : Montant de test agrégateur (10 FCFA)
  if p_montant_test is not null and p_montant_test = 10 then
    -- Autorisé uniquement en mode test / démo, via le serveur service_role ou par un super-admin
    if coalesce(p_est_demo, false) or v_role = 'service_role' or app.est_super_admin() then
      v_montant_total := 10;
    else
      raise exception 'MONTANT_TEST_NON_AUTORISE' using errcode = '42501';
    end if;
  else
    -- Tarification standard de production
    select * into v_tarif
    from public.tarifs_durees_plans
    where plan_code = v_plan.code and duree_mois = p_duree_mois and est_actif;

    if v_tarif.id is not null then
      v_montant_total := v_tarif.montant_total;
    else
      v_montant_total := v_plan.prix_mensuel * p_duree_mois;
    end if;
  end if;

  if v_montant_total <= 0 then
    raise exception 'MONTANT_INVALIDE' using errcode = 'P0001';
  end if;

  -- 4. Idempotence
  v_idempotency := coalesce(nullif(trim(p_idempotency_key), ''), 'IDEMP_' || gen_random_uuid()::text);

  select * into v_tx from public.transactions_abonnement where idempotency_key = v_idempotency;
  if v_tx.id is not null then
    return jsonb_build_object(
      'succes', true,
      'deja_cree', true,
      'transaction', row_to_json(v_tx)
    );
  end if;

  -- 5. Génération de référence interne unique
  v_reference := 'DBG-' || upper(p_prestataire) || '-' || to_char(now(), 'YYYYMMDD-HH24MISS') || '-' || substr(md5(random()::text), 1, 6);

  -- 6. Création de la transaction en base
  insert into public.transactions_abonnement (
    entreprise_id,
    user_id,
    plan_code,
    duree_mois,
    montant,
    devise,
    prestataire,
    reference_interne,
    idempotency_key,
    statut,
    type_paiement,
    est_demo,
    environnement,
    diagnostic
  ) values (
    p_entreprise_id,
    v_uid,
    v_plan.code,
    p_duree_mois,
    v_montant_total,
    'XOF',
    p_prestataire,
    v_reference,
    v_idempotency,
    'EN_ATTENTE',
    v_type_paiement,
    coalesce(p_est_demo, false),
    case when coalesce(p_est_demo, false) or p_montant_test = 10 then 'TEST' else 'PRODUCTION' end,
    jsonb_build_object(
      'client_mode', case when coalesce(p_est_demo, false) or p_montant_test = 10 then 'TEST_INTEGRATION' else 'PRODUCTION' end,
      'montant_test_applique', p_montant_test = 10,
      'type_paiement', v_type_paiement,
      'initialisation_ts', now()
    )
  )
  returning * into v_tx;

  return jsonb_build_object(
    'succes', true,
    'deja_cree', false,
    'transaction', row_to_json(v_tx)
  );
end;
$$;

revoke all on function public.initialiser_paiement_abonnement from public, anon;
grant execute on function public.initialiser_paiement_abonnement to authenticated, service_role;

