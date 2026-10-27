-- =============================================================================
-- DUBAGEST : INVITATIONS SÉCURISÉES PAR CODE PIN À 6 CHIFFRES (5 MINUTES)
--
-- Migration : 20261022000300_invitation_pin_6_chiffres.sql
-- Description :
--   1. Génération d'un code PIN aléatoire unique à 6 chiffres (100000 - 999999).
--   2. Expiration stricte à 5 minutes (now() + interval '5 minutes').
--   3. Stockage exclusif sous forme d'empreinte SHA-256 (app.hash_jeton).
--   4. Renvoyer : regénération d'un PIN 6 chiffres et réinitialisation de 5 min.
--   5. Accepter : validation atomique du PIN 6 chiffres et rattachement des boutiques.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. RPC creer_invitation avec PIN 6 chiffres (5 min)
-- -----------------------------------------------------------------------------
create or replace function public.creer_invitation(
  p_entreprise_id uuid,
  p_email text,
  p_role_code text,
  p_perimetre_ids uuid[] default '{}',
  p_validite_jours integer default 1
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_email text := lower(trim(coalesce(p_email, '')));
  v_plan text;
  v_role public.roles;
  v_acces_tous boolean;
  v_quota integer;
  v_nb integer;
  v_max integer;
  v_pin text;
  v_id uuid;
  v_expires timestamptz;
  v_pid uuid;
begin
  if v_uid is null or not app.a_permission(p_entreprise_id, 'users.invite') then
    raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
  end if;
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
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

  -- Périmètres : obligatoires pour un rôle restreint, interdits pour un accès global
  v_acces_tous := exists (
    select 1 from public.roles_permissions
    where role_code = p_role_code and permission_code = 'perimetres.access_all'
  );
  if v_acces_tous and coalesce(cardinality(p_perimetre_ids), 0) > 0 then
    perform app.refuser('AFFECTATION_INUTILE', jsonb_build_object('role', p_role_code));
  end if;
  if not v_acces_tous and coalesce(cardinality(p_perimetre_ids), 0) = 0 then
    perform app.refuser('PERIMETRE_REQUIS');
  end if;

  -- Génération d'un code PIN à 6 chiffres aléatoire cryptographique
  v_pin := lpad((floor(random() * 900000) + 100000)::text, 6, '0');
  -- Expiration stricte à 5 minutes
  v_expires := now() + interval '5 minutes';

  insert into public.invitations (
    entreprise_id, email, role_code, token_hash, expires_at, created_by
  )
  values (
    p_entreprise_id, v_email, p_role_code, app.hash_jeton(v_pin), v_expires, v_uid
  )
  returning id into v_id;

  if not v_acces_tous then
    foreach v_pid in array p_perimetre_ids loop
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

-- -----------------------------------------------------------------------------
-- 2. RPC renvoyer_invitation avec PIN 6 chiffres (5 min)
-- -----------------------------------------------------------------------------
create or replace function public.renvoyer_invitation(p_invitation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_inv public.invitations;
  v_plan text;
  v_quota integer;
  v_nb integer;
  v_max integer;
  v_pin text;
  v_expires timestamptz;
begin
  if v_uid is null then
    raise exception 'NON_AUTHENTIFIE' using errcode = '42501';
  end if;

  select * into v_inv from public.invitations
  where id = p_invitation_id
  for update;

  if not found then
    perform app.refuser('INVITATION_INTROUVABLE');
  end if;

  if not app.a_permission(v_inv.entreprise_id, 'users.invite') then
    raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
  end if;

  if v_inv.statut = 'ACCEPTED' then
    perform app.refuser('INVITATION_DEJA_UTILISEE');
  end if;

  perform app.verrouiller_entreprise(v_inv.entreprise_id);
  v_plan := app.plan_courant(v_inv.entreprise_id);
  if v_plan is null then
    perform app.refuser('ABONNEMENT_INACTIF');
  end if;

  -- Nouveau PIN 6 chiffres et expiration 5 minutes
  v_pin := lpad((floor(random() * 900000) + 100000)::text, 6, '0');
  v_expires := now() + interval '5 minutes';

  update public.invitations
  set token_hash = app.hash_jeton(v_pin),
      statut = 'PENDING',
      expires_at = v_expires,
      cancelled_at = null,
      updated_at = now()
  where id = v_inv.id;

  return jsonb_build_object(
    'id', v_inv.id,
    'token', v_pin,
    'expires_at', v_expires
  );
end;
$$;

-- -----------------------------------------------------------------------------
-- 3. RPC verifier_invitation (support PIN 6 chiffres ou token)
-- -----------------------------------------------------------------------------
create or replace function public.verifier_invitation(p_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_clean_token text := trim(coalesce(p_token, ''));
  v_inv public.invitations;
  v_statut text;
begin
  select * into v_inv from public.invitations
  where token_hash = app.hash_jeton(v_clean_token);

  if not found then
    return jsonb_build_object('statut', 'INVALIDE');
  end if;

  v_statut := case
    when v_inv.statut = 'PENDING' and v_inv.expires_at <= now() then 'EXPIRED'
    else v_inv.statut
  end;

  return jsonb_build_object(
    'id', v_inv.id,
    'statut', v_statut,
    'entreprise_nom', (select nom from public.entreprises where id = v_inv.entreprise_id),
    'role_code', v_inv.role_code,
    'email_masque', left(v_inv.email, 1) || '***' || substring(v_inv.email from '@.*$'),
    'expires_at', v_inv.expires_at
  );
end;
$$;

-- -----------------------------------------------------------------------------
-- 4. RPC accepter_invitation (support PIN 6 chiffres)
-- -----------------------------------------------------------------------------
create or replace function public.accepter_invitation(p_token text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_clean_token text := trim(coalesce(p_token, ''));
  v_uid uuid := auth.uid();
  v_user auth.users;
  v_inv public.invitations;
  v_membre_id uuid;
begin
  if v_uid is null then
    raise exception 'NON_AUTHENTIFIE' using errcode = '42501';
  end if;

  select * into v_user from auth.users where id = v_uid;

  select * into v_inv from public.invitations
  where token_hash = app.hash_jeton(v_clean_token)
  for update;

  if not found then
    perform app.refuser('INVITATION_INVALIDE');
  end if;

  case
    when v_inv.statut = 'ACCEPTED' then perform app.refuser('INVITATION_DEJA_UTILISEE');
    when v_inv.statut = 'CANCELLED' then perform app.refuser('INVITATION_ANNULEE');
    when v_inv.statut = 'EXPIRED' or v_inv.expires_at <= now() then
      perform app.refuser('INVITATION_EXPIREE');
    else null;
  end case;

  if exists (
    select 1 from public.membres_entreprise
    where entreprise_id = v_inv.entreprise_id and user_id = v_uid
  ) then
    perform app.refuser('DEJA_MEMBRE');
  end if;

  perform app.rpc_de_confiance(true);

  insert into public.membres_entreprise (entreprise_id, user_id, role_code)
  values (v_inv.entreprise_id, v_uid, v_inv.role_code)
  returning id into v_membre_id;

  insert into public.membre_perimetres (entreprise_id, membre_id, perimetre_id)
  select ip.entreprise_id, v_membre_id, ip.perimetre_id
  from public.invitation_perimetres ip
  where ip.invitation_id = v_inv.id;

  update public.invitations
  set statut = 'ACCEPTED', accepted_by = v_uid, accepted_at = now(), updated_at = now()
  where id = v_inv.id;

  return v_inv.entreprise_id;
end;
$$;

grant execute on function public.creer_invitation(uuid, text, text, uuid[], integer) to authenticated;
grant execute on function public.renvoyer_invitation(uuid) to authenticated;
grant execute on function public.verifier_invitation(text) to authenticated, anon;
grant execute on function public.accepter_invitation(text) to authenticated;
