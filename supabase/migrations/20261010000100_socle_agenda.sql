-- =============================================================================
-- SOCLE COMMUN — ÉTAPE 6 : AGENDA ET NOTIFICATIONS
--
--   echeances      rappels, rendez-vous, tâches, relances (hors-ligne),
--                  éventuellement confiés à un membre et liés à une fiche
--   notifications  messages destinés à un utilisateur, créés par le serveur
--                  (tâche confiée, tâche terminée) ; seul le destinataire
--                  les voit et peut les marquer comme lues
--
-- Les échéances des sommes dues ne sont pas recopiées ici : l'application
-- les affiche dans l'agenda à partir des engagements (pas de double saisie).
-- =============================================================================

insert into public.modules (code, libelle, activite_code, permission_acces, ordre, categorie)
values ('commun.agenda', 'Agenda', null, 'agenda.view', 12, 'COMMUN');
insert into public.plan_modules (plan_code, module_code)
select code, 'commun.agenda' from public.plans;

-- -----------------------------------------------------------------------------
-- 1. Échéances
-- -----------------------------------------------------------------------------

create table public.echeances (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  perimetre_id uuid,
  type text not null check (type in ('RAPPEL', 'RENDEZ_VOUS', 'TACHE', 'RELANCE')),
  titre text not null check (char_length(trim(titre)) between 1 and 200),
  note text check (char_length(note) <= 1000),
  date_heure timestamptz not null,
  -- Rappel N minutes avant (null : aucun).
  rappel_minutes integer check (rappel_minutes between 0 and 43200),
  responsable_id uuid references auth.users (id) on delete set null,
  -- Nom affiché, copié par le serveur (lisible hors-ligne par tous).
  responsable_nom text,
  -- Fiche concernée (contrôlée par trigger : même entreprise).
  cible_type text check (cible_type in ('CONTACT', 'ENGAGEMENT', 'PAIEMENT', 'DOCUMENT')),
  cible_id uuid,
  statut text not null default 'A_FAIRE' check (statut in ('A_FAIRE', 'FAIT', 'ANNULE')),
  fait_le timestamptz,
  fait_par uuid references public.profiles (id) on delete set null,
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id),
  foreign key (perimetre_id, entreprise_id) references public.perimetres (id, entreprise_id),
  check ((cible_type is null) = (cible_id is null))
);
create index echeances_sync_idx on public.echeances (entreprise_id, updated_at);
create index echeances_date_idx on public.echeances (entreprise_id, statut, date_heure);
create index echeances_responsable_idx on public.echeances (responsable_id, statut);

create or replace function app.tg_echeances_regles()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_gerer boolean := app.peut(new.entreprise_id, 'commun.agenda', 'agenda.manage', new.perimetre_id);
  v_cible_ok boolean;
begin
  if tg_op = 'INSERT' then
    perform app.exiger(v_gerer);
  else
    -- Le responsable (sans agenda.manage) peut seulement marquer « fait ».
    perform app.exiger(v_gerer or old.responsable_id = auth.uid());
    if not v_gerer and (select auth.role()) = 'authenticated'
       and (new.titre, new.note, new.date_heure, new.rappel_minutes, new.responsable_id, new.cible_type,
            new.cible_id, new.type) is distinct from
           (old.titre, old.note, old.date_heure, old.rappel_minutes, old.responsable_id, old.cible_type,
            old.cible_id, old.type) then
      raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
    end if;
  end if;

  -- Responsable : membre actif de l'entreprise.
  if new.responsable_id is not null and (tg_op = 'INSERT' or new.responsable_id is distinct from old.responsable_id) then
    if not exists (select 1 from public.membres_entreprise m
                   where m.entreprise_id = new.entreprise_id and m.user_id = new.responsable_id and m.statut = 'ACTIF') then
      perform app.refuser('RESPONSABLE_INVALIDE');
    end if;
  end if;
  new.responsable_nom := (select p.nom_complet from public.profiles p where p.id = new.responsable_id);

  -- Fiche concernée : doit exister dans la même entreprise.
  if new.cible_id is not null and (tg_op = 'INSERT' or (new.cible_type, new.cible_id) is distinct from (old.cible_type, old.cible_id)) then
    v_cible_ok := false;
    if new.cible_type = 'CONTACT' then
      v_cible_ok := exists (select 1 from public.contacts c where c.id = new.cible_id and c.entreprise_id = new.entreprise_id);
    elsif new.cible_type = 'ENGAGEMENT' then
      v_cible_ok := exists (select 1 from public.engagements e where e.id = new.cible_id and e.entreprise_id = new.entreprise_id);
    elsif new.cible_type = 'PAIEMENT' then
      v_cible_ok := exists (select 1 from public.paiements p where p.id = new.cible_id and p.entreprise_id = new.entreprise_id);
    elsif new.cible_type = 'DOCUMENT' then
      v_cible_ok := exists (select 1 from public.documents d where d.id = new.cible_id and d.entreprise_id = new.entreprise_id);
    end if;
    if not v_cible_ok then
      perform app.refuser('CIBLE_INVALIDE');
    end if;
  end if;

  if tg_op = 'INSERT' then
    new.statut := 'A_FAIRE';
    new.fait_le := null;
    new.fait_par := null;
    new.created_by := coalesce(auth.uid(), new.created_by);
  elsif new.statut is distinct from old.statut then
    if new.statut = 'FAIT' then
      new.fait_le := now();
      new.fait_par := auth.uid();
    elsif new.statut = 'A_FAIRE' then
      new.fait_le := null;
      new.fait_par := null;
    end if;
  end if;
  return new;
