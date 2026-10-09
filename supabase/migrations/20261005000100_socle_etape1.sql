-- =============================================================================
-- SOCLE COMMUN — ÉTAPE 1
--   1. Profil d'entreprise (contact, fiscal, devise XOF par défaut)
--   2. Plans NORMAL / MOYEN / PRO avec prix ; limite NULL = illimitée
--   3. Rôles Caissier et Gestionnaire immobilier
--   4. Permissions du socle commun
--   5. Journal d'audit (écrit uniquement par le serveur)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Profil d'entreprise
-- -----------------------------------------------------------------------------

alter table public.entreprises
  add column telephone text check (char_length(telephone) <= 30),
  add column adresse text check (char_length(adresse) <= 200),
  add column ville text check (char_length(ville) <= 80),
  add column identifiant_fiscal text check (char_length(identifiant_fiscal) <= 40),
  add column registre_commerce text check (char_length(registre_commerce) <= 40),
  add column logo_path text check (char_length(logo_path) <= 300),
  alter column devise set default 'XOF';

update public.entreprises set devise = 'XOF' where devise is null;
alter table public.entreprises alter column devise set not null;

grant update (telephone, adresse, ville, identifiant_fiscal, registre_commerce, logo_path)
  on public.entreprises to authenticated;

-- -----------------------------------------------------------------------------
-- 2. Plans : FAIBLE devient NORMAL, PRO ajouté, prix mensuels
-- -----------------------------------------------------------------------------

alter table public.plans
  add column prix_mensuel integer not null default 0 check (prix_mensuel >= 0),
  add column devise_prix text not null default 'XOF' check (char_length(devise_prix) = 3);

insert into public.plans (code, nom, description, max_activites, ordre, prix_mensuel)
values ('NORMAL', 'Normal', 'Une activité, petite équipe.', 1, 1, 1000);

update public.plan_activites set plan_code = 'NORMAL' where plan_code = 'FAIBLE';
update public.plan_roles set plan_code = 'NORMAL' where plan_code = 'FAIBLE';
update public.plan_modules set plan_code = 'NORMAL' where plan_code = 'FAIBLE';
update public.abonnements set plan_code = 'NORMAL' where plan_code = 'FAIBLE';
delete from public.plans where code = 'FAIBLE';

update public.plans set prix_mensuel = 2000, ordre = 2 where code = 'MOYEN';

-- Limites NULL = illimitées (formule PRO).
alter table public.plan_activites
  alter column max_utilisateurs drop not null,
  alter column max_perimetres drop not null;
alter table public.plan_roles alter column max_membres drop not null;

insert into public.plans (code, nom, description, max_activites, ordre, prix_mensuel)
values ('PRO', 'Pro', 'Utilisateurs et boutiques illimités, Commerce + Services + Immobilier.', 3, 3, 5000);

insert into public.plan_activites (plan_code, activite_code, max_utilisateurs, max_perimetres)
select 'PRO', code, null, null from public.activites;

insert into public.plan_modules (plan_code, module_code)
select 'PRO', code from public.modules;

-- Une seule ligne avec une limite NULL rend l'entreprise illimitée.
create or replace function app.max_utilisateurs(p_entreprise_id uuid, p_plan_code text)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select case when bool_or(pa.max_utilisateurs is null) then null
              else coalesce(max(pa.max_utilisateurs), 1) end
  from public.plan_activites pa
  join public.entreprise_activites ea
    on ea.activite_code = pa.activite_code
   and ea.entreprise_id = p_entreprise_id
   and ea.est_active
  where pa.plan_code = p_plan_code;
$$;

-- Fonctions reprises de 20261003000300 et 20261004000100 : seule la gestion
-- des limites NULL (illimitées) change.

create or replace function app.tg_verifier_membre()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_plan text;
  v_activite text;
  v_max integer;
  v_nb integer;
