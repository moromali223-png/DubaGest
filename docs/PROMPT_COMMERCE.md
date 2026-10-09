# DUBAGEST — Module Commerce
## Brief de conception & d'implémentation : Produits · Stock · Achats · Ventes · Fournisseurs

---

## 0. Ton rôle

Tu interviens comme **Product Designer senior + Architecte Flutter/Supabase** sur DUBAGEST — *La gestion simple de votre activité*.

Tu combines trois expertises :
- **UX/UI mobile-first** pour le commerce de proximité (boutiques, alimentations, supermarchés, quincailleries, gros/détail) ;
- **Architecture applicative** Flutter, Supabase/PostgreSQL, RLS, Offline-First ;
- **Métier de la distribution** : catalogue, conditionnements, stock multi-boutiques, achats fournisseurs, vente gros/détail, inventaire.

Ta mission : concevoir puis implémenter un **écosystème Commerce cohérent, visuel et fiable**, où le **produit — avec sa photo et sa catégorie — est le point d'ancrage de toute l'expérience**.

> **Règle d'or :** la complexité appartient au système, jamais à l'utilisateur.
> L'utilisateur ne doit jamais avoir l'impression de gérer une base de données. Il gère son commerce.

---

## 1. Pour qui on construit — simple en surface, solide en profondeur

### 1.1 Les utilisateurs

La majorité des utilisateurs de DUBAGEST :
- **n'ont pas fait de longues études** ; certains lisent difficilement ;
- utilisent surtout **un smartphone**, parfois d'entrée de gamme, avec une connexion instable ;
- connaissent **parfaitement leur métier** (prix, cartons, clients, fournisseurs) mais **pas l'informatique** ;
- n'ont **ni le temps ni l'envie de suivre une formation**.

### 1.2 Mais leurs besoins métier sont réels

Un petit ou moyen commerce doit pouvoir :
- vendre au détail **et** en gros ;
- acheter en cartons et vendre à la pièce ;
- vendre ½ bidon, 2,5 mètres, 0,25 kg ;
- gérer 1, 2 ou plusieurs boutiques et transférer entre elles ;
- suivre ses dettes fournisseurs ;
- savoir ce qui manque et ce qu'il faut racheter ;
- faire un inventaire et expliquer les écarts ;
- continuer à travailler **sans Internet**.

### 1.3 Ce que cela impose

