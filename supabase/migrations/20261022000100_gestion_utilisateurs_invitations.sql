-- =============================================================================
-- GESTION SÉCURISÉE DES UTILISATEURS, MEMBRES ET INVITATIONS
--
-- Migration : 20261022000100_gestion_utilisateurs_invitations.sql
-- Description :
--   1. RPC renvoyer_invitation : renouvellement sécurisé de token et date d'expiration
--   2. RPC supprimer_invitation : purge propre des invitations annulées ou expirées
--   3. RPC modifier_membre : mise à jour atomique du rôle et des affectations
--   4. RPC changer_statut_membre : activation/suspension contrôlée avec vérification des quotas
--   5. RPC retirer_membre : révocation sécurisée avec conservation de l'historique d'audit
--   6. Mise à jour de get_contexte_session : calcul exact des places occupées (actifs + invitations)
--   7. Triggers d'audit étendus pour invitations (SUPPRESSION)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Triggers d'audit sur les invitations (ajout de SUPPRESSION)
-- -----------------------------------------------------------------------------
drop trigger if exists audit_invitations on public.invitations;
create trigger audit_invitations after insert or update or delete on public.invitations
  for each row execute function app.tg_audit();

-- -----------------------------------------------------------------------------
-- 2. RPC renvoyer_invitation (renouvellement du jeton et prolongation d'expiration)
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
  v_jeton text;
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

  -- Vérifier si l'utilisateur est déjà membre actif
  if exists (
    select 1 from public.membres_entreprise m
    join auth.users u on u.id = m.user_id
    where m.entreprise_id = v_inv.entreprise_id
      and lower(u.email) = v_inv.email
      and m.statut = 'ACTIF'
  ) then
    perform app.refuser('DEJA_MEMBRE');
  end if;

  perform app.verrouiller_entreprise(v_inv.entreprise_id);
  v_plan := app.plan_courant(v_inv.entreprise_id);
  if v_plan is null then
    perform app.refuser('ABONNEMENT_INACTIF');
  end if;

  -- Quota global d'utilisateurs
  v_max := app.max_utilisateurs(v_inv.entreprise_id, v_plan);
  select count(*) into v_nb from (
    select 1 from public.membres_entreprise
    where entreprise_id = v_inv.entreprise_id and statut = 'ACTIF'
    union all
    select 1 from public.invitations
    where entreprise_id = v_inv.entreprise_id
      and statut = 'PENDING'
      and expires_at > now()
      and id <> v_inv.id
  ) s;

  if v_max is not null and v_nb >= v_max then
    perform app.refuser('LIMITE_UTILISATEURS', jsonb_build_object('plan', v_plan, 'max', v_max));
  end if;

  -- Quota par rôle
  select max_membres into v_quota from public.plan_roles
  where plan_code = v_plan and role_code = v_inv.role_code;

  if v_quota is not null then
    select count(*) into v_nb from (
      select 1 from public.membres_entreprise
      where entreprise_id = v_inv.entreprise_id and statut = 'ACTIF' and role_code = v_inv.role_code
      union all
      select 1 from public.invitations
      where entreprise_id = v_inv.entreprise_id
        and statut = 'PENDING'
        and expires_at > now()
        and role_code = v_inv.role_code
        and id <> v_inv.id
    ) s;
    if v_nb >= v_quota then
      perform app.refuser('LIMITE_ROLE', jsonb_build_object('plan', v_plan, 'role', v_inv.role_code, 'max', v_quota));
    end if;
  end if;

  -- Générer un nouveau jeton d'invitation sécurisé
  v_jeton := rtrim(translate(encode(extensions.gen_random_bytes(24), 'base64'), '+/', '-_'), '=');
  v_expires := now() + interval '7 days';

  update public.invitations
  set token_hash = app.hash_jeton(v_jeton),
      statut = 'PENDING',
      expires_at = v_expires,
      cancelled_at = null,
      updated_at = now()
  where id = v_inv.id;

  return jsonb_build_object('id', v_inv.id, 'token', v_jeton, 'expires_at', v_expires);
end;
$$;

-- -----------------------------------------------------------------------------
-- 3. RPC supprimer_invitation (purge propre pour invitations expirées ou annulées)
-- -----------------------------------------------------------------------------
create or replace function public.supprimer_invitation(p_invitation_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_inv public.invitations;
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

  -- Seules les invitations non actives (annulées, expirées ou déjà acceptées) peuvent être supprimées
  if v_inv.statut = 'PENDING' and v_inv.expires_at > now() then
    perform app.refuser('INVITATION_ACTIVE_NON_SUPPRIMABLE');
  end if;

  delete from public.invitation_perimetres where invitation_id = p_invitation_id;
  delete from public.invitations where id = p_invitation_id;
end;
$$;

-- -----------------------------------------------------------------------------
-- 4. RPC modifier_membre (rôle et synchronisation atomique des périmètres)
-- -----------------------------------------------------------------------------
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
  v_uid uuid := auth.uid();
  v_membre public.membres_entreprise;
  v_role public.roles;
  v_acces_tous boolean;
  v_pid uuid;
begin
  if v_uid is null then
    raise exception 'NON_AUTHENTIFIE' using errcode = '42501';
  end if;

  if not app.a_permission(p_entreprise_id, 'users.manage') then
    raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
  end if;

  perform app.verrouiller_entreprise(p_entreprise_id);

  select * into v_membre from public.membres_entreprise
  where id = p_membre_id and entreprise_id = p_entreprise_id
  for update;

  if not found then
    perform app.refuser('MEMBRE_INTROUVABLE');
  end if;

  select * into v_role from public.roles where code = p_role_code;
  if not found then
    perform app.refuser('ROLE_INVALIDE');
  end if;

  -- 1. Mise à jour du rôle (déclenche app.tg_verifier_membre qui vérifie last admin et quotas)
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
  elsif p_perimetre_ids is not null then
    -- Supprimer les périmètres retirés
    delete from public.membre_perimetres
    where membre_id = p_membre_id
      and entreprise_id = p_entreprise_id
      and not (perimetre_id = any(p_perimetre_ids));

    -- Insérer les nouveaux périmètres valides
    foreach v_pid in array p_perimetre_ids loop
      if exists (
        select 1 from public.perimetres
        where id = v_pid
          and entreprise_id = p_entreprise_id
          and deleted_at is null
          and (v_role.activite_code is null or activite_code = v_role.activite_code)
      ) then
        insert into public.membre_perimetres (entreprise_id, membre_id, perimetre_id)
        values (p_entreprise_id, p_membre_id, v_pid)
        on conflict do nothing;
      end if;
    end loop;
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- 5. RPC changer_statut_membre (activation / suspension sécurisée)
-- -----------------------------------------------------------------------------
create or replace function public.changer_statut_membre(
  p_entreprise_id uuid,
  p_membre_id uuid,
  p_statut text,
  p_motif text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_membre public.membres_entreprise;
  v_plan text;
  v_max integer;
  v_nb integer;
begin
  if v_uid is null then
    raise exception 'NON_AUTHENTIFIE' using errcode = '42501';
  end if;

  if not app.a_permission(p_entreprise_id, 'users.manage') then
    raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
  end if;

  if p_statut not in ('ACTIF', 'SUSPENDU') then
    perform app.refuser('STATUT_INVALIDE');
  end if;

  perform app.verrouiller_entreprise(p_entreprise_id);

  select * into v_membre from public.membres_entreprise
  where id = p_membre_id and entreprise_id = p_entreprise_id
  for update;

  if not found then
    perform app.refuser('MEMBRE_INTROUVABLE');
  end if;

  if v_membre.statut = p_statut then
    return;
  end if;

  -- Empêcher l'administrateur de suspendre son propre compte
  if v_membre.user_id = v_uid and p_statut = 'SUSPENDU' then
    perform app.refuser('AUTO_SUSPENSION_INTERDITE');
  end if;

  -- Si on réactive le membre, revérifier le quota du forfait
  if p_statut = 'ACTIF' then
    v_plan := app.plan_courant(p_entreprise_id);
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
  end if;

  -- Mise à jour : le trigger tg_verifier_membre protégera le dernier administrateur
  update public.membres_entreprise
  set statut = p_statut,
      updated_at = now()
  where id = p_membre_id;
end;
$$;

-- -----------------------------------------------------------------------------
-- 6. RPC retirer_membre (suppression sécurisée de l'entreprise)
-- -----------------------------------------------------------------------------
create or replace function public.retirer_membre(
  p_entreprise_id uuid,
  p_membre_id uuid,
  p_motif text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_membre public.membres_entreprise;
begin
  if v_uid is null then
    raise exception 'NON_AUTHENTIFIE' using errcode = '42501';
  end if;

  if not app.a_permission(p_entreprise_id, 'users.manage') then
    raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
  end if;

  perform app.verrouiller_entreprise(p_entreprise_id);

  select * into v_membre from public.membres_entreprise
  where id = p_membre_id and entreprise_id = p_entreprise_id
  for update;

  if not found then
    perform app.refuser('MEMBRE_INTROUVABLE');
  end if;

  if v_membre.user_id = v_uid then
    perform app.refuser('AUTO_RETRAIT_INTERDIT');
  end if;

  -- Nettoyage des périmètres puis du membre (tg_verifier_membre bloque le dernier administrateur)
  delete from public.membre_perimetres where membre_id = p_membre_id and entreprise_id = p_entreprise_id;
  delete from public.membres_entreprise where id = p_membre_id and entreprise_id = p_entreprise_id;
end;
$$;

-- -----------------------------------------------------------------------------
-- 7. Mise à jour de get_contexte_session (Capacité et décompte exact)
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
  v_actifs integer;
  v_en_attente integer;
  v_max_users integer;
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

  -- Abonnement courant
  select a.plan_code into v_plan_code
  from public.abonnements a
  where a.entreprise_id = v_eid
  order by (a.statut in ('ESSAI', 'ACTIF', 'SUSPENDU')) desc, a.date_debut desc
  limit 1;

  -- Décompte d'utilisation exacte des utilisateurs
  select count(*) into v_actifs
  from public.membres_entreprise
  where entreprise_id = v_eid and statut = 'ACTIF';

  select count(*) into v_en_attente
  from public.invitations
  where entreprise_id = v_eid and statut = 'PENDING' and expires_at > now();

  v_max_users := app.max_utilisateurs(v_eid, v_plan_code);

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
        'libelle', r.libelle,
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
      'utilisateurs', v_actifs + v_en_attente,
      'utilisateurs_actifs', v_actifs,
      'invitations_en_attente', v_en_attente,
      'utilisateurs_occupes', v_actifs + v_en_attente,
      'utilisateurs_max', v_max_users,
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

-- -----------------------------------------------------------------------------
-- 8. Permissions et Grants
-- -----------------------------------------------------------------------------
revoke execute on function
  public.renvoyer_invitation(uuid),
  public.supprimer_invitation(uuid),
  public.modifier_membre(uuid, uuid, text, uuid[]),
  public.changer_statut_membre(uuid, uuid, text, text),
  public.retirer_membre(uuid, uuid, text)
from public, anon;

grant execute on function
  public.renvoyer_invitation(uuid),
  public.supprimer_invitation(uuid),
  public.modifier_membre(uuid, uuid, text, uuid[]),
  public.changer_statut_membre(uuid, uuid, text, text),
  public.retirer_membre(uuid, uuid, text)
to authenticated;
