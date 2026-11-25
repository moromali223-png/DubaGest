-- =============================================================================
-- Migration: Gestion des Lots de Stock, Traçabilité FIFO & Archivage Sécurisé
-- Date: 2026-11-23
-- Fichier: 20261123000100_lots_stock_fifo_archivage.sql
-- =============================================================================

-- 1. Table des Lots de Stock
create table if not exists public.lots_stock (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises(id) on delete restrict,
  perimetre_id uuid not null references public.perimetres(id) on delete restrict,
  produit_id uuid not null references public.produits(id) on delete restrict,
  reference text not null,
  date_achat timestamptz not null default now(),
  date_reception timestamptz not null default now(),
  quantite_initiale numeric(14, 4) not null check (quantite_initiale > 0),
  quantite_restante numeric(14, 4) not null check (quantite_restante >= 0 and quantite_restante <= quantite_initiale),
  prix_achat_unitaire bigint not null check (prix_achat_unitaire >= 0),
  prix_vente_unitaire bigint not null check (prix_vente_unitaire >= 0),
  fournisseur_id uuid references public.contacts(id) on delete set null,
  achat_id uuid references public.achats(id) on delete set null,
  reception_id uuid references public.receptions(id) on delete set null,
  lot_origine_id uuid references public.lots_stock(id) on delete set null,
  statut text not null default 'ACTIF' check (statut in ('ACTIF', 'EPUISE', 'ARCHIVE')),
  version int default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  created_by uuid references auth.users(id) on delete set null
);

create index if not exists lots_stock_sync_idx on public.lots_stock (entreprise_id, updated_at);
create index if not exists lots_stock_fifo_idx on public.lots_stock (entreprise_id, perimetre_id, produit_id, date_reception asc, date_achat asc, id asc)
  where deleted_at is null and quantite_restante > 0;
create index if not exists lots_stock_produit_idx on public.lots_stock (produit_id, perimetre_id);
create index if not exists lots_stock_achat_idx on public.lots_stock (achat_id) where achat_id is not null;

-- 2. Liens vers Lots sur mouvements et ventes
alter table public.mouvements_stock add column if not exists lot_id uuid references public.lots_stock(id) on delete set null;
create index if not exists mouvements_stock_lot_idx on public.mouvements_stock (lot_id) where lot_id is not null;

alter table public.ventes add column if not exists cout_total bigint not null default 0;

-- 3. Sécurité RLS et Permissions pour lots_stock
alter table public.lots_stock enable row level security;

drop policy if exists lots_stock_lecture on public.lots_stock;
create policy lots_stock_lecture on public.lots_stock for select to authenticated
  using (app.peut(entreprise_id, 'commerce.stock', 'stock.view', perimetre_id));

drop policy if exists lots_stock_ecriture on public.lots_stock;
create policy lots_stock_ecriture on public.lots_stock for all to authenticated
  using (app.peut(entreprise_id, 'commerce.stock', 'stock.create', perimetre_id))
  with check (app.peut(entreprise_id, 'commerce.stock', 'stock.create', perimetre_id));

create trigger lots_stock_versionnement before insert or update on public.lots_stock
  for each row execute function app.tg_versionnement();
create trigger audit_lots_stock after insert or update or delete on public.lots_stock
  for each row execute function app.tg_audit();

grant select, insert, update on public.lots_stock to authenticated;
grant all on public.lots_stock to service_role;

-- 4. Règles de Suppression et d'Archivage Sécurisé des Produits
create or replace function app.tg_produits_regles()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v record;
  v_stock_total numeric(14, 4);
begin
  -- Cas 1: Suppression définitive ou marquage deleted_at
  if (tg_op = 'DELETE') or (tg_op = 'UPDATE' and new.deleted_at is not null and old.deleted_at is null) then
    -- Vérification si le produit a déjà été utilisé dans une transaction ou possède un historique
    if exists (select 1 from public.ventes v where exists (
        select 1 from jsonb_array_elements(v.lignes) l where (l->>'produit_id')::uuid = coalesce(old.id, new.id))) then
      perform app.refuser('PRODUIT_UTILISE');
    end if;
    if exists (select 1 from public.achats a where exists (
        select 1 from jsonb_array_elements(a.lignes) l where (l->>'produit_id')::uuid = coalesce(old.id, new.id))) then
      perform app.refuser('PRODUIT_UTILISE');
    end if;
    if exists (select 1 from public.mouvements_stock m where m.produit_id = coalesce(old.id, new.id) and m.deleted_at is null) then
      perform app.refuser('PRODUIT_UTILISE');
    end if;
    if exists (select 1 from public.lots_stock ls where ls.produit_id = coalesce(old.id, new.id) and ls.deleted_at is null) then
      perform app.refuser('PRODUIT_UTILISE');
    end if;
    select coalesce(sum(quantite), 0) into v_stock_total from public.stocks where produit_id = coalesce(old.id, new.id);
    if v_stock_total > 0 then
      perform app.refuser('PRODUIT_EN_STOCK');
    end if;

    if tg_op = 'DELETE' then
      return old;
    end if;
  end if;

  -- Cas 2: Archivage (est_actif passe à false)
  if tg_op = 'UPDATE' and old.est_actif = true and new.est_actif = false then
    -- Règle D: Interdire l'archivage tant que le stock n'est pas à 0
    select coalesce(sum(quantite), 0) into v_stock_total from public.stocks where produit_id = new.id;
    if v_stock_total > 0 or exists (
        select 1 from public.lots_stock ls
        where ls.produit_id = new.id and ls.quantite_restante > 0 and ls.deleted_at is null) then
      perform app.refuser('PRODUIT_EN_STOCK');
    end if;
  end if;

  -- Cas 3: Validation des unités & photos
  for v in
    select * from jsonb_to_recordset(new.unites)
      as x(id uuid, nom text, facteur numeric, prix_detail bigint, prix_gros bigint, prix_achat bigint)
  loop
    if v.id is null or coalesce(v.facteur, 0) <= 0 or char_length(coalesce(trim(v.nom), '')) not between 1 and 30
       or coalesce(v.prix_detail, 0) < 0 or coalesce(v.prix_gros, 0) < 0 or coalesce(v.prix_achat, 0) < 0 then
      perform app.refuser('UNITE_INVALIDE');
    end if;
  end loop;

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

