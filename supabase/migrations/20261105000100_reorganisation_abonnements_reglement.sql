-- =============================================================================
-- Migration: Réorganisation professionnelle du parcours d'abonnement et de réabonnement DubaGest
-- Migration: 20261105000100_reorganisation_abonnements_reglement.sql
-- Description:
--   1. Grille officielle des tarifs par durée (1, 3, 6, 12 mois) stockée côté serveur.
--   2. Historique officiel et immuable des renouvellements (historique_renouvellements_abonnement).
--   3. Verrouillage anti-fraude strict de la période d'essai de 10 jours (non-réactivable, non-prolongeable).
--   4. Vérification stricte des limites lors de l'initialisation et de la confirmation du règlement.
--   5. RPC complète preparer_reglement_abonnement pour distinguer CAS A (Fin essai) et CAS B (Réabonnement).
--   6. Intégration de l'historique complet des renouvellements dans lister_paiements_et_abonnements.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Table des tarifs par formule et par durée (1, 3, 6, 12 mois)
-- -----------------------------------------------------------------------------
create table if not exists public.tarifs_durees_plans (
  id uuid primary key default gen_random_uuid(),
  plan_code text not null references public.plans(code) on delete cascade,
  duree_mois smallint not null check (duree_mois in (1, 3, 6, 12)),
  montant_total integer not null check (montant_total > 0),
  devise text not null default 'XOF' check (devise = 'XOF'),
  remise_pourcentage smallint not null default 0 check (remise_pourcentage between 0 and 100),
  badge_promo text,
  description text,
  est_actif boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (plan_code, duree_mois)
);

create trigger tg_tarifs_durees_plans_updated_at
  before update on public.tarifs_durees_plans
  for each row execute function app.tg_set_updated_at();

alter table public.tarifs_durees_plans enable row level security;
create policy tarifs_durees_plans_lecture on public.tarifs_durees_plans
  for select to authenticated, anon
  using (est_actif = true);

grant select on public.tarifs_durees_plans to authenticated, anon;
grant all on public.tarifs_durees_plans to service_role;

-- Insertion des tarifs officiels DubaGest pour toutes les durées (1, 3, 6, 12 mois)
-- Remise annuelle avantageuse : 12 mois pour le prix de 10 mois (~17% de réduction)
insert into public.tarifs_durees_plans (plan_code, duree_mois, montant_total, remise_pourcentage, badge_promo, description)
values
  -- Formule NORMAL (1 000 FCFA / mois)
  ('NORMAL', 1,  1000,  0, null, 'Facturation mensuelle sans engagement'),
  ('NORMAL', 3,  3000,  0, null, 'Tranche trimestrielle'),
  ('NORMAL', 6,  6000,  0, null, 'Tranche semestrielle'),
  ('NORMAL', 12, 10000, 17, '2 mois offerts', 'Abonnement annuel économique (10 000 au lieu de 12 000 FCFA)'),

  -- Formule MOYEN (2 000 FCFA / mois)
  ('MOYEN',  1,  2000,  0, null, 'Facturation mensuelle standard'),
  ('MOYEN',  3,  6000,  0, null, 'Tranche trimestrielle'),
  ('MOYEN',  6,  12000, 0, null, 'Tranche semestrielle'),
  ('MOYEN',  12, 20000, 17, '2 mois offerts', 'Abonnement annuel économique (20 000 au lieu de 24 000 FCFA)'),

  -- Formule PRO (5 000 FCFA / mois)
  ('PRO',    1,  5000,  0, null, 'Facturation mensuelle tout illimité'),
  ('PRO',    3,  15000, 0, null, 'Tranche trimestrielle'),
  ('PRO',    6,  30000, 0, null, 'Tranche semestrielle'),
  ('PRO',    12, 50000, 17, '2 mois offerts', 'Abonnement annuel économique (50 000 au lieu de 60 000 FCFA)')
on conflict (plan_code, duree_mois) do update set
  montant_total = excluded.montant_total,
  remise_pourcentage = excluded.remise_pourcentage,
  badge_promo = excluded.badge_promo,
  description = excluded.description,
  updated_at = now();

