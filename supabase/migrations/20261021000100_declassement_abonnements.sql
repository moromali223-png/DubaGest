-- =============================================================================
-- MIGRATION : Déclassement intelligent et contrôlé des abonnements
-- Version : 20261021000100_declassement_abonnements.sql
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Table des demandes de déclassement
-- -----------------------------------------------------------------------------

create table if not exists public.demandes_declassement (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  plan_actuel_code text not null references public.plans (code),
  plan_cible_code text not null references public.plans (code),
  statut text not null default 'pending_preparation'
    check (statut in ('pending_preparation', 'ready', 'scheduled', 'applied', 'cancelled', 'blocked')),
  conforme boolean not null default false,
  date_effective_prevue timestamptz,
  details_analyse jsonb not null default '{}'::jsonb,
  anomalies jsonb not null default '[]'::jsonb,
  ajustements jsonb not null default '{}'::jsonb,
  cree_par uuid references auth.users (id) on delete set null,
  applique_par uuid references auth.users (id) on delete set null,
  applique_le timestamptz,
  motif_blocage text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists demandes_declassement_en_cours
  on public.demandes_declassement (entreprise_id)
  where statut in ('pending_preparation', 'ready', 'scheduled');

create index if not exists demandes_declassement_entreprise_idx
  on public.demandes_declassement (entreprise_id, created_at desc);

create trigger demandes_declassement_updated_at before update on public.demandes_declassement
  for each row execute function app.tg_set_updated_at();

create trigger audit_demandes_declassement after insert or update or delete on public.demandes_declassement
  for each row execute function app.tg_audit();

alter table public.demandes_declassement enable row level security;

drop policy if exists demandes_declassement_lecture on public.demandes_declassement;
create policy demandes_declassement_lecture on public.demandes_declassement
  for select to authenticated
  using (app.a_permission(entreprise_id, 'entreprise.manage') or app.est_super_admin());

grant select on public.demandes_declassement to authenticated;

-- -----------------------------------------------------------------------------
-- 2. Ajustement du trigger app.tg_verifier_perimetre()
--    Seuls les périmètres actifs (est_actif = true and deleted_at is null)
--    consomment le quota du plan. Une désactivation ne consomme pas de quota.
-- -----------------------------------------------------------------------------

create or replace function app.tg_verifier_perimetre()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_plan text;
  v_max integer;
  v_nb integer;
begin
  if tg_op = 'UPDATE' then
    if new.entreprise_id <> old.entreprise_id or new.activite_code <> old.activite_code then
      perform app.refuser('PERIMETRE_IMMUABLE');
    end if;

    -- Si le périmètre reste supprimé ou reste inactif, aucune place supplémentaire n'est requise.
    if new.deleted_at is not null or not new.est_actif then
      return new;
    end if;

    -- Si le périmètre était déjà actif et non supprimé, aucun quota supplémentaire n'est consommé.
    if old.deleted_at is null and old.est_actif then
      return new;
    end if;
  end if;

  if new.deleted_at is not null or not new.est_actif then
    return new;
  end if;

  if app.appel_client_sans_permission(new.entreprise_id, 'perimetres.manage') then
    return new;
  end if;

  perform app.verrouiller_entreprise(new.entreprise_id);
  v_plan := app.plan_courant(new.entreprise_id);
  if v_plan is null then
    perform app.refuser('ABONNEMENT_INACTIF');
  end if;

  if not exists (
    select 1 from public.entreprise_activites
    where entreprise_id = new.entreprise_id and activite_code = new.activite_code and est_active
  ) then
    perform app.refuser('ACTIVITE_INACTIVE', jsonb_build_object('activite', new.activite_code));
  end if;

  select max_perimetres into v_max
  from public.plan_activites
  where plan_code = v_plan and activite_code = new.activite_code;
  if not found then
    perform app.refuser('ACTIVITE_NON_AUTORISEE',
      jsonb_build_object('plan', v_plan, 'activite', new.activite_code));
  end if;

  select count(*) into v_nb
  from public.perimetres
  where entreprise_id = new.entreprise_id
    and activite_code = new.activite_code
    and deleted_at is null
    and est_actif
    and id <> new.id;
  if v_max is not null and v_nb >= v_max then
    perform app.refuser('LIMITE_PERIMETRES',
      jsonb_build_object('plan', v_plan, 'activite', new.activite_code, 'max', v_max));
  end if;

  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- 3. Mise à jour de get_contexte_session() pour refléter les périmètres actifs
-- -----------------------------------------------------------------------------

create or replace function public.get_contexte_session(p_entreprise_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_base jsonb;
  v_membre public.membres_entreprise%rowtype;
  v_eid uuid;
  v_plan_code text;
  v_acces_tout boolean;
begin
  if v_uid is null then
    return null;
  end if;

  v_base := jsonb_build_object(
    'server_time', now(),
    'profil', (
      select jsonb_build_object('id', p.id, 'nom_complet', p.nom_complet,
                                'telephone', p.telephone, 'langue', p.langue,
                                'prenom', p.prenom, 'nom', p.nom)
      from public.profiles p where p.id = v_uid
    ),
    'entreprises', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', e.id, 'nom', e.nom, 'statut', e.statut, 'pays', e.pays, 'devise', e.devise,
        'role_code', m.role_code, 'role_libelle', r.libelle, 'membre_statut', m.statut
      ) order by e.nom), '[]'::jsonb)
      from public.membres_entreprise m
      join public.entreprises e on e.id = m.entreprise_id
      join public.roles r on r.code = m.role_code
      where m.user_id = v_uid and m.statut = 'ACTIF' and e.statut = 'ACTIF'
    )
  );

  select m.* into v_membre
  from public.membres_entreprise m
  where m.user_id = v_uid
    and (p_entreprise_id is null or m.entreprise_id = p_entreprise_id)
  order by (m.statut = 'ACTIF') desc, m.created_at desc
  limit 1;

  if v_membre.id is null then
    return v_base || jsonb_build_object('entreprise', null, 'membre', null);
  end if;

  v_eid := v_membre.entreprise_id;
  v_acces_tout := exists (
    select 1 from public.roles_permissions
    where role_code = v_membre.role_code and permission_code = 'perimetres.access_all'
  );

  -- Abonnement courant (ou le plus récent, pour expliquer une expiration).
  select a.plan_code into v_plan_code
  from public.abonnements a
  where a.entreprise_id = v_eid
  order by (a.statut in ('ESSAI', 'ACTIF', 'SUSPENDU')) desc, a.date_debut desc
  limit 1;

  return v_base || jsonb_build_object(
    'entreprise', (
      select jsonb_build_object('id', e.id, 'nom', e.nom, 'statut', e.statut, 'pays', e.pays,
                                'devise', e.devise, 'langue_defaut', e.langue_defaut)
      from public.entreprises e where e.id = v_eid
    ),
    'membre', jsonb_build_object('id', v_membre.id, 'role_code', v_membre.role_code,
                                 'statut', v_membre.statut),
    'role', (
      select jsonb_build_object('code', r.code, 'libelle', r.libelle, 'activite_code', r.activite_code)
      from public.roles r where r.code = v_membre.role_code
    ),
    'permissions', case when v_membre.statut = 'ACTIF' then (
      select coalesce(jsonb_agg(rp.permission_code order by rp.permission_code), '[]'::jsonb)
      from public.roles_permissions rp where rp.role_code = v_membre.role_code
    ) else '[]'::jsonb end,
    'abonnement', (
      select jsonb_build_object('id', a.id, 'plan_code', a.plan_code, 'statut', a.statut,
                                'date_debut', a.date_debut, 'date_fin', a.date_fin,
                                'type_facturation', a.type_facturation,
                                'sponsor_motif', a.sponsor_motif,
                                'valeur_commerciale_reference', a.valeur_commerciale_reference)
      from public.abonnements a
      where a.entreprise_id = v_eid
      order by (a.statut in ('ESSAI', 'ACTIF', 'SUSPENDU')) desc, a.date_debut desc
      limit 1
    ),
    'plan', (
      select jsonb_build_object(
        'code', pl.code,
        'nom', pl.nom,
        'max_activites', pl.max_activites,
        'prix_mensuel', pl.prix_mensuel,
        'activites', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'activite_code', pa.activite_code,
            'max_utilisateurs', pa.max_utilisateurs,
            'max_perimetres', pa.max_perimetres) order by pa.activite_code), '[]'::jsonb)
          from public.plan_activites pa where pa.plan_code = pl.code
        ),
        'roles', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'role_code', pr.role_code, 'max_membres', pr.max_membres) order by pr.role_code), '[]'::jsonb)
          from public.plan_roles pr where pr.plan_code = pl.code
        ),
        'modules', (
          select coalesce(jsonb_agg(pm.module_code order by pm.module_code), '[]'::jsonb)
          from public.plan_modules pm where pm.plan_code = pl.code
        )
      )
      from public.plans pl where pl.code = v_plan_code
    ),
    'activites', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'code', ea.activite_code, 'est_active', ea.est_active,
        'type_perimetre_defaut', ac.type_perimetre_defaut) order by ac.ordre), '[]'::jsonb)
      from public.entreprise_activites ea
      join public.activites ac on ac.code = ea.activite_code
      where ea.entreprise_id = v_eid
    ),
    'roles', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'code', r.code, 'activite_code', r.activite_code,
        'acces_tous_perimetres', exists (
          select 1 from public.roles_permissions rp
          where rp.role_code = r.code and rp.permission_code = 'perimetres.access_all')
      ) order by r.ordre), '[]'::jsonb)
      from public.roles r
    ),
    'modules', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'code', mo.code, 'activite_code', mo.activite_code,
        'permission_acces', mo.permission_acces, 'ordre', mo.ordre, 'categorie', mo.categorie) order by mo.ordre), '[]'::jsonb)
      from public.modules mo where mo.est_actif
    ),
    'perimetres', case when v_membre.statut = 'ACTIF' then (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', p.id, 'entreprise_id', p.entreprise_id, 'activite_code', p.activite_code,
        'type', p.type, 'nom', p.nom, 'code', p.code, 'est_actif', p.est_actif,
        'version', p.version, 'updated_at', p.updated_at) order by p.nom), '[]'::jsonb)
      from public.perimetres p
      where p.entreprise_id = v_eid
        and p.deleted_at is null
        and (v_acces_tout or exists (
          select 1 from public.membre_perimetres mp
          where mp.membre_id = v_membre.id and mp.perimetre_id = p.id))
    ) else '[]'::jsonb end,
    'usage', jsonb_build_object(
      'utilisateurs', (
        select count(*) from public.membres_entreprise
        where entreprise_id = v_eid and statut = 'ACTIF'
      ),
      'membres_par_role', (
        select coalesce(jsonb_object_agg(role_code, nb), '{}'::jsonb)
        from (
          select role_code, count(*) as nb from public.membres_entreprise
          where entreprise_id = v_eid and statut = 'ACTIF' group by role_code
        ) s
      ),
      'perimetres_par_activite', (
        select coalesce(jsonb_object_agg(activite_code, nb), '{}'::jsonb)
        from (
          select activite_code, count(*) as nb from public.perimetres
          where entreprise_id = v_eid and deleted_at is null and est_actif group by activite_code
        ) s
      )
    )
  );
