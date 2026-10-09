import 'package:drift/drift.dart';

// =============================================================================
// Tables d'infrastructure
// =============================================================================

/// Cache clé → JSON (contexte de session, listes consultables hors-ligne).
class JsonCache extends Table {
  TextColumn get cle => text()();
  TextColumn get contenu => text()();
  DateTimeColumn get majLe => dateTime()();

  @override
  Set<Column> get primaryKey => {cle};
}

/// File d'attente des opérations locales à envoyer au serveur.
@DataClassName('SyncQueueRow')
class SyncQueue extends Table {
  /// Identifiant d'opération = clé d'idempotence côté serveur.
  TextColumn get id => text()();

  /// Une opération n'est jamais envoyée sous l'identité d'un autre utilisateur.
  TextColumn get userId => text()();
  TextColumn get entityTable => text()();
  TextColumn get recordId => text()();
  TextColumn get operation => text()();
  TextColumn get payload => text()();
  IntColumn get baseVersion => integer().nullable()();
  TextColumn get status => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Curseur de synchronisation descendante par table et par entreprise.
/// Stocké en texte brut (horodatage serveur, précision microseconde).
class SyncCursors extends Table {
  TextColumn get entityTable => text()();
  TextColumn get scope => text()();
  TextColumn get lastUpdatedAt => text()();

  @override
  Set<Column> get primaryKey => {entityTable, scope};
}

/// Journal de synchronisation (diagnostic), borné en taille.
@DataClassName('SyncJournalRow')
class SyncJournal extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get at => dateTime()();
  TextColumn get level => text()();
  TextColumn get opId => text().nullable()();
  TextColumn get message => text()();
}

// =============================================================================
// Tables métier synchronisées
// Convention : id, version (null = jamais synchronisé), updatedAt, deletedAt,
// syncStatus.
// =============================================================================

/// Contacts (socle commun). [cleRecherche] : nom, prénom, e-mail et ville
/// normalisés (accents, variantes de l'arabe) ; [telephoneChiffres] : chiffres
/// seuls, pour la recherche et la détection des doublons hors-ligne.
@DataClassName('ContactRow')
class Contacts extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get typePersonne => text()();
  TextColumn get nom => text()();
  TextColumn get prenom => text().nullable()();
  TextColumn get telephone => text().nullable()();
  TextColumn get whatsapp => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get adresse => text().nullable()();
  TextColumn get ville => text().nullable()();
  TextColumn get remarque => text().nullable()();

  /// Codes séparés par des virgules (CLIENT,FOURNISSEUR…).
  TextColumn get relations => text().withDefault(const Constant(''))();
  TextColumn get statut => text()();
  TextColumn get cleRecherche => text().withDefault(const Constant(''))();
  TextColumn get telephoneChiffres => text().withDefault(const Constant(''))();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- Noyau financier --------------------------------------------------------
// Montants en entiers (unités de la devise). Dates sans heure en texte
// « AAAA-MM-JJ » (aucun décalage de fuseau).

/// À recevoir / à payer. [montantRegle] : valeur serveur ; les paiements
/// locaux pas encore envoyés s'y ajoutent à l'affichage.
@DataClassName('EngagementRow')
class Engagements extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get activiteCode => text().nullable()();
  TextColumn get perimetreId => text().nullable()();
  TextColumn get sens => text()();
  TextColumn get contactId => text().nullable()();
  TextColumn get libelle => text()();
  IntColumn get montantTotal => integer()();
  IntColumn get montantRegle => integer().withDefault(const Constant(0))();
  TextColumn get dateEngagement => text()();
  TextColumn get echeance => text().nullable()();
  TextColumn get origineType => text().withDefault(const Constant('MANUEL'))();
  TextColumn get statut => text()();
  TextColumn get motifAnnulation => text().nullable()();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Paiements : jamais modifiés, annulés par un paiement inverse.
@DataClassName('PaiementRow')
class Paiements extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get activiteCode => text().nullable()();
  TextColumn get perimetreId => text().nullable()();
  TextColumn get sens => text()();
  IntColumn get montant => integer()();
  TextColumn get modeCode => text()();
  DateTimeColumn get datePaiement => dateTime()();
  TextColumn get contactId => text().nullable()();
  TextColumn get reference => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get sessionId => text().nullable()();

  /// JSON des affectations demandées (`[{id, engagement_id, montant}]`).
  TextColumn get affectations => text().withDefault(const Constant('[]'))();
  TextColumn get annulePaiementId => text().nullable()();
  TextColumn get statut => text()();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()();
  // v11 : nature (apport, retrait, transfert…) et transfert d'appartenance.
  TextColumn get nature => text().nullable()();
  TextColumn get transfertId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Transferts d'argent : leurs deux jambes sont des [Paiements] portant
