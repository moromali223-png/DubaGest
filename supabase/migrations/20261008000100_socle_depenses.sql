-- =============================================================================
-- SOCLE COMMUN — ÉTAPE 4 : DÉPENSES
--
-- Une dépense crée toujours une somme « à payer » liée (engagement d'origine
-- DEPENSE, même identifiant que la dépense). Payée tout de suite, elle crée
-- aussi le paiement (sortie) qui la règle, et la sortie de caisse pour des
-- espèces. Tout est fait par trigger dans la même transaction, à partir
-- d'UNE ligne envoyée : hors-ligne, tout est appliqué ou rien.
--
-- Identifiants connus d'avance par l'appareil :
--   engagement = id de la dépense ; paiement = paiement_id (fourni) ;
--   affectation et mouvement de caisse = id du paiement.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Opérations internes de confiance
-- -----------------------------------------------------------------------------

create or replace function app.confiance()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(current_setting('app.rpc_de_confiance', true), '') = 'on';
$$;

-- Les contrôles de droits ont déjà été faits par l'opération qui crée les
-- lignes liées : on ne les refait pas sur chacune.
create or replace function app.exiger(p_autorise boolean)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if not coalesce(p_autorise, false)
     and not app.confiance()
     and (select auth.role()) in ('authenticated', 'anon') then
    raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
  end if;
end;
$$;

-- Engagements : origine conservée pour les créations internes ; une somme
-- due liée à une dépense se modifie / s'annule depuis la dépense.
create or replace function app.tg_engagements_regles()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    perform app.exiger(app.peut(new.entreprise_id, 'finances.creances', 'receivables.manage', new.perimetre_id));
    new.activite_code := app.activite_du_perimetre(new.entreprise_id, new.perimetre_id, new.activite_code);
    new.montant_regle := 0;
    new.statut := 'OUVERT';
    new.motif_annulation := null;
    new.annule_par := null;
    new.annule_le := null;
    if (select auth.role()) = 'authenticated' and not app.confiance() then
      new.origine_type := 'MANUEL';
      new.origine_id := null;
    end if;
    new.created_by := coalesce(auth.uid(), new.created_by);
    return new;
  end if;

  if (new.contact_id, new.libelle, new.montant_total, new.echeance, new.statut, new.motif_annulation)
     is not distinct from
     (old.contact_id, old.libelle, old.montant_total, old.echeance, old.statut, old.motif_annulation) then
    return new;
  end if;

  perform app.exiger(app.peut(new.entreprise_id, 'finances.creances', 'receivables.manage', new.perimetre_id));
  if old.origine_type <> 'MANUEL' and not app.confiance() then
    perform app.refuser('ENGAGEMENT_LIE', jsonb_build_object('origine', old.origine_type));
  end if;
  if old.statut = 'ANNULE' then
    perform app.refuser('ENGAGEMENT_ANNULE');
  end if;
  if new.montant_total < old.montant_regle then
    perform app.refuser('MONTANT_INFERIEUR_REGLE', jsonb_build_object('regle', old.montant_regle));
  end if;
  if new.contact_id is distinct from old.contact_id and old.montant_regle > 0 then
    perform app.refuser('ENGAGEMENT_REGLE');
  end if;
  if new.statut = 'ANNULE' then
    if old.montant_regle > 0 then
      perform app.refuser('ENGAGEMENT_REGLE');
    end if;
    new.annule_par := auth.uid();
    new.annule_le := now();
  end if;
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- 2. Module et catégories
-- -----------------------------------------------------------------------------

insert into public.modules (code, libelle, activite_code, permission_acces, ordre, categorie)
values ('finances.depenses', 'Dépenses', null, 'expenses.view', 10, 'FINANCES');
insert into public.plan_modules (plan_code, module_code)
select code, 'finances.depenses' from public.plans;

create table public.depense_categories (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  -- Catégorie fournie par l'application (libellé traduit) ; null = créée
  -- par l'entreprise, avec son propre [nom].
  code text check (code ~ '^[A-Z_]+$'),
  nom text check (char_length(trim(nom)) between 1 and 60),
  est_active boolean not null default true,
  ordre integer not null default 100,
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id),
  unique (entreprise_id, code),
  check (code is not null or nom is not null)
);
create index depense_categories_sync_idx on public.depense_categories (entreprise_id, updated_at);

create trigger depense_categories_versionnement before insert or update on public.depense_categories
  for each row execute function app.tg_versionnement();
create trigger audit_depense_categories after insert or update or delete on public.depense_categories
  for each row execute function app.tg_audit();

