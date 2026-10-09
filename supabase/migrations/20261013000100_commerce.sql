-- =============================================================================
-- COMMERCE : CATALOGUE, STOCK, ACHATS, VENTES
--
-- Principes :
--   • un produit unique par entreprise, plusieurs unités (pièce, paquet, carton…)
--     décrites par un facteur vers l'unité de base ;
--   • UN stock réel par boutique, en unité de base ;
--   • l'appareil n'écrit JAMAIS une quantité de stock : il envoie des opérations
--     (mouvement, transfert, réception, vente). Les triggers vérifient les droits,
--     calculent et tiennent `stocks` à jour, dans la même transaction ;
--   • les identifiants des lignes créées par le serveur sont fournis par
--     l'appareil (copies locales hors-ligne, comme pour les dépenses) ;
--   • chaque table est filtrée par boutique : l'administrateur
--     (perimetres.access_all) voit tout, les autres leurs boutiques affectées.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. Achats fournisseurs : origine d'une somme à payer
-- -----------------------------------------------------------------------------

alter table public.engagements drop constraint engagements_origine_type_check;
alter table public.engagements add constraint engagements_origine_type_check
  check (origine_type in ('MANUEL', 'VENTE', 'PRESTATION', 'LOYER', 'DEPENSE', 'ACHAT'));

-- Lignes d'une opération (achat, vente) : [{id, produit_id, unite, facteur, quantite, prix_unitaire}]
create or replace function app.lignes_valides(p_lignes jsonb, p_entreprise_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v record;
begin
  if jsonb_typeof(p_lignes) <> 'array' or jsonb_array_length(p_lignes) not between 1 and 200 then
    return false;
  end if;
  for v in
    select * from jsonb_to_recordset(p_lignes)
      as x(id uuid, produit_id uuid, unite text, facteur numeric, quantite numeric, prix_unitaire bigint)
  loop
    if v.id is null or v.produit_id is null or coalesce(v.facteur, 0) <= 0 or coalesce(v.quantite, 0) <= 0
       or coalesce(v.prix_unitaire, -1) < 0 or char_length(coalesce(trim(v.unite), '')) not between 1 and 30 then
      return false;
    end if;
    if not exists (select 1 from public.produits p
                   where p.id = v.produit_id and p.entreprise_id = p_entreprise_id and p.deleted_at is null) then
      return false;
    end if;
  end loop;
  return true;
end;
$$;

create or replace function app.total_lignes(p_lignes jsonb)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select coalesce(sum(round((x->>'quantite')::numeric * (x->>'prix_unitaire')::bigint)), 0)::bigint
  from jsonb_array_elements(p_lignes) x;
$$;

-- -----------------------------------------------------------------------------
-- 1. Catégories (2 niveaux)
-- -----------------------------------------------------------------------------

create table public.categories_produits (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  parent_id uuid,
  nom text not null check (char_length(trim(nom)) between 1 and 60),
  icone text check (char_length(icone) <= 40),
  couleur text check (couleur ~ '^#[0-9A-Fa-f]{6}$'),
  ordre integer not null default 100,
  est_active boolean not null default true,
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id),
  foreign key (parent_id, entreprise_id) references public.categories_produits (id, entreprise_id),
  check (parent_id is null or parent_id <> id)
);
create index categories_produits_sync_idx on public.categories_produits (entreprise_id, updated_at);

create or replace function app.tg_categories_produits_regles()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Deux niveaux au plus : le parent est lui-même une catégorie racine.
  if new.parent_id is not null and exists (
    select 1 from public.categories_produits c where c.id = new.parent_id and c.parent_id is not null
  ) then
    perform app.refuser('CATEGORIE_INVALIDE');
  end if;
  if tg_op = 'INSERT' then
    new.created_by := coalesce(auth.uid(), new.created_by);
  end if;
  return new;
end;
$$;

create trigger categories_produits_regles before insert or update on public.categories_produits
  for each row execute function app.tg_categories_produits_regles();
create trigger categories_produits_versionnement before insert or update on public.categories_produits
  for each row execute function app.tg_versionnement();
create trigger audit_categories_produits after insert or update or delete on public.categories_produits
  for each row execute function app.tg_audit();

alter table public.categories_produits enable row level security;
create policy categories_produits_lecture on public.categories_produits for select to authenticated
  using (app.peut(entreprise_id, 'commerce.produits', 'products.view'));
create policy categories_produits_ajout on public.categories_produits for insert to authenticated
  with check (app.peut(entreprise_id, 'commerce.produits', 'products.create'));
create policy categories_produits_modification on public.categories_produits for update to authenticated
  using (app.peut(entreprise_id, 'commerce.produits', 'products.update'))
  with check (app.peut(entreprise_id, 'commerce.produits', 'products.update'));

revoke all on public.categories_produits from anon, authenticated;
grant select on public.categories_produits to authenticated;
grant insert (id, entreprise_id, parent_id, nom, icone, couleur, ordre) on public.categories_produits to authenticated;
grant update (parent_id, nom, icone, couleur, ordre, est_active, deleted_at) on public.categories_produits to authenticated;
grant all on public.categories_produits to service_role;

