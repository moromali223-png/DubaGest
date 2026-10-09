-- =============================================================================
-- CAISSE — TRÉSORERIE : NATURE DES MOUVEMENTS, TRANSFERTS, AJUSTEMENTS, ÉCARTS
--
-- Pas de second système : un mouvement d'argent reste un PAIEMENT (entrée ou
-- sortie, par moyen d'argent, par boutique), et les espèces passent toujours
-- par la session de caisse. Cette étape ajoute :
--   • la NATURE des paiements qui ne règlent aucune somme due (apport,
--     retrait, transfert, remboursement, ajustement, solde initial, autre).
--     Les autres tirent leur origine de la somme réglée (vente, achat,
--     dépense, loyer…) : plus rien n'est deviné à partir d'un texte ;
--   • les TRANSFERTS (boutique → boutique, espèces → banque…) : une seule
--     ligne envoyée, les deux jambes créées dans la même transaction, jamais
--     comptées comme entrées ou sorties ; annulables d'un bloc ;
--   • les AJUSTEMENTS et soldes initiaux : droit propre, motif obligatoire ;
--   • la JUSTIFICATION obligatoire d'un écart à la clôture.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Permissions
-- -----------------------------------------------------------------------------

insert into public.permissions (code, description) values
  ('cash.transfer', 'Transférer de l''argent entre boutiques ou moyens d''argent'),
  ('cash.adjust', 'Corriger un solde (ajustement, solde initial) avec motif');

-- Transferts : administrateur et superviseur (pas le caissier, qui reste à sa
-- caisse) ; ajustements : l'administrateur seul.
insert into public.roles_permissions (role_code, permission_code)
select r.code, p.code
from public.roles r
cross join (values ('cash.transfer')) as p(code)
where r.code in ('ADMINISTRATEUR', 'SUPERVISEUR')
on conflict do nothing;

insert into public.roles_permissions (role_code, permission_code)
values ('ADMINISTRATEUR', 'cash.adjust')
on conflict do nothing;

-- -----------------------------------------------------------------------------
-- 2. Nature des paiements
-- -----------------------------------------------------------------------------

alter table public.paiements
  add column nature text check (nature in
    ('APPORT', 'RETRAIT', 'TRANSFERT', 'REMBOURSEMENT', 'AJUSTEMENT', 'SOLDE_INITIAL', 'AUTRE')),
  add column transfert_id uuid;

create index paiements_transfert_idx on public.paiements (transfert_id) where transfert_id is not null;

create or replace function app.tg_paiements_nature()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_origine public.paiements;
begin
  if new.annule_paiement_id is not null then
    -- L'inverse garde la nature de l'original (statistiques justes).
    select * into v_origine from public.paiements where id = new.annule_paiement_id;
    if v_origine.transfert_id is not null and not app.confiance() then
      perform app.refuser('TRANSFERT_LIE');
    end if;
    new.nature := v_origine.nature;
    new.transfert_id := v_origine.transfert_id;
    return new;
  end if;

  if new.transfert_id is not null or new.nature = 'TRANSFERT' then
    -- Seul un transfert crée ses deux jambes.
    if not app.confiance() then
      perform app.refuser('TRANSFERT_DIRECT_INTERDIT');
    end if;
    new.nature := 'TRANSFERT';
  end if;

  if new.nature is not null and jsonb_array_length(new.affectations) > 0 then
    perform app.refuser('NATURE_INCOMPATIBLE');
  end if;

  if new.nature in ('AJUSTEMENT', 'SOLDE_INITIAL') then
    perform app.exiger(app.peut(new.entreprise_id, 'finances.caisse', 'cash.adjust', new.perimetre_id));
    if char_length(trim(coalesce(new.note, ''))) = 0 then
      perform app.refuser('MOTIF_REQUIS');
    end if;
  end if;
  return new;
end;
$$;

-- « paiements_nature » s'exécute après « paiements_avant » (ordre alphabétique).
create trigger paiements_nature before insert on public.paiements
  for each row execute function app.tg_paiements_nature();

grant insert (nature) on public.paiements to authenticated;

-- -----------------------------------------------------------------------------
-- 3. Transferts
-- -----------------------------------------------------------------------------

create table public.transferts_tresorerie (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  -- null : niveau entreprise (siège, banque de l'entreprise).
  perimetre_source_id uuid,
  perimetre_dest_id uuid,
  mode_source text not null references public.modes_paiement (code),
  mode_dest text not null references public.modes_paiement (code),
  montant bigint not null check (montant > 0),
  -- Sessions de caisse des jambes en espèces.
  session_source_id uuid,
  session_dest_id uuid,
  -- Identifiants des deux jambes, connus d'avance par l'appareil.
  sortie_id uuid not null unique,
  entree_id uuid not null unique,
  date_transfert timestamptz not null default now(),
  motif text check (char_length(motif) <= 300),
  statut text not null default 'VALIDE' check (statut in ('VALIDE', 'ANNULE')),
  motif_annulation text check (char_length(motif_annulation) <= 500),
  annulation_sortie_id uuid unique,
  annulation_entree_id uuid unique,
  annule_par uuid references public.profiles (id) on delete set null,
  annule_le timestamptz,
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id),
  foreign key (perimetre_source_id, entreprise_id) references public.perimetres (id, entreprise_id),
  foreign key (perimetre_dest_id, entreprise_id) references public.perimetres (id, entreprise_id),
  foreign key (session_source_id, entreprise_id) references public.caisse_sessions (id, entreprise_id),
  foreign key (session_dest_id, entreprise_id) references public.caisse_sessions (id, entreprise_id),
  check (sortie_id <> entree_id),
  check ((perimetre_source_id, mode_source) is distinct from (perimetre_dest_id, mode_dest)),
  check (statut = 'VALIDE' or (annulation_sortie_id is not null and annulation_entree_id is not null))
);
create index transferts_tresorerie_sync_idx on public.transferts_tresorerie (entreprise_id, updated_at);

