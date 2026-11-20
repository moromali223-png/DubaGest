-- =============================================================================
-- SERVICES : PERSISTANCE DES PHOTOS DE PRESTATIONS / CONTRATS DE SERVICE
--
-- 1. Ajoute la colonne jsonb `photos` sur `public.prestations` (idempotent).
-- 2. Étend `app.acces_fichier` pour autoriser le stockage dans le bucket privé
--    « fichiers » sous le chemin `<entreprise_id>/prestations/<prestation_id>/<fichier>`.
-- =============================================================================

alter table public.prestations
  add column if not exists photos jsonb not null default '[]'::jsonb
  check (jsonb_typeof(photos) = 'array');

grant insert (photos) on public.prestations to authenticated;
grant update (photos) on public.prestations to authenticated;

-- Étend l'accès au bucket privé « fichiers » pour les photos de prestations
create or replace function app.acces_fichier(p_chemin text, p_mode text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_parts text[] := string_to_array(p_chemin, '/');
  v_eid uuid;
begin
  begin
    v_eid := v_parts[1]::uuid;
  exception when others then
    return false;
  end;

  if v_parts[2] = 'logo' then
    return case p_mode when 'LECTURE' then app.est_membre(v_eid)
                       else app.a_permission(v_eid, 'entreprise.manage') end;
  elsif v_parts[2] = 'pj' and array_length(v_parts, 1) = 5 then
    begin
      return app.peut_cible(v_eid, v_parts[3], v_parts[4]::uuid, p_mode);
    exception when others then
      return false;
    end;
  elsif v_parts[2] = 'produits' and array_length(v_parts, 1) = 4 then
    return case p_mode when 'LECTURE' then app.est_membre(v_eid)
                       else app.a_permission(v_eid, 'products.create')
                            or app.a_permission(v_eid, 'products.update') end;
  elsif v_parts[2] = 'prestations' and array_length(v_parts, 1) = 4 then
    return case p_mode when 'LECTURE' then app.est_membre(v_eid)
                       else app.a_permission(v_eid, 'prestations.create')
                            or app.a_permission(v_eid, 'prestations.update') end;
  end if;

  return false;
end;
$$;
