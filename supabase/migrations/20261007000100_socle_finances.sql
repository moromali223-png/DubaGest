-- =============================================================================
-- SOCLE COMMUN — ÉTAPE 3 : NOYAU FINANCIER
--
--   engagements           « à recevoir » / « à payer » (ce qui est dû)
--   paiements             argent réellement reçu ou versé (jamais modifié)
--   paiement_affectations quelle part d'un paiement règle quel engagement
--   caisses               une caisse par boutique / agence
--   caisse_sessions       ouverture → clôture, avec écart de caisse
--   caisse_mouvements     entrées / sorties d'espèces (jamais modifiées)
--
-- Règles :
-- - Montants en entiers, dans la devise de l'entreprise (FCFA sans centimes).
-- - Le reste dû n'est jamais saisi : total − somme des affectations valides.
-- - Un paiement n'est jamais modifié ni supprimé : on l'annule par un
--   paiement inverse, qui génère aussi le mouvement de caisse inverse.
-- - Un paiement est UNE ligne insérée (hors-ligne compris) ; ses affectations
--   et son mouvement de caisse sont créés par trigger dans la même
--   transaction : tout est appliqué, ou rien. L'idempotence vient de
--   sync_operations (rejeu sans doublon).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Modules : une catégorie FINANCES, regroupée dans l'onglet Finances
-- -----------------------------------------------------------------------------

alter table public.modules drop constraint modules_categorie_check;
alter table public.modules add constraint modules_categorie_check
  check (categorie in ('ADMIN', 'COMMUN', 'METIER', 'FINANCES'));

insert into public.modules (code, libelle, activite_code, permission_acces, ordre, categorie) values
  ('finances.creances',  'À recevoir / À payer', null, 'receivables.view', 7, 'FINANCES'),
  ('finances.paiements', 'Paiements',            null, 'payments.view',    8, 'FINANCES'),
  ('finances.caisse',    'Caisse',               null, 'cash.view',        9, 'FINANCES');

insert into public.plan_modules (plan_code, module_code)
select p.code, m.code
from public.plans p
cross join (values ('finances.creances'), ('finances.paiements'), ('finances.caisse')) as m(code);

-- La caisse devient commune à toutes les activités (boutique ou agence).
delete from public.plan_modules where module_code = 'commerce.caisse';
delete from public.modules where code = 'commerce.caisse';

-- -----------------------------------------------------------------------------
-- 2. Outils communs
-- -----------------------------------------------------------------------------

-- Refus de droits (42501) levé AVANT toute règle métier, pour ne rien révéler
-- à un utilisateur non autorisé. Sans effet pour le serveur lui-même (seed).
create or replace function app.exiger(p_autorise boolean)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if not coalesce(p_autorise, false) and (select auth.role()) in ('authenticated', 'anon') then
    raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
  end if;
end;
$$;

-- Activité du site, ou contrôle de cohérence activité ↔ site.
create or replace function app.activite_du_perimetre(
  p_entreprise_id uuid, p_perimetre_id uuid, p_activite text
)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_activite text;
begin
  if p_perimetre_id is null then
    return p_activite;
  end if;
  select activite_code into v_activite
  from public.perimetres where id = p_perimetre_id and entreprise_id = p_entreprise_id;
  if not found then
    perform app.refuser('PERIMETRE_INTROUVABLE');
  end if;
  if p_activite is not null and p_activite <> v_activite then
    perform app.refuser('ACTIVITE_PERIMETRE_INCOHERENTE');
  end if;
  return v_activite;
end;
$$;

create table public.modes_paiement (
  code text primary key check (code ~ '^[A-Z_]+$'),
  ordre integer not null,
  -- Les espèces passent par la caisse ; les autres modes non.
  mouvement_caisse boolean not null default false,
  est_actif boolean not null default true
);

insert into public.modes_paiement (code, ordre, mouvement_caisse) values
  ('ESPECES', 1, true),
  ('MOBILE_MONEY', 2, false),
  ('CARTE', 3, false),
  ('VIREMENT', 4, false),
  ('CHEQUE', 5, false),
  ('AUTRE', 6, false);

alter table public.modes_paiement enable row level security;
create policy modes_paiement_lecture on public.modes_paiement for select to authenticated using (true);
revoke all on public.modes_paiement from anon, authenticated;
grant select on public.modes_paiement to authenticated;
grant all on public.modes_paiement to service_role;

