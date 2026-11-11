-- =============================================================================
-- Migration: Paiements d'abonnements (LigdiCash & Orange Money) et Essai 10 jours
-- Migration: 20261029000100_paiements_abonnements_et_essai_10j.sql
-- Description:
--   1. Réduction de la période d'essai gratuit de 14 à 10 jours lors de la création d'entreprise.
--   2. Synchronisation de l'expiration des abonnements côté serveur (sans perte de données).
--   3. Table de traçabilité des transactions d'abonnement (LigdiCash, Orange Money).
--   4. RPC sécurisée d'initialisation de paiement côté client.
--   5. RPC serveur exclusive (service_role) pour la confirmation définitive après webhook.
--   6. RPC de consultation de l'historique des paiements et abonnements.
--   7. Sécurisation du déclassement/surclassement pour exiger un paiement si applicable.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Réduction de l'essai gratuit à 10 jours dans public.creer_entreprise
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
  -- V1 : une entreprise créée par compte (anti-abus de l'essai gratuit).
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

  insert into public.entreprises (nom, created_by)
  values (trim(p_nom), v_uid)
  returning id into v_eid;

  -- Essai gratuit de 10 jours (remplace les 14 jours précédents)
  insert into public.abonnements (entreprise_id, plan_code, statut, date_debut, date_fin)
  values (v_eid, v_plan.code, 'ESSAI', now(), now() + interval '10 days');

  -- Le créateur devient administrateur PARCE QU'il crée l'entreprise.
  insert into public.membres_entreprise (entreprise_id, user_id, role_code)
  values (v_eid, v_uid, 'ADMINISTRATEUR');

  -- Les triggers vérifient : activité incluse dans le plan, nombre d'activités.
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

-- -----------------------------------------------------------------------------
-- 2. Procédure de synchronisation automatique de l'expiration des abonnements
--    Ne supprime JAMAIS de données commerciales : bascule uniquement le statut à EXPIRE.
-- -----------------------------------------------------------------------------
create or replace function app.synchroniser_expiration_abonnement(p_entreprise_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_entreprise_id is null then
    return;
  end if;

  update public.abonnements
  set statut = 'EXPIRE',
      updated_at = now()
  where entreprise_id = p_entreprise_id
    and statut in ('ESSAI', 'ACTIF')
    and date_fin is not null
    and date_fin <= now();
end;
$$;

-- -----------------------------------------------------------------------------
-- 3. Mise à jour de public.get_contexte_session pour déclencher la synchronisation
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

  -- Synchronisation proactive de l'état d'expiration
  perform app.synchroniser_expiration_abonnement(v_eid);

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
          select activite_code, count(*) as nb
          from public.perimetres
          where entreprise_id = v_eid and deleted_at is null and est_actif group by activite_code
        ) s
      )
    )
  );
end;
$$;