create or replace function app.creer_categories_depenses(p_entreprise_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.depense_categories (entreprise_id, code, ordre)
  select p_entreprise_id, c.code, c.ordre
  from (values
    ('LOYER', 1), ('ENERGIE', 2), ('TRANSPORT', 3), ('SALAIRES', 4), ('FOURNITURES', 5),
    ('COMMUNICATION', 6), ('ENTRETIEN', 7), ('TAXES', 8), ('AUTRE', 99)
  ) as c(code, ordre)
  on conflict (entreprise_id, code) do nothing;
$$;

create or replace function app.tg_entreprises_categories()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.creer_categories_depenses(new.id);
  return null;
end;
$$;

create trigger entreprises_categories_depenses after insert on public.entreprises
  for each row execute function app.tg_entreprises_categories();

select app.creer_categories_depenses(id) from public.entreprises;

alter table public.depense_categories enable row level security;
create policy depense_categories_lecture on public.depense_categories for select to authenticated
  using (app.peut(entreprise_id, 'finances.depenses', 'expenses.view'));
create policy depense_categories_ajout on public.depense_categories for insert to authenticated
  with check (app.peut(entreprise_id, 'finances.depenses', 'expenses.update'));
create policy depense_categories_modification on public.depense_categories for update to authenticated
  using (app.peut(entreprise_id, 'finances.depenses', 'expenses.update'))
  with check (app.peut(entreprise_id, 'finances.depenses', 'expenses.update'));

revoke all on public.depense_categories from anon, authenticated;
grant select on public.depense_categories to authenticated;
grant insert (id, entreprise_id, nom, ordre) on public.depense_categories to authenticated;
grant update (nom, est_active, ordre) on public.depense_categories to authenticated;
grant all on public.depense_categories to service_role;

-- -----------------------------------------------------------------------------
-- 3. Dépenses
-- -----------------------------------------------------------------------------

create table public.depenses (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  activite_code text references public.activites (code),
  perimetre_id uuid,
  categorie_id uuid not null,
  libelle text not null check (char_length(trim(libelle)) between 1 and 200),
  montant bigint not null check (montant > 0),
  date_depense date not null default current_date,
  contact_id uuid,
  -- IMMEDIAT : payée maintenant ; DIFFERE : devient une somme à payer.
  reglement text not null check (reglement in ('IMMEDIAT', 'DIFFERE')),
  mode_code text references public.modes_paiement (code),
  session_id uuid,
  paiement_id uuid unique,
  echeance date,
  reference text check (char_length(reference) <= 100),
  note text check (char_length(note) <= 500),
  statut text not null default 'ENREGISTREE' check (statut in ('ENREGISTREE', 'ANNULEE')),
  motif_annulation text check (char_length(motif_annulation) <= 500),
  annule_par uuid references public.profiles (id) on delete set null,
  annule_le timestamptz,
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id),
  foreign key (categorie_id, entreprise_id) references public.depense_categories (id, entreprise_id),
  foreign key (perimetre_id, entreprise_id) references public.perimetres (id, entreprise_id),
  foreign key (contact_id, entreprise_id) references public.contacts (id, entreprise_id),
  foreign key (session_id, entreprise_id) references public.caisse_sessions (id, entreprise_id),
  check (reglement = 'DIFFERE' or (mode_code is not null and paiement_id is not null)),
  check (reglement = 'IMMEDIAT' or (mode_code is null and session_id is null and paiement_id is null))
);
create index depenses_sync_idx on public.depenses (entreprise_id, updated_at);
create index depenses_date_idx on public.depenses (entreprise_id, date_depense desc);
create index depenses_categorie_idx on public.depenses (categorie_id);

create or replace function app.tg_depenses_avant()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session public.caisse_sessions;
begin
  if tg_op = 'INSERT' then
    perform app.exiger(app.peut(new.entreprise_id, 'finances.depenses', 'expenses.create', new.perimetre_id));
    if new.reglement = 'IMMEDIAT' then
      perform app.exiger(app.peut(new.entreprise_id, 'finances.paiements', 'payments.create', new.perimetre_id));
      if new.session_id is not null then
        select * into v_session from public.caisse_sessions
        where id = new.session_id and entreprise_id = new.entreprise_id;
        perform app.exiger(app.peut(new.entreprise_id, 'finances.caisse', 'cash.move', v_session.perimetre_id));
        if new.perimetre_id is null then
          new.perimetre_id := v_session.perimetre_id;
        end if;
      end if;
    end if;
    if not exists (
      select 1 from public.depense_categories c
      where c.id = new.categorie_id and c.entreprise_id = new.entreprise_id and c.est_active
    ) then
      perform app.refuser('CATEGORIE_INVALIDE');
    end if;
    new.activite_code := app.activite_du_perimetre(new.entreprise_id, new.perimetre_id, new.activite_code);
    new.statut := 'ENREGISTREE';
    new.motif_annulation := null;
    new.annule_par := null;
    new.annule_le := null;
    new.created_by := coalesce(auth.uid(), new.created_by);
    return new;
  end if;

  -- Modification : texte, catégorie, date, ou annulation.
  perform app.exiger(app.peut(new.entreprise_id, 'finances.depenses', 'expenses.update', new.perimetre_id));
  if old.statut = 'ANNULEE' then
    perform app.refuser('DEPENSE_ANNULEE');
  end if;
  if new.categorie_id is distinct from old.categorie_id and not exists (
    select 1 from public.depense_categories c
    where c.id = new.categorie_id and c.entreprise_id = new.entreprise_id and c.est_active
  ) then
    perform app.refuser('CATEGORIE_INVALIDE');
  end if;
  if new.statut = 'ANNULEE' then
    -- Ce qui a été payé s'annule d'abord (paiement inverse) : rien n'est effacé.
    if exists (select 1 from public.engagements e where e.id = old.id and e.montant_regle > 0) then
      perform app.refuser('DEPENSE_PAYEE');
    end if;
    new.annule_par := auth.uid();
    new.annule_le := now();
  end if;
  return new;