begin
  -- Protection du dernier administrateur actif.
  if tg_op in ('UPDATE', 'DELETE')
     and old.role_code = 'ADMINISTRATEUR' and old.statut = 'ACTIF'
     and (tg_op = 'DELETE' or new.role_code <> 'ADMINISTRATEUR' or new.statut <> 'ACTIF')
     -- Une suppression en cascade (entreprise / compte supprimé) reste permise.
     and not (tg_op = 'DELETE' and pg_trigger_depth() > 1)
     and not exists (
       select 1 from public.membres_entreprise
       where entreprise_id = old.entreprise_id
         and id <> old.id
         and role_code = 'ADMINISTRATEUR'
         and statut = 'ACTIF'
     ) then
    perform app.refuser('DERNIER_ADMINISTRATEUR');
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  if new.statut <> 'ACTIF' then
    return new;
  end if;
  if tg_op = 'UPDATE'
     and old.statut = 'ACTIF'
     and old.role_code = new.role_code
     and old.entreprise_id = new.entreprise_id then
    return new;
  end if;
  if app.appel_client_sans_permission(new.entreprise_id, 'users.manage') then
    return new;
  end if;

  perform app.verrouiller_entreprise(new.entreprise_id);
  v_plan := app.plan_courant(new.entreprise_id);
  if v_plan is null then
    perform app.refuser('ABONNEMENT_INACTIF');
  end if;

  select activite_code into v_activite from public.roles where code = new.role_code;
  if v_activite is not null and not exists (
    select 1 from public.entreprise_activites
    where entreprise_id = new.entreprise_id and activite_code = v_activite and est_active
  ) then
    perform app.refuser('ROLE_ACTIVITE_INACTIVE',
      jsonb_build_object('role', new.role_code, 'activite', v_activite));
  end if;

  select max_membres into v_max
  from public.plan_roles
  where plan_code = v_plan and role_code = new.role_code;
  if not found then
    perform app.refuser('ROLE_NON_AUTORISE', jsonb_build_object('plan', v_plan, 'role', new.role_code));
  end if;

  select count(*) into v_nb
  from public.membres_entreprise
  where entreprise_id = new.entreprise_id
    and statut = 'ACTIF'
    and role_code = new.role_code
    and id <> new.id;
  if v_max is not null and v_nb >= v_max then
    perform app.refuser('LIMITE_ROLE',
      jsonb_build_object('plan', v_plan, 'role', new.role_code, 'max', v_max));
  end if;

  v_max := app.max_utilisateurs(new.entreprise_id, v_plan);
  select count(*) into v_nb
  from public.membres_entreprise
  where entreprise_id = new.entreprise_id and statut = 'ACTIF' and id <> new.id;
  if v_max is not null and v_nb >= v_max then
    perform app.refuser('LIMITE_UTILISATEURS', jsonb_build_object('plan', v_plan, 'max', v_max));
  end if;

  return new;
end;
$$;

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
    -- Seule une restauration (deleted_at → null) consomme à nouveau une place.
    if not (old.deleted_at is not null and new.deleted_at is null) then
      return new;
    end if;
  end if;
  if new.deleted_at is not null then
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
    and id <> new.id;
  if v_max is not null and v_nb >= v_max then
    perform app.refuser('LIMITE_PERIMETRES',
      jsonb_build_object('plan', v_plan, 'activite', new.activite_code, 'max', v_max));
  end if;

  return new;
end;
$$;

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
  if v_role.code is null or not found then
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
  if v_quota is not null and v_nb >= v_quota then
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
  if v_max is not null and v_nb >= v_max then
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
-- 3. Nouveaux rôles
-- -----------------------------------------------------------------------------

insert into public.roles (code, libelle, activite_code, ordre) values
  ('CAISSIER', 'Caissier', 'COMMERCE', 5),
  ('GESTIONNAIRE_IMMOBILIER', 'Gestionnaire immobilier', 'IMMOBILIER', 6);

insert into public.plan_roles (plan_code, role_code, max_membres) values
  ('NORMAL', 'CAISSIER', 1),
  ('NORMAL', 'GESTIONNAIRE_IMMOBILIER', 1),
  ('MOYEN', 'CAISSIER', 2),
  ('MOYEN', 'GESTIONNAIRE_IMMOBILIER', 1);

-- PRO : tous les rôles, sans quota.
insert into public.plan_roles (plan_code, role_code, max_membres)
select 'PRO', code, null from public.roles;

-- -----------------------------------------------------------------------------
-- 4. Permissions du socle commun
-- -----------------------------------------------------------------------------

insert into public.permissions (code, description)
select r || '.' || a, null
from (values
  ('contacts',    array['view', 'create', 'update', 'archive']),
  ('payments',    array['view', 'create', 'cancel', 'refund']),
  ('receivables', array['view', 'manage']),
  ('expenses',    array['view', 'create', 'update']),
  ('documents',   array['view', 'create', 'print', 'share']),
  ('reports',     array['view']),
  ('agenda',      array['view', 'manage']),
  ('audit',       array['view'])
) as p(r, actions), unnest(p.actions) as a;

-- Caisse : actions explicites (ouvrir, mouvementer, clôturer) au lieu de create/update.
insert into public.permissions (code, description)
values ('cash.open', null), ('cash.move', null), ('cash.close', null);

insert into public.roles_permissions (role_code, permission_code)
select distinct rp.role_code, n.code
from public.roles_permissions rp
join (values ('cash.create', 'cash.open'), ('cash.create', 'cash.move'), ('cash.update', 'cash.close')) as n(ancien, code)
  on n.ancien = rp.permission_code;

delete from public.permissions where code in ('cash.create', 'cash.update');