create or replace function app.tg_transferts_avant()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    perform app.exiger(app.peut(new.entreprise_id, 'finances.caisse', 'cash.transfer', new.perimetre_source_id)
                       and app.peut(new.entreprise_id, 'finances.caisse', 'cash.transfer', new.perimetre_dest_id));
    if new.date_transfert > now() + interval '1 day' then
      perform app.refuser('DATE_INVALIDE');
    end if;
    new.statut := 'VALIDE';
    new.motif_annulation := null;
    new.annulation_sortie_id := null;
    new.annulation_entree_id := null;
    new.annule_par := null;
    new.annule_le := null;
    new.created_by := coalesce(auth.uid(), new.created_by);
    return new;
  end if;

  -- Seule modification : l'annulation, une seule fois.
  perform app.exiger(app.peut(new.entreprise_id, 'finances.caisse', 'cash.transfer', new.perimetre_source_id)
                     and app.peut(new.entreprise_id, 'finances.caisse', 'cash.transfer', new.perimetre_dest_id));
  if old.statut = 'ANNULE' then
    perform app.refuser('TRANSFERT_ANNULE');
  end if;
  if new.statut <> 'ANNULE' then
    perform app.refuser('ANNULATION_REQUISE');
  end if;
  if char_length(trim(coalesce(new.motif_annulation, ''))) = 0 then
    perform app.refuser('MOTIF_REQUIS');
  end if;
  new.annule_par := auth.uid();
  new.annule_le := now();
  return new;
end;
$$;

create or replace function app.tg_transferts_apres()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_note text;
begin
  perform app.rpc_de_confiance(true);
  if tg_op = 'INSERT' then
    v_note := coalesce(nullif(trim(new.motif), ''), 'Transfert');
    -- Sortie d'abord : en espèces, le solde de la caisse source est vérifié.
    insert into public.paiements (id, entreprise_id, perimetre_id, sens, montant, mode_code, date_paiement,
                                  note, session_id, nature, transfert_id)
    values (new.sortie_id, new.entreprise_id, new.perimetre_source_id, 'SORTIE', new.montant, new.mode_source,
            new.date_transfert, v_note, new.session_source_id, 'TRANSFERT', new.id);
    insert into public.paiements (id, entreprise_id, perimetre_id, sens, montant, mode_code, date_paiement,
                                  note, session_id, nature, transfert_id)
    values (new.entree_id, new.entreprise_id, new.perimetre_dest_id, 'ENTREE', new.montant, new.mode_dest,
            new.date_transfert, v_note, new.session_dest_id, 'TRANSFERT', new.id);
  elsif new.statut = 'ANNULE' and old.statut <> 'ANNULE' then
    -- Entrée reprise d'abord (l'argent doit encore être là), puis sortie rendue.
    insert into public.paiements (id, entreprise_id, sens, montant, mode_code, annule_paiement_id)
    values (new.annulation_entree_id, new.entreprise_id, 'SORTIE', new.montant, new.mode_dest, new.entree_id);
    insert into public.paiements (id, entreprise_id, sens, montant, mode_code, annule_paiement_id)
    values (new.annulation_sortie_id, new.entreprise_id, 'ENTREE', new.montant, new.mode_source, new.sortie_id);
  end if;
  perform app.rpc_de_confiance(false);
  return null;
end;
$$;

create trigger transferts_avant before insert or update on public.transferts_tresorerie
  for each row execute function app.tg_transferts_avant();
create trigger transferts_versionnement before insert or update on public.transferts_tresorerie
  for each row execute function app.tg_versionnement();
create trigger transferts_apres after insert or update on public.transferts_tresorerie
  for each row execute function app.tg_transferts_apres();
create trigger audit_transferts_tresorerie after insert or update or delete on public.transferts_tresorerie
  for each row execute function app.tg_audit();

alter table public.transferts_tresorerie enable row level security;
-- Visible depuis l'une ou l'autre boutique.
create policy transferts_lecture on public.transferts_tresorerie for select to authenticated
  using (app.peut(entreprise_id, 'finances.caisse', 'cash.view', perimetre_source_id)
         or app.peut(entreprise_id, 'finances.caisse', 'cash.view', perimetre_dest_id));
