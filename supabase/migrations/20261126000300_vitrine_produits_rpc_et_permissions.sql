-- =============================================================================
-- DUBAGEST V2 — PERMISSIONS & RPC GESTION PRODUITS VITRINE
-- Migration : 20261126000300_vitrine_produits_rpc_et_permissions.sql
-- =============================================================================

-- 1. Accorder les droits SELECT, INSERT, UPDATE sur la table produits au rôle authenticated
grant select, insert, update on public.produits to authenticated;

-- 2. Politique RLS permettant aux membres d'une entreprise de gérer les produits de leur vitrine
drop policy if exists produits_vitrine_membre on public.produits;
create policy produits_vitrine_membre on public.produits
  for all
  to authenticated
  using (app.est_membre(entreprise_id))
  with check (app.est_membre(entreprise_id));
