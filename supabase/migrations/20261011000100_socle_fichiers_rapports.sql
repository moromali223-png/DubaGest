-- =============================================================================
-- SOCLE COMMUN — ÉTAPE 8 : NOTES, PIÈCES JOINTES, LOGO, RAPPORTS
--
--   notes            texte libre sur une fiche (hors-ligne)
--   pieces_jointes   fichier (photo de justificatif, PDF) attaché à une fiche,
--                    stocké dans le bucket privé « fichiers »
--   logo             fichier du bucket « fichiers », chemin dans
--                    entreprises.logo_path (en-tête des reçus)
--   commun.rapports  rapports calculés sur l'appareil (reports.view)
--
-- Droits sur une fiche, selon son type (même règle que les modules) :
--   lecture : voir la fiche ; ajout : la modifier / l'alimenter.
-- Chemins de stockage : <entreprise>/logo/<fichier>
--                       <entreprise>/pj/<TYPE>/<fiche>/<fichier>
-- =============================================================================

insert into public.modules (code, libelle, activite_code, permission_acces, ordre, categorie)
values ('commun.rapports', 'Rapports', null, 'reports.view', 13, 'COMMUN');
insert into public.plan_modules (plan_code, module_code)
select code, 'commun.rapports' from public.plans;

-- -----------------------------------------------------------------------------
-- 1. Droits sur une fiche
-- -----------------------------------------------------------------------------