-- -----------------------------------------------------------------------------
-- 4. Table des transactions de paiement d'abonnements
-- -----------------------------------------------------------------------------
create table if not exists public.transactions_abonnement (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  abonnement_id uuid references public.abonnements(id) on delete set null,
  plan_code text not null references public.plans(code) on delete restrict,
  duree_mois smallint not null default 1 check (duree_mois in (1, 3, 6, 12)),
  montant integer not null check (montant > 0),
  devise text not null default 'XOF' check (devise = 'XOF'),
  prestataire text not null check (prestataire in ('LIGDICASH', 'ORANGE_MONEY')),
  reference_interne text not null unique,
  idempotency_key text not null unique,
  reference_prestataire text,
  statut text not null default 'EN_ATTENTE'
    check (statut in ('EN_ATTENTE', 'CONFIRME', 'ECHOUE', 'ANNULE', 'REMBOURSE')),
  est_demo boolean not null default false,
  diagnostic jsonb not null default '{}'::jsonb,
  confirmed_at timestamptz,
  cancelled_at timestamptz,
  failed_at timestamptz,
  refunded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists incomplete_transactions_idx
  on public.transactions_abonnement (entreprise_id, statut, created_at desc);

create trigger tg_transactions_abonnement_updated_at
  before update on public.transactions_abonnement
  for each row execute function app.tg_set_updated_at();

alter table public.transactions_abonnement enable row level security;

-- Lecture autorisée uniquement pour les membres de l'entreprise ou le super administrateur
create policy transactions_abonnement_lecture on public.transactions_abonnement
  for select to authenticated
  using (app.est_membre(entreprise_id) or app.est_super_admin());

-- Aucune insertion / modification / suppression directe par les clients
revoke all on public.transactions_abonnement from anon, authenticated;
grant select on public.transactions_abonnement to authenticated;
grant all on public.transactions_abonnement to service_role;

-- -----------------------------------------------------------------------------
-- 5. RPC public.initialiser_paiement_abonnement
--    Vérifie les permissions, calcule le montant exact selon le tarif officiel
--    et génère la transaction en statut EN_ATTENTE.
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
  v_montant_mensuel integer;
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

  v_montant_mensuel := v_plan.prix_mensuel;
  v_montant_total := v_montant_mensuel * p_duree_mois;

  if v_montant_total <= 0 then
    raise exception 'MONTANT_INVALIDE' using errcode = 'P0001';
  end if;

  v_idempotency := coalesce(nullif(trim(p_idempotency_key), ''), 'IDEMP_' || gen_random_uuid()::text);

  -- Vérifier si la transaction avec cette clé idempotente existe déjà
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
      'created_by_ip', null,
      'client_mode', case when coalesce(p_est_demo, false) then 'DEMO' else 'PRODUCTION' end,
      'initialisation_ts', now()
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
-- 6. RPC public.mettre_a_jour_statut_paiement_abonnement_client
--    Permet au client de renoncer/annuler ou (en mode démo) de simuler l'échec/l'annulation.
--    IMPORTANT : N'autorise JAMAIS le client à forcer 'CONFIRME' ni à activer un abonnement !
-- -----------------------------------------------------------------------------
create or replace function public.mettre_a_jour_statut_paiement_abonnement_client(
  p_transaction_id uuid,
  p_action text, -- 'ANNULER' ou 'SIMULER_ECHEC'
  p_diagnostic jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_tx public.transactions_abonnement%rowtype;
begin
  if v_uid is null then
    raise exception 'NON_AUTHENTIFIE' using errcode = '42501';
  end if;

  select * into v_tx
  from public.transactions_abonnement
  where id = p_transaction_id;

  if v_tx.id is null then
    raise exception 'TRANSACTION_INTROUVABLE' using errcode = 'P0001';
  end if;

  if not (app.a_permission(v_tx.entreprise_id, 'entreprise.manage') or app.est_super_admin()) then
    raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
  end if;

  if v_tx.statut in ('CONFIRME', 'REMBOURSE') then
    raise exception 'STATUT_NON_MODIFIABLE' using errcode = 'P0001';
  end if;

  if p_action = 'ANNULER' then
    update public.transactions_abonnement
    set statut = 'ANNULE',
        cancelled_at = now(),
        diagnostic = diagnostic || jsonb_build_object('client_action', 'ANNULER', 'timestamp', now()) || coalesce(p_diagnostic, '{}'::jsonb)
    where id = v_tx.id
    returning * into v_tx;
  elsif p_action = 'SIMULER_ECHEC' and v_tx.est_demo then
    update public.transactions_abonnement
    set statut = 'ECHOUE',
        failed_at = now(),
        diagnostic = diagnostic || jsonb_build_object('client_action', 'SIMULER_ECHEC_DEMO', 'timestamp', now()) || coalesce(p_diagnostic, '{}'::jsonb)
    where id = v_tx.id
    returning * into v_tx;
  else
    raise exception 'ACTION_NON_AUTORISEE' using errcode = 'P0001';
  end if;

  return jsonb_build_object(
    'succes', true,
    'transaction', row_to_json(v_tx)
  );
end;
$$;

revoke execute on function public.mettre_a_jour_statut_paiement_abonnement_client from public, anon;
grant execute on function public.mettre_a_jour_statut_paiement_abonnement_client to authenticated;

-- -----------------------------------------------------------------------------
-- 7. RPC serveur STRICTE app.confirmer_paiement_abonnement_serveur
--    Réservée exclusivement à `service_role` (inaccessible au client ou super admin).
--    Appelée uniquement par la Edge Function après vérification cryptographique du webhook.
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

  -- Sécurité : une transaction DEMO ne peut jamais activer un abonnement réel
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

  -- Trouver l'abonnement en cours pour l'entreprise
  select * into v_abo_actuel
  from public.abonnements
  where entreprise_id = v_tx.entreprise_id
    and statut in ('ESSAI', 'ACTIF')
  order by date_debut desc
  limit 1
  for update;

  -- Calcul de la nouvelle date de fin (cumule sur la période restante si déjà active)
  v_date_base := now();
  if v_abo_actuel.id is not null and v_abo_actuel.date_fin is not null and v_abo_actuel.date_fin > now() then
    -- Si même formule, prolonge à partir de l'ancienne fin de période
    if v_abo_actuel.plan_code = v_tx.plan_code then
      v_date_base := v_abo_actuel.date_fin;
    end if;
  end if;

  v_nouvelle_date_fin := v_date_base + make_interval(months => v_tx.duree_mois);

  -- Clôture de l'ancien abonnement
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

  -- Audit log
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
      'nouvel_abonnement_id', v_nouvel_abo_id,
      'date_fin', v_nouvelle_date_fin
    )
  );

  return jsonb_build_object(
    'succes', true,
    'transaction_id', v_tx.id,
    'abonnement_id', v_nouvel_abo_id,
    'date_fin', v_nouvelle_date_fin
  );