-- 5. Trigger Réceptions : Création automatique d'un lot distinct à chaque réception
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
  v_lot_id uuid;
  v_lot_ref text;
  v_prix_achat_base bigint;
  v_prix_vente_base bigint;
  v_qte_base numeric(14, 4);
begin
  select * into v_achat from public.achats where id = new.achat_id;
  perform app.rpc_de_confiance(true);

  for v in
    select r.id, r.quantite, l.produit_id, l.unite, l.facteur, l.prix_unitaire,
           (l.l->>'prix_vente')::bigint as prix_vente_saisi
    from jsonb_to_recordset(new.lignes) as r(id uuid, ligne_id uuid, quantite numeric)
    join (
      select (x->>'id')::uuid as id, (x->>'produit_id')::uuid as produit_id,
             x->>'unite' as unite, coalesce((x->>'facteur')::numeric, 1) as facteur,
             coalesce((x->>'prix_unitaire')::bigint, 0) as prix_unitaire,
             x as l
      from jsonb_array_elements(v_achat.lignes) x
    ) l on l.id = r.ligne_id
  loop
    v_qte_base := v.quantite * v.facteur;
    v_prix_achat_base := case when v.facteur > 0 then round(v.prix_unitaire / v.facteur) else v.prix_unitaire end;

    -- Prix de vente conseillé en unité de base
    if v.prix_vente_saisi is not null and v.prix_vente_saisi > 0 then
      v_prix_vente_base := case when v.facteur > 0 then round(v.prix_vente_saisi / v.facteur) else v.prix_vente_saisi end;
    else
      select coalesce(prix_detail, 0) into v_prix_vente_base from public.produits where id = v.produit_id;
    end if;

    v_lot_id := v.id;
    v_lot_ref := 'LOT-' || to_char(coalesce(new.date_reception, now()), 'YYYYMMDD') || '-' || upper(substring(replace(v.id::text, '-', '') from 1 for 6));

    -- Création du lot dédié à cette réception
    insert into public.lots_stock (
      id, entreprise_id, perimetre_id, produit_id, reference, date_achat, date_reception,
      quantite_initiale, quantite_restante, prix_achat_unitaire, prix_vente_unitaire,
      fournisseur_id, achat_id, reception_id, statut, created_by
    ) values (
      v_lot_id, new.entreprise_id, new.perimetre_id, v.produit_id, v_lot_ref,
      v_achat.date_achat::timestamptz, new.date_reception,
      v_qte_base, v_qte_base, v_prix_achat_base, v_prix_vente_base,
      v_achat.fournisseur_id, v_achat.id, new.id, 'ACTIF', new.created_by
    );

    -- Mouvement d'entrée rattaché au lot
    insert into public.mouvements_stock (
      id, entreprise_id, perimetre_id, produit_id, type, motif, quantite,
      quantite_saisie, unite_saisie, facteur, origine_type, origine_id,
      date_mouvement, created_by, lot_id
    ) values (
      v.id, new.entreprise_id, new.perimetre_id, v.produit_id, 'ENTREE', 'ACHAT', v_qte_base,
      v.quantite, v.unite, v.facteur, 'RECEPTION', new.id, new.date_reception, new.created_by, v_lot_id
    );
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

-- 6. Trigger Ventes : Sortie FIFO automatique, traçabilité des lots et calcul exact du COGS
create or replace function app.tg_ventes_apres()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v record;
  v_lot record;
  v_qte_a_consommer numeric(14, 4);
  v_qte_prise numeric(14, 4);
  v_cout_ligne bigint;
  v_cout_vente bigint := 0;
  v_lots_details jsonb;
  v_lignes_nouvelles jsonb := '[]'::jsonb;