create policy transferts_ajout on public.transferts_tresorerie for insert to authenticated
  with check (app.peut(entreprise_id, 'finances.caisse', 'cash.transfer', perimetre_source_id)
              and app.peut(entreprise_id, 'finances.caisse', 'cash.transfer', perimetre_dest_id));
create policy transferts_annulation on public.transferts_tresorerie for update to authenticated
  using (app.peut(entreprise_id, 'finances.caisse', 'cash.transfer', perimetre_source_id)
         and app.peut(entreprise_id, 'finances.caisse', 'cash.transfer', perimetre_dest_id))
  with check (app.peut(entreprise_id, 'finances.caisse', 'cash.transfer', perimetre_source_id)
              and app.peut(entreprise_id, 'finances.caisse', 'cash.transfer', perimetre_dest_id));

revoke all on public.transferts_tresorerie from anon, authenticated;
grant select on public.transferts_tresorerie to authenticated;
grant insert (id, entreprise_id, perimetre_source_id, perimetre_dest_id, mode_source, mode_dest, montant,
              session_source_id, session_dest_id, sortie_id, entree_id, date_transfert, motif)
  on public.transferts_tresorerie to authenticated;
grant update (statut, motif_annulation, annulation_sortie_id, annulation_entree_id)
  on public.transferts_tresorerie to authenticated;
grant all on public.transferts_tresorerie to service_role;

-- -----------------------------------------------------------------------------
-- 4. Clôture : un écart se justifie
-- -----------------------------------------------------------------------------

alter table public.caisse_sessions
  add column motif_ecart text check (motif_ecart in
    ('RENDU_MONNAIE', 'DEPENSE_NON_ENREGISTREE', 'ERREUR_COMPTAGE', 'AUTRE'));

create or replace function app.tg_caisse_sessions_regles()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caisse public.caisses;
begin
  if tg_op = 'INSERT' then
    select * into v_caisse from public.caisses
    where id = new.caisse_id and entreprise_id = new.entreprise_id;
    perform app.exiger(app.peut(new.entreprise_id, 'finances.caisse', 'cash.open', v_caisse.perimetre_id)
                       and v_caisse.id is not null);
    if v_caisse.id is null then
      perform app.refuser('CAISSE_INTROUVABLE');
    end if;
    if not v_caisse.est_active then
      perform app.refuser('CAISSE_INACTIVE');
    end if;
    if exists (select 1 from public.caisse_sessions s where s.caisse_id = new.caisse_id and s.statut = 'OUVERTE') then
      perform app.refuser('CAISSE_DEJA_OUVERTE');
    end if;
    new.perimetre_id := v_caisse.perimetre_id;
    new.statut := 'OUVERTE';
    new.ouverte_par := coalesce(auth.uid(), new.ouverte_par);
    new.ouverte_le := now();
    new.fermee_par := null;
    new.fermee_le := null;
    new.solde_theorique := null;
    new.solde_reel := null;
    new.ecart := null;
    new.note_cloture := null;
    new.motif_ecart := null;
    return new;
  end if;

  -- Seule modification possible : la clôture, une seule fois.
  perform app.exiger(app.peut(new.entreprise_id, 'finances.caisse', 'cash.close', new.perimetre_id));
  if old.statut = 'FERMEE' then
    perform app.refuser('CAISSE_FERMEE');
  end if;
  if new.statut <> 'FERMEE' then
    perform app.refuser('SESSION_CLOTURE_REQUISE');
  end if;
  if new.solde_reel is null then
    perform app.refuser('SOLDE_REEL_REQUIS');
  end if;
  new.solde_theorique := app.solde_session(old.id);
  new.ecart := new.solde_reel - new.solde_theorique;
  if new.ecart <> 0 then
    -- Le solde n'est jamais corrigé en silence : l'écart reste, expliqué.
    if char_length(trim(coalesce(new.note_cloture, ''))) = 0 then
      perform app.refuser('JUSTIFICATION_ECART_REQUISE', jsonb_build_object('ecart', new.ecart));
    end if;
    new.motif_ecart := coalesce(new.motif_ecart, 'AUTRE');
  else
    new.motif_ecart := null;
  end if;
  new.fermee_par := auth.uid();
  new.fermee_le := now();
  return new;
end;
$$;

grant update (motif_ecart) on public.caisse_sessions to authenticated;

-- -----------------------------------------------------------------------------
-- 5. Synchronisation
-- -----------------------------------------------------------------------------

update app.sync_tables
set colonnes_creation = colonnes_creation || array['nature']
where table_name = 'paiements';

update app.sync_tables
set colonnes_modification = colonnes_modification || array['motif_ecart']
where table_name = 'caisse_sessions';

insert into app.sync_tables (table_name, colonnes_creation, colonnes_modification) values
  ('transferts_tresorerie',
   array['entreprise_id', 'perimetre_source_id', 'perimetre_dest_id', 'mode_source', 'mode_dest', 'montant',
         'session_source_id', 'session_dest_id', 'sortie_id', 'entree_id', 'date_transfert', 'motif'],
   array['statut', 'motif_annulation', 'annulation_sortie_id', 'annulation_entree_id']);