-- -----------------------------------------------------------------------------
-- 2. Produits
--   unites : [{id, nom, facteur, prix_detail, prix_gros, prix_achat}]
--            prix null = calculé (facteur × prix de l'unité de base) ;
--            prix renseigné = prix fixé par le commerçant.
--   photos : chemins dans le bucket « fichiers » ({entreprise}/produits/{produit}/…)
-- -----------------------------------------------------------------------------

create table public.produits (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  categorie_id uuid,
  nom text not null check (char_length(trim(nom)) between 1 and 120),
  reference text check (char_length(reference) <= 40),
  code_barres text check (char_length(code_barres) <= 64),
  description text check (char_length(description) <= 1000),
  photos text[] not null default '{}' check (cardinality(photos) <= 5),
  unite_base text not null default 'Pièce' check (char_length(trim(unite_base)) between 1 and 30),
  unites jsonb not null default '[]' check (jsonb_typeof(unites) = 'array' and jsonb_array_length(unites) <= 10),
  prix_detail bigint not null default 0 check (prix_detail >= 0),
  prix_gros bigint check (prix_gros >= 0),
  prix_achat bigint check (prix_achat >= 0),
  vente_fractionnee boolean not null default false,
  pas_minimum numeric(14, 4) not null default 1 check (pas_minimum > 0),
  seuil_alerte numeric(14, 4) not null default 0 check (seuil_alerte >= 0),
  attributs jsonb not null default '{}' check (jsonb_typeof(attributs) = 'object'),
  fournisseur_id uuid,
  est_actif boolean not null default true,
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id),
  foreign key (categorie_id, entreprise_id) references public.categories_produits (id, entreprise_id),
  foreign key (fournisseur_id, entreprise_id) references public.contacts (id, entreprise_id)
);
create index produits_sync_idx on public.produits (entreprise_id, updated_at);
create unique index produits_code_barres_uidx on public.produits (entreprise_id, code_barres)
  where code_barres is not null and deleted_at is null;

create or replace function app.tg_produits_regles()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v record;
begin
  for v in
    select * from jsonb_to_recordset(new.unites)
      as x(id uuid, nom text, facteur numeric, prix_detail bigint, prix_gros bigint, prix_achat bigint)
  loop
    if v.id is null or coalesce(v.facteur, 0) <= 0 or char_length(coalesce(trim(v.nom), '')) not between 1 and 30
       or coalesce(v.prix_detail, 0) < 0 or coalesce(v.prix_gros, 0) < 0 or coalesce(v.prix_achat, 0) < 0 then
      perform app.refuser('UNITE_INVALIDE');
    end if;
  end loop;
  -- Les photos sont rangées sous la fiche du produit.
  if exists (select 1 from unnest(new.photos) c
             where c not like new.entreprise_id || '/produits/' || new.id || '/%') then
    perform app.refuser('CHEMIN_INVALIDE');
  end if;
  new.code_barres := nullif(trim(new.code_barres), '');
  new.reference := nullif(trim(new.reference), '');
  if tg_op = 'INSERT' then
    new.created_by := coalesce(auth.uid(), new.created_by);
  end if;
  return new;
end;
$$;

create trigger produits_regles before insert or update on public.produits
  for each row execute function app.tg_produits_regles();
create trigger produits_versionnement before insert or update on public.produits
  for each row execute function app.tg_versionnement();
create trigger audit_produits after insert or update or delete on public.produits
  for each row execute function app.tg_audit();

alter table public.produits enable row level security;
create policy produits_lecture on public.produits for select to authenticated
  using (app.peut(entreprise_id, 'commerce.produits', 'products.view'));
create policy produits_ajout on public.produits for insert to authenticated
  with check (app.peut(entreprise_id, 'commerce.produits', 'products.create'));
create policy produits_modification on public.produits for update to authenticated
  using (app.peut(entreprise_id, 'commerce.produits', 'products.update'))
  with check (app.peut(entreprise_id, 'commerce.produits', 'products.update'));

revoke all on public.produits from anon, authenticated;
grant select on public.produits to authenticated;
grant insert (id, entreprise_id, categorie_id, nom, reference, code_barres, description, photos, unite_base, unites,
              prix_detail, prix_gros, prix_achat, vente_fractionnee, pas_minimum, seuil_alerte, attributs,
              fournisseur_id)
  on public.produits to authenticated;
grant update (categorie_id, nom, reference, code_barres, description, photos, unite_base, unites, prix_detail,
              prix_gros, prix_achat, vente_fractionnee, pas_minimum, seuil_alerte, attributs, fournisseur_id,
              est_actif, deleted_at)
  on public.produits to authenticated;
grant all on public.produits to service_role;

-- Photos : lecture pour tout membre, ajout pour qui gère les produits.
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
  end if;
  return false;
end;
$$;

-- -----------------------------------------------------------------------------
-- 3. Stock par boutique (écrit uniquement par les triggers de mouvements)
-- -----------------------------------------------------------------------------

create table public.stocks (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  perimetre_id uuid not null,
  produit_id uuid not null,
  quantite numeric(14, 4) not null default 0,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (perimetre_id, produit_id),
  foreign key (perimetre_id, entreprise_id) references public.perimetres (id, entreprise_id),
  foreign key (produit_id, entreprise_id) references public.produits (id, entreprise_id) on delete cascade
);
create index stocks_sync_idx on public.stocks (entreprise_id, updated_at);

create trigger stocks_versionnement before insert or update on public.stocks
  for each row execute function app.tg_versionnement();

alter table public.stocks enable row level security;
create policy stocks_lecture on public.stocks for select to authenticated
  using (app.peut(entreprise_id, 'commerce.stock', 'stock.view', perimetre_id)
         or app.peut(entreprise_id, 'commerce.ventes', 'sales.create', perimetre_id));

revoke all on public.stocks from anon, authenticated;
grant select on public.stocks to authenticated;
grant all on public.stocks to service_role;