begin
  perform app.rpc_de_confiance(true);

  if tg_op = 'INSERT' then
    for v in
      select * from jsonb_to_recordset(new.lignes)
        as x(id uuid, produit_id uuid, unite text, facteur numeric, quantite numeric, prix_unitaire bigint, remise bigint)
    loop
      v_qte_a_consommer := v.quantite * coalesce(v.facteur, 1);
      v_cout_ligne := 0;
      v_lots_details := '[]'::jsonb;

      -- Consommation FIFO des lots disponibles de la boutique
      for v_lot in
        select * from public.lots_stock
        where entreprise_id = new.entreprise_id
          and perimetre_id = new.perimetre_id
          and produit_id = v.produit_id
          and quantite_restante > 0
          and deleted_at is null
          and statut = 'ACTIF'
        order by date_reception asc, date_achat asc, id asc
        for update
      loop
        exit when v_qte_a_consommer <= 0;

        v_qte_prise := least(v_qte_a_consommer, v_lot.quantite_restante);
        v_qte_a_consommer := v_qte_a_consommer - v_qte_prise;
        v_cout_ligne := v_cout_ligne + round(v_qte_prise * v_lot.prix_achat_unitaire)::bigint;

        -- Décrémentation du lot
        update public.lots_stock
        set quantite_restante = quantite_restante - v_qte_prise,
            statut = case when quantite_restante - v_qte_prise = 0 then 'EPUISE' else 'ACTIF' end
        where id = v_lot.id;

        -- Enregistrement du détail pour la facture/reçu
        v_lots_details := v_lots_details || jsonb_build_object(
          'lot_id', v_lot.id,
          'reference', v_lot.reference,
          'quantite', v_qte_prise,
          'prix_achat_unitaire', v_lot.prix_achat_unitaire,
          'prix_vente_unitaire', v_lot.prix_vente_unitaire,
          'cout_total', round(v_qte_prise * v_lot.prix_achat_unitaire)::bigint
        );

        -- Mouvement de sortie par lot consommé
        insert into public.mouvements_stock (
          entreprise_id, perimetre_id, produit_id, type, motif, quantite,
          quantite_saisie, unite_saisie, facteur, origine_type, origine_id,
          date_mouvement, created_by, lot_id
        ) values (
          new.entreprise_id, new.perimetre_id, v.produit_id, 'SORTIE', 'VENTE', v_qte_prise,
          v_qte_prise / coalesce(v.facteur, 1), v.unite, coalesce(v.facteur, 1), 'VENTE', new.id,
          new.date_vente, new.created_by, v_lot.id
        );
      end loop;

      -- Si la vente a été passée hors-ligne sans lots suffisants connus du serveur,
      -- tracer le reliquat avec le coût de référence catalogue sans bloquer la transaction
      if v_qte_a_consommer > 0 then
        declare
          v_prix_achat_cat bigint;
        begin
          select coalesce(prix_achat, 0) into v_prix_achat_cat from public.produits where id = v.produit_id;
          v_cout_ligne := v_cout_ligne + round(v_qte_a_consommer * v_prix_achat_cat)::bigint;
          insert into public.mouvements_stock (
            entreprise_id, perimetre_id, produit_id, type, motif, quantite,
            quantite_saisie, unite_saisie, facteur, origine_type, origine_id,
            date_mouvement, created_by, lot_id
          ) values (
            new.entreprise_id, new.perimetre_id, v.produit_id, 'SORTIE', 'VENTE', v_qte_a_consommer,
            v_qte_a_consommer / coalesce(v.facteur, 1), v.unite, coalesce(v.facteur, 1), 'VENTE', new.id,
            new.date_vente, new.created_by, null
          );
        end;
      end if;

      v_cout_vente := v_cout_vente + v_cout_ligne;
      v_lignes_nouvelles := v_lignes_nouvelles || jsonb_build_object(
        'id', v.id,
        'produit_id', v.produit_id,
        'unite', v.unite,
        'facteur', v.facteur,
        'quantite', v.quantite,
        'prix_unitaire', v.prix_unitaire,
        'remise', coalesce(v.remise, 0),
        'cout_total', v_cout_ligne,
        'lots', v_lots_details
      );
    end loop;

    -- Mise à jour du coût total réel et des lignes enrichies
    update public.ventes
    set cout_total = v_cout_vente,
        lignes = v_lignes_nouvelles
    where id = new.id;

    -- Création des engagements et paiements
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
    -- Annulation de la vente : Restauration des quantités dans les lots d'origine
    for v in
      select * from jsonb_to_recordset(old.lignes)
        as x(id uuid, produit_id uuid, unite text, facteur numeric, quantite numeric, lots jsonb)
    loop
      if v.lots is not null and jsonb_array_length(v.lots) > 0 then
        for v_lot in select (x->>'lot_id')::uuid as lot_id, (x->>'quantite')::numeric as quantite
                     from jsonb_array_elements(v.lots) x
        loop
          update public.lots_stock
          set quantite_restante = quantite_restante + v_lot.quantite,
              statut = 'ACTIF'
          where id = v_lot.lot_id;

          insert into public.mouvements_stock (
            entreprise_id, perimetre_id, produit_id, type, motif, quantite,
            quantite_saisie, unite_saisie, facteur, origine_type, origine_id,
            note, created_by, lot_id
          ) values (
            new.entreprise_id, new.perimetre_id, v.produit_id, 'ENTREE', 'RETOUR', v_lot.quantite,
            v_lot.quantite / coalesce(v.facteur, 1), v.unite, coalesce(v.facteur, 1), 'VENTE', new.id,
            new.motif_annulation, auth.uid(), v_lot.lot_id
          );
        end loop;
      else
        -- Restauration générique si les détails du lot n'étaient pas présents
        insert into public.mouvements_stock (
          entreprise_id, perimetre_id, produit_id, type, motif, quantite,
          quantite_saisie, unite_saisie, facteur, origine_type, origine_id,
          note, created_by
        ) values (
          new.entreprise_id, new.perimetre_id, v.produit_id, 'ENTREE', 'RETOUR', v.quantite * coalesce(v.facteur, 1),
          v.quantite, v.unite, coalesce(v.facteur, 1), 'VENTE', new.id, new.motif_annulation, auth.uid()
        );
      end if;
    end loop;
    update public.engagements set statut = 'ANNULE', motif_annulation = new.motif_annulation where id = new.id;
  end if;

  perform app.rpc_de_confiance(false);
  return null;