end;
$$;

revoke execute on function public.get_contexte_session(uuid) from public, anon;
grant execute on function public.get_contexte_session(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 4. RPC : Analyse automatique des limites de déclassement
-- -----------------------------------------------------------------------------

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

  if v_plan_cible.ordre >= v_plan_actuel.ordre then
    raise exception 'LE_PLAN_CIBLE_DOIT_ETRE_INFERIEUR' using errcode = 'P0001';
  end if;

  -- 1. Analyse des activités actives
  select coalesce(array_agg(activite_code), '{}') into v_activites_actives
  from public.entreprise_activites
  where entreprise_id = p_entreprise_id and est_active = true;

  v_nb_activites := coalesce(cardinality(v_activites_actives), 0);

  if v_nb_activites > v_plan_cible.max_activites then
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

  if not v_has_unlimited_users and v_target_max_users is not null then
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
  for v_role in (
    select pr.role_code, pr.max_membres, r.libelle as role_libelle
    from public.plan_roles pr
    join public.roles r on r.code = pr.role_code
    where pr.plan_code = v_plan_cible.code
  ) loop
    if v_role.max_membres is not null then
      select count(*) into v_nb_role
      from public.membres_entreprise
      where entreprise_id = p_entreprise_id and role_code = v_role.role_code and statut = 'ACTIF';

      if v_nb_role > v_role.max_membres then
        v_conforme := false;
        v_anomalies := v_anomalies || jsonb_build_object(
          'type', 'ROLE_LIMITE',
          'role_code', v_role.role_code,
          'message', format('Vous avez %s membres avec le rôle "%s". La formule cible n''en autorise que %s.', v_nb_role, v_role.role_libelle, v_role.max_membres),
          'actuel', v_nb_role,
          'max', v_role.max_membres,
          'exces', v_nb_role - v_role.max_membres
        );
      end if;
    end if;
  end loop;

  -- Vérifier les rôles qui ne seraient plus autorisés du tout dans le plan cible
  for v_role in (
    select distinct m.role_code, r.libelle as role_libelle, count(*) as nb
    from public.membres_entreprise m
    join public.roles r on r.code = m.role_code
    where m.entreprise_id = p_entreprise_id and m.statut = 'ACTIF'
      and not exists (
        select 1 from public.plan_roles pr
        where pr.plan_code = v_plan_cible.code and pr.role_code = m.role_code
      )
    group by m.role_code, r.libelle
  ) loop
    v_conforme := false;
    v_anomalies := v_anomalies || jsonb_build_object(
      'type', 'ROLE_NON_AUTORISE',
      'role_code', v_role.role_code,
      'message', format('Le rôle "%s" n''est pas inclus dans la formule cible (%s utilisateurs concernés).', v_role.role_libelle, v_role.nb),
      'actuel', v_role.nb,
      'max', 0,
      'exces', v_role.nb
    );
  end loop;

  -- 4. Analyse des périmètres (boutiques / agences / sites) par activité
  for v_act in (
    select ea.activite_code, ac.libelle as activite_libelle, ac.type_perimetre_defaut
    from public.entreprise_activites ea
    join public.activites ac on ac.code = ea.activite_code
    where ea.entreprise_id = p_entreprise_id and ea.est_active = true
  ) loop
    select max_perimetres into v_max_perim
    from public.plan_activites
    where plan_code = v_plan_cible.code and activite_code = v_act.activite_code;

    select count(*) into v_nb_perim
    from public.perimetres
    where entreprise_id = p_entreprise_id
      and activite_code = v_act.activite_code
      and deleted_at is null
      and est_actif = true;

    if v_max_perim is not null and v_nb_perim > v_max_perim then
      v_conforme := false;
      v_anomalies := v_anomalies || jsonb_build_object(
        'type', 'PERIMETRES_EXCEDENTAIRES',
        'activite_code', v_act.activite_code,
        'message', format('Vous avez %s %s actives pour %s. La formule cible n''en autorise que %s.',
          v_nb_perim,
          case when v_act.type_perimetre_defaut = 'BOUTIQUE' then 'boutiques' else 'sites/agences' end,
          v_act.activite_libelle,
          v_max_perim),
        'actuel', v_nb_perim,
        'max', v_max_perim,
        'exces', v_nb_perim - v_max_perim
      );
    end if;
  end loop;

  -- 5. Vérification du dernier administrateur actif indispensable
  select count(*) into v_nb_admins
  from public.membres_entreprise
  where entreprise_id = p_entreprise_id and role_code = 'ADMINISTRATEUR' and statut = 'ACTIF';

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

  return jsonb_build_object(
    'conforme', v_conforme,
    'entreprise_id', p_entreprise_id,
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

-- -----------------------------------------------------------------------------
-- 5. RPC : Demander un déclassement (création / mise à jour de la demande)
-- -----------------------------------------------------------------------------

create or replace function public.demander_declassement(
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
  v_analyse jsonb;
  v_abonnement public.abonnements%rowtype;
  v_demande public.demandes_declassement%rowtype;
  v_statut text;
  v_conforme boolean;
begin
  if v_uid is null then
    raise exception 'NON_AUTHENTIFIE' using errcode = '42501';
  end if;

  if not (app.a_permission(p_entreprise_id, 'entreprise.manage') or app.est_super_admin()) then
    raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
  end if;

  perform app.verrouiller_entreprise(p_entreprise_id);

  select * into v_abonnement
  from public.abonnements
  where entreprise_id = p_entreprise_id
  order by (statut in ('ESSAI', 'ACTIF', 'SUSPENDU')) desc, date_debut desc
  limit 1;

  if v_abonnement.id is null then
    raise exception 'AUCUN_ABONNEMENT' using errcode = 'P0001';
  end if;

  v_analyse := public.analyser_limites_declassement(p_entreprise_id, p_plan_cible);
  v_conforme := (v_analyse ->> 'conforme')::boolean;
  v_statut := case when v_conforme then 'ready' else 'pending_preparation' end;

  -- Insère ou met à jour la demande en cours
  select * into v_demande
  from public.demandes_declassement
  where entreprise_id = p_entreprise_id
    and statut in ('pending_preparation', 'ready', 'scheduled')
  limit 1;

  if v_demande.id is not null then
    update public.demandes_declassement
    set plan_actuel_code = v_abonnement.plan_code,
        plan_cible_code = p_plan_cible,
        statut = v_statut,
        conforme = v_conforme,
        details_analyse = v_analyse,
        anomalies = (v_analyse -> 'anomalies'),
        updated_at = now()
    where id = v_demande.id
    returning * into v_demande;
  else
    insert into public.demandes_declassement (
      entreprise_id, plan_actuel_code, plan_cible_code, statut, conforme,
      details_analyse, anomalies, cree_par
    ) values (
      p_entreprise_id, v_abonnement.plan_code, p_plan_cible, v_statut, v_conforme,
      v_analyse, (v_analyse -> 'anomalies'), v_uid
    )
    returning * into v_demande;
  end if;

  return jsonb_build_object(
    'demande_id', v_demande.id,
    'entreprise_id', v_demande.entreprise_id,
    'plan_actuel_code', v_demande.plan_actuel_code,
    'plan_cible_code', v_demande.plan_cible_code,
    'statut', v_demande.statut,
    'conforme', v_demande.conforme,
    'analyse', v_analyse
  );
end;
$$;

grant execute on function public.demander_declassement(uuid, text) to authenticated;

-- -----------------------------------------------------------------------------
-- 6. RPC : Ajustement unitaire des ressources (suspension / désactivation)
--    Ne supprime JAMAIS de données métier. Préserve tout l'historique.
-- -----------------------------------------------------------------------------

create or replace function public.ajuster_ressource_declassement(
  p_entreprise_id uuid,
  p_type_ressource text, -- 'UTILISATEUR', 'PERIMETRE', 'ACTIVITE'
  p_ressource_id text,
  p_action text          -- 'DESACTIVER' (ou 'SUSPENDRE'), 'ACTIVER'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_demande public.demandes_declassement%rowtype;
  v_nb_admins integer;
  v_analyse jsonb;
begin
  if v_uid is null then
    raise exception 'NON_AUTHENTIFIE' using errcode = '42501';
  end if;

  if not (app.a_permission(p_entreprise_id, 'entreprise.manage') or app.est_super_admin()) then
    raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
  end if;

  perform app.verrouiller_entreprise(p_entreprise_id);

  if p_type_ressource = 'UTILISATEUR' then
    if p_action in ('DESACTIVER', 'SUSPENDRE') then
      -- Vérification stricte : ne jamais suspendre le dernier administrateur actif
      select count(*) into v_nb_admins
      from public.membres_entreprise
      where entreprise_id = p_entreprise_id
        and role_code = 'ADMINISTRATEUR'
        and statut = 'ACTIF'
        and id <> p_ressource_id::uuid;

      if exists (
        select 1 from public.membres_entreprise
        where id = p_ressource_id::uuid and entreprise_id = p_entreprise_id and role_code = 'ADMINISTRATEUR'
      ) and v_nb_admins < 1 then
        raise exception 'DERNIER_ADMINISTRATEUR_PROTEGE' using errcode = 'P0001';
      end if;

      update public.membres_entreprise
      set statut = 'SUSPENDU', updated_at = now()
      where id = p_ressource_id::uuid and entreprise_id = p_entreprise_id;
    elsif p_action = 'ACTIVER' then
      update public.membres_entreprise
      set statut = 'ACTIF', updated_at = now()
      where id = p_ressource_id::uuid and entreprise_id = p_entreprise_id;
    end if;

  elsif p_type_ressource = 'PERIMETRE' then
    if p_action = 'DESACTIVER' then
      update public.perimetres
      set est_actif = false, updated_at = now()
      where id = p_ressource_id::uuid and entreprise_id = p_entreprise_id;
    elsif p_action = 'ACTIVER' then
      update public.perimetres
      set est_actif = true, updated_at = now()
      where id = p_ressource_id::uuid and entreprise_id = p_entreprise_id;
    end if;

  elsif p_type_ressource = 'ACTIVITE' then
    if p_action = 'DESACTIVER' then
      update public.entreprise_activites
      set est_active = false, desactivee_le = now(), updated_at = now()
      where activite_code = p_ressource_id and entreprise_id = p_entreprise_id;
    elsif p_action = 'ACTIVER' then
      update public.entreprise_activites
      set est_active = true, desactivee_le = null, updated_at = now()
      where activite_code = p_ressource_id and entreprise_id = p_entreprise_id;
    end if;
  else
    raise exception 'TYPE_RESSOURCE_INCONNU' using errcode = 'P0001';
  end if;

  -- Re-calcule automatiquement la conformité pour la demande en cours
  select * into v_demande
  from public.demandes_declassement
  where entreprise_id = p_entreprise_id
    and statut in ('pending_preparation', 'ready')
  limit 1;

  if v_demande.id is not null then
    v_analyse := public.analyser_limites_declassement(p_entreprise_id, v_demande.plan_cible_code);
    update public.demandes_declassement
    set conforme = (v_analyse ->> 'conforme')::boolean,
        statut = case when (v_analyse ->> 'conforme')::boolean then 'ready' else 'pending_preparation' end,
        details_analyse = v_analyse,
        anomalies = (v_analyse -> 'anomalies'),
        updated_at = now()
    where id = v_demande.id
    returning * into v_demande;
  end if;

  return jsonb_build_object(
    'succes', true,
    'demande', case when v_demande.id is not null then jsonb_build_object(
      'id', v_demande.id,
      'statut', v_demande.statut,
      'conforme', v_demande.conforme,
      'anomalies', v_demande.anomalies
    ) else null end
  );
end;
$$;

grant execute on function public.ajuster_ressource_declassement(uuid, text, text, text) to authenticated;

-- -----------------------------------------------------------------------------
-- 7. RPC : Validation finale et application sécurisée du déclassement
--    Transaction atomique protégée contre les états incohérents et la concurrence.
--    Respecte intégralement le statut de parrainage / accès sponsorisé (0 FCFA).
-- -----------------------------------------------------------------------------

create or replace function public.valider_et_appliquer_declassement(
  p_demande_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_demande public.demandes_declassement%rowtype;
  v_abonnement_actuel public.abonnements%rowtype;
  v_plan_cible public.plans%rowtype;
  v_analyse jsonb;
  v_conforme boolean;
  v_nouveau_id uuid;
begin
  if v_uid is null then
    raise exception 'NON_AUTHENTIFIE' using errcode = '42501';
  end if;

  -- Verrouillage de la demande
  select * into v_demande
  from public.demandes_declassement
  where id = p_demande_id
  for update;

  if v_demande.id is null then
    raise exception 'DEMANDE_INTROUVABLE' using errcode = 'P0001';
  end if;

  if v_demande.statut = 'applied' then
    return jsonb_build_object(
      'succes', true,
      'message', 'Cette demande a déjà été appliquée.',
      'plan_code', v_demande.plan_cible_code
    );
  end if;

  if not (app.a_permission(v_demande.entreprise_id, 'entreprise.manage') or app.est_super_admin()) then
    raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
  end if;

  perform app.verrouiller_entreprise(v_demande.entreprise_id);

  -- Re-contrôle strict de toutes les limites en temps réel
  v_analyse := public.analyser_limites_declassement(v_demande.entreprise_id, v_demande.plan_cible_code);
  v_conforme := (v_analyse ->> 'conforme')::boolean;

  if not v_conforme then
    update public.demandes_declassement
    set statut = 'pending_preparation',
        conforme = false,
        details_analyse = v_analyse,
        anomalies = (v_analyse -> 'anomalies'),
        updated_at = now()
    where id = v_demande.id;

    return jsonb_build_object(
      'succes', false,
      'code', 'LIMITES_NON_RESPECTEES',
      'message', 'Des limites ne sont pas encore respectées pour finaliser le déclassement.',
      'anomalies', (v_analyse -> 'anomalies')
    );
  end if;

  -- Récupération du plan cible et de l'abonnement actuel
  select * into v_plan_cible from public.plans where code = v_demande.plan_cible_code;
  select * into v_abonnement_actuel
  from public.abonnements
  where entreprise_id = v_demande.entreprise_id
    and statut in ('ESSAI', 'ACTIF', 'SUSPENDU')
  order by date_debut desc
  limit 1
  for update;

  if v_abonnement_actuel.id is null then
    raise exception 'ABONNEMENT_ACTUEL_MANQUANT' using errcode = 'P0001';
  end if;

  -- 1. Clôture propre de l'ancien abonnement
  update public.abonnements
  set statut = 'EXPIRE',
      date_fin = now(),
      updated_at = now()
  where id = v_abonnement_actuel.id;

  -- 2. Activation du nouvel abonnement avec conservation stricte du parrainage le cas échéant
  insert into public.abonnements (
    entreprise_id,
    plan_code,
    statut,
    date_debut,
    date_fin,
    type_facturation,
    sponsor_motif,
    sponsor_attribue_par,
    sponsor_attribue_le,
    valeur_commerciale_reference
  ) values (
    v_demande.entreprise_id,
    v_demande.plan_cible_code,
    'ACTIF',
    now(),
    case
      -- Si formule payante avec fin de période déjà réglée, on conserve le terme payé
      when v_abonnement_actuel.date_fin is not null and v_abonnement_actuel.date_fin > now()
      then v_abonnement_actuel.date_fin
      else null
    end,
    v_abonnement_actuel.type_facturation, -- 'COMMERCIAL' ou 'SPONSORISE' (préservé intact)
    v_abonnement_actuel.sponsor_motif,
    v_abonnement_actuel.sponsor_attribue_par,
    v_abonnement_actuel.sponsor_attribue_le,
    v_plan_cible.prix_mensuel
  )
  returning id into v_nouveau_id;

  -- 3. Marquer la demande comme appliquée
  update public.demandes_declassement
  set statut = 'applied',
      conforme = true,
      applique_par = v_uid,
      applique_le = now(),
      updated_at = now()
  where id = v_demande.id;

  -- 4. Traces d'audit
  insert into public.audit_logs (
    entreprise_id, user_id, entite_type, entite_id, action,
    donnees_avant, donnees_apres
  ) values (
    v_demande.entreprise_id,
    v_uid,
    'abonnements',
    v_nouveau_id,
    'DECLASSEMENT',
    jsonb_build_object(
      'plan_code', v_abonnement_actuel.plan_code,
      'type_facturation', v_abonnement_actuel.type_facturation,
      'valeur_commerciale_reference', v_abonnement_actuel.valeur_commerciale_reference
    ),
    jsonb_build_object(
      'plan_code', v_demande.plan_cible_code,
      'type_facturation', v_abonnement_actuel.type_facturation,
      'valeur_commerciale_reference', v_plan_cible.prix_mensuel,
      'demande_id', v_demande.id
    )
  );

  return jsonb_build_object(
    'succes', true,
    'message', format('L''abonnement a été déclassé avec succès vers la formule %s.', v_plan_cible.nom),
    'plan_code', v_demande.plan_cible_code,
    'type_facturation', v_abonnement_actuel.type_facturation,
    'nouvel_abonnement_id', v_nouveau_id
  );
end;
$$;

grant execute on function public.valider_et_appliquer_declassement(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 8. RPC : Annuler une demande de déclassement
--    Ne rétablit pas automatiquement les ressources désactivées (action manuelle requise).
-- -----------------------------------------------------------------------------

create or replace function public.annuler_demande_declassement(
  p_demande_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_demande public.demandes_declassement%rowtype;
begin
  if v_uid is null then
    raise exception 'NON_AUTHENTIFIE' using errcode = '42501';
  end if;

  select * into v_demande
  from public.demandes_declassement
  where id = p_demande_id;

  if v_demande.id is null then
    raise exception 'DEMANDE_INTROUVABLE' using errcode = 'P0001';
  end if;

  if not (app.a_permission(v_demande.entreprise_id, 'entreprise.manage') or app.est_super_admin()) then
    raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
  end if;

  if v_demande.statut = 'applied' then
    raise exception 'DEMANDE_DEJA_APPLIQUEE' using errcode = 'P0001';
  end if;

  update public.demandes_declassement
  set statut = 'cancelled', updated_at = now()
  where id = p_demande_id;

  return jsonb_build_object('succes', true);
end;
$$;

grant execute on function public.annuler_demande_declassement(uuid) to authenticated;