-- -----------------------------------------------------------------------------
-- 4. Mouvements de stock
--   quantite : en unité de base, toujours positive (pour un inventaire :
--              la quantité comptée) ; delta : variation signée, calculée ici.
-- -----------------------------------------------------------------------------

create table public.mouvements_stock (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  perimetre_id uuid not null,
  produit_id uuid not null,
  type text not null check (type in ('ENTREE', 'SORTIE', 'TRANSFERT_SORTIE', 'TRANSFERT_ENTREE', 'INVENTAIRE')),
  motif text not null check (motif in ('ACHAT', 'RETOUR', 'AJUSTEMENT', 'VENTE', 'PERTE', 'CASSE', 'TRANSFERT',
                                       'ERREUR_COMPTAGE', 'MANQUANT', 'AUTRE')),
  quantite numeric(14, 4) not null check (quantite >= 0),
  quantite_saisie numeric(14, 4) not null check (quantite_saisie >= 0),
  unite_saisie text not null check (char_length(trim(unite_saisie)) between 1 and 30),
  facteur numeric(14, 4) not null default 1 check (facteur > 0),
  delta numeric(14, 4) not null default 0,
  stock_avant numeric(14, 4) not null default 0,
  stock_apres numeric(14, 4) not null default 0,
  origine_type text not null default 'MANUEL'
    check (origine_type in ('MANUEL', 'TRANSFERT', 'RECEPTION', 'VENTE')),
  origine_id uuid,
  note text check (char_length(note) <= 500),
  date_mouvement timestamptz not null default now(),
  auteur_nom text,
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id),
  foreign key (perimetre_id, entreprise_id) references public.perimetres (id, entreprise_id),
  foreign key (produit_id, entreprise_id) references public.produits (id, entreprise_id) on delete cascade,
  check (type <> 'ENTREE' or motif in ('ACHAT', 'RETOUR', 'AJUSTEMENT', 'AUTRE')),
  check (type <> 'SORTIE' or motif in ('VENTE', 'PERTE', 'CASSE', 'AJUSTEMENT', 'AUTRE')),
  check (type not like 'TRANSFERT_%' or motif = 'TRANSFERT'),
  check (type <> 'INVENTAIRE' or motif in ('ERREUR_COMPTAGE', 'CASSE', 'PERTE', 'MANQUANT', 'AUTRE'))
);
create index mouvements_stock_sync_idx on public.mouvements_stock (entreprise_id, updated_at);
create index mouvements_stock_produit_idx on public.mouvements_stock (produit_id, date_mouvement desc);
create index mouvements_stock_origine_idx on public.mouvements_stock (origine_id) where origine_id is not null;

create or replace function app.tg_mouvements_stock_avant()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_avant numeric(14, 4);
begin
  if not app.confiance() then
    -- Saisie directe : entrée, sortie, inventaire. Le reste vient des opérations.
    if new.type not in ('ENTREE', 'SORTIE', 'INVENTAIRE') then
      perform app.refuser('MOUVEMENT_INVALIDE');
    end if;
    perform app.exiger(app.peut(new.entreprise_id, 'commerce.stock',
      case new.type when 'INVENTAIRE' then 'stock.update' else 'stock.create' end, new.perimetre_id));
    if new.type <> 'INVENTAIRE' and new.quantite <= 0 then
      perform app.refuser('QUANTITE_INVALIDE');
    end if;
    new.origine_type := 'MANUEL';
    new.origine_id := null;
    if new.date_mouvement > now() + interval '1 day' then
      new.date_mouvement := now();
    end if;
  end if;

  -- Verrou de la ligne de stock : les opérations concurrentes s'enchaînent.
  insert into public.stocks (entreprise_id, perimetre_id, produit_id)
  values (new.entreprise_id, new.perimetre_id, new.produit_id)
  on conflict (perimetre_id, produit_id) do nothing;
  select quantite into v_avant from public.stocks
  where perimetre_id = new.perimetre_id and produit_id = new.produit_id
  for update;

  new.delta := case
    when new.type in ('ENTREE', 'TRANSFERT_ENTREE') then new.quantite
    when new.type in ('SORTIE', 'TRANSFERT_SORTIE') then -new.quantite
    else new.quantite - v_avant
  end;

  -- Stock négatif interdit, sauf pour une vente déjà faite au comptoir
  -- (enregistrée hors-ligne) : le stock affiché doit alors être vérifié.
  if new.delta < 0 and v_avant + new.delta < 0 and new.origine_type <> 'VENTE' then
    perform app.refuser('STOCK_INSUFFISANT', jsonb_build_object('disponible', v_avant));
  end if;

  new.stock_avant := v_avant;
  new.stock_apres := v_avant + new.delta;
  new.created_by := coalesce(auth.uid(), new.created_by);
  new.auteur_nom := (select nom_complet from public.profiles where id = new.created_by);

  update public.stocks set quantite = new.stock_apres
  where perimetre_id = new.perimetre_id and produit_id = new.produit_id;
  return new;
end;
$$;

create trigger mouvements_stock_avant before insert on public.mouvements_stock
  for each row execute function app.tg_mouvements_stock_avant();
create trigger mouvements_stock_versionnement before insert or update on public.mouvements_stock
  for each row execute function app.tg_versionnement();
create trigger audit_mouvements_stock after insert on public.mouvements_stock
  for each row execute function app.tg_audit();

alter table public.mouvements_stock enable row level security;
create policy mouvements_stock_lecture on public.mouvements_stock for select to authenticated
  using (app.peut(entreprise_id, 'commerce.stock', 'stock.view', perimetre_id));
