# DUBAGEST — Commerce : analyse de l'existant et plan d'implémentation

Référence : [PROMPT_COMMERCE.md](PROMPT_COMMERCE.md) · Statut : **réalisé (étapes 0 à 5)**

## Réalisation

| Élément | Fichiers |
|---|---|
| Migration serveur (remplace `socle_stock`, jamais appliquée) | `supabase/migrations/20261013000100_commerce.sql` |
| Tests serveur (44) : droits par boutique, stock, transferts, réceptions, ventes | `supabase/tests/database/commerce.test.sql` |
| Base locale v8 (tables Commerce + photos) | `lib/core/database/tables.dart`, `app_database.dart`, `drift_schemas/` |
| Métier (quantités exactes, prix calculés, règles) | `lib/features/commerce/domain/` |
| Données, synchronisation, photos | `lib/features/commerce/data/` |
| Écrans | `lib/features/commerce/presentation/` (Produits, Catégories, Stock, Mouvements, Achats, Ventes, Fournisseurs) |
| Textes FR / EN / AR | `lib/app/localization/arb/` (préfixes `com*`, `rule*`) |
| Tests application (21) et intégration | `test/features/commerce/`, `test/integration/commerce_integration_test.dart` |

Décisions prises : migration réécrite (elle échouait, donc n'a jamais été appliquée) · stock négatif interdit, sauf pour une vente déjà faite au comptoir enregistrée hors-ligne (acceptée, stock signalé « à vérifier ») · `mobile_scanner` ajouté (scan masqué sur Windows : une douchette tape au clavier) · photos compressées par `image_picker`, gardées sur l'appareil et envoyées au retour du réseau.

---

---

## 1. Ce qui existe et qu'on réutilise

| Brique | Où | Usage pour Commerce |
|---|---|---|
| Moteur de permissions | `PermissionEngine`, `app.a_permission`, `app.acces_perimetre`, **`app.peut(entreprise, module, permission, perimetre)`** | Toutes les règles RLS Produits / Stock / Achats / Ventes |
| Rôles + permissions | `roles_permissions` : ADMINISTRATEUR (tout + `perimetres.access_all`), SUPERVISEUR, GESTIONNAIRE_STOCK, VENDEUR, CAISSIER | Qui voit quoi (section 20 du prompt) — déjà conforme |
| Limites d'abonnement | `plans`, `plan_activites` (MOYEN : 2 boutiques, PRO : illimité), `plan_roles` | Rien à coder en dur |
| Synchronisation offline | `SyncQueueStore` (outbox), `sync_push` (idempotent, versionné, RLS), `StandardSyncHandler`, curseurs | Toutes les nouvelles tables Commerce |
| Fichiers | bucket privé `fichiers`, `app.acces_fichier` par chemin, upload dans `fichiers_repository_impl` | Photos produits (nouveau préfixe `produits/`) |
| Fournisseurs | `contacts` avec relation `FOURNISSEUR` | Pas de nouvelle table fournisseur |
| Dettes / paiements | `engagements` (`origine_type`), `paiements`, caisse | Dette fournisseur d'un achat, encaissement d'une vente |
| Thème | `AppColors`, `AppSpacing`, `AppBreakpoints`, `AppTheme.light/dark` | Tous les écrans |
| i18n | FR / EN / AR + RTL | Tous les libellés |
| Recherche | `core/utils/recherche.dart` | Recherche tolérante produits |

---

## 2. Problèmes constatés dans le module Stock actuel

### Bloquants

| # | Problème | Fichier | Conséquence |
|---|---|---|---|
| B1 | Les politiques RLS utilisent `public.membres` / `utilisateur_id` / `est_actif`, **table inexistante** (la vraie est `membres_entreprise` / `user_id` / `statut`) | `supabase/migrations/20261013000100_socle_stock.sql` | La migration échoue au déploiement |
| B2 | RLS filtrée **par entreprise seulement**, `FOR ALL` | idem | Un vendeur de la Boutique A peut lire et **modifier** le stock de B ; n'importe quel membre peut écrire directement `stocks.quantite_disponible` |
| B3 | Le stock n'est **jamais synchronisé** : tables `local_*` créées à la main (`customStatement`), hors schéma Drift, hors outbox | `stock_local_data_source.dart` | Les données restent sur le téléphone ; un autre appareil ne voit rien ; perte en cas de réinstallation |
| B4 | **Données de démonstration injectées** automatiquement (Carreaux, Ciment, Peinture, Eau) | `stockProduitsProvider` → `seedExemplesSiVide` | Faux produits chez les vrais clients |
| B5 | Aucun filtrage par périmètre côté Flutter : totaux et listes cumulent **toutes** les boutiques | `watchProduits`, `boutiquesStockProvider` | Un gestionnaire de B voit les quantités de A |

### Importants

| # | Problème | Conséquence |
|---|---|---|
| I1 | Quantités en `double` (REAL) | Erreurs d'arrondi (0,1 + 0,2), stock faux sur fractions |
| I2 | Stock calculé côté client (`stock_avant`/`stock_apres`) | Deux appareils hors ligne = stock incohérent ; le serveur doit faire foi |
| I3 | Les streams Drift ne déclarent pas les tables lues (`readsFrom: jsonCache`) et les écritures ne notifient pas | Listes probablement non rafraîchies après une opération |
| I4 | Requêtes N+1 (2 requêtes par produit) | Lenteur au-delà de quelques centaines de produits |
| I5 | Nom de boutique fabriqué à partir de l'ID (`perimetre_id.replaceAll('-', ' ')`) | Affichage illisible dans l'historique |
| I6 | « Transférer » autorisé avec `stock.update` sans vérifier l'accès aux **deux** boutiques | Transfert vers une boutique non autorisée |
| I7 | Pas de triggers serveur (versionnement, audit, règles) contrairement aux autres modules | Pas de traçabilité, conflits non détectés |
| I8 | « Achats » = simple entrée de stock : pas de fournisseur, pas de commande, pas de réception partielle, pas de dette | Besoin métier non couvert |

### Manquants (par rapport au prompt)

Catégories (aujourd'hui texte libre) · photos produits · prix d'achat · prix détail/gros **par unité** · prix calculés automatiquement · unités personnalisées · code-barres scanné · ventes · fournisseurs liés aux produits · alertes avec « Commander ».

### Design

~220 couleurs écrites en dur dans `features/stock/presentation/`, dont 65 hors palette (`#01226C` navy, `#F8FAFC`, `#0F172A`). À remplacer par `AppColors` / `colorScheme`.

---

## 3. Modèle de données proposé

> Principe : **le client n'écrit jamais une quantité de stock**. Il envoie des **opérations** (mouvement, transfert, réception, vente) ; des triggers serveur vérifient les droits, calculent et mettent à jour `stocks`. Même schéma que `paiements` → `engagements`.

```
categories_produits ─┐
                     ▼
produits ── produit_unites (pièce, paquet ×4, carton ×40 … + prix détail/gros/achat)
   │    └── produit_photos (bucket fichiers : {eid}/produits/{pid}/…)
   │
   ├── stocks (perimetre × produit)            ← écrit UNIQUEMENT par trigger
   │      ▲
   ├── mouvements_stock                        ← insert-only, trigger → stocks
   │      ▲            ▲             ▲
   │  transferts_stock  receptions    ventes_lignes
   │                     ▲
   └── achats ── achat_lignes ── reception_lignes
         │
         └── contacts (FOURNISSEUR) + engagements (dette, origine ACHAT)
```

| Table | Champs clés | Notes |
|---|---|---|
| `categories_produits` | `parent_id`, `nom`, `icone`, `couleur`, `ordre` | 2 niveaux max ; modèles par secteur à l'inscription |
| `produits` (modifiée) | + `categorie_id`, `photo_chemin`, `unite_base`, `vente_fractionnee`, `pas_minimum`, `seuil_alerte`, `attributs jsonb` | `categorie` texte migré vers `categorie_id` |
| `produit_unites` (remplace `produit_conditionnements`) | `nom`, `facteur` (numeric), `prix_detail`, `prix_gros`, `prix_achat`, `prix_detail_force`, `prix_gros_force`, `defaut_achat`, `defaut_vente` | L'unité de base est une ligne avec `facteur = 1` |
| `produit_photos` | `chemin`, `ordre` | `app.acces_fichier` étendu au préfixe `produits` |
| `stocks` | `quantite` numeric(14,4) | Lecture seule pour les clients |
| `mouvements_stock` | `type`, `quantite_base`, `quantite_saisie`, `unite_id`, `stock_avant/apres` (calculés serveur), `origine_type/id`, `motif`, `note` | Insert-only via `sync_push` |
| `transferts_stock` | `de_perimetre_id`, `vers_perimetre_id`, `produit_id`, quantité | Trigger : 2 mouvements liés, accès aux 2 boutiques exigé |
| `achats`, `achat_lignes` | fournisseur (`contacts`), boutique, statut, total, payé | Crée un `engagement` (dette fournisseur) |
| `receptions`, `reception_lignes` | quantités reçues par ligne | Réception partielle → mouvements `ENTREE_ACHAT` |
| `ventes`, `vente_lignes` | mode DETAIL/GROS, unité, prix appliqué | Phase ventes ; s'appuie sur `engagements`/`paiements` existants |

**RLS de chaque table** : `app.peut(entreprise_id, '<module>', '<permission>', perimetre_id)` — exactement comme demandé : l'administrateur (`perimetres.access_all`) voit tout, les autres seulement leurs boutiques affectées.

**Quantités côté Flutter** : entier en **millièmes d'unité de base** (`int`), jamais `double`. **Prix** : entiers FCFA.

**Calcul automatique des prix** : fonction pure Dart (`domain/services/calcul_prix.dart`) + tests :
- prix pièce saisi → prix carton = pièce × facteur ;
- prix carton saisi → prix pièce = carton ÷ facteur (arrondi au franc) ;
- prix forcé conservé, écart affiché en %.

---

## 4. Plan d'implémentation par étapes

Chaque étape est livrable, testée et utilisable seule.

| Étape | Contenu | Résultat visible |
|---|---|---|
| **0. Fondations sûres** | Corriger B1–B5 : nouvelle migration Stock (RLS par boutique, triggers, versionnement, audit, `sync_tables`), tables Drift déclarées, stock dans l'outbox, suppression des données de démo, filtrage par périmètre | Le stock se synchronise et respecte les rôles |
| **1. Catalogue visuel** | Catégories visuelles, photos produits (prise, galerie, miniatures, cache), unités personnalisées, **prix calculés automatiquement**, formulaire produit progressif, catalogue grille/liste | Créer un produit avec photo, unités et prix en < 1 min |
| **2. Stock refait** | Écran Stock (KPI, photo, jauge, filtres, vue globale/boutique), fiche stock, Entrée/Sortie/Transfert/Inventaire avec aperçu avant→après, historique, alertes ; migration complète vers le thème | Module Stock conforme au prompt |
| **3. Achats & fournisseurs** | Achat multi-produits, produits habituels du fournisseur, réception partielle, dette fournisseur et paiements, fiche fournisseur | Cycle Fournisseur → Achat → Réception → Stock |
| **4. Ventes** | Écran de vente par photos, panier, gros/détail, unité au choix, encaissement (caisse existante), sortie de stock automatique | Vendre 3 articles en < 15 s |
| **5. Finitions** | Scan code-barres (caméra), scan continu inventaire, accueil Commerce avec alertes en photos, états vides | Expérience complète |

---

## 5. Décisions à valider

1. **Migration `20261013000100_socle_stock.sql`** : déjà appliquée sur un projet Supabase réel ?
   - Non → on la **réécrit** directement (plus propre).
   - Oui → on ajoute une migration corrective.
2. **Nouvelles dépendances** :
   - `mobile_scanner` pour le code-barres (étape 5) ;
   - compression d'images : `image_picker` (déjà présent) suffit avec `maxWidth` + `imageQuality` → **pas de nouveau paquet**.
3. **Stock négatif** : interdit par défaut (vente bloquée si stock insuffisant), avec option entreprise pour l'autoriser ?
4. **Ordre** : commencer par **étapes 0 + 1** ?
