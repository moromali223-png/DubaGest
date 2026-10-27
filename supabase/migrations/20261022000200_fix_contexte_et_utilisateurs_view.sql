-- =============================================================================
-- MIGRATION CORRECTIVE : VUE UTILISATEURS & GET_CONTEXTE_SESSION
--
-- Migration : 20261022000200_fix_contexte_et_utilisateurs_view.sql
-- Description :
--   1. Création de la vue public.utilisateurs basée sur public.profiles et auth.users.
--      Cette vue garantit une compatibilité totale et permanente avec toutes les
--      requêtes ciblant public.utilisateurs.
--   2. Mise à jour définitive de get_contexte_session pour renvoyer à la fois
--      'profil' et 'utilisateur', empêchant toute erreur 42P01.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Vue de compatibilité public.utilisateurs
-- -----------------------------------------------------------------------------
create or replace view public.utilisateurs as
select 
  p.id,
  u.email,
  p.nom,
  p.prenom,
  p.nom_complet,
  p.telephone,
  p.langue,
  null::uuid as derniere_entreprise_id
from public.profiles p
left join auth.users u on u.id = p.id;

grant select on public.utilisateurs to authenticated, anon, service_role;

-- -----------------------------------------------------------------------------
-- 2. Fonction public.get_contexte_session avec double compatibilité
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
    'utilisateur', (
      select jsonb_build_object('id', p.id, 'email', u.email, 'nom', p.nom, 'prenom', p.prenom,
                                'telephone', p.telephone, 'derniere_entreprise_id', null)
      from public.profiles p
      left join auth.users u on u.id = p.id
      where p.id = v_uid
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

revoke execute on function public.get_contexte_session(uuid) from public, anon;
grant execute on function public.get_contexte_session(uuid) to authenticated;