create policy mouvements_stock_ajout on public.mouvements_stock for insert to authenticated
  with check (app.peut(entreprise_id, 'commerce.stock', 'stock.create', perimetre_id)
              or app.peut(entreprise_id, 'commerce.stock', 'stock.update', perimetre_id));

revoke all on public.mouvements_stock from anon, authenticated;
grant select on public.mouvements_stock to authenticated;
grant insert (id, entreprise_id, perimetre_id, produit_id, type, motif, quantite, quantite_saisie, unite_saisie,
              facteur, note, date_mouvement)
  on public.mouvements_stock to authenticated;
grant all on public.mouvements_stock to service_role;

-- -----------------------------------------------------------------------------
-- 5. Transferts entre boutiques : un transfert = sortie (id du transfert)
--    + entrée (mouvement_entree_id), dans la même transaction.
-- -----------------------------------------------------------------------------

create table public.transferts_stock (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  produit_id uuid not null,
  de_perimetre_id uuid not null,
  vers_perimetre_id uuid not null,
  quantite numeric(14, 4) not null check (quantite > 0),
  quantite_saisie numeric(14, 4) not null check (quantite_saisie > 0),
  unite_saisie text not null check (char_length(trim(unite_saisie)) between 1 and 30),
  facteur numeric(14, 4) not null default 1 check (facteur > 0),
  mouvement_entree_id uuid not null unique,
  note text check (char_length(note) <= 500),
  date_transfert timestamptz not null default now(),
  auteur_nom text,
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id),
  foreign key (produit_id, entreprise_id) references public.produits (id, entreprise_id) on delete cascade,
  foreign key (de_perimetre_id, entreprise_id) references public.perimetres (id, entreprise_id),
  foreign key (vers_perimetre_id, entreprise_id) references public.perimetres (id, entreprise_id),
  check (de_perimetre_id <> vers_perimetre_id)
);
create index transferts_stock_sync_idx on public.transferts_stock (entreprise_id, updated_at);

create or replace function app.tg_transferts_stock_avant()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Il faut gérer le stock des DEUX boutiques.
  perform app.exiger(app.peut(new.entreprise_id, 'commerce.stock', 'stock.update', new.de_perimetre_id)
                     and app.peut(new.entreprise_id, 'commerce.stock', 'stock.update', new.vers_perimetre_id));
  new.created_by := coalesce(auth.uid(), new.created_by);
  new.auteur_nom := (select nom_complet from public.profiles where id = new.created_by);
  if new.date_transfert > now() + interval '1 day' then
    new.date_transfert := now();
  end if;
  return new;
end;
$$;

create or replace function app.tg_transferts_stock_apres()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.rpc_de_confiance(true);
  insert into public.mouvements_stock (id, entreprise_id, perimetre_id, produit_id, type, motif, quantite,
                                       quantite_saisie, unite_saisie, facteur, origine_type, origine_id, note,
                                       date_mouvement, created_by)
  values
    (new.id, new.entreprise_id, new.de_perimetre_id, new.produit_id, 'TRANSFERT_SORTIE', 'TRANSFERT',
     new.quantite, new.quantite_saisie, new.unite_saisie, new.facteur, 'TRANSFERT', new.id, new.note,
     new.date_transfert, new.created_by),
    (new.mouvement_entree_id, new.entreprise_id, new.vers_perimetre_id, new.produit_id, 'TRANSFERT_ENTREE',
     'TRANSFERT', new.quantite, new.quantite_saisie, new.unite_saisie, new.facteur, 'TRANSFERT', new.id,
     new.note, new.date_transfert, new.created_by);
  perform app.rpc_de_confiance(false);
  return null;
end;
$$;

create trigger transferts_stock_avant before insert on public.transferts_stock
  for each row execute function app.tg_transferts_stock_avant();
create trigger transferts_stock_versionnement before insert or update on public.transferts_stock
  for each row execute function app.tg_versionnement();
create trigger transferts_stock_apres after insert on public.transferts_stock
  for each row execute function app.tg_transferts_stock_apres();
create trigger audit_transferts_stock after insert on public.transferts_stock
  for each row execute function app.tg_audit();

alter table public.transferts_stock enable row level security;
create policy transferts_stock_lecture on public.transferts_stock for select to authenticated
  using (app.peut(entreprise_id, 'commerce.stock', 'stock.view', de_perimetre_id)
         or app.peut(entreprise_id, 'commerce.stock', 'stock.view', vers_perimetre_id));
create policy transferts_stock_ajout on public.transferts_stock for insert to authenticated
  with check (app.peut(entreprise_id, 'commerce.stock', 'stock.update', de_perimetre_id)
              and app.peut(entreprise_id, 'commerce.stock', 'stock.update', vers_perimetre_id));

revoke all on public.transferts_stock from anon, authenticated;
grant select on public.transferts_stock to authenticated;
grant insert (id, entreprise_id, produit_id, de_perimetre_id, vers_perimetre_id, quantite, quantite_saisie,
              unite_saisie, facteur, mouvement_entree_id, note, date_transfert)
  on public.transferts_stock to authenticated;
grant all on public.transferts_stock to service_role;

-- -----------------------------------------------------------------------------
-- 6. Achats fournisseurs : une commande, plusieurs produits, une somme à payer
--    (engagement A_PAYER d'origine ACHAT, même identifiant que l'achat).
--    lignes : [{id, produit_id, unite, facteur, quantite, prix_unitaire, recu}]
--             quantités dans l'unité de la ligne ; « recu » tenu par le serveur.
-- -----------------------------------------------------------------------------

