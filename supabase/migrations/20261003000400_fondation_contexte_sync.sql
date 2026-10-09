-- =============================================================================
-- FONDATION V1 — CONTEXTE DE SESSION + SYNCHRONISATION
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Contexte de session : un seul appel après connexion, mis en cache hors-ligne.
-- entreprise → abonnement/plan → activités → modules → rôle → permissions →
-- périmètres → consommation des limites.
-- -----------------------------------------------------------------------------

create or replace function public.get_contexte_session(p_entreprise_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_membre public.membres_entreprise;
  v_eid uuid;
  v_plan_code text;
  v_acces_tout boolean;
  v_base jsonb;
begin
  if v_uid is null then
    raise exception 'NON_AUTHENTIFIE' using errcode = '42501';
  end if;

  v_base := jsonb_build_object(
    'server_time', now(),
    'profil', (
      select jsonb_build_object('id', p.id, 'nom_complet', p.nom_complet,
                                'telephone', p.telephone, 'langue', p.langue)
      from public.profiles p where p.id = v_uid
    ),
    'entreprises', (
      select coalesce(jsonb_agg(jsonb_build_object('id', e.id, 'nom', e.nom) order by e.nom), '[]'::jsonb)
      from public.membres_entreprise m
      join public.entreprises e on e.id = m.entreprise_id
      where m.user_id = v_uid
    )
  );

  select m.* into v_membre
  from public.membres_entreprise m
  where m.user_id = v_uid
    and (p_entreprise_id is null or m.entreprise_id = p_entreprise_id)
  order by (m.statut = 'ACTIF') desc, m.created_at
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
                                'date_debut', a.date_debut, 'date_fin', a.date_fin)
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
        'permission_acces', mo.permission_acces, 'ordre', mo.ordre) order by mo.ordre), '[]'::jsonb)
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
          where entreprise_id = v_eid and deleted_at is null group by activite_code
        ) s
      )
    )
  );
end;
$$;

