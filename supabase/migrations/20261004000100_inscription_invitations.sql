-- =============================================================================
-- INSCRIPTION, CRÉATION D'ENTREPRISE ET INVITATIONS
--
-- AUTHENTIFICATION ≠ RÔLE MÉTIER : s'inscrire (Google ou e-mail) ne donne
-- aucun rôle. Un rôle n'est obtenu que :
--   - en créant son entreprise (créateur → ADMINISTRATEUR) ;
--   - en acceptant une invitation créée par une personne autorisée (le rôle
--     et les périmètres viennent de l'invitation, jamais de l'invité).
-- Aucune policy n'autorise l'écriture directe : tout passe par les RPC.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Profil : prénom / nom (Google ne fournit souvent qu'un nom complet)
-- -----------------------------------------------------------------------------

alter table public.profiles
  add column prenom text check (char_length(prenom) <= 60),
  add column nom text check (char_length(nom) <= 60);

grant update (prenom, nom) on public.profiles to authenticated;

create or replace function app.tg_creer_profil()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_prenom text := nullif(trim(coalesce(v_meta ->> 'prenom', v_meta ->> 'given_name')), '');
  v_nom text := nullif(trim(coalesce(v_meta ->> 'nom', v_meta ->> 'family_name')), '');
begin
  insert into public.profiles (id, prenom, nom, nom_complet, langue)
  values (
    new.id,
    left(v_prenom, 60),
    left(v_nom, 60),
    left(coalesce(
      nullif(trim(v_meta ->> 'nom_complet'), ''),
      nullif(trim(concat_ws(' ', v_prenom, v_nom)), ''),
      nullif(trim(v_meta ->> 'full_name'), ''),
      nullif(trim(v_meta ->> 'name'), '')
    ), 120),
    case when v_meta ->> 'langue' in ('fr', 'ar', 'en') then v_meta ->> 'langue' else 'fr' end
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- Permission d'invitation (distincte de la gestion des membres)
-- -----------------------------------------------------------------------------

insert into public.permissions (code, description)
values ('users.invite', 'Inviter un utilisateur dans l''entreprise');

insert into public.roles_permissions (role_code, permission_code)
values ('ADMINISTRATEUR', 'users.invite');

-- -----------------------------------------------------------------------------
-- RPC de confiance : les triggers de limites s'appliquent pleinement (ils ne
-- délèguent plus le refus à la RLS, qui ne s'applique pas en SECURITY DEFINER).
-- -----------------------------------------------------------------------------

create or replace function app.appel_client_sans_permission(p_entreprise_id uuid, p_permission text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.role()) in ('authenticated', 'anon')
     and coalesce(current_setting('app.rpc_de_confiance', true), '') <> 'on'
     and not app.a_permission(p_entreprise_id, p_permission);
$$;

create or replace function app.rpc_de_confiance(p_actif boolean)
returns void
language sql
set search_path = ''
as $$
  select set_config('app.rpc_de_confiance', case when p_actif then 'on' else 'off' end, true);
$$;

-- -----------------------------------------------------------------------------
-- Invitations
-- -----------------------------------------------------------------------------

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  email text not null check (email = lower(email) and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  role_code text not null references public.roles (code) on delete restrict,
  statut text not null default 'PENDING'
    check (statut in ('PENDING', 'ACCEPTED', 'EXPIRED', 'CANCELLED')),
  -- Empreinte SHA-256 du jeton : le jeton lui-même n'est jamais stocké.
  token_hash bytea not null unique,
  expires_at timestamptz not null,
  created_by uuid references public.profiles (id) on delete set null,
  accepted_by uuid references public.profiles (id) on delete set null,
  accepted_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, entreprise_id),
  check (statut <> 'ACCEPTED' or (accepted_by is not null and accepted_at is not null))
);

create unique index invitations_une_en_attente
  on public.invitations (entreprise_id, email) where statut = 'PENDING';
create index invitations_entreprise_idx on public.invitations (entreprise_id, created_at desc);

create trigger invitations_updated_at before update on public.invitations
  for each row execute function app.tg_set_updated_at();

create table public.invitation_perimetres (
  invitation_id uuid not null,
  entreprise_id uuid not null,
  perimetre_id uuid not null,
  primary key (invitation_id, perimetre_id),
  foreign key (invitation_id, entreprise_id)
    references public.invitations (id, entreprise_id) on delete cascade,
  foreign key (perimetre_id, entreprise_id)
    references public.perimetres (id, entreprise_id) on delete cascade
);

alter table public.invitations enable row level security;
alter table public.invitation_perimetres enable row level security;

create policy invitations_lecture on public.invitations for select to authenticated
  using (app.a_permission(entreprise_id, 'users.invite'));
create policy invitation_perimetres_lecture on public.invitation_perimetres for select to authenticated
  using (app.a_permission(entreprise_id, 'users.invite'));

-- Lecture sans l'empreinte du jeton ; aucune écriture directe.
revoke all on public.invitations, public.invitation_perimetres from anon, authenticated;
grant select (id, entreprise_id, email, role_code, statut, expires_at, created_by,
              accepted_by, accepted_at, cancelled_at, created_at, updated_at)
  on public.invitations to authenticated;
grant select on public.invitation_perimetres to authenticated;
grant all on public.invitations, public.invitation_perimetres to service_role;

create or replace function app.hash_jeton(p_jeton text)
returns bytea
language sql
immutable
set search_path = ''
as $$
  select extensions.digest(convert_to(p_jeton, 'UTF8'), 'sha256');
$$;

-- -----------------------------------------------------------------------------
-- Créer mon entreprise (transactionnel)
-- -----------------------------------------------------------------------------

create or replace function public.creer_entreprise(
  p_nom text,
  p_plan_code text,
  p_activites text[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_eid uuid;
  v_activite text;
  v_plan public.plans;
begin
  if v_uid is null then
    raise exception 'NON_AUTHENTIFIE' using errcode = '42501';
  end if;
  if char_length(trim(coalesce(p_nom, ''))) < 2 then
    perform app.refuser('NOM_INVALIDE');
  end if;
  -- V1 : une entreprise créée par compte (anti-abus de l'essai gratuit).
  if exists (select 1 from public.entreprises where created_by = v_uid) then
    perform app.refuser('ENTREPRISE_DEJA_CREEE');
  end if;

  select * into v_plan from public.plans where code = p_plan_code and est_actif;
  if not found then
    perform app.refuser('PLAN_INVALIDE');
  end if;
  if coalesce(cardinality(p_activites), 0) = 0 then
    perform app.refuser('ACTIVITE_REQUISE');
  end if;

  perform app.rpc_de_confiance(true);

  insert into public.entreprises (nom, created_by)
  values (trim(p_nom), v_uid)
  returning id into v_eid;

  insert into public.abonnements (entreprise_id, plan_code, statut, date_debut, date_fin)
  values (v_eid, v_plan.code, 'ESSAI', now(), now() + interval '14 days');

  -- Le créateur devient administrateur PARCE QU'il crée l'entreprise.
  insert into public.membres_entreprise (entreprise_id, user_id, role_code)
  values (v_eid, v_uid, 'ADMINISTRATEUR');

  -- Les triggers vérifient : activité incluse dans le plan, nombre d'activités.
  foreach v_activite in array (select array_agg(distinct a) from unnest(p_activites) a) loop
    insert into public.entreprise_activites (entreprise_id, activite_code)
    values (v_eid, v_activite);

    insert into public.perimetres (entreprise_id, activite_code, type, nom)
    select v_eid, ac.code, ac.type_perimetre_defaut,
           case ac.type_perimetre_defaut when 'BOUTIQUE' then 'Boutique principale'
                                         else 'Agence principale' end
           || case when ac.code = 'IMMOBILIER' then ' (Immobilier)' else '' end
    from public.activites ac where ac.code = v_activite;
  end loop;

  perform app.rpc_de_confiance(false);
  return v_eid;
end;
$$;

-- -----------------------------------------------------------------------------
-- Créer une invitation (personne autorisée uniquement)
-- -----------------------------------------------------------------------------

create or replace function public.creer_invitation(
  p_entreprise_id uuid,
  p_email text,
  p_role_code text,
  p_perimetre_ids uuid[] default '{}',
  p_validite_jours integer default 7
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
  v_jeton text;
  v_id uuid;
  v_expires timestamptz;
  v_perimetre public.perimetres;
begin
  if v_uid is null or not app.a_permission(p_entreprise_id, 'users.invite') then
    raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
  end if;
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    perform app.refuser('EMAIL_INVALIDE');
  end if;
  if p_validite_jours not between 1 and 30 then
    perform app.refuser('VALIDITE_INVALIDE');
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
  if v_role.code is null or v_quota is null then
    perform app.refuser('ROLE_NON_AUTORISE', jsonb_build_object('plan', v_plan, 'role', p_role_code));
  end if;
  if v_role.activite_code is not null and not exists (
    select 1 from public.entreprise_activites
    where entreprise_id = p_entreprise_id and activite_code = v_role.activite_code and est_active
  ) then
    perform app.refuser('ROLE_ACTIVITE_INACTIVE', jsonb_build_object('role', p_role_code));
  end if;

  -- Une invitation en attente pour ce même e-mail est remplacée.
  update public.invitations set statut = 'CANCELLED', cancelled_at = now()
  where entreprise_id = p_entreprise_id and email = v_email and statut = 'PENDING';

  -- Quotas : membres actifs + invitations encore valides.
  select count(*) into v_nb from (
    select 1 from public.membres_entreprise
    where entreprise_id = p_entreprise_id and statut = 'ACTIF' and role_code = p_role_code
    union all
    select 1 from public.invitations
    where entreprise_id = p_entreprise_id and statut = 'PENDING'
      and expires_at > now() and role_code = p_role_code
  ) s;
  if v_nb >= v_quota then
    perform app.refuser('LIMITE_ROLE',
      jsonb_build_object('plan', v_plan, 'role', p_role_code, 'max', v_quota));
  end if;

  v_max := app.max_utilisateurs(p_entreprise_id, v_plan);
  select count(*) into v_nb from (
    select 1 from public.membres_entreprise
    where entreprise_id = p_entreprise_id and statut = 'ACTIF'
    union all
    select 1 from public.invitations
    where entreprise_id = p_entreprise_id and statut = 'PENDING' and expires_at > now()
  ) s;
  if v_nb >= v_max then
    perform app.refuser('LIMITE_UTILISATEURS', jsonb_build_object('plan', v_plan, 'max', v_max));
  end if;

  -- Périmètres : obligatoires pour un rôle restreint, interdits sinon.
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

  v_jeton := rtrim(translate(encode(extensions.gen_random_bytes(24), 'base64'), '+/', '-_'), '=');
  v_expires := now() + make_interval(days => p_validite_jours);

  insert into public.invitations (entreprise_id, email, role_code, token_hash, expires_at, created_by)
  values (p_entreprise_id, v_email, p_role_code, app.hash_jeton(v_jeton), v_expires, v_uid)
  returning id into v_id;

  for v_perimetre in
    select * from public.perimetres
    where id = any (p_perimetre_ids) and entreprise_id = p_entreprise_id and deleted_at is null
  loop
    if v_role.activite_code is not null and v_perimetre.activite_code <> v_role.activite_code then
      perform app.refuser('AFFECTATION_ACTIVITE_INCOMPATIBLE',
        jsonb_build_object('role', p_role_code, 'activite', v_perimetre.activite_code));
    end if;
    insert into public.invitation_perimetres (invitation_id, entreprise_id, perimetre_id)
    values (v_id, p_entreprise_id, v_perimetre.id);
  end loop;

  if (select count(*) from public.invitation_perimetres where invitation_id = v_id)
     <> coalesce(cardinality(p_perimetre_ids), 0) then
    perform app.refuser('PERIMETRE_NON_AUTORISE');
  end if;

  -- Le jeton n'est renvoyé qu'ici, une seule fois.
  return jsonb_build_object('id', v_id, 'token', v_jeton, 'expires_at', v_expires);
end;
$$;

-- -----------------------------------------------------------------------------
-- Vérifier une invitation (aperçu minimal, sans donnée sensible)
-- -----------------------------------------------------------------------------

create or replace function public.verifier_invitation(p_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_inv public.invitations;
  v_statut text;
begin
  select * into v_inv from public.invitations where token_hash = app.hash_jeton(coalesce(p_token, ''));
  if not found then
    return jsonb_build_object('statut', 'INVALIDE');
  end if;

  v_statut := case
    when v_inv.statut = 'PENDING' and v_inv.expires_at <= now() then 'EXPIRED'
    else v_inv.statut
  end;

  return jsonb_build_object(
    'statut', v_statut,
    'entreprise_nom', (select nom from public.entreprises where id = v_inv.entreprise_id),
    'role_code', v_inv.role_code,
    'email_masque', left(v_inv.email, 1) || '***' || substring(v_inv.email from '@.*$'),
    'expires_at', v_inv.expires_at
  );
end;
$$;

-- -----------------------------------------------------------------------------
-- Accepter une invitation : rôle et périmètres viennent de l'invitation
-- -----------------------------------------------------------------------------

create or replace function public.accepter_invitation(p_token text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_user auth.users;
  v_inv public.invitations;
  v_membre_id uuid;
begin
  if v_uid is null then
    raise exception 'NON_AUTHENTIFIE' using errcode = '42501';
  end if;

  select * into v_user from auth.users where id = v_uid;
  -- Sans e-mail confirmé, n'importe qui pourrait s'inscrire avec l'adresse invitée.
  if v_user.email_confirmed_at is null then
    perform app.refuser('EMAIL_NON_CONFIRME');
  end if;

  select * into v_inv from public.invitations
  where token_hash = app.hash_jeton(coalesce(p_token, ''))
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
  if lower(v_user.email) <> v_inv.email then
    perform app.refuser('INVITATION_EMAIL_DIFFERENT');
  end if;
  if exists (
    select 1 from public.membres_entreprise
    where entreprise_id = v_inv.entreprise_id and user_id = v_uid
  ) then
    perform app.refuser('DEJA_MEMBRE');
  end if;

  perform app.rpc_de_confiance(true);

  -- Quotas et cohérence revérifiés par les triggers (abonnement, rôle, limites).
  insert into public.membres_entreprise (entreprise_id, user_id, role_code)
  values (v_inv.entreprise_id, v_uid, v_inv.role_code)
  returning id into v_membre_id;

  insert into public.membre_perimetres (entreprise_id, membre_id, perimetre_id)
  select ip.entreprise_id, v_membre_id, ip.perimetre_id
  from public.invitation_perimetres ip
  join public.perimetres p on p.id = ip.perimetre_id and p.deleted_at is null
  where ip.invitation_id = v_inv.id;

  update public.invitations
  set statut = 'ACCEPTED', accepted_by = v_uid, accepted_at = now()
  where id = v_inv.id;

  perform app.rpc_de_confiance(false);
  return v_inv.entreprise_id;
end;
$$;

create or replace function public.annuler_invitation(p_invitation_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inv public.invitations;
begin
  select * into v_inv from public.invitations where id = p_invitation_id for update;
  if not found or not app.a_permission(v_inv.entreprise_id, 'users.invite') then
    raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
  end if;
  if v_inv.statut <> 'PENDING' then
    perform app.refuser('INVITATION_NON_ANNULABLE');
  end if;
  update public.invitations set statut = 'CANCELLED', cancelled_at = now() where id = p_invitation_id;
end;
$$;

revoke execute on function
  public.creer_entreprise(text, text, text[]),
  public.creer_invitation(uuid, text, text, uuid[], integer),
  public.verifier_invitation(text),
  public.accepter_invitation(text),
  public.annuler_invitation(uuid),
  app.rpc_de_confiance(boolean),
  app.hash_jeton(text)
from public, anon;

grant execute on function
  public.creer_entreprise(text, text, text[]),
  public.creer_invitation(uuid, text, text, uuid[], integer),
  public.verifier_invitation(text),
  public.accepter_invitation(text),
  public.annuler_invitation(uuid)
to authenticated;

-- L'aperçu est consultable avant connexion (le jeton est l'autorisation).
grant execute on function public.verifier_invitation(text) to anon;