create table public.achats (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  perimetre_id uuid not null,
  fournisseur_id uuid,
  reference text check (char_length(reference) <= 40),
  date_achat date not null default current_date,
  lignes jsonb not null,
  total bigint not null default 0 check (total >= 0),
  statut text not null default 'COMMANDE' check (statut in ('COMMANDE', 'RECU_PARTIEL', 'RECU', 'ANNULE')),
  note text check (char_length(note) <= 500),
  auteur_nom text,
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id),
  foreign key (perimetre_id, entreprise_id) references public.perimetres (id, entreprise_id),
  foreign key (fournisseur_id, entreprise_id) references public.contacts (id, entreprise_id)
);
create index achats_sync_idx on public.achats (entreprise_id, updated_at);
create index achats_fournisseur_idx on public.achats (fournisseur_id);

create or replace function app.tg_achats_avant()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_recu jsonb;
begin
  if tg_op = 'INSERT' then
    perform app.exiger(app.peut(new.entreprise_id, 'commerce.achats', 'purchases.create', new.perimetre_id));
    if not app.lignes_valides(new.lignes, new.entreprise_id) then
      perform app.refuser('LIGNES_INVALIDES');
    end if;
    -- Rien n'est reçu à la création.
    select jsonb_agg(x || jsonb_build_object('recu', 0)) into new.lignes from jsonb_array_elements(new.lignes) x;
    new.statut := 'COMMANDE';
    new.total := app.total_lignes(new.lignes);
    new.created_by := coalesce(auth.uid(), new.created_by);
    new.auteur_nom := (select nom_complet from public.profiles where id = new.created_by);
    return new;
  end if;

  if app.confiance() then
    return new;   -- réception : quantités reçues et statut
  end if;

  perform app.exiger(app.peut(new.entreprise_id, 'commerce.achats', 'purchases.update', new.perimetre_id));
  if old.statut = 'ANNULE' then
    perform app.refuser('ACHAT_ANNULE');
  end if;
  new.perimetre_id := old.perimetre_id;
  if new.statut is distinct from old.statut and new.statut <> 'ANNULE' then
    new.statut := old.statut;
  end if;

  if new.lignes is distinct from old.lignes then
    if old.statut <> 'COMMANDE' then
      perform app.refuser('ACHAT_RECU');
    end if;
    if not app.lignes_valides(new.lignes, new.entreprise_id) then
      perform app.refuser('LIGNES_INVALIDES');
    end if;
    select jsonb_agg(x || jsonb_build_object('recu', 0)) into v_recu from jsonb_array_elements(new.lignes) x;
    new.lignes := v_recu;
    new.total := app.total_lignes(new.lignes);
  else
    new.total := old.total;
  end if;

  if new.statut = 'ANNULE' and old.statut <> 'ANNULE' then
    if old.statut <> 'COMMANDE' then
      perform app.refuser('ACHAT_RECU');
    end if;
    if exists (select 1 from public.engagements e where e.id = old.id and e.montant_regle > 0) then
      perform app.refuser('ACHAT_PAYE');
    end if;
  end if;
  return new;
end;
$$;

create or replace function app.tg_achats_apres()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_libelle text;
begin
  perform app.rpc_de_confiance(true);
  v_libelle := left(trim(both from 'Achat ' || coalesce(new.reference, '') || ' ' || coalesce((
    select coalesce(c.prenom || ' ', '') || c.nom from public.contacts c where c.id = new.fournisseur_id), '')), 200);

  if tg_op = 'INSERT' then
    if new.total > 0 then
      insert into public.engagements (id, entreprise_id, perimetre_id, sens, contact_id, libelle, montant_total,
                                      date_engagement, origine_type, origine_id)
      values (new.id, new.entreprise_id, new.perimetre_id, 'A_PAYER', new.fournisseur_id, v_libelle, new.total,
              new.date_achat, 'ACHAT', new.id);
    end if;
  elsif new.statut = 'ANNULE' and old.statut <> 'ANNULE' then
    update public.engagements set statut = 'ANNULE', motif_annulation = 'Achat annulé' where id = new.id;
  elsif new.total is distinct from old.total or new.fournisseur_id is distinct from old.fournisseur_id
        or new.reference is distinct from old.reference then
    if new.total > 0 then
      insert into public.engagements (id, entreprise_id, perimetre_id, sens, contact_id, libelle, montant_total,
                                      date_engagement, origine_type, origine_id)
      values (new.id, new.entreprise_id, new.perimetre_id, 'A_PAYER', new.fournisseur_id, v_libelle, new.total,
              new.date_achat, 'ACHAT', new.id)
      on conflict (id) do update
        set montant_total = excluded.montant_total, contact_id = excluded.contact_id, libelle = excluded.libelle;
    end if;
  end if;

  perform app.rpc_de_confiance(false);
  return null;
end;
$$;

create trigger achats_avant before insert or update on public.achats
  for each row execute function app.tg_achats_avant();
create trigger achats_versionnement before insert or update on public.achats
  for each row execute function app.tg_versionnement();
create trigger achats_apres after insert or update on public.achats
  for each row execute function app.tg_achats_apres();
create trigger audit_achats after insert or update or delete on public.achats
  for each row execute function app.tg_audit();

alter table public.achats enable row level security;
create policy achats_lecture on public.achats for select to authenticated
  using (app.peut(entreprise_id, 'commerce.achats', 'purchases.view', perimetre_id));
create policy achats_ajout on public.achats for insert to authenticated
  with check (app.peut(entreprise_id, 'commerce.achats', 'purchases.create', perimetre_id));