-- L'administrateur reçoit toutes les nouvelles permissions.
insert into public.roles_permissions (role_code, permission_code)
select 'ADMINISTRATEUR', p.code from public.permissions p
where not exists (
  select 1 from public.roles_permissions rp
  where rp.role_code = 'ADMINISTRATEUR' and rp.permission_code = p.code
);

insert into public.roles_permissions (role_code, permission_code)
select r.role_code, r.permission_code
from (values
  ('SUPERVISEUR', 'contacts.view'), ('SUPERVISEUR', 'contacts.create'), ('SUPERVISEUR', 'contacts.update'),
  ('SUPERVISEUR', 'payments.view'), ('SUPERVISEUR', 'payments.create'),
  ('SUPERVISEUR', 'receivables.view'), ('SUPERVISEUR', 'receivables.manage'),
  ('SUPERVISEUR', 'expenses.view'), ('SUPERVISEUR', 'expenses.create'),
  ('SUPERVISEUR', 'documents.view'), ('SUPERVISEUR', 'documents.create'),
  ('SUPERVISEUR', 'documents.print'), ('SUPERVISEUR', 'documents.share'),
  ('SUPERVISEUR', 'reports.view'), ('SUPERVISEUR', 'agenda.view'), ('SUPERVISEUR', 'agenda.manage'),

  ('GESTIONNAIRE_STOCK', 'contacts.view'), ('GESTIONNAIRE_STOCK', 'contacts.create'),
  ('GESTIONNAIRE_STOCK', 'documents.view'), ('GESTIONNAIRE_STOCK', 'expenses.view'),

  ('VENDEUR', 'contacts.view'), ('VENDEUR', 'contacts.create'), ('VENDEUR', 'contacts.update'),
  ('VENDEUR', 'payments.view'), ('VENDEUR', 'payments.create'), ('VENDEUR', 'receivables.view'),
  ('VENDEUR', 'documents.view'), ('VENDEUR', 'documents.create'),
  ('VENDEUR', 'documents.print'), ('VENDEUR', 'documents.share'), ('VENDEUR', 'agenda.view'),

  ('CAISSIER', 'perimetres.view'), ('CAISSIER', 'products.view'), ('CAISSIER', 'sales.view'),
  ('CAISSIER', 'contacts.view'), ('CAISSIER', 'contacts.create'),
  ('CAISSIER', 'payments.view'), ('CAISSIER', 'payments.create'),
  ('CAISSIER', 'receivables.view'), ('CAISSIER', 'receivables.manage'),
  ('CAISSIER', 'cash.view'), ('CAISSIER', 'cash.open'), ('CAISSIER', 'cash.move'), ('CAISSIER', 'cash.close'),
  ('CAISSIER', 'documents.view'), ('CAISSIER', 'documents.create'),
  ('CAISSIER', 'documents.print'), ('CAISSIER', 'documents.share'),

  ('GESTIONNAIRE_IMMOBILIER', 'perimetres.view'),
  ('GESTIONNAIRE_IMMOBILIER', 'contacts.view'), ('GESTIONNAIRE_IMMOBILIER', 'contacts.create'),
  ('GESTIONNAIRE_IMMOBILIER', 'contacts.update'),
  ('GESTIONNAIRE_IMMOBILIER', 'payments.view'), ('GESTIONNAIRE_IMMOBILIER', 'payments.create'),
  ('GESTIONNAIRE_IMMOBILIER', 'receivables.view'), ('GESTIONNAIRE_IMMOBILIER', 'receivables.manage'),
  ('GESTIONNAIRE_IMMOBILIER', 'expenses.view'), ('GESTIONNAIRE_IMMOBILIER', 'expenses.create'),
  ('GESTIONNAIRE_IMMOBILIER', 'documents.view'), ('GESTIONNAIRE_IMMOBILIER', 'documents.create'),
  ('GESTIONNAIRE_IMMOBILIER', 'documents.print'), ('GESTIONNAIRE_IMMOBILIER', 'documents.share'),
  ('GESTIONNAIRE_IMMOBILIER', 'agenda.view'), ('GESTIONNAIRE_IMMOBILIER', 'agenda.manage'),
  ('GESTIONNAIRE_IMMOBILIER', 'reports.view')
) as r(role_code, permission_code)
on conflict do nothing;

-- Toutes les permissions métier Immobilier pour le gestionnaire immobilier.
insert into public.roles_permissions (role_code, permission_code)
select 'GESTIONNAIRE_IMMOBILIER', code from public.permissions
where split_part(code, '.', 1) in ('properties', 'owners', 'tenants', 'rentals', 'contracts', 'rents')
on conflict do nothing;

-- -----------------------------------------------------------------------------
-- 5. Journal d'audit
-- -----------------------------------------------------------------------------

