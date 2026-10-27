-- Migration : Sécurisation et permissions du rôle SUPERVISEUR
-- Objectif :
-- 1. Révoquer formellement les permissions d'achats fournisseurs (purchases.create, purchases.update) pour le rôle SUPERVISEUR.
-- 2. Empêcher toute entrée manuelle de stock avec motif ACHAT sans la permission purchases.create.
-- 3. Interdire la suppression de produits ayant un historique d'achats, ventes ou mouvements de stock.
-- 4. Exiger une note justificative en cas d'écart négatif d'inventaire pour les rôles opérationnels (SUPERVISEUR, GESTIONNAIRE_STOCK).

-- 1. Révocation des permissions d'achat pour le Superviseur
delete from public.roles_permissions
where role_code = 'SUPERVISEUR'
  and permission_code in (
    'purchases.create',
    'purchases.update'
  );

-- 2. Protection contre la suppression de produits utilisés
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

  -- Protection contre la suppression de produits avec historique (mouvements, ventes, achats)
  if new.deleted_at is not null and (old.deleted_at is null or tg_op = 'DELETE') then
    if exists (select 1 from public.mouvements_stock where produit_id = new.id and entreprise_id = new.entreprise_id)
       or exists (select 1 from public.lignes_ventes where produit_id = new.id and entreprise_id = new.entreprise_id)
       or exists (
         select 1 from public.achats a, jsonb_array_elements(a.lignes) l
         where a.entreprise_id = new.entreprise_id and (l->>'produit_id')::uuid = new.id
       ) then
      perform app.refuser('PRODUIT_UTILISE');
    end if;
  end if;

  return new;
end;
$$;

-- 3. Renforcement du trigger mouvements_stock_avant :
-- Empêcher la simulation d'achats fictifs et exiger une justification sur écart d'inventaire négatif
create or replace function app.tg_mouvements_stock_avant()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_avant numeric(14, 4);
  v_role text;
begin
  if not app.confiance() then
    -- Saisie directe : entrée, sortie, inventaire. Le reste vient des opérations système.
    if new.type not in ('ENTREE', 'SORTIE', 'INVENTAIRE') then
      perform app.refuser('MOUVEMENT_INVALIDE');
    end if;

    perform app.exiger(app.peut(new.entreprise_id, 'commerce.stock',
      case new.type when 'INVENTAIRE' then 'stock.update' else 'stock.create' end, new.perimetre_id));

    if new.type <> 'INVENTAIRE' and new.quantite <= 0 then
      perform app.refuser('QUANTITE_INVALIDE');
    end if;

    -- Interdiction de simuler un achat sans la permission 'purchases.create'
    if new.type = 'ENTREE' and new.motif = 'ACHAT' and not app.a_permission(new.entreprise_id, 'purchases.create') then
      perform app.refuser('PERMISSION_REFUSEE');
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

  -- Justification obligatoire si écart négatif pour les rôles opérationnels
  if new.type = 'INVENTAIRE' and new.delta < 0 and (new.note is null or trim(new.note) = '') then
    select m.role_code into v_role
    from public.membres_entreprise m
    where m.entreprise_id = new.entreprise_id and m.user_id = (select auth.uid());

    if v_role in ('SUPERVISEUR', 'GESTIONNAIRE_STOCK') then
      perform app.refuser('JUSTIFICATION_ECART_REQUISE');
    end if;
  end if;

  -- Stock négatif interdit, sauf pour une vente déjà faite au comptoir
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