create policy achats_modification on public.achats for update to authenticated
  using (app.peut(entreprise_id, 'commerce.achats', 'purchases.update', perimetre_id))
  with check (app.peut(entreprise_id, 'commerce.achats', 'purchases.update', perimetre_id));

revoke all on public.achats from anon, authenticated;
grant select on public.achats to authenticated;
grant insert (id, entreprise_id, perimetre_id, fournisseur_id, reference, date_achat, lignes, note)
  on public.achats to authenticated;
grant update (fournisseur_id, reference, date_achat, lignes, note, statut) on public.achats to authenticated;
grant all on public.achats to service_role;

-- -----------------------------------------------------------------------------
-- 7. Réceptions (totales ou partielles)
--    lignes : [{id, ligne_id, quantite}] — id = mouvement d'entrée créé.
-- -----------------------------------------------------------------------------

create table public.receptions (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  achat_id uuid not null,
  perimetre_id uuid,
  lignes jsonb not null check (jsonb_typeof(lignes) = 'array' and jsonb_array_length(lignes) between 1 and 200),
  date_reception timestamptz not null default now(),
  note text check (char_length(note) <= 500),
  auteur_nom text,
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id),
  foreign key (achat_id, entreprise_id) references public.achats (id, entreprise_id),
  foreign key (perimetre_id, entreprise_id) references public.perimetres (id, entreprise_id)
);
create index receptions_sync_idx on public.receptions (entreprise_id, updated_at);
create index receptions_achat_idx on public.receptions (achat_id);

create or replace function app.tg_receptions_avant()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_achat public.achats;
  v record;
  v_ligne jsonb;
begin
  select * into v_achat from public.achats
  where id = new.achat_id and entreprise_id = new.entreprise_id
  for update;
  perform app.exiger(v_achat.id is not null
    and app.peut(new.entreprise_id, 'commerce.achats', 'purchases.update', v_achat.perimetre_id));
  if v_achat.statut = 'ANNULE' then
    perform app.refuser('ACHAT_ANNULE');
  end if;
  if v_achat.statut = 'RECU' then
    perform app.refuser('ACHAT_RECU');
  end if;
  new.perimetre_id := v_achat.perimetre_id;

  for v in select * from jsonb_to_recordset(new.lignes) as x(id uuid, ligne_id uuid, quantite numeric) loop
    select x into v_ligne from jsonb_array_elements(v_achat.lignes) x where (x->>'id')::uuid = v.ligne_id;
    if v.id is null or v_ligne is null or coalesce(v.quantite, 0) <= 0 then
      perform app.refuser('LIGNES_INVALIDES');
    end if;
    if (v_ligne->>'recu')::numeric + v.quantite > (v_ligne->>'quantite')::numeric then
      perform app.refuser('RECEPTION_SUPERIEURE',
        jsonb_build_object('reste', (v_ligne->>'quantite')::numeric - (v_ligne->>'recu')::numeric));
    end if;
  end loop;

  new.created_by := coalesce(auth.uid(), new.created_by);
  new.auteur_nom := (select nom_complet from public.profiles where id = new.created_by);
  if new.date_reception > now() + interval '1 day' then
    new.date_reception := now();
  end if;
  return new;
end;
$$;

create or replace function app.tg_receptions_apres()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_achat public.achats;
  v record;
  v_lignes jsonb;
begin
  select * into v_achat from public.achats where id = new.achat_id;
  perform app.rpc_de_confiance(true);

  for v in
    select r.id, r.quantite, l.produit_id, l.unite, l.facteur
    from jsonb_to_recordset(new.lignes) as r(id uuid, ligne_id uuid, quantite numeric)
    join jsonb_to_recordset(v_achat.lignes) as l(id uuid, produit_id uuid, unite text, facteur numeric)
      on l.id = r.ligne_id
  loop
    insert into public.mouvements_stock (id, entreprise_id, perimetre_id, produit_id, type, motif, quantite,
                                         quantite_saisie, unite_saisie, facteur, origine_type, origine_id,
                                         date_mouvement, created_by)
    values (v.id, new.entreprise_id, new.perimetre_id, v.produit_id, 'ENTREE', 'ACHAT', v.quantite * v.facteur,
            v.quantite, v.unite, v.facteur, 'RECEPTION', new.id, new.date_reception, new.created_by);
  end loop;

  select jsonb_agg(
           l || jsonb_build_object('recu', (l->>'recu')::numeric + coalesce((
             select sum((r->>'quantite')::numeric) from jsonb_array_elements(new.lignes) r
             where (r->>'ligne_id')::uuid = (l->>'id')::uuid), 0))
           order by o)
    into v_lignes
  from jsonb_array_elements(v_achat.lignes) with ordinality as t(l, o);

  update public.achats
  set lignes = v_lignes,
      statut = case when exists (select 1 from jsonb_array_elements(v_lignes) l
                                 where (l->>'recu')::numeric < (l->>'quantite')::numeric)
                    then 'RECU_PARTIEL' else 'RECU' end
  where id = new.achat_id;

  perform app.rpc_de_confiance(false);
  return null;
end;
$$;

create trigger receptions_avant before insert on public.receptions
  for each row execute function app.tg_receptions_avant();
create trigger receptions_versionnement before insert or update on public.receptions
  for each row execute function app.tg_versionnement();
create trigger receptions_apres after insert on public.receptions
  for each row execute function app.tg_receptions_apres();
create trigger audit_receptions after insert on public.receptions
  for each row execute function app.tg_audit();

