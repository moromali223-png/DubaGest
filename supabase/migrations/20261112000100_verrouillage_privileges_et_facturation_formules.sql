-- =============================================================================
-- MIGRATION : Verrouillage des privilèges (Module intelligent) et Facturation exacte des formules
-- Version : 20261112000100_verrouillage_privileges_et_facturation_formules.sql
-- Description :
--   1. Déclaration officielle du module 'commerce.intelligence' dans public.modules
--   2. Attribution stricte des privilèges :
--      - Formule NORMAL (1 000 FCFA) : Module intelligent INTERDIT
--      - Formule MOYEN (2 000 FCFA) : Module intelligent AUTORISÉ
--      - Formule PRO (5 000 FCFA) : Module intelligent AUTORISÉ
--   3. Barème officiel consolidé dans public.tarifs_durees_plans (1 000 F / 2 000 F / 5 000 F)
--   4. Sécurisation serveur de public.initialiser_paiement_abonnement :
--      - Détermination autoritaire du montant d'après la formule réelle
--      - Interdiction de tout montant arbitraire ou repli forcé sur 1 000 FCFA
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Enregistrement officiel du module 'commerce.intelligence'
-- -----------------------------------------------------------------------------
insert into public.modules (code, libelle, activite_code, permission_acces, ordre, categorie, est_actif)
values (
  'commerce.intelligence',
  'Intelligence commerciale',
  'COMMERCE',
  'sales.view',
  16,
  'METIER',
  true
)
on conflict (code) do update set
  libelle = excluded.libelle,
  activite_code = excluded.activite_code,
  permission_acces = excluded.permission_acces,
  ordre = excluded.ordre,
  categorie = excluded.categorie,
  est_actif = true,
  updated_at = now();

-- -----------------------------------------------------------------------------
-- 2. Matrice stricte des privilèges dans public.plan_modules
--    Seul interdit pour la formule 1 000 FCFA (NORMAL) : module intelligent.
--    Formules 2 000 FCFA (MOYEN) et 5 000 FCFA (PRO) : module intelligent inclus.
-- -----------------------------------------------------------------------------
delete from public.plan_modules
where module_code = 'commerce.intelligence';

insert into public.plan_modules (plan_code, module_code)
values
  ('MOYEN', 'commerce.intelligence'),
  ('PRO', 'commerce.intelligence')
on conflict (plan_code, module_code) do nothing;

-- -----------------------------------------------------------------------------
-- 3. Consolidation des tarifs officiels dans public.tarifs_durees_plans
-- -----------------------------------------------------------------------------
insert into public.tarifs_durees_plans (plan_code, duree_mois, montant_total, remise_pourcentage, badge_promo, description, est_actif)
values
  -- Formule NORMAL (1 000 FCFA / mois)
  ('NORMAL', 1,  1000,  0, null, 'Facturation mensuelle sans engagement', true),
  ('NORMAL', 3,  3000,  0, null, 'Tranche trimestrielle', true),
  ('NORMAL', 6,  6000,  0, null, 'Tranche semestrielle', true),
  ('NORMAL', 12, 10000, 17, '2 mois offerts', 'Abonnement annuel économique (10 000 au lieu de 12 000 FCFA)', true),

  -- Formule MOYEN (2 000 FCFA / mois)
  ('MOYEN',  1,  2000,  0, null, 'Facturation mensuelle standard', true),
  ('MOYEN',  3,  6000,  0, null, 'Tranche trimestrielle', true),
  ('MOYEN',  6,  12000, 0, null, 'Tranche semestrielle', true),
  ('MOYEN',  12, 20000, 17, '2 mois offerts', 'Abonnement annuel économique (20 000 au lieu de 24 000 FCFA)', true),

  -- Formule PRO (5 000 FCFA / mois)
  ('PRO',    1,  5000,  0, null, 'Facturation mensuelle tout illimité', true),
  ('PRO',    3,  15000, 0, null, 'Tranche trimestrielle', true),
  ('PRO',    6,  30000, 0, null, 'Tranche semestrielle', true),
  ('PRO',    12, 50000, 17, '2 mois offerts', 'Abonnement annuel économique (50 000 au lieu de 60 000 FCFA)', true)
on conflict (plan_code, duree_mois) do update set
  montant_total = excluded.montant_total,
  remise_pourcentage = excluded.remise_pourcentage,
  badge_promo = excluded.badge_promo,
  description = excluded.description,
  est_actif = true,
  updated_at = now();

-- Mise à jour du prix mensuel de référence dans public.plans
update public.plans set prix_mensuel = 1000, updated_at = now() where code = 'NORMAL';
update public.plans set prix_mensuel = 2000, updated_at = now() where code = 'MOYEN';
update public.plans set prix_mensuel = 5000, updated_at = now() where code = 'PRO';

-- -----------------------------------------------------------------------------
-- 4. Sécurisation serveur de public.initialiser_paiement_abonnement
-- -----------------------------------------------------------------------------
drop function if exists public.initialiser_paiement_abonnement(uuid, text, integer, text, text, boolean, integer, text);
drop function if exists public.initialiser_paiement_abonnement(uuid, text, integer, text, text, boolean);
drop function if exists public.initialiser_paiement_abonnement(uuid, text, smallint, text, text, boolean);

