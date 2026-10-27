-- =============================================================================
-- Migration : Correction des permissions pour l'invitation et la gestion des membres
-- =============================================================================

-- Corrige creer_invitation : utilise la permission 'users.invite'
create or replace function public.creer_invitation(
  p_entreprise_id uuid,
  p_email text,
  p_role_code text,
  p_perimetre_ids uuid[] default '{}',
  p_validite_jours integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_email text := lower(trim(p_email));
  v_plan text;
  v_role record;
  v_quota smallint;
  v_max integer;
  v_nb integer;
  v_acces_tous boolean;
  v_id uuid;
  v_pid uuid;
  v_expires timestamptz;
  v_pin text;
  v_resolved_pids uuid[] := coalesce(p_perimetre_ids, '{}');
begin
  if v_uid is null then
    perform app.refuser('NON_AUTHENTIFIE');
  end if;

  if not app.a_permission(p_entreprise_id, 'users.invite') then
    perform app.refuser('PERMISSION_REFUSEE', jsonb_build_object('permission', 'users.invite'));
  end if;

  if v_email !~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$' then
    perform app.refuser('EMAIL_INVALIDE');
  end if;

  perform app.verrouiller_entreprise(p_entreprise_id);

  v_plan := app.plan_courant(p_entreprise_id);
  if v_plan is null then
    perform app.refuser('ABONNEMENT_INACTIF');
  end if;

  if exists (
    select 1 from public.membres_entreprise m
    join auth.users u on u.id = m.user_id
    where m.entreprise_id = p_entreprise_id and lower(u.email) = v_email
  ) then
    perform app.refuser('DEJA_MEMBRE');
  end if;

  select * into v_role from public.roles where code = p_role_code;
  select max_membres into v_quota from public.plan_roles
  where plan_code = v_plan and role_code = p_role_code;
  if v_role.code is null then
    perform app.refuser('ROLE_NON_AUTORISE', jsonb_build_object('plan', v_plan, 'role', p_role_code));
  end if;
  if v_role.activite_code is not null and not exists (
    select 1 from public.entreprise_activites
    where entreprise_id = p_entreprise_id and activite_code = v_role.activite_code and est_active
  ) then
    perform app.refuser('ROLE_ACTIVITE_INACTIVE', jsonb_build_object('role', p_role_code));
  end if;

  -- Remplacer toute invitation en attente pour cette même adresse
  update public.invitations set statut = 'CANCELLED', cancelled_at = now()
  where entreprise_id = p_entreprise_id and email = v_email and statut = 'PENDING';

  -- Contrôle des quotas rôle
  select count(*) into v_nb from (
    select 1 from public.membres_entreprise
    where entreprise_id = p_entreprise_id and statut = 'ACTIF' and role_code = p_role_code
    union all
    select 1 from public.invitations
    where entreprise_id = p_entreprise_id and statut = 'PENDING'
      and expires_at > now() and role_code = p_role_code
  ) s;
  if v_quota is not null and v_nb >= v_quota then
    perform app.refuser('LIMITE_ROLE', jsonb_build_object('plan', v_plan, 'role', p_role_code, 'max', v_quota));
  end if;

  -- Contrôle des quotas globaux utilisateurs
  v_max := app.max_utilisateurs(p_entreprise_id, v_plan);
  select count(*) into v_nb from (
    select 1 from public.membres_entreprise
    where entreprise_id = p_entreprise_id and statut = 'ACTIF'
    union all
    select 1 from public.invitations
    where entreprise_id = p_entreprise_id and statut = 'PENDING' and expires_at > now()
  ) s;
  if v_max is not null and v_nb >= v_max then
    perform app.refuser('LIMITE_UTILISATEURS', jsonb_build_object('plan', v_plan, 'max', v_max));
  end if;

  -- Périmètres : obligatoires pour un rôle restreint (ex. VENDEUR), interdits pour un accès global
  v_acces_tous := exists (
    select 1 from public.roles_permissions
    where role_code = p_role_code and permission_code = 'perimetres.access_all'
  );
  if v_acces_tous and coalesce(cardinality(v_resolved_pids), 0) > 0 then
    perform app.refuser('AFFECTATION_INUTILE', jsonb_build_object('role', p_role_code));
  end if;

  -- RÈGLE MÉTIER VENDEUR / RÔLES RESTREINTS :
  -- Si aucun périmètre n'est fourni, affecter automatiquement la boutique principale
  if not v_acces_tous and coalesce(cardinality(v_resolved_pids), 0) = 0 then
    select array_agg(id) into v_resolved_pids from (
      select p.id from public.perimetres p
      where p.entreprise_id = p_entreprise_id
        and (p.activite = coalesce(v_role.activite_code, 'COMMERCE') or p.activite = 'COMMERCE')
        and p.deleted_at is null
      order by p.created_at asc
      limit 1
    ) sub;

    if coalesce(cardinality(v_resolved_pids), 0) = 0 then
      select array_agg(id) into v_resolved_pids from (
        select p.id from public.perimetres p
        where p.entreprise_id = p_entreprise_id
          and p.deleted_at is null
        order by p.created_at asc
        limit 1
      ) sub2;
    end if;

    if coalesce(cardinality(v_resolved_pids), 0) = 0 then
      perform app.refuser('AUCUNE_BOUTIQUE_DISPONIBLE');
    end if;
  end if;

  -- Génération d'un code PIN à 6 chiffres
  v_pin := lpad((floor(random() * 900000) + 100000)::text, 6, '0');
  v_expires := now() + interval '5 minutes';

  insert into public.invitations (
    entreprise_id, email, role_code, token_hash, expires_at, created_by
  )
  values (
    p_entreprise_id, v_email, p_role_code, app.hash_jeton(v_pin), v_expires, v_uid
  )
  returning id into v_id;

  if not v_acces_tous then
    foreach v_pid in array v_resolved_pids loop
      if not exists (
        select 1 from public.perimetres
        where id = v_pid and entreprise_id = p_entreprise_id and deleted_at is null
      ) then
        perform app.refuser('PERIMETRE_INVALIDE', jsonb_build_object('perimetre_id', v_pid));
      end if;
      insert into public.invitation_perimetres (invitation_id, entreprise_id, perimetre_id)
      values (v_id, p_entreprise_id, v_pid);
    end loop;
  end if;

  return jsonb_build_object(
    'id', v_id,
    'token', v_pin,
    'expires_at', v_expires
  );
end;
$$;

-- Corrige modifier_membre : utilise la permission 'users.manage'
create or replace function public.modifier_membre(
  p_entreprise_id uuid,
  p_membre_id uuid,
  p_role_code text,
  p_perimetre_ids uuid[] default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_membre record;
  v_role record;
  v_acces_tous boolean;
  v_pid uuid;
  v_resolved_pids uuid[] := coalesce(p_perimetre_ids, '{}');
begin
  if auth.uid() is null then
    perform app.refuser('NON_AUTHENTIFIE');
  end if;

  if not app.a_permission(p_entreprise_id, 'users.manage') then
    perform app.refuser('PERMISSION_REFUSEE', jsonb_build_object('permission', 'users.manage'));
  end if;

  perform app.verrouiller_entreprise(p_entreprise_id);

  select * into v_membre from public.membres_entreprise
  where id = p_membre_id and entreprise_id = p_entreprise_id;
  if not found then
    perform app.refuser('MEMBRE_INTROUVABLE');
  end if;

  select * into v_role from public.roles where code = p_role_code;
  if not found then
    perform app.refuser('ROLE_INVALIDE');
  end if;

  -- 1. Mise à jour du rôle
  if v_membre.role_code <> p_role_code then
    update public.membres_entreprise
    set role_code = p_role_code,
        updated_at = now()
    where id = p_membre_id;
  end if;

  -- 2. Synchronisation des périmètres
  v_acces_tous := exists (
    select 1 from public.roles_permissions
    where role_code = p_role_code and permission_code = 'perimetres.access_all'
  );

  if v_acces_tous then
    delete from public.membre_perimetres
    where membre_id = p_membre_id and entreprise_id = p_entreprise_id;
  else
    if coalesce(cardinality(v_resolved_pids), 0) = 0 and not exists (
      select 1 from public.membre_perimetres where membre_id = p_membre_id and entreprise_id = p_entreprise_id
    ) then
      select array_agg(id) into v_resolved_pids from (
        select p.id from public.perimetres p
        where p.entreprise_id = p_entreprise_id
          and (p.activite = coalesce(v_role.activite_code, 'COMMERCE') or p.activite = 'COMMERCE')
          and p.deleted_at is null
        order by p.created_at asc
        limit 1
      ) sub;
    end if;

    if cardinality(v_resolved_pids) > 0 then
      delete from public.membre_perimetres
      where membre_id = p_membre_id
        and entreprise_id = p_entreprise_id
        and not (perimetre_id = any(v_resolved_pids));

      foreach v_pid in array v_resolved_pids loop
        if exists (
          select 1 from public.perimetres
          where id = v_pid
            and entreprise_id = p_entreprise_id
            and deleted_at is null
        ) then
          insert into public.membre_perimetres (entreprise_id, membre_id, perimetre_id)
          values (p_entreprise_id, p_membre_id, v_pid)
          on conflict do nothing;
        end if;
      end loop;
    end if;
  end if;
end;
$$;