end;
$$;

-- 7. Trigger Transferts : Sortie du lot source et création du lot destination au même coût
create or replace function app.tg_transferts_stock_apres()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_qte_base numeric(14, 4);
  v_qte_a_transferer numeric(14, 4);
  v_lot_src record;
  v_qte_prise numeric(14, 4);
  v_lot_dst_id uuid;
begin
  perform app.rpc_de_confiance(true);
  v_qte_base := new.quantite * new.facteur;
  v_qte_a_transferer := v_qte_base;

  -- Déduction FIFO des lots dans la boutique source
  for v_lot_src in
    select * from public.lots_stock
    where entreprise_id = new.entreprise_id
      and perimetre_id = new.de_perimetre_id
      and produit_id = new.produit_id
      and quantite_restante > 0
      and deleted_at is null
      and statut = 'ACTIF'
    order by date_reception asc, date_achat asc, id asc
    for update
  loop
    exit when v_qte_a_transferer <= 0;
    v_qte_prise := least(v_qte_a_transferer, v_lot_src.quantite_restante);
    v_qte_a_transferer := v_qte_a_transferer - v_qte_prise;

    update public.lots_stock
    set quantite_restante = quantite_restante - v_qte_prise,
        statut = case when quantite_restante - v_qte_prise = 0 then 'EPUISE' else 'ACTIF' end
    where id = v_lot_src.id;

    -- Création d'un lot dans la boutique destinataire au coût d'acquisition exact (pas de gain artificiel)
    v_lot_dst_id := gen_random_uuid();
    insert into public.lots_stock (
      id, entreprise_id, perimetre_id, produit_id, reference, date_achat, date_reception,
      quantite_initiale, quantite_restante, prix_achat_unitaire, prix_vente_unitaire,
      fournisseur_id, lot_origine_id, statut, created_by
    ) values (
      v_lot_dst_id, new.entreprise_id, new.vers_perimetre_id, new.produit_id,
      'TRF-' || v_lot_src.reference, v_lot_src.date_achat, new.date_transfert,
      v_qte_prise, v_qte_prise, v_lot_src.prix_achat_unitaire, v_lot_src.prix_vente_unitaire,
      v_lot_src.fournisseur_id, v_lot_src.id, 'ACTIF', coalesce(auth.uid(), new.created_by)
    );

    -- Sortie boutique source
    insert into public.mouvements_stock (
      entreprise_id, perimetre_id, produit_id, type, motif, quantite,
      quantite_saisie, unite_saisie, facteur, origine_type, origine_id,
      note, date_mouvement, created_by, lot_id
    ) values (
      new.entreprise_id, new.de_perimetre_id, new.produit_id, 'TRANSFERT_SORTIE', 'TRANSFERT',
      v_qte_prise, v_qte_prise / new.facteur, new.unite_saisie, new.facteur, 'TRANSFERT', new.id,
      new.note, new.date_transfert, coalesce(auth.uid(), new.created_by), v_lot_src.id
    );

    -- Entrée boutique destinataire
    insert into public.mouvements_stock (
      entreprise_id, perimetre_id, produit_id, type, motif, quantite,
      quantite_saisie, unite_saisie, facteur, origine_type, origine_id,
      note, date_mouvement, created_by, lot_id
    ) values (
      new.entreprise_id, new.vers_perimetre_id, new.produit_id, 'TRANSFERT_ENTREE', 'TRANSFERT',
      v_qte_prise, v_qte_prise / new.facteur, new.unite_saisie, new.facteur, 'TRANSFERT', new.id,
      new.note, new.date_transfert, coalesce(auth.uid(), new.created_by), v_lot_dst_id
    );
  end loop;

  -- Si reliquat sans lots dans la boutique source
  if v_qte_a_transferer > 0 then
    insert into public.mouvements_stock (
      entreprise_id, perimetre_id, produit_id, type, motif, quantite,
      quantite_saisie, unite_saisie, facteur, origine_type, origine_id,
      note, date_mouvement, created_by
    ) values (
      new.entreprise_id, new.de_perimetre_id, new.produit_id, 'TRANSFERT_SORTIE', 'TRANSFERT',
      v_qte_a_transferer, v_qte_a_transferer / new.facteur, new.unite_saisie, new.facteur, 'TRANSFERT', new.id,
      new.note, new.date_transfert, coalesce(auth.uid(), new.created_by)
    );
    insert into public.mouvements_stock (
      id, entreprise_id, perimetre_id, produit_id, type, motif, quantite,
      quantite_saisie, unite_saisie, facteur, origine_type, origine_id,
      note, date_mouvement, created_by
    ) values (
      new.mouvement_entree_id, new.entreprise_id, new.vers_perimetre_id, new.produit_id, 'TRANSFERT_ENTREE', 'TRANSFERT',
      v_qte_a_transferer, v_qte_a_transferer / new.facteur, new.unite_saisie, new.facteur, 'TRANSFERT', new.id,
      new.note, new.date_transfert, coalesce(auth.uid(), new.created_by)
    );
  end if;

  perform app.rpc_de_confiance(false);
  return null;
end;
$$;