create or replace function public.initialiser_paiement_abonnement(
  p_entreprise_id uuid,
  p_plan_code text default null,
  p_duree_mois integer default 1,
  p_prestataire text default 'LIGDICASH',
  p_idempotency_key text default null,
  p_est_demo boolean default false,
  p_montant_test integer default null,
  p_type_paiement text default 'REDIRECTION'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_role text := coalesce(auth.role(), '');
  v_code_cible text;
  v_plan public.plans%rowtype;
  v_tarif public.tarifs_durees_plans%rowtype;
  v_montant_total integer;
  v_idempotency text;
  v_reference text;
  v_tx public.transactions_abonnement%rowtype;
  v_type_paiement text;
  v_abo_actuel public.abonnements%rowtype;
begin
  -- 1. Authentification & Autorisation
  if v_role <> 'service_role' then
    if v_uid is null then
      raise exception 'NON_AUTHENTIFIE' using errcode = '42501';
    end if;

    if not (app.a_permission(p_entreprise_id, 'entreprise.manage') or app.est_super_admin()) then
      raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
    end if;
  end if;

  -- 2. Résolution robuste du plan cible
  -- Si p_plan_code n'est pas fourni, récupérer le plan actif ou d'essai de l'entreprise
  v_code_cible := trim(coalesce(p_plan_code, ''));
  if v_code_cible = '' then
    select * into v_abo_actuel
    from public.abonnements
    where entreprise_id = p_entreprise_id
    order by (statut in ('ESSAI', 'ACTIF')) desc, date_debut desc
    limit 1;

    v_code_cible := coalesce(v_abo_actuel.plan_code, 'NORMAL');
  end if;

  select * into v_plan from public.plans where code = v_code_cible and est_actif;
  if v_plan.code is null then
    raise exception 'PLAN_INVALIDE' using errcode = 'P0001';
  end if;

  -- 3. Validation de la durée et du prestataire
  if p_duree_mois not in (1, 3, 6, 12) then
    raise exception 'DUREE_INVALIDE' using errcode = 'P0001';
  end if;

  if p_prestataire not in ('LIGDICASH', 'ORANGE_MONEY') then
    raise exception 'PRESTATAIRE_INVALIDE' using errcode = 'P0001';
  end if;

  v_type_paiement := coalesce(p_type_paiement, 'REDIRECTION');
  if v_type_paiement not in ('REDIRECTION', 'DIRECT_SANS_REDIRECTION') then
    v_type_paiement := 'REDIRECTION';
  end if;

  -- 4. Détermination autoritaire et stricte du montant officiel
  if p_montant_test is not null and p_montant_test = 10 then
    if coalesce(p_est_demo, false) or v_role = 'service_role' or app.est_super_admin() then
      v_montant_total := 10;
    else
      raise exception 'MONTANT_TEST_NON_AUTORISE' using errcode = '42501';
    end if;
  else
    -- Récupération du tarif serveur officiel pour ce plan et cette durée
    select * into v_tarif
    from public.tarifs_durees_plans
    where plan_code = v_plan.code and duree_mois = p_duree_mois and est_actif;

    if v_tarif.id is not null then
      v_montant_total := v_tarif.montant_total;
    else
      v_montant_total := v_plan.prix_mensuel * p_duree_mois;
    end if;
  end if;

  if v_montant_total is null or v_montant_total <= 0 then
    raise exception 'MONTANT_INVALIDE' using errcode = 'P0001';
  end if;

  -- 5. Gestion de l'idempotence
  v_idempotency := coalesce(nullif(trim(p_idempotency_key), ''), 'IDEMP_' || gen_random_uuid()::text);

  select * into v_tx from public.transactions_abonnement where idempotency_key = v_idempotency;
  if v_tx.id is not null then
    return jsonb_build_object(
      'succes', true,
      'deja_cree', true,
      'transaction', row_to_json(v_tx)
    );
  end if;

  -- 6. Génération de la référence unique interne
  v_reference := 'ABO_' || to_char(now(), 'YYYYMMDD_HH24MISS') || '_' || upper(substr(gen_random_uuid()::text, 1, 8));

  -- 7. Création de la transaction dans public.transactions_abonnement
  insert into public.transactions_abonnement (
    entreprise_id,
    plan_code,
    duree_mois,
    montant,
    devise,
    prestataire,
    statut,
    type_paiement,
    idempotency_key,
    reference_interne,
    est_demo,
    cree_par,
    diagnostic
  ) values (
    p_entreprise_id,
    v_plan.code,
    p_duree_mois,
    v_montant_total,
    'XOF',
    p_prestataire,
    'EN_ATTENTE',
    v_type_paiement,
    v_idempotency,
    v_reference,
    coalesce(p_est_demo, false),
    v_uid,
    jsonb_build_object(
      'initialise_a', now(),
      'mode', case when coalesce(p_est_demo, false) then 'DEMO' else 'PRODUCTION' end,
      'tarif_applique', v_montant_total,
      'type_paiement', v_type_paiement
    )
  )
  returning * into v_tx;

  return jsonb_build_object(
    'succes', true,
    'transaction', row_to_json(v_tx)
  );
end;
$$;

revoke all on function public.initialiser_paiement_abonnement from public, anon;
grant execute on function public.initialiser_paiement_abonnement to authenticated, service_role;
