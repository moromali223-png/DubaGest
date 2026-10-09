-- =============================================================================
-- DÉPENSES — ÉTAPE 2 : DÉPENSES COURANTES, BÉNÉFICIAIRE, PERMISSIONS
--
-- Une dépense courante est un MODÈLE (loyer, électricité, carburant…) avec une
-- fréquence et une prochaine échéance. Elle n'est jamais comptée comme payée
-- d'elle-même : payer une échéance = enregistrer une dépense normale (montant
-- réel) portant [courante_id] et [echeance_prevue]. Tout le circuit financier
-- existant (somme à payer, paiement, caisse) reste celui de la dépense.
--
-- La prochaine échéance avance quand l'échéance est payée, et recule si cette
-- dépense est annulée : rien n'est perdu, rien n'est compté deux fois.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Permissions : annuler, gérer les dépenses courantes
-- -----------------------------------------------------------------------------

insert into public.permissions (code, description) values
  ('expenses.cancel', 'Annuler une dépense (avec motif, sans effacement)'),
  ('expenses.recurring', 'Gérer les dépenses courantes');

-- Continuité : qui pouvait modifier (et donc annuler) garde ces droits.
insert into public.roles_permissions (role_code, permission_code)
select distinct rp.role_code, n.code
from public.roles_permissions rp
cross join (values ('expenses.cancel'), ('expenses.recurring')) as n(code)
where rp.permission_code = 'expenses.update'
on conflict do nothing;

insert into public.roles_permissions (role_code, permission_code)
values ('ADMINISTRATEUR', 'expenses.cancel'), ('ADMINISTRATEUR', 'expenses.recurring')
on conflict do nothing;

-- -----------------------------------------------------------------------------
-- 2. Catégories par défaut, pour toutes les activités
-- -----------------------------------------------------------------------------

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
    ('COMMUNICATION', 6), ('ENTRETIEN', 7), ('TAXES', 8),
    ('CARBURANT', 9), ('EAU', 10), ('INTERNET', 11), ('REPARATION', 12), ('NETTOYAGE', 13),
    ('GARDIENNAGE', 14), ('LIVRAISON', 15), ('FRAIS_BANCAIRES', 16), ('ASSURANCE', 17),
    ('AUTRE', 99)
  ) as c(code, ordre)
  on conflict (entreprise_id, code) do nothing;
$$;

select app.creer_categories_depenses(id) from public.entreprises;

-- -----------------------------------------------------------------------------
-- 3. Échéances : calcul commun (serveur ; l'application fait le même)
-- -----------------------------------------------------------------------------

-- Première échéance strictement après [p_apres], comptée depuis [p_debut]
-- (pas de dérive : le 31 janvier mensuel donne 28 février puis 31 mars).
create or replace function app.echeance_suivante(
  p_debut date, p_periode text, p_intervalle integer, p_apres date
)
returns date
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_pas interval;
  v_k integer;
  v_date date;
begin
  if p_apres < p_debut then
    return p_debut;
  end if;
  v_pas := case p_periode
    when 'JOUR' then interval '1 day'
    when 'SEMAINE' then interval '7 days'
    when 'MOIS' then interval '1 month'
    else interval '1 year'
  end * p_intervalle;
  v_k := case p_periode
    when 'JOUR' then (p_apres - p_debut) / p_intervalle
    when 'SEMAINE' then (p_apres - p_debut) / (7 * p_intervalle)
    when 'MOIS' then ((extract(year from age(p_apres, p_debut)) * 12
                       + extract(month from age(p_apres, p_debut)))::integer) / p_intervalle
    else extract(year from age(p_apres, p_debut))::integer / p_intervalle
  end;
  loop
    v_date := (p_debut + v_pas * v_k)::date;
    exit when v_date > p_apres;
    v_k := v_k + 1;
  end loop;
  return v_date;
end;
$$;

-- -----------------------------------------------------------------------------
-- 4. Dépenses courantes
-- -----------------------------------------------------------------------------

create table public.depenses_courantes (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  activite_code text references public.activites (code),
  -- null : dépense de toute l'entreprise (siège, assurance…).
  perimetre_id uuid,
  categorie_id uuid not null,
  nom text not null check (char_length(trim(nom)) between 1 and 120),
  montant_prevu bigint not null check (montant_prevu > 0),
  -- FIXE : le montant prévu est payé ; VARIABLE : prévision, montant réel saisi.
  type_montant text not null default 'FIXE' check (type_montant in ('FIXE', 'VARIABLE')),
  -- Tous les [intervalle] [periode] : 1 JOUR, 2 SEMAINE, 3 MOIS, 1 AN…
  periode text not null check (periode in ('JOUR', 'SEMAINE', 'MOIS', 'AN')),
  intervalle integer not null default 1 check (intervalle between 1 and 366),
  date_debut date not null default current_date,
  prochaine_echeance date not null,
  mode_code text references public.modes_paiement (code),
  beneficiaire text check (char_length(beneficiaire) <= 120),
  note text check (char_length(note) <= 500),
  est_active boolean not null default true,
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id),
  foreign key (categorie_id, entreprise_id) references public.depense_categories (id, entreprise_id),
  foreign key (perimetre_id, entreprise_id) references public.perimetres (id, entreprise_id),
  check (prochaine_echeance >= date_debut)
);
create index depenses_courantes_sync_idx on public.depenses_courantes (entreprise_id, updated_at);

