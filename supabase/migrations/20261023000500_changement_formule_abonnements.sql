-- =============================================================================
-- Migration: Changement de formule d'abonnement bidirectionnel (Upgrade & Downgrade)
-- Permet aux entreprises :
-- 1. De surclasser leur abonnement (Upgrade, ex: NORMAL -> MOYEN -> PRO)
--    -> Débloque immédiatement plus de privilèges (quotas étendus, boutiques, activités).
-- 2. De déclasser leur abonnement (Downgrade, ex: PRO -> MOYEN -> NORMAL)
--    -> Assiste l'utilisateur via une checklist de conformité sans perte de données.
-- =============================================================================

create or replace function public.analyser_limites_declassement(
  p_entreprise_id uuid,
  p_plan_cible text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_abonnement public.abonnements%rowtype;
  v_plan_actuel public.plans%rowtype;
  v_plan_cible public.plans%rowtype;
  v_anomalies jsonb := '[]'::jsonb;
  v_activites_actives text[];
  v_nb_activites integer;
  v_utilisateurs_actifs integer;
  v_target_max_users integer;
  v_has_unlimited_users boolean := false;
  v_act record;
  v_role record;
  v_nb_perim integer;
  v_max_perim integer;
  v_nb_role integer;
  v_max_role integer;
  v_nb_admins integer;
  v_conforme boolean := true;
  v_est_surclassement boolean := false;
begin
  if v_uid is null then
    raise exception 'NON_AUTHENTIFIE' using errcode = '42501';
  end if;

  if not (app.a_permission(p_entreprise_id, 'entreprise.manage') or app.est_super_admin()) then
    raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
  end if;

  -- Abonnement courant
  select * into v_abonnement
  from public.abonnements
  where entreprise_id = p_entreprise_id
  order by (statut in ('ESSAI', 'ACTIF', 'SUSPENDU')) desc, date_debut desc
  limit 1;

  if v_abonnement.id is null then
    raise exception 'AUCUN_ABONNEMENT' using errcode = 'P0001';
  end if;

  select * into v_plan_actuel from public.plans where code = v_abonnement.plan_code;
  select * into v_plan_cible from public.plans where code = p_plan_cible;

  if v_plan_cible.code is null then
    raise exception 'PLAN_CIBLE_INTROUVABLE' using errcode = 'P0001';
  end if;

  if v_plan_cible.code = v_plan_actuel.code then
    raise exception 'MEME_PLAN' using errcode = 'P0001';
  end if;

  v_est_surclassement := (v_plan_cible.ordre > v_plan_actuel.ordre);

  -- 1. Analyse des activités actives
  select coalesce(array_agg(activite_code), '{}') into v_activites_actives
  from public.entreprise_activites
  where entreprise_id = p_entreprise_id and est_active = true;

  v_nb_activites := coalesce(cardinality(v_activites_actives), 0);

  if not v_est_surclassement and v_nb_activites > v_plan_cible.max_activites then
    v_conforme := false;
    v_anomalies := v_anomalies || jsonb_build_object(
      'type', 'ACTIVITES_EXCEDENTAIRES',
      'message', format('Vous avez %s activités actives. La formule %s n''en autorise que %s.', v_nb_activites, v_plan_cible.nom, v_plan_cible.max_activites),
      'actuel', v_nb_activites,
      'max', v_plan_cible.max_activites,
      'exces', v_nb_activites - v_plan_cible.max_activites
    );
  end if;

  -- Vérifier si chaque activité active est supportée par le plan cible
  for v_act in (
    select ea.activite_code, ac.libelle
    from public.entreprise_activites ea
    join public.activites ac on ac.code = ea.activite_code
    where ea.entreprise_id = p_entreprise_id and ea.est_active = true
  ) loop
    if not exists (
      select 1 from public.plan_activites pa
      where pa.plan_code = v_plan_cible.code and pa.activite_code = v_act.activite_code
    ) then
      v_conforme := false;
      v_anomalies := v_anomalies || jsonb_build_object(
        'type', 'ACTIVITE_NON_AUTORISEE',
        'activite_code', v_act.activite_code,
        'message', format('L''activité %s n''est pas autorisée par la formule %s.', v_act.libelle, v_plan_cible.nom),
        'actuel', 1,
        'max', 0,
        'exces', 1
      );
    end if;
  end loop;

  -- 2. Analyse des utilisateurs actifs
  select count(*) into v_utilisateurs_actifs
  from public.membres_entreprise
  where entreprise_id = p_entreprise_id and statut = 'ACTIF';

  -- Calcul du max_utilisateurs cible pour les activités actives
  select bool_or(pa.max_utilisateurs is null), coalesce(max(pa.max_utilisateurs), 1)
  into v_has_unlimited_users, v_target_max_users
  from public.plan_activites pa
  join public.entreprise_activites ea
    on ea.activite_code = pa.activite_code
   and ea.entreprise_id = p_entreprise_id
   and ea.est_active
  where pa.plan_code = v_plan_cible.code;

  if not v_est_surclassement and not v_has_unlimited_users and v_target_max_users is not null then
    if v_utilisateurs_actifs > v_target_max_users then
      v_conforme := false;
      v_anomalies := v_anomalies || jsonb_build_object(
        'type', 'UTILISATEURS_EXCEDENTAIRES',
        'message', format('Vous avez %s utilisateurs actifs. La formule %s en autorise au maximum %s.', v_utilisateurs_actifs, v_plan_cible.nom, v_target_max_users),
        'actuel', v_utilisateurs_actifs,
        'max', v_target_max_users,
        'exces', v_utilisateurs_actifs - v_target_max_users
      );
    end if;
  end if;

  -- 3. Analyse des quotas de rôles
  if not v_est_surclassement then
    for v_role in (
      select pr.role_code, pr.max_membres, r.libelle as role_libelle
      from public.plan_roles pr
      join public.roles r on r.code = pr.role_code
      where pr.plan_code = v_plan_cible.code
    ) loop
      if v_role.max_membres is not null then
        select count(*) into v_nb_role
        from public.membres_entreprise
        where entreprise_id = p_entreprise_id
          and role_code = v_role.role_code
          and statut = 'ACTIF';

        if v_nb_role > v_role.max_membres then
          v_conforme := false;
          v_anomalies := v_anomalies || jsonb_build_object(
            'type', 'ROLE_LIMITE',
            'role_code', v_role.role_code,
            'message', format('Le rôle %s compte %s membres actifs pour un maximum autorisé de %s.', v_role.role_libelle, v_nb_role, v_role.max_membres),
            'actuel', v_nb_role,
            'max', v_role.max_membres,
            'exces', v_nb_role - v_role.max_membres
          );
        end if;
      end if;
    end loop;
  end if;

  -- 4. Analyse des boutiques / périmètres par activité
  if not v_est_surclassement then
    for v_act in (
      select ea.activite_code, ac.libelle
      from public.entreprise_activites ea
      join public.activites ac on ac.code = ea.activite_code
      where ea.entreprise_id = p_entreprise_id and ea.est_active = true
    ) loop
      select pa.max_perimetres into v_max_perim
      from public.plan_activites pa
      where pa.plan_code = v_plan_cible.code and pa.activite_code = v_act.activite_code;

      if v_max_perim is not null then
        select count(*) into v_nb_perim
        from public.perimetres
        where entreprise_id = p_entreprise_id
          and activite_code = v_act.activite_code
          and deleted_at is null
          and est_actif = true;

        if v_nb_perim > v_max_perim then
          v_conforme := false;
          v_anomalies := v_anomalies || jsonb_build_object(
            'type', 'PERIMETRES_EXCEDENTAIRES',
            'activite_code', v_act.activite_code,
            'message', format('Activité %s : %s boutiques/sites actifs pour un quota autorisé de %s.', v_act.libelle, v_nb_perim, v_max_perim),
            'actuel', v_nb_perim,
            'max', v_max_perim,
            'exces', v_nb_perim - v_max_perim
          );
        end if;
      end if;
    end loop;
  end if;

  -- 5. Sécurité : au moins un administrateur actif doit toujours être conservé
  select count(*) into v_nb_admins
  from public.membres_entreprise
  where entreprise_id = p_entreprise_id
    and role_code = 'ADMINISTRATEUR'
    and statut = 'ACTIF';

  if v_nb_admins < 1 then
    v_conforme := false;
    v_anomalies := v_anomalies || jsonb_build_object(
      'type', 'DERNIER_ADMINISTRATEUR',
      'message', 'L''entreprise doit conserver au moins un administrateur actif.',
      'actuel', 0,
      'max', 1,
      'exces', 0
    );
  end if;

  -- En cas de surclassement, la conformité est immédiate
  if v_est_surclassement then
    v_conforme := true;
    v_anomalies := '[]'::jsonb;
  end if;

  return jsonb_build_object(
    'conforme', v_conforme,
    'entreprise_id', p_entreprise_id,
    'est_surclassement', v_est_surclassement,
    'type_changement', case when v_est_surclassement then 'SURCLASSEMENT' else 'DECLASSEMENT' end,
    'plan_actuel', jsonb_build_object(
      'code', v_plan_actuel.code,
      'nom', v_plan_actuel.nom,
      'prix_mensuel', v_plan_actuel.prix_mensuel,
      'max_activites', v_plan_actuel.max_activites
    ),
    'plan_cible', jsonb_build_object(
      'code', v_plan_cible.code,
      'nom', v_plan_cible.nom,
      'prix_mensuel', v_plan_cible.prix_mensuel,
      'max_activites', v_plan_cible.max_activites
    ),
    'type_facturation', v_abonnement.type_facturation,
    'sponsor_motif', v_abonnement.sponsor_motif,
    'valeur_commerciale_reference', v_plan_cible.prix_mensuel,
    'montant_du', case when v_abonnement.type_facturation = 'SPONSORISE' then 0 else v_plan_cible.prix_mensuel end,
    'usage_actuel', jsonb_build_object(
      'utilisateurs_actifs', v_utilisateurs_actifs,
      'activites_actives', v_activites_actives,
      'nb_activites_actives', v_nb_activites,
      'perimetres_actifs_par_activite', (
        select coalesce(jsonb_object_agg(activite_code, nb), '{}'::jsonb)
        from (
          select activite_code, count(*) as nb
          from public.perimetres
          where entreprise_id = p_entreprise_id and deleted_at is null and est_actif = true
          group by activite_code
        ) s
      )
    ),
    'limites_cible', jsonb_build_object(
      'max_activites', v_plan_cible.max_activites,
      'max_utilisateurs', v_target_max_users,
      'utilisateurs_illimites', v_has_unlimited_users
    ),
    'anomalies', v_anomalies
  );
end;
$$;

grant execute on function public.analyser_limites_declassement(uuid, text) to authenticated;
