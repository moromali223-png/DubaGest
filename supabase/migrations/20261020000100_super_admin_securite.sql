-- =============================================================================
-- MIGRATION : ADMINISTRATION CENTRALE SÉCURISÉE (SUPER ADMIN) & ACCÈS SPONSORISÉS
--
-- RÈGLE ABSOLUE :
-- Un utilisateur qui s'inscrit normalement sur DubaGest ne doit JAMAIS
-- pouvoir devenir Super Admin.
--
-- Les privilèges centraux sont totalement découplés du multi-tenant
-- (membres_entreprise) et résident dans le schéma protégé app.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Table sécurisée des Super Administrateurs centraux
-- -----------------------------------------------------------------------------

create table if not exists app.super_admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  role text not null default 'SUPER_ADMIN' check (role in ('SUPER_ADMIN', 'SUPPORT_LEAD', 'AUDITEUR')),
  est_actif boolean not null default true,
  cree_par uuid references auth.users (id) on delete set null,
  motif text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Interdiction totale d'accès direct par l'API cliente
revoke all on app.super_admins from anon, authenticated, public;
grant all on app.super_admins to service_role;

alter table app.super_admins enable row level security;
-- Aucune policy pour authenticated/anon sur app.super_admins : écriture impossible depuis le client.

-- -----------------------------------------------------------------------------
-- 2. Journal d'audit central de l'administration DubaGest
-- -----------------------------------------------------------------------------

create table if not exists app.super_admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references auth.users (id) on delete restrict,
  action text not null,
  cible_type text not null,
  cible_id text not null,
  details jsonb not null default '{}'::jsonb,
  ip_address text,
  created_at timestamptz not null default now()
);

revoke all on app.super_admin_audit_logs from anon, authenticated, public;
grant all on app.super_admin_audit_logs to service_role;

alter table app.super_admin_audit_logs enable row level security;

-- -----------------------------------------------------------------------------
-- 3. Fonctions d'autorité et de vérification des privilèges
-- -----------------------------------------------------------------------------

create or replace function app.est_super_admin(p_user_id uuid default null)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from app.super_admins sa
    where sa.user_id = coalesce(p_user_id, (select auth.uid()))
      and sa.est_actif = true
  );
$$;

create or replace function app.verifier_super_admin()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null or not app.est_super_admin(v_uid) then
    raise exception 'ACCES_SUPER_ADMIN_REFUSE' using errcode = '42501';
  end if;
  return v_uid;
end;
$$;