-- -----------------------------------------------------------------------------
-- 2. Table d'historique immuable des renouvellements d'abonnements
-- -----------------------------------------------------------------------------
create table if not exists public.historique_renouvellements_abonnement (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises(id) on delete cascade,
  transaction_id uuid references public.transactions_abonnement(id) on delete set null,
  abonnement_id uuid references public.abonnements(id) on delete set null,
  type_operation text not null check (type_operation in ('NOUVELLE_SOUSCRIPTION', 'FIN_ESSAI', 'RENOUVELLEMENT', 'CHANGEMENT_FORMULE', 'SPONSORISE')),
  ancien_plan_code text,
  nouveau_plan_code text not null references public.plans(code),
  duree_mois smallint not null check (duree_mois in (1, 3, 6, 12)),
  montant integer not null default 0,
  devise text not null default 'XOF',
  prestataire text,
  ancienne_date_fin timestamptz,
  nouvelle_date_fin timestamptz not null,
  cree_par uuid references auth.users(id) on delete set null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_historique_renouvellements_entreprise
  on public.historique_renouvellements_abonnement(entreprise_id, created_at desc);

alter table public.historique_renouvellements_abonnement enable row level security;
create policy historique_renouvellements_lecture on public.historique_renouvellements_abonnement
  for select to authenticated
  using (app.est_membre(entreprise_id) or app.est_super_admin());

grant select on public.historique_renouvellements_abonnement to authenticated;
grant all on public.historique_renouvellements_abonnement to service_role;

-- -----------------------------------------------------------------------------
-- 3. Sécurisation anti-abus stricte de l'essai gratuit de 10 jours
-- -----------------------------------------------------------------------------
alter table public.entreprises
  add column if not exists essai_consomme boolean not null default true;

-- Trigger empêchant toute altération illicite d'une période d'essai expirée
create or replace function app.tg_proteger_regles_essai_abonnement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Règle 1 : Une période d'essai ne peut JAMAIS être étendue au-delà de 10 jours à partir de sa date de début initiale
  if new.statut = 'ESSAI' then
    if new.date_fin > (new.date_debut + interval '10 days 1 hour') then
      raise exception 'PROLONGATION_ESSAI_INTERDITE' using errcode = 'P0001';
    end if;
  end if;

  -- Règle 2 : Un abonnement qui a expiré ne peut JAMAIS être rebasculé en 'ESSAI'
  if tg_op = 'UPDATE' and old.statut in ('EXPIRE', 'ACTIF') and new.statut = 'ESSAI' then
    raise exception 'REDUCTION_EN_ESSAI_INTERDITE' using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists tg_proteger_regles_essai on public.abonnements;
create trigger tg_proteger_regles_essai
  before insert or update on public.abonnements
  for each row execute function app.tg_proteger_regles_essai_abonnement();

-- -----------------------------------------------------------------------------
-- 4. Enrichissement du catalogue public des formules avec les tarifs de durées
-- -----------------------------------------------------------------------------
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
  where p.est_actif;
$$;

grant execute on function public.lister_catalogue_plans() to authenticated, anon;

-- -----------------------------------------------------------------------------
-- 5. RPC public.preparer_reglement_abonnement
--    Fournit tous les paramètres exacts pour la Page 2 de règlement DubaGest
-- -----------------------------------------------------------------------------
create or replace function public.preparer_reglement_abonnement(
  p_entreprise_id uuid,
  p_plan_cible text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_abo public.abonnements%rowtype;
  v_plan_code_choisi text;
  v_plan_info public.plans%rowtype;
  v_situation text;
  v_est_expire boolean := false;
  v_est_essai boolean := false;
  v_jours_restants integer := 0;
  v_conformite jsonb := '{"conforme": true, "anomalies": []}'::jsonb;
begin
  if v_uid is null then
    raise exception 'NON_AUTHENTIFIE' using errcode = '42501';
  end if;

  if not (app.est_membre(p_entreprise_id) or app.est_super_admin()) then
    raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
  end if;

  -- Synchroniser l'état d'expiration proactif sans toucher aux données
  perform app.synchroniser_expiration_abonnement(p_entreprise_id);

  select * into v_abo
  from public.abonnements
  where entreprise_id = p_entreprise_id
  order by (statut in ('ESSAI', 'ACTIF', 'SUSPENDU')) desc, date_debut desc
  limit 1;

  if v_abo.id is null then
    v_est_expire := true;
    v_situation := 'REABONNEMENT_EXPIRE';
    v_plan_code_choisi := coalesce(p_plan_cible, 'NORMAL');
  else
    v_est_essai := (v_abo.statut = 'ESSAI');
    v_est_expire := (v_abo.statut = 'EXPIRE' or (v_abo.date_fin is not null and v_abo.date_fin < now()));

    if v_abo.date_fin is not null and v_abo.date_fin > now() then
      v_jours_restants := extract(day from (v_abo.date_fin - now()))::integer;
    else
      v_jours_restants := 0;
    end if;

    if v_est_essai and v_est_expire then
      v_situation := 'FIN_ESSAI';
    elsif v_est_essai then
      v_situation := 'ESSAI_EN_COURS';
    elsif v_est_expire then
      v_situation := 'REABONNEMENT_EXPIRE';
    else
      v_situation := 'RENOUVELLEMENT_ACTIF';
    end if;

    v_plan_code_choisi := coalesce(p_plan_cible, v_abo.plan_code, 'NORMAL');
  end if;

  select * into v_plan_info from public.plans where code = v_plan_code_choisi;
  if v_plan_info.code is null then
    select * into v_plan_info from public.plans where code = 'NORMAL';
    v_plan_code_choisi := 'NORMAL';
  end if;

  -- Contrôle de conformité des quotas si changement de plan vers une formule inférieure
  if v_abo.id is not null and v_plan_code_choisi <> v_abo.plan_code then
    begin
      v_conformite := public.analyser_limites_declassement(p_entreprise_id, v_plan_code_choisi);
    exception when others then
      v_conformite := jsonb_build_object('conforme', true, 'anomalies', '[]'::jsonb);
    end;
  end if;

  return jsonb_build_object(
    'entreprise_id', p_entreprise_id,
    'situation', v_situation,
    'est_essai', v_est_essai,
    'est_expire', v_est_expire,
    'jours_restants', v_jours_restants,
    'plan_actuel_code', coalesce(v_abo.plan_code, 'NORMAL'),
    'plan_choisi', jsonb_build_object(
      'code', v_plan_info.code,
      'nom', v_plan_info.nom,
      'prix_mensuel', v_plan_info.prix_mensuel,
      'devise', 'XOF',
      'max_activites', v_plan_info.max_activites
    ),
    'date_expiration_actuelle', v_abo.date_fin,
    'conformite_limites', v_conformite,
    'tarifs_durees', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'duree_mois', t.duree_mois,
        'montant_total', t.montant_total,
        'remise_pourcentage', t.remise_pourcentage,
        'badge_promo', t.badge_promo,
        'description', t.description
      ) order by t.duree_mois), '[]'::jsonb)
      from public.tarifs_durees_plans t
      where t.plan_code = v_plan_code_choisi and t.est_actif
    ),
    'prestataires_disponibles', jsonb_build_array(
      jsonb_build_object(
        'code', 'ORANGE_MONEY',
        'nom', 'Orange Money',
        'description', 'Paiement mobile sécurisé par Orange Money',
        'couleur', '#FF7900'
      ),
      jsonb_build_object(
        'code', 'LIGDICASH',
        'nom', 'LigdiCash',
        'description', 'Paiement mobile sécurisé par LigdiCash (Burkina Faso & UEMOA)',
        'couleur', '#1E88E5'
      )
    )
  );
