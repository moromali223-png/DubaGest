-- =============================================================================
-- SERVICES — ÉTAPE 1 : CATALOGUE, PRESTATIONS, HISTORIQUE, RÔLES
--
-- Une prestation (ordre de travail) suit le modèle des ventes : elle crée sa
-- somme à recevoir (engagement d'origine PRESTATION, même identifiant). Les
-- acomptes et soldes sont des paiements ordinaires affectés à cette somme :
-- caisse, dettes et finance restent ceux du socle, sans double saisie.
--
-- Deux dimensions INDÉPENDANTES :
--   • statut du travail : A_FAIRE, PLANIFIEE, EN_COURS, TERMINEE, LIVREE, ANNULEE
--   • état du paiement   : calculé (engagement réglé, partiel, rien), jamais saisi.
--
-- Dates distinctes, jamais confondues :
--   debut_prevu (instant précis), echeance_jour + echeance_heure (date limite,
--   heure LOCALE facultative : sans heure, toute la journée compte), et
--   l'historique de chaque changement de date ou de statut (avec motif).
-- La priorité (À venir, Attention, Urgent, Aujourd'hui, En retard) est
-- CALCULÉE à partir de l'échéance et du statut : jamais stockée.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Permissions et rôles
-- -----------------------------------------------------------------------------

insert into public.permissions (code, description) values
  ('prestations.cancel', 'Annuler une prestation (avec motif)');

insert into public.roles (code, libelle, activite_code, ordre) values
  ('GESTIONNAIRE_SERVICES', 'Gestionnaire services', 'SERVICES', 7),
  ('PRESTATAIRE', 'Prestataire', 'SERVICES', 8);

insert into public.plan_roles (plan_code, role_code, max_membres) values
  ('NORMAL', 'GESTIONNAIRE_SERVICES', 1),
  ('NORMAL', 'PRESTATAIRE', 2),
  ('MOYEN', 'GESTIONNAIRE_SERVICES', 1),
  ('MOYEN', 'PRESTATAIRE', 3),
  ('PRO', 'GESTIONNAIRE_SERVICES', null),
  ('PRO', 'PRESTATAIRE', null)
on conflict do nothing;

insert into public.roles_permissions (role_code, permission_code)
select r.role_code, r.permission_code
from (values
  ('ADMINISTRATEUR', 'prestations.cancel'),
  -- Gestionnaire : tout le module Services et le socle utile.
  ('GESTIONNAIRE_SERVICES', 'perimetres.view'),
  ('GESTIONNAIRE_SERVICES', 'services.view'), ('GESTIONNAIRE_SERVICES', 'services.create'),
  ('GESTIONNAIRE_SERVICES', 'services.update'),
  ('GESTIONNAIRE_SERVICES', 'prestations.view'), ('GESTIONNAIRE_SERVICES', 'prestations.create'),
  ('GESTIONNAIRE_SERVICES', 'prestations.update'), ('GESTIONNAIRE_SERVICES', 'prestations.cancel'),
  ('GESTIONNAIRE_SERVICES', 'quotes.view'), ('GESTIONNAIRE_SERVICES', 'quotes.create'),
  ('GESTIONNAIRE_SERVICES', 'quotes.update'),
  ('GESTIONNAIRE_SERVICES', 'contacts.view'), ('GESTIONNAIRE_SERVICES', 'contacts.create'),
  ('GESTIONNAIRE_SERVICES', 'contacts.update'),
  ('GESTIONNAIRE_SERVICES', 'payments.view'), ('GESTIONNAIRE_SERVICES', 'payments.create'),
  ('GESTIONNAIRE_SERVICES', 'receivables.view'), ('GESTIONNAIRE_SERVICES', 'receivables.manage'),
  ('GESTIONNAIRE_SERVICES', 'expenses.view'), ('GESTIONNAIRE_SERVICES', 'expenses.create'),
  ('GESTIONNAIRE_SERVICES', 'documents.view'), ('GESTIONNAIRE_SERVICES', 'documents.create'),
  ('GESTIONNAIRE_SERVICES', 'documents.print'), ('GESTIONNAIRE_SERVICES', 'documents.share'),
  ('GESTIONNAIRE_SERVICES', 'agenda.view'), ('GESTIONNAIRE_SERVICES', 'agenda.manage'),
  ('GESTIONNAIRE_SERVICES', 'reports.view'),
  -- Prestataire : voit les prestations et fait avancer le travail.
  ('PRESTATAIRE', 'perimetres.view'), ('PRESTATAIRE', 'services.view'),
  ('PRESTATAIRE', 'prestations.view'), ('PRESTATAIRE', 'prestations.update'),
  ('PRESTATAIRE', 'contacts.view'), ('PRESTATAIRE', 'agenda.view')
) as r(role_code, permission_code)
on conflict do nothing;

-- -----------------------------------------------------------------------------
-- 2. Catalogue des prestations
-- -----------------------------------------------------------------------------

create table public.services_catalogue (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  nom text not null check (char_length(trim(nom)) between 1 and 120),
  categorie text check (char_length(categorie) <= 60),
  description text check (char_length(description) <= 500),
  -- Prix indicatif : valeur par défaut, figée dans chaque prestation.
  prix bigint not null default 0 check (prix >= 0),
  unite text not null default 'FORFAIT' check (unite in ('FORFAIT', 'HEURE', 'JOUR', 'PIECE', 'M2', 'KM')),
  duree_minutes integer check (duree_minutes between 1 and 10080),
  icone text check (char_length(icone) <= 40),
  est_actif boolean not null default true,
  ordre integer not null default 100,
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id)
);
create index services_catalogue_sync_idx on public.services_catalogue (entreprise_id, updated_at);

create or replace function app.tg_services_catalogue_regles()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.exiger(app.peut(new.entreprise_id, 'services.services',
                              case when tg_op = 'INSERT' then 'services.create' else 'services.update' end));
  if tg_op = 'INSERT' then
    new.created_by := coalesce(auth.uid(), new.created_by);
  end if;
  return new;
end;
$$;

create trigger services_catalogue_regles before insert or update on public.services_catalogue
  for each row execute function app.tg_services_catalogue_regles();
create trigger services_catalogue_versionnement before insert or update on public.services_catalogue
  for each row execute function app.tg_versionnement();
create trigger audit_services_catalogue after insert or update or delete on public.services_catalogue
  for each row execute function app.tg_audit();

alter table public.services_catalogue enable row level security;
create policy services_catalogue_lecture on public.services_catalogue for select to authenticated
  using (app.peut(entreprise_id, 'services.services', 'services.view'));
create policy services_catalogue_ajout on public.services_catalogue for insert to authenticated
  with check (app.peut(entreprise_id, 'services.services', 'services.create'));
create policy services_catalogue_modification on public.services_catalogue for update to authenticated
  using (app.peut(entreprise_id, 'services.services', 'services.update'))
  with check (app.peut(entreprise_id, 'services.services', 'services.update'));

revoke all on public.services_catalogue from anon, authenticated;
grant select on public.services_catalogue to authenticated;
grant insert (id, entreprise_id, nom, categorie, description, prix, unite, duree_minutes, icone, ordre)
  on public.services_catalogue to authenticated;
-- Pas de suppression : on archive (est_actif = false).
grant update (nom, categorie, description, prix, unite, duree_minutes, icone, ordre, est_actif)
  on public.services_catalogue to authenticated;
grant all on public.services_catalogue to service_role;

-- -----------------------------------------------------------------------------
-- 3. Prestations
--    lignes : [{id, service_id?, libelle, quantite, prix_unitaire}]
--    prix figé : un changement du catalogue ne touche jamais l'historique.
-- -----------------------------------------------------------------------------

create or replace function app.lignes_prestation_valides(p_lignes jsonb, p_entreprise_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_typeof(p_lignes) = 'array'
     and jsonb_array_length(p_lignes) between 1 and 100
     and not exists (
       select 1
       from jsonb_to_recordset(p_lignes) as x(id uuid, service_id uuid, libelle text, quantite numeric, prix_unitaire bigint)
       where x.id is null
          or char_length(trim(coalesce(x.libelle, ''))) not between 1 and 200
          or coalesce(x.quantite, 0) <= 0 or x.quantite > 1000000
          or coalesce(x.prix_unitaire, -1) < 0
          or (x.service_id is not null and not exists (
                select 1 from public.services_catalogue s
                where s.id = x.service_id and s.entreprise_id = p_entreprise_id))
     );
$$;

create or replace function app.total_lignes_prestation(p_lignes jsonb)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select coalesce(sum(round(x.quantite * x.prix_unitaire)), 0)::bigint
  from jsonb_to_recordset(p_lignes) as x(quantite numeric, prix_unitaire bigint);
$$;

create table public.prestations (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  activite_code text references public.activites (code),
  perimetre_id uuid,
  contact_id uuid,
  titre text not null check (char_length(trim(titre)) between 1 and 200),
  description text check (char_length(description) <= 2000),
  lignes jsonb not null,
  remise bigint not null default 0 check (remise >= 0),
  total bigint not null default 0 check (total >= 0),
  statut text not null default 'A_FAIRE'
    check (statut in ('A_FAIRE', 'PLANIFIEE', 'EN_COURS', 'TERMINEE', 'LIVREE', 'ANNULEE')),
  -- Priorité métier choisie (la priorité d'échéance, elle, est calculée).
  priorite text not null default 'NORMALE' check (priorite in ('NORMALE', 'HAUTE')),
  debut_prevu timestamptz,
  echeance_jour date,
  echeance_heure time,
  livraison_requise boolean not null default false,
  duree_minutes integer check (duree_minutes between 1 and 100000),
  responsable_id uuid references auth.users (id) on delete set null,
  responsable_nom text,
  lieu text check (char_length(lieu) <= 200),
  note text check (char_length(note) <= 2000),
  -- Motif du dernier report (repris dans l'historique).
  motif_report text check (char_length(motif_report) <= 500),
  termine_le timestamptz,
  livre_le timestamptz,
  motif_annulation text check (char_length(motif_annulation) <= 500),
  annule_par uuid references public.profiles (id) on delete set null,
  annule_le timestamptz,
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id),
  foreign key (perimetre_id, entreprise_id) references public.perimetres (id, entreprise_id),
  foreign key (contact_id, entreprise_id) references public.contacts (id, entreprise_id),
  check (echeance_heure is null or echeance_jour is not null),
  check (statut <> 'ANNULEE' or motif_annulation is not null)
);
create index prestations_sync_idx on public.prestations (entreprise_id, updated_at);
create index prestations_echeance_idx on public.prestations (entreprise_id, statut, echeance_jour);
create index prestations_responsable_idx on public.prestations (responsable_id, statut);
create index prestations_contact_idx on public.prestations (contact_id);

create table public.prestation_historique (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  prestation_id uuid not null,
  perimetre_id uuid,
  type text not null check (type in ('CREATION', 'STATUT', 'ECHEANCE', 'RESPONSABLE')),
  ancien text,
  nouveau text,
  motif text,
  auteur_id uuid references public.profiles (id) on delete set null,
  auteur_nom text,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  foreign key (prestation_id, entreprise_id) references public.prestations (id, entreprise_id)
);
create index prestation_historique_sync_idx on public.prestation_historique (entreprise_id, updated_at);
create index prestation_historique_prestation_idx on public.prestation_historique (prestation_id, created_at);

create or replace function app.tg_prestations_avant()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    perform app.exiger(app.peut(new.entreprise_id, 'services.prestations', 'prestations.create', new.perimetre_id));
    if new.statut not in ('A_FAIRE', 'PLANIFIEE', 'EN_COURS', 'TERMINEE') then
      perform app.refuser('STATUT_INVALIDE');
    end if;
    new.termine_le := case when new.statut = 'TERMINEE' then now() end;
    new.livre_le := null;
    new.motif_annulation := null;
    new.annule_par := null;
    new.annule_le := null;
    new.created_by := coalesce(auth.uid(), new.created_by);
  else
    if old.statut = 'ANNULEE' then
      perform app.refuser('PRESTATION_ANNULEE');
    end if;
    if new.statut = 'ANNULEE' then
      perform app.exiger(app.peut(new.entreprise_id, 'services.prestations', 'prestations.cancel', new.perimetre_id));
      if char_length(trim(coalesce(new.motif_annulation, ''))) = 0 then
        perform app.refuser('MOTIF_REQUIS');
      end if;
      -- Ce qui a été encaissé s'annule d'abord (paiement inverse).
      if exists (select 1 from public.engagements e where e.id = old.id and e.montant_regle > 0) then
        perform app.refuser('PRESTATION_PAYEE');
      end if;
      new.annule_par := auth.uid();
      new.annule_le := now();
    else
      perform app.exiger(app.peut(new.entreprise_id, 'services.prestations', 'prestations.update', new.perimetre_id));
    end if;
    -- Le contenu facturé ne change plus une fois le travail terminé.
    if (new.lignes, new.remise) is distinct from (old.lignes, old.remise)
       and old.statut in ('TERMINEE', 'LIVREE') then
      perform app.refuser('PRESTATION_TERMINEE');
    end if;
    if new.statut is distinct from old.statut then
      new.termine_le := case
        when new.statut in ('TERMINEE', 'LIVREE') then coalesce(old.termine_le, now())
        when new.statut = 'ANNULEE' then old.termine_le
      end;
      new.livre_le := case when new.statut = 'LIVREE' then now() end;
    end if;
  end if;

  if not app.lignes_prestation_valides(new.lignes, new.entreprise_id) then
    perform app.refuser('LIGNES_INVALIDES');
  end if;
  new.total := app.total_lignes_prestation(new.lignes) - new.remise;
  if new.total < 0 then
    perform app.refuser('MONTANT_INVALIDE');
  end if;
  if tg_op = 'UPDATE' and new.total < coalesce((select e.montant_regle from public.engagements e where e.id = old.id), 0) then
    perform app.refuser('MONTANT_INFERIEUR_REGLE');
  end if;

  if new.responsable_id is not null
     and (tg_op = 'INSERT' or new.responsable_id is distinct from old.responsable_id) then
    if not exists (select 1 from public.membres_entreprise m
                   where m.entreprise_id = new.entreprise_id and m.user_id = new.responsable_id
                     and m.statut = 'ACTIF') then
      perform app.refuser('RESPONSABLE_INVALIDE');
    end if;
  end if;
  new.responsable_nom := (select p.nom_complet from public.profiles p where p.id = new.responsable_id);
  new.activite_code := coalesce(app.activite_du_perimetre(new.entreprise_id, new.perimetre_id, new.activite_code),
                                'SERVICES');
  return new;
end;
$$;

create or replace function app.tg_prestations_apres()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auteur text := (select p.nom_complet from public.profiles p where p.id = auth.uid());
  v_echeance_avant text;
  v_echeance_apres text;
begin
  perform app.rpc_de_confiance(true);

  if tg_op = 'INSERT' then
    if new.total > 0 then
      insert into public.engagements (id, entreprise_id, activite_code, perimetre_id, sens, contact_id, libelle,
                                      montant_total, date_engagement, echeance, origine_type, origine_id)
      values (new.id, new.entreprise_id, new.activite_code, new.perimetre_id, 'A_RECEVOIR', new.contact_id,
              new.titre, new.total, current_date, new.echeance_jour, 'PRESTATION', new.id);
    end if;
    insert into public.prestation_historique (entreprise_id, prestation_id, perimetre_id, type, nouveau,
                                              auteur_id, auteur_nom)
    values (new.entreprise_id, new.id, new.perimetre_id, 'CREATION', new.statut, auth.uid(), v_auteur);
  else
    -- Somme à recevoir : suit le contenu, l'échéance, le client ; annulée avec la prestation.
    if new.statut = 'ANNULEE' and old.statut <> 'ANNULEE' then
      update public.engagements set statut = 'ANNULE', motif_annulation = new.motif_annulation where id = new.id;
    elsif exists (select 1 from public.engagements e where e.id = new.id) then
      update public.engagements
      set montant_total = new.total, libelle = new.titre, echeance = new.echeance_jour, contact_id = new.contact_id
      where id = new.id
        and (montant_total, libelle, echeance, contact_id) is distinct from
            (new.total, new.titre, new.echeance_jour, new.contact_id);
    elsif new.total > 0 then
      insert into public.engagements (id, entreprise_id, activite_code, perimetre_id, sens, contact_id, libelle,
                                      montant_total, date_engagement, echeance, origine_type, origine_id)
      values (new.id, new.entreprise_id, new.activite_code, new.perimetre_id, 'A_RECEVOIR', new.contact_id,
              new.titre, new.total, current_date, new.echeance_jour, 'PRESTATION', new.id);
    end if;

    if new.statut is distinct from old.statut then
      insert into public.prestation_historique (entreprise_id, prestation_id, perimetre_id, type, ancien, nouveau,
                                                motif, auteur_id, auteur_nom)
      values (new.entreprise_id, new.id, new.perimetre_id, 'STATUT', old.statut, new.statut,
              case when new.statut = 'ANNULEE' then new.motif_annulation end, auth.uid(), v_auteur);
    end if;
    v_echeance_avant := concat_ws(' ', old.echeance_jour::text, old.echeance_heure::text);
    v_echeance_apres := concat_ws(' ', new.echeance_jour::text, new.echeance_heure::text);
    if v_echeance_avant is distinct from v_echeance_apres then
      insert into public.prestation_historique (entreprise_id, prestation_id, perimetre_id, type, ancien, nouveau,
                                                motif, auteur_id, auteur_nom)
      values (new.entreprise_id, new.id, new.perimetre_id, 'ECHEANCE', nullif(v_echeance_avant, ''),
              nullif(v_echeance_apres, ''), new.motif_report, auth.uid(), v_auteur);
    end if;
    if new.responsable_id is distinct from old.responsable_id then
      insert into public.prestation_historique (entreprise_id, prestation_id, perimetre_id, type, ancien, nouveau,
                                                auteur_id, auteur_nom)
      values (new.entreprise_id, new.id, new.perimetre_id, 'RESPONSABLE', old.responsable_nom, new.responsable_nom,
              auth.uid(), v_auteur);
    end if;
  end if;

  perform app.rpc_de_confiance(false);
  return null;
end;
$$;

create trigger prestations_avant before insert or update on public.prestations
  for each row execute function app.tg_prestations_avant();
create trigger prestations_versionnement before insert or update on public.prestations
  for each row execute function app.tg_versionnement();
create trigger prestations_apres after insert or update on public.prestations
  for each row execute function app.tg_prestations_apres();
create trigger audit_prestations after insert or update or delete on public.prestations
  for each row execute function app.tg_audit();
create trigger prestation_historique_versionnement before insert or update on public.prestation_historique
  for each row execute function app.tg_versionnement();

alter table public.prestations enable row level security;
create policy prestations_lecture on public.prestations for select to authenticated
  using (app.peut(entreprise_id, 'services.prestations', 'prestations.view', perimetre_id));
create policy prestations_ajout on public.prestations for insert to authenticated
  with check (app.peut(entreprise_id, 'services.prestations', 'prestations.create', perimetre_id));
create policy prestations_modification on public.prestations for update to authenticated
  using (app.peut(entreprise_id, 'services.prestations', 'prestations.update', perimetre_id)
         or app.peut(entreprise_id, 'services.prestations', 'prestations.cancel', perimetre_id))
  with check (app.peut(entreprise_id, 'services.prestations', 'prestations.update', perimetre_id)
              or app.peut(entreprise_id, 'services.prestations', 'prestations.cancel', perimetre_id));

alter table public.prestation_historique enable row level security;
create policy prestation_historique_lecture on public.prestation_historique for select to authenticated
  using (app.peut(entreprise_id, 'services.prestations', 'prestations.view', perimetre_id));

revoke all on public.prestations, public.prestation_historique from anon, authenticated;
grant select on public.prestations, public.prestation_historique to authenticated;
grant insert (id, entreprise_id, perimetre_id, contact_id, titre, description, lignes, remise, statut, priorite,
              debut_prevu, echeance_jour, echeance_heure, livraison_requise, duree_minutes, responsable_id, lieu, note)
  on public.prestations to authenticated;
-- Pas de suppression : on annule (avec motif), l'historique reste.
grant update (contact_id, titre, description, lignes, remise, statut, priorite, debut_prevu, echeance_jour,
              echeance_heure, livraison_requise, duree_minutes, responsable_id, lieu, note, motif_report,
              motif_annulation)
  on public.prestations to authenticated;
grant all on public.prestations, public.prestation_historique to service_role;

-- -----------------------------------------------------------------------------
-- 4. Synchronisation (l'historique est en lecture seule, écrit par le serveur)
-- -----------------------------------------------------------------------------

insert into app.sync_tables (table_name, colonnes_creation, colonnes_modification) values
  ('services_catalogue',
   array['entreprise_id', 'nom', 'categorie', 'description', 'prix', 'unite', 'duree_minutes', 'icone', 'ordre'],
   array['nom', 'categorie', 'description', 'prix', 'unite', 'duree_minutes', 'icone', 'ordre', 'est_actif']),
  ('prestations',
   array['entreprise_id', 'perimetre_id', 'contact_id', 'titre', 'description', 'lignes', 'remise', 'statut',
         'priorite', 'debut_prevu', 'echeance_jour', 'echeance_heure', 'livraison_requise', 'duree_minutes',
         'responsable_id', 'lieu', 'note'],
   array['contact_id', 'titre', 'description', 'lignes', 'remise', 'statut', 'priorite', 'debut_prevu',
         'echeance_jour', 'echeance_heure', 'livraison_requise', 'duree_minutes', 'responsable_id', 'lieu', 'note',
         'motif_report', 'motif_annulation']),
  ('prestation_historique', array[]::text[], array[]::text[]);
