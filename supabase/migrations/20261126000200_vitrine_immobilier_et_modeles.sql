-- =============================================================================
-- VITRINE V2 — EXTENSION DOMAINE IMMOBILIER, BIENS & DEMANDES DE VISITE
-- =============================================================================

-- 1. Table des biens immobiliers spécifiques pour la vitrine
create table if not exists public.vitrine_biens (
  id uuid primary key default gen_random_uuid(),
  vitrine_id uuid not null references public.vitrines(id) on delete cascade,
  entreprise_id uuid not null references public.entreprises(id) on delete cascade,
  titre text not null check (char_length(trim(titre)) between 1 and 200),
  type_bien text not null default 'VILLA',
  type_offre text not null default 'LOCATION', -- LOCATION ou VENTE
  prix bigint not null default 0 check (prix >= 0),
  prix_barre bigint,
  devise text not null default 'FCFA',
  description text,
  adresse text,
  ville text,
  quartier text,
  photos jsonb not null default '[]'::jsonb,
  audio_url text,
  surface_m2 numeric,
  nb_chambres integer,
  nb_salles_de_bain integer,
  meuble boolean not null default false,
  climatisation boolean not null default false,
  parking boolean not null default false,
  est_disponible boolean not null default true,
  est_vedette boolean not null default false,
  ordre integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists vitrine_biens_vitrine_idx on public.vitrine_biens(vitrine_id);
create index if not exists vitrine_biens_entreprise_idx on public.vitrine_biens(entreprise_id);

alter table public.vitrine_biens enable row level security;

create policy vitrine_biens_select_publique on public.vitrine_biens
  for select
  using (est_disponible = true or app.est_membre(entreprise_id));

create policy vitrine_biens_insert_membre on public.vitrine_biens
  for insert
  to authenticated
  with check (app.est_membre(entreprise_id));

create policy vitrine_biens_update_membre on public.vitrine_biens
  for update
  to authenticated
  using (app.est_membre(entreprise_id))
  with check (app.est_membre(entreprise_id));

create policy vitrine_biens_delete_membre on public.vitrine_biens
  for delete
  to authenticated
  using (app.est_membre(entreprise_id));

-- 2. Table des demandes de visite pour les biens immobiliers
create table if not exists public.vitrine_demandes_visite (
  id uuid primary key default gen_random_uuid(),
  vitrine_id uuid not null references public.vitrines(id) on delete cascade,
  entreprise_id uuid not null references public.entreprises(id) on delete cascade,
  bien_id uuid,
  nom_bien text not null,
  nom_client text not null check (char_length(trim(nom_client)) between 1 and 150),
  telephone_client text not null check (char_length(trim(telephone_client)) between 5 and 30),
  email_client text,
  date_souhaitee date not null,
  heure_souhaitee text not null default '10:00',
  message_client text,
  statut text not null default 'EN_ATTENTE' check (statut in ('EN_ATTENTE', 'CONFIRMEE', 'ANNULEE')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists vitrine_visites_entreprise_idx on public.vitrine_demandes_visite(entreprise_id);

alter table public.vitrine_demandes_visite enable row level security;

-- N'importe quel visiteur anonyme ou authentifié peut envoyer une demande de visite depuis le site public
create policy vitrine_visites_insert_publique on public.vitrine_demandes_visite
  for insert
  to anon, authenticated
  with check (true);

-- Seul les membres de l'entreprise peuvent consulter et traiter les demandes
create policy vitrine_visites_select_membre on public.vitrine_demandes_visite
  for select
  to authenticated
  using (app.est_membre(entreprise_id));

create policy vitrine_visites_update_membre on public.vitrine_demandes_visite
  for update
  to authenticated
  using (app.est_membre(entreprise_id))
  with check (app.est_membre(entreprise_id));

create policy vitrine_visites_delete_membre on public.vitrine_demandes_visite
  for delete
  to authenticated
  using (app.est_membre(entreprise_id));

-- 3. Mise à jour de la RPC publique pour inclure les biens immobiliers
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
  -- Recherche par slug exact (insensible à la casse) ou par id uuid
  select * into v_vitrine
  from public.vitrines
  where lower(trim(slug)) = lower(trim(p_slug_ou_id))
     or (id::text = p_slug_ou_id and est_publie = true)
  limit 1;

  if v_vitrine is null then
    return null;
  end if;

  select id, nom, slug, telephone, devise, logo_path, description_commerciale, whatsapp_commercial
  into v_entreprise
  from public.entreprises
  where id = v_vitrine.entreprise_id;

  select jsonb_build_object(
    'vitrine', to_jsonb(v_vitrine),
    'entreprise', to_jsonb(v_entreprise),
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
    ),
    'biens', (
      select coalesce(
        (
          select jsonb_agg(jsonb_build_object(
            'id', b.id,
            'titre', b.titre,
            'type_bien', b.type_bien,
            'type_offre', b.type_offre,
            'prix', b.prix,
            'prix_barre', b.prix_barre,
            'devise', b.devise,
            'description', b.description,
            'adresse', b.adresse,
            'ville', b.ville,
            'quartier', b.quartier,
            'photos', b.photos,
            'audio_url', b.audio_url,
            'surface_m2', b.surface_m2,
            'nb_chambres', b.nb_chambres,
            'nb_salles_de_bain', b.nb_salles_de_bain,
            'meuble', b.meuble,
            'climatisation', b.climatisation,
            'parking', b.parking,
            'est_disponible', b.est_disponible,
            'est_vedette', b.est_vedette,
            'ordre', b.ordre
          ) order by b.ordre asc, b.created_at desc)
          from public.vitrine_biens b
          where b.entreprise_id = v_entreprise.id and b.est_disponible = true
        ),
        -- Fallback sur la table de gestion immobilier_biens si vitrine_biens est vide
        (
          select coalesce(jsonb_agg(jsonb_build_object(
            'id', ib.id,
            'titre', ib.nom,
            'type_bien', ib.type,
            'type_offre', 'LOCATION',
            'prix', ib.loyer_reference,
            'devise', 'FCFA',
            'description', ib.description,
            'adresse', ib.adresse,
            'ville', ib.ville,
            'quartier', ib.quartier,
            'photos', ib.photos,
            'surface_m2', (ib.caracteristiques->>'surface_m2')::numeric,
            'nb_chambres', (ib.caracteristiques->>'nb_chambres')::integer,
            'nb_salles_de_bain', (ib.caracteristiques->>'nb_salles_de_bain')::integer,
            'meuble', coalesce((ib.caracteristiques->>'meuble')::boolean, false),
            'climatisation', coalesce((ib.caracteristiques->>'climatisation')::boolean, false),
            'parking', coalesce((ib.caracteristiques->>'parking')::boolean, false),
            'est_disponible', (ib.statut = 'DISPONIBLE'),
            'est_vedette', false,
            'ordre', 0
          ) order by ib.created_at desc), '[]'::jsonb)
          from public.immobilier_biens ib
          where ib.entreprise_id = v_entreprise.id
            and ib.statut = 'DISPONIBLE'
            and ib.deleted_at is null
        ),
        '[]'::jsonb
      )
    )
  ) into v_resultat;

  return v_resultat;
end;
$$;

grant execute on function public.consulter_vitrine_publique(text) to anon, authenticated;