| Côté utilisateur (ce qu'il voit) | Côté système (ce qui est caché) |
|---|---|
| Des photos, des mots du quotidien, de gros boutons | Unité de référence, conversions, mouvements typés |
| Une seule question par écran | Validation, calculs, contrôles de stock |
| « Il reste 98 cartons » | 3 920 pièces en décimal exact |
| « Transférer 20 cartons à la Boutique B » | Sortie A + entrée B + transfert lié, en une transaction |
| 🟠 « En attente d'envoi » | Outbox, UUID, idempotence, retry, gestion des conflits |

**Test à appliquer à chaque écran :** *un commerçant qui n'a jamais utilisé d'application de gestion comprend-il quoi faire en moins de 5 secondes, sans lire de texte long ?* Si non, simplifier.

**Divulgation progressive :** par défaut, l'application est en **mode simple**. Les fonctions avancées (conditionnements, fractions, prix gros, multi-boutiques, attributs) n'apparaissent **que lorsque l'entreprise ou le produit en a besoin**.

### 1.4 Une seule application pour tous les commerces

DUBAGEST doit convenir à **tout type de commerce** sans développement spécifique. Le même moteur sert tout le monde ; seuls les **catégories proposées, les unités suggérées et les options visibles** changent selon le secteur choisi à l'inscription (modifiable ensuite).

| Type de commerce | Exemples de produits | Unités typiques | Besoins activés |
|---|---|---|---|
| Boutique / alimentation de quartier | Eau, riz, savon, sucre | Pièce, bouteille, sachet, sac | Vente rapide, stock faible, mode simple |
| Supermarché / supérette | Produits emballés | Pièce, paquet, carton | Code-barres, scan continu, catégories nombreuses |
| Quincaillerie | Carreaux, ciment, peinture, câble, vis | Pièce, paquet, carton, sac, bidon, mètre, kg | Conditionnements, fractions, gros/détail, attributs |
| Grossiste / demi-grossiste | Cartons, sacs, fûts | Carton, sac, palette + pièce | Prix gros, achats volumineux, dettes fournisseurs |
| Textile / chaussures | Vêtements, chaussures | Pièce, lot | Attributs (taille, couleur), photos |
| Cosmétique / divers | Crèmes, parfums | Pièce, carton | Photos, catégories, code-barres |
| Commerce multi-boutiques | Tout | Tout | Stock par boutique, transferts, vue globale |

**Les besoins réels à couvrir pour tous**, activés seulement quand ils servent :
- **gros / détail** avec un stock unique ;
- **cartons, paquets, pièces** et unités libres, avec conversion automatique ;
- **fractions** (½ bidon, 2,5 m, 0,25 kg) ;
- **plusieurs boutiques**, chacune avec son stock, et transferts ;
- **dettes fournisseurs** et paiements partiels ;
- **inventaire** avec justification des écarts ;
- **travail sans Internet**, synchronisé ensuite.

Aucune de ces fonctions ne doit encombrer un commerce qui ne s'en sert pas.

---

## 2. Vision produit

L'utilisateur doit pouvoir s'exprimer comme il parle :

| Il dit… | Le système fait… |
|---|---|
| « J'ai acheté 100 cartons de carreaux. » | Crée un achat multi-lignes rattaché au fournisseur |
| « J'ai reçu la marchandise. » | Réceptionne (totalement ou partiellement) et génère les mouvements de stock |
| « J'en ai vendu 2 cartons. » | Convertit en unité de référence, décrémente le stock, enregistre la vente |
| « Il me reste combien ? » | Affiche 98 cartons (= 3 920 pièces), par boutique |
| « Transfère 20 cartons à la Boutique B. » | Crée un transfert sortie A / entrée B, atomique |
| « J'ai compté 95 cartons, le système dit 98. » | Calcule l'écart, demande la raison, crée l'ajustement |

**Modèle mental à transmettre :**

```
Produits      = ce que je vends
Achats        = ce que j'achète
Stock         = ce que j'ai, et où
Ventes        = ce que je vends à mes clients
Fournisseurs  = auprès de qui j'achète
```

---

## 3. Écosystème fonctionnel et règles fondamentales

Les cinq modules forment **un seul système**, pas cinq applications.

```
FOURNISSEUR → ACHAT → RÉCEPTION → STOCK ⇄ PRODUIT → VENTE → STOCK
```

1. **Une fiche produit unique**, réutilisée partout (Produits, Stock, Achats, Ventes, Rapports). Jamais de doublon.
2. **Produit ≠ Stock.** Le produit décrit *ce qu'on vend* ; le stock décrit *la quantité disponible d'un produit dans une boutique donnée*.
3. **Un seul stock réel**, exprimé en unité de référence. Pas de stock séparé pour gros, détail, carton, paquet ou pièce : ce ne sont que des **représentations** converties.
4. **Toute variation de stock passe par un mouvement contrôlé** — jamais une modification directe de quantité depuis un écran. L'historique du stock doit pouvoir être **reconstruit intégralement** à partir des mouvements.

---

## 4. Photo · Catégorie · Code-barres — le cœur de l'expérience

> Les commerçants reconnaissent un produit **par son apparence** bien avant son nom — et pour un utilisateur qui lit difficilement, la photo **est** le nom.
> Toutes les routes mènent au même produit.

| Pilier | Rôle | Usage |
|---|---|---|
| 📷 **Photo** | Reconnaissance instantanée | Toucher une vignette pour agir |
| 🗂️ **Catégorie** | Organisation & navigation | Entrer par rayon : Matériaux → Ciment |
| ▥ **Code-barres** | Identification immédiate | Scanner → fiche + actions |
| 🔎 **Recherche** | Accès direct | Nom, référence, code produit, code-barres |

### 4.1 Photo produit

**Capture**
- Bouton visible dès le début de la création : **📷 Ajouter une photo** → *Prendre une photo* / *Choisir dans la galerie*.
- Recadrage carré simple (1:1), aperçu avant validation.
- Plusieurs photos possibles (jusqu'à 5) ; la première est la **photo principale**.

**Traitement technique (invisible pour l'utilisateur)**
- Compression côté client (WebP, ~1024 px) + **miniature ~256 px** pour les listes.
- Stockage **Supabase Storage**, chemins cloisonnés par entreprise, protégés par politiques RLS.
- **Cache local** des miniatures (affichage instantané et hors ligne) ; upload mis en file d'attente sans connexion.
- Chargement progressif (skeleton), jamais de saut de mise en page.

**Sans photo — placeholder intelligent**
Jamais d'icône grise générique : vignette générée avec **couleur + icône de la catégorie + initiales du produit**.

**La photo apparaît** dans : Produits, Stock, Ventes, Achats, recherche, résultat de scan, fiche produit, alertes, historique des mouvements.

### 4.2 Catégories visuelles

Les catégories sont des **points d'entrée**, pas une liste déroulante.

Chaque catégorie possède : **icône**, **couleur discrète**, **image de couverture** (facultative), **compteur de produits**, **indicateur d'alerte** (stock faible / rupture).

Hiérarchie sur **2 niveaux** maximum : Catégorie → Sous-catégorie.

```
🎨 Peinture
 ├── Intérieur
 ├── Extérieur
 ├── Primaire
 └── Vernis
```

- Mobile : **rangée de chips visuelles défilantes** en haut de Produits, Stock et Ventes + écran « Toutes les catégories » en grille 2 colonnes.
- Tablette/desktop : grille 3–4 colonnes ou panneau latéral.

```
┌──────────────┐ ┌──────────────┐
│   [image]    │ │   [image]    │
│ 🧱 Matériaux │ │ 🎨 Peinture  │
│ 45 produits  │ │ 28 produits  │
│ 🟠 3 faibles │ │              │
└──────────────┘ └──────────────┘
```

**Catégories proposées selon le secteur** à l'inscription (ex. quincaillerie : 🔨 Outils · 🧱 Matériaux · 🎨 Peinture · 🚰 Plomberie · ⚡ Électricité · 🔩 Visserie · 🚪 Menuiserie · 🧰 Accessoires), modifiables. L'utilisateur ne part jamais d'une page blanche.

### 4.3 Code-barres

- **Facultatif**, jamais bloquant.
- Bouton **▥ Scanner** disponible dans la recherche, Produits, Stock, Ventes, Achats, création produit.
- Scan → panneau immédiat :

```
┌─────────────────────────────────┐
│ [PHOTO]  Carreau 40×40          │
│          Carrelage · CAR-4040   │
│          🟢 100 cartons         │
│                                 │
│ [ Vendre ] [ + Stock ] [ Voir ] │
└─────────────────────────────────┘
```

- Code inconnu → « Ce code n'est lié à aucun produit » + **[Créer le produit]** (code pré-rempli).
- Mode **scan continu** en vente et en inventaire (bip + vibration).

---

## 5. Accueil Commerce

Léger, personnel, orienté action.

```
Bonjour Mohamed 👋                 🟢 Synchronisé
🏪 Boutique A ▾                     (si plusieurs boutiques)

🔎 Rechercher ou scanner un produit…  [▥]

┌─────────────┐ ┌─────────────┐
│ 💰 Ventes   │ │ 📦 Stock    │
└─────────────┘ └─────────────┘
┌─────────────┐ ┌─────────────┐
│ 🧾 Produits │ │ 🛒 Achats   │
└─────────────┘ └─────────────┘
┌──────────────┐
│🚚 Fournisseurs│
└──────────────┘

À surveiller
[photo][photo][photo] 🟠 8 produits en stock faible  →
[photo][photo]        🔴 2 produits en rupture       →
```

| Carte | Ce qu'elle permet |
|---|---|
| 💰 Ventes | Vendre rapidement |
| 📦 Stock | Voir ce qui est disponible, faible, en rupture, et les mouvements |
| 🧾 Produits | Créer, modifier, rechercher les produits |
| 🛒 Achats | Acheter chez un fournisseur, plusieurs produits, réceptionner |
| 🚚 Fournisseurs | Voir les fournisseurs, leurs achats et leurs dettes |

- Les alertes montrent les **photos des produits concernés**.
- **Adaptatif** : module sans permission → masqué ; sélecteur de boutique → uniquement si plusieurs boutiques.

---

## 6. Module Produits — le catalogue central

### 6.1 Écran principal

Catalogue **visuel**, jamais un tableau froid.

```
Produits                      [▥] [+]
🔎 Rechercher…
[Tous] [🧱 Matériaux] [🎨 Peinture] [🚰 Plomberie] →

┌────────────┐ ┌────────────┐
│  [PHOTO]   │ │  [PHOTO]   │
│Carreau     │ │Ciment 50 kg│
│40×40       │ │Matériaux   │
│Carrelage   │ │            │
│12 000 FCFA │ │ 6 500 FCFA │
│🟢 100 ctn  │ │🟠 35 sacs  │
└────────────┘ └────────────┘
```

- **Deux vues** : *Grille* (photo dominante, par défaut) et *Liste* (petite photo + infos). Choix mémorisé.
- **Carte produit** : photo, nom, catégorie › sous-catégorie, prix de vente, statut de stock (icône + texte + couleur), référence en secondaire.
- Tri simple : nom, catégorie, stock, prix.

### 6.2 Fiche produit

```
[ Photos — glisser pour voir les autres ]

Carreau 40×40                    🟢 En stock
Carrelage › Carrelage sol · CAR-4040

┌ Stock ─────────────────────────────┐
│ 100 cartons  (= 4 000 pièces)      │
│ ███████████████░░░  minimum 10     │
│ Boutique A : 70 · Boutique B : 30  │
└────────────────────────────────────┘

[ 💰 Vendre ] [ 🛒 Acheter ] [ ⇄ Transférer ] [ ⋮ ]

Prix · Unités · Fournisseurs · Mouvements
```

### 6.3 Création produit — formulaire progressif

**Seuls la photo (recommandée), le nom, l'unité et le prix de vente sont demandés au départ.** Le bouton « Enregistrer » est disponible dès ce minimum.

| Étape | Contenu |
|---|---|
| **1. Identité** | 📷 Photo · Nom · Catégorie (choix visuel) · Sous-catégorie · Référence (proposée automatiquement) · Code-barres (saisie ou scan) |
| **2. Unité** | Unité principale (pièce, sac, carton, paquet, bidon, mètre, kg, litre…) · *+ Ajouter un conditionnement* (ex. 1 paquet = 4 pièces ; 1 carton = 40 pièces) |
| **3. Prix** | Prix d'achat · Prix de vente détail · Prix de vente gros *(uniquement si l'entreprise vend en gros)* · Bénéfice calculé automatiquement |
| **4. Stock** | Boutique · Stock de départ · Unité · Stock minimum (alerte) |
| **5. Plus d'options** *(fermé par défaut)* | Vente en fraction · Marque · Modèle · Dimensions · Couleur · Poids · Emplacement · Fournisseur principal |

Le choix des unités et le calcul automatique des prix de l'étape 2–3 sont détaillés en **section 10**.

### 6.4 Produit simple = formulaire simple

```
[PHOTO]  Eau 1,5 L
Unité : Bouteille
Prix : 500 FCFA
→ Enregistrer
```

C'est suffisant. Aucun écran de conversion, de fraction ou de prix gros ne doit apparaître pour ce produit.

### 6.5 Champs adaptés à la catégorie

Le formulaire **propose** (sans imposer) des champs selon la catégorie :

| Catégorie | Champs proposés |
|---|---|
| Carrelage | Dimensions, couleur, marque, finition, pièces/carton |
| Peinture | Couleur, volume, marque, type |
| Câble | Section, longueur, marque |

Système flexible, jamais de formulaire à 50 champs.

---

## 7. Module Stock — « Qu'est-ce que j'ai, et où ? »

En ouvrant Stock pour la première fois, l'utilisateur comprend en quelques secondes : combien de produits il a, lesquels sont faibles, lesquels manquent, dans quelle boutique, et comment faire une entrée, une sortie, un transfert ou consulter l'historique.

### 7.1 Écran principal

```
Stock
Suivez vos produits, vos quantités et vos mouvements.

🔎 Nom, référence ou code-barres…    [▥]
🏪 Toutes les boutiques ▾

┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐
│ 245   │ │🟠 18  │ │🔴 5   │ │ 37    │
│Produits│ │Faibles│ │Ruptures│ │Mouv.  │
│        │ │       │ │        │ │aujourd'hui│
└───────┘ └───────┘ └───────┘ └───────┘
   (compactes, défilement horizontal sur mobile,
    toucher une carte = filtrer la liste)

[Toutes] [🧱 Matériaux] [🎨 Peinture] →

┌──────────────────────────────────────┐
│ [PHOTO] Carreau 40×40      🟢 En stock│
│         Carrelage · CAR-4040          │
│         100 cartons · 4 000 pièces    │
│         ███████████████░░░            │
│         A : 70 · B : 30               │
├──────────────────────────────────────┤
│ [PHOTO] Ciment 50 kg  🟠 Stock faible │
│         Matériaux                     │
│         35 sacs  ████░░░░ minimum 50  │
├──────────────────────────────────────┤
│ [PHOTO] Peinture blanche 20 L         │
│         Peinture          🔴 Rupture  │
│         0 bidon        [ Commander ]  │
└──────────────────────────────────────┘
```

- **4 indicateurs maximum**, compacts. Jamais d'énormes KPI qui occupent la moitié de l'écran.
- **Photo sur chaque ligne** et **jauge** par rapport au stock minimum : lecture sans calcul.
- Unité affichée = **la plus parlante** (ex. cartons), l'équivalent en unité de base en petit.

### 7.2 Toutes les boutiques / une boutique

- **Toutes les boutiques** → vue globale avec répartition :
  ```
  Carreaux 40×40 — Total : 4 000 pièces
  Boutique A : 2 500 · Boutique B : 1 500
  ```
- **Une boutique choisie** → l'écran entier devient spécifique à cette boutique, sans changer d'écran.
- Sur tablette/desktop, vue tableau possible :

  | Produit | Boutique A | Boutique B | Total |
  |---|---|---|---|
  | Ciment | 150 | 100 | 250 |
  | Carreaux | 2 500 | 1 500 | 4 000 |
  | Peinture | 20 | 8 | 28 |

- L'utilisateur ne voit **que les boutiques autorisées** par ses permissions. Une seule boutique → aucun sélecteur.
- **Qui voit quoi** selon le rôle et l'abonnement : voir **section 20**.

### 7.3 Recherche

- Par **nom, référence, code produit, code-barres**.
- Résultats **pendant la frappe**, avec photo.
- **Tolérante** : sans accents, fautes légères, mots partiels (« cimen » → Ciment 50 kg).

### 7.4 Statuts

| Statut | Affichage |
|---|---|
| En stock | 🟢 icône + « En stock » |
| Stock faible | 🟠 icône + « Stock faible » |
| Rupture | 🔴 icône + « Rupture » |

Jamais la couleur seule.

### 7.5 Filtres

Simples, en chips : **Boutique** · **Catégorie** · **État** (Tous / En stock / Stock faible / Rupture) · **Recherche**.

### 7.6 Fiche stock d'un produit

```
[PHOTO] Carreaux 40×40 · CAR-4040

Stock actuel
100 cartons   (= 4 000 pièces)

Répartition
🏪 Boutique A   2 500 pièces
🏪 Boutique B   1 500 pièces

[ + Entrée ] [ − Sortie ] [ ⇄ Transfert ] [ 📋 Inventaire ]

Derniers mouvements →
```

Les 4 actions principales sont **visibles immédiatement**, jamais cachées dans des menus.

### 7.7 Alertes stock

Écran **« À surveiller »** qui n'affiche que les produits demandant une action :

```
[PHOTO] 🟠 Ciment 50 kg
        35 sacs restants · minimum 50
        [ Voir ]  [ Commander ]

[PHOTO] 🔴 Peinture blanche
        0 bidon · Rupture
        [ Voir ]  [ Commander ]
```

Le bouton **[Commander]** (achat pré-rempli avec le fournisseur habituel) n'apparaît **que si le module Achats est activé** pour l'entreprise et l'utilisateur.

---

## 8. Opérations de stock

Chaque opération = **un écran court**, une question à la fois, avec **aperçu avant/après** systématique.

### 8.1 Entrée

```
Nouvelle entrée
Produit    [PHOTO] Carreaux 40×40   (rechercher / scanner)
Quantité   [ 100 ]      Unité [ Carton ▾ ]
Boutique   [ Boutique A ▾ ]
Motif      (Achat) (Retour) (Ajustement) (Autre)

Stock actuel : 100 cartons → Après : 200 cartons

        [ Enregistrer l'entrée ]
```

### 8.2 Sortie

```
Nouvelle sortie
Produit    [PHOTO] Carreaux 40×40
Quantité   [ 2 ]        Unité [ Carton ▾ ]
Boutique   [ Boutique A ▾ ]
Motif      (Vente) (Perte) (Casse) (Ajustement) (Autre)

Stock actuel : 100 cartons → Après : 98 cartons

        [ Confirmer la sortie ]
```

### 8.3 Transfert entre boutiques

```
Transférer du stock
De    🏪 Boutique A   →   Vers  🏪 Boutique B
Produit   [PHOTO] Carreaux 40×40
Quantité  20 cartons

Boutique A : 100 → 80 cartons
Boutique B :  30 → 50 cartons

        [ Confirmer le transfert ]
```

Pour l'utilisateur : **1 seul transfert**. Pour le système : une sortie A + une entrée B + un transfert qui les relie, dans **une seule transaction**.
Visible uniquement si l'entreprise a au moins 2 boutiques et que l'utilisateur a accès aux deux.

### 8.4 Inventaire

```
Inventaire — [PHOTO] Carreaux 40×40
Selon le système    100 cartons
J'ai compté         [ 97 ] cartons
Écart               −3 cartons

Pourquoi ?
(Erreur de comptage) (Casse) (Perte) (Produit manquant) (Autre)
Note (facultatif) [ ............ ]

        [ Valider l'inventaire ]
```

Après validation : mouvement d'ajustement créé automatiquement. Possible produit par produit ou par catégorie (avec scan continu).

### 8.5 Contrôles instantanés

La vérification se fait **pendant la saisie**, pas après une erreur serveur :

```
⚠ Stock insuffisant
Disponible : 5 cartons — vous demandez 8.
```

### 8.6 Confirmations intelligentes

Pour les opérations sensibles (sortie importante, transfert, ajustement), un récapitulatif avant validation :

```
Confirmer la sortie ?
Produit    Carreaux 40×40
Quantité   20 cartons
Boutique   Boutique A
Avant      100 cartons
Après      80 cartons

[ Annuler ]   [ Confirmer ]
```

Pas de confirmation pour les actions courantes et sans risque (éviter la fatigue des pop-ups).

### 8.7 Retours visuels

Message bref en bas d'écran, vibration légère :
- ✓ Stock mis à jour
- ✓ 20 cartons transférés vers Boutique B
- ⚠ Stock insuffisant — disponible : 5 cartons

---

## 9. Historique des mouvements

Écran **Mouvements**, groupé par jour, lisible comme un journal :

```
Aujourd'hui
14:35  🟢 Entrée     [PHOTO] 100 cartons — Carreaux 40×40
                     Boutique A · Achat · par Mohamed
13:10  🔴 Sortie     [PHOTO] 2 cartons — Carreaux 40×40
                     Boutique A · Vente · par Ibrahim
11:02  🔵 Transfert  [PHOTO] 20 cartons — Carreaux 40×40
                     Boutique A → Boutique B · par Mohamed
```

Filtres : **Tous · Entrées · Sorties · Transferts · Ajustements · Pertes** + recherche + boutique + période.
Toucher un mouvement → son détail et le document d'origine (achat, vente, transfert, inventaire).

---

## 10. Unités, conditionnements, prix et fractions

### 10.1 L'utilisateur définit ses propres unités

Chaque commerce compte à sa façon. L'utilisateur doit pouvoir **décrire ses propres conditionnements avec ses propres quantités**, simplement, comme il le dirait à voix haute :

```
Comment vendez-vous ce produit ?

Je compte en :     [ Pièce ▾ ]          ← unité de base

+ Ajouter un emballage
  1 [ Carton ▾ ] contient [ 40 ] [ pièces ]
  1 [ Paquet ▾ ] contient [ 4  ] [ pièces ]
  1 [ Sac de 25 kg ▾ ] …
```

- **Liste d'unités prêtes** (pièce, carton, paquet, sac, bidon, bouteille, sachet, boîte, rouleau, mètre, kg, litre, douzaine, lot, palette…) **+ « Autre… »** pour créer sa propre unité (ex. « botte », « seau », « fût »).
- Les unités les plus utilisées dans l'entreprise remontent en premier.
- **Aide au calcul intégrée** : la phrase de vérification s'affiche en direct — *« 1 carton = 40 pièces · 1 paquet = 4 pièces · donc 1 carton = 10 paquets »*.
- **Modèles réutilisables** : « Copier les unités d'un autre produit » (tous les carreaux d'une même gamme ont 40 pièces/carton).
- Contrôles : quantité > 0, pas de doublon, pas de boucle ; message clair en cas d'erreur (« Un carton doit contenir au moins 1 pièce »).
- Modifier une conversion d'un produit qui a déjà du stock **ne change pas le stock réel** (en unité de base) — seul l'affichage s'adapte ; l'utilisateur en est prévenu.

### 10.2 Enregistrer dans l'unité de son choix

À chaque saisie (achat, réception, entrée, sortie, vente, transfert, inventaire), l'utilisateur **choisit l'unité qui lui convient** :

```
Quantité  [ 3 ]   Unité  ( Carton ) ( Paquet ) ( Pièce )
                  = 120 pièces
```

- L'unité proposée par défaut est **la dernière utilisée** pour ce produit et cette opération (ex. Achats → carton, Ventes → pièce).
- L'équivalent est **toujours affiché en direct** sous la saisie.
- Saisie mixte possible quand c'est naturel : *2 cartons + 5 pièces = 85 pièces*.
- Si le produit n'a qu'une unité, le sélecteur n'apparaît pas.

### 10.3 Prix calculés automatiquement

L'utilisateur saisit **un seul prix** ; le système calcule les autres. Il peut ensuite **corriger** n'importe quel prix calculé.

**Exemple — Ampoule, 1 carton = 100 pièces**

```
Prix de vente

          Prix pièce       Prix carton
Détail    [ 1 000 F ]  →   100 000 F   (calculé)
Gros      [   900 F ]  →    90 000 F   (calculé)

✏️ Modifier le prix carton
```

- **Dans les deux sens** :
  - saisie du prix **pièce** 1 000 F → carton calculé **100 × 1 000 = 100 000 F** ;
  - saisie du prix **carton** 95 000 F → pièce calculée **950 F**.
- **Prix forcé** : si le commerçant fixe lui-même le prix carton (ex. 95 000 F au lieu de 100 000 F), ce prix est conservé et l'écart est affiché simplement : *« Prix carton : 95 000 F (au lieu de 100 000 F, remise de 5 %) »*.
- Prix forcé plus élevé que le calcul → avertissement doux (« Le carton coûte plus cher que 100 pièces vendues séparément. Continuer ? »).
- Même logique pour le **prix d'achat** : acheté 80 000 F le carton → coût pièce **800 F**, et **bénéfice** affiché par unité (pièce : 200 F · carton : 20 000 F).
- Arrondis au franc près selon une règle documentée ; aucun prix à virgule affiché pour le FCFA.
- Prix gros visibles uniquement si l'entreprise vend en gros.

**Lors de la vente** : le prix suit l'unité choisie et le mode Détail/Gros, sans aucun calcul par le vendeur.

### 10.4 Unité de référence (moteur interne)

Le stock est enregistré **dans une seule unité de référence** (la plus petite unité vendable).

```
Carreau 40×40 — unité de référence : pièce
1 paquet = 4 pièces
1 carton = 40 pièces

Réception  100 cartons → +4 000 pièces   (100 × 40, calculé par le système)
Vente        2 cartons →    −80 pièces
Vente        5 pièces  →     −5 pièces
Affichage : 97 cartons + 35 pièces (= 3 915 pièces)
```

- L'utilisateur saisit **dans l'unité qu'il connaît** ; il ne fait **jamais** le calcul.
- Conversions en **décimal exact** (pas de flottants), règles d'arrondi documentées.
- Produit à unité unique → aucune notion de conversion affichée.

### 10.5 Vente fractionnée

- Option par produit : **Vente en fraction : Oui / Non** + **pas minimum** (ex. 0,25).
- Quantités **toujours stockées en nombre** (`0.5`), **jamais en texte** (`"1/2"`).
- Saisie facile : boutons ¼ · ½ · ¾ · 1, ou saisie libre contrôlée par le pas.
- Exemple : 1 bidon = 20 L → vente possible de 20 L, 10 L, 5 L, 2,5 L si le produit l'autorise.
- Fraction non autorisée → aucun élément de fraction affiché.

---

## 11. Module Achats

### 11.1 Création

```
Nouvel achat                 ACH-0048
🚚 Fournisseur : ABC Matériaux ▾
🏪 Boutique : A ▾        📅 06/10/2026

Produits habituels de ce fournisseur
[PHOTO][PHOTO][PHOTO][PHOTO] →

[PHOTO] Carreau 40×40      100 cartons   1 100 000
[PHOTO] Ciment 50 kg        50 sacs        325 000
[PHOTO] Peinture blanche    20 bidons      620 000
+ Ajouter un produit  (recherche · scan · catégorie)

Total : 2 045 000 FCFA     Payé : [ ______ ]
[ Enregistrer ]   [ Enregistrer et réceptionner ]
```

- Plusieurs produits par achat.
- **Produits habituels du fournisseur** en vignettes photo, en premier.
- Dernier prix d'achat pré-rempli.
- Produit inexistant → création rapide (photo + nom + unité) sans quitter l'achat.

### 11.2 Réception totale ou partielle

- Par ligne : commandé / déjà reçu / **reçu aujourd'hui** (pré-rempli avec le restant).
- **Seules les quantités réellement reçues** augmentent le stock ; chaque réception crée ses mouvements.
- Exemple : commandé 100 cartons + 50 sacs + 20 bidons ; reçu aujourd'hui 100 cartons + 50 sacs → la peinture reste « à recevoir ».
- Statuts : *Brouillon · Commandé · Reçu en partie · Reçu · Annulé*.
- Résumé « Effet sur le stock » : Ciment 50 → **150 sacs**.

---

## 12. Module Ventes — vitesse maximale

### 12.1 Écran de vente

```
🔎 Rechercher…                 [▥ Scanner]
[Favoris] [🧱 Matériaux] [🎨 Peinture] →

┌──────┐ ┌──────┐ ┌──────┐
│PHOTO │ │PHOTO │ │PHOTO │
│Carreau│ │Ciment│ │Peint.│
│12 000│ │6 500 │ │45 000│
└──────┘ └──────┘ └──────┘

──────── Panier (3) ── 61 500 FCFA [Encaisser] ▲
```

- **Toucher la photo = ajouter au panier.** Toucher encore = +1. Appui long = choisir quantité / unité.
- **Favoris / plus vendus** en premier.
- Produit en rupture : visible mais grisé avec la mention « Rupture ».
- Sur tablette : panier fixe à droite.

### 12.2 Gros / Détail

- Choix **Détail | Gros** sur la vente (modifiable par ligne si besoin).
- Le prix change automatiquement : Carton — Détail 12 000 FCFA / Gros 11 000 FCFA.
- Le stock reste **unique** (100 cartons quel que soit le mode).
- Entreprise sans vente en gros → ce choix n'existe pas à l'écran.

---

## 13. Module Fournisseurs

**Fiche fournisseur :** nom, téléphone (appel / WhatsApp en un toucher), adresse, **produits fournis (grille photo)**, historique des achats, total acheté, total payé, **dette** (mise en évidence), dernier achat.

Actions : *Nouvel achat* · *Enregistrer un paiement* · *Appeler*.

Les produits fournis se remplissent automatiquement à partir des achats et restent modifiables.

---

## 14. Navigation entre les modules

Jamais besoin de revenir à l'accueil.

| Depuis | Accès directs |
|---|---|
| Produit | Stock · Acheter · Vendre · Mouvements · Fournisseurs |
| Stock | Produit · Entrée · Sortie · Transfert · Inventaire |
| Achat | Fournisseur · Produits · Réceptions · Effet sur le stock |
| Vente | Produit · Client · Effet sur le stock |
| Fournisseur | Achats · Produits fournis · Dette |

Recherche + scan accessibles depuis chaque écran du module.

---

## 15. Une interface qui s'adapte

> L'interface montre **ce qui est utile à l'utilisateur**, pas tout ce que le système sait faire.

### 15.1 Selon le contexte

| Contexte | Comportement |
|---|---|
| Produit à une seule unité | Aucune conversion affichée |
| Aucune fraction autorisée | Aucune option de fraction |
| Une seule boutique | Pas de sélecteur, pas de répartition, pas de transfert |
| Deux boutiques ou plus | Sélecteur, répartition et transferts activés naturellement |
| Pas de vente en gros | Aucun prix gros, aucun choix Gros/Détail |
| Module Achats non activé | Pas de bouton « Commander » |
| Pas de permission d'ajustement | Pas de bouton « Ajuster » / « Inventaire » |
| Pas d'accès Fournisseurs | Module masqué |

### 15.2 Selon le type d'entreprise

| Profil | Ce qu'il voit |
|---|---|
| **Petit commerce** | Eau 1,5 L · Bouteille · 500 FCFA. Aucune configuration superflue. |
| **Quincaillerie** | Carreaux 40×40 · Pièce / Paquet / Carton · conversion automatique · fractions · gros/détail |
| **Multi-boutiques** | Vue « Toutes les boutiques » + accès à chaque boutique + transferts |

### 15.3 États vides pédagogiques

Chaque module a un état vide avec une illustration légère, une phrase et **une seule** action :

- **Produits** — 📦 *Aucun produit* · « Ajoutez vos produits pour commencer à gérer votre stock et vos ventes. » · **[+ Ajouter un produit]**
- **Stock** — 📦 *Votre stock est encore vide* · « Commencez par ajouter votre premier produit. » · **[+ Ajouter un produit]**
- **Fournisseurs** — 🚚 *Aucun fournisseur* · **[+ Ajouter un fournisseur]**
- **Catégorie vide** — « Aucun produit dans Peinture » · **[+ Ajouter un produit ici]**

Chargement : **skeletons** en forme de cartes, jamais d'écran blanc ni de spinner plein écran.

---

## 16. Hiérarchie des actions et zéro surcharge

### 16.1 Hiérarchie

| Niveau | Actions | Où |
|---|---|---|
| **Principales** | Entrée · Sortie · Transfert · Inventaire · Vendre · Acheter | Boutons visibles |
| **Secondaires** | Modifier · Voir l'historique · Configurer | Visibles mais discrètes |
| **Avancées** | Archiver · Dupliquer · Exporter… | Menu **⋮ Plus** |

### 16.2 Interdits

❌ Trop de cartes · ❌ Trop de couleurs · ❌ Trop de graphiques · ❌ Tableaux géants sur mobile · ❌ 15 boutons sur un écran · ❌ Formulaires interminables · ❌ Informations techniques inutiles · ❌ Accordéons partout · ❌ Menus dans des menus · ❌ Texte trop petit · ❌ Informations importantes cachées · ❌ Grandes fenêtres modales

Impression recherchée : **simplicité + confiance + professionnalisme**.

### 16.3 Formulaires — modernes, professionnels, faciles

Tous les formulaires (produit, unités, prix, achat, réception, entrée, sortie, transfert, inventaire, fournisseur, paiement) suivent les mêmes règles :

| Règle | Application |
|---|---|
| **Une question à la fois** | Étapes courtes ; 3 à 5 champs visibles maximum par écran mobile |
| **Choisir plutôt que taper** | Photos, chips, boutons, listes avec recherche ; saisie libre seulement si nécessaire |
| **Pré-remplir intelligemment** | Boutique courante, date du jour, dernier fournisseur, dernière unité, dernier prix |
| **Libellés clairs au-dessus des champs** | « Combien de cartons ? » plutôt que « Qté » ; exemple en gris dans le champ |
| **Le bon clavier** | Numérique pour quantités et prix, téléphone pour les numéros |
| **Calcul en direct** | Équivalences d'unités, prix calculés, total, stock avant → après |
| **Erreurs au bon endroit** | Sous le champ concerné, en phrase simple, dès la saisie — jamais une liste d'erreurs en haut |
| **Obligatoire minimal** | Les champs facultatifs sont clairement marqués « (facultatif) » ou rangés dans « Plus d'options » |
| **Bouton principal unique** | En bas, large (≥ 52 px), toujours visible, avec un verbe (« Enregistrer le produit ») |
| **Brouillon automatique** | Rien n'est perdu si l'utilisateur quitte ou reçoit un appel |
| **Grands chiffres** | Montants et quantités en gros caractères, séparateurs de milliers (100 000 F) |
| **Confirmation claire** | Message de succès + action suivante proposée (« Ajouter un autre produit ») |

Style visuel : champs arrondis (14 px) sur fond blanc, bordure fine, bordure verte au focus, espacement aéré, sections titrées, icônes devant les champs clés — conforme au thème existant de l'application.

---

## 17. Design system DUBAGEST

### 17.1 Couleurs — celles du code existant

La palette officielle est celle déjà définie dans **`lib/app/theme/app_theme.dart`** (`AppColors` + `AppTheme`) : **Vert Émeraude + Ardoise sombre + Menthe douce**, avec un accent ambre.

| Token `AppColors` | Valeur | Usage |
|---|---|---|
| `green` (alias `navy`) | `#1E7E4E` | Couleur principale : actions principales, navigation, focus |
| `greenPressed` (`navyDark`) | `#15633D` | État pressé, texte sur fond menthe |
| `greenLight` (`navyLight`) | `#27AE60` | Accents, graphiques |
| `greenSoft` (`navySoft`) | `#E8F5EE` | Fonds doux, badges « En stock », sélection |
| `gold` | `#D97706` | Accent secondaire, mise en avant |
| `goldSoft` | `#FDECDA` | Fond d'accent doux |
| `ink` | `#1A2522` | Texte principal, menu latéral, snackbars, segment sélectionné |
| `background` | `#F4F7F5` | Fond d'écran |
| `surface` | `#FFFFFF` | Cartes, champs, panneaux |
| `border` | `#E5EAE7` | Bordures fines des cartes et champs |
| `muted` | `#64748B` | Texte secondaire |
| `positive` / `positiveSoft` | `#1E7E4E` / `#E8F5EE` | 🟢 En stock, entrées, gains |
| `warning` / `warningSoft` | `#D97706` / `#FDECDA` | 🟠 Stock faible |
| `negative` / `negativeSoft` | `#DC2626` / `#FEE2E2` | 🔴 Rupture, sorties, erreurs |

Règles :
- **Ne jamais écrire de couleur en dur** (`Color(0xFF…)`) dans les écrans : passer par `AppColors` ou `Theme.of(context).colorScheme`. Les couleurs en dur actuellement présentes dans `features/stock/presentation/` sont à migrer vers le thème.
- Réutiliser aussi `AppSpacing` (4 · 8 · 16 · 24 · 32), `AppBreakpoints` (600 / 840, largeur max 720) et les styles déjà définis (coins 14–16 px, boutons 52 px, cartes sans ombre avec bordure fine).
- Les couleurs de catégories (placeholders photo) sont des teintes **douces** dérivées, harmonisées avec cette palette.
- Le thème sombre existe déjà (`AppTheme.dark()`) : tout nouvel écran doit y rester lisible.
- L'identité visuelle se change **uniquement** dans `app_theme.dart`.

**La couleur se mérite** : réservée aux actions importantes, aux statuts, aux indicateurs et à la navigation. Le reste reste sobre et blanc.

### 17.2 Style

- **Élégant, chaleureux, aéré** — ni ERP vieillissant, ni dashboard SaaS générique.
- **Les photos produits sont l'élément visuel dominant** ; l'interface s'efface.
- Coins arrondis (14–16 px), cartes plates à bordure fine, espace généreux.
- Espacements `AppSpacing`, hiérarchie typographique nette, chiffres importants en **grand**.
- Material 3, prise en charge **RTL** (arabe).

### 17.3 Composants réutilisables

`ProductImage` (photo / placeholder catégorie / cache) · `ProductCard` · `ProductTile` · `CategoryChip` · `CategoryCard` · `StockBadge` · `StockLevelBar` · `QuantityUnitPicker` · `BeforeAfterPreview` · `BarcodeScanSheet` · `EmptyState` · `SyncStatusIndicator` · `ShopSelector`

### 17.4 Mobile-first

Priorité **smartphone → tablette → desktop**. Ne jamais concevoir un écran desktop puis le réduire.

| Format | Mise en page |
|---|---|
| Mobile | Cartes / liste, photos, boutons ≥ 48 px, actions au pouce, peu de champs à la fois, **clavier adapté** (numérique pour les quantités et prix) |
| Tablette | Grille 3–4 colonnes, liste + détail côte à côte, panier fixe |
| Desktop | Grille plus large, filtres latéraux, tableaux professionnels **avec photos** quand ils font vraiment gagner du temps |

---

## 18. Accessibilité et langage

- **Mots du quotidien** : « Entrée », « Sortie », « Il reste », « Bénéfice » — jamais « mouvement », « ADJUSTMENT_IN », « SKU », « unité de référence ».
- **Phrases courtes**, boutons avec des verbes : « Réceptionner », « Confirmer la sortie ».
- **Icône + texte** toujours ensemble ; jamais d'icône seule pour une action importante.
- **Le moins de saisie possible** : choix par photos, boutons, valeurs pré-remplies, scan.
- Cibles tactiles ≥ 48 × 48 px ; texte agrandissable ; contraste WCAG AA.
- Aucune information critique **uniquement par la couleur**.
- Erreurs compréhensibles : ce qui se passe + quoi faire.
  - ❌ `StockMovementException`
  - ✅ « Impossible de faire cette sortie : il reste seulement 5 cartons. »
- Langues : **français, anglais, arabe (RTL)** via i18n.

---

## 19. Offline-First

S'appuyer sur l'architecture Offline-First **existante** de DUBAGEST.

- Toute opération (vente, achat, réception, entrée, sortie, transfert, inventaire, création produit, photo) est **enregistrée localement** puis synchronisée **en arrière-plan** au retour du réseau.
- **Ne jamais bloquer** l'utilisateur parce qu'Internet est coupé.
- Mécanismes : **UUID** générés côté client · **outbox / file de synchronisation** · **idempotence** · **retry** avec backoff · **timestamps** · **gestion des conflits** documentée · **journalisation**.
- Photos : miniatures en cache, uploads en file d'attente avec reprise.
- Indicateur discret : 🟢 Synchronisé · 🟠 En attente d'envoi · 🔴 Échec (avec « Réessayer »).

---

## 20. Rôles, boutiques, abonnements et sécurité

Chaîne d'autorisation : **Entreprise → Abonnement → Membre → Rôle → Périmètre (Boutique) → Permissions**.

### 20.1 Abonnements (déjà définis en base : `plans`, `plan_activites`, `plan_roles`)

| Formule | Boutiques Commerce | Utilisateurs Commerce | Rôles |
|---|---|---|---|
| **NORMAL** | 1 | limité | quotas par rôle |
| **MOYEN** | **2** | 7 | quotas par rôle (ex. 2 caissiers) |
| **PRO** | **illimitées** | illimités | tous les rôles, sans quota (plusieurs superviseurs, plusieurs gestionnaires de stock…) |

> Les limites ne sont **jamais codées en dur** dans Flutter : elles viennent des tables `plans` / `plan_activites` / `plan_roles` et sont contrôlées côté serveur. L'interface s'adapte à ce que la formule autorise.

### 20.2 Qui voit quoi

| Rôle (`RoleCodes`) | Boutiques visibles | Ce qu'il voit et fait dans Commerce |
|---|---|---|
| **Administrateur** | **Toutes les boutiques de l'entreprise** (`perimetres.access_all`) | Vue **globale** (toutes boutiques cumulées) **et** vue **séparée** boutique par boutique ; tous les modules ; transferts entre boutiques ; paramètres, prix, utilisateurs |
| **Superviseur** | **Uniquement la ou les boutiques qui lui sont affectées** | Pilotage de sa boutique : ventes, dépenses, stock, achats, alertes, mouvements de sa boutique |
| **Gestionnaire de stock** | **Uniquement sa boutique** | Partie **Stock** de sa boutique : entrées, sorties, réceptions, inventaires, mouvements, alertes |
| **Vendeur** | Uniquement sa boutique | Ventes ; consultation du stock disponible pour vendre |
| **Caissier** | Uniquement sa boutique | Encaissements, caisse ; consultation des prix |

Règles :
- Les droits viennent des **permissions** du rôle (`PermissionEngine.has`, `canAccessPerimetre`), **jamais** de tests sur le code du rôle.
- Un utilisateur limité à la Boutique A **ne voit jamais l'existence des données de la Boutique B** : ni dans les listes, ni dans les totaux, ni dans les recherches, ni dans les alertes, ni dans les transferts.
- **Transfert** : proposé uniquement si l'utilisateur a accès aux **deux** boutiques (en pratique l'administrateur, ou un superviseur affecté à plusieurs boutiques).
- **Vue « Toutes les boutiques »** : réservée à ceux qui ont accès à plus d'une boutique. Un utilisateur à boutique unique arrive directement sur sa boutique, sans sélecteur.
- Les indicateurs de l'accueil (stock faible, ruptures, ventes du jour) sont calculés **sur le périmètre de l'utilisateur uniquement**.
- Les actions non autorisées sont **masquées**, pas simplement grisées.

