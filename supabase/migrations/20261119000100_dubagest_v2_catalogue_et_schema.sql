-- =============================================================================
-- DUBAGEST V2 — FONDATION DU CATALOGUE NUMÉRIQUE & PLAN CATALOGUE SEUL
-- Migration : 20261119000100_dubagest_v2_catalogue_et_schema.sql
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. EXTENSION DE LA TABLE PUBLIC.ENTREPRISES POUR LE CATALOGUE
-- -----------------------------------------------------------------------------

alter table public.entreprises
  add column if not exists slug text,
  add column if not exists whatsapp_commercial text,
  add column if not exists description_commerciale text,
  add column if not exists logo_url text,
  add column if not exists couverture_url text,
  add column if not exists est_catalogue_actif boolean not null default true;

-- Index unique sur le slug public de la boutique
create unique index if not exists entreprises_slug_idx
  on public.entreprises (lower(trim(slug)))
  where slug is not null and slug <> '';

-- Fonction trigger pour générer un slug automatique basé sur le nom
create or replace function app.generer_slug_boutique()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_base_slug text;
  v_slug text;
  v_counter integer := 1;
begin
  if new.slug is null or trim(new.slug) = '' then
    -- Nettoyage des caractères spéciaux et accents
    v_base_slug := lower(regexp_replace(trim(new.nom), '[^a-zA-Z0-9]+', '-', 'g'));
    v_base_slug := trim(both '-' from v_base_slug);
    if v_base_slug = '' or v_base_slug is null then
      v_base_slug := 'boutique-' || substr(new.id::text, 1, 8);
    end if;

    v_slug := v_base_slug;
    while exists (
      select 1 from public.entreprises
      where lower(trim(slug)) = v_slug
      and id <> new.id
    ) loop
      v_counter := v_counter + 1;
      v_slug := v_base_slug || '-' || v_counter;
    end loop;
    new.slug := v_slug;
  else
    new.slug := lower(trim(new.slug));
  end if;
  return new;
end;
$$;

drop trigger if exists trg_generer_slug_boutique on public.entreprises;
create trigger trg_generer_slug_boutique
  before insert or update of nom, slug on public.entreprises
  for each row execute function app.generer_slug_boutique();

-- Rétrocompatibilité : Générer les slugs uniques pour les entreprises existantes
with num_entreprises as (
  select id, nom,
         row_number() over (
           partition by lower(regexp_replace(trim(nom), '[^a-zA-Z0-9]+', '-', 'g'))
           order by created_at asc
         ) as rn,
         coalesce(nullif(trim(both '-' from lower(regexp_replace(trim(nom), '[^a-zA-Z0-9]+', '-', 'g'))), ''), 'boutique') as base_slug
  from public.entreprises
  where slug is null or slug = ''
)
update public.entreprises e
set slug = case
  when n.rn = 1 then n.base_slug
  else n.base_slug || '-' || n.rn
end
from num_entreprises n
where e.id = n.id;

-- -----------------------------------------------------------------------------
-- 2. EXTENSION DE LA TABLE PUBLIC.PRODUITS POUR LE CATALOGUE V2
-- -----------------------------------------------------------------------------

alter table public.produits
  add column if not exists est_publie_catalogue boolean not null default false,
  add column if not exists prix_public bigint check (prix_public is null or prix_public >= 0),
  add column if not exists prix_barre bigint check (prix_barre is null or prix_barre >= 0),
  add column if not exists photos_v2 jsonb not null default '[]'::jsonb check (jsonb_typeof(photos_v2) = 'array'),
  add column if not exists audio_presentation_url text,
  add column if not exists video_presentation_url text,
  add column if not exists collection_id uuid;

-- -----------------------------------------------------------------------------
-- 3. NOUVELLES TABLES CATALOGUE V2 (COLLECTIONS, NOUVEAUTÉS, STATISTIQUES)
-- -----------------------------------------------------------------------------

