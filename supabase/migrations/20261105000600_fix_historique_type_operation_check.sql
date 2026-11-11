-- =============================================================================
-- Migration: Élargir la contrainte type_operation sur historique_renouvellements_abonnement
-- Migration: 20261105000600_fix_historique_type_operation_check.sql
-- =============================================================================

alter table public.historique_renouvellements_abonnement
  drop constraint if exists historique_renouvellements_abonnement_type_operation_check;

alter table public.historique_renouvellements_abonnement
  add constraint historique_renouvellements_abonnement_type_operation_check
  check (type_operation in (
    'NOUVELLE_SOUSCRIPTION',
    'FIN_ESSAI',
    'SOUSCRIPTION_POST_ESSAI',
    'RENOUVELLEMENT',
    'RENOUVELLEMENT_EXPIRE',
    'CHANGEMENT_FORMULE',
    'SPONSORISE'
  ));