### 20.3 Exemples concrets

**Abonnement MOYEN — 2 boutiques**
```
Administrateur (Mohamed)   → 🏪 Toutes les boutiques ▾  (Global · Boutique A · Boutique B)
Superviseur (Awa)          → 🏪 Boutique A  — ventes, dépenses, stock de A uniquement
Gestionnaire stock (Ibra)  → 🏪 Boutique B  — stock de B uniquement
Vendeur (Fatou)            → 🏪 Boutique A  — ventes de A uniquement
```

**Abonnement PRO — 5 boutiques**
```
Administrateur             → les 5 boutiques, global et séparé
Superviseur 1              → Boutiques A et B
Superviseur 2              → Boutique C
Gestionnaires de stock     → un ou plusieurs par boutique
```

### 20.4 Application technique

- Un vendeur, superviseur ou gestionnaire de la Boutique A ne peut ni voir ni modifier le stock de la Boutique B sans autorisation — **même en modifiant une route Flutter**.
- Les politiques RLS filtrent par entreprise **et** par périmètre (`app.a_permission()` + affectation aux périmètres) ; les agrégats « global » sont calculés côté serveur sur les seules boutiques autorisées.
- **Toutes les règles sont appliquées dans Supabase/PostgreSQL via RLS** (tables + buckets Storage des photos).
- Opérations sensibles (réception, vente, transfert, inventaire) exécutées par **fonctions SQL transactionnelles** garantissant la cohérence du stock.
- Flutter masque ce qui n'est pas autorisé mais **n'est jamais la couche de sécurité**.