-- -----------------------------------------------------------------------------
-- 3. Engagements : à recevoir / à payer
-- -----------------------------------------------------------------------------

create table public.engagements (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  activite_code text references public.activites (code),
  perimetre_id uuid,
  sens text not null check (sens in ('A_RECEVOIR', 'A_PAYER')),
  contact_id uuid,
  libelle text not null check (char_length(trim(libelle)) between 1 and 200),
  montant_total bigint not null check (montant_total > 0),
  -- Calculé par le serveur à partir des affectations de paiements valides.
  montant_regle bigint not null default 0 check (montant_regle >= 0),
  date_engagement date not null default current_date,
  echeance date,
  -- Les modules métier (ventes, loyers…) créeront leurs propres engagements.
  origine_type text not null default 'MANUEL'
    check (origine_type in ('MANUEL', 'VENTE', 'PRESTATION', 'LOYER', 'DEPENSE')),
  origine_id uuid,
  statut text not null default 'OUVERT' check (statut in ('OUVERT', 'ANNULE')),
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
  check (montant_regle <= montant_total)
);

create index engagements_sync_idx on public.engagements (entreprise_id, updated_at);
create index engagements_suivi_idx on public.engagements (entreprise_id, sens, statut, echeance);
create index engagements_contact_idx on public.engagements (contact_id);

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
    if (select auth.role()) = 'authenticated' then
      new.origine_type := 'MANUEL';
      new.origine_id := null;
      new.created_by := auth.uid();
    end if;
    return new;
  end if;

  -- Recalcul du réglé par le serveur : aucun champ saisi ne change.
  if (new.contact_id, new.libelle, new.montant_total, new.echeance, new.statut, new.motif_annulation)
     is not distinct from
     (old.contact_id, old.libelle, old.montant_total, old.echeance, old.statut, old.motif_annulation) then
    return new;
  end if;

  perform app.exiger(app.peut(new.entreprise_id, 'finances.creances', 'receivables.manage', new.perimetre_id));
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
    -- Annuler d'abord les paiements : l'argent reçu ne disparaît jamais en silence.
    if old.montant_regle > 0 then
      perform app.refuser('ENGAGEMENT_REGLE');
    end if;
    new.annule_par := auth.uid();
    new.annule_le := now();
  end if;
  return new;
end;
$$;

create trigger engagements_regles before insert or update on public.engagements
  for each row execute function app.tg_engagements_regles();
create trigger engagements_versionnement before insert or update on public.engagements
  for each row execute function app.tg_versionnement();
create trigger audit_engagements after insert or update or delete on public.engagements
  for each row execute function app.tg_audit();

alter table public.engagements enable row level security;
create policy engagements_lecture on public.engagements for select to authenticated
  using (app.peut(entreprise_id, 'finances.creances', 'receivables.view', perimetre_id));
create policy engagements_ajout on public.engagements for insert to authenticated
  with check (app.peut(entreprise_id, 'finances.creances', 'receivables.manage', perimetre_id));
create policy engagements_modification on public.engagements for update to authenticated
  using (app.peut(entreprise_id, 'finances.creances', 'receivables.manage', perimetre_id))
  with check (app.peut(entreprise_id, 'finances.creances', 'receivables.manage', perimetre_id));

revoke all on public.engagements from anon, authenticated;
grant select on public.engagements to authenticated;
grant insert (id, entreprise_id, activite_code, perimetre_id, sens, contact_id, libelle,
              montant_total, date_engagement, echeance)
  on public.engagements to authenticated;
grant update (contact_id, libelle, montant_total, echeance, statut, motif_annulation)
  on public.engagements to authenticated;
grant all on public.engagements to service_role;

-- -----------------------------------------------------------------------------
-- 4. Caisses et sessions
-- -----------------------------------------------------------------------------

create table public.caisses (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  perimetre_id uuid not null,
  nom text not null check (char_length(trim(nom)) between 1 and 80),
  est_active boolean not null default true,
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id),
  foreign key (perimetre_id, entreprise_id) references public.perimetres (id, entreprise_id)
);
create index caisses_sync_idx on public.caisses (entreprise_id, updated_at);