end;
$$;

create trigger echeances_regles before insert or update on public.echeances
  for each row execute function app.tg_echeances_regles();
create trigger echeances_versionnement before insert or update on public.echeances
  for each row execute function app.tg_versionnement();
create trigger audit_echeances after insert or update or delete on public.echeances
  for each row execute function app.tg_audit();

alter table public.echeances enable row level security;
create policy echeances_lecture on public.echeances for select to authenticated
  using (app.peut(entreprise_id, 'commun.agenda', 'agenda.view', perimetre_id));
create policy echeances_ajout on public.echeances for insert to authenticated
  with check (app.peut(entreprise_id, 'commun.agenda', 'agenda.manage', perimetre_id));
create policy echeances_modification on public.echeances for update to authenticated
  using (app.peut(entreprise_id, 'commun.agenda', 'agenda.manage', perimetre_id)
         or (responsable_id = (select auth.uid()) and app.peut(entreprise_id, 'commun.agenda', 'agenda.view', perimetre_id)))
  with check (app.peut(entreprise_id, 'commun.agenda', 'agenda.view', perimetre_id));

revoke all on public.echeances from anon, authenticated;
grant select on public.echeances to authenticated;
grant insert (id, entreprise_id, perimetre_id, type, titre, note, date_heure, rappel_minutes, responsable_id,
              cible_type, cible_id)
  on public.echeances to authenticated;
grant update (type, titre, note, date_heure, rappel_minutes, responsable_id, cible_type, cible_id, statut)
  on public.echeances to authenticated;
grant all on public.echeances to service_role;

-- -----------------------------------------------------------------------------
-- 2. Notifications
-- -----------------------------------------------------------------------------

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  destinataire_id uuid not null references auth.users (id) on delete cascade,
  type text not null check (type in ('ECHEANCE_CONFIEE', 'ECHEANCE_FAITE')),
  -- Texte construit par l'application dans la langue de l'utilisateur.
  parametres jsonb not null default '{}',
  cible_type text,
  cible_id uuid,
  auteur_nom text,
  lue_le timestamptz,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index notifications_sync_idx on public.notifications (entreprise_id, updated_at);
create index notifications_destinataire_idx on public.notifications (destinataire_id, lue_le);

create trigger notifications_versionnement before insert or update on public.notifications
  for each row execute function app.tg_versionnement();

alter table public.notifications enable row level security;
create policy notifications_lecture on public.notifications for select to authenticated
  using (destinataire_id = (select auth.uid()));
create policy notifications_lecture_marquee on public.notifications for update to authenticated
  using (destinataire_id = (select auth.uid()))
  with check (destinataire_id = (select auth.uid()));

revoke all on public.notifications from anon, authenticated;
grant select on public.notifications to authenticated;
grant update (lue_le) on public.notifications to authenticated;
grant all on public.notifications to service_role;

create or replace function app.notifier(
  p_entreprise_id uuid, p_destinataire uuid, p_type text, p_parametres jsonb, p_cible_type text, p_cible_id uuid
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.notifications (entreprise_id, destinataire_id, type, parametres, cible_type, cible_id, auteur_nom)
  select p_entreprise_id, p_destinataire, p_type, p_parametres, p_cible_type, p_cible_id,
         (select nom_complet from public.profiles where id = auth.uid())
  where p_destinataire is not null and p_destinataire is distinct from auth.uid();
$$;

-- Tâche confiée à quelqu'un d'autre ; tâche terminée par le responsable.
create or replace function app.tg_echeances_notifier()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_params jsonb := jsonb_build_object('titre', new.titre, 'date_heure', new.date_heure);
begin
  if new.responsable_id is not null
     and (tg_op = 'INSERT' or new.responsable_id is distinct from old.responsable_id) then
    perform app.notifier(new.entreprise_id, new.responsable_id, 'ECHEANCE_CONFIEE', v_params, 'ECHEANCE', new.id);
  end if;
  if tg_op = 'UPDATE' and new.statut = 'FAIT' and old.statut <> 'FAIT' then
    perform app.notifier(new.entreprise_id, new.created_by, 'ECHEANCE_FAITE', v_params, 'ECHEANCE', new.id);
  end if;
  return null;
end;
$$;

create trigger echeances_notifier after insert or update on public.echeances
  for each row execute function app.tg_echeances_notifier();

-- -----------------------------------------------------------------------------
-- 3. Synchronisation
-- -----------------------------------------------------------------------------

insert into app.sync_tables (table_name, colonnes_creation, colonnes_modification) values
  ('echeances',
   array['entreprise_id', 'perimetre_id', 'type', 'titre', 'note', 'date_heure', 'rappel_minutes',
         'responsable_id', 'cible_type', 'cible_id'],
   array['type', 'titre', 'note', 'date_heure', 'rappel_minutes', 'responsable_id', 'cible_type', 'cible_id',
         'statut']),
  ('notifications', '{}', array['lue_le']);
