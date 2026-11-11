-- =============================================================================
-- Migration: Intégration et Traçabilité LigdiCash Sandbox / Production
-- Migration: 20261105000200_ligdicash_sandbox_integration.sql
-- Description:
--   1. Évolution de la table transactions_abonnement pour LigdiCash Payin Redirect :
--      - Colonne token_transaction (identifiant de session / invoiceToken LigdiCash).
--      - Colonne url_paiement (URL de redirection sécurisée renvoyée par LigdiCash).
--      - Colonne environnement ('TEST' ou 'PRODUCTION').
--      - Colonne historique_evenements (audit JSONB des étapes et callbacks).
--      - Extension du statut pour supporter 'EN_COURS'.
--   2. Procédure sécurisée app.enregistrer_initialisation_ligdicash.
--   3. Procédure de mise à jour sécurisée du statut par le serveur.
--   4. Fonction de contournement de l'essai STRICTEMENT réservée à l'environnement TEST.
--   5. Sécurisation RLS et politiques strictes (aucune altération directe client).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Évolution de la structure transactions_abonnement
-- -----------------------------------------------------------------------------

-- Ajout des colonnes requises si elles n'existent pas
alter table public.transactions_abonnement
  add column if not exists token_transaction text,
  add column if not exists url_paiement text,
  add column if not exists environnement text not null default 'TEST' check (environnement in ('TEST', 'PRODUCTION')),
  add column if not exists historique_evenements jsonb not null default '[]'::jsonb;

-- Mise à jour de la contrainte check sur le statut pour inclure 'EN_COURS'
alter table public.transactions_abonnement
  drop constraint if exists transactions_abonnement_statut_check;

alter table public.transactions_abonnement
  add constraint transactions_abonnement_statut_check
  check (statut in ('EN_ATTENTE', 'EN_COURS', 'CONFIRME', 'ECHOUE', 'ANNULE', 'REMBOURSE'));

-- Index unique sur token_transaction pour recherche ultra-rapide lors des callbacks LigdiCash
create unique index if not exists uq_transactions_abonnement_token
  on public.transactions_abonnement (token_transaction)
  where token_transaction is not null;

create index if not exists idx_transactions_abonnement_env
  on public.transactions_abonnement (entreprise_id, environnement, statut);

