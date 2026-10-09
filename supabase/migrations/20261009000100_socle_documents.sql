-- =============================================================================
-- SOCLE COMMUN — ÉTAPE 5 : DOCUMENTS ET NUMÉROTATION
--
-- Numérotation hors-ligne par BLOCS RÉSERVÉS : en ligne, un appareil réserve
-- un bloc de numéros (ex. REC-2026-00051 à 00100) ; hors-ligne, il émet ses
-- documents dans ce bloc. Les numéros sont uniques et croissants par série ;
-- un bloc entamé puis abandonné laisse des numéros inutilisés (trous connus).
--
-- Un document est FIGÉ : son contenu (en-tête de l'entreprise, contact,
-- montants) est copié à l'émission et ne change plus. Premier type : le reçu
-- de paiement (RECU) ; FACTURE, DEVIS, AVOIR viendront avec leurs modules.
-- =============================================================================

insert into public.modules (code, libelle, activite_code, permission_acces, ordre, categorie)
values ('commun.documents', 'Documents', null, 'documents.view', 11, 'COMMUN');
insert into public.plan_modules (plan_code, module_code)
select code, 'commun.documents' from public.plans;

-- -----------------------------------------------------------------------------
-- 1. Séries et blocs
-- -----------------------------------------------------------------------------

create table public.document_series (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  type text not null check (type in ('RECU', 'FACTURE', 'DEVIS', 'AVOIR')),
  annee integer not null check (annee between 2000 and 2999),
  prefixe text not null check (prefixe ~ '^[A-Z]{2,5}$'),
  prochain bigint not null default 1 check (prochain >= 1),
  unique (entreprise_id, type, annee)
);

create table public.numero_blocs (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  serie_id uuid not null references public.document_series (id) on delete cascade,
  type text not null,
  annee integer not null,
  prefixe text not null,
  appareil_id text not null check (char_length(appareil_id) between 8 and 64),
  user_id uuid not null references auth.users (id) on delete cascade,
  debut bigint not null,
  fin bigint not null,
  created_at timestamptz not null default now(),
  check (fin >= debut)
);
create index numero_blocs_user_idx on public.numero_blocs (user_id, entreprise_id, type);

alter table public.document_series enable row level security;
alter table public.numero_blocs enable row level security;
-- Chaque utilisateur ne voit que ses propres blocs ; aucune écriture directe.
create policy numero_blocs_lecture on public.numero_blocs for select to authenticated
  using (user_id = (select auth.uid()));
revoke all on public.document_series, public.numero_blocs from anon, authenticated;
grant select on public.numero_blocs to authenticated;
grant all on public.document_series, public.numero_blocs to service_role;