alter table public.receptions enable row level security;
create policy receptions_lecture on public.receptions for select to authenticated
  using (app.peut(entreprise_id, 'commerce.achats', 'purchases.view', perimetre_id));
create policy receptions_ajout on public.receptions for insert to authenticated
  with check (app.peut(entreprise_id, 'commerce.achats', 'purchases.update'));

revoke all on public.receptions from anon, authenticated;
grant select on public.receptions to authenticated;
grant insert (id, entreprise_id, achat_id, lignes, date_reception, note) on public.receptions to authenticated;
grant all on public.receptions to service_role;

-- -----------------------------------------------------------------------------
-- 8. Ventes
--    lignes : [{id, produit_id, unite, facteur, quantite, prix_unitaire}]
--             id = mouvement de sortie créé.
--    Une vente crée : les sorties de stock, la somme à recevoir (engagement
--    d'origine VENTE, même identifiant) et, payée tout de suite, le paiement
--    (paiement_id fourni) et l'entrée de caisse.
-- -----------------------------------------------------------------------------

create table public.ventes (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  perimetre_id uuid not null,
  contact_id uuid,
  mode text not null default 'DETAIL' check (mode in ('DETAIL', 'GROS')),
  lignes jsonb not null,
  remise bigint not null default 0 check (remise >= 0),
  total bigint not null default 0 check (total >= 0),
  date_vente timestamptz not null default now(),
  reglement text not null default 'IMMEDIAT' check (reglement in ('IMMEDIAT', 'CREDIT')),
  mode_code text references public.modes_paiement (code),
  session_id uuid,
  paiement_id uuid unique,
  statut text not null default 'VALIDEE' check (statut in ('VALIDEE', 'ANNULEE')),
  motif_annulation text check (char_length(motif_annulation) <= 500),
  note text check (char_length(note) <= 500),
  auteur_nom text,
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, entreprise_id),
  foreign key (perimetre_id, entreprise_id) references public.perimetres (id, entreprise_id),
  foreign key (contact_id, entreprise_id) references public.contacts (id, entreprise_id),
  check (reglement = 'CREDIT' or (mode_code is not null and paiement_id is not null))
);
create index ventes_sync_idx on public.ventes (entreprise_id, updated_at);
create index ventes_date_idx on public.ventes (entreprise_id, date_vente desc);

create or replace function app.tg_ventes_avant()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    perform app.exiger(app.peut(new.entreprise_id, 'commerce.ventes', 'sales.create', new.perimetre_id));
    if not app.lignes_valides(new.lignes, new.entreprise_id) then
      perform app.refuser('LIGNES_INVALIDES');
    end if;
    new.total := app.total_lignes(new.lignes) - new.remise;
    if new.total < 0 then
      perform app.refuser('MONTANT_INVALIDE');
    end if;
    if new.reglement = 'CREDIT' and new.contact_id is null then
      perform app.refuser('CLIENT_REQUIS');
    end if;
    if new.reglement = 'IMMEDIAT' then
      perform app.exiger(app.peut(new.entreprise_id, 'finances.paiements', 'payments.create', new.perimetre_id));
      -- Vente faite au comptoir : si la caisse a été fermée entre-temps,
      -- le paiement est gardé, sans mouvement de caisse.
      if new.session_id is not null and not exists (
        select 1 from public.caisse_sessions s
        where s.id = new.session_id and s.entreprise_id = new.entreprise_id
          and s.statut = 'OUVERTE' and s.perimetre_id = new.perimetre_id
      ) then
        new.session_id := null;
      end if;
    else
      new.mode_code := null;
      new.session_id := null;
      new.paiement_id := null;
    end if;
    if new.date_vente > now() + interval '1 day' then
      new.date_vente := now();
    end if;
    new.statut := 'VALIDEE';
    new.motif_annulation := null;
    new.created_by := coalesce(auth.uid(), new.created_by);
    new.auteur_nom := (select nom_complet from public.profiles where id = new.created_by);
    return new;
  end if;

  -- Modification : note, ou annulation d'une vente non encaissée.
  perform app.exiger(app.peut(new.entreprise_id, 'commerce.ventes', 'sales.update', new.perimetre_id));
  if old.statut = 'ANNULEE' then
    perform app.refuser('VENTE_ANNULEE');
  end if;
  if new.statut = 'ANNULEE' and exists (
    select 1 from public.engagements e where e.id = old.id and e.montant_regle > 0
  ) then
    perform app.refuser('VENTE_PAYEE');
  end if;
  return new;
end;
$$;