/// `transfert_id`, créées localement avec les mêmes identifiants que le serveur.
@DataClassName('TransfertRow')
class TransfertsTresorerie extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get perimetreSourceId => text().nullable()();
  TextColumn get perimetreDestId => text().nullable()();
  TextColumn get modeSource => text()();
  TextColumn get modeDest => text()();
  IntColumn get montant => integer()();
  TextColumn get sessionSourceId => text().nullable()();
  TextColumn get sessionDestId => text().nullable()();
  TextColumn get sortieId => text()();
  TextColumn get entreeId => text()();
  DateTimeColumn get dateTransfert => dateTime()();
  TextColumn get motif => text().nullable()();
  TextColumn get statut => text()();
  TextColumn get motifAnnulation => text().nullable()();
  TextColumn get annulationSortieId => text().nullable()();
  TextColumn get annulationEntreeId => text().nullable()();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Affectations : créées localement avec leur paiement (même identifiant
/// que côté serveur), puis remplacées par la copie serveur.
@DataClassName('AffectationRow')
class PaiementAffectations extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get paiementId => text()();
  TextColumn get engagementId => text()();
  IntColumn get montant => integer()();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CaisseRow')
class Caisses extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get perimetreId => text()();
  TextColumn get nom => text()();
  BoolColumn get estActive => boolean().withDefault(const Constant(true))();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SessionCaisseRow')
class CaisseSessions extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get caisseId => text()();
  TextColumn get perimetreId => text()();
  TextColumn get statut => text()();
  IntColumn get soldeInitial => integer()();
  DateTimeColumn get ouverteLe => dateTime()();
  TextColumn get ouvertePar => text().nullable()();
  DateTimeColumn get fermeeLe => dateTime().nullable()();
  TextColumn get fermeePar => text().nullable()();
  IntColumn get soldeTheorique => integer().nullable()();
  IntColumn get soldeReel => integer().nullable()();
  IntColumn get ecart => integer().nullable()();
  TextColumn get noteCloture => text().nullable()();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()();
  // v11 : justification d'un écart à la clôture.
  TextColumn get motifEcart => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Mouvements d'espèces. Ceux d'un paiement portent l'identifiant du paiement.
@DataClassName('MouvementCaisseRow')
class CaisseMouvements extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get sessionId => text()();
  TextColumn get caisseId => text()();
  TextColumn get perimetreId => text()();
  TextColumn get type => text()();
  TextColumn get sens => text()();
  IntColumn get montant => integer()();
  TextColumn get paiementId => text().nullable()();
  TextColumn get motif => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Catégories de dépenses : [code] pour les catégories fournies (libellé
/// traduit), [nom] pour celles créées par l'entreprise.
@DataClassName('CategorieDepenseRow')
class DepenseCategories extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get code => text().nullable()();
  TextColumn get nom => text().nullable()();
  BoolColumn get estActive => boolean().withDefault(const Constant(true))();
  IntColumn get ordre => integer().withDefault(const Constant(100))();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Dépenses. La somme à payer liée porte le même identifiant ; le paiement
/// immédiat porte [paiementId].
@DataClassName('DepenseRow')
class Depenses extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get activiteCode => text().nullable()();
  TextColumn get perimetreId => text().nullable()();
  TextColumn get categorieId => text()();
  TextColumn get libelle => text()();
  IntColumn get montant => integer()();
  TextColumn get dateDepense => text()();
  TextColumn get contactId => text().nullable()();
  TextColumn get reglement => text()();
  TextColumn get modeCode => text().nullable()();
  TextColumn get sessionId => text().nullable()();
  TextColumn get paiementId => text().nullable()();
  TextColumn get echeance => text().nullable()();
  TextColumn get reference => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get statut => text()();
  TextColumn get motifAnnulation => text().nullable()();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()();
  // v10 : bénéficiaire libre, échéance de dépense courante réglée.
  TextColumn get beneficiaire => text().nullable()();
  TextColumn get couranteId => text().nullable()();
  TextColumn get echeancePrevue => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Dépenses courantes (modèles récurrents). Les échéances payées sont des
/// [Depenses] portant `courante_id`.
@DataClassName('DepenseCouranteRow')
class DepensesCourantes extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get activiteCode => text().nullable()();
  TextColumn get perimetreId => text().nullable()();
  TextColumn get categorieId => text()();
  TextColumn get nom => text()();
  IntColumn get montantPrevu => integer()();
  TextColumn get typeMontant => text()();
  TextColumn get periode => text()();
  IntColumn get intervalle => integer().withDefault(const Constant(1))();
  TextColumn get dateDebut => text()();
  TextColumn get prochaineEcheance => text()();
  TextColumn get modeCode => text().nullable()();
  TextColumn get beneficiaire => text().nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get estActive => boolean().withDefault(const Constant(true))();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Blocs de numéros réservés par cet appareil (jamais synchronisés : propres
/// à l'appareil et à l'utilisateur). [prochain] avance à chaque émission.
@DataClassName('NumeroBlocRow')
class NumeroBlocs extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get userId => text()();
  TextColumn get type => text()();
  TextColumn get prefixe => text()();
  IntColumn get annee => integer()();
  IntColumn get debut => integer()();
  IntColumn get fin => integer()();
  IntColumn get prochain => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Documents émis (contenu figé en JSON).
@DataClassName('DocumentRow')
class Documents extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get type => text()();
  TextColumn get numero => text()();
  TextColumn get blocId => text()();
  IntColumn get sequence => integer()();
  TextColumn get langue => text()();
  DateTimeColumn get dateDocument => dateTime()();
  TextColumn get perimetreId => text().nullable()();
  TextColumn get contactId => text().nullable()();
  IntColumn get montant => integer()();
  TextColumn get origineType => text()();
  TextColumn get origineId => text().nullable()();
  TextColumn get contenu => text()();
  TextColumn get statut => text()();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Agenda : rappels, rendez-vous, tâches, relances.
@DataClassName('EcheanceRow')
class Echeances extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get perimetreId => text().nullable()();
  TextColumn get type => text()();
  TextColumn get titre => text()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get dateHeure => dateTime()();
  IntColumn get rappelMinutes => integer().nullable()();
  TextColumn get responsableId => text().nullable()();
  TextColumn get responsableNom => text().nullable()();
  TextColumn get cibleType => text().nullable()();
  TextColumn get cibleId => text().nullable()();
  TextColumn get statut => text()();
  DateTimeColumn get faitLe => dateTime().nullable()();
  TextColumn get createdBy => text().nullable()();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Notifications reçues (créées par le serveur, propres à l'utilisateur).
@DataClassName('NotificationRow')
class Notifications extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get destinataireId => text()();
  TextColumn get type => text()();
  TextColumn get parametres => text().withDefault(const Constant('{}'))();
  TextColumn get cibleType => text().nullable()();
  TextColumn get cibleId => text().nullable()();
  TextColumn get auteurNom => text().nullable()();
  DateTimeColumn get lueLe => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Notes sur une fiche (contact, somme due, paiement, dépense).
@DataClassName('NoteRow')
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get cibleType => text()();
  TextColumn get cibleId => text()();
  TextColumn get texte => text()();
  TextColumn get auteurNom => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Pièces jointes : description locale ; le fichier reste dans le stockage.
@DataClassName('PieceJointeRow')
class PiecesJointes extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get cibleType => text()();
  TextColumn get cibleId => text()();
  TextColumn get chemin => text()();
  TextColumn get nomFichier => text()();
  TextColumn get typeMime => text()();
  IntColumn get taille => integer()();
  TextColumn get auteurNom => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- Commerce ----------------------------------------------------------------
// Quantités en entiers : dix-millièmes de l'unité (numeric(14,4) côté serveur),
// jamais de flottants. Prix en unités entières de la devise. Listes (unités,
// lignes, photos) en JSON.

@DataClassName('CategorieProduitRow')
class CategoriesProduits extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get nom => text()();
  TextColumn get icone => text().nullable()();
  TextColumn get couleur => text().nullable()();
  IntColumn get ordre => integer().withDefault(const Constant(100))();
  BoolColumn get estActive => boolean().withDefault(const Constant(true))();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Produits du catalogue. [cleRecherche] : nom, référence, marque normalisés.
@DataClassName('ProduitRow')
class Produits extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get categorieId => text().nullable()();
  TextColumn get nom => text()();
  TextColumn get reference => text().nullable()();
  TextColumn get codeBarres => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get photos => text().withDefault(const Constant('[]'))();
  TextColumn get uniteBase => text()();
  TextColumn get unites => text().withDefault(const Constant('[]'))();
  IntColumn get prixDetail => integer().withDefault(const Constant(0))();
  IntColumn get prixGros => integer().nullable()();
  IntColumn get prixAchat => integer().nullable()();
  BoolColumn get venteFractionnee => boolean().withDefault(const Constant(false))();
  IntColumn get pasMinimum => integer().withDefault(const Constant(10000))();
  IntColumn get seuilAlerte => integer().withDefault(const Constant(0))();
  TextColumn get attributs => text().withDefault(const Constant('{}'))();
  TextColumn get fournisseurId => text().nullable()();
  BoolColumn get estActif => boolean().withDefault(const Constant(true))();
  TextColumn get cleRecherche => text().withDefault(const Constant(''))();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Stock connu du serveur, par boutique (jamais écrit par l'appareil : les
/// mouvements locaux non envoyés s'y ajoutent à l'affichage).
@DataClassName('StockRow')
class Stocks extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get perimetreId => text()();
  TextColumn get produitId => text()();
  IntColumn get quantite => integer().withDefault(const Constant(0))();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MouvementStockRow')
class MouvementsStock extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get perimetreId => text()();
  TextColumn get produitId => text()();
  TextColumn get type => text()();
  TextColumn get motif => text()();
  IntColumn get quantite => integer()();
  IntColumn get quantiteSaisie => integer()();
  TextColumn get uniteSaisie => text()();
  IntColumn get facteur => integer().withDefault(const Constant(10000))();

  /// Variation signée (estimée localement tant que le serveur n'a pas répondu).
  IntColumn get delta => integer().withDefault(const Constant(0))();
  IntColumn get stockAvant => integer().nullable()();
  IntColumn get stockApres => integer().nullable()();
  TextColumn get origineType => text().withDefault(const Constant('MANUEL'))();
  TextColumn get origineId => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get dateMouvement => dateTime()();
  TextColumn get auteurNom => text().nullable()();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TransfertStockRow')
class TransfertsStock extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get produitId => text()();
  TextColumn get dePerimetreId => text()();
  TextColumn get versPerimetreId => text()();
  IntColumn get quantite => integer()();
  IntColumn get quantiteSaisie => integer()();
  TextColumn get uniteSaisie => text()();
  IntColumn get facteur => integer()();
  TextColumn get mouvementEntreeId => text()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get dateTransfert => dateTime()();
  TextColumn get auteurNom => text().nullable()();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AchatRow')
class Achats extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get perimetreId => text()();
  TextColumn get fournisseurId => text().nullable()();
  TextColumn get reference => text().nullable()();
  TextColumn get dateAchat => text()();
  TextColumn get lignes => text()();
  IntColumn get total => integer().withDefault(const Constant(0))();
  TextColumn get statut => text()();
  TextColumn get note => text().nullable()();
  TextColumn get auteurNom => text().nullable()();
  DateTimeColumn get creeLe => dateTime()();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ReceptionRow')
class Receptions extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get achatId => text()();
  TextColumn get perimetreId => text().nullable()();
  TextColumn get lignes => text()();
  DateTimeColumn get dateReception => dateTime()();
  TextColumn get note => text().nullable()();
  TextColumn get auteurNom => text().nullable()();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('VenteRow')
class Ventes extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get perimetreId => text()();
  TextColumn get contactId => text().nullable()();
  TextColumn get mode => text()();
  TextColumn get lignes => text()();
  IntColumn get remise => integer().withDefault(const Constant(0))();
  IntColumn get total => integer().withDefault(const Constant(0))();
  DateTimeColumn get dateVente => dateTime()();
  TextColumn get reglement => text()();
  TextColumn get modeCode => text().nullable()();
  TextColumn get sessionId => text().nullable()();
  TextColumn get paiementId => text().nullable()();
  TextColumn get statut => text()();
  TextColumn get motifAnnulation => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get auteurNom => text().nullable()();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()();
  // Reçu (v9) : numéro commercial « REC-AAAAMMJJ-A001 », figé à la vente.
  TextColumn get numero => text().nullable()();
  TextColumn get dateCommerciale => text().nullable()();
  TextColumn get poste => text().nullable()();
  IntColumn get sequence => integer().nullable()();
  IntColumn get montantPaye => integer().withDefault(const Constant(0))();
  DateTimeColumn get annuleeLe => dateTime().nullable()();
  TextColumn get annuleeParNom => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Lettre de cet appareil dans chaque boutique (attribuée par le serveur) et
/// compteur des reçus du jour. Jamais purgée : un numéro n'est jamais réutilisé.
@DataClassName('PosteVenteRow')
class PostesVente extends Table {
  TextColumn get perimetreId => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get code => text()();

  /// Jour du compteur (AAAA-MM-JJ) et dernière séquence utilisée ce jour-là.
  TextColumn get jour => text()();
  IntColumn get dernier => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {perimetreId};
}

/// Photos de produits gardées sur l'appareil (miniatures) : affichage
/// immédiat et hors-ligne ; [aEnvoyer] tant que le fichier n'est pas en ligne.
@DataClassName('PhotoLocaleRow')
class PhotosLocales extends Table {
  TextColumn get chemin => text()();
  BlobColumn get octets => blob()();
  BoolColumn get aEnvoyer => boolean().withDefault(const Constant(false))();
  DateTimeColumn get majLe => dateTime()();

  @override
  Set<Column> get primaryKey => {chemin};
}

@DataClassName('PerimetreRow')
class Perimetres extends Table {
  TextColumn get id => text()();
  TextColumn get entrepriseId => text()();
  TextColumn get activiteCode => text()();
  TextColumn get type => text()();
  TextColumn get nom => text()();
  TextColumn get code => text().nullable()();
  BoolColumn get estActif => boolean().withDefault(const Constant(true))();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}