-- 8. Migration et Reprise Progressive des Données Existantes
-- Pour tous les stocks actuels > 0 sans lot associé, créer un lot initialisé propre
insert into public.lots_stock (
  id, entreprise_id, perimetre_id, produit_id, reference, date_achat, date_reception,
  quantite_initiale, quantite_restante, prix_achat_unitaire, prix_vente_unitaire,
  statut, created_at
)
select
  gen_random_uuid(),
  s.entreprise_id,
  s.perimetre_id,
  s.produit_id,
  'LOT-INIT-' || upper(substring(replace(s.id::text, '-', '') from 1 for 6)),
  coalesce(p.created_at, now()),
  coalesce(p.created_at, now()),
  s.quantite,
  s.quantite,
  coalesce(p.prix_achat, 0),
  coalesce(p.prix_detail, 0),
  'ACTIF',
  now()
from public.stocks s
join public.produits p on p.id = s.produit_id
where s.quantite > 0
  and not exists (
    select 1 from public.lots_stock ls
    where ls.perimetre_id = s.perimetre_id and ls.produit_id = s.produit_id
  );

-- 9. Mise à jour de la fonction analytique Bénéfice Commerce avec COGS Réel issu des Lots
create or replace function app.calculer_benefice_commerce(
  p_entreprise_id uuid,
  p_perimetre_id uuid default null,
  p_date_debut timestamptz default null,
  p_date_fin timestamptz default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_debut timestamptz;
  v_fin timestamptz;
  v_debut_prec timestamptz;
  v_fin_prec timestamptz;
  v_duree interval;

  v_ca_brut bigint := 0;
  v_remises bigint := 0;
  v_ca_net bigint := 0;
  v_nb_ventes integer := 0;
  v_cogs bigint := 0;
  v_nb_lignes_total integer := 0;
  v_nb_lignes_avec_cout integer := 0;
  v_marge_brute bigint := 0;
  v_taux_marge numeric(6, 2) := 0;
  v_depenses_commerciales bigint := 0;
  v_benefice_net bigint := 0;
  v_taux_benefice_net numeric(6, 2) := 0;
  v_taux_couverture_cout numeric(6, 2) := 0;

  v_ca_net_prec bigint := 0;
  v_cogs_prec bigint := 0;
  v_marge_brute_prec bigint := 0;
  v_depenses_prec bigint := 0;
  v_benefice_net_prec bigint := 0;

  v_total_encaisse bigint := 0;
  v_total_decaisse bigint := 0;
  v_solde_tresorerie bigint := 0;
  v_creances_restantes bigint := 0;

  v_points_evolution jsonb := '[]'::jsonb;
  v_repartition_depenses jsonb := '[]'::jsonb;
  v_produits_rentabilite jsonb := '[]'::jsonb;
  v_produits_cout_manquant jsonb := '[]'::jsonb;
begin
  if not app.peut(p_entreprise_id, 'commerce.ventes', 'sales.view', p_perimetre_id) then
    perform app.refuser('ACCES_REFUSE');
  end if;

  v_fin := coalesce(p_date_fin, now());
  v_debut := coalesce(p_date_debut, date_trunc('month', now()));
  if v_debut > v_fin then
    v_debut := date_trunc('month', v_fin);
  end if;

  v_duree := v_fin - v_debut;
  v_fin_prec := v_debut - interval '1 second';
  v_debut_prec := v_fin_prec - v_duree;

  select
    coalesce(count(*), 0),
    coalesce(sum(v.total + v.remise), 0),
    coalesce(sum(v.remise), 0),
    coalesce(sum(v.total), 0)
  into v_nb_ventes, v_ca_brut, v_remises, v_ca_net
  from public.ventes v
  where v.entreprise_id = p_entreprise_id
    and (p_perimetre_id is null or v.perimetre_id = p_perimetre_id)
    and v.statut = 'VALIDEE'
    and v.date_vente >= v_debut
    and v.date_vente <= v_fin;

  select coalesce(sum(v.total), 0)
  into v_ca_net_prec
  from public.ventes v
  where v.entreprise_id = p_entreprise_id
    and (p_perimetre_id is null or v.perimetre_id = p_perimetre_id)
    and v.statut = 'VALIDEE'
    and v.date_vente >= v_debut_prec
    and v.date_vente <= v_fin_prec;

  -- 4. Coût Réel des Marchandises Vendues (COGS) issu des lots ou du produit
  with lignes_extraites as (
    select
      v.id as vente_id,
      v.date_vente,
      (l->>'produit_id')::uuid as produit_id,
      (l->>'quantite')::numeric as quantite,
      coalesce((l->>'facteur')::numeric, 1) as facteur,
      coalesce((l->>'prix_unitaire')::bigint, 0) as prix_unitaire,
      (l->>'cout_total')::bigint as cout_total_lot,
      l->>'unite' as unite_nom
    from public.ventes v,
    jsonb_array_elements(v.lignes) l
    where v.entreprise_id = p_entreprise_id
      and (p_perimetre_id is null or v.perimetre_id = p_perimetre_id)
      and v.statut = 'VALIDEE'
      and v.date_vente >= v_debut
      and v.date_vente <= v_fin
  ),
  lignes_valorisees as (
    select
      le.vente_id,
      le.produit_id,
      p.nom as produit_nom,
      le.quantite,
      le.facteur,
      le.unite_nom,
      (le.quantite * le.facteur) as qte_base,
      (le.quantite * le.prix_unitaire)::bigint as ca_ligne,
      case
        when le.cout_total_lot is not null and le.cout_total_lot > 0 then
          round(le.cout_total_lot::numeric / nullif(le.quantite * le.facteur, 0))::bigint
        else p.prix_achat
      end as cout_unitaire_base,
      case
        when le.cout_total_lot is not null and le.cout_total_lot > 0 then
          le.cout_total_lot
        when p.prix_achat is not null and p.prix_achat > 0 then
          round(le.quantite * le.facteur * p.prix_achat)::bigint
        else 0
      end as cout_total_ligne,
      (le.cout_total_lot is not null and le.cout_total_lot > 0) or (p.prix_achat is not null and p.prix_achat > 0) as cout_renseigne
    from lignes_extraites le
    join public.produits p on p.id = le.produit_id and p.entreprise_id = p_entreprise_id
  )
  select
    coalesce(count(*), 0),
    coalesce(sum(case when cout_renseigne then 1 else 0 end), 0),
    coalesce(sum(cout_total_ligne), 0)
  into v_nb_lignes_total, v_nb_lignes_avec_cout, v_cogs
  from lignes_valorisees;

  with lignes_prec as (
    select
      coalesce(
        (l->>'cout_total')::bigint,
        round((l->>'quantite')::numeric * coalesce((l->>'facteur')::numeric, 1) * coalesce(p.prix_achat, 0))::bigint
      ) as cout_ligne
    from public.ventes v,
    jsonb_array_elements(v.lignes) l
    join public.produits p on p.id = (l->>'produit_id')::uuid and p.entreprise_id = p_entreprise_id
    where v.entreprise_id = p_entreprise_id
      and (p_perimetre_id is null or v.perimetre_id = p_perimetre_id)
      and v.statut = 'VALIDEE'
      and v.date_vente >= v_debut_prec
      and v.date_vente <= v_fin_prec
  )
  select coalesce(sum(cout_ligne), 0)
  into v_cogs_prec
  from lignes_prec;

  v_marge_brute := v_ca_net - v_cogs;
  if v_ca_net > 0 then
    v_taux_marge := round((v_marge_brute::numeric / v_ca_net::numeric) * 100, 2);
  else
    v_taux_marge := 0;
  end if;

  if v_nb_lignes_total > 0 then
    v_taux_couverture_cout := round((v_nb_lignes_avec_cout::numeric / v_nb_lignes_total::numeric) * 100, 2);
  else
    v_taux_couverture_cout := 100;
  end if;

  v_marge_brute_prec := v_ca_net_prec - v_cogs_prec;

  -- 5. Dépenses Commerciales Imputables
  select coalesce(sum(d.montant), 0)
  into v_depenses_commerciales
  from public.depenses d
  where d.entreprise_id = p_entreprise_id
    and (d.activite_code = 'COMMERCE' or d.activite_code is null)
    and d.statut = 'ENREGISTREE'
    and d.deleted_at is null
    and ((p_perimetre_id is not null and d.perimetre_id = p_perimetre_id) or (p_perimetre_id is null))
    and d.date_depense >= v_debut::date
    and d.date_depense <= v_fin::date;

  select coalesce(sum(d.montant), 0)
  into v_depenses_prec
  from public.depenses d
  where d.entreprise_id = p_entreprise_id
    and (d.activite_code = 'COMMERCE' or d.activite_code is null)
    and d.statut = 'ENREGISTREE'
    and d.deleted_at is null
    and ((p_perimetre_id is not null and d.perimetre_id = p_perimetre_id) or (p_perimetre_id is null))
    and d.date_depense >= v_debut_prec::date
    and d.date_depense <= v_fin_prec::date;

  v_benefice_net := v_marge_brute - v_depenses_commerciales;
  v_benefice_net_prec := v_marge_brute_prec - v_depenses_prec;

  if v_ca_net > 0 then
    v_taux_benefice_net := round((v_benefice_net::numeric / v_ca_net::numeric) * 100, 2);
  else
    v_taux_benefice_net := 0;
  end if;

  -- 6. Trésorerie Réelle sur la Période
  select coalesce(sum(p.montant), 0)
  into v_total_encaisse
  from public.paiements p
  where p.entreprise_id = p_entreprise_id
    and (p_perimetre_id is null or p.perimetre_id = p_perimetre_id)
    and p.sens = 'ENTREE'
    and p.statut = 'VALIDE'
    and p.date_paiement >= v_debut
    and p.date_paiement <= v_fin;

  select coalesce(sum(p.montant), 0)
  into v_total_decaisse
  from public.paiements p
  where p.entreprise_id = p_entreprise_id
    and ((p_perimetre_id is not null and p.perimetre_id = p_perimetre_id) or (p_perimetre_id is null))
    and p.sens = 'SORTIE'
    and p.statut = 'VALIDE'
    and p.date_paiement >= v_debut
    and p.date_paiement <= v_fin;

  v_solde_tresorerie := v_total_encaisse - v_total_decaisse;

  select coalesce(sum(e.montant_total - e.montant_regle), 0)
  into v_creances_restantes
  from public.engagements e
  where e.entreprise_id = p_entreprise_id
    and (p_perimetre_id is null or e.perimetre_id = p_perimetre_id)
    and e.sens = 'A_RECEVOIR'
    and e.origine_type = 'VENTE'
    and e.statut = 'OUVERT'
    and (e.montant_total - e.montant_regle) > 0;

  -- 7. Répartition des dépenses par catégorie
  select coalesce(jsonb_agg(jsonb_build_object(
    'categorie_id', c.id,
    'categorie_nom', coalesce(c.nom, 'Autres charges'),
    'icone', c.icone,
    'couleur', c.couleur,
    'total', agg.somme,
    'pourcentage', case when v_depenses_commerciales > 0
                        then round((agg.somme::numeric / v_depenses_commerciales::numeric) * 100, 1)
                        else 0 end
  ) order by agg.somme desc), '[]'::jsonb)
  into v_repartition_depenses
  from (
    select d.categorie_id, sum(d.montant) as somme
    from public.depenses d
    where d.entreprise_id = p_entreprise_id
      and (d.activite_code = 'COMMERCE' or d.activite_code is null)
      and d.statut = 'ENREGISTREE'
      and d.deleted_at is null
      and ((p_perimetre_id is not null and d.perimetre_id = p_perimetre_id) or (p_perimetre_id is null))
      and d.date_depense >= v_debut::date
      and d.date_depense <= v_fin::date
    group by d.categorie_id
  ) agg
  join public.depense_categories c on c.id = agg.categorie_id;

  -- 8. Top 15 Produits par Bénéfice / Marge
  with lignes_prod as (
    select
      (l->>'produit_id')::uuid as produit_id,
      sum((l->>'quantite')::numeric * coalesce((l->>'facteur')::numeric, 1)) as qte_totale,
      sum((l->>'quantite')::numeric * coalesce((l->>'prix_unitaire')::bigint, 0))::bigint as ca_total,
      sum(coalesce(
        (l->>'cout_total')::bigint,
        round((l->>'quantite')::numeric * coalesce((l->>'facteur')::numeric, 1) * coalesce(p.prix_achat, 0))::bigint
      )) as cogs_total
    from public.ventes v,
    jsonb_array_elements(v.lignes) l
    left join public.produits p on p.id = (l->>'produit_id')::uuid and p.entreprise_id = p_entreprise_id
    where v.entreprise_id = p_entreprise_id
      and (p_perimetre_id is null or v.perimetre_id = p_perimetre_id)
      and v.statut = 'VALIDEE'
      and v.date_vente >= v_debut
      and v.date_vente <= v_fin
    group by (l->>'produit_id')::uuid
  ),
  top_produits as (
    select
      p.id as produit_id,
      p.nom,
      p.reference,
      p.unite_base,
      lp.qte_totale as quantite_vendue,
      lp.ca_total as chiffre_affaires,
      p.prix_achat as cout_achat_unitaire,
      lp.cogs_total as cogs,
      (lp.ca_total - lp.cogs_total) as marge_brute,
      (lp.cogs_total = 0 and (p.prix_achat is null or p.prix_achat = 0)) as cout_manquant
    from lignes_prod lp
    join public.produits p on p.id = lp.produit_id and p.entreprise_id = p_entreprise_id
    order by (lp.ca_total - lp.cogs_total) desc
    limit 15
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'produit_id', tp.produit_id,
    'nom', tp.nom,
    'reference', tp.reference,
    'unite_base', tp.unite_base,
    'quantite_vendue', tp.quantite_vendue,
    'chiffre_affaires', tp.chiffre_affaires,
    'cout_achat_unitaire', tp.cout_achat_unitaire,
    'cogs', tp.cogs,
    'marge_brute', tp.marge_brute,
    'cout_manquant', tp.cout_manquant
  )), '[]'::jsonb)
  into v_produits_rentabilite
  from top_produits tp;

  -- 9. Produits vendus sans coût de revient (Top 10)
  with sans_cout as (
    select distinct p.id as produit_id, p.nom, p.reference, p.unite_base
    from (
      select distinct (l->>'produit_id')::uuid as produit_id
      from public.ventes v,
      jsonb_array_elements(v.lignes) l
      where v.entreprise_id = p_entreprise_id
        and (p_perimetre_id is null or v.perimetre_id = p_perimetre_id)
        and v.statut = 'VALIDEE'
        and v.date_vente >= v_debut
        and v.date_vente <= v_fin
        and coalesce((l->>'cout_total')::bigint, 0) = 0
    ) x
    join public.produits p on p.id = x.produit_id and p.entreprise_id = p_entreprise_id
    where p.prix_achat is null or p.prix_achat = 0
    limit 10
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'produit_id', sc.produit_id,
    'nom', sc.nom,
    'reference', sc.reference,
    'unite_base', sc.unite_base
  )), '[]'::jsonb)
  into v_produits_cout_manquant
  from sans_cout sc;

  -- 10. Série chronologique
  if v_duree <= interval '35 days' then
    select coalesce(jsonb_agg(jsonb_build_object(
      'date', s.jour::date,
      'label', to_char(s.jour, 'DD Mon'),
      'chiffre_affaires', coalesce(v_agg.ca, 0),
      'cogs', coalesce(v_agg.cout, 0),
      'marge_brute', coalesce(v_agg.ca, 0) - coalesce(v_agg.cout, 0),
      'depenses', coalesce(d_agg.dep, 0),
      'benefice_net', (coalesce(v_agg.ca, 0) - coalesce(v_agg.cout, 0)) - coalesce(d_agg.dep, 0)
    ) order by s.jour), '[]'::jsonb)
    into v_points_evolution
    from generate_series(v_debut::date, v_fin::date, interval '1 day') s(jour)
    left join (
      with lv as (
        select
          v.date_vente::date as jour,
          v.total as total_vente,
          coalesce(
            (l->>'cout_total')::bigint,
            round((l->>'quantite')::numeric * coalesce((l->>'facteur')::numeric, 1) * coalesce(p.prix_achat, 0))::bigint
          ) as cout_ligne
        from public.ventes v,
        jsonb_array_elements(v.lignes) l
        left join public.produits p on p.id = (l->>'produit_id')::uuid and p.entreprise_id = p_entreprise_id
        where v.entreprise_id = p_entreprise_id
          and (p_perimetre_id is null or v.perimetre_id = p_perimetre_id)
          and v.statut = 'VALIDEE'
          and v.date_vente >= v_debut
          and v.date_vente <= v_fin
      )
      select
        jour,
        coalesce(sum(distinct total_vente), sum(total_vente)) as ca,
        coalesce(sum(cout_ligne), 0) as cout
      from lv
      group by jour
    ) v_agg on v_agg.jour = s.jour::date
    left join (
      select
        d.date_depense as jour,
        sum(d.montant) as dep
      from public.depenses d
      where d.entreprise_id = p_entreprise_id
        and (d.activite_code = 'COMMERCE' or d.activite_code is null)
        and d.statut = 'ENREGISTREE'
        and d.deleted_at is null
        and ((p_perimetre_id is not null and d.perimetre_id = p_perimetre_id) or (p_perimetre_id is null))
        and d.date_depense >= v_debut::date
        and d.date_depense <= v_fin::date
      group by d.date_depense
    ) d_agg on d_agg.jour = s.jour::date;
  else
    select coalesce(jsonb_agg(jsonb_build_object(
      'date', s.mois::date,
      'label', to_char(s.mois, 'Mon YYYY'),
      'chiffre_affaires', coalesce(v_agg.ca, 0),
      'cogs', coalesce(v_agg.cout, 0),
      'marge_brute', coalesce(v_agg.ca, 0) - coalesce(v_agg.cout, 0),
      'depenses', coalesce(d_agg.dep, 0),
      'benefice_net', (coalesce(v_agg.ca, 0) - coalesce(v_agg.cout, 0)) - coalesce(d_agg.dep, 0)
    ) order by s.mois), '[]'::jsonb)
    into v_points_evolution
    from generate_series(date_trunc('month', v_debut), date_trunc('month', v_fin), interval '1 month') s(mois)
    left join (
      with lv as (
        select
          date_trunc('month', v.date_vente) as mois,
          v.total as total_vente,
          coalesce(
            (l->>'cout_total')::bigint,
            round((l->>'quantite')::numeric * coalesce((l->>'facteur')::numeric, 1) * coalesce(p.prix_achat, 0))::bigint
          ) as cout_ligne
        from public.ventes v,
        jsonb_array_elements(v.lignes) l
        left join public.produits p on p.id = (l->>'produit_id')::uuid and p.entreprise_id = p_entreprise_id
        where v.entreprise_id = p_entreprise_id
          and (p_perimetre_id is null or v.perimetre_id = p_perimetre_id)
          and v.statut = 'VALIDEE'
          and v.date_vente >= v_debut
          and v.date_vente <= v_fin
      )
      select
        mois,
        coalesce(sum(distinct total_vente), sum(total_vente)) as ca,
        coalesce(sum(cout_ligne), 0) as cout
      from lv
      group by mois
    ) v_agg on v_agg.mois = s.mois
    left join (
      select
        date_trunc('month', d.date_depense::timestamptz) as mois,
        sum(d.montant) as dep
      from public.depenses d
      where d.entreprise_id = p_entreprise_id
        and (d.activite_code = 'COMMERCE' or d.activite_code is null)
        and d.statut = 'ENREGISTREE'
        and d.deleted_at is null
        and ((p_perimetre_id is not null and d.perimetre_id = p_perimetre_id) or (p_perimetre_id is null))
        and d.date_depense >= v_debut::date
        and d.date_depense <= v_fin::date
      group by date_trunc('month', d.date_depense::timestamptz)
    ) d_agg on d_agg.mois = s.mois;
  end if;

  return jsonb_build_object(
    'succes', true,
    'entreprise_id', p_entreprise_id,
    'perimetre_id', p_perimetre_id,
    'date_debut', v_debut,
    'date_fin', v_fin,
    'kpi', jsonb_build_object(
      'chiffre_affaires_brut', v_ca_brut,
      'remises', v_remises,
      'chiffre_affaires_net', v_ca_net,
      'chiffre_affaires_precedent', v_ca_net_prec,
      'nombre_ventes', v_nb_ventes,
      'cogs', v_cogs,
      'cogs_precedent', v_cogs_prec,
      'marge_brute', v_marge_brute,
      'marge_brute_precedente', v_marge_brute_prec,
      'taux_marge', v_taux_marge,
      'depenses_commerciales', v_depenses_commerciales,
      'depenses_precedentes', v_depenses_prec,
      'benefice_net_estime', v_benefice_net,
      'benefice_net_precedent', v_benefice_net_prec,
      'taux_benefice_net', v_taux_benefice_net,
      'taux_couverture_cout', v_taux_couverture_cout,
      'lignes_total', v_nb_lignes_total,
      'lignes_avec_cout', v_nb_lignes_avec_cout
    ),
    'tresorerie', jsonb_build_object(
      'total_encaisse', v_total_encaisse,
      'total_decaisse', v_total_decaisse,
      'solde_net_flux', v_solde_tresorerie,
      'creances_clients_restantes', v_creances_restantes
    ),
    'repartition_depenses', v_repartition_depenses,
    'produits_rentabilite', v_produits_rentabilite,
    'produits_cout_manquant', v_produits_cout_manquant,
    'evolution', v_points_evolution
  );
end;
$$;

