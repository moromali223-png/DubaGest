-- =============================================================================
-- Migration: Exposer les procédures serveur sécurisées dans le schéma public
--            pour appel via supabase.rpc depuis l'Edge Function abonnement-paiement
-- Migration: 20261105000500_expose_server_rpcs_in_public.sql
-- =============================================================================

-- 1. Procédure serveur d'enregistrement LigdiCash (réservée à service_role)
create or replace function public.enregistrer_initialisation_ligdicash(
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
begin
  return app.enregistrer_initialisation_ligdicash(
    p_reference_interne => p_reference_interne,
    p_token => p_token,
    p_url_paiement => p_url_paiement,
    p_environnement => p_environnement,
    p_diagnostic => p_diagnostic
  );
end;
$$;

revoke all on function public.enregistrer_initialisation_ligdicash(text, text, text, text, jsonb) from public, anon, authenticated;
grant execute on function public.enregistrer_initialisation_ligdicash(text, text, text, text, jsonb) to service_role;

-- 2. Procédure serveur de confirmation de paiement (réservée à service_role)
create or replace function public.confirmer_paiement_abonnement_serveur(
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
begin
  return app.confirmer_paiement_abonnement_serveur(
    p_reference_interne => p_reference_interne,
    p_prestataire => p_prestataire,
    p_reference_prestataire => p_reference_prestataire,
    p_montant => p_montant,
    p_devise => p_devise,
    p_diagnostic => p_diagnostic
  );
end;
$$;

revoke all on function public.confirmer_paiement_abonnement_serveur(text, text, text, integer, text, jsonb) from public, anon, authenticated;
grant execute on function public.confirmer_paiement_abonnement_serveur(text, text, text, integer, text, jsonb) to service_role;

