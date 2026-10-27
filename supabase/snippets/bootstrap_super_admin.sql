-- =============================================================================
-- SNIPPET DE BOOTSTRAP DU PREMIER SUPER ADMIN DUBAGEST (Exécution directe DBA/DevOps)
--
-- Instructions :
-- 1. Remplacez 'superadmin@dubagest.com' par l'adresse e-mail exacte du compte cible
--    préalablement créé et vérifié dans Supabase Auth.
-- 2. Exécutez ce script dans Supabase SQL Editor ou via psql avec le rôle postgres / service_role.
-- =============================================================================

do $$
declare
  v_target_email text := 'admin@dubagest.com'; -- À ADAPTER
  v_user_id uuid;
  v_deja_admin boolean;
begin
  -- Recherche du compte dans auth.users
  select id into v_user_id from auth.users where lower(email) = lower(trim(v_target_email));

  if v_user_id is null then
    raise exception 'ERREUR BOOTSTRAP : Aucun compte auth.users trouvé avec l''adresse %', v_target_email;
  end if;

  select est_actif into v_deja_admin from app.super_admins where user_id = v_user_id;

  if v_deja_admin is true then
    raise notice 'INFO : Le compte % est déjà Super Admin actif.', v_target_email;
    return;
  end if;

  insert into app.super_admins (user_id, role, est_actif, motif)
  values (v_user_id, 'SUPER_ADMIN', true, 'Bootstrap initial plateforme via SQL Editor')
  on conflict (user_id) do update set
    est_actif = true,
    motif = 'Réactivation Super Admin via SQL Editor',
    updated_at = now();

  insert into app.super_admin_audit_logs (
    admin_id, action, cible_type, cible_id, details
  ) values (
    v_user_id,
    'BOOTSTRAP_INITIAL_DBA',
    'USER',
    v_user_id::text,
    jsonb_build_object('email', v_target_email, 'methode', 'DIRECT_SQL_SNIPPET')
  );

  raise notice 'SUCCÈS : Le compte % (%) est désormais configuré comme SUPER ADMIN de DubaGest.', v_target_email, v_user_id;
end;
$$;