create or replace function app.tg_ventes_apres()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v record;
begin
  perform app.rpc_de_confiance(true);

  if tg_op = 'INSERT' then
    for v in
      select * from jsonb_to_recordset(new.lignes)
        as x(id uuid, produit_id uuid, unite text, facteur numeric, quantite numeric)
    loop
      insert into public.mouvements_stock (id, entreprise_id, perimetre_id, produit_id, type, motif, quantite,
                                           quantite_saisie, unite_saisie, facteur, origine_type, origine_id,
                                           date_mouvement, created_by)
      values (v.id, new.entreprise_id, new.perimetre_id, v.produit_id, 'SORTIE', 'VENTE', v.quantite * v.facteur,
              v.quantite, v.unite, v.facteur, 'VENTE', new.id, new.date_vente, new.created_by);
    end loop;

    if new.total > 0 then
      insert into public.engagements (id, entreprise_id, perimetre_id, sens, contact_id, libelle, montant_total,
                                      date_engagement, origine_type, origine_id)
      values (new.id, new.entreprise_id, new.perimetre_id, 'A_RECEVOIR', new.contact_id, 'Vente',
              new.total, new.date_vente::date, 'VENTE', new.id);

      if new.reglement = 'IMMEDIAT' then
        insert into public.paiements (id, entreprise_id, perimetre_id, sens, montant, mode_code, date_paiement,
                                      contact_id, note, session_id, affectations)
        values (new.paiement_id, new.entreprise_id, new.perimetre_id, 'ENTREE', new.total, new.mode_code,
                least(new.date_vente, now()), new.contact_id, 'Vente', new.session_id,
                jsonb_build_array(jsonb_build_object(
                  'id', new.paiement_id, 'engagement_id', new.id, 'montant', new.total)));
      end if;
    end if;
  elsif new.statut = 'ANNULEE' and old.statut <> 'ANNULEE' then
    -- Les produits reviennent en stock ; la somme à recevoir est annulée.
    for v in
      select * from jsonb_to_recordset(new.lignes)
        as x(id uuid, produit_id uuid, unite text, facteur numeric, quantite numeric)
    loop
      insert into public.mouvements_stock (entreprise_id, perimetre_id, produit_id, type, motif, quantite,
                                           quantite_saisie, unite_saisie, facteur, origine_type, origine_id,
                                           note, created_by)
      values (new.entreprise_id, new.perimetre_id, v.produit_id, 'ENTREE', 'RETOUR', v.quantite * v.facteur,
              v.quantite, v.unite, v.facteur, 'VENTE', new.id, new.motif_annulation, auth.uid());
    end loop;
    update public.engagements set statut = 'ANNULE', motif_annulation = new.motif_annulation where id = new.id;
  end if;

  perform app.rpc_de_confiance(false);
  return null;
end;
$$;

create trigger ventes_avant before insert or update on public.ventes
  for each row execute function app.tg_ventes_avant();
create trigger ventes_versionnement before insert or update on public.ventes
  for each row execute function app.tg_versionnement();
create trigger ventes_apres after insert or update on public.ventes
  for each row execute function app.tg_ventes_apres();
create trigger audit_ventes after insert or update or delete on public.ventes
  for each row execute function app.tg_audit();

alter table public.ventes enable row level security;
create policy ventes_lecture on public.ventes for select to authenticated
  using (app.peut(entreprise_id, 'commerce.ventes', 'sales.view', perimetre_id));
create policy ventes_ajout on public.ventes for insert to authenticated
  with check (app.peut(entreprise_id, 'commerce.ventes', 'sales.create', perimetre_id));
create policy ventes_modification on public.ventes for update to authenticated
  using (app.peut(entreprise_id, 'commerce.ventes', 'sales.update', perimetre_id))
  with check (app.peut(entreprise_id, 'commerce.ventes', 'sales.update', perimetre_id));

revoke all on public.ventes from anon, authenticated;
grant select on public.ventes to authenticated;
grant insert (id, entreprise_id, perimetre_id, contact_id, mode, lignes, remise, date_vente, reglement, mode_code,
              session_id, paiement_id, note)
  on public.ventes to authenticated;
grant update (note, statut, motif_annulation) on public.ventes to authenticated;
grant all on public.ventes to service_role;

-- -----------------------------------------------------------------------------
-- 9. Synchronisation
-- -----------------------------------------------------------------------------

insert into app.sync_tables (table_name, colonnes_creation, colonnes_modification) values
  ('categories_produits',
   array['entreprise_id', 'parent_id', 'nom', 'icone', 'couleur', 'ordre'],
   array['parent_id', 'nom', 'icone', 'couleur', 'ordre', 'est_active']),
  ('produits',
   array['entreprise_id', 'categorie_id', 'nom', 'reference', 'code_barres', 'description', 'photos', 'unite_base',
         'unites', 'prix_detail', 'prix_gros', 'prix_achat', 'vente_fractionnee', 'pas_minimum', 'seuil_alerte',
         'attributs', 'fournisseur_id'],
   array['categorie_id', 'nom', 'reference', 'code_barres', 'description', 'photos', 'unite_base', 'unites',
         'prix_detail', 'prix_gros', 'prix_achat', 'vente_fractionnee', 'pas_minimum', 'seuil_alerte', 'attributs',
         'fournisseur_id', 'est_actif']),
  ('stocks', array[]::text[], array[]::text[]),
  ('mouvements_stock',
   array['entreprise_id', 'perimetre_id', 'produit_id', 'type', 'motif', 'quantite', 'quantite_saisie',
         'unite_saisie', 'facteur', 'note', 'date_mouvement'],
   array[]::text[]),
  ('transferts_stock',
   array['entreprise_id', 'produit_id', 'de_perimetre_id', 'vers_perimetre_id', 'quantite', 'quantite_saisie',
         'unite_saisie', 'facteur', 'mouvement_entree_id', 'note', 'date_transfert'],
   array[]::text[]),
  ('achats',
   array['entreprise_id', 'perimetre_id', 'fournisseur_id', 'reference', 'date_achat', 'lignes', 'note'],
   array['fournisseur_id', 'reference', 'date_achat', 'lignes', 'note', 'statut']),
  ('receptions',
   array['entreprise_id', 'achat_id', 'lignes', 'date_reception', 'note'],
   array[]::text[]),
  ('ventes',
   array['entreprise_id', 'perimetre_id', 'contact_id', 'mode', 'lignes', 'remise', 'date_vente', 'reglement',
         'mode_code', 'session_id', 'paiement_id', 'note'],
   array['note', 'statut', 'motif_annulation']);
