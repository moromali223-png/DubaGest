-- =============================================================================
-- MIGRATION : ATTRIBUTION PRIVILÈGES SUPER ADMIN FONDATEUR
-- Email ciblé : mdmoroco71@gmail.com
-- =============================================================================

-- 1. Si le compte existe déjà dans auth.users, l'activer immédiatement comme Super Admin
insert into app.super_admins (user_id, role, est_actif, motif)
select id, 'SUPER_ADMIN', true, 'Fondateur & Super Administrateur DubaGest'
from auth.users
where lower(email) = 'mdmoroco71@gmail.com'
on conflict (user_id) do update set
  role = 'SUPER_ADMIN',
  est_actif = true,
  motif = 'Fondateur & Super Administrateur DubaGest',
  updated_at = now();

-- 2. Trigger automatique à la création de compte si l'utilisateur s'inscrit ultérieurement
create or replace function app.tg_auto_attribuer_super_admin_fondateur()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if lower(trim(new.email)) = 'mdmoroco71@gmail.com' then
    insert into app.super_admins (user_id, role, est_actif, motif)
    values (new.id, 'SUPER_ADMIN', true, 'Fondateur & Super Administrateur DubaGest')
    on conflict (user_id) do update set
      role = 'SUPER_ADMIN',
      est_actif = true,
      motif = 'Fondateur & Super Administrateur DubaGest',
      updated_at = now();
  end if;
  return new;
end;
$$;

drop trigger if exists on_super_admin_fondateur_created on auth.users;

create trigger on_super_admin_fondateur_created
  after insert or update of email on auth.users
  for each row execute function app.tg_auto_attribuer_super_admin_fondateur();