create table public.caisse_sessions (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  caisse_id uuid not null,
  perimetre_id uuid not null,
  statut text not null default 'OUVERTE' check (statut in ('OUVERTE', 'FERMEE')),
  solde_initial bigint not null default 0 check (solde_initial >= 0),
  ouverte_par uuid default auth.uid() references public.profiles (id) on delete set null,
  ouverte_le timestamptz not null default now(),
  fermee_par uuid references public.profiles (id) on delete set null,
  fermee_le timestamptz,
  -- À la clôture : solde attendu, solde compté et écart (compté − attendu).
  solde_theorique bigint,
  solde_reel bigint check (solde_reel >= 0),
  ecart bigint,
  note_cloture text check (char_length(note_cloture) <= 500),
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id),
  foreign key (caisse_id, entreprise_id) references public.caisses (id, entreprise_id),
  foreign key (perimetre_id, entreprise_id) references public.perimetres (id, entreprise_id),
  check (statut = 'OUVERTE' or (fermee_le is not null and solde_reel is not null))
);
create index caisse_sessions_sync_idx on public.caisse_sessions (entreprise_id, updated_at);
-- Une seule session ouverte par caisse (protège aussi deux ouvertures hors-ligne).
create unique index caisse_sessions_une_ouverte on public.caisse_sessions (caisse_id)
  where statut = 'OUVERTE';

create or replace function app.tg_caisses_regles()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.exiger(app.peut(new.entreprise_id, 'finances.caisse', 'entreprise.manage', new.perimetre_id));
  if tg_op = 'UPDATE' and old.est_active and not new.est_active
     and exists (select 1 from public.caisse_sessions s where s.caisse_id = old.id and s.statut = 'OUVERTE') then
    perform app.refuser('CAISSE_OUVERTE');
  end if;
  return new;
end;
$$;

create trigger caisses_regles before insert or update on public.caisses
  for each row execute function app.tg_caisses_regles();
create trigger caisses_versionnement before insert or update on public.caisses
  for each row execute function app.tg_versionnement();
create trigger audit_caisses after insert or update or delete on public.caisses
  for each row execute function app.tg_audit();

create table public.caisse_mouvements (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  session_id uuid not null,
  caisse_id uuid not null,
  perimetre_id uuid not null,
  -- ENCAISSEMENT / DECAISSEMENT : créés par un paiement en espèces.
  -- DEPOT / RETRAIT : saisis à la main (apport, retrait vers la banque…).
  type text not null check (type in ('ENCAISSEMENT', 'DECAISSEMENT', 'DEPOT', 'RETRAIT')),
  sens text not null check (sens in ('ENTREE', 'SORTIE')),
  montant bigint not null check (montant > 0),
  paiement_id uuid unique,
  motif text check (char_length(motif) <= 300),
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  foreign key (session_id, entreprise_id) references public.caisse_sessions (id, entreprise_id),
  check ((type in ('ENCAISSEMENT', 'DECAISSEMENT')) = (paiement_id is not null)),
  check (sens = case when type in ('ENCAISSEMENT', 'DEPOT') then 'ENTREE' else 'SORTIE' end)
);
create index caisse_mouvements_sync_idx on public.caisse_mouvements (entreprise_id, updated_at);
create index caisse_mouvements_session_idx on public.caisse_mouvements (session_id);

-- Solde courant d'une session : initial + entrées − sorties.
create or replace function app.solde_session(p_session_id uuid)
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select s.solde_initial + coalesce((
    select sum(case when m.sens = 'ENTREE' then m.montant else -m.montant end)
    from public.caisse_mouvements m where m.session_id = s.id
  ), 0)
  from public.caisse_sessions s where s.id = p_session_id;
$$;

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
  new.fermee_par := auth.uid();
  new.fermee_le := now();
  return new;
end;
$$;

create trigger caisse_sessions_regles before insert or update on public.caisse_sessions
  for each row execute function app.tg_caisse_sessions_regles();
create trigger caisse_sessions_versionnement before insert or update on public.caisse_sessions
  for each row execute function app.tg_versionnement();
create trigger audit_caisse_sessions after insert or update or delete on public.caisse_sessions
  for each row execute function app.tg_audit();

create or replace function app.tg_caisse_mouvements_regles()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session public.caisse_sessions;
  v_solde bigint;
