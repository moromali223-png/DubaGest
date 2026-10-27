-- Augmentation de la limite de caractères pour les colonnes icône/photo.
-- La limite de 40 caractères était insuffisante pour stocker les chemins des photos (préfixés par "photo:").

-- 1. Commerce : Catégories de produits
alter table public.categories_produits drop constraint if exists categories_produits_icone_check;
alter table public.categories_produits add constraint categories_produits_icone_check check (char_length(icone) <= 255);

-- 2. Services : Catalogue des prestations
alter table public.services_catalogue drop constraint if exists services_catalogue_icone_check;
alter table public.services_catalogue add constraint services_catalogue_icone_check check (char_length(icone) <= 255);