create or replace function app.perimetre_cible(p_type text, p_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v uuid;
begin
  if p_type = 'ENGAGEMENT' then
    select perimetre_id into v from public.engagements where id = p_id;
  elsif p_type = 'PAIEMENT' then
    select perimetre_id into v from public.paiements where id = p_id;
  elsif p_type = 'DEPENSE' then
    select perimetre_id into v from public.depenses where id = p_id;
  end if;
  return v;
end;
$$;

create or replace function app.cible_existe(p_entreprise_id uuid, p_type text, p_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_type = 'CONTACT' then
    return exists (select 1 from public.contacts where id = p_id and entreprise_id = p_entreprise_id);
  elsif p_type = 'ENGAGEMENT' then
    return exists (select 1 from public.engagements where id = p_id and entreprise_id = p_entreprise_id);
  elsif p_type = 'PAIEMENT' then
    return exists (select 1 from public.paiements where id = p_id and entreprise_id = p_entreprise_id);
  elsif p_type = 'DEPENSE' then
    return exists (select 1 from public.depenses where id = p_id and entreprise_id = p_entreprise_id);
  end if;
  return false;
end;
$$;

-- p_mode : 'LECTURE' (voir la fiche) ou 'AJOUT' (la compléter).
create or replace function app.peut_cible(p_entreprise_id uuid, p_type text, p_id uuid, p_mode text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_module text;
  v_permission text;
begin
  if p_type = 'CONTACT' then
    v_module := 'commun.contacts';
    v_permission := case p_mode when 'LECTURE' then 'contacts.view' else 'contacts.update' end;
  elsif p_type = 'ENGAGEMENT' then
    v_module := 'finances.creances';
    v_permission := case p_mode when 'LECTURE' then 'receivables.view' else 'receivables.manage' end;
  elsif p_type = 'PAIEMENT' then
    v_module := 'finances.paiements';
    v_permission := case p_mode when 'LECTURE' then 'payments.view' else 'payments.create' end;
  elsif p_type = 'DEPENSE' then
    v_module := 'finances.depenses';
    v_permission := case p_mode when 'LECTURE' then 'expenses.view' else 'expenses.create' end;
  else
    return false;
  end if;
  return app.peut(p_entreprise_id, v_module, v_permission, app.perimetre_cible(p_type, p_id));
end;
$$;

-- -----------------------------------------------------------------------------
-- 2. Notes
-- -----------------------------------------------------------------------------

create table public.notes (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  cible_type text not null check (cible_type in ('CONTACT', 'ENGAGEMENT', 'PAIEMENT', 'DEPENSE')),
  cible_id uuid not null,
  texte text not null check (char_length(trim(texte)) between 1 and 2000),
  auteur_nom text,
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index notes_sync_idx on public.notes (entreprise_id, updated_at);
create index notes_cible_idx on public.notes (cible_type, cible_id);

create or replace function app.tg_notes_regles()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    perform app.exiger(app.peut_cible(new.entreprise_id, new.cible_type, new.cible_id, 'AJOUT'));
    if not app.cible_existe(new.entreprise_id, new.cible_type, new.cible_id) then
      perform app.refuser('CIBLE_INVALIDE');
    end if;
    new.created_by := coalesce(auth.uid(), new.created_by);
    new.auteur_nom := (select nom_complet from public.profiles where id = new.created_by);
    return new;
  end if;
  -- Modifier le texte : l'auteur ; supprimer : l'auteur ou l'administration.
  perform app.exiger(old.created_by = auth.uid()
                     or (new.texte = old.texte and app.a_permission(old.entreprise_id, 'entreprise.manage')));
  return new;
end;
$$;

create trigger notes_regles before insert or update on public.notes
  for each row execute function app.tg_notes_regles();
create trigger notes_versionnement before insert or update on public.notes
  for each row execute function app.tg_versionnement();
create trigger audit_notes after insert or update or delete on public.notes
  for each row execute function app.tg_audit();

alter table public.notes enable row level security;
create policy notes_lecture on public.notes for select to authenticated
  using (app.peut_cible(entreprise_id, cible_type, cible_id, 'LECTURE'));
create policy notes_ajout on public.notes for insert to authenticated
  with check (app.peut_cible(entreprise_id, cible_type, cible_id, 'AJOUT'));
create policy notes_modification on public.notes for update to authenticated
  using (app.peut_cible(entreprise_id, cible_type, cible_id, 'LECTURE')
         and (created_by = (select auth.uid()) or app.a_permission(entreprise_id, 'entreprise.manage')))
  with check (app.peut_cible(entreprise_id, cible_type, cible_id, 'LECTURE'));

revoke all on public.notes from anon, authenticated;
grant select on public.notes to authenticated;
grant insert (id, entreprise_id, cible_type, cible_id, texte) on public.notes to authenticated;
grant update (texte, deleted_at) on public.notes to authenticated;
grant all on public.notes to service_role;

-- -----------------------------------------------------------------------------
-- 3. Pièces jointes et bucket de fichiers
-- -----------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fichiers', 'fichiers', false, 10485760,
        array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
on conflict (id) do nothing;

create table public.pieces_jointes (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  cible_type text not null check (cible_type in ('CONTACT', 'ENGAGEMENT', 'PAIEMENT', 'DEPENSE')),
  cible_id uuid not null,
  chemin text not null unique,
  nom_fichier text not null check (char_length(nom_fichier) between 1 and 200),
  type_mime text not null check (type_mime in ('image/jpeg', 'image/png', 'image/webp', 'application/pdf')),
  taille bigint not null check (taille between 1 and 10485760),
  auteur_nom text,
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index pieces_jointes_sync_idx on public.pieces_jointes (entreprise_id, updated_at);
create index pieces_jointes_cible_idx on public.pieces_jointes (cible_type, cible_id);

create or replace function app.tg_pieces_jointes_regles()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    perform app.exiger(app.peut_cible(new.entreprise_id, new.cible_type, new.cible_id, 'AJOUT'));
    if not app.cible_existe(new.entreprise_id, new.cible_type, new.cible_id) then
      perform app.refuser('CIBLE_INVALIDE');
    end if;
    -- Le fichier doit être rangé sous la fiche, dans l'entreprise.
    if new.chemin not like new.entreprise_id || '/pj/' || new.cible_type || '/' || new.cible_id || '/%' then
      perform app.refuser('CHEMIN_INVALIDE');
    end if;
    new.created_by := coalesce(auth.uid(), new.created_by);
    new.auteur_nom := (select nom_complet from public.profiles where id = new.created_by);
    return new;
  end if;
  perform app.exiger(old.created_by = auth.uid() or app.a_permission(old.entreprise_id, 'entreprise.manage'));
  return new;
end;
$$;

create trigger pieces_jointes_regles before insert or update on public.pieces_jointes
  for each row execute function app.tg_pieces_jointes_regles();
create trigger pieces_jointes_versionnement before insert or update on public.pieces_jointes
  for each row execute function app.tg_versionnement();
create trigger audit_pieces_jointes after insert or update or delete on public.pieces_jointes
  for each row execute function app.tg_audit();

alter table public.pieces_jointes enable row level security;
create policy pieces_jointes_lecture on public.pieces_jointes for select to authenticated
  using (app.peut_cible(entreprise_id, cible_type, cible_id, 'LECTURE'));
create policy pieces_jointes_ajout on public.pieces_jointes for insert to authenticated
  with check (app.peut_cible(entreprise_id, cible_type, cible_id, 'AJOUT'));
create policy pieces_jointes_retrait on public.pieces_jointes for update to authenticated
  using (app.peut_cible(entreprise_id, cible_type, cible_id, 'LECTURE')
         and (created_by = (select auth.uid()) or app.a_permission(entreprise_id, 'entreprise.manage')))
  with check (app.peut_cible(entreprise_id, cible_type, cible_id, 'LECTURE'));

revoke all on public.pieces_jointes from anon, authenticated;
grant select on public.pieces_jointes to authenticated;
grant insert (id, entreprise_id, cible_type, cible_id, chemin, nom_fichier, type_mime, taille)
  on public.pieces_jointes to authenticated;
grant update (deleted_at) on public.pieces_jointes to authenticated;
grant all on public.pieces_jointes to service_role;

-- Accès aux fichiers du bucket, selon le chemin.
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
  end if;
  return false;
end;
$$;

create policy fichiers_lecture on storage.objects for select to authenticated
  using (bucket_id = 'fichiers' and app.acces_fichier(name, 'LECTURE'));
create policy fichiers_ajout on storage.objects for insert to authenticated
  with check (bucket_id = 'fichiers' and app.acces_fichier(name, 'AJOUT'));
create policy fichiers_remplacement on storage.objects for update to authenticated
  using (bucket_id = 'fichiers' and app.acces_fichier(name, 'AJOUT'));
create policy fichiers_suppression on storage.objects for delete to authenticated
  using (bucket_id = 'fichiers' and app.acces_fichier(name, 'AJOUT'));

grant execute on function app.acces_fichier(text, text) to authenticated;

-- -----------------------------------------------------------------------------
-- 4. Synchronisation
-- -----------------------------------------------------------------------------

insert into app.sync_tables (table_name, colonnes_creation, colonnes_modification) values
  ('notes', array['entreprise_id', 'cible_type', 'cible_id', 'texte'], array['texte']),
  -- Ajout en ligne (fichier envoyé d'abord) ; retrait possible hors-ligne.
  ('pieces_jointes', array['entreprise_id', 'cible_type', 'cible_id', 'chemin', 'nom_fichier', 'type_mime', 'taille'], '{}');
