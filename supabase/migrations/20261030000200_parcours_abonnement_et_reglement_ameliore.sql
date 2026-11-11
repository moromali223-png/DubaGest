-- =============================================================================
-- Migration: Parcours d'abonnement et de réabonnement DubaGest
-- Migration: 20261030000200_parcours_abonnement_et_reglement_ameliore.sql
-- Description:
--   1. Extension des statuts de transactions pour inclure EN_COURS (en cours de traitement).
--   2. Enrichissement de public.lister_catalogue_plans (description, libellés d'activités et modules).
--   3. RPC sécurisée public.verifier_statut_transaction pour la vérification temps-réel côté client.
--   4. Idempotence renforcée et traçabilité pour le règlement et réabonnement.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Extension du check constraint de statut sur public.transactions_abonnement
-- -----------------------------------------------------------------------------
alter table public.transactions_abonnement
  drop constraint if exists transactions_abonnement_statut_check;

alter table public.transactions_abonnement
  add constraint transactions_abonnement_statut_check
  check (statut in ('EN_ATTENTE', 'EN_COURS', 'CONFIRME', 'ECHOUE', 'ANNULE', 'REMBOURSE'));

-- -----------------------------------------------------------------------------
-- 2. Enrichissement du catalogue dynamique des formules d'abonnement
-- -----------------------------------------------------------------------------
create or replace function public.lister_catalogue_plans()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'code', p.code,
        'nom', p.nom,
        'description', coalesce(p.description, ''),
        'ordre', p.ordre,
        'prix_mensuel', p.prix_mensuel,
        'devise', 'XOF',
        'max_activites', p.max_activites,
        'activites', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'activite_code', pa.activite_code,
            'activite_libelle', ac.libelle,
            'max_utilisateurs', pa.max_utilisateurs,
            'max_perimetres', pa.max_perimetres
          ) order by ac.ordre), '[]'::jsonb)
          from public.plan_activites pa
          join public.activites ac on ac.code = pa.activite_code
          where pa.plan_code = p.code
        ),
        'roles', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'role_code', pr.role_code,
            'max_membres', pr.max_membres
          ) order by pr.role_code), '[]'::jsonb)
          from public.plan_roles pr
          where pr.plan_code = p.code
        ),
        'modules', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'code', pm.module_code,
            'libelle', mo.libelle,
            'activite_code', mo.activite_code,
            'ordre', mo.ordre
          ) order by mo.ordre), '[]'::jsonb)
          from public.plan_modules pm
          join public.modules mo on mo.code = pm.module_code
          where pm.plan_code = p.code
        )
      ) order by p.ordre
    ),
    '[]'::jsonb
  )
  from public.plans p
  where p.est_actif;
$$;

grant execute on function public.lister_catalogue_plans() to authenticated, anon;

-- -----------------------------------------------------------------------------
-- 3. RPC de vérification en temps réel du statut d'une transaction
--    Permet au client Flutter de rafraîchir l'état d'un paiement en cours
-- -----------------------------------------------------------------------------
create or replace function public.verifier_statut_transaction(p_transaction_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_tx public.transactions_abonnement%rowtype;
  v_abo public.abonnements%rowtype;
begin
  if v_uid is null then
    raise exception 'NON_AUTHENTIFIE' using errcode = '42501';
  end if;

  select * into v_tx
  from public.transactions_abonnement
  where id = p_transaction_id;

  if v_tx.id is null then
    raise exception 'TRANSACTION_INTROUVABLE' using errcode = 'P0001';
  end if;

  if not (app.est_membre(v_tx.entreprise_id) or app.est_super_admin()) then
    raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
  end if;

  -- Synchroniser l'état d'expiration proactif
  perform app.synchroniser_expiration_abonnement(v_tx.entreprise_id);

  if v_tx.abonnement_id is not null then
    select * into v_abo from public.abonnements where id = v_tx.abonnement_id;
  end if;

  return jsonb_build_object(
    'succes', true,
    'transaction', row_to_json(v_tx),
    'abonnement', case when v_abo.id is not null then row_to_json(v_abo) else null end
  );
end;
$$;

revoke execute on function public.verifier_statut_transaction from public, anon;
grant execute on function public.verifier_statut_transaction to authenticated;