create table public.audit_logs (
  id bigint generated always as identity primary key,
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  user_id uuid references auth.users (id) on delete set null,
  action text not null
    check (action in ('CREATION', 'MODIFICATION', 'ARCHIVAGE', 'RESTAURATION', 'SUPPRESSION')),
  entite_type text not null,
  entite_id text not null,
  activite_code text,
  perimetre_id uuid,
  anciennes_valeurs jsonb,
  nouvelles_valeurs jsonb,
  created_at timestamptz not null default now()
);
create index audit_logs_entreprise_idx on public.audit_logs (entreprise_id, created_at desc);
create index audit_logs_entite_idx on public.audit_logs (entite_type, entite_id);

-- Écrit par trigger uniquement (SECURITY DEFINER) : aucun utilisateur ne peut
-- créer, modifier ou effacer une ligne d'audit.
create or replace function app.tg_audit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ignore text[] := array['updated_at', 'created_at', 'version', 'token_hash'];
  v_old jsonb;
  v_new jsonb;
  v_ref jsonb;
  v_action text;
  v_eid uuid;
  v_avant jsonb;
  v_apres jsonb;
begin
  -- Suppression en cascade (entreprise ou compte supprimé) : rien à tracer.
  if tg_op = 'DELETE' and (pg_trigger_depth() > 1 or tg_table_name = 'entreprises') then
    return null;
  end if;

  if tg_op <> 'INSERT' then v_old := to_jsonb(old) - v_ignore; end if;
  if tg_op <> 'DELETE' then v_new := to_jsonb(new) - v_ignore; end if;
  v_ref := coalesce(v_new, v_old);

  if tg_op = 'UPDATE' then
    -- Seuls les champs réellement modifiés sont conservés.
    select jsonb_object_agg(o.key, o.value), jsonb_object_agg(o.key, v_new -> o.key)
      into v_avant, v_apres
    from jsonb_each(v_old) o
    where (v_new -> o.key) is distinct from o.value;
    if v_avant is null then
      return null;
    end if;
    v_action := case
      when (v_old ->> 'deleted_at') is null and (v_new ->> 'deleted_at') is not null then 'ARCHIVAGE'
      when (v_old ->> 'deleted_at') is not null and (v_new ->> 'deleted_at') is null then 'RESTAURATION'
      else 'MODIFICATION'
    end;
  elsif tg_op = 'INSERT' then
    v_action := 'CREATION';
    v_apres := v_new;
  else
    v_action := 'SUPPRESSION';
    v_avant := v_old;
  end if;

  v_eid := coalesce(
    (v_ref ->> 'entreprise_id')::uuid,
    case when tg_table_name = 'entreprises' then (v_ref ->> 'id')::uuid end
  );

  insert into public.audit_logs (
    entreprise_id, user_id, action, entite_type, entite_id,
    activite_code, perimetre_id, anciennes_valeurs, nouvelles_valeurs
  ) values (
    v_eid,
    (select auth.uid()),
    v_action,
    tg_table_name,
    coalesce(
      v_ref ->> 'id',
      v_ref ->> 'activite_code',
      (v_ref ->> 'membre_id') || ':' || (v_ref ->> 'perimetre_id')
    ),
    v_ref ->> 'activite_code',
    case when tg_table_name = 'perimetres' then (v_ref ->> 'id')::uuid
         else (v_ref ->> 'perimetre_id')::uuid end,
    v_avant,
    v_apres
  );
  return null;
end;
$$;

create trigger audit_entreprises after insert or update on public.entreprises
  for each row execute function app.tg_audit();
create trigger audit_entreprise_activites after insert or update or delete on public.entreprise_activites
  for each row execute function app.tg_audit();
create trigger audit_abonnements after insert or update or delete on public.abonnements
  for each row execute function app.tg_audit();
create trigger audit_membres after insert or update or delete on public.membres_entreprise
  for each row execute function app.tg_audit();
create trigger audit_membre_perimetres after insert or delete on public.membre_perimetres
  for each row execute function app.tg_audit();
create trigger audit_perimetres after insert or update or delete on public.perimetres
  for each row execute function app.tg_audit();
create trigger audit_invitations after insert or update on public.invitations
  for each row execute function app.tg_audit();

alter table public.audit_logs enable row level security;
create policy audit_lecture on public.audit_logs for select to authenticated
  using (app.a_permission(entreprise_id, 'audit.view'));

revoke all on public.audit_logs from anon, authenticated;
grant select on public.audit_logs to authenticated;
grant all on public.audit_logs to service_role;
revoke execute on function app.tg_audit() from public, anon, authenticated;

-- Module « Journal d'activité » (administration).
insert into public.modules (code, libelle, activite_code, permission_acces, ordre)
values ('admin.audit', 'Journal d''activité', null, 'audit.view', 5);
insert into public.plan_modules (plan_code, module_code)
select code, 'admin.audit' from public.plans;