begin
  -- Verrou : deux sorties simultanées ne peuvent pas vider deux fois la caisse.
  select * into v_session from public.caisse_sessions
  where id = new.session_id and entreprise_id = new.entreprise_id
  for update;
  perform app.exiger(app.peut(new.entreprise_id, 'finances.caisse', 'cash.move', v_session.perimetre_id)
                     and v_session.id is not null);
  if v_session.id is null then
    perform app.refuser('SESSION_INTROUVABLE');
  end if;
  if v_session.statut <> 'OUVERTE' then
    perform app.refuser('CAISSE_FERMEE');
  end if;
  if new.paiement_id is null and new.type in ('ENCAISSEMENT', 'DECAISSEMENT') then
    perform app.refuser('TYPE_MOUVEMENT_INVALIDE');
  end if;

  new.caisse_id := v_session.caisse_id;
  new.perimetre_id := v_session.perimetre_id;
  new.sens := case when new.type in ('ENCAISSEMENT', 'DEPOT') then 'ENTREE' else 'SORTIE' end;
  new.created_by := coalesce(auth.uid(), new.created_by);

  if new.sens = 'SORTIE' then
    v_solde := app.solde_session(v_session.id);
    if v_solde < new.montant then
      perform app.refuser('SOLDE_CAISSE_INSUFFISANT', jsonb_build_object('solde', v_solde));
    end if;
  end if;
  return new;
end;
$$;

create trigger caisse_mouvements_regles before insert on public.caisse_mouvements
  for each row execute function app.tg_caisse_mouvements_regles();
create trigger caisse_mouvements_versionnement before insert or update on public.caisse_mouvements
  for each row execute function app.tg_versionnement();
create trigger audit_caisse_mouvements after insert or update or delete on public.caisse_mouvements
  for each row execute function app.tg_audit();

alter table public.caisses enable row level security;
create policy caisses_lecture on public.caisses for select to authenticated
  using (app.peut(entreprise_id, 'finances.caisse', 'cash.view', perimetre_id));
create policy caisses_ajout on public.caisses for insert to authenticated
  with check (app.peut(entreprise_id, 'finances.caisse', 'entreprise.manage', perimetre_id));
create policy caisses_modification on public.caisses for update to authenticated
  using (app.peut(entreprise_id, 'finances.caisse', 'entreprise.manage', perimetre_id))
  with check (app.peut(entreprise_id, 'finances.caisse', 'entreprise.manage', perimetre_id));

alter table public.caisse_sessions enable row level security;
create policy caisse_sessions_lecture on public.caisse_sessions for select to authenticated
  using (app.peut(entreprise_id, 'finances.caisse', 'cash.view', perimetre_id));
create policy caisse_sessions_ouverture on public.caisse_sessions for insert to authenticated
  with check (app.peut(entreprise_id, 'finances.caisse', 'cash.open', perimetre_id));
create policy caisse_sessions_cloture on public.caisse_sessions for update to authenticated
  using (app.peut(entreprise_id, 'finances.caisse', 'cash.close', perimetre_id))
  with check (app.peut(entreprise_id, 'finances.caisse', 'cash.close', perimetre_id));

alter table public.caisse_mouvements enable row level security;
create policy caisse_mouvements_lecture on public.caisse_mouvements for select to authenticated
  using (app.peut(entreprise_id, 'finances.caisse', 'cash.view', perimetre_id));
create policy caisse_mouvements_ajout on public.caisse_mouvements for insert to authenticated
  with check (app.peut(entreprise_id, 'finances.caisse', 'cash.move', perimetre_id));

revoke all on public.caisses, public.caisse_sessions, public.caisse_mouvements from anon, authenticated;
grant select on public.caisses, public.caisse_sessions, public.caisse_mouvements to authenticated;
grant insert (id, entreprise_id, perimetre_id, nom) on public.caisses to authenticated;
grant update (nom, est_active) on public.caisses to authenticated;
grant insert (id, entreprise_id, caisse_id, solde_initial) on public.caisse_sessions to authenticated;
grant update (statut, solde_reel, note_cloture) on public.caisse_sessions to authenticated;
grant insert (id, entreprise_id, session_id, type, montant, motif) on public.caisse_mouvements to authenticated;
grant all on public.caisses, public.caisse_sessions, public.caisse_mouvements to service_role;

-- -----------------------------------------------------------------------------
-- 5. Paiements et affectations
-- -----------------------------------------------------------------------------

