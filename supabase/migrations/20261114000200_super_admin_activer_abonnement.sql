-- =============================================================================
-- MIGRATION : ACTIVATION ET MODIFICATION D'ABONNEMENT PAR LE SUPER ADMIN
-- Permet au Super Admin d'activer ou de changer directement la formule
-- (NORMAL / MOYEN / PRO) d'une entreprise avec une durée définie (1, 3, 6, 12 mois)
-- ou illimitée (Sponsorisé 0 FCFA), en mode COMMERCIAL ou SPONSORISE.
-- =============================================================================

create or replace function public.admin_activer_abonnement(
  p_entreprise_id uuid,
  p_plan_code text,
  p_duree_mois integer default null,
  p_type_facturation text default 'COMMERCIAL',
  p_motif text default 'Activation manuelle Super Admin'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid;
  v_plan public.plans%rowtype;
  v_entreprise public.entreprises%rowtype;
  v_ab_id uuid;
  v_facturation text;
  v_motif text;
  v_now timestamptz := now();
  v_date_fin timestamptz;
  v_valeur_ref integer;
begin
  v_uid := app.verifier_super_admin();

  select * into v_entreprise
  from public.entreprises
  where id = p_entreprise_id;
  if not found then
    raise exception 'ENTREPRISE_INTROUVABLE' using errcode = '42501';
  end if;

  select * into v_plan
  from public.plans
  where code = upper(trim(coalesce(p_plan_code, '')))
    and est_actif = true;
  if not found then
    raise exception 'PLAN_INVALIDE' using errcode = '42501';
  end if;

  v_facturation := case
    when upper(trim(coalesce(p_type_facturation, ''))) = 'SPONSORISE' then 'SPONSORISE'
    else 'COMMERCIAL'
  end;

  v_motif := coalesce(nullif(trim(p_motif), ''), 'Activation manuelle Super Admin');
  if char_length(v_motif) < 3 then
    raise exception 'MOTIF_REQUIS' using errcode = '42501';
  end if;

  if p_duree_mois is not null and p_duree_mois > 0 then
    v_date_fin := v_now + make_interval(months => p_duree_mois);
  else
    v_date_fin := null;
  end if;

  v_valeur_ref := coalesce(v_plan.prix_mensuel, 0) * greatest(coalesce(p_duree_mois, 1), 1);

  -- Clôture les abonnements en cours ou en essai existants sans violer check (date_fin > date_debut)
  update public.abonnements
  set
    statut = 'ANNULE',
    date_fin = greatest(v_now, date_debut + interval '1 second'),
    updated_at = v_now
  where entreprise_id = p_entreprise_id
    and statut in ('ESSAI', 'ACTIF', 'SUSPENDU');

  -- Insère le nouvel abonnement actif
  insert into public.abonnements (
    entreprise_id,
    plan_code,
    statut,
    type_facturation,
    sponsor_motif,
    sponsor_attribue_par,
    sponsor_attribue_le,
    valeur_commerciale_reference,
    date_debut,
    date_fin
  ) values (
    p_entreprise_id,
    v_plan.code,
    'ACTIF',
    v_facturation,
    v_motif,
    v_uid,
    v_now,
    v_valeur_ref,
    v_now,
    v_date_fin
  )
  returning id into v_ab_id;

  -- Si l'entreprise était suspendue, la réactiver lors de l'activation d'abonnement
  update public.entreprises
  set statut = 'ACTIVE', updated_at = v_now
  where id = p_entreprise_id
    and statut = 'SUSPENDUE';

  perform app.tracer_super_admin_action(
    'ACTIVATION_ABONNEMENT_ADMIN',
    'ENTREPRISE',
    p_entreprise_id::text,
    jsonb_build_object(
      'nom_entreprise', v_entreprise.nom,
      'plan_code', v_plan.code,
      'duree_mois', p_duree_mois,
      'type_facturation', v_facturation,
      'valeur_commerciale_reference', v_valeur_ref,
      'date_fin', v_date_fin,
      'motif', v_motif
    )
  );

  return jsonb_build_object(
    'success', true,
    'abonnement_id', v_ab_id,
    'plan_code', v_plan.code,
    'duree_mois', p_duree_mois,
    'type_facturation', v_facturation,
    'date_debut', v_now,
    'date_fin', v_date_fin,
    'valeur_reference', v_valeur_ref
  );
end;
$$;

grant execute on function public.admin_activer_abonnement(uuid, text, integer, text, text) to authenticated;

notify pgrst, 'reload schema';
