-- =============================================================================
-- DUBAGEST V2 — REFONTE DU MODULE MA VITRINE & SITE CRÉATEUR PROFESSIONNEL
-- Migration : 20261126000100_refonte_ma_vitrine_v2.sql
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. TABLE PRINCIPALE DES VITRINES PERSONNALISÉES
-- -----------------------------------------------------------------------------

create table if not exists public.vitrines (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises(id) on delete cascade unique,
  slug text not null,
  type_activite text not null default 'COMMERCE_GENERAL' check (
    type_activite in (
      'COMMERCE_GENERAL',
      'BOUTIQUE_SPECIALISEE',
      'SALON_COIFFURE',
      'BEAUTE_ESTHETIQUE',
      'PRESTATAIRE_SERVICES',
      'AUTRE'
    )
  ),
  modele_visuel text not null default 'MODELE_A' check (
    modele_visuel in (
      'MODELE_A',
      'MODELE_B',
      'MODELE_C',
      'MODELE_D',
      'MODELE_E'
    )
  ),
  theme_style text not null default 'COMMERCIAL_VERT' check (
    theme_style in (
      'COMMERCIAL_VERT',
      'LUXE_OR',
      'ELEGANT_BEIGE',
      'MODERNE_MINIMAL',
      'NATUREL_CHAUD',
      'SOMBRE_PRO'
    )
  ),
  couleur_principale text not null default '#1E7E4E',
  couleur_secondaire text not null default '#10B981',
  titre_hero text,
  slogan text,
  description text,
  logo_url text,
  banniere_url text,
  photo_presentation_url text,
  audio_presentation_url text,
  sections_actives jsonb not null default '{
    "accueil": true,
    "a_propos": true,
    "produits": true,
    "prestations": false,
    "tarifs": false,
    "galerie": false,
    "equipe": false,
    "rdv": false,
    "horaires": true,
    "contact": true,
    "temoignages": false
  }'::jsonb,
  horaires jsonb not null default '[
    {"jour": "Lundi", "ouvert": true, "ouverture": "08:30", "fermeture": "19:00"},
    {"jour": "Mardi", "ouvert": true, "ouverture": "08:30", "fermeture": "19:00"},
    {"jour": "Mercredi", "ouvert": true, "ouverture": "08:30", "fermeture": "19:00"},
    {"jour": "Jeudi", "ouvert": true, "ouverture": "08:30", "fermeture": "19:00"},
    {"jour": "Vendredi", "ouvert": true, "ouverture": "08:30", "fermeture": "19:00"},
    {"jour": "Samedi", "ouvert": true, "ouverture": "09:00", "fermeture": "20:00"},
    {"jour": "Dimanche", "ouvert": false, "ouverture": "09:00", "fermeture": "14:00"}
  ]'::jsonb,
  adresse text,
  ville text,
  pays text default 'Mali',
  telephone text,
  whatsapp text,
  email text,
  reseaux_sociaux jsonb not null default '{}'::jsonb,
  est_publie boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists vitrines_entreprise_idx on public.vitrines(entreprise_id);
create unique index if not exists vitrines_slug_idx on public.vitrines(lower(trim(slug)));

alter table public.vitrines enable row level security;

-- Politiques RLS vitrines
create policy vitrines_select_publique on public.vitrines
  for select
  using (est_publie = true or app.est_membre(entreprise_id));

create policy vitrines_insert_membre on public.vitrines
  for insert
  to authenticated
  with check (app.est_membre(entreprise_id));

create policy vitrines_update_membre on public.vitrines
  for update
  to authenticated
  using (app.est_membre(entreprise_id))
  with check (app.est_membre(entreprise_id));

create policy vitrines_delete_membre on public.vitrines
  for delete
  to authenticated
  using (app.est_membre(entreprise_id));

-- -----------------------------------------------------------------------------
-- 2. TABLE DES PRESTATIONS ET SOINS VITRINE
-- -----------------------------------------------------------------------------

