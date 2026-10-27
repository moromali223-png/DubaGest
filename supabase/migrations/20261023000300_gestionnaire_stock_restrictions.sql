-- Migration : Restrictions de sécurité pour le rôle GESTIONNAIRE_STOCK
-- Objectif : Interdire formellement l'accès aux dépenses, caisse et finances sensibles pour les gestionnaires de stock.

delete from public.roles_permissions
where role_code = 'GESTIONNAIRE_STOCK'
  and permission_code in (
    'expenses.view',
    'expenses.create',
    'expenses.update',
    'expenses.delete',
    'expenses.cancel',
    'expenses.recurring',
    'cash.view',
    'payments.view',
    'receivables.view'
  );
