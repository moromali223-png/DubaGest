-- =============================================================================
-- EXTENSION DU MODULE DOCUMENTS : TYPES DE DOCUMENTS ET LIENS MULTI-ACTIVITÉS
-- =============================================================================

-- 1. Extension des préfixes de documents
create or replace function app.prefixe_document(p_type text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_type
    when 'RECU' then 'REC'
    when 'FACTURE' then 'FAC'
    when 'DEVIS' then 'DEV'
    when 'AVOIR' then 'AV'
    when 'BON_COMMANDE' then 'BC'
    when 'BON_TRAVAIL' then 'BT'
    when 'QUITTANCE' then 'QUI'
    when 'CONTRAT' then 'CTR'
  end;
$$;

-- 2. Mise à jour des contraintes sur document_series
do $$
begin
  alter table public.document_series drop constraint if exists document_series_type_check;
  alter table public.document_series add constraint document_series_type_check
    check (type in ('RECU', 'FACTURE', 'DEVIS', 'AVOIR', 'BON_COMMANDE', 'BON_TRAVAIL', 'QUITTANCE', 'CONTRAT'));
exception when others then
  null;
end $$;

-- 3. Mise à jour des contraintes sur documents
do $$
begin
  alter table public.documents drop constraint if exists documents_type_check;
  alter table public.documents add constraint documents_type_check
    check (type in ('RECU', 'FACTURE', 'DEVIS', 'AVOIR', 'BON_COMMANDE', 'BON_TRAVAIL', 'QUITTANCE', 'CONTRAT'));

  alter table public.documents drop constraint if exists documents_origine_type_check;
  alter table public.documents add constraint documents_origine_type_check
    check (origine_type in ('PAIEMENT', 'DEPENSE', 'ENGAGEMENT', 'VENTE', 'ACHAT', 'PRESTATION', 'IMMOBILIER', 'MANUEL'));
exception when others then
  null;
end $$;

-- 4. Trigger avant insertion sur documents
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

  if new.origine_id is not null and exists (
    select 1 from public.documents d
    where d.type = new.type and d.origine_type = new.origine_type and d.origine_id = new.origine_id
  ) then
    perform app.refuser('DOCUMENT_EXISTANT');
  end if;

  -- Validation spécifique pour le reçu d'un encaissement
  if new.type = 'RECU' and new.origine_type = 'PAIEMENT' then
    select * into v_paiement from public.paiements
    where id = new.origine_id and entreprise_id = new.entreprise_id;
    if v_paiement.id is null or v_paiement.sens <> 'ENTREE' or v_paiement.annule_paiement_id is not null then
      perform app.refuser('ORIGINE_INVALIDE');
    end if;
    new.montant := v_paiement.montant;
    new.contact_id := v_paiement.contact_id;
    new.perimetre_id := v_paiement.perimetre_id;
    new.activite_code := v_paiement.activite_code;
  end if;

  new.statut := coalesce(new.statut, 'EMIS');
  new.created_by := coalesce(auth.uid(), new.created_by);
  return new;
end;
$$;

-- 5. Extension des pièces jointes et vérifications de cibles
do $$
begin
  alter table public.pieces_jointes drop constraint if exists pieces_jointes_cible_type_check;
  alter table public.pieces_jointes add constraint pieces_jointes_cible_type_check
    check (cible_type in ('CONTACT', 'ENGAGEMENT', 'PAIEMENT', 'DEPENSE', 'DOCUMENT'));

  alter table public.notes drop constraint if exists notes_cible_type_check;
  alter table public.notes add constraint notes_cible_type_check
    check (cible_type in ('CONTACT', 'ENGAGEMENT', 'PAIEMENT', 'DEPENSE', 'DOCUMENT'));
exception when others then
  null;
end $$;

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
  elsif p_type = 'DOCUMENT' then
    select perimetre_id into v from public.documents where id = p_id;
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
    select exists (select 1 from public.paiements where id = p_id and entreprise_id = p_entreprise_id);
  elsif p_type = 'DEPENSE' then
    return exists (select 1 from public.depenses where id = p_id and entreprise_id = p_entreprise_id);
  elsif p_type = 'DOCUMENT' then
    return exists (select 1 from public.documents where id = p_id and entreprise_id = p_entreprise_id);
  end if;
  return false;
end;
$$;

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
  elsif p_type = 'DOCUMENT' then
    v_module := 'commun.documents';
    v_permission := case p_mode when 'LECTURE' then 'documents.view' else 'documents.create' end;
  else
    return false;
  end if;
  return app.peut(p_entreprise_id, v_module, v_permission, app.perimetre_cible(p_type, p_id));
end;
$$;
