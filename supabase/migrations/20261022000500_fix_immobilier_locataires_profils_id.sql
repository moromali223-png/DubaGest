-- =============================================================================
-- CORRECTION SYNCHRONISATION : COLONNE ID SUR IMMOBILIER_LOCATAIRES_PROFILS
--
-- La table immobilier_locataires_profils avait contact_id comme clé primaire
-- mais pas de colonne 'id'. Le moteur de synchronisation SupabaseSyncGateway.pull
-- et la fonction sync_push ordonnent et insèrent par 'id'.
-- Cet ajustement ajoute la colonne 'id' et 'deleted_at' pour permettre
-- une synchronisation sans interruption.
-- =============================================================================

alter table public.immobilier_locataires_profils 
  add column if not exists id uuid default gen_random_uuid();

update public.immobilier_locataires_profils
  set id = coalesce(id, contact_id, gen_random_uuid())
  where id is null;

alter table public.immobilier_locataires_profils 
  alter column id set not null;

create unique index if not exists immobilier_locataires_profils_id_uindex 
  on public.immobilier_locataires_profils (id);

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'immobilier_locataires_profils_id_key'
  ) then
    alter table public.immobilier_locataires_profils 
      add constraint immobilier_locataires_profils_id_key unique using index immobilier_locataires_profils_id_uindex;
  end if;
end $$;

-- Colonne deleted_at pour conformité avec sync_push
alter table public.immobilier_locataires_profils 
  add column if not exists deleted_at timestamptz;

alter table public.immobilier_locations 
  add column if not exists deleted_at timestamptz;

alter table public.immobilier_contrats 
  add column if not exists deleted_at timestamptz;

alter table public.immobilier_echeances_loyers 
  add column if not exists deleted_at timestamptz;

-- Privilèges pour les rôles
grant insert (id, deleted_at) on public.immobilier_locataires_profils to authenticated;
grant update (deleted_at) on public.immobilier_locataires_profils to authenticated;
grant update (deleted_at) on public.immobilier_locations to authenticated;
grant update (deleted_at) on public.immobilier_contrats to authenticated;
grant update (deleted_at) on public.immobilier_echeances_loyers to authenticated;
