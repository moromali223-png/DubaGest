-- =============================================================================
-- FONDATION V1 — RÈGLES D'ABONNEMENT (côté serveur) + SÉCURITÉ RLS
--
-- ACCÈS FINAL = abonnement actif ET activité active ET module du plan
--               ET permission du rôle ET périmètre autorisé
-- Flutter réplique ces règles pour l'UX ; ici elles sont la vraie sécurité.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Helpers (SECURITY DEFINER : lisent sans RLS, évitent la récursion des policies)
-- -----------------------------------------------------------------------------

-- Refus métier : SQLSTATE dédié + code stable (traduit côté client) + détails JSON.
create or replace function app.refuser(p_code text, p_details jsonb default '{}'::jsonb)
returns void
language plpgsql
set search_path = ''
as $$
begin
  raise exception using errcode = 'DGL01', message = p_code, detail = p_details::text;
end;
$$;

create or replace function app.plan_courant(p_entreprise_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select a.plan_code
  from public.abonnements a
  join public.entreprises e on e.id = a.entreprise_id and e.statut = 'ACTIVE'
  where a.entreprise_id = p_entreprise_id
    and a.statut in ('ESSAI', 'ACTIF')
    and a.date_debut <= now()
    and (a.date_fin is null or a.date_fin > now())
  limit 1;
$$;

create or replace function app.est_membre(p_entreprise_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.membres_entreprise m
    where m.entreprise_id = p_entreprise_id
      and m.user_id = (select auth.uid())
      and m.statut = 'ACTIF'
  );
$$;

create or replace function app.a_permission(p_entreprise_id uuid, p_permission text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.membres_entreprise m
    join public.roles_permissions rp on rp.role_code = m.role_code
    where m.entreprise_id = p_entreprise_id
      and m.user_id = (select auth.uid())
      and m.statut = 'ACTIF'
      and rp.permission_code = p_permission
  );
$$;

-- Accès à un périmètre : affectation explicite, ou permission perimetres.access_all.
-- Ne relit pas la ligne du périmètre : utilisable dans INSERT … RETURNING.
create or replace function app.acces_perimetre(p_entreprise_id uuid, p_perimetre_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.membres_entreprise m
    where m.entreprise_id = p_entreprise_id
      and m.user_id = (select auth.uid())
      and m.statut = 'ACTIF'
      and (
        exists (
          select 1 from public.roles_permissions rp
          where rp.role_code = m.role_code and rp.permission_code = 'perimetres.access_all'
        )
        or exists (
          select 1 from public.membre_perimetres mp
          where mp.membre_id = m.id and mp.perimetre_id = p_perimetre_id
        )
      )
  );
$$;

-- Vrai pour un appel API sans la permission requise : le trigger de limites
-- laisse alors la RLS refuser (et ne divulgue pas l'état des limites).
create or replace function app.appel_client_sans_permission(p_entreprise_id uuid, p_permission text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.role()) in ('authenticated', 'anon')
     and not app.a_permission(p_entreprise_id, p_permission);
$$;

create or replace function app.est_mon_membre(p_membre_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.membres_entreprise m
    where m.id = p_membre_id and m.user_id = (select auth.uid())
  );
$$;

create or replace function app.partage_entreprise(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.membres_entreprise moi
    join public.membres_entreprise autre on autre.entreprise_id = moi.entreprise_id
    where moi.user_id = (select auth.uid())
      and moi.statut = 'ACTIF'
      and autre.user_id = p_user_id
  );
$$;

create or replace function app.module_disponible(p_entreprise_id uuid, p_module_code text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.modules mo
    join public.plan_modules pm
      on pm.module_code = mo.code
     and pm.plan_code = app.plan_courant(p_entreprise_id)
    where mo.code = p_module_code
      and mo.est_actif
      and (
        mo.activite_code is null
        or exists (
          select 1 from public.entreprise_activites ea
          where ea.entreprise_id = p_entreprise_id
            and ea.activite_code = mo.activite_code
            and ea.est_active
        )
      )
  );
$$;

-- Point d'entrée unique pour les policies des futures tables métier.
create or replace function app.peut(
  p_entreprise_id uuid,
  p_module_code text,
  p_permission text,
  p_perimetre_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select app.module_disponible(p_entreprise_id, p_module_code)
     and app.a_permission(p_entreprise_id, p_permission)
     and (p_perimetre_id is null or app.acces_perimetre(p_entreprise_id, p_perimetre_id));
$$;

-- Limite d'utilisateurs = max des limites des activités actives du plan.
create or replace function app.max_utilisateurs(p_entreprise_id uuid, p_plan_code text)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(max(pa.max_utilisateurs), 1)
  from public.plan_activites pa
  join public.entreprise_activites ea
    on ea.activite_code = pa.activite_code
   and ea.entreprise_id = p_entreprise_id
   and ea.est_active
  where pa.plan_code = p_plan_code;
$$;

-- Verrou par entreprise : évite que deux créations simultanées dépassent une limite.
create or replace function app.verrouiller_entreprise(p_entreprise_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  select pg_advisory_xact_lock(hashtextextended(p_entreprise_id::text, 0));
$$;

-- -----------------------------------------------------------------------------
-- Moteur de limites côté serveur (triggers)
-- -----------------------------------------------------------------------------

create or replace function app.tg_verifier_activite()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_plan text;
  v_max smallint;
  v_nb integer;
begin
  if not new.est_active then
    new.desactivee_le := coalesce(new.desactivee_le, now());
    return new;
  end if;
  if tg_op = 'UPDATE' and old.est_active then
    return new;
  end if;
  if app.appel_client_sans_permission(new.entreprise_id, 'entreprise.manage') then
    return new;
  end if;

  perform app.verrouiller_entreprise(new.entreprise_id);
  v_plan := app.plan_courant(new.entreprise_id);
  if v_plan is null then
    perform app.refuser('ABONNEMENT_INACTIF');
  end if;

  if not exists (
    select 1 from public.plan_activites
    where plan_code = v_plan and activite_code = new.activite_code
  ) then
    perform app.refuser('ACTIVITE_NON_AUTORISEE',
      jsonb_build_object('plan', v_plan, 'activite', new.activite_code));
  end if;

  select max_activites into v_max from public.plans where code = v_plan;
  select count(*) into v_nb
  from public.entreprise_activites
  where entreprise_id = new.entreprise_id
    and est_active
    and activite_code <> new.activite_code;

  if v_nb >= v_max then
    perform app.refuser('LIMITE_ACTIVITES', jsonb_build_object('plan', v_plan, 'max', v_max));
  end if;

  new.activee_le := now();
  new.desactivee_le := null;
  return new;
end;
$$;

create trigger entreprise_activites_limites
  before insert or update of est_active on public.entreprise_activites
  for each row execute function app.tg_verifier_activite();

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
  if v_max is null then
    perform app.refuser('ROLE_NON_AUTORISE', jsonb_build_object('plan', v_plan, 'role', new.role_code));
  end if;

  select count(*) into v_nb
  from public.membres_entreprise
  where entreprise_id = new.entreprise_id
    and statut = 'ACTIF'
    and role_code = new.role_code
    and id <> new.id;
  if v_nb >= v_max then
    perform app.refuser('LIMITE_ROLE',
      jsonb_build_object('plan', v_plan, 'role', new.role_code, 'max', v_max));
  end if;

  v_max := app.max_utilisateurs(new.entreprise_id, v_plan);
  select count(*) into v_nb
  from public.membres_entreprise
  where entreprise_id = new.entreprise_id and statut = 'ACTIF' and id <> new.id;
  if v_nb >= v_max then
    perform app.refuser('LIMITE_UTILISATEURS', jsonb_build_object('plan', v_plan, 'max', v_max));
  end if;

  return new;
end;
$$;

create trigger membres_entreprise_limites
  before insert or update or delete on public.membres_entreprise
  for each row execute function app.tg_verifier_membre();

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
  if v_max is null then
    perform app.refuser('ACTIVITE_NON_AUTORISEE',
      jsonb_build_object('plan', v_plan, 'activite', new.activite_code));
  end if;

  select count(*) into v_nb
  from public.perimetres
  where entreprise_id = new.entreprise_id
    and activite_code = new.activite_code
    and deleted_at is null
    and id <> new.id;
  if v_nb >= v_max then
    perform app.refuser('LIMITE_PERIMETRES',
      jsonb_build_object('plan', v_plan, 'activite', new.activite_code, 'max', v_max));
  end if;

  return new;
end;
$$;

create trigger perimetres_limites
  before insert or update on public.perimetres
  for each row execute function app.tg_verifier_perimetre();

-- Affectation : uniquement des périmètres de l'activité du rôle ; inutile pour
-- un rôle qui accède déjà à tous les périmètres.
create or replace function app.tg_verifier_affectation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text;
  v_role_activite text;
  v_perimetre_activite text;
begin
  if app.appel_client_sans_permission(new.entreprise_id, 'users.manage') then
    return new;
  end if;

  select m.role_code, r.activite_code into v_role, v_role_activite
  from public.membres_entreprise m
  join public.roles r on r.code = m.role_code
  where m.id = new.membre_id;

  if exists (
    select 1 from public.roles_permissions
    where role_code = v_role and permission_code = 'perimetres.access_all'
  ) then
    perform app.refuser('AFFECTATION_INUTILE', jsonb_build_object('role', v_role));
  end if;

  select activite_code into v_perimetre_activite from public.perimetres where id = new.perimetre_id;
  if v_role_activite is not null and v_role_activite <> v_perimetre_activite then
    perform app.refuser('AFFECTATION_ACTIVITE_INCOMPATIBLE',
      jsonb_build_object('role', v_role, 'activite', v_perimetre_activite));
  end if;
  return new;
end;
$$;

create trigger membre_perimetres_coherence
  before insert on public.membre_perimetres
  for each row execute function app.tg_verifier_affectation();

-- -----------------------------------------------------------------------------
-- Droits d'exécution des helpers
-- -----------------------------------------------------------------------------

revoke execute on all functions in schema app from public, anon;
grant execute on function
  app.plan_courant(uuid),
  app.est_membre(uuid),
  app.a_permission(uuid, text),
  app.acces_perimetre(uuid, uuid),
  app.appel_client_sans_permission(uuid, text),
  app.est_mon_membre(uuid),
  app.partage_entreprise(uuid),
  app.module_disponible(uuid, text),
  app.peut(uuid, text, text, uuid),
  app.max_utilisateurs(uuid, text)
to authenticated;

-- -----------------------------------------------------------------------------
-- RLS
-- -----------------------------------------------------------------------------

alter table public.activites enable row level security;
alter table public.plans enable row level security;
alter table public.plan_activites enable row level security;
alter table public.permissions enable row level security;
alter table public.roles enable row level security;
alter table public.roles_permissions enable row level security;
alter table public.plan_roles enable row level security;
alter table public.modules enable row level security;
alter table public.plan_modules enable row level security;
alter table public.profiles enable row level security;
alter table public.entreprises enable row level security;
alter table public.entreprise_activites enable row level security;
alter table public.abonnements enable row level security;
alter table public.membres_entreprise enable row level security;
alter table public.perimetres enable row level security;
alter table public.membre_perimetres enable row level security;

-- Catalogues : lecture seule pour les utilisateurs connectés.
create policy catalogue_lecture on public.activites for select to authenticated using (true);
create policy catalogue_lecture on public.plans for select to authenticated using (true);
create policy catalogue_lecture on public.plan_activites for select to authenticated using (true);
create policy catalogue_lecture on public.permissions for select to authenticated using (true);
create policy catalogue_lecture on public.roles for select to authenticated using (true);
create policy catalogue_lecture on public.roles_permissions for select to authenticated using (true);
create policy catalogue_lecture on public.plan_roles for select to authenticated using (true);
create policy catalogue_lecture on public.modules for select to authenticated using (true);
create policy catalogue_lecture on public.plan_modules for select to authenticated using (true);

-- Profils : soi-même, ou collègues d'une même entreprise.
create policy profils_lecture on public.profiles for select to authenticated
  using (id = (select auth.uid()) or app.partage_entreprise(id));
create policy profils_modification on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- Entreprises : création via back-office / RPC dédiée (pas d'insert client).
create policy entreprises_lecture on public.entreprises for select to authenticated
  using (app.est_membre(id));
create policy entreprises_modification on public.entreprises for update to authenticated
  using (app.a_permission(id, 'entreprise.manage'))
  with check (app.a_permission(id, 'entreprise.manage'));

create policy entreprise_activites_lecture on public.entreprise_activites for select to authenticated
  using (app.est_membre(entreprise_id));
create policy entreprise_activites_ajout on public.entreprise_activites for insert to authenticated
  with check (app.a_permission(entreprise_id, 'entreprise.manage'));
create policy entreprise_activites_modification on public.entreprise_activites for update to authenticated
  using (app.a_permission(entreprise_id, 'entreprise.manage'))
  with check (app.a_permission(entreprise_id, 'entreprise.manage'));

-- Abonnements : lecture seule côté client (gérés par le back-office).
create policy abonnements_lecture on public.abonnements for select to authenticated
  using (app.est_membre(entreprise_id));

-- Membres : lecture par les membres actifs ; chacun voit sa propre adhésion
-- (même suspendue) pour que l'application puisse l'expliquer.
create policy membres_lecture on public.membres_entreprise for select to authenticated
  using (user_id = (select auth.uid()) or app.est_membre(entreprise_id));
create policy membres_ajout on public.membres_entreprise for insert to authenticated
  with check (app.a_permission(entreprise_id, 'users.manage'));
create policy membres_modification on public.membres_entreprise for update to authenticated
  using (app.a_permission(entreprise_id, 'users.manage'))
  with check (app.a_permission(entreprise_id, 'users.manage'));
create policy membres_suppression on public.membres_entreprise for delete to authenticated
  using (app.a_permission(entreprise_id, 'users.manage'));

-- Périmètres : visibles uniquement si autorisés (affectation ou access_all).
-- Les lignes supprimées (deleted_at) restent lisibles pour la synchronisation.
create policy perimetres_lecture on public.perimetres for select to authenticated
  using (app.acces_perimetre(entreprise_id, id));
create policy perimetres_ajout on public.perimetres for insert to authenticated
  with check (app.a_permission(entreprise_id, 'perimetres.manage'));
create policy perimetres_modification on public.perimetres for update to authenticated
  using (app.a_permission(entreprise_id, 'perimetres.manage'))
  with check (app.a_permission(entreprise_id, 'perimetres.manage'));

create policy membre_perimetres_lecture on public.membre_perimetres for select to authenticated
  using (app.a_permission(entreprise_id, 'users.view') or app.est_mon_membre(membre_id));
create policy membre_perimetres_ajout on public.membre_perimetres for insert to authenticated
  with check (app.a_permission(entreprise_id, 'users.manage'));
create policy membre_perimetres_suppression on public.membre_perimetres for delete to authenticated
  using (app.a_permission(entreprise_id, 'users.manage'));

-- -----------------------------------------------------------------------------
-- Privilèges explicites (la RLS filtre ensuite les lignes).
-- Aucun accès anonyme. Les mises à jour sont limitées par colonne : un
-- administrateur ne peut modifier ni statut, ni version, ni rattachement tenant.
-- -----------------------------------------------------------------------------

revoke all on all tables in schema public from anon, authenticated;
grant all on all tables in schema public to service_role;

grant select on public.activites, public.plans, public.plan_activites, public.permissions,
  public.roles, public.roles_permissions, public.plan_roles, public.modules,
  public.plan_modules
to authenticated;

grant select on public.profiles to authenticated;
grant update (nom_complet, telephone, langue) on public.profiles to authenticated;

grant select on public.entreprises to authenticated;
grant update (nom, pays, devise, langue_defaut) on public.entreprises to authenticated;

grant select, insert on public.entreprise_activites to authenticated;
grant update (est_active) on public.entreprise_activites to authenticated;

grant select on public.abonnements to authenticated;

grant select, insert, delete on public.membres_entreprise to authenticated;
grant update (role_code, statut) on public.membres_entreprise to authenticated;

grant select, insert on public.perimetres to authenticated;
grant update (type, nom, code, est_actif, deleted_at) on public.perimetres to authenticated;

grant select, insert, delete on public.membre_perimetres to authenticated;
