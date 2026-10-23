-- Augmentation de la limite de caractères pour la colonne icône des catégories.
-- La limite de 40 caractères était insuffisante pour stocker les chemins des photos (préfixés par "photo:").
alter table public.categories_produits drop constraint if exists categories_produits_icone_check;
alter table public.categories_produits add constraint categories_produits_icone_check check (char_length(icone) <= 255);
