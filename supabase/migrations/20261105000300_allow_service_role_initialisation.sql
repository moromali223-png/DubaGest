-- =============================================================================
-- Migration: Autoriser le rôle de confiance serveur (service_role) sur l'initialisation
-- Migration: 20261105000300_allow_service_role_initialisation.sql
-- =============================================================================

create or replace function public.initialiser_paiement_abonnement(
  p_entreprise_id uuid,
  p_plan_code text,
  p_duree_mois smallint,
  p_prestataire text,
  p_idempotency_key text default null,
  p_est_demo boolean default false
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
begin
  -- Authentification : soit un utilisateur connecté autorisé, soit l'Edge Function de confiance (service_role)
  if v_role <> 'service_role' then
    if v_uid is null then
      raise exception 'NON_AUTHENTIFIE' using errcode = '42501';
    end if;

    if not (app.a_permission(p_entreprise_id, 'entreprise.manage') or app.est_super_admin()) then
      raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
    end if;
  end if;

  if p_duree_mois not in (1, 3, 6, 12) then
    raise exception 'DUREE_INVALIDE' using errcode = 'P0001';
  end if;

  if p_prestataire not in ('LIGDICASH', 'ORANGE_MONEY') then
    raise exception 'PRESTATAIRE_INVALIDE' using errcode = 'P0001';
  end if;

  select * into v_plan from public.plans where code = p_plan_code and est_actif;
  if v_plan.code is null then
    raise exception 'PLAN_INVALIDE' using errcode = 'P0001';
  end if;

  -- Récupération du tarif officiel serveur configuré pour cette formule et cette durée
  select * into v_tarif
  from public.tarifs_durees_plans
  where plan_code = v_plan.code and duree_mois = p_duree_mois and est_actif;

  if v_tarif.id is not null then
    v_montant_total := v_tarif.montant_total;
  else
    v_montant_total := v_plan.prix_mensuel * p_duree_mois;
  end if;

  if v_montant_total <= 0 then
    raise exception 'MONTANT_INVALIDE' using errcode = 'P0001';
  end if;

  v_idempotency := coalesce(nullif(trim(p_idempotency_key), ''), 'IDEMP_' || gen_random_uuid()::text);

  -- Protection contre les doubles transactions (Idempotence)
  select * into v_tx from public.transactions_abonnement where idempotency_key = v_idempotency;
  if v_tx.id is not null then
    return jsonb_build_object(
      'succes', true,
      'deja_cree', true,
      'transaction', row_to_json(v_tx)
    );
  end if;

  v_reference := 'DBG-' || upper(p_prestataire) || '-' || to_char(now(), 'YYYYMMDD-HH24MISS') || '-' || substr(md5(random()::text), 1, 6);

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
    est_demo,
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
    coalesce(p_est_demo, false),
    jsonb_build_object(
      'client_mode', case when coalesce(p_est_demo, false) then 'DEMO' else 'PRODUCTION' end,
      'initialisation_ts', now(),
      'tarif_serveur', v_montant_total,
      'initie_par', case when v_role = 'service_role' then 'EDGE_FUNCTION' else 'CLIENT' end
    )
  )
  returning * into v_tx;

  return jsonb_build_object(
    'succes', true,
    'transaction', row_to_json(v_tx)
  );
end;
$$;