---

## 21. Modèle conceptuel

```
Entreprise
   ↓
Boutique / Périmètre
   ↓
Produit  ── Catégorie / Sous-catégorie · Photos · Code-barres
   ↓
Unité de référence
   ↓
Conditionnements (conversions)
   ↓
Stock par boutique
   ↓
Mouvements de stock
```

Exemple : Carreaux 40×40 · référence PIÈCE · 1 paquet = 4 · 1 carton = 40 · Boutique A 2 500 · Boutique B 1 500 · Global 4 000.

**Types de mouvements :**

`PURCHASE` · `SALE` · `TRANSFER_OUT` · `TRANSFER_IN` · `ADJUSTMENT_IN` · `ADJUSTMENT_OUT` · `RETURN` · `LOSS` · `DAMAGE`

Chaque mouvement porte : produit, boutique, quantité en unité de référence, unité et quantité saisies par l'utilisateur, motif, auteur, date, document d'origine (achat, vente, transfert, inventaire).

---

## 22. Architecture technique

Respecter l'architecture existante de DUBAGEST :
Flutter · Dart · Clean Architecture · Feature-first · Repository Pattern · Supabase · PostgreSQL · RLS · stockage local · Offline-first · Outbox · i18n FR/EN/AR · RTL · Material 3.

