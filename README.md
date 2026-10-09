# DubaGest — fondation technique V1

Application de gestion **mobile-first, PWA, offline-first, multi-tenant** pour entreprises
Commerce, Services et Immobilier. Cette phase livre la fondation : aucune fonctionnalité métier
(ventes, stock…) n'est encore développée.

## Démarrage

```bash
supabase start                 # Supabase Local (API 54321, Studio 54323, Mailpit 54324)
supabase db reset              # migrations + données de démo (supabase/seed.sql)
flutter pub get
dart run build_runner build    # code drift (base locale)
flutter run                    # Android (émulateur → 10.0.2.2), Windows…
flutter run -d chrome --web-port 3000   # PWA : le port 3000 est celui autorisé par Supabase Auth
```

Autre environnement : `flutter run --dart-define-from-file=config/local.json`
(modèle : `config/local.example.json`). En release, `SUPABASE_URL`, `SUPABASE_KEY` et `APP_URL`
(adresse publique de la PWA, utilisée dans les liens d'invitation) sont obligatoires.

Les e-mails locaux (confirmation, réinitialisation) arrivent dans **Mailpit** : http://127.0.0.1:54324.

### Google
1. Google Cloud → identifiants OAuth « Application Web ».
   URI de redirection autorisée : `http://127.0.0.1:54321/auth/v1/callback` (en local).
2. `supabase/.env` (non versionné) :
   `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID=…` et `SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET=…`.
3. Passer `[auth.external.google] enabled = true` dans `supabase/config.toml`, puis `supabase stop && supabase start`.

Retour vers l'application :
- web : origine de la PWA ;
- Android / iOS : lien profond `io.dubagest://auth-callback`, déjà déclaré dans le manifeste et `Info.plist`.

Sur Windows / macOS, le retour Google n'est pas encore géré (aucun lien profond desktop en V1).

**Comptes de démo** (mot de passe `Password123!`) :

| Compte | Entreprise | Plan | Rôle | Périmètres |
|---|---|---|---|---|
| admin@alpha.test | Alpha Distribution | MOYEN (Commerce + Services) | Administrateur | tous |
| superviseur@alpha.test | Alpha Distribution | MOYEN | Superviseur | Boutique Centre |
| vendeur@alpha.test | Alpha Distribution | MOYEN | Vendeur | Boutique Marché |
| admin@beta.test | Beta Immobilier | NORMAL (Immobilier) | Administrateur | tous |

## Tests

```bash
flutter analyze
flutter test --exclude-tags integration   # unitaires + widgets, sans serveur
flutter test --tags integration --concurrency=1  # Auth, RPC, RLS, sync contre Supabase Local
                                                 # (un fichier à la fois : base partagée)
supabase test db                          # pgTAP : RLS, limites, sync côté PostgreSQL
```

## Architecture

```
lib/
├── app/        composition : config, DI des features, router (gardes), thème, i18n
├── core/       transverse, sans dépendance vers les features
│   ├── database/   drift (SQLite natif / WASM+OPFS/IndexedDB en PWA)
│   ├── sync/       file d'opérations, moteur, gateway Supabase
│   ├── permissions/ AccessDecision + codes de règles partagés avec PostgreSQL
│   ├── errors/     Failure + ErrorMapper (aucune erreur technique affichée)
│   └── network/, auth/, di/, utils/
├── features/<feature>/{data,domain,presentation}
└── shared/widgets/   états loading/empty/error, sync, langue, responsive
```

Flux de données : `Page → Provider (Riverpod) → UseCase → Repository → LocalDataSource / RemoteDataSource`.
Aucun écran n'accède à Supabase ou à SQLite.

### Modèle d'accès

```
auth.users → profiles → membres_entreprise (rôle) → roles_permissions
                                   └→ membre_perimetres → perimetres (boutique / agence / site)
entreprises → invitations (rôle, empreinte du jeton, expiration) → invitation_perimetres
entreprises → abonnements → plans → plan_activites / plan_roles / plan_modules
            → entreprise_activites
```

**ACCÈS FINAL = abonnement en vigueur ∧ activité active ∧ module du plan ∧ permission du rôle ∧ périmètre autorisé**

| Règle | Flutter (UX) | PostgreSQL (sécurité) |
|---|---|---|
| Limites d'abonnement | `LimitesEngine` | triggers `app.tg_verifier_*` |
| Permissions | `PermissionEngine` | `app.a_permission()` dans la RLS |
| Accès final | `ModuleAccessPolicy` | `app.peut()` |
| Affectation périmètre | `AffectationPolicy` | trigger `app.tg_verifier_affectation` |

Les limites NORMAL / MOYEN sont **des données** (`supabase/migrations/…_catalogue.sql`), pas du code.
Les refus serveur portent le même code (`LIMITE_PERIMETRES`…) que les décisions locales,
traduits par `AppLabels.rule()`.

### Inscription, entreprise, invitations

**Authentification ≠ rôle métier.** S'inscrire, par Google ou par e-mail, crée seulement une identité
(`auth.users` → `profiles`). Un rôle ne s'obtient que de deux façons.

| Parcours | Rôle obtenu | Garanti par |
|---|---|---|
| Créer mon entreprise | ADMINISTRATEUR (parce que créateur) | RPC `creer_entreprise` (transaction : entreprise, abonnement ESSAI 14 j, activités, périmètre, membre) |
| Rejoindre (invitation) | rôle et périmètres **de l'invitation** | RPC `accepter_invitation` |

Règles de sécurité des invitations (RPC `creer_invitation`, `verifier_invitation`, `accepter_invitation`, `annuler_invitation`) :
- **Création** : réservée à `users.invite`. Elle respecte les quotas du plan (membres actifs + invitations en attente) et l'activité du rôle. Un rôle restreint exige au moins un périmètre.
- **Jeton** : aléatoire (192 bits). Seule son empreinte SHA-256 est stockée, et il n'est affiché qu'une fois.
- **Acceptation** :
  - e-mail **confirmé** et identique à l'adresse invitée ;
  - invitation non expirée (7 jours) et à usage unique ;
  - quotas revérifiés par les triggers.
- **Aucune écriture directe** n'est possible sur `invitations` ni sur `membres_entreprise`.

Routage, recalculé à partir de l'état réel :
- pas de session → `/login` ;
- session sans entreprise → `/onboarding` ;
- invitation en attente → `/join-company` ;
- sinon → l'application.

Un compte peut appartenir à plusieurs entreprises ; le contexte s'ouvre sur la dernière rejointe.

**Hors-ligne :**
- **Autorisé** : une session déjà ouverte reste valide, le contexte (rôle, permissions, périmètres) est lu depuis le cache, les données métier restent consultables et les écritures synchronisables sont mises en file. La déconnexion est locale.
- **Réseau requis** : connexion, inscription, Google, mot de passe oublié, création d'entreprise, création et acceptation d'invitation, affectations. Aucune de ces actions n'est mise en file : elles doivent être validées immédiatement par le serveur.
- **Sécurité** : un refus de droits venant du serveur (403, session révoquée) n'est jamais remplacé par le cache.

### Offline-first

1. Écriture : SQLite local + opération en file, dans une même transaction (`PENDING_SYNC`).
2. `SyncEngine` : montée une opération à la fois via la RPC `sync_push`.
   - **Idempotente** : `op_id` journalisé dans `sync_operations`.
   - **Conflits** : contrôle de `version`. En V1, la version serveur gagne et la ligne est marquée `CONFLICT`.
   - **Réessais** : backoff exponentiel. Un refus métier passe l'opération en `REJECTED` et la ligne en `SYNC_ERROR`.
3. Descente : lignes modifiées depuis le curseur, pagination par `(updated_at, id)`, suppressions logiques.

## Ajouter…

- **une langue** : `lib/app/localization/arb/app_xx.arb`, puis `flutter gen-l10n`.
- **un module métier** : une ligne dans `modules` + `plan_modules` (migration), sa permission,
  son libellé ARB et sa route (`ModuleRoutes`). La navigation et les gardes suivent automatiquement.
- **une entité synchronisée** :
  1. table avec `id uuid, version, updated_at, deleted_at`, plus le trigger `app.tg_versionnement` ;
  2. RLS via `app.peut()` ;
  3. déclaration dans `app.sync_tables` ;
  4. table drift dans `core/database/tables.dart` ;
  5. data source locale implémentant `StockageSynchronise`, et un handler qui étend `StandardSyncHandler` (politique commune), enregistré dans `app/di/app_composition.dart`. Exemple complet : `features/contacts`.
- **un rôle** : `roles` + `roles_permissions` + `plan_roles`. Aucun `if (role == …)` dans le code.
- **une évolution de la base locale (SQLite / PWA)** :
  1. modifier `core/database/tables.dart` et incrémenter `schemaVersion` ;
  2. `dart run drift_dev make-migrations` : fige la version dans `drift_schemas/` et génère les tests ;
  3. écrire l'étape dans `AppDatabase.migrerVers`.

  Une copie de la base (`*.vN-<date>.bak`) est faite automatiquement avant chaque migration (hors web), et les références sont contrôlées après. Une version sans étape refuse de s'ouvrir plutôt que de corrompre les données. `drift` est figé en 2.34.0 pour rester compatible avec `drift_dev`.
- **la base locale de la PWA** : `web/sqlite3.wasm` et `web/drift_worker.js` doivent correspondre aux versions résolues de `sqlite3` et `drift` (`pubspec.lock`). Sinon, au démarrage, on obtient `LinkError: WebAssembly.instantiate(): Import … "xFileControl"`. Après chaque mise à jour de ces paquets :
  1. télécharger `sqlite3.wasm` depuis la release `sqlite3-<version>` de [sqlite3.dart](https://github.com/simolus3/sqlite3.dart/releases) ;
  2. recompiler le worker : `dart compile js -O2 -o web/drift_worker.js tool/drift_worker.dart`, puis supprimer les fichiers `.deps` et `.map` produits.

  Le `drift_worker.js` publié avec drift peut avoir été compilé avec un `sqlite3` plus ancien : on le compile donc depuis le projet.
- **une traduction** : le test `test/app/traductions_test.dart` échoue si une clé ou un paramètre manque en FR, EN ou AR.

## Formules (données, modifiables sans code)

| Formule | Prix | Activités | Utilisateurs | Boutiques |
|---|---|---|---|---|
| NORMAL | 1 000 FCFA/mois | 1 | 3 (Commerce), 1 sinon | 1 |
| MOYEN | 2 000 FCFA/mois | 2 combinables | 7 (Commerce), 1 sinon | 2 |
| PRO | 5 000 FCFA/mois | 3 | illimité | illimité |

Une limite `NULL` en base signifie « illimité » : c'est le cas de PRO. Les triggers serveur et `LimitesEngine` appliquent la même règle.

## Journal d'activité

La table `audit_logs` est remplie **uniquement par les triggers** (`app.tg_audit`) et aucun utilisateur ne peut y écrire ni l'effacer. Chaque ligne indique :
- qui a agi, quand et sur quoi ;
- l'action : création, modification, archivage ou restauration ;
- avant / après, en ne gardant que les champs modifiés.

Le journal est consultable avec la permission `audit.view` (Administration → Journal d'activité).

## Contacts

Un **seul** module `commun.contacts` pour toutes les activités : il remplace les anciens modules « Clients » de Commerce et Services. Une personne n'a qu'une fiche, avec une ou plusieurs relations : client, fournisseur, locataire, propriétaire ou prestataire.

- **Catégories de module** (`modules.categorie`) :
  - `ADMIN` : menu ☰ › Administration ;
  - `COMMUN` : section « Outils communs » de l'accueil, visible quelle que soit l'activité choisie ;
  - `METIER` : section de son activité.
- **Hors-ligne** : la liste, la fiche, la recherche et la détection des doublons utilisent la base locale.
  - La recherche ignore les accents, les majuscules et les variantes de l'alef en arabe.
  - Le téléphone est comparé chiffres seuls (« +223 70 11 22 33 » = « 70112233 »).
- **Doublons** : avant une création, les fiches ayant le même téléphone (8 derniers chiffres) ou le même nom complet sont proposées. L'utilisateur peut ajouter la relation à la fiche existante plutôt que d'en créer une seconde.
- **Droits** :

  | Permission | Action |
  |---|---|
  | `contacts.view` | consulter |
  | `contacts.create` | créer |
  | `contacts.update` | modifier |
  | `contacts.archive` | archiver / réactiver (aussi contrôlé par trigger) |

  Un contact n'est jamais supprimé : il est archivé, et son historique est conservé.
- **Historique** de la fiche : vide pour l'instant. Il sera alimenté par les paiements, créances et documents des étapes suivantes.

## Noyau financier (onglet Finances)

Trois modules de catégorie `FINANCES`, communs à toutes les activités et regroupés en onglets dans Finances :

| Module | Permission d'accès | Contenu |
|---|---|---|
| `finances.creances` | `receivables.view` | À recevoir / à payer (`engagements`) |
| `finances.paiements` | `payments.view` | Paiements et affectations |
| `finances.caisse` | `cash.view` | Caisses, sessions, mouvements d'espèces |

Le module `commerce.caisse` est supprimé : une caisse appartient à une boutique **ou** à une agence.

**Règles (appliquées par le serveur, vérifiées aussi dans l'application)** :
- Montants en **entiers** dans la devise de l'entreprise (FCFA sans centimes).
- Le **reste dû n'est jamais saisi** : total − affectations des paiements valides (`app.recalculer_engagement`).
- Un **paiement n'est jamais modifié ni supprimé**. On l'annule par un paiement inverse (`annule_paiement_id`), qui remet la créance en dû et crée le mouvement de caisse inverse.
- Une somme due ne peut être annulée qu'une fois ses paiements annulés.
- Caisse : une seule session ouverte par caisse ; pas de mouvement hors session ouverte ; pas de sortie au-delà du solde ; à la clôture, le serveur calcule le solde attendu et l'écart.
- Droits :

  | Action | Permissions |
  |---|---|
  | encaisser | `payments.create` |
  | verser (fournisseur) | `payments.create` + `receivables.manage` |
  | annuler un paiement | `payments.cancel` |
  | créances / dettes | `receivables.manage` |
  | caisse | `cash.open`, `cash.move`, `cash.close` |
  | créer une caisse | `entreprise.manage` |

  Chaque contrôle tient compte du site (boutique / agence) de l'utilisateur.

**Hors-ligne, sans perte ni doublon** :
- Un paiement est **une seule ligne** envoyée par `sync_push`. Ses affectations (colonne `affectations`) et son mouvement de caisse sont créés par trigger **dans la même transaction** : tout est appliqué, ou rien. Le rejeu est idempotent.
- L'appareil crée ces lignes dérivées avec **les mêmes identifiants** que le serveur (le mouvement porte l'identifiant du paiement). La copie serveur les remplace sans doublon.
- Le **réglé affiché** = réglé serveur + paiements de l'appareil non envoyés − annulations non envoyées (`EtatFinances`).
- Une écriture **refusée** par le serveur (dette déjà payée sur un autre appareil, caisse fermée…) reste visible, marquée « Refusé ». Elle n'est comptée nulle part, et l'utilisateur peut la **retirer**.
- `SyncQueueStore.enqueue(fusionner: false)` : une modification qui porte sur des champs refusés à la création (clôture de caisse, annulation d'une somme due) n'est **pas fusionnée** dans la création encore en attente. Elle part après la création et après les mouvements de la session.

### Dépenses (`finances.depenses`)

- Une dépense crée **toujours** une somme « à payer » liée : origine `DEPENSE`, avec le même identifiant que la dépense.
  - **Payée maintenant** : le serveur crée aussi le paiement (sortie) et, pour des espèces, la sortie de caisse. Tout cela part d'une seule ligne envoyée et s'applique dans une seule transaction.
  - **À payer plus tard** : la dépense apparaît dans « À payer » et se règle comme toute dette.
- **Identifiants connus d'avance par l'appareil** : somme liée = id de la dépense ; paiement = `paiement_id` fourni ; affectation et mouvement de caisse = id du paiement.
- **Ce qui ne se modifie pas** :
  - le montant d'une dépense : on l'annule puis on la ressaisit ;
  - la somme liée : elle se gère depuis la dépense (`ENGAGEMENT_LIE`).
- **Annulation** : le paiement est d'abord annulé (paiement inverse, caisse réajustée), puis la dépense. Les deux opérations partent dans cet ordre.
- **Catégories** : neuf catégories fournies (libellés traduits), créées pour chaque entreprise, plus celles créées par l'entreprise. Une catégorie se désactive mais ne se supprime pas.
- **Droits** : `expenses.view` (consulter), `expenses.create` (saisir ; payer tout de suite demande aussi `payments.create`), `expenses.update` (modifier, annuler, gérer les catégories).

**Données de démo** : une caisse par boutique d'Alpha et une créance de 50 000 FCFA d'Amadou Traoré (Boutique Marché).

## Documents (`commun.documents`)

Premier type de document : le **reçu de paiement** (un par encaissement). La facture, le devis et l'avoir viendront avec les modules Ventes et Services ; les séries correspondantes existent déjà.

**Numérotation hors-ligne par blocs réservés** :
- En ligne, l'appareil réserve un bloc de 50 numéros (RPC `reserver_bloc`, atomique) : par exemple `REC-2026-00051` à `00100`. La réserve est complétée automatiquement au démarrage et au retour du réseau, dès qu'il reste moins de 10 numéros.
- Hors-ligne, l'appareil émet ses documents dans son bloc. Les numéros sont **uniques et croissants par série et par année**.
- **Limite connue** : un bloc entamé puis abandonné (appareil réinitialisé, fin d'année) laisse des numéros inutilisés. Ces trous sont normaux et documentés.
- Sans aucun numéro disponible et sans réseau, l'émission est refusée avec un message clair. Aucun numéro provisoire n'est créé.

**Le serveur contrôle** :
- le bloc appartient à l'utilisateur et le numéro est dans le bloc ;
- il calcule lui-même le numéro final ;
- un seul reçu par paiement, et seulement pour un encaissement valide ;
- montant et contact repris du paiement ;
- un document émis ne se modifie plus.

**Contenu figé** : l'en-tête de l'entreprise (nom, adresse, téléphone, n° fiscal, RCCM), le contact, le montant et les sommes réglées sont copiés à l'émission. Le profil de l'entreprise est gardé en cache pour émettre hors-ligne. Si le paiement est annulé plus tard, le reçu affiche un tampon « ANNULÉ ».

**PDF, impression, partage** :
- Paquets `pdf` et `printing` : aperçu, impression, et partage natif (WhatsApp, e-mail…) via la feuille de partage du système.
- Chaque action est réservée à la permission correspondante : `documents.print`, `documents.share`.
- Le document est généré dans la **langue des documents** choisie dans le profil de l'entreprise (FR, EN ou AR, droite à gauche en arabe).
- Les polices Noto Sans et Noto Sans Arabic sont **embarquées** (`assets/fonts/`, licence OFL) : génération hors-ligne.
- Format A5.

## Agenda et notifications (`commun.agenda`)

**Agenda** (table `echeances`, hors-ligne) :
- Rappels, rendez-vous, tâches et relances, avec un rappel optionnel (15 min, 1 h, 1 jour avant).
- Une échéance peut être **confiée** à un membre actif de l'entreprise et **liée à une fiche** (contact, somme due, paiement, document). Le serveur vérifie que la fiche existe dans la même entreprise.
- Les **échéances des sommes dues** apparaissent automatiquement, calculées depuis les finances, sans double saisie.
- Regroupement : en retard, aujourd'hui, 7 prochains jours, plus tard. Filtre « Mes tâches ».
- « Planifier une relance » depuis une fiche contact ou une somme due.
- Droits : `agenda.view` pour consulter ; `agenda.manage` pour créer, modifier, confier et annuler. Le **responsable** d'une tâche peut la marquer faite sans `agenda.manage` (contrôlé par le serveur).

**Notifications** (cloche de l'accueil, avec compteur) :
- **Messages serveur** (table `notifications`), créés uniquement par trigger :
  - « on vous a confié une tâche » ;
  - « votre tâche a été faite ».

  Seul le destinataire les voit. Il peut seulement les marquer comme lues (hors-ligne compris).
- **Alertes calculées** à partir des données réelles, selon les droits :
  - échéance du jour, en retard ou dont le rappel est atteint ;
  - sommes à recevoir en retard ;
  - caisse ouverte depuis plus de 24 h ;
  - opérations refusées par le serveur.

**Synchronisation** : une modification envoyée séparément de sa création, dans le même cycle, part désormais de la version obtenue par la création (correction du moteur, testée).

## Recherche globale et tableau de bord

**Recherche globale** (champ en haut de l'accueil) :
- Elle porte sur les données de l'appareil, déjà filtrées par la RLS : contacts, sommes dues, paiements, dépenses, documents, agenda. Elle fonctionne donc **hors-ligne**, sans requête serveur.
- Elle ignore les accents, les majuscules et les variantes de l'arabe.
- Un nombre trouve aussi un téléphone, un montant exact ou un numéro de reçu.
- Chaque source n'est cherchée que si l'utilisateur a le droit de la consulter. Résultats limités à 5 par type.
- Pas de FTS SQLite : les volumes d'une PME tiennent largement en mémoire.

**Tableau de bord** (accueil › Tableau de bord, ou icône dans Finances) :
- Période : 7 jours, 30 jours ou mois en cours.
- Il suit l'**espace de travail** (vue globale, une activité ou une boutique), comme les indicateurs de l'accueil. Une dimension n'est filtrée que si l'utilisateur avait un vrai choix : avec une seule activité ou un seul site, les écritures de niveau entreprise restent visibles.
- Indicateurs : encaissé, versé, solde de la période, dépenses, à recevoir (dont en retard), à payer, en caisse. Les annulations et les écritures refusées sont exclues.
- Graphiques :
  - encaissé / versé par jour : colonnes groupées, une seule échelle, légende et info-bulles ;
  - dépenses par catégorie : barres d'une seule teinte, triées, montants écrits ; au-delà de 6 catégories, regroupement en « Autres » ;
  - « Qui vous doit le plus » : top 5, retard signalé par une icône et un libellé.
- Couleurs des graphiques : la paire bleu `#2A78D6` / orange `#EB6834`, validée pour le daltonisme. Le vert de la marque face à l'orange échoue au test protan (ΔE 4,4) ; il reste donc réservé à l'interface.
- Chaque section n'apparaît qu'avec le droit correspondant (`payments.view`, `expenses.view`, `receivables.view`, `cash.view`).

## Rapports, notes, pièces jointes et logo

**Rapports** (`commun.rapports`, permission `reports.view`) :
- Quatre rapports :
  - journal de trésorerie (entrées, sorties et solde ; les annulations sont affichées mais exclues des totaux) ;
  - dépenses par catégorie ;
  - balance âgée des sommes à recevoir (non échu, 1–30, 31–60, 61–90, plus de 90 jours, par contact) ;
  - clôtures de caisse (attendu, compté, écart).
- Chaque rapport suit l'espace de travail et la période du tableau de bord. Il n'est proposé que si l'utilisateur voit les données sources.
- Tout est calculé sur l'appareil, donc disponible hors-ligne. Export en PDF (A4 paysage, polices Noto, FR/EN/AR).

**Notes et pièces jointes** sur les fiches contact, somme due, paiement et dépense :
- Les droits suivent la fiche, côté serveur (`app.peut_cible`) comme dans l'application :

  | Fiche | Lecture | Ajout |
  |---|---|---|
  | Contact | `contacts.view` | `contacts.update` |
  | Somme due | `receivables.view` | `receivables.manage` |
  | Paiement | `payments.view` | `payments.create` |
  | Dépense | `expenses.view` | `expenses.create` |

- Notes (2000 caractères au plus) : ajoutées hors-ligne et synchronisées. Seul l'auteur modifie sa note. L'auteur ou un administrateur (`entreprise.manage`) la retire ; la suppression est logique.
- Pièces jointes : photo (appareil photo) ou fichier JPEG, PNG, WebP ou PDF, 10 Mo au plus.
  - Elles sont stockées dans le bucket privé `fichiers` (Supabase Storage), au chemin `entreprise/pj/TYPE/fiche/…`. Les politiques de `storage.objects` vérifient les mêmes droits que la fiche.
  - L'envoi demande le réseau ; hors-ligne, un message clair s'affiche.
  - La lecture passe par un lien temporaire (5 minutes).
  - Une pièce n'est jamais modifiée, seulement retirée.

**Logo de l'entreprise** :
- Il s'envoie depuis la fiche entreprise (`entreprise.manage`) : PNG, JPEG ou WebP, 2 Mo au plus.
- Il est stocké dans `fichiers/<entreprise>/logo/` et lisible par tous les membres.
- Une copie locale est gardée, si bien que les reçus PDF portent le logo même hors-ligne.

## Paramètres

L'écran Paramètres est organisé en sections. Chaque réglage n'apparaît qu'avec le droit correspondant :

| Section | Contenu | Droit |
|---|---|---|
| Compte | identité, mot de passe | tout utilisateur |
| Langue | FR / EN / AR | tout utilisateur |
| Entreprise | fiche de l'entreprise (logo compris) | module `admin.entreprise` |
| | paiements et reçus | `entreprise.manage` |
| | catégories de dépenses | `expenses.update` |
| Synchronisation | état, synchroniser maintenant | tout utilisateur |

**Paiements et reçus** (colonnes de `entreprises`, migration `20261012000100_socle_parametres.sql`) :
- **Modes de paiement proposés** : un sous-ensemble du catalogue commun (espèces, mobile money, carte, virement, chèque, autre).
  - Il faut au moins un mode. Le serveur les vérifie, sans doublon et dans l'ordre du catalogue.
  - Les formulaires de paiement et de dépense ne proposent que ces modes, y compris hors-ligne grâce au profil en cache.
  - Le serveur refuse un nouveau paiement dont le mode est retiré (`MODE_PAIEMENT_DESACTIVE`).
  - Exception : un paiement daté du jour du changement ou d'avant reste accepté. L'argent saisi hors-ligne avant le changement a bien été reçu. Les annulations reprennent le mode d'origine.
- **Mention en bas des reçus** (300 caractères au plus) : elle est figée dans le contenu du reçu à son émission, si bien que les reçus déjà émis ne changent pas.
- Ces réglages se modifient en ligne. Une modification masquée par la RLS est signalée comme un refus, jamais comme un succès.

## Mise en production (liste de contrôle)

- **Réactiver la confirmation des e-mails** dans Supabase Cloud (Authentication › Sign In / Providers › Email › *Confirm email*). En local, elle est désactivée (`enable_confirmations = false`). La protection des invitations (`EMAIL_NON_CONFIRME`) en dépend : sans confirmation, n'importe qui pourrait créer un compte à l'adresse invitée.
- Ne jamais mettre la clé `service_role` dans l'application. Seule la clé publique (anon) est livrée.
- Identifiants Google : dans `supabase/.env` (jamais versionné) en local, et dans le tableau de bord Supabase en production.
- Renseigner `site_url` et les URL de redirection autorisées avec le vrai domaine. Configurer un SMTP pour les e-mails d'authentification.
- Appliquer les migrations avec `supabase db push`, puis lancer `supabase test db` sur une base de recette.
- Serveur web : renvoyer `index.html` pour toutes les routes (voir les limites ci-dessous).

## Limites connues de la V1

- Finances : le catalogue des modes de paiement est commun ; chaque entreprise choisit ceux qu'elle propose, sans en créer de nouveaux. La permission `payments.refund` n'est pas encore utilisée.
- Les notifications sont internes à l'application. Il n'y a pas de notification du téléphone quand l'application est fermée : cela demanderait Firebase Cloud Messaging (FCM) et une configuration Android/iOS.

- Les invitations sont partagées par lien ou code (WhatsApp, SMS…). L'envoi automatique par e-mail (Edge Function + SMTP) n'est pas livré.
- Les affectations membre ↔ périmètre se font en ligne uniquement.
- Le passage de l'essai à un abonnement payant (facturation) se fait hors application.
- Il n'y a pas encore de sélecteur d'entreprise pour un compte membre de plusieurs entreprises.
- En production, le serveur web doit renvoyer `index.html` pour toutes les routes (URL sans `#`, liens `/join-company`).