create or replace function app.prefixe_document(p_type text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_type when 'RECU' then 'REC' when 'FACTURE' then 'FAC' when 'DEVIS' then 'DEV' when 'AVOIR' then 'AV' end;
$$;

-- Réserve un bloc de numéros pour cet appareil (en ligne). Atomique : deux
-- appareils ne reçoivent jamais le même numéro.
create or replace function public.reserver_bloc(
  p_entreprise_id uuid,
  p_type text,
  p_appareil_id text,
  p_taille integer default 50
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_annee integer := extract(year from now())::integer;
  v_serie public.document_series;
  v_taille integer := least(greatest(coalesce(p_taille, 50), 1), 200);
  v_bloc public.numero_blocs;
begin
  if not app.peut(p_entreprise_id, 'commun.documents', 'documents.create') then
    raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
  end if;
  if app.prefixe_document(p_type) is null then
    perform app.refuser('TYPE_DOCUMENT_INVALIDE');
  end if;

  insert into public.document_series (entreprise_id, type, annee, prefixe)
  values (p_entreprise_id, p_type, v_annee, app.prefixe_document(p_type))
  on conflict (entreprise_id, type, annee) do nothing;

  select * into v_serie from public.document_series
  where entreprise_id = p_entreprise_id and type = p_type and annee = v_annee
  for update;

  update public.document_series set prochain = prochain + v_taille where id = v_serie.id;

  insert into public.numero_blocs (entreprise_id, serie_id, type, annee, prefixe, appareil_id, user_id, debut, fin)
  values (p_entreprise_id, v_serie.id, p_type, v_annee, v_serie.prefixe, p_appareil_id, auth.uid(),
          v_serie.prochain, v_serie.prochain + v_taille - 1)
  returning * into v_bloc;

  return to_jsonb(v_bloc);
end;
$$;

revoke execute on function public.reserver_bloc(uuid, text, text, integer) from public, anon;
grant execute on function public.reserver_bloc(uuid, text, text, integer) to authenticated;

-- -----------------------------------------------------------------------------
-- 2. Documents
-- -----------------------------------------------------------------------------

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  type text not null check (type in ('RECU', 'FACTURE', 'DEVIS', 'AVOIR')),
  -- Calculé par le serveur : PREFIXE-ANNEE-00000.
  numero text not null,
  serie_id uuid not null references public.document_series (id),
  bloc_id uuid not null references public.numero_blocs (id),
  sequence bigint not null,
  langue text not null check (langue in ('fr', 'en', 'ar')),
  date_document timestamptz not null default now(),
  perimetre_id uuid,
  activite_code text references public.activites (code),
  contact_id uuid,
  montant bigint not null check (montant >= 0),
  origine_type text not null check (origine_type in ('PAIEMENT', 'DEPENSE', 'ENGAGEMENT', 'MANUEL')),
  origine_id uuid,
  -- Contenu figé à l'émission (en-tête, contact, lignes, montants).
  contenu jsonb not null check (jsonb_typeof(contenu) = 'object'),
  statut text not null default 'EMIS' check (statut in ('EMIS', 'ANNULE')),
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (entreprise_id, numero),
  unique (serie_id, sequence),
  foreign key (perimetre_id, entreprise_id) references public.perimetres (id, entreprise_id),
  foreign key (contact_id, entreprise_id) references public.contacts (id, entreprise_id)
);
create index documents_sync_idx on public.documents (entreprise_id, updated_at);
create index documents_origine_idx on public.documents (origine_type, origine_id);
-- Un seul reçu par paiement (deux appareils hors-ligne : le second est refusé).
create unique index documents_un_par_origine on public.documents (type, origine_type, origine_id)
  where origine_id is not null;

create or replace function app.tg_documents_avant()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bloc public.numero_blocs;
  v_paiement public.paiements;
begin
  perform app.exiger(app.peut(new.entreprise_id, 'commun.documents', 'documents.create', new.perimetre_id));

  select * into v_bloc from public.numero_blocs where id = new.bloc_id and entreprise_id = new.entreprise_id;
  if v_bloc.id is null or v_bloc.type <> new.type
     or (v_bloc.user_id <> auth.uid() and (select auth.role()) = 'authenticated') then
    perform app.refuser('BLOC_INVALIDE');
  end if;
  if new.sequence not between v_bloc.debut and v_bloc.fin then
    perform app.refuser('NUMERO_HORS_BLOC');
  end if;
  new.serie_id := v_bloc.serie_id;
  new.numero := v_bloc.prefixe || '-' || v_bloc.annee || '-' || lpad(new.sequence::text, 5, '0');

  if exists (select 1 from public.documents d
             where d.type = new.type and d.origine_type = new.origine_type and d.origine_id = new.origine_id) then
    perform app.refuser('DOCUMENT_EXISTANT');
  end if;

  -- Reçu : uniquement pour un encaissement valide ; montant et contact du paiement.
  if new.type = 'RECU' then
    select * into v_paiement from public.paiements
    where id = new.origine_id and entreprise_id = new.entreprise_id;
    if new.origine_type <> 'PAIEMENT' or v_paiement.id is null
       or v_paiement.sens <> 'ENTREE' or v_paiement.annule_paiement_id is not null then
      perform app.refuser('ORIGINE_INVALIDE');
    end if;
    new.montant := v_paiement.montant;
    new.contact_id := v_paiement.contact_id;
    new.perimetre_id := v_paiement.perimetre_id;
    new.activite_code := v_paiement.activite_code;
  end if;

  new.statut := 'EMIS';
  new.created_by := coalesce(auth.uid(), new.created_by);
  return new;
end;
$$;

create trigger documents_avant before insert on public.documents
  for each row execute function app.tg_documents_avant();
create trigger documents_versionnement before insert or update on public.documents
  for each row execute function app.tg_versionnement();
create trigger audit_documents after insert or update or delete on public.documents
  for each row execute function app.tg_audit();

alter table public.documents enable row level security;
create policy documents_lecture on public.documents for select to authenticated
  using (app.peut(entreprise_id, 'commun.documents', 'documents.view', perimetre_id));
create policy documents_ajout on public.documents for insert to authenticated
  with check (app.peut(entreprise_id, 'commun.documents', 'documents.create', perimetre_id));

revoke all on public.documents from anon, authenticated;
grant select on public.documents to authenticated;
-- Aucun droit de modification : un document émis ne change plus.
grant insert (id, entreprise_id, type, bloc_id, sequence, langue, date_document, perimetre_id, activite_code,
              contact_id, montant, origine_type, origine_id, contenu)
  on public.documents to authenticated;
grant all on public.documents to service_role;

insert into app.sync_tables (table_name, colonnes_creation, colonnes_modification) values
  ('documents',
   array['entreprise_id', 'type', 'bloc_id', 'sequence', 'langue', 'date_document', 'perimetre_id',
         'activite_code', 'contact_id', 'montant', 'origine_type', 'origine_id', 'contenu'],
   '{}');