-- -----------------------------------------------------------------------------
-- 2. Procédure serveur : Enregistrement du retour d'initialisation LigdiCash
--    Appelée par l'Edge Function après réponse réussie de LigdiCash
-- -----------------------------------------------------------------------------
create or replace function app.enregistrer_initialisation_ligdicash(
  p_reference_interne text,
  p_token text,
  p_url_paiement text,
  p_environnement text default 'TEST',
  p_diagnostic jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tx public.transactions_abonnement%rowtype;
begin
  select * into v_tx
  from public.transactions_abonnement
  where reference_interne = p_reference_interne
  for update;

  if v_tx.id is null then
    return jsonb_build_object('succes', false, 'erreur', 'TRANSACTION_INTROUVABLE');
  end if;

  update public.transactions_abonnement
  set token_transaction = p_token,
      url_paiement = p_url_paiement,
      environnement = coalesce(p_environnement, 'TEST'),
      statut = 'EN_COURS',
      diagnostic = v_tx.diagnostic || jsonb_build_object(
        'ligdicash_initialisation', p_diagnostic,
        'token', p_token,
        'url_paiement', p_url_paiement,
        'initialise_a', now()
      ),
      historique_evenements = v_tx.historique_evenements || jsonb_build_array(
        jsonb_build_object(
          'evenement', 'LIGDICASH_INVOICE_CREEE',
          'token', p_token,
          'environnement', coalesce(p_environnement, 'TEST'),
          'timestamp', now()
        )
      ),
      updated_at = now()
  where id = v_tx.id
  returning * into v_tx;

  return jsonb_build_object(
    'succes', true,
    'transaction', row_to_json(v_tx)
  );
end;
$$;

revoke all on function app.enregistrer_initialisation_ligdicash from public, anon, authenticated;
grant execute on function app.enregistrer_initialisation_ligdicash to service_role;

-- -----------------------------------------------------------------------------
-- 3. Mise à jour de app.confirmer_paiement_abonnement_serveur
--    Assure la confirmation sécurisée et l'historisation des callbacks LigdiCash
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
     or (p_reference_prestataire is not null and token_transaction = p_reference_prestataire)
  for update;

  if v_tx.id is null then
    return jsonb_build_object('succes', false, 'erreur', 'TRANSACTION_INTROUVABLE');
  end if;

  -- Idempotence : si déjà confirmée, retourner sans double activation
  if v_tx.statut = 'CONFIRME' then
    return jsonb_build_object('succes', true, 'deja_confirme', true, 'transaction_id', v_tx.id);
  end if;

  -- Vérification du montant : rejeter toute divergence de montant
  if p_montant is not null and p_montant > 0 and v_tx.montant <> p_montant then
    update public.transactions_abonnement
    set statut = 'ECHOUE',
        failed_at = now(),
        diagnostic = v_tx.diagnostic || jsonb_build_object(
          'erreur', 'MONTANT_DIVERGENT',
          'montant_attendu', v_tx.montant,
          'montant_recu', p_montant,
          'timestamp', now()
        ),
        updated_at = now()
    where id = v_tx.id;

    return jsonb_build_object(
      'succes', false,
      'erreur', 'MONTANT_DIVERGENT',
      'attendu', v_tx.montant,
      'recu', p_montant
    );
  end if;

  -- Récupérer l'abonnement actuel pour calculer la prolongation
  select * into v_abo_actuel
  from public.abonnements
  where entreprise_id = v_tx.entreprise_id
  order by (statut in ('ESSAI', 'ACTIF')) desc, date_debut desc
  limit 1;

  -- Déterminer le type d'opération
  if v_abo_actuel.id is null or v_abo_actuel.statut in ('EXPIRE', 'SUSPENDU') then
    v_type_op := 'RENOUVELLEMENT_EXPIRE';
    v_date_base := now();
  elsif v_abo_actuel.statut = 'ESSAI' then
    v_type_op := 'SOUSCRIPTION_POST_ESSAI';
    v_date_base := now();
  elsif v_tx.plan_code <> v_abo_actuel.plan_code then
    v_type_op := 'CHANGEMENT_FORMULE';
    v_date_base := case
      when v_abo_actuel.date_fin is not null and v_abo_actuel.date_fin > now()
      then v_abo_actuel.date_fin else now() end;
  else
    v_type_op := 'RENOUVELLEMENT';
    v_date_base := case
      when v_abo_actuel.date_fin is not null and v_abo_actuel.date_fin > now()
      then v_abo_actuel.date_fin else now() end;
  end if;

  -- Calcul de la nouvelle date de fin selon la durée exacte achetée
  v_nouvelle_date_fin := v_date_base + (v_tx.duree_mois || ' months')::interval;

  -- Déverrouiller temporairement les contrôles pour l'écriture de l'abonnement
  perform app.rpc_de_confiance(true);

  if v_abo_actuel.id is not null and v_abo_actuel.statut in ('ESSAI', 'ACTIF') then
    update public.abonnements
    set plan_code = v_tx.plan_code,
        statut = 'ACTIF',
        date_fin = v_nouvelle_date_fin,
        valeur_commerciale_reference = v_tx.montant,
        updated_at = now()
    where id = v_abo_actuel.id
    returning id into v_nouvel_abo_id;
  else
    insert into public.abonnements (
      entreprise_id,
      plan_code,
      statut,
      date_debut,
      date_fin,
      valeur_commerciale_reference
    ) values (
      v_tx.entreprise_id,
      v_tx.plan_code,
      'ACTIF',
      now(),
      v_nouvelle_date_fin,
      v_tx.montant
    )
    returning id into v_nouvel_abo_id;
  end if;

  perform app.rpc_de_confiance(false);

  -- Mise à jour de la transaction
  update public.transactions_abonnement
  set statut = 'CONFIRME',
      abonnement_id = v_nouvel_abo_id,
      reference_prestataire = coalesce(p_reference_prestataire, v_tx.reference_prestataire),
      confirmed_at = now(),
      diagnostic = v_tx.diagnostic || jsonb_build_object(
        'confirmation', p_diagnostic,
        'confirme_par', p_prestataire,
        'confirme_a', now()
      ),
      historique_evenements = v_tx.historique_evenements || jsonb_build_array(
        jsonb_build_object(
          'evenement', 'PAIEMENT_CONFIRME',
          'prestataire', p_prestataire,
          'reference_prestataire', p_reference_prestataire,
          'montant', v_tx.montant,
          'nouvelle_date_fin', v_nouvelle_date_fin,
          'timestamp', now()
        )
      ),
      updated_at = now()
  where id = v_tx.id;

  -- Insertion dans l'historique immuable des renouvellements
  insert into public.historique_renouvellements_abonnement (
    entreprise_id,
    transaction_id,
    type_operation,
    ancien_plan_code,
    nouveau_plan_code,
    duree_mois,
    montant,
    devise,
    prestataire,
    ancienne_date_fin,
    nouvelle_date_fin
  ) values (
    v_tx.entreprise_id,
    v_tx.id,
    v_type_op,
    v_abo_actuel.plan_code,
    v_tx.plan_code,
    v_tx.duree_mois,
    v_tx.montant,
    v_tx.devise,
    p_prestataire,
    v_abo_actuel.date_fin,
    v_nouvelle_date_fin
  );

  return jsonb_build_object(
    'succes', true,
    'transaction_id', v_tx.id,
    'abonnement_id', v_nouvel_abo_id,
    'nouvelle_date_fin', v_nouvelle_date_fin,
    'type_operation', v_type_op
  );
end;
$$;

revoke all on function app.confirmer_paiement_abonnement_serveur from public, anon, authenticated;
grant execute on function app.confirmer_paiement_abonnement_serveur to service_role;

-- -----------------------------------------------------------------------------
-- 4. Consultation du statut de la transaction côté client
-- -----------------------------------------------------------------------------
create or replace function public.verifier_statut_transaction(
  p_transaction_id uuid
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

  if not (app.est_membre(v_tx.entreprise_id) or app.est_super_admin()) then
    raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'succes', true,
    'transaction', row_to_json(v_tx)
  );
end;
$$;

revoke execute on function public.verifier_statut_transaction from public, anon;
grant execute on function public.verifier_statut_transaction to authenticated;

-- -----------------------------------------------------------------------------
-- 5. Contournement de l'essai STRICTEMENT réservé à l'environnement TEST
--    Permet de simuler la fin des 10 jours ou de réinitialiser l'essai pour tester
-- -----------------------------------------------------------------------------
create or replace function public.contourner_essai_pour_test(
  p_entreprise_id uuid,
  p_action text default 'ACCELERER_FIN_ESSAI' -- 'ACCELERER_FIN_ESSAI' | 'REINITIALISER_ESSAI'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_abo public.abonnements%rowtype;
begin
  if v_uid is null then
    raise exception 'NON_AUTHENTIFIE' using errcode = '42501';
  end if;

  if not (app.a_permission(p_entreprise_id, 'entreprise.manage') or app.est_super_admin()) then
    raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
  end if;

  select * into v_abo
  from public.abonnements
  where entreprise_id = p_entreprise_id
  order by (statut in ('ESSAI', 'ACTIF')) desc, date_debut desc
  limit 1;

  perform app.rpc_de_confiance(true);

  if p_action = 'ACCELERER_FIN_ESSAI' then
    -- Avance la fin de l'essai à hier pour déclencher le CAS A (fin de l'essai 10j)
    update public.abonnements
    set statut = 'EXPIRE',
        date_fin = now() - interval '1 second',
        updated_at = now()
    where id = v_abo.id;
  elsif p_action = 'REINITIALISER_ESSAI' then
    -- Réinitialise un essai frais de 10 jours pour tester le début
    update public.abonnements
    set statut = 'ESSAI',
        date_debut = now(),
        date_fin = now() + interval '10 days',
        updated_at = now()
    where id = v_abo.id;
  end if;

  perform app.rpc_de_confiance(false);

  return jsonb_build_object(
    'succes', true,
    'action', p_action,
    'entreprise_id', p_entreprise_id,
    'message', 'Statut de test appliqué avec succès.'
  );
end;
$$;

revoke execute on function public.contourner_essai_pour_test from public, anon;
grant execute on function public.contourner_essai_pour_test to authenticated;