revoke execute on function public.get_contexte_session(uuid) from public, anon;
grant execute on function public.get_contexte_session(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- Synchronisation hors-ligne
-- -----------------------------------------------------------------------------

-- Tables autorisées à la synchronisation et colonnes modifiables par le client.
-- Toute table synchronisée doit avoir : id uuid, version, updated_at, deleted_at.
create table app.sync_tables (
  table_name text primary key,
  colonnes_creation text[] not null,
  colonnes_modification text[] not null
);

insert into app.sync_tables (table_name, colonnes_creation, colonnes_modification) values
  ('perimetres',
   array['entreprise_id', 'activite_code', 'type', 'nom', 'code', 'est_actif'],
   array['type', 'nom', 'code', 'est_actif']);

grant select on app.sync_tables to authenticated;
grant execute on function app.refuser(text, jsonb) to authenticated;

-- Journal d'idempotence : une opération déjà appliquée renvoie le même résultat.
create table public.sync_operations (
  op_id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  table_name text not null,
  record_id uuid not null,
  operation text not null check (operation in ('INSERT', 'UPDATE', 'DELETE')),
  resultat jsonb not null,
  applied_at timestamptz not null default now()
);
create index sync_operations_user_idx on public.sync_operations (user_id, applied_at desc);

alter table public.sync_operations enable row level security;
create policy sync_operations_lecture on public.sync_operations for select to authenticated
  using (user_id = (select auth.uid()));
create policy sync_operations_ajout on public.sync_operations for insert to authenticated
  with check (user_id = (select auth.uid()));
revoke all on public.sync_operations from anon, authenticated;
grant select, insert on public.sync_operations to authenticated;
grant all on public.sync_operations to service_role;

-- Application idempotente d'une opération locale, avec contrôle de version.
-- SECURITY INVOKER : RLS, privilèges colonnes et triggers de limites s'appliquent.
-- Résultat : {statut: APPLIQUE | CONFLIT | INTROUVABLE | INTERDIT, ligne: {...}}
create or replace function public.sync_push(
  p_op_id uuid,
  p_table text,
  p_operation text,
  p_record_id uuid,
  p_base_version integer default null,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_config app.sync_tables;
  v_deja jsonb;
  v_cols text;
  v_src text;
  v_ligne jsonb;
  v_actuelle jsonb;
  v_statut text;
  v_resultat jsonb;
begin
  if auth.uid() is null then
    raise exception 'NON_AUTHENTIFIE' using errcode = '42501';
  end if;

  select s.resultat into v_deja from public.sync_operations s where s.op_id = p_op_id;
  if found then
    return v_deja || jsonb_build_object('rejoue', true);
  end if;

  select * into v_config from app.sync_tables t where t.table_name = p_table;
  if not found then
    perform app.refuser('SYNC_TABLE_INCONNUE', jsonb_build_object('table', p_table));
  end if;

  if p_operation = 'INSERT' then
    select string_agg(format('%I', c), ', '), string_agg(format('r.%I', c), ', ')
      into v_cols, v_src
    from unnest(v_config.colonnes_creation) c
    where p_payload ? c;

    execute format(
      'insert into public.%1$I as t (id%2$s) select $2%3$s '
      'from jsonb_populate_record(null::public.%1$I, $1) r returning to_jsonb(t.*)',
      p_table, coalesce(', ' || v_cols, ''), coalesce(', ' || v_src, ''))
      using p_payload, p_record_id
      into v_ligne;

  elsif p_operation = 'UPDATE' then
    select string_agg(format('%I', c), ', '), string_agg(format('r.%I', c), ', ')
      into v_cols, v_src
    from unnest(v_config.colonnes_modification) c
    where p_payload ? c;

    if v_cols is null then
      perform app.refuser('SYNC_PAYLOAD_VIDE');
    end if;

    execute format(
      'update public.%1$I as t set (%2$s) = (select %3$s '
      'from jsonb_populate_record(null::public.%1$I, $1) r) '
      'where t.id = $2 and t.version = $3 and t.deleted_at is null '
      'returning to_jsonb(t.*)',
      p_table, v_cols, v_src)
      using p_payload, p_record_id, p_base_version
      into v_ligne;

  elsif p_operation = 'DELETE' then
    execute format(
      'update public.%1$I as t set deleted_at = now() '
      'where t.id = $1 and t.version = $2 and t.deleted_at is null '
      'returning to_jsonb(t.*)',
      p_table)
      using p_record_id, p_base_version
      into v_ligne;

  else
    perform app.refuser('SYNC_OPERATION_INVALIDE', jsonb_build_object('operation', p_operation));
  end if;

  if v_ligne is not null then
    v_statut := 'APPLIQUE';
  else
    -- Aucune ligne touchée : diagnostiquer pourquoi.
    execute format('select to_jsonb(t.*) from public.%I t where t.id = $1', p_table)
      using p_record_id
      into v_actuelle;

    if v_actuelle is null then
      v_statut := 'INTROUVABLE';
    elsif p_operation = 'DELETE' and v_actuelle ->> 'deleted_at' is not null then
      v_statut := 'APPLIQUE';
      v_ligne := v_actuelle;
    elsif (v_actuelle ->> 'version')::integer = p_base_version
          and v_actuelle ->> 'deleted_at' is null then
      -- Version identique mais ligne non modifiée : refus RLS.
      v_statut := 'INTERDIT';
    else
      v_statut := 'CONFLIT';
      v_ligne := v_actuelle;
    end if;
  end if;

  v_resultat := jsonb_build_object('statut', v_statut, 'ligne', v_ligne);

  insert into public.sync_operations (op_id, table_name, record_id, operation, resultat)
  values (p_op_id, p_table, p_record_id, p_operation, v_resultat);

  return v_resultat;
end;
$$;

revoke execute on function public.sync_push(uuid, text, text, uuid, integer, jsonb) from public, anon;
grant execute on function public.sync_push(uuid, text, text, uuid, integer, jsonb) to authenticated;