-- Collections / Rayons du catalogue public
create table if not exists public.catalogue_collections (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  nom text not null check (char_length(trim(nom)) between 1 and 100),
  description text check (char_length(description) <= 500),
  image_url text,
  ordre integer not null default 0,
  est_actif boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists catalogue_collections_entreprise_idx
  on public.catalogue_collections (entreprise_id, ordre);

alter table public.catalogue_collections enable row level security;

-- Nouveautés & Arrivages (Stories commerciales temporaires : 24h, 48h, 7j ou permanent)
create table if not exists public.catalogue_nouveautes (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  titre text not null check (char_length(trim(titre)) between 1 and 120),
  message text check (char_length(message) <= 1000),
  type_media text not null default 'IMAGE' check (type_media in ('IMAGE', 'VIDEO')),
  media_url text not null,
  duree_visibilite text not null default '24H' check (duree_visibilite in ('24H', '48H', '7D', 'PERMANENT')),
  expire_a timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists catalogue_nouveautes_entreprise_expire_idx
  on public.catalogue_nouveautes (entreprise_id, expire_a);

alter table public.catalogue_nouveautes enable row level security;

-- Statistiques et télémétrie de clics (Anonyme, zéro traçage intrusif)
create table if not exists public.catalogue_statistiques (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  produit_id uuid references public.produits (id) on delete cascade,
  type_evenement text not null check (type_evenement in ('VUE_CATALOGUE', 'VUE_PRODUIT', 'CLIC_WHATSAPP')),
  date_evenement timestamptz not null default now()
);

create index if not exists catalogue_statistiques_entreprise_date_idx
  on public.catalogue_statistiques (entreprise_id, date_evenement);

alter table public.catalogue_statistiques enable row level security;

-- -----------------------------------------------------------------------------
-- 4. INSERTION DE LA FORMULE "CATALOGUE_SEUL" DANS LE CATALOGUE DES PLANS
-- -----------------------------------------------------------------------------

insert into public.plans (
  code, nom, description, max_activites, ordre, prix_mensuel, devise_prix, est_actif
)
values (
  'CATALOGUE_SEUL',
  'Catalogue Seul',
  'Vitrine numérique commerciale, messages vocaux, vidéos courtes et commandes WhatsApp.',
  1,
  0,
  250, -- 3 000 FCFA / an
  'XOF',
  true
)
on conflict (code) do update set
  nom = excluded.nom,
  description = excluded.description,
  max_activites = excluded.max_activites,
  prix_mensuel = excluded.prix_mensuel,
  devise_prix = excluded.devise_prix,
  est_actif = excluded.est_actif,
  updated_at = now();

-- Quotas d'activité : Commerce uniquement
insert into public.plan_activites (plan_code, activite_code, max_utilisateurs, max_perimetres)
values ('CATALOGUE_SEUL', 'COMMERCE', 1, 1)
on conflict (plan_code, activite_code) do update set
  max_utilisateurs = excluded.max_utilisateurs,
  max_perimetres = excluded.max_perimetres;

-- Rôles autorisés : Administrateur (1 membre)
insert into public.plan_roles (plan_code, role_code, max_membres)
values ('CATALOGUE_SEUL', 'ADMINISTRATEUR', 1)
on conflict (plan_code, role_code) do update set
  max_membres = excluded.max_membres;

-- Modules autorisés pour le Mode B (Zéro module de stock/ventes/achats/finances)
insert into public.plan_modules (plan_code, module_code)
values
  ('CATALOGUE_SEUL', 'commerce.produits'),
  ('CATALOGUE_SEUL', 'admin.entreprise'),
  ('CATALOGUE_SEUL', 'admin.abonnement')
on conflict (plan_code, module_code) do nothing;

-- Tarif officiel annuel dans tarifs_durees_plans : 3 000 FCFA / an
insert into public.tarifs_durees_plans (
  plan_code, duree_mois, montant_total, remise_pourcentage, badge_promo, description, est_actif
)
values (
  'CATALOGUE_SEUL',
  12,
  3000,
  0,
  'Formule Annuelle',
  'Abonnement annuel Catalogue Seul à 3 000 FCFA / an',
  true
)
on conflict (plan_code, duree_mois) do update set
  montant_total = excluded.montant_total,
  remise_pourcentage = excluded.remise_pourcentage,
  badge_promo = excluded.badge_promo,
  description = excluded.description,
  est_actif = true,
  updated_at = now();

-- -----------------------------------------------------------------------------
-- 5. VERROU STRICT DU MODE B (INTERDICTION D'ÉCRITURE SUR MODULES DE GESTION)
-- -----------------------------------------------------------------------------

create or replace function app.verifier_interdiction_gestion_catalogue_seul()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_eid uuid;
  v_plan_code text;
begin
  v_eid := new.entreprise_id;
  if v_eid is null then
    return new;
  end if;

  select a.plan_code into v_plan_code
  from public.abonnements a
  where a.entreprise_id = v_eid
    and a.statut in ('ESSAI', 'ACTIF', 'SUSPENDU')
  order by a.created_at desc
  limit 1;

  if v_plan_code = 'CATALOGUE_SEUL' then
    perform app.refuser('PLAN_CATALOGUE_SEUL_GESTION_INTERDITE');
  end if;

  return new;
end;
$$;

-- Triggers de protection sur les tables de gestion comptable
drop trigger if exists trg_catalogue_seul_bloquer_ventes on public.ventes;
create trigger trg_catalogue_seul_bloquer_ventes
  before insert or update on public.ventes
  for each row execute function app.verifier_interdiction_gestion_catalogue_seul();

drop trigger if exists trg_catalogue_seul_bloquer_achats on public.achats;
create trigger trg_catalogue_seul_bloquer_achats
  before insert or update on public.achats
  for each row execute function app.verifier_interdiction_gestion_catalogue_seul();

drop trigger if exists trg_catalogue_seul_bloquer_caisses on public.caisse_mouvements;
create trigger trg_catalogue_seul_bloquer_caisses
  before insert or update on public.caisse_mouvements
  for each row execute function app.verifier_interdiction_gestion_catalogue_seul();

drop trigger if exists trg_catalogue_seul_bloquer_depenses on public.depenses;
create trigger trg_catalogue_seul_bloquer_depenses
  before insert or update on public.depenses
  for each row execute function app.verifier_interdiction_gestion_catalogue_seul();

-- -----------------------------------------------------------------------------
-- 6. POLITIQUES RLS DU CATALOGUE NUMÉRIQUE PUBLIC (VISITEURS SANS AUTHENTIFICATION)
-- -----------------------------------------------------------------------------

-- Lecture publique de la boutique par son slug ou ID
create policy entreprises_lecture_catalogue_public on public.entreprises
  for select
  to anon, authenticated
  using (est_catalogue_actif = true and slug is not null and slug <> '');

-- Lecture publique des produits publiés au catalogue
create policy produits_lecture_catalogue_public on public.produits
  for select
  to anon, authenticated
  using (
    deleted_at is null
    and est_actif = true
    and est_publie_catalogue = true
    and exists (
      select 1 from public.entreprises e
      where e.id = produits.entreprise_id
      and e.est_catalogue_actif = true
    )
  );

-- Lecture publique des collections
create policy collections_lecture_catalogue_public on public.catalogue_collections
  for select
  to anon, authenticated
  using (
    est_actif = true
    and exists (
      select 1 from public.entreprises e
      where e.id = catalogue_collections.entreprise_id
      and e.est_catalogue_actif = true
    )
  );

-- Gestion interne des collections pour les membres de l'entreprise
create policy collections_gestion_entreprise on public.catalogue_collections
  for all
  to authenticated
  using (app.est_membre(entreprise_id))
  with check (app.est_membre(entreprise_id));

-- Lecture publique des nouveautés actives (non expirées)
create policy nouveautes_lecture_catalogue_public on public.catalogue_nouveautes
  for select
  to anon, authenticated
  using (
    (expire_a is null or expire_a > now())
    and exists (
      select 1 from public.entreprises e
      where e.id = catalogue_nouveautes.entreprise_id
      and e.est_catalogue_actif = true
    )
  );

-- Gestion interne des nouveautés
create policy nouveautes_gestion_entreprise on public.catalogue_nouveautes
  for all
  to authenticated
  using (app.est_membre(entreprise_id))
  with check (app.est_membre(entreprise_id));

-- Enregistrement des statistiques de visite (Autorisé à anon)
create policy statistiques_enregistrement_public on public.catalogue_statistiques
  for insert
  to anon, authenticated
  with check (
    exists (
      select 1 from public.entreprises e
      where e.id = catalogue_statistiques.entreprise_id
      and e.est_catalogue_actif = true
    )
  );

-- Consultation des statistiques réservée au commerçant
create policy statistiques_consultation_entreprise on public.catalogue_statistiques
  for select
  to authenticated
  using (app.est_membre(entreprise_id));

-- -----------------------------------------------------------------------------
-- 7. FONCTION RPC DE CONSULTATION SÉCURISÉE DU CATALOGUE PUBLIC
-- -----------------------------------------------------------------------------

create or replace function public.consulter_catalogue_public(p_slug_ou_id text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_entreprise record;
  v_resultat jsonb;
begin
  select
    e.id,
    e.nom,
    e.slug,
    e.description_commerciale,
    e.logo_url,
    e.couverture_url,
    e.whatsapp_commercial,
    e.ville,
    e.pays,
    coalesce(e.devise, 'XOF') as devise
  into v_entreprise
  from public.entreprises e
  where (lower(e.slug) = lower(trim(p_slug_ou_id)) or e.id::text = trim(p_slug_ou_id))
    and e.est_catalogue_actif = true
  limit 1;

  if v_entreprise.id is null then
    return null;
  end if;

  select jsonb_build_object(
    'boutique', jsonb_build_object(
      'id', v_entreprise.id,
      'nom', v_entreprise.nom,
      'slug', v_entreprise.slug,
      'description', v_entreprise.description_commerciale,
      'logo_url', v_entreprise.logo_url,
      'couverture_url', v_entreprise.couverture_url,
      'whatsapp', v_entreprise.whatsapp_commercial,
      'ville', v_entreprise.ville,
      'pays', v_entreprise.pays,
      'devise', v_entreprise.devise
    ),
    'collections', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', c.id,
        'nom', c.nom,
        'description', c.description,
        'image_url', c.image_url,
        'ordre', c.ordre
      ) order by c.ordre, c.nom), '[]'::jsonb)
      from public.catalogue_collections c
      where c.entreprise_id = v_entreprise.id
        and c.est_actif = true
    ),
    'nouveautes', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', n.id,
        'titre', n.titre,
        'message', n.message,
        'type_media', n.type_media,
        'media_url', n.media_url,
        'created_at', n.created_at
      ) order by n.created_at desc), '[]'::jsonb)
      from public.catalogue_nouveautes n
      where n.entreprise_id = v_entreprise.id
        and (n.expire_a is null or n.expire_a > now())
    ),
    'produits', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', p.id,
        'nom', p.nom,
        'description', p.description,
        'prix_public', coalesce(p.prix_public, p.prix_detail),
        'prix_barre', p.prix_barre,
        'photos', p.photos,
        'photos_v2', p.photos_v2,
        'audio_url', p.audio_presentation_url,
        'video_url', p.video_presentation_url,
        'collection_id', p.collection_id
      ) order by p.created_at desc), '[]'::jsonb)
      from public.produits p
      where p.entreprise_id = v_entreprise.id
        and p.est_publie_catalogue = true
        and p.est_actif = true
        and p.deleted_at is null
    )
  ) into v_resultat;

  return v_resultat;
end;
$$;

grant execute on function public.consulter_catalogue_public(text) to anon, authenticated;