create or replace function app.tg_depenses_courantes_regles()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    perform app.exiger(app.peut(new.entreprise_id, 'finances.depenses', 'expenses.recurring', new.perimetre_id));
    new.activite_code := app.activite_du_perimetre(new.entreprise_id, new.perimetre_id, new.activite_code);
    new.prochaine_echeance := greatest(coalesce(new.prochaine_echeance, new.date_debut), new.date_debut);
    new.created_by := coalesce(auth.uid(), new.created_by);
  else
    perform app.exiger(app.peut(new.entreprise_id, 'finances.depenses', 'expenses.recurring', new.perimetre_id));
    -- Nouveau rythme : il repart de la prochaine échéance (pas de saut).
    if (new.periode, new.intervalle) is distinct from (old.periode, old.intervalle) then
      new.date_debut := new.prochaine_echeance;
    end if;
  end if;
  if not exists (
    select 1 from public.depense_categories c
    where c.id = new.categorie_id and c.entreprise_id = new.entreprise_id and c.est_active
  ) and (tg_op = 'INSERT' or new.categorie_id is distinct from old.categorie_id) then
    perform app.refuser('CATEGORIE_INVALIDE');
  end if;
  return new;
end;
$$;

create trigger depenses_courantes_regles before insert or update on public.depenses_courantes
  for each row execute function app.tg_depenses_courantes_regles();
create trigger depenses_courantes_versionnement before insert or update on public.depenses_courantes
  for each row execute function app.tg_versionnement();
create trigger audit_depenses_courantes after insert or update or delete on public.depenses_courantes
  for each row execute function app.tg_audit();

alter table public.depenses_courantes enable row level security;
create policy depenses_courantes_lecture on public.depenses_courantes for select to authenticated
  using (app.peut(entreprise_id, 'finances.depenses', 'expenses.view', perimetre_id));
create policy depenses_courantes_ajout on public.depenses_courantes for insert to authenticated
  with check (app.peut(entreprise_id, 'finances.depenses', 'expenses.recurring', perimetre_id));
create policy depenses_courantes_modification on public.depenses_courantes for update to authenticated
  using (app.peut(entreprise_id, 'finances.depenses', 'expenses.recurring', perimetre_id))
  with check (app.peut(entreprise_id, 'finances.depenses', 'expenses.recurring', perimetre_id));

revoke all on public.depenses_courantes from anon, authenticated;
grant select on public.depenses_courantes to authenticated;
grant insert (id, entreprise_id, activite_code, perimetre_id, categorie_id, nom, montant_prevu, type_montant,
              periode, intervalle, date_debut, prochaine_echeance, mode_code, beneficiaire, note)
  on public.depenses_courantes to authenticated;
-- Pas de suppression : on arrête (est_active = false), l'historique reste.
grant update (categorie_id, nom, montant_prevu, type_montant, periode, intervalle, prochaine_echeance, mode_code,
              beneficiaire, note, est_active)
  on public.depenses_courantes to authenticated;
grant all on public.depenses_courantes to service_role;

-- -----------------------------------------------------------------------------
-- 5. Dépenses : bénéficiaire libre, lien avec l'échéance payée
-- -----------------------------------------------------------------------------

alter table public.depenses
  add column beneficiaire text check (char_length(beneficiaire) <= 120),
  add column courante_id uuid,
  add column echeance_prevue date,
  add foreign key (courante_id, entreprise_id) references public.depenses_courantes (id, entreprise_id),
  add check ((courante_id is null) = (echeance_prevue is null));

-- Une échéance n'est payée qu'une fois (une dépense annulée la libère).
create unique index depenses_echeance_unique on public.depenses (courante_id, echeance_prevue)
  where courante_id is not null and statut <> 'ANNULEE';