Structure de référence (à adapter à l'existant) :

```
features/
└── stock/
    ├── data/          datasources/ · models/ · repositories/
    ├── domain/        entities/ · repositories/ · usecases/
    └── presentation/  pages/ · widgets/ · controllers/ · providers/
```

Ne pas créer une nouvelle architecture si une architecture cohérente existe déjà. Ne pas casser les fonctionnalités existantes.

---

## 23. Ne pas sur-ingénier

À éviter : 20 tables pour une fonction simple, workflows complexes, écrans d'administration inutiles, configurations obligatoires, abstractions sans besoin réel.

Le modèle doit malgré tout supporter : petit commerce, commerce moyen, quincaillerie, gros + détail, plusieurs boutiques, plusieurs unités, fractions, transferts, inventaire, hors ligne.

**Construire le minimum solide, puis activer la puissance à la demande.**

---

## 24. Démarche obligatoire avant de coder

### Phase 1 — Analyse de l'existant
Analyser : code Flutter (structure, gestion d'état, navigation), tables et migrations Supabase, politiques RLS, authentification et permissions, système Offline-First, thème et composants UI, gestion des images, fonctionnalités Produits/Stock/Achats/Ventes/Fournisseurs déjà présentes.
→ Identifier **ce qui existe et fonctionne** (à réutiliser), **ce qui est à corriger**, **ce qui manque**, et les **conflits possibles**.

### Phase 2 — Proposition (à faire valider)
1. Architecture fonctionnelle
2. Flux Fournisseur → Achat → Réception → Stock → Vente
3. Modèle de données
4. Règles métier (conversions, fractions, seuils, réception partielle, transferts, inventaire, stock négatif)
5. Parcours utilisateurs
6. Architecture des écrans + wireframes / logique UI
7. Architecture technique (Flutter, Supabase, Storage, RLS, offline, sync)
8. Plan d'implémentation par étapes livrables et testables

### Phase 3 — Implémentation
**Ne pas lancer de grosse refonte immédiatement.** Attendre la validation explicite avant de toucher aux parties sensibles. Livrer par petites étapes, chacune testée (conversions, mouvements, RLS, composants clés).

---

## 25. Résultat attendu

En ouvrant le module, l'utilisateur comprend immédiatement :

**Ce que j'ai · Où je l'ai · Ce qui manque · Ce qui a changé · Ce que je peux faire maintenant**

Critères mesurables :
- Créer un produit **avec photo** en moins d'une minute.
- Faire une vente de 3 articles en **moins de 15 secondes**.
- Retrouver un produit par **4 chemins** : recherche, catégorie, scan, photo.
- Stock **toujours juste**, quelle que soit l'unité utilisée.
- **Aucune fiche produit en double.**
- Application **pleinement utilisable hors connexion**.
- Aucun accès hors du périmètre autorisé : l'administrateur voit toutes ses boutiques (global et séparé), superviseurs, gestionnaires de stock et vendeurs ne voient que leur(s) boutique(s).
- L'utilisateur saisit **un seul prix** (pièce ou carton) et obtient les autres automatiquement, en pouvant les corriger.
- Un même produit s'enregistre indifféremment en pièces, paquets ou cartons, avec l'équivalent affiché en direct.
- Le même écran convient à une alimentation de quartier comme à une quincaillerie multi-boutiques.
- Un nouvel utilisateur réussit une entrée, une sortie et une vente **sans aide**.

---

## Priorités absolues

**Simplicité → rapidité → lisibilité → fiabilité → puissance**

1. Simplicité et compréhension immédiate, même pour un utilisateur peu scolarisé
2. Reconnaissance visuelle par **photo**
3. Organisation par **catégories**
4. Recherche et **scan** code-barres
5. Rapidité des opérations
6. Cohérence Produits · Achats · Stock · Ventes · Fournisseurs
7. Fiabilité du stock (unité de référence unique, mouvements tracés)
8. Multi-boutiques et gros/détail
9. Offline-first
10. Sécurité (RLS)

> **Ne jamais sacrifier la simplicité au profit de la complexité technique.**
> Un outil assez simple pour une petite boutique de quartier, assez puissant pour une quincaillerie multi-boutiques — et assez beau pour qu'on ait envie de l'ouvrir chaque matin.
