-- =============================================================================
-- MIGRATION : Retrait de CATALOGUE_SEUL des formules d'abonnement récurrent
-- Date : 2026-11-25
-- Description :
--   Le Catalogue Numérique est un achat / paiement unique (one-time purchase / à vie),
--   il ne doit donc JAMAIS figurer dans le catalogue des abonnements récurrents
--   (Normal 1000 FCFA/m, Moyen 2000 FCFA/m, Pro 5000 FCFA/m), ni être proposé
--   par tranches mensuelles (1 mois, 3 mois, 6 mois, 12 mois).
-- =============================================================================

-- 1. Marquer CATALOGUE_SEUL comme inactif dans les plans d'abonnement récurrents
update public.plans
set est_actif = false, updated_at = now()
where code = 'CATALOGUE_SEUL';

-- 2. Désactiver les tarifs par durée pour CATALOGUE_SEUL
update public.tarifs_durees_plans
set est_actif = false, updated_at = now()
where plan_code = 'CATALOGUE_SEUL';

-- 3. Mise à jour de la fonction lister_catalogue_plans pour exclure formellement CATALOGUE_SEUL
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
        'description', coalesce(p.description, ''),
        'ordre', p.ordre,
        'prix_mensuel', p.prix_mensuel,
        'devise', 'XOF',
        'max_activites', p.max_activites,
        'activites', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'activite_code', pa.activite_code,
            'activite_libelle', ac.libelle,
            'max_utilisateurs', pa.max_utilisateurs,
            'max_perimetres', pa.max_perimetres
          ) order by ac.ordre), '[]'::jsonb)
          from public.plan_activites pa
          join public.activites ac on ac.code = pa.activite_code
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
          select coalesce(jsonb_agg(jsonb_build_object(
            'code', pm.module_code,
            'libelle', mo.libelle,
            'activite_code', mo.activite_code,
            'ordre', mo.ordre
          ) order by mo.ordre), '[]'::jsonb)
          from public.plan_modules pm
          join public.modules mo on mo.code = pm.module_code
          where pm.plan_code = p.code
        ),
        'tarifs_durees', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'duree_mois', t.duree_mois,
            'montant_total', t.montant_total,
            'remise_pourcentage', t.remise_pourcentage,
            'badge_promo', t.badge_promo,
            'description', t.description
          ) order by t.duree_mois), '[]'::jsonb)
          from public.tarifs_durees_plans t
          where t.plan_code = p.code and t.est_actif
        )
      ) order by p.ordre
    ),
    '[]'::jsonb
  )
  from public.plans p
  where p.est_actif and p.code <> 'CATALOGUE_SEUL';
$$;

grant execute on function public.lister_catalogue_plans() to authenticated, anon;