create table public.paiements (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  activite_code text references public.activites (code),
  perimetre_id uuid,
  sens text not null check (sens in ('ENTREE', 'SORTIE')),
  montant bigint not null check (montant > 0),
  mode_code text not null references public.modes_paiement (code),
  -- Date réelle du paiement (peut précéder la synchronisation).
  date_paiement timestamptz not null default now(),
  contact_id uuid,
  reference text check (char_length(reference) <= 100),
  note text check (char_length(note) <= 500),
  -- Session de caisse : un paiement en espèces y crée un mouvement.
  session_id uuid,
  -- Affectations demandées [{id, engagement_id, montant}] : figées avec le
  -- paiement, matérialisées dans paiement_affectations par trigger.
  affectations jsonb not null default '[]' check (jsonb_typeof(affectations) = 'array'),
  -- Renseigné sur le paiement inverse : il annule ce paiement d'origine.
  annule_paiement_id uuid unique,
  statut text not null default 'VALIDE' check (statut in ('VALIDE', 'ANNULE')),
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
  foreign key (session_id, entreprise_id) references public.caisse_sessions (id, entreprise_id),
  foreign key (annule_paiement_id, entreprise_id) references public.paiements (id, entreprise_id)
);
create index paiements_sync_idx on public.paiements (entreprise_id, updated_at);
create index paiements_date_idx on public.paiements (entreprise_id, date_paiement desc);
create index paiements_contact_idx on public.paiements (contact_id);

alter table public.caisse_mouvements
  add foreign key (paiement_id) references public.paiements (id);

create table public.paiement_affectations (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  paiement_id uuid not null,
  engagement_id uuid not null,
  -- Site du paiement (droits de lecture).
  perimetre_id uuid,
  montant bigint not null check (montant > 0),
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (paiement_id, engagement_id),
  foreign key (paiement_id, entreprise_id) references public.paiements (id, entreprise_id),
  foreign key (engagement_id, entreprise_id) references public.engagements (id, entreprise_id)
);
create index paiement_affectations_sync_idx on public.paiement_affectations (entreprise_id, updated_at);
create index paiement_affectations_engagement_idx on public.paiement_affectations (engagement_id);