create index depenses_courante_idx on public.depenses (courante_id) where courante_id is not null;

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
    if new.courante_id is not null and not exists (
      select 1 from public.depenses_courantes dc
      where dc.id = new.courante_id and dc.entreprise_id = new.entreprise_id and dc.deleted_at is null
    ) then
      perform app.refuser('DEPENSE_COURANTE_INVALIDE');
    end if;
    new.activite_code := app.activite_du_perimetre(new.entreprise_id, new.perimetre_id, new.activite_code);
    new.statut := 'ENREGISTREE';
    new.motif_annulation := null;
    new.annule_par := null;
    new.annule_le := null;
    new.created_by := coalesce(auth.uid(), new.created_by);
    return new;
  end if;

  if old.statut = 'ANNULEE' then
    perform app.refuser('DEPENSE_ANNULEE');
  end if;

  -- Annulation : droit propre (expenses.cancel).
  if new.statut = 'ANNULEE' then
    perform app.exiger(app.peut(new.entreprise_id, 'finances.depenses', 'expenses.cancel', new.perimetre_id));
    -- Ce qui a été payé s'annule d'abord (paiement inverse) : rien n'est effacé.
    if exists (select 1 from public.engagements e where e.id = old.id and e.montant_regle > 0) then
      perform app.refuser('DEPENSE_PAYEE');
    end if;
    new.annule_par := auth.uid();
    new.annule_le := now();
  end if;

  -- Modification : texte, catégorie, date, bénéficiaire.
  if (new.categorie_id, new.libelle, new.date_depense, new.reference, new.note, new.beneficiaire)
     is distinct from
     (old.categorie_id, old.libelle, old.date_depense, old.reference, old.note, old.beneficiaire) then
    perform app.exiger(app.peut(new.entreprise_id, 'finances.depenses', 'expenses.update', new.perimetre_id));
  end if;
  if new.categorie_id is distinct from old.categorie_id and not exists (
    select 1 from public.depense_categories c
    where c.id = new.categorie_id and c.entreprise_id = new.entreprise_id and c.est_active
  ) then
    perform app.refuser('CATEGORIE_INVALIDE');
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

    -- Échéance payée : la dépense courante passe à la suivante.
    if new.courante_id is not null then
      update public.depenses_courantes dc
      set prochaine_echeance = app.echeance_suivante(dc.date_debut, dc.periode, dc.intervalle, new.echeance_prevue)
      where dc.id = new.courante_id and dc.prochaine_echeance <= new.echeance_prevue;
    end if;
  else
    update public.engagements
    set libelle = new.libelle,
        statut = case when new.statut = 'ANNULEE' then 'ANNULE' else statut end,
        motif_annulation = case when new.statut = 'ANNULEE' then new.motif_annulation else motif_annulation end
    where id = new.id;

    -- Échéance payée puis annulée : elle redevient à payer.
    if new.statut = 'ANNULEE' and old.statut <> 'ANNULEE' and new.courante_id is not null then
      update public.depenses_courantes dc
      set prochaine_echeance = greatest(least(dc.prochaine_echeance, new.echeance_prevue), dc.date_debut)
      where dc.id = new.courante_id;
    end if;
  end if;

  perform app.rpc_de_confiance(false);
  return null;
end;
$$;

-- Annulation possible avec expenses.cancel seul.
drop policy depenses_modification on public.depenses;
create policy depenses_modification on public.depenses for update to authenticated
  using (app.peut(entreprise_id, 'finances.depenses', 'expenses.update', perimetre_id)
         or app.peut(entreprise_id, 'finances.depenses', 'expenses.cancel', perimetre_id))
  with check (app.peut(entreprise_id, 'finances.depenses', 'expenses.update', perimetre_id)
              or app.peut(entreprise_id, 'finances.depenses', 'expenses.cancel', perimetre_id));

grant insert (beneficiaire, courante_id, echeance_prevue) on public.depenses to authenticated;
grant update (beneficiaire) on public.depenses to authenticated;

-- -----------------------------------------------------------------------------
-- 6. Synchronisation
-- -----------------------------------------------------------------------------

update app.sync_tables
set colonnes_creation = colonnes_creation || array['beneficiaire', 'courante_id', 'echeance_prevue'],
    colonnes_modification = colonnes_modification || array['beneficiaire']
where table_name = 'depenses';

insert into app.sync_tables (table_name, colonnes_creation, colonnes_modification) values
  ('depenses_courantes',
   array['entreprise_id', 'activite_code', 'perimetre_id', 'categorie_id', 'nom', 'montant_prevu', 'type_montant',
         'periode', 'intervalle', 'date_debut', 'prochaine_echeance', 'mode_code', 'beneficiaire', 'note'],
   array['categorie_id', 'nom', 'montant_prevu', 'type_montant', 'periode', 'intervalle', 'prochaine_echeance',
         'mode_code', 'beneficiaire', 'note', 'est_active']);
