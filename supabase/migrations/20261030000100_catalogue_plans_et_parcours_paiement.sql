-- =============================================================================
-- Migration: Catalogue public des plans et dissociation des parcours d'abonnement
-- Migration: 20261030000100_catalogue_plans_et_parcours_paiement.sql
-- =============================================================================

create or replace function public.lister_catalogue_plans()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'code', p.code,
        'nom', p.nom,
        'ordre', p.ordre,
        'prix_mensuel', p.prix_mensuel,
        'devise', 'XOF',
        'max_activites', p.max_activites,
        'activites', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'activite_code', pa.activite_code,
            'max_utilisateurs', pa.max_utilisateurs,
            'max_perimetres', pa.max_perimetres
          ) order by pa.activite_code), '[]'::jsonb)
          from public.plan_activites pa
          where pa.plan_code = p.code
        ),
        'roles', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'role_code', pr.role_code,
            'max_membres', pr.max_membres
          ) order by pr.role_code), '[]'::jsonb)
          from public.plan_roles pr
          where pr.plan_code = p.code
        ),
        'modules', (
          select coalesce(jsonb_agg(pm.module_code order by pm.module_code), '[]'::jsonb)
          from public.plan_modules pm
          where pm.plan_code = p.code
        )
      ) order by p.ordre
    ),
    '[]'::jsonb
  )
  from public.plans p
  where p.est_actif;
$$;

grant execute on function public.lister_catalogue_plans() to authenticated, anon;