end;
$$;

create or replace function app.tg_depenses_apres()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.rpc_de_confiance(true);

  if tg_op = 'INSERT' then
    insert into public.engagements (id, entreprise_id, activite_code, perimetre_id, sens, contact_id,
                                    libelle, montant_total, date_engagement, echeance, origine_type, origine_id)
    values (new.id, new.entreprise_id, new.activite_code, new.perimetre_id, 'A_PAYER', new.contact_id,
            new.libelle, new.montant, new.date_depense,
            case when new.reglement = 'DIFFERE' then new.echeance end, 'DEPENSE', new.id);

    if new.reglement = 'IMMEDIAT' then
      insert into public.paiements (id, entreprise_id, activite_code, perimetre_id, sens, montant, mode_code,
                                    date_paiement, contact_id, reference, note, session_id, affectations)
      values (new.paiement_id, new.entreprise_id, new.activite_code, new.perimetre_id, 'SORTIE', new.montant,
              new.mode_code,
              case when new.date_depense = current_date then now() else new.date_depense::timestamptz end,
              new.contact_id, new.reference, new.libelle, new.session_id,
              jsonb_build_array(jsonb_build_object(
                'id', new.paiement_id, 'engagement_id', new.id, 'montant', new.montant)));
    end if;
  else
    update public.engagements
    set libelle = new.libelle,
        statut = case when new.statut = 'ANNULEE' then 'ANNULE' else statut end,
        motif_annulation = case when new.statut = 'ANNULEE' then new.motif_annulation else motif_annulation end
    where id = new.id;
  end if;

  perform app.rpc_de_confiance(false);
  return null;
end;
$$;

create trigger depenses_avant before insert or update on public.depenses
  for each row execute function app.tg_depenses_avant();
create trigger depenses_versionnement before insert or update on public.depenses
  for each row execute function app.tg_versionnement();
create trigger depenses_apres after insert or update on public.depenses
  for each row execute function app.tg_depenses_apres();
create trigger audit_depenses after insert or update or delete on public.depenses
  for each row execute function app.tg_audit();

alter table public.depenses enable row level security;
create policy depenses_lecture on public.depenses for select to authenticated
  using (app.peut(entreprise_id, 'finances.depenses', 'expenses.view', perimetre_id));
create policy depenses_ajout on public.depenses for insert to authenticated
  with check (app.peut(entreprise_id, 'finances.depenses', 'expenses.create', perimetre_id));
create policy depenses_modification on public.depenses for update to authenticated
  using (app.peut(entreprise_id, 'finances.depenses', 'expenses.update', perimetre_id))
  with check (app.peut(entreprise_id, 'finances.depenses', 'expenses.update', perimetre_id));

revoke all on public.depenses from anon, authenticated;
grant select on public.depenses to authenticated;
grant insert (id, entreprise_id, activite_code, perimetre_id, categorie_id, libelle, montant, date_depense,
              contact_id, reglement, mode_code, session_id, paiement_id, echeance, reference, note)
  on public.depenses to authenticated;
-- Le montant ne se modifie pas : on annule et on ressaisit (traçabilité).
grant update (categorie_id, libelle, date_depense, reference, note, statut, motif_annulation)
  on public.depenses to authenticated;
grant all on public.depenses to service_role;

-- -----------------------------------------------------------------------------
-- 4. Synchronisation
-- -----------------------------------------------------------------------------

insert into app.sync_tables (table_name, colonnes_creation, colonnes_modification) values
  ('depense_categories', array['entreprise_id', 'nom', 'ordre'], array['nom', 'est_active', 'ordre']),
  ('depenses',
   array['entreprise_id', 'activite_code', 'perimetre_id', 'categorie_id', 'libelle', 'montant', 'date_depense',
         'contact_id', 'reglement', 'mode_code', 'session_id', 'paiement_id', 'echeance', 'reference', 'note'],
   array['categorie_id', 'libelle', 'date_depense', 'reference', 'note', 'statut', 'motif_annulation']);