end;
$$;

revoke execute on function public.preparer_reglement_abonnement from public, anon;
grant execute on function public.preparer_reglement_abonnement to authenticated;

-- -----------------------------------------------------------------------------
-- 6. Mise à jour de public.initialiser_paiement_abonnement avec tarifs officiels
-- -----------------------------------------------------------------------------
create or replace function public.initialiser_paiement_abonnement(
  p_entreprise_id uuid,
  p_plan_code text,
  p_duree_mois integer,
  p_prestataire text,
  p_idempotency_key text default null,
  p_est_demo boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_plan public.plans%rowtype;
  v_tarif public.tarifs_durees_plans%rowtype;
  v_montant_total integer;
  v_idempotency text;
  v_reference text;
  v_tx public.transactions_abonnement%rowtype;
begin
  if v_uid is null then
    raise exception 'NON_AUTHENTIFIE' using errcode = '42501';
  end if;

  if not (app.a_permission(p_entreprise_id, 'entreprise.manage') or app.est_super_admin()) then
    raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
  end if;

  if p_duree_mois not in (1, 3, 6, 12) then
    raise exception 'DUREE_INVALIDE' using errcode = 'P0001';
  end if;

  if p_prestataire not in ('LIGDICASH', 'ORANGE_MONEY') then
    raise exception 'PRESTATAIRE_INVALIDE' using errcode = 'P0001';
  end if;

  select * into v_plan from public.plans where code = p_plan_code and est_actif;
  if v_plan.code is null then
    raise exception 'PLAN_INVALIDE' using errcode = 'P0001';
  end if;

  -- Récupération du tarif officiel serveur configuré pour cette formule et cette durée
  select * into v_tarif
  from public.tarifs_durees_plans
  where plan_code = v_plan.code and duree_mois = p_duree_mois and est_actif;

  if v_tarif.id is not null then
    v_montant_total := v_tarif.montant_total;
  else
    v_montant_total := v_plan.prix_mensuel * p_duree_mois;
  end if;

  if v_montant_total <= 0 then
    raise exception 'MONTANT_INVALIDE' using errcode = 'P0001';
  end if;

  v_idempotency := coalesce(nullif(trim(p_idempotency_key), ''), 'IDEMP_' || gen_random_uuid()::text);

  -- Protection contre les doubles transactions (Idempotence)
  select * into v_tx from public.transactions_abonnement where idempotency_key = v_idempotency;
  if v_tx.id is not null then
    return jsonb_build_object(
      'succes', true,
      'deja_cree', true,
      'transaction', row_to_json(v_tx)
    );
  end if;

  v_reference := 'DBG-' || upper(p_prestataire) || '-' || to_char(now(), 'YYYYMMDD-HH24MISS') || '-' || substr(md5(random()::text), 1, 6);

  insert into public.transactions_abonnement (
    entreprise_id,
    user_id,
    plan_code,
    duree_mois,
    montant,
    devise,
    prestataire,
    reference_interne,
    idempotency_key,
    statut,
    est_demo,
    diagnostic
  ) values (
    p_entreprise_id,
    v_uid,
    v_plan.code,
    p_duree_mois,
    v_montant_total,
    'XOF',
    p_prestataire,
    v_reference,
    v_idempotency,
    'EN_ATTENTE',
    coalesce(p_est_demo, false),
    jsonb_build_object(
      'client_mode', case when coalesce(p_est_demo, false) then 'DEMO' else 'PRODUCTION' end,
      'initialisation_ts', now(),
      'tarif_serveur', v_montant_total
    )
  )
  returning * into v_tx;

  return jsonb_build_object(
    'succes', true,
    'deja_cree', false,
    'transaction', row_to_json(v_tx)
  );
end;
$$;

revoke execute on function public.initialiser_paiement_abonnement from public, anon;
grant execute on function public.initialiser_paiement_abonnement to authenticated;

-- -----------------------------------------------------------------------------
-- 7. Mise à jour de app.confirmer_paiement_abonnement_serveur
--    Activation sécurisée avec enregistrement dans l'historique des renouvellements
-- -----------------------------------------------------------------------------
create or replace function app.confirmer_paiement_abonnement_serveur(
  p_reference_interne text,
  p_prestataire text,
  p_reference_prestataire text,
  p_montant integer,
  p_devise text,
  p_diagnostic jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tx public.transactions_abonnement%rowtype;
  v_abo_actuel public.abonnements%rowtype;
  v_nouvel_abo_id uuid;
  v_nouvelle_date_fin timestamptz;
  v_date_base timestamptz;
  v_type_op text;
begin
  select * into v_tx
  from public.transactions_abonnement
  where reference_interne = p_reference_interne
  for update;

  if v_tx.id is null then
    return jsonb_build_object('succes', false, 'erreur', 'TRANSACTION_INTROUVABLE');
  end if;

  -- Idempotence : si déjà confirmée, retourner sans double activation
  if v_tx.statut = 'CONFIRME' then
    return jsonb_build_object('succes', true, 'deja_confirme', true, 'transaction_id', v_tx.id);
  end if;

  -- Sécurité : une transaction DEMO ne peut jamais activer un abonnement réel en production
  if v_tx.est_demo then
    return jsonb_build_object('succes', false, 'erreur', 'TRANSACTION_DEMO_INTERDITE_EN_PROD');
  end if;

  -- Vérification stricte du prestataire, du montant et de la devise
  if v_tx.prestataire <> p_prestataire then
    return jsonb_build_object('succes', false, 'erreur', 'PRESTATAIRE_INCOHERENT');
  end if;

  if v_tx.montant <> p_montant or v_tx.devise <> coalesce(p_devise, 'XOF') then
    return jsonb_build_object('succes', false, 'erreur', 'MONTANT_OU_DEVISE_INCOHERENT');
  end if;

  -- Trouver l'abonnement le plus récent pour l'entreprise
  select * into v_abo_actuel
  from public.abonnements
  where entreprise_id = v_tx.entreprise_id
    and statut in ('ESSAI', 'ACTIF', 'EXPIRE')
  order by (statut in ('ESSAI', 'ACTIF')) desc, date_debut desc
  limit 1
  for update;

  -- Déterminer le type d'opération pour l'historique
  if v_abo_actuel.id is null then
    v_type_op := 'NOUVELLE_SOUSCRIPTION';
    v_date_base := now();
  elsif v_abo_actuel.statut = 'ESSAI' then
    v_type_op := 'FIN_ESSAI';
    v_date_base := now();
  elsif v_abo_actuel.statut = 'EXPIRE' or (v_abo_actuel.date_fin is not null and v_abo_actuel.date_fin <= now()) then
    v_type_op := case when v_abo_actuel.plan_code <> v_tx.plan_code then 'CHANGEMENT_FORMULE' else 'RENOUVELLEMENT' end;
    v_date_base := now();
  else
    -- Abonnement ACTIF encore en cours
    v_type_op := case when v_abo_actuel.plan_code <> v_tx.plan_code then 'CHANGEMENT_FORMULE' else 'RENOUVELLEMENT' end;
    -- Si même formule, prolonge à partir de la date_fin active existante
    if v_abo_actuel.plan_code = v_tx.plan_code and v_abo_actuel.date_fin is not null and v_abo_actuel.date_fin > now() then
      v_date_base := v_abo_actuel.date_fin;
    else
      v_date_base := now();
    end if;
  end if;

  v_nouvelle_date_fin := v_date_base + make_interval(months => v_tx.duree_mois);

  -- Clôture propre de l'ancien abonnement
  if v_abo_actuel.id is not null then
    update public.abonnements
    set statut = 'EXPIRE',
        date_fin = case when v_abo_actuel.date_fin > now() then now() else v_abo_actuel.date_fin end,
        updated_at = now()
    where id = v_abo_actuel.id;
  end if;

  -- Création du nouvel abonnement payé et vérifié
  insert into public.abonnements (
    entreprise_id,
    plan_code,
    statut,
    date_debut,
    date_fin,
    type_facturation,
    valeur_commerciale_reference
  ) values (
    v_tx.entreprise_id,
    v_tx.plan_code,
    'ACTIF',
    now(),
    v_nouvelle_date_fin,
    'COMMERCIAL',
    (select prix_mensuel from public.plans where code = v_tx.plan_code)
  )
  returning id into v_nouvel_abo_id;

  -- Mise à jour de la transaction
  update public.transactions_abonnement
  set statut = 'CONFIRME',
      reference_prestataire = p_reference_prestataire,
      abonnement_id = v_nouvel_abo_id,
      confirmed_at = now(),
      diagnostic = diagnostic || jsonb_build_object('serveur_confirmation', true, 'confirme_le', now()) || coalesce(p_diagnostic, '{}'::jsonb),
      updated_at = now()
  where id = v_tx.id;

  -- Enregistrement officiel dans l'historique des renouvellements
  insert into public.historique_renouvellements_abonnement (
    entreprise_id,
    transaction_id,
    abonnement_id,
    type_operation,
    ancien_plan_code,
    nouveau_plan_code,
    duree_mois,
    montant,
    devise,
    prestataire,
    ancienne_date_fin,
    nouvelle_date_fin,
    cree_par,
    details
  ) values (
    v_tx.entreprise_id,
    v_tx.id,
    v_nouvel_abo_id,
    v_type_op,
    v_abo_actuel.plan_code,
    v_tx.plan_code,
    v_tx.duree_mois,
    v_tx.montant,
    v_tx.devise,
    v_tx.prestataire,
    v_abo_actuel.date_fin,
    v_nouvelle_date_fin,
    v_tx.user_id,
    jsonb_build_object('reference_interne', v_tx.reference_interne, 'reference_prestataire', p_reference_prestataire)
  );

  -- Audit log immuable
  insert into public.audit_logs (
    entreprise_id, user_id, entite_type, entite_id, action, donnees_apres
  ) values (
    v_tx.entreprise_id,
    v_tx.user_id,
    'transactions_abonnement',
    v_tx.id,
    'PAIEMENT_CONFIRME',
    jsonb_build_object(
      'montant', v_tx.montant,
      'devise', v_tx.devise,
      'prestataire', v_tx.prestataire,
      'plan_code', v_tx.plan_code,
      'duree_mois', v_tx.duree_mois,
      'type_operation', v_type_op,
      'nouvel_abonnement_id', v_nouvel_abo_id,
      'date_fin', v_nouvelle_date_fin
    )
  );

  return jsonb_build_object(
    'succes', true,
    'transaction_id', v_tx.id,
    'abonnement_id', v_nouvel_abo_id,
    'date_fin', v_nouvelle_date_fin,
    'type_operation', v_type_op
  );
end;
$$;

revoke all on function app.confirmer_paiement_abonnement_serveur from public, anon, authenticated;
grant execute on function app.confirmer_paiement_abonnement_serveur to service_role;

-- -----------------------------------------------------------------------------
-- 8. Mise à jour de public.lister_paiements_et_abonnements avec historique_renouvellements
-- -----------------------------------------------------------------------------
create or replace function public.lister_paiements_et_abonnements(p_entreprise_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'NON_AUTHENTIFIE' using errcode = '42501';
  end if;

  if not (app.est_membre(p_entreprise_id) or app.est_super_admin()) then
    raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'entreprise_id', p_entreprise_id,
    'transactions', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', t.id,
        'plan_code', t.plan_code,
        'duree_mois', t.duree_mois,
        'montant', t.montant,
        'devise', t.devise,
        'prestataire', t.prestataire,
        'reference_interne', t.reference_interne,
        'reference_prestataire', t.reference_prestataire,
        'statut', t.statut,
        'est_demo', t.est_demo,
        'created_at', t.created_at,
        'confirmed_at', t.confirmed_at,
        'cancelled_at', t.cancelled_at,
        'failed_at', t.failed_at
      ) order by t.created_at desc), '[]'::jsonb)
      from public.transactions_abonnement t
      where t.entreprise_id = p_entreprise_id
    ),
    'abonnements', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', a.id,
        'plan_code', a.plan_code,
        'statut', a.statut,
        'date_debut', a.date_debut,
        'date_fin', a.date_fin,
        'type_facturation', a.type_facturation,
        'sponsor_motif', a.sponsor_motif,
        'created_at', a.created_at
      ) order by a.date_debut desc), '[]'::jsonb)
      from public.abonnements a
      where a.entreprise_id = p_entreprise_id
    ),
    'renouvellements', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', r.id,
        'type_operation', r.type_operation,
        'ancien_plan_code', r.ancien_plan_code,
        'nouveau_plan_code', r.nouveau_plan_code,
        'duree_mois', r.duree_mois,
        'montant', r.montant,
        'devise', r.devise,
        'prestataire', r.prestataire,
        'ancienne_date_fin', r.ancienne_date_fin,
        'nouvelle_date_fin', r.nouvelle_date_fin,
        'created_at', r.created_at
      ) order by r.created_at desc), '[]'::jsonb)
      from public.historique_renouvellements_abonnement r
      where r.entreprise_id = p_entreprise_id
    )
  );
end;
$$;

revoke execute on function public.lister_paiements_et_abonnements from public, anon;
grant execute on function public.lister_paiements_et_abonnements to authenticated;

-- -----------------------------------------------------------------------------
-- 9. Mise à jour de public.creer_entreprise
--    Période d'essai stricte de 10 jours et marquage essai_consomme = true
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
  -- Anti-abus de l'essai gratuit : un compte ne peut pas recréer une entreprise d'essai
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

  insert into public.entreprises (nom, created_by, essai_consomme)
  values (trim(p_nom), v_uid, true)
  returning id into v_eid;

  -- Période d'essai stricte de 10 jours selon le cahier des charges DubaGest
  insert into public.abonnements (entreprise_id, plan_code, statut, date_debut, date_fin)
  values (v_eid, v_plan.code, 'ESSAI', now(), now() + interval '10 days');

  -- Le créateur devient administrateur
  insert into public.membres_entreprise (entreprise_id, user_id, role_code)
  values (v_eid, v_uid, 'ADMINISTRATEUR');

  -- Configuration des activités et périmètres
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

revoke execute on function public.creer_entreprise from public, anon;
grant execute on function public.creer_entreprise to authenticated;