end;
$$;

-- Révocation stricte : JAMAIS exécutable par anon, public ou authenticated
revoke all on function app.confirmer_paiement_abonnement_serveur from public, anon, authenticated;
grant execute on function app.confirmer_paiement_abonnement_serveur to service_role;

-- -----------------------------------------------------------------------------
-- 8. RPC public.lister_paiements_et_abonnements
--    Fournit l'historique complet pour la page DubaGest
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
    )
  );
end;
$$;

revoke execute on function public.lister_paiements_et_abonnements from public, anon;
grant execute on function public.lister_paiements_et_abonnements to authenticated;

-- -----------------------------------------------------------------------------
-- 9. Sécurisation de public.valider_et_appliquer_declassement
--    Empêche le surclassement commercial gratuit sans passer par le paiement.
--    Empêche la promotion abusive d'un essai expiré à 'ACTIF'.
-- -----------------------------------------------------------------------------
create or replace function public.valider_et_appliquer_declassement(
  p_demande_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_demande public.demandes_declassement%rowtype;
  v_abonnement_actuel public.abonnements%rowtype;
  v_plan_cible public.plans%rowtype;
  v_plan_actuel public.plans%rowtype;
  v_analyse jsonb;
  v_conforme boolean;
  v_nouveau_id uuid;
  v_est_surclassement boolean;
begin
  if v_uid is null then
    raise exception 'NON_AUTHENTIFIE' using errcode = '42501';
  end if;

  select * into v_demande
  from public.demandes_declassement
  where id = p_demande_id
  for update;

  if v_demande.id is null then
    raise exception 'DEMANDE_INTROUVABLE' using errcode = 'P0001';
  end if;

  if v_demande.statut = 'applied' then
    return jsonb_build_object(
      'succes', true,
      'message', 'Cette demande a déjà été appliquée.',
      'plan_code', v_demande.plan_cible_code
    );
  end if;

  if not (app.a_permission(v_demande.entreprise_id, 'entreprise.manage') or app.est_super_admin()) then
    raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
  end if;

  perform app.verrouiller_entreprise(v_demande.entreprise_id);

  -- Re-contrôle strict de toutes les limites en temps réel
  v_analyse := public.analyser_limites_declassement(v_demande.entreprise_id, v_demande.plan_cible_code);
  v_conforme := (v_analyse ->> 'conforme')::boolean;

  if not v_conforme then
    update public.demandes_declassement
    set statut = 'pending_preparation',
        conforme = false,
        details_analyse = v_analyse,
        anomalies = (v_analyse -> 'anomalies'),
        updated_at = now()
    where id = v_demande.id;

    return jsonb_build_object(
      'succes', false,
      'code', 'LIMITES_NON_RESPECTEES',
      'message', 'Des limites ne sont pas encore respectées pour finaliser le déclassement.',
      'anomalies', (v_analyse -> 'anomalies')
    );
  end if;

  select * into v_plan_cible from public.plans where code = v_demande.plan_cible_code;
  select * into v_abonnement_actuel
  from public.abonnements
  where entreprise_id = v_demande.entreprise_id
    and statut in ('ESSAI', 'ACTIF', 'SUSPENDU')
  order by date_debut desc
  limit 1
  for update;

  if v_abonnement_actuel.id is null then
    raise exception 'ABONNEMENT_ACTUEL_MANQUANT' using errcode = 'P0001';
  end if;

  select * into v_plan_actuel from public.plans where code = v_abonnement_actuel.plan_code;
  v_est_surclassement := (v_plan_cible.ordre > v_plan_actuel.ordre);

  -- Bloquer les surclassements commerciaux sans paiement
  if v_est_surclassement and v_abonnement_actuel.type_facturation <> 'SPONSORISE' then
    return jsonb_build_object(
      'succes', false,
      'code', 'PAIEMENT_REQUIS',
      'message', 'Un surclassement commercial nécessite un règlement par LigdiCash ou Orange Money.',
      'plan_cible', v_plan_cible.code,
      'prix_mensuel', v_plan_cible.prix_mensuel
    );
  end if;

  -- 1. Clôture de l'ancien abonnement
  update public.abonnements
  set statut = 'EXPIRE',
      date_fin = now(),
      updated_at = now()
  where id = v_abonnement_actuel.id;

  -- 2. Activation du nouvel abonnement déclassé (ou sponsorisé)
  insert into public.abonnements (
    entreprise_id,
    plan_code,
    statut,
    date_debut,
    date_fin,
    type_facturation,
    sponsor_motif,
    sponsor_attribue_par,
    sponsor_attribue_le,
    valeur_commerciale_reference
  ) values (
    v_demande.entreprise_id,
    v_demande.plan_cible_code,
    case when v_abonnement_actuel.statut = 'ESSAI' then 'ESSAI' else 'ACTIF' end,
    now(),
    case
      when v_abonnement_actuel.date_fin is not null and v_abonnement_actuel.date_fin > now()
      then v_abonnement_actuel.date_fin
      else null
    end,
    v_abonnement_actuel.type_facturation,
    v_abonnement_actuel.sponsor_motif,
    v_abonnement_actuel.sponsor_attribue_par,
    v_abonnement_actuel.sponsor_attribue_le,
    v_plan_cible.prix_mensuel
  )
  returning id into v_nouveau_id;

  -- 3. Marquer la demande comme appliquée
  update public.demandes_declassement
  set statut = 'applied',
      conforme = true,
      applique_par = v_uid,
      applique_le = now(),
      updated_at = now()
  where id = v_demande.id;

  -- 4. Traces d'audit
  insert into public.audit_logs (
    entreprise_id, user_id, entite_type, entite_id, action,
    donnees_avant, donnees_apres
  ) values (
    v_demande.entreprise_id,
    v_uid,
    'abonnements',
    v_nouveau_id,
    case when v_est_surclassement then 'SURCLASSEMENT' else 'DECLASSEMENT' end,
    jsonb_build_object(
      'plan_code', v_abonnement_actuel.plan_code,
      'type_facturation', v_abonnement_actuel.type_facturation,
      'valeur_commerciale_reference', v_abonnement_actuel.valeur_commerciale_reference
    ),
    jsonb_build_object(
      'plan_code', v_demande.plan_cible_code,
      'type_facturation', v_abonnement_actuel.type_facturation,
      'valeur_commerciale_reference', v_plan_cible.prix_mensuel,
      'demande_id', v_demande.id
    )
  );

  return jsonb_build_object(
    'succes', true,
    'message', format('L''abonnement a été mis à jour avec succès vers la formule %s.', v_plan_cible.nom),
    'plan_code', v_demande.plan_cible_code,
    'type_facturation', v_abonnement_actuel.type_facturation,
    'nouvel_abonnement_id', v_nouveau_id
  );
end;
$$;