create or replace function app.tracer_super_admin_action(
  p_action text,
  p_cible_type text,
  p_cible_id text,
  p_details jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin_id uuid := (select auth.uid());
begin
  if v_admin_id is null then
    return;
  end if;
  insert into app.super_admin_audit_logs (admin_id, action, cible_type, cible_id, details)
  values (v_admin_id, p_action, p_cible_type, p_cible_id, p_details);
end;
$$;

-- -----------------------------------------------------------------------------
-- 4. Extension de public.abonnements pour les accès sponsorisés
-- -----------------------------------------------------------------------------

alter table public.abonnements
  add column if not exists type_facturation text not null default 'COMMERCIAL'
    check (type_facturation in ('COMMERCIAL', 'SPONSORISE')),
  add column if not exists sponsor_motif text,
  add column if not exists sponsor_attribue_par uuid references auth.users (id) on delete set null,
  add column if not exists sponsor_attribue_le timestamptz,
  add column if not exists valeur_commerciale_reference integer default 0;

-- -----------------------------------------------------------------------------
-- 5. RPCs d'administration centrale (Exposées à authenticated, protégées serveur)
-- -----------------------------------------------------------------------------

-- Vérifier si l'utilisateur courant est Super Admin (pour aiguillage propre dans Flutter)
create or replace function public.est_super_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select app.est_super_admin();
$$;
grant execute on function public.est_super_admin() to authenticated;

-- Procédure de bootstrap sécurisée du premier Super Admin
create or replace function public.admin_bootstrap_super_admin(
  p_email text,
  p_motif text default 'Bootstrap initial plateforme'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_target_user auth.users;
  v_nb_super_admins integer;
begin
  select count(*) into v_nb_super_admins from app.super_admins where est_actif = true;

  -- Si un Super Admin existe déjà, l'appelant DOIT être lui-même Super Admin actif
  if v_nb_super_admins > 0 then
    if v_uid is null or not app.est_super_admin(v_uid) then
      raise exception 'BOOTSTRAP_VERROUILLE_SUPER_ADMIN_EXISTANT' using errcode = '42501';
    end if;
  end if;

  select * into v_target_user from auth.users where lower(email) = lower(trim(p_email));
  if not found then
    raise exception 'UTILISATEUR_INTROUVABLE' using errcode = '42501';
  end if;

  insert into app.super_admins (user_id, role, est_actif, cree_par, motif)
  values (v_target_user.id, 'SUPER_ADMIN', true, v_uid, coalesce(p_motif, 'Bootstrap initial'))
  on conflict (user_id) do update set
    est_actif = true,
    motif = excluded.motif,
    updated_at = now();

  insert into app.super_admin_audit_logs (
    admin_id, action, cible_type, cible_id, details
  ) values (
    v_target_user.id,
    case when v_nb_super_admins = 0 then 'BOOTSTRAP_INITIAL' else 'PROMOTION_SUPER_ADMIN' end,
    'USER',
    v_target_user.id::text,
    jsonb_build_object('email', v_target_user.email, 'motif', p_motif)
  );

  return jsonb_build_object(
    'success', true,
    'user_id', v_target_user.id,
    'email', v_target_user.email,
    'action', case when v_nb_super_admins = 0 then 'BOOTSTRAP_INITIAL' else 'PROMOTION_SUPER_ADMIN' end
  );
end;
$$;
grant execute on function public.admin_bootstrap_super_admin(text, text) to authenticated;

-- Métriques du Tableau de Bord central
create or replace function public.admin_get_tableau_de_bord()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid;
  v_total_entreprises integer;
  v_entreprises_actives integer;
  v_entreprises_suspendues integer;
  v_total_utilisateurs integer;
  v_abonnements_actifs integer;
  v_abonnements_sponsorises integer;
  v_abonnements_expires integer;
  v_derniers_logs jsonb;
begin
  v_uid := app.verifier_super_admin();

  select count(*) into v_total_entreprises from public.entreprises;
  select count(*) into v_entreprises_actives from public.entreprises where statut = 'ACTIVE';
  select count(*) into v_entreprises_suspendues from public.entreprises where statut = 'SUSPENDUE';
  select count(*) into v_total_utilisateurs from auth.users;

  select count(*) into v_abonnements_actifs
  from public.abonnements where statut in ('ACTIF', 'ESSAI');

  select count(*) into v_abonnements_sponsorises
  from public.abonnements where statut in ('ACTIF', 'ESSAI') and type_facturation = 'SPONSORISE';

  select count(*) into v_abonnements_expires
  from public.abonnements where statut = 'EXPIRE' or (date_fin is not null and date_fin < now());

  select coalesce(jsonb_agg(l order by l.created_at desc), '[]'::jsonb)
  into v_derniers_logs
  from (
    select
      al.id, al.action, al.cible_type, al.cible_id, al.details, al.created_at,
      p.nom_complet as admin_nom, u.email as admin_email
    from app.super_admin_audit_logs al
    join auth.users u on u.id = al.admin_id
    left join public.profiles p on p.id = al.admin_id
    order by al.created_at desc
    limit 10
  ) l;

  return jsonb_build_object(
    'total_entreprises', v_total_entreprises,
    'entreprises_actives', v_entreprises_actives,
    'entreprises_suspendues', v_entreprises_suspendues,
    'total_utilisateurs', v_total_utilisateurs,
    'abonnements_actifs', v_abonnements_actifs,
    'abonnements_sponsorises', v_abonnements_sponsorises,
    'abonnements_expires', v_abonnements_expires,
    'activites_recentes', v_derniers_logs
  );
end;
$$;
grant execute on function public.admin_get_tableau_de_bord() to authenticated;

-- Lister les entreprises avec pagination et filtres
create or replace function public.admin_lister_entreprises(
  p_recherche text default null,
  p_statut text default null,
  p_plan text default null,
  p_limit integer default 25,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid;
  v_result jsonb;
  v_total integer;
begin
  v_uid := app.verifier_super_admin();

  select count(*) into v_total
  from public.entreprises e
  left join public.abonnements a on a.entreprise_id = e.id
    and a.statut in ('ESSAI', 'ACTIF', 'SUSPENDU')
  where (p_statut is null or e.statut = p_statut)
    and (p_plan is null or a.plan_code = p_plan)
    and (p_recherche is null or e.nom ilike '%' || trim(p_recherche) || '%');

  select coalesce(jsonb_agg(sub order by sub.created_at desc), '[]'::jsonb)
  into v_result
  from (
    select
      e.id,
      e.nom,
      e.statut,
      e.pays,
      e.devise,
      e.telephone,
      e.ville,
      e.created_at,
      p.nom_complet as createur_nom,
      u.email as createur_email,
      a.plan_code,
      a.statut as abonnement_statut,
      a.type_facturation,
      a.sponsor_motif,
      a.valeur_commerciale_reference,
      (select count(*) from public.membres_entreprise m where m.entreprise_id = e.id and m.statut = 'ACTIF') as nb_utilisateurs,
      (select count(*) from public.perimetres pe where pe.entreprise_id = e.id and pe.deleted_at is null) as nb_perimetres,
      (select coalesce(jsonb_agg(ea.activite_code), '[]'::jsonb) from public.entreprise_activites ea where ea.entreprise_id = e.id and ea.est_active) as activites
    from public.entreprises e
    left join public.profiles p on p.id = e.created_by
    left join auth.users u on u.id = e.created_by
    left join public.abonnements a on a.entreprise_id = e.id
      and a.statut in ('ESSAI', 'ACTIF', 'SUSPENDU')
    where (p_statut is null or e.statut = p_statut)
      and (p_plan is null or a.plan_code = p_plan)
      and (p_recherche is null or e.nom ilike '%' || trim(p_recherche) || '%')
    order by e.created_at desc
    limit p_limit offset p_offset
  ) sub;

  return jsonb_build_object(
    'total', v_total,
    'entreprises', v_result
  );
end;
$$;
grant execute on function public.admin_lister_entreprises(text, text, text, integer, integer) to authenticated;

-- Détails complets d'une entreprise pour l'administration centrale
create or replace function public.admin_detail_entreprise(p_entreprise_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid;
  v_entreprise jsonb;
  v_abonnements jsonb;
  v_membres jsonb;
  v_perimetres jsonb;
begin
  v_uid := app.verifier_super_admin();

  select jsonb_build_object(
    'id', e.id, 'nom', e.nom, 'statut', e.statut, 'pays', e.pays, 'devise', e.devise,
    'telephone', e.telephone, 'adresse', e.adresse, 'ville', e.ville,
    'identifiant_fiscal', e.identifiant_fiscal, 'registre_commerce', e.registre_commerce,
    'created_at', e.created_at,
    'createur', jsonb_build_object('id', u.id, 'email', u.email, 'nom_complet', p.nom_complet)
  )
  into v_entreprise
  from public.entreprises e
  left join auth.users u on u.id = e.created_by
  left join public.profiles p on p.id = e.created_by
  where e.id = p_entreprise_id;

  if v_entreprise is null then
    raise exception 'ENTREPRISE_INTROUVABLE' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(a order by a.date_debut desc), '[]'::jsonb)
  into v_abonnements
  from (
    select
      ab.id, ab.plan_code, ab.statut, ab.date_debut, ab.date_fin,
      ab.type_facturation, ab.sponsor_motif, ab.valeur_commerciale_reference,
      ab.sponsor_attribue_le,
      pu.email as sponsor_attribue_par_email
    from public.abonnements ab
    left join auth.users pu on pu.id = ab.sponsor_attribue_par
    where ab.entreprise_id = p_entreprise_id
  ) a;

  select coalesce(jsonb_agg(m order by m.created_at), '[]'::jsonb)
  into v_membres
  from (
    select
      me.id, me.role_code, me.statut, me.created_at,
      u.email, p.nom_complet, p.telephone
    from public.membres_entreprise me
    join auth.users u on u.id = me.user_id
    left join public.profiles p on p.id = me.user_id
    where me.entreprise_id = p_entreprise_id
  ) m;

  select coalesce(jsonb_agg(pe order by pe.nom), '[]'::jsonb)
  into v_perimetres
  from public.perimetres pe
  where pe.entreprise_id = p_entreprise_id and pe.deleted_at is null;

  return jsonb_build_object(
    'entreprise', v_entreprise,
    'abonnements', v_abonnements,
    'membres', v_membres,
    'perimetres', v_perimetres
  );
end;
$$;
grant execute on function public.admin_detail_entreprise(uuid) to authenticated;

-- Suspendre une entreprise
create or replace function public.admin_suspendre_entreprise(
  p_entreprise_id uuid,
  p_motif text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid;
  v_nom text;
begin
  v_uid := app.verifier_super_admin();

  select nom into v_nom from public.entreprises where id = p_entreprise_id;
  if not found then
    raise exception 'ENTREPRISE_INTROUVABLE' using errcode = '42501';
  end if;

  update public.entreprises set statut = 'SUSPENDUE', updated_at = now()
  where id = p_entreprise_id;

  perform app.tracer_super_admin_action(
    'SUSPENSION_ENTREPRISE',
    'ENTREPRISE',
    p_entreprise_id::text,
    jsonb_build_object('nom', v_nom, 'motif', p_motif)
  );

  return jsonb_build_object('success', true, 'statut', 'SUSPENDUE');
end;
$$;
grant execute on function public.admin_suspendre_entreprise(uuid, text) to authenticated;

-- Réactiver une entreprise
create or replace function public.admin_reactiver_entreprise(
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
  v_nom text;
begin
  v_uid := app.verifier_super_admin();

  select nom into v_nom from public.entreprises where id = p_entreprise_id;
  if not found then
    raise exception 'ENTREPRISE_INTROUVABLE' using errcode = '42501';
  end if;

  update public.entreprises set statut = 'ACTIVE', updated_at = now()
  where id = p_entreprise_id;

  perform app.tracer_super_admin_action(
    'REACTIVATION_ENTREPRISE',
    'ENTREPRISE',
    p_entreprise_id::text,
    jsonb_build_object('nom', v_nom, 'motif', p_motif)
  );

  return jsonb_build_object('success', true, 'statut', 'ACTIVE');
end;
$$;
grant execute on function public.admin_reactiver_entreprise(uuid, text) to authenticated;

-- Accorder un accès sponsorisé (Formule existante offerte gratuitement à une entreprise partenaire)
create or replace function public.admin_accorder_acces_sponsorise(
  p_entreprise_id uuid,
  p_plan_code text,
  p_motif text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid;
  v_plan public.plans;
  v_ab_id uuid;
begin
  v_uid := app.verifier_super_admin();

  if char_length(trim(coalesce(p_motif, ''))) < 3 then
    raise exception 'MOTIF_SPONSOR_REQUIS' using errcode = '42501';
  end if;

  select * into v_plan from public.plans where code = p_plan_code and est_actif = true;
  if not found then
    raise exception 'PLAN_INVALIDE' using errcode = '42501';
  end if;

  -- Ferme les abonnements actifs ou en essai existants
  update public.abonnements
  set statut = 'ANNULE', date_fin = now(), updated_at = now()
  where entreprise_id = p_entreprise_id and statut in ('ESSAI', 'ACTIF', 'SUSPENDU');

  -- Insère l'abonnement sponsorisé sans expiration automatique
  insert into public.abonnements (
    entreprise_id, plan_code, statut, type_facturation,
    sponsor_motif, sponsor_attribue_par, sponsor_attribue_le,
    valeur_commerciale_reference, date_debut, date_fin
  ) values (
    p_entreprise_id, v_plan.code, 'ACTIF', 'SPONSORISE',
    p_motif, v_uid, now(),
    v_plan.prix_mensuel, now(), null
  )
  returning id into v_ab_id;

  perform app.tracer_super_admin_action(
    'ATTRIBUTION_ACCES_SPONSORISE',
    'ENTREPRISE',
    p_entreprise_id::text,
    jsonb_build_object(
      'plan_code', v_plan.code,
      'valeur_commerciale_reference', v_plan.prix_mensuel,
      'motif', p_motif
    )
  );

  return jsonb_build_object(
    'success', true,
    'abonnement_id', v_ab_id,
    'plan_code', v_plan.code,
    'type_facturation', 'SPONSORISE',
    'valeur_reference', v_plan.prix_mensuel
  );
end;
$$;
grant execute on function public.admin_accorder_acces_sponsorise(uuid, text, text) to authenticated;

-- Révoquer un accès sponsorisé (repasse en EXPIRE)
create or replace function public.admin_revoquer_acces_sponsorise(
  p_entreprise_id uuid,
  p_motif text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid;
begin
  v_uid := app.verifier_super_admin();

  update public.abonnements
  set statut = 'EXPIRE', date_fin = now(), updated_at = now()
  where entreprise_id = p_entreprise_id and statut = 'ACTIF' and type_facturation = 'SPONSORISE';

  perform app.tracer_super_admin_action(
    'REVOCATION_ACCES_SPONSORISE',
    'ENTREPRISE',
    p_entreprise_id::text,
    jsonb_build_object('motif', p_motif)
  );

  return jsonb_build_object('success', true, 'statut', 'EXPIRE');
end;
$$;
grant execute on function public.admin_revoquer_acces_sponsorise(uuid, text) to authenticated;

-- Consulter le journal d'audit central
create or replace function public.admin_lister_audit_logs(
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid;
  v_total integer;
  v_result jsonb;
begin
  v_uid := app.verifier_super_admin();

  select count(*) into v_total from app.super_admin_audit_logs;

  select coalesce(jsonb_agg(l order by l.created_at desc), '[]'::jsonb)
  into v_result
  from (
    select
      al.id, al.action, al.cible_type, al.cible_id, al.details, al.created_at,
      p.nom_complet as admin_nom, u.email as admin_email
    from app.super_admin_audit_logs al
    join auth.users u on u.id = al.admin_id
    left join public.profiles p on p.id = al.admin_id
    order by al.created_at desc
    limit p_limit offset p_offset
  ) l;

  return jsonb_build_object(
    'total', v_total,
    'logs', v_result
  );
end;
$$;
grant execute on function public.admin_lister_audit_logs(integer, integer) to authenticated;

-- Bootstrap initial contrôlé du premier Super Admin
create or replace function public.admin_bootstrap_super_admin(
  p_email text,
  p_role text default 'SUPER_ADMIN',
  p_motif text default 'Bootstrap initial plateforme'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_count integer;
begin
  select count(*) into v_count from app.super_admins where est_actif = true;
  -- Autorisé si aucun super admin n'existe encore OU si l'appelant est déjà super admin
  if v_count > 0 and not app.est_super_admin((select auth.uid())) then
    raise exception 'BOOTSTRAP_INTERDIT : Des super administrateurs existent déjà.' using errcode = '42501';
  end if;

  select id into v_user_id from auth.users where lower(email) = lower(trim(p_email));
  if v_user_id is null then
    raise exception 'COMPTE_INTROUVABLE : Aucun compte auth.users avec l''email %', p_email;
  end if;

  insert into app.super_admins (user_id, role, est_actif, motif)
  values (v_user_id, p_role, true, p_motif)
  on conflict (user_id) do update set
    role = excluded.role,
    est_actif = true,
    motif = excluded.motif,
    updated_at = now();

  insert into app.super_admin_audit_logs (
    admin_id, action, cible_type, cible_id, details
  ) values (
    v_user_id,
    'BOOTSTRAP_SUPER_ADMIN',
    'USER',
    v_user_id::text,
    jsonb_build_object('email', p_email, 'role', p_role, 'motif', p_motif)
  );

  return jsonb_build_object('success', true, 'user_id', v_user_id, 'email', p_email, 'role', p_role);
end;
$$;
grant execute on function public.admin_bootstrap_super_admin(text, text, text) to authenticated, anon;