create table if not exists public.vitrine_prestations (
  id uuid primary key default gen_random_uuid(),
  vitrine_id uuid not null references public.vitrines(id) on delete cascade,
  entreprise_id uuid not null references public.entreprises(id) on delete cascade,
  nom text not null check (char_length(trim(nom)) between 1 and 150),
  description text check (char_length(description) <= 800),
  prix bigint not null default 0 check (prix >= 0),
  prix_barre bigint check (prix_barre is null or prix_barre >= 0),
  duree_minutes integer check (duree_minutes is null or duree_minutes between 5 and 720),
  categorie text check (char_length(categorie) <= 80),
  photo_url text,
  audio_url text,
  ordre integer not null default 0,
  est_actif boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists vitrine_prestations_vitrine_idx
  on public.vitrine_prestations(vitrine_id, ordre);
create index if not exists vitrine_prestations_entreprise_idx
  on public.vitrine_prestations(entreprise_id);

alter table public.vitrine_prestations enable row level security;

create policy vitrine_prestations_select_publique on public.vitrine_prestations
  for select
  using (est_actif = true or app.est_membre(entreprise_id));

create policy vitrine_prestations_write_membre on public.vitrine_prestations
  for all
  to authenticated
  using (app.est_membre(entreprise_id))
  with check (app.est_membre(entreprise_id));

-- -----------------------------------------------------------------------------
-- 3. TABLE DE LA GALERIE & RÉALISATIONS (AVANT / APRÈS)
-- -----------------------------------------------------------------------------

create table if not exists public.vitrine_galerie (
  id uuid primary key default gen_random_uuid(),
  vitrine_id uuid not null references public.vitrines(id) on delete cascade,
  entreprise_id uuid not null references public.entreprises(id) on delete cascade,
  titre text check (char_length(titre) <= 120),
  categorie text check (char_length(categorie) <= 80),
  photo_url text not null,
  photo_avant_url text,
  ordre integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists vitrine_galerie_vitrine_idx
  on public.vitrine_galerie(vitrine_id, ordre);

alter table public.vitrine_galerie enable row level security;

create policy vitrine_galerie_select_publique on public.vitrine_galerie
  for select
  using (true);

create policy vitrine_galerie_write_membre on public.vitrine_galerie
  for all
  to authenticated
  using (app.est_membre(entreprise_id))
  with check (app.est_membre(entreprise_id));

-- -----------------------------------------------------------------------------
-- 4. TABLE DE L'ÉQUIPE & DES COIFFEURS / ESTHÉTICIENNES
-- -----------------------------------------------------------------------------

create table if not exists public.vitrine_equipe (
  id uuid primary key default gen_random_uuid(),
  vitrine_id uuid not null references public.vitrines(id) on delete cascade,
  entreprise_id uuid not null references public.entreprises(id) on delete cascade,
  nom text not null check (char_length(trim(nom)) between 1 and 100),
  role_ou_specialite text check (char_length(role_ou_specialite) <= 120),
  presentation text check (char_length(presentation) <= 500),
  photo_url text,
  ordre integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists vitrine_equipe_vitrine_idx
  on public.vitrine_equipe(vitrine_id, ordre);

alter table public.vitrine_equipe enable row level security;

create policy vitrine_equipe_select_publique on public.vitrine_equipe
  for select
  using (true);

create policy vitrine_equipe_write_membre on public.vitrine_equipe
  for all
  to authenticated
  using (app.est_membre(entreprise_id))
  with check (app.est_membre(entreprise_id));

-- -----------------------------------------------------------------------------
-- 5. TABLE DES DEMANDES DE RENDEZ-VOUS (AVEC CONFIRMATION DU SALON)
-- -----------------------------------------------------------------------------

create table if not exists public.vitrine_rendez_vous (
  id uuid primary key default gen_random_uuid(),
  vitrine_id uuid not null references public.vitrines(id) on delete cascade,
  entreprise_id uuid not null references public.entreprises(id) on delete cascade,
  prestation_id uuid references public.vitrine_prestations(id) on delete set null,
  nom_prestation text not null,
  date_souhaitee date not null,
  heure_souhaitee text not null,
  nom_client text not null check (char_length(trim(nom_client)) between 1 and 120),
  telephone_client text not null check (char_length(trim(telephone_client)) between 4 and 30),
  message_client text check (char_length(message_client) <= 600),
  statut text not null default 'EN_ATTENTE' check (
    statut in ('EN_ATTENTE', 'CONFIRME', 'REFUSE', 'TERMINE')
  ),
  reponse_salon text check (char_length(reponse_salon) <= 600),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists vitrine_rendez_vous_entreprise_statut_idx
  on public.vitrine_rendez_vous(entreprise_id, statut, date_souhaitee);

alter table public.vitrine_rendez_vous enable row level security;

-- RLS Sécurité stricte : Les demandes ne sont visibles QUE par les membres autorisés du salon
create policy vitrine_rendez_vous_select_membre on public.vitrine_rendez_vous
  for select
  to authenticated
  using (app.est_membre(entreprise_id));

-- Insertion autorisée publiquement (clients anon et connectés) pour réserver un RDV
create policy vitrine_rendez_vous_insert_public on public.vitrine_rendez_vous
  for insert
  with check (true);

-- Modification (confirmation / refus) strictement réservée aux membres de l'entreprise
create policy vitrine_rendez_vous_update_membre on public.vitrine_rendez_vous
  for update
  to authenticated
  using (app.est_membre(entreprise_id))
  with check (app.est_membre(entreprise_id));

create policy vitrine_rendez_vous_delete_membre on public.vitrine_rendez_vous
  for delete
  to authenticated
  using (app.est_membre(entreprise_id));

-- -----------------------------------------------------------------------------
-- 6. RPC CONSULTATION VITRINE PUBLIQUE UNIFIÉE (MODÈLES A, B, C, D, E)
-- -----------------------------------------------------------------------------

create or replace function public.consulter_vitrine_publique(p_slug_ou_id text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_vitrine record;
  v_entreprise record;
  v_resultat jsonb;
begin
  -- 1. Chercher d'abord dans la table dédiée vitrines
  select *
  into v_vitrine
  from public.vitrines
  where (lower(slug) = lower(trim(p_slug_ou_id)) or entreprise_id::text = trim(p_slug_ou_id) or id::text = trim(p_slug_ou_id))
    and est_publie = true
  limit 1;

  -- 2. Récupérer l'entreprise associée
  if v_vitrine.id is not null then
    select * into v_entreprise from public.entreprises where id = v_vitrine.entreprise_id;
  else
    -- Repli sur entreprises existantes (rétrocompatibilité boutique simple)
    select *
    into v_entreprise
    from public.entreprises
    where (lower(slug) = lower(trim(p_slug_ou_id)) or id::text = trim(p_slug_ou_id))
      and est_catalogue_actif = true
    limit 1;
  end if;

  if v_entreprise.id is null then
    return null;
  end if;

  -- 3. Construction du JSON unifié pour le frontend
  select jsonb_build_object(
    'vitrine', jsonb_build_object(
      'id', coalesce(v_vitrine.id::text, v_entreprise.id::text),
      'entreprise_id', v_entreprise.id,
      'nom', v_entreprise.nom,
      'slug', coalesce(v_vitrine.slug, v_entreprise.slug),
      'type_activite', coalesce(v_vitrine.type_activite, 'COMMERCE_GENERAL'),
      'modele_visuel', coalesce(v_vitrine.modele_visuel, 'MODELE_A'),
      'theme_style', coalesce(v_vitrine.theme_style, 'COMMERCIAL_VERT'),
      'couleur_principale', coalesce(v_vitrine.couleur_principale, '#1E7E4E'),
      'couleur_secondaire', coalesce(v_vitrine.couleur_secondaire, '#10B981'),
      'titre_hero', v_vitrine.titre_hero,
      'slogan', v_vitrine.slogan,
      'description', coalesce(v_vitrine.description, v_entreprise.description_commerciale),
      'logo_url', coalesce(v_vitrine.logo_url, v_entreprise.logo_url),
      'banniere_url', coalesce(v_vitrine.banniere_url, v_entreprise.couverture_url),
      'photo_presentation_url', v_vitrine.photo_presentation_url,
      'audio_presentation_url', v_vitrine.audio_presentation_url,
      'sections_actives', coalesce(v_vitrine.sections_actives, '{
        "accueil": true,
        "a_propos": true,
        "produits": true,
        "prestations": false,
        "tarifs": false,
        "galerie": false,
        "equipe": false,
        "rdv": false,
        "horaires": true,
        "contact": true
      }'::jsonb),
      'horaires', coalesce(v_vitrine.horaires, '[]'::jsonb),
      'adresse', coalesce(v_vitrine.adresse, v_entreprise.ville),
      'ville', coalesce(v_vitrine.ville, v_entreprise.ville),
      'pays', coalesce(v_vitrine.pays, v_entreprise.pays, 'Mali'),
      'telephone', coalesce(v_vitrine.telephone, v_entreprise.telephone),
      'whatsapp', coalesce(v_vitrine.whatsapp, v_entreprise.whatsapp_commercial),
      'email', v_vitrine.email,
      'reseaux_sociaux', coalesce(v_vitrine.reseaux_sociaux, '{}'::jsonb),
      'devise', coalesce(v_entreprise.devise, 'XOF'),
      'est_publie', coalesce(v_vitrine.est_publie, true)
    ),
    'prestations', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', p.id,
        'nom', p.nom,
        'description', p.description,
        'prix', p.prix,
        'prix_barre', p.prix_barre,
        'duree_minutes', p.duree_minutes,
        'categorie', p.categorie,
        'photo_url', p.photo_url,
        'audio_url', p.audio_url,
        'ordre', p.ordre
      ) order by p.ordre asc, p.nom asc), '[]'::jsonb)
      from public.vitrine_prestations p
      where p.entreprise_id = v_entreprise.id and p.est_actif = true
    ),
    'galerie', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', g.id,
        'titre', g.titre,
        'categorie', g.categorie,
        'photo_url', g.photo_url,
        'photo_avant_url', g.photo_avant_url,
        'ordre', g.ordre
      ) order by g.ordre asc, g.created_at desc), '[]'::jsonb)
      from public.vitrine_galerie g
      where g.entreprise_id = v_entreprise.id
    ),
    'equipe', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', eq.id,
        'nom', eq.nom,
        'role_ou_specialite', eq.role_ou_specialite,
        'presentation', eq.presentation,
        'photo_url', eq.photo_url,
        'ordre', eq.ordre
      ) order by eq.ordre asc, eq.nom asc), '[]'::jsonb)
      from public.vitrine_equipe eq
      where eq.entreprise_id = v_entreprise.id
    ),
    'produits', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', prod.id,
        'nom', prod.nom,
        'description', prod.description,
        'prix_public', coalesce(prod.prix_public, prod.prix_detail, 0),
        'prix_barre', prod.prix_barre,
        'photos', prod.photos,
        'photos_v2', prod.photos_v2,
        'audio_url', prod.audio_presentation_url,
        'video_url', prod.video_presentation_url,
        'collection_id', prod.collection_id
      ) order by prod.created_at desc), '[]'::jsonb)
      from public.produits prod
      where prod.entreprise_id = v_entreprise.id
        and prod.est_publie_catalogue = true
        and prod.est_actif = true
        and prod.deleted_at is null
    ),
    'collections', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', coll.id,
        'nom', coll.nom,
        'description', coll.description,
        'image_url', coll.image_url,
        'ordre', coll.ordre
      ) order by coll.ordre asc, coll.nom asc), '[]'::jsonb)
      from public.catalogue_collections coll
      where coll.entreprise_id = v_entreprise.id
        and coll.est_actif = true
    ),
    'nouveautes', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', nouv.id,
        'titre', nouv.titre,
        'message', nouv.message,
        'type_media', nouv.type_media,
        'media_url', nouv.media_url,
        'created_at', nouv.created_at
      ) order by nouv.created_at desc), '[]'::jsonb)
      from public.catalogue_nouveautes nouv
      where nouv.entreprise_id = v_entreprise.id
        and (nouv.expire_a is null or nouv.expire_a > now())
    )
  ) into v_resultat;

  return v_resultat;
end;
$$;

grant execute on function public.consulter_vitrine_publique(text) to anon, authenticated;

-- Rétrocompatibilité : faire pointer consulter_catalogue_public sur la nouvelle structure
create or replace function public.consulter_catalogue_public(p_slug_ou_id text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  return public.consulter_vitrine_publique(p_slug_ou_id);
end;
$$;

grant execute on function public.consulter_catalogue_public(text) to anon, authenticated;