-- Réglé = somme des affectations de paiements encore valides.
create or replace function app.recalculer_engagement(p_engagement_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.engagements e
  set montant_regle = coalesce((
    select sum(a.montant)
    from public.paiement_affectations a
    join public.paiements p on p.id = a.paiement_id
    where a.engagement_id = e.id and p.statut = 'VALIDE'
  ), 0)
  where e.id = p_engagement_id;
$$;

create or replace function app.tg_paiements_avant()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_origine public.paiements;
  v_session public.caisse_sessions;
  v_caisse uuid;
  v_mode public.modes_paiement;
  v_total bigint := 0;
  v_a record;
begin
  if new.annule_paiement_id is not null then
    -- Annulation : paiement inverse, copie conforme du paiement d'origine.
    perform app.exiger(app.peut(new.entreprise_id, 'finances.paiements', 'payments.cancel', new.perimetre_id));
    select * into v_origine from public.paiements
    where id = new.annule_paiement_id and entreprise_id = new.entreprise_id
    for update;
    perform app.exiger(v_origine.id is not null
      and app.peut(new.entreprise_id, 'finances.paiements', 'payments.cancel', v_origine.perimetre_id));
    if v_origine.id is null then
      perform app.refuser('PAIEMENT_INTROUVABLE');
    end if;
    if v_origine.annule_paiement_id is not null then
      perform app.refuser('PAIEMENT_ANNULATION_INVALIDE');
    end if;
    if v_origine.statut = 'ANNULE' then
      perform app.refuser('PAIEMENT_DEJA_ANNULE');
    end if;

    new.sens := case v_origine.sens when 'ENTREE' then 'SORTIE' else 'ENTREE' end;
    new.montant := v_origine.montant;
    new.mode_code := v_origine.mode_code;
    new.contact_id := v_origine.contact_id;
    new.perimetre_id := v_origine.perimetre_id;
    new.activite_code := v_origine.activite_code;
    new.affectations := '[]';
    new.session_id := null;
    -- Espèces : le mouvement inverse va dans la session ouverte de la même caisse.
    if v_origine.session_id is not null then
      select caisse_id into v_caisse from public.caisse_sessions where id = v_origine.session_id;
      select id into new.session_id from public.caisse_sessions
      where caisse_id = v_caisse and statut = 'OUVERTE';
      if new.session_id is null then
        perform app.refuser('CAISSE_FERMEE', jsonb_build_object('caisse', v_caisse));
      end if;
    end if;
  else
    perform app.exiger(
      app.peut(new.entreprise_id, 'finances.paiements', 'payments.create', new.perimetre_id)
      -- Verser de l'argent (fournisseur, remboursement) : gérer les dettes.
      and (new.sens = 'ENTREE'
           or app.peut(new.entreprise_id, 'finances.creances', 'receivables.manage', new.perimetre_id)));

    select * into v_mode from public.modes_paiement where code = new.mode_code;
    if v_mode.code is null or not v_mode.est_actif then
      perform app.refuser('MODE_PAIEMENT_INVALIDE');
    end if;
    if new.date_paiement > now() + interval '1 day' then
      perform app.refuser('DATE_INVALIDE');
    end if;

    if new.session_id is not null then
      select * into v_session from public.caisse_sessions
      where id = new.session_id and entreprise_id = new.entreprise_id;
      if v_session.id is null then
        perform app.refuser('SESSION_INTROUVABLE');
      end if;
      if v_session.statut <> 'OUVERTE' then
        perform app.refuser('CAISSE_FERMEE', jsonb_build_object('caisse', v_session.caisse_id));
      end if;
      if not v_mode.mouvement_caisse then
        perform app.refuser('MODE_SANS_CAISSE');
      end if;
      if new.perimetre_id is null then
        new.perimetre_id := v_session.perimetre_id;
      elsif new.perimetre_id <> v_session.perimetre_id then
        perform app.refuser('PERIMETRE_INCOHERENT');
      end if;
    end if;
    new.activite_code := app.activite_du_perimetre(new.entreprise_id, new.perimetre_id, new.activite_code);

    for v_a in
      select x.engagement_id, x.montant
      from jsonb_to_recordset(new.affectations) as x(id uuid, engagement_id uuid, montant bigint)
    loop
      if v_a.engagement_id is null or coalesce(v_a.montant, 0) <= 0 then
        perform app.refuser('AFFECTATION_INVALIDE');
      end if;
      v_total := v_total + v_a.montant;
    end loop;
    if v_total > new.montant then
      perform app.refuser('AFFECTATION_SUPERIEURE_PAIEMENT');
    end if;
  end if;

  new.statut := 'VALIDE';
  new.annule_par := null;
  new.annule_le := null;
  new.created_by := coalesce(auth.uid(), new.created_by);
  return new;
end;
$$;

create or replace function app.tg_paiements_apres()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_a record;
begin
  for v_a in
    select x.id, x.engagement_id, x.montant
    from jsonb_to_recordset(new.affectations) as x(id uuid, engagement_id uuid, montant bigint)
  loop
    insert into public.paiement_affectations (id, entreprise_id, paiement_id, engagement_id, perimetre_id, montant)
    values (coalesce(v_a.id, gen_random_uuid()), new.entreprise_id, new.id, v_a.engagement_id,
            new.perimetre_id, v_a.montant);
  end loop;

  -- Même identifiant que le paiement : l'appareil connaît d'avance le mouvement.
  if new.session_id is not null then
    insert into public.caisse_mouvements (id, entreprise_id, session_id, type, montant, paiement_id)
    values (new.id, new.entreprise_id, new.session_id,
            case new.sens when 'ENTREE' then 'ENCAISSEMENT' else 'DECAISSEMENT' end,
            new.montant, new.id);
  end if;

  if new.annule_paiement_id is not null then
    update public.paiements
    set statut = 'ANNULE', annule_par = auth.uid(), annule_le = now()
    where id = new.annule_paiement_id;
    perform app.recalculer_engagement(a.engagement_id)
    from public.paiement_affectations a where a.paiement_id = new.annule_paiement_id;
  end if;
  return null;
end;
$$;

create trigger paiements_avant before insert on public.paiements
  for each row execute function app.tg_paiements_avant();
create trigger paiements_versionnement before insert or update on public.paiements
  for each row execute function app.tg_versionnement();
create trigger paiements_apres after insert on public.paiements
  for each row execute function app.tg_paiements_apres();
create trigger audit_paiements after insert or update or delete on public.paiements
  for each row execute function app.tg_audit();

create or replace function app.tg_affectations_regles()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_paiement public.paiements;
  v_engagement public.engagements;
begin
  select * into v_paiement from public.paiements where id = new.paiement_id;
  select * into v_engagement from public.engagements
  where id = new.engagement_id and entreprise_id = new.entreprise_id
  for update;

  if v_engagement.id is null then
    perform app.refuser('ENGAGEMENT_INTROUVABLE');
  end if;
  if v_engagement.perimetre_id is not null
     and not app.acces_perimetre(new.entreprise_id, v_engagement.perimetre_id)
     and (select auth.role()) = 'authenticated' then
    perform app.refuser('PERIMETRE_NON_AUTORISE');
  end if;
  if v_engagement.statut = 'ANNULE' then
    perform app.refuser('ENGAGEMENT_ANNULE');
  end if;
  if (v_paiement.sens = 'ENTREE') <> (v_engagement.sens = 'A_RECEVOIR') then
    perform app.refuser('AFFECTATION_SENS_INCOMPATIBLE');
  end if;
  if v_paiement.contact_id is not null and v_engagement.contact_id is not null
     and v_paiement.contact_id <> v_engagement.contact_id then
    perform app.refuser('AFFECTATION_CONTACT_DIFFERENT');
  end if;
  if v_engagement.montant_regle + new.montant > v_engagement.montant_total then
    perform app.refuser('MONTANT_SUPERIEUR_RESTE',
      jsonb_build_object('reste', v_engagement.montant_total - v_engagement.montant_regle));
  end if;
  new.perimetre_id := v_paiement.perimetre_id;
  return new;
end;
$$;

create or replace function app.tg_affectations_apres()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.recalculer_engagement(new.engagement_id);
  return null;
end;
$$;

create trigger paiement_affectations_regles before insert on public.paiement_affectations
  for each row execute function app.tg_affectations_regles();
create trigger paiement_affectations_versionnement before insert or update on public.paiement_affectations
  for each row execute function app.tg_versionnement();
create trigger paiement_affectations_apres after insert on public.paiement_affectations
  for each row execute function app.tg_affectations_apres();

alter table public.paiements enable row level security;
create policy paiements_lecture on public.paiements for select to authenticated
  using (app.peut(entreprise_id, 'finances.paiements', 'payments.view', perimetre_id));
create policy paiements_ajout on public.paiements for insert to authenticated
  with check (app.peut(entreprise_id, 'finances.paiements',
                       case when annule_paiement_id is null then 'payments.create' else 'payments.cancel' end,
                       perimetre_id));

alter table public.paiement_affectations enable row level security;
create policy paiement_affectations_lecture on public.paiement_affectations for select to authenticated
  using (app.peut(entreprise_id, 'finances.paiements', 'payments.view', perimetre_id));

revoke all on public.paiements, public.paiement_affectations from anon, authenticated;
grant select on public.paiements, public.paiement_affectations to authenticated;
-- Aucun droit de modification : un paiement s'annule, il ne se corrige pas.
grant insert (id, entreprise_id, activite_code, perimetre_id, sens, montant, mode_code, date_paiement,
              contact_id, reference, note, session_id, affectations, annule_paiement_id)
  on public.paiements to authenticated;
grant all on public.paiements, public.paiement_affectations to service_role;

-- -----------------------------------------------------------------------------
-- 6. Synchronisation hors-ligne
-- -----------------------------------------------------------------------------

insert into app.sync_tables (table_name, colonnes_creation, colonnes_modification) values
  ('engagements',
   array['entreprise_id', 'activite_code', 'perimetre_id', 'sens', 'contact_id', 'libelle',
         'montant_total', 'date_engagement', 'echeance'],
   array['contact_id', 'libelle', 'montant_total', 'echeance', 'statut', 'motif_annulation']),
  ('paiements',
   array['entreprise_id', 'activite_code', 'perimetre_id', 'sens', 'montant', 'mode_code',
         'date_paiement', 'contact_id', 'reference', 'note', 'session_id', 'affectations',
         'annule_paiement_id'],
   '{}'),
  ('caisses', array['entreprise_id', 'perimetre_id', 'nom'], array['nom', 'est_active']),
  ('caisse_sessions', array['entreprise_id', 'caisse_id', 'solde_initial'],
   array['statut', 'solde_reel', 'note_cloture']),
  ('caisse_mouvements', array['entreprise_id', 'session_id', 'type', 'montant', 'motif'], '{}');
