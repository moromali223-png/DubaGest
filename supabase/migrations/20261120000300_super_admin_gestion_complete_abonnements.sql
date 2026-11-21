-- =============================================================================
-- MIGRATION : GESTION COMPLÈTE DES ABONNEMENTS PAR LE SUPER ADMIN
-- (Activation, Désactivation / Suspension, Réactivation, Annulation / Résiliation)
-- =============================================================================

-- 1. Désactiver / Suspendre un abonnement en cours
create or replace function public.admin_desactiver_abonnement(
  p_entreprise_id uuid,
  p_motif text default 'Désactivation administrative Super Admin'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid;
  v_ab_id uuid;
  v_plan_code text;
  v_nom_entreprise text;
  v_motif text;
begin
  v_uid := app.verifier_super_admin();

  select nom into v_nom_entreprise
  from public.entreprises
  where id = p_entreprise_id;
  if not found then
    raise exception 'ENTREPRISE_INTROUVABLE' using errcode = '42501';
  end if;

  v_motif := coalesce(nullif(trim(p_motif), ''), 'Désactivation administrative Super Admin');

  update public.abonnements
  set
    statut = 'SUSPENDU',
    updated_at = now()
  where entreprise_id = p_entreprise_id
    and statut = 'ACTIF'
  returning id, plan_code into v_ab_id, v_plan_code;

  if v_ab_id is null then
    raise exception 'AUCUN_ABONNEMENT_ACTIF_A_DESACTIVER' using errcode = '42501';
  end if;

  perform app.tracer_super_admin_action(
    'DESACTIVATION_ABONNEMENT',
    'ENTREPRISE',
    p_entreprise_id::text,
    jsonb_build_object(
      'nom_entreprise', v_nom_entreprise,
      'abonnement_id', v_ab_id,
      'plan_code', v_plan_code,
      'motif', v_motif
    )
  );

  return jsonb_build_object(
    'success', true,
    'abonnement_id', v_ab_id,
    'statut', 'SUSPENDU',
    'plan_code', v_plan_code,
    'motif', v_motif
  );
end;
$$;
grant execute on function public.admin_desactiver_abonnement(uuid, text) to authenticated;

-- 2. Réactiver un abonnement suspendu
create or replace function public.admin_reactiver_abonnement(
  p_entreprise_id uuid,
  p_motif text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid;
  v_ab_id uuid;
  v_plan_code text;
  v_nom_entreprise text;
  v_motif text;
begin
  v_uid := app.verifier_super_admin();

  select nom into v_nom_entreprise
  from public.entreprises
  where id = p_entreprise_id;
  if not found then
    raise exception 'ENTREPRISE_INTROUVABLE' using errcode = '42501';
  end if;

  v_motif := coalesce(nullif(trim(p_motif), ''), 'Réactivation administrative Super Admin');

  update public.abonnements
  set
    statut = 'ACTIF',
    updated_at = now()
  where entreprise_id = p_entreprise_id
    and statut = 'SUSPENDU'
  returning id, plan_code into v_ab_id, v_plan_code;

  if v_ab_id is null then
    raise exception 'AUCUN_ABONNEMENT_SUSPENDU_A_REACTIVER' using errcode = '42501';
  end if;

  perform app.tracer_super_admin_action(
    'REACTIVATION_ABONNEMENT',
    'ENTREPRISE',
    p_entreprise_id::text,
    jsonb_build_object(
      'nom_entreprise', v_nom_entreprise,
      'abonnement_id', v_ab_id,
      'plan_code', v_plan_code,
      'motif', v_motif
    )
  );

  return jsonb_build_object(
    'success', true,
    'abonnement_id', v_ab_id,
    'statut', 'ACTIF',
    'plan_code', v_plan_code
  );
end;
$$;
grant execute on function public.admin_reactiver_abonnement(uuid, text) to authenticated;

-- 3. Annuler / Résilier définitivement un abonnement en cours
create or replace function public.admin_annuler_abonnement(
  p_entreprise_id uuid,
  p_motif text default 'Annulation administrative Super Admin'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid;
  v_ab_id uuid;
  v_plan_code text;
  v_nom_entreprise text;
  v_motif text;
  v_now timestamptz := now();
begin
  v_uid := app.verifier_super_admin();

  select nom into v_nom_entreprise
  from public.entreprises
  where id = p_entreprise_id;
  if not found then
    raise exception 'ENTREPRISE_INTROUVABLE' using errcode = '42501';
  end if;

  v_motif := coalesce(nullif(trim(p_motif), ''), 'Annulation administrative Super Admin');

  update public.abonnements
  set
    statut = 'ANNULE',
    date_fin = greatest(v_now, date_debut + interval '1 second'),
    updated_at = v_now
  where entreprise_id = p_entreprise_id
    and statut in ('ESSAI', 'ACTIF', 'SUSPENDU')
  returning id, plan_code into v_ab_id, v_plan_code;

  if v_ab_id is null then
    raise exception 'AUCUN_ABONNEMENT_EN_COURS_A_ANNULER' using errcode = '42501';
  end if;

  perform app.tracer_super_admin_action(
    'ANNULATION_ABONNEMENT',
    'ENTREPRISE',
    p_entreprise_id::text,
    jsonb_build_object(
      'nom_entreprise', v_nom_entreprise,
      'abonnement_id', v_ab_id,
      'plan_code', v_plan_code,
      'motif', v_motif
    )
  );

  return jsonb_build_object(
    'success', true,
    'abonnement_id', v_ab_id,
    'statut', 'ANNULE',
    'plan_code', v_plan_code,
    'motif', v_motif
  );
end;
$$;
grant execute on function public.admin_annuler_abonnement(uuid, text) to authenticated;

notify pgrst, 'reload schema';
