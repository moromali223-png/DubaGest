import '../../../../core/sync/sync_models.dart';
import 'quantite.dart';

export 'quantite.dart';

// =============================================================================
// Catalogue
// =============================================================================

/// Catégorie de produits (2 niveaux : catégorie › sous-catégorie).
class CategorieProduit {
  const CategorieProduit({
    required this.id,
    required this.entrepriseId,
    required this.nom,
    this.parentId,
    this.icone,
    this.couleur,
    this.ordre = 100,
    this.estActive = true,
    this.version,
    this.syncStatus = RecordSyncStatus.synced,
  });

  final String id;
  final String entrepriseId;
  final String? parentId;
  final String nom;

  /// Code d'icône (voir `IconesCategories`).
  final String? icone;

  /// Couleur « #RRGGBB ».
  final String? couleur;
  final int ordre;
  final bool estActive;
  final int? version;
  final RecordSyncStatus syncStatus;

  bool get estRacine => parentId == null;

  CategorieProduit copyWith({String? nom, String? Function()? icone, String? Function()? couleur, bool? estActive,
          String? Function()? parentId}) =>
      CategorieProduit(
        id: id,
        entrepriseId: entrepriseId,
        parentId: parentId == null ? this.parentId : parentId(),
        nom: nom ?? this.nom,
        icone: icone == null ? this.icone : icone(),
        couleur: couleur == null ? this.couleur : couleur(),
        ordre: ordre,
        estActive: estActive ?? this.estActive,
        version: version,
        syncStatus: syncStatus,
      );
}

/// Unité supplémentaire d'un produit : « 1 carton = 40 pièces ».
/// Un prix `null` est calculé (facteur × prix de l'unité de base) ; un prix
/// renseigné a été fixé par le commerçant.
class UniteProduit {
  const UniteProduit({
    required this.id,
    required this.nom,
    required this.facteur,
    this.prixDetail,
    this.prixGros,
    this.prixAchat,
  });

  final String id;
  final String nom;
  final Qte facteur;
  final int? prixDetail;
  final int? prixGros;
  final int? prixAchat;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nom': nom,
        'facteur': facteur.json,
        'prix_detail': prixDetail,
        'prix_gros': prixGros,
        'prix_achat': prixAchat,
      };

  static UniteProduit fromJson(Map<String, dynamic> j) => UniteProduit(
        id: j['id'] as String,
        nom: j['nom'] as String,
        facteur: Qte.depuis(j['facteur'] as num),
        prixDetail: (j['prix_detail'] as num?)?.toInt(),
        prixGros: (j['prix_gros'] as num?)?.toInt(),
        prixAchat: (j['prix_achat'] as num?)?.toInt(),
      );
}

/// Unité telle qu'utilisée pour acheter, vendre ou compter : prix effectifs.
class UniteVente {
  const UniteVente({
    required this.id,
    required this.nom,
    required this.facteur,
    required this.prixDetail,
    this.prixGros,
    this.prixAchat,
    this.prixDetailFixe = false,
  });

  /// Identifiant de l'unité de base.
  static const idBase = 'base';

  final String id;
  final String nom;
  final Qte facteur;
  final int prixDetail;
  final int? prixGros;
  final int? prixAchat;

  /// Prix de détail fixé par le commerçant (différent du calcul).
  final bool prixDetailFixe;

  bool get estBase => id == idBase;
  int prix(ModeVente mode) => mode == ModeVente.gros ? (prixGros ?? prixDetail) : prixDetail;
}

class Produit {
  const Produit({
    required this.id,
    required this.entrepriseId,
    required this.nom,
    required this.uniteBase,
    this.categorieId,
    this.reference,
    this.codeBarres,
    this.description,
    this.photos = const [],
    this.unites = const [],
    this.prixDetail = 0,
    this.prixGros,
    this.prixAchat,
    this.venteFractionnee = false,
    this.pasMinimum = Qte.un,
    this.seuilAlerte = Qte.zero,
    this.attributs = const {},
    this.fournisseurId,
    this.estActif = true,
    this.version,
    this.syncStatus = RecordSyncStatus.synced,
  });

  final String id;
  final String entrepriseId;
  final String? categorieId;
  final String nom;
  final String? reference;
  final String? codeBarres;
  final String? description;

  /// Chemins des photos ; la première est la photo principale.
  final List<String> photos;
  final String uniteBase;
  final List<UniteProduit> unites;
  final int prixDetail;
  final int? prixGros;
  final int? prixAchat;
  final bool venteFractionnee;
  final Qte pasMinimum;

  /// Seuil d'alerte, en unité de base.
  final Qte seuilAlerte;

  /// Caractéristiques libres (marque, couleur, dimensions…).
  final Map<String, String> attributs;
  final String? fournisseurId;
  final bool estActif;
  final int? version;
  final RecordSyncStatus syncStatus;

  String? get photoPrincipale => photos.isEmpty ? null : photos.first;
  bool get aPlusieursUnites => unites.isNotEmpty;
  bool get venteEnGros => prixGros != null || unites.any((u) => u.prixGros != null);

  UniteVente get uniteDeBase => UniteVente(
        id: UniteVente.idBase,
        nom: uniteBase,
        facteur: Qte.un,
        prixDetail: prixDetail,
        prixGros: prixGros,
        prixAchat: prixAchat,
      );

  /// Toutes les unités, de la plus petite à la plus grande, avec leurs prix
  /// effectifs (fixés, ou calculés depuis l'unité de base).
  List<UniteVente> get toutesUnites {
    final autres = [...unites]..sort((a, b) => a.facteur.brut.compareTo(b.facteur.brut));
    return [
      uniteDeBase,
      for (final u in autres)
        UniteVente(
          id: u.id,
          nom: u.nom,
          facteur: u.facteur,
          prixDetail: u.prixDetail ?? CalculPrix.lot(prixDetail, u.facteur),
          prixGros: u.prixGros ?? (prixGros == null ? null : CalculPrix.lot(prixGros!, u.facteur)),
          prixAchat: u.prixAchat ?? (prixAchat == null ? null : CalculPrix.lot(prixAchat!, u.facteur)),
          prixDetailFixe: u.prixDetail != null && u.prixDetail != CalculPrix.lot(prixDetail, u.facteur),
        ),
    ];
  }

  UniteVente unite(String? id) =>
      toutesUnites.where((u) => u.id == id).firstOrNull ?? uniteDeBase;

  UniteVente uniteNommee(String nom) =>
      toutesUnites.where((u) => u.nom == nom).firstOrNull ?? uniteDeBase;

  /// La plus grande unité (affichage « 100 cartons »).
  UniteVente get plusGrandeUnite => toutesUnites.last;

  Produit copyWith({
    String? Function()? categorieId,
    String? nom,
    String? Function()? reference,
    String? Function()? codeBarres,
    String? Function()? description,
    List<String>? photos,
    String? uniteBase,
    List<UniteProduit>? unites,
    int? prixDetail,
    int? Function()? prixGros,
    int? Function()? prixAchat,
    bool? venteFractionnee,
    Qte? pasMinimum,
    Qte? seuilAlerte,
    Map<String, String>? attributs,
    String? Function()? fournisseurId,
    bool? estActif,
  }) =>
      Produit(
        id: id,
        entrepriseId: entrepriseId,
        categorieId: categorieId == null ? this.categorieId : categorieId(),
        nom: nom ?? this.nom,
        reference: reference == null ? this.reference : reference(),
        codeBarres: codeBarres == null ? this.codeBarres : codeBarres(),
        description: description == null ? this.description : description(),
        photos: photos ?? this.photos,
        uniteBase: uniteBase ?? this.uniteBase,
        unites: unites ?? this.unites,
        prixDetail: prixDetail ?? this.prixDetail,
        prixGros: prixGros == null ? this.prixGros : prixGros(),
        prixAchat: prixAchat == null ? this.prixAchat : prixAchat(),
        venteFractionnee: venteFractionnee ?? this.venteFractionnee,
        pasMinimum: pasMinimum ?? this.pasMinimum,
        seuilAlerte: seuilAlerte ?? this.seuilAlerte,
        attributs: attributs ?? this.attributs,
        fournisseurId: fournisseurId == null ? this.fournisseurId : fournisseurId(),
        estActif: estActif ?? this.estActif,
        version: version,
        syncStatus: syncStatus,
      );
}

/// Calculs de prix entre unités : le commerçant saisit un prix, l'application
/// calcule les autres.
abstract final class CalculPrix {
  /// Prix d'un lot depuis le prix de l'unité de base (1 000 F × 100 = 100 000 F).
  static int lot(int prixBase, Qte facteur) => (prixBase * facteur.brut / Qte.echelle).round();

  /// Prix de l'unité de base depuis le prix d'un lot (95 000 F ÷ 100 = 950 F).
  static int base(int prixLot, Qte facteur) =>
      facteur.brut <= 0 ? prixLot : (prixLot * Qte.echelle / facteur.brut).round();

  /// Prix à enregistrer pour un lot : `null` s'il est égal au calcul
  /// (il suivra alors le prix de base), sinon le prix fixé.
  static int? aEnregistrer(int? saisi, int? prixBase, Qte facteur) =>
      saisi == null || (prixBase != null && saisi == lot(prixBase, facteur)) ? null : saisi;

  /// Écart en % d'un prix fixé par rapport au calcul (négatif = remise).
  static double ecartPourcent(int fixe, int calcule) => calcule == 0 ? 0 : (fixe - calcule) * 100 / calcule;

  /// Bénéfice d'une unité (prix de vente − prix d'achat).
  static int? benefice(int vente, int? achat) => achat == null ? null : vente - achat;
}

// =============================================================================
// Stock
// =============================================================================

enum StatutStock { enStock, faible, rupture }

enum TypeMouvementStock {
  entree('ENTREE'),
  sortie('SORTIE'),
  transfertSortie('TRANSFERT_SORTIE'),
  transfertEntree('TRANSFERT_ENTREE'),
  inventaire('INVENTAIRE');

  const TypeMouvementStock(this.code);
  final String code;

  static TypeMouvementStock parse(String? code) => values.firstWhere((t) => t.code == code, orElse: () => entree);
}

enum MotifMouvement {
  achat('ACHAT'),
  retour('RETOUR'),
  ajustement('AJUSTEMENT'),
  vente('VENTE'),
  perte('PERTE'),
  casse('CASSE'),
  transfert('TRANSFERT'),
  erreurComptage('ERREUR_COMPTAGE'),
  manquant('MANQUANT'),
  autre('AUTRE');

  const MotifMouvement(this.code);
  final String code;

  static MotifMouvement parse(String? code) => values.firstWhere((m) => m.code == code, orElse: () => autre);

  static const entrees = [achat, retour, ajustement, autre];
  static const sorties = [vente, perte, casse, ajustement, autre];
  static const inventaire = [erreurComptage, casse, perte, manquant, autre];
}

/// Filtre de l'historique : familles de mouvements telles que l'utilisateur
/// les comprend.
enum FamilleMouvement { entrees, sorties, transferts, ajustements, pertes }

class MouvementStock {
  const MouvementStock({
    required this.id,
    required this.entrepriseId,
    required this.perimetreId,
    required this.produitId,
    required this.type,
    required this.motif,
    required this.quantite,
    required this.quantiteSaisie,
    required this.uniteSaisie,
    required this.facteur,
    required this.delta,
    required this.date,
    this.stockAvant,
    this.stockApres,
    this.origineType = 'MANUEL',
    this.origineId,
    this.note,
    this.auteurNom,
    this.version,
    this.syncStatus = RecordSyncStatus.synced,
  });

  final String id;
  final String entrepriseId;
  final String perimetreId;
  final String produitId;
  final TypeMouvementStock type;
  final MotifMouvement motif;

  /// En unité de base, positive (inventaire : quantité comptée).
  final Qte quantite;
  final Qte quantiteSaisie;
  final String uniteSaisie;
  final Qte facteur;

  /// Variation signée du stock.
  final Qte delta;
  final Qte? stockAvant;
  final Qte? stockApres;
  final String origineType;
  final String? origineId;
  final String? note;
  final DateTime date;
  final String? auteurNom;
  final int? version;
  final RecordSyncStatus syncStatus;

  /// Pas encore pris en compte par le serveur : s'ajoute au stock affiché.
  bool get enAttente => syncStatus == RecordSyncStatus.pendingSync;
  bool get refuse => syncStatus == RecordSyncStatus.syncError;

  FamilleMouvement get famille => switch ((type, motif)) {
        (TypeMouvementStock.transfertSortie || TypeMouvementStock.transfertEntree, _) => FamilleMouvement.transferts,
        (TypeMouvementStock.inventaire, _) || (_, MotifMouvement.ajustement) => FamilleMouvement.ajustements,
        (_, MotifMouvement.perte || MotifMouvement.casse) => FamilleMouvement.pertes,
        (TypeMouvementStock.entree, _) => FamilleMouvement.entrees,
        _ => FamilleMouvement.sorties,
      };
}

/// Quantité du serveur pour un produit dans une boutique.
class StockBoutique {
  const StockBoutique({required this.perimetreId, required this.produitId, required this.quantite});
  final String perimetreId;
  final String produitId;
  final Qte quantite;
}

class Transfert {
  const Transfert({
    required this.id,
    required this.entrepriseId,
    required this.produitId,
    required this.dePerimetreId,
    required this.versPerimetreId,
    required this.quantite,
    required this.quantiteSaisie,
    required this.uniteSaisie,
    required this.facteur,
    required this.mouvementEntreeId,
    required this.date,
    this.note,
    this.auteurNom,
    this.syncStatus = RecordSyncStatus.synced,
  });

  final String id;
  final String entrepriseId;
  final String produitId;
  final String dePerimetreId;
  final String versPerimetreId;
  final Qte quantite;
  final Qte quantiteSaisie;
  final String uniteSaisie;
  final Qte facteur;
  final String mouvementEntreeId;
  final DateTime date;
  final String? note;
  final String? auteurNom;
  final RecordSyncStatus syncStatus;
}

// =============================================================================
// Achats et ventes
// =============================================================================

/// Ligne d'un achat ou d'une vente, dans l'unité choisie.
class LigneOperation {
  const LigneOperation({
    required this.id,
    required this.produitId,
    required this.unite,
    required this.facteur,
    required this.quantite,
    required this.prixUnitaire,
    this.recu = Qte.zero,
  });

  final String id;
  final String produitId;
  final String unite;
  final Qte facteur;
  final Qte quantite;
  final int prixUnitaire;

  /// Achat : quantité déjà reçue (même unité).
  final Qte recu;

  Qte get quantiteBase => quantite.fois(facteur);
  int get montant => quantite.montant(prixUnitaire);
  Qte get reste => (quantite - recu).max(Qte.zero);
  bool get complete => recu >= quantite;

  LigneOperation copyWith({Qte? quantite, int? prixUnitaire, Qte? recu, String? unite, Qte? facteur}) =>
      LigneOperation(
        id: id,
        produitId: produitId,
        unite: unite ?? this.unite,
        facteur: facteur ?? this.facteur,
        quantite: quantite ?? this.quantite,
        prixUnitaire: prixUnitaire ?? this.prixUnitaire,
        recu: recu ?? this.recu,
      );

  Map<String, dynamic> toJson({bool avecRecu = false}) => {
        'id': id,
        'produit_id': produitId,
        'unite': unite,
        'facteur': facteur.json,
        'quantite': quantite.json,
        'prix_unitaire': prixUnitaire,
        if (avecRecu) 'recu': recu.json,
      };

  static LigneOperation fromJson(Map<String, dynamic> j) => LigneOperation(
        id: j['id'] as String,
        produitId: j['produit_id'] as String,
        unite: j['unite'] as String,
        facteur: Qte.depuis(j['facteur'] as num),
        quantite: Qte.depuis(j['quantite'] as num),
        prixUnitaire: (j['prix_unitaire'] as num).toInt(),
        recu: Qte.depuis((j['recu'] as num?) ?? 0),
      );
}

int totalLignes(Iterable<LigneOperation> lignes) => lignes.fold(0, (s, l) => s + l.montant);

enum StatutAchat {
  commande('COMMANDE'),
  recuPartiel('RECU_PARTIEL'),
  recu('RECU'),
  annule('ANNULE');

  const StatutAchat(this.code);
  final String code;

  static StatutAchat parse(String? code) => values.firstWhere((s) => s.code == code, orElse: () => commande);
}

class Achat {
  const Achat({
    required this.id,
    required this.entrepriseId,
    required this.perimetreId,
    required this.dateAchat,
    required this.lignes,
    required this.creeLe,
    this.fournisseurId,
    this.reference,
    this.total = 0,
    this.statut = StatutAchat.commande,
    this.note,
    this.auteurNom,
    this.version,
    this.syncStatus = RecordSyncStatus.synced,
  });

  final String id;
  final String entrepriseId;
  final String perimetreId;
  final String? fournisseurId;
  final String? reference;
  final DateTime dateAchat;
  final List<LigneOperation> lignes;
  final int total;
  final StatutAchat statut;
  final String? note;
  final String? auteurNom;
  final DateTime creeLe;
  final int? version;
  final RecordSyncStatus syncStatus;

  bool get annule => statut == StatutAchat.annule;
  bool get aRecevoir => statut == StatutAchat.commande || statut == StatutAchat.recuPartiel;
  bool get refuse => syncStatus == RecordSyncStatus.syncError && version == null;

  Achat copyWith({
    List<LigneOperation>? lignes,
    StatutAchat? statut,
    String? Function()? fournisseurId,
    String? Function()? reference,
    String? Function()? note,
    DateTime? dateAchat,
    int? total,
  }) =>
      Achat(
        id: id,
        entrepriseId: entrepriseId,
        perimetreId: perimetreId,
        fournisseurId: fournisseurId == null ? this.fournisseurId : fournisseurId(),
        reference: reference == null ? this.reference : reference(),
        dateAchat: dateAchat ?? this.dateAchat,
        lignes: lignes ?? this.lignes,
        total: total ?? this.total,
        statut: statut ?? this.statut,
        note: note == null ? this.note : note(),
        auteurNom: auteurNom,
        creeLe: creeLe,
        version: version,
        syncStatus: syncStatus,
      );
}

class LigneReception {
  const LigneReception({required this.id, required this.ligneId, required this.quantite});

  /// Identifiant du mouvement d'entrée créé.
  final String id;
  final String ligneId;
  final Qte quantite;

  Map<String, dynamic> toJson() => {'id': id, 'ligne_id': ligneId, 'quantite': quantite.json};

  static LigneReception fromJson(Map<String, dynamic> j) => LigneReception(
        id: j['id'] as String,
        ligneId: j['ligne_id'] as String,
        quantite: Qte.depuis(j['quantite'] as num),
      );
}

class Reception {
  const Reception({
    required this.id,
    required this.entrepriseId,
    required this.achatId,
    required this.lignes,
    required this.date,
    this.perimetreId,
    this.note,
    this.auteurNom,
    this.syncStatus = RecordSyncStatus.synced,
  });

  final String id;
  final String entrepriseId;
  final String achatId;
  final String? perimetreId;
  final List<LigneReception> lignes;
  final DateTime date;
  final String? note;
  final String? auteurNom;
  final RecordSyncStatus syncStatus;
}

enum ModeVente {
  detail('DETAIL'),
  gros('GROS');

  const ModeVente(this.code);
  final String code;

  static ModeVente parse(String? code) => code == 'GROS' ? gros : detail;
}

enum ReglementVente {
  immediat('IMMEDIAT'),
  credit('CREDIT');

  const ReglementVente(this.code);
  final String code;

  static ReglementVente parse(String? code) => code == 'CREDIT' ? credit : immediat;
}

class Vente {
  const Vente({
    required this.id,
    required this.entrepriseId,
    required this.perimetreId,
    required this.lignes,
    required this.date,
    this.contactId,
    this.mode = ModeVente.detail,
    this.remise = 0,
    this.total = 0,
    this.reglement = ReglementVente.immediat,
    this.modePaiement,
    this.sessionId,
    this.paiementId,
    this.annulee = false,
    this.motifAnnulation,
    this.note,
    this.auteurNom,
    this.version,
    this.syncStatus = RecordSyncStatus.synced,
    this.numero,
    this.dateCommerciale,
    this.poste,
    this.sequence,
    this.montantPaye = 0,
    this.annuleeLe,
    this.annuleeParNom,
  });

  final String id;
  final String entrepriseId;
  final String perimetreId;
  final String? contactId;
  final ModeVente mode;

  /// Numéro du reçu (« REC-20261007-A001 ») ; `null` tant que le serveur doit
  /// l'attribuer (appareil sans lettre de poste, vente hors-ligne).
  final String? numero;

  /// Jour commercial (local) de la vente, « AAAA-MM-JJ ».
  final String? dateCommerciale;
  final String? poste;
  final int? sequence;

  /// Encaissé à la vente : le total au comptant, l'acompte à crédit.
  final int montantPaye;
  final DateTime? annuleeLe;
  final String? annuleeParNom;
  final List<LigneOperation> lignes;
  final int remise;
  final int total;
  final DateTime date;
  final ReglementVente reglement;

  /// Code du mode de paiement (ESPECES, MOBILE_MONEY…).
  final String? modePaiement;
  final String? sessionId;
  final String? paiementId;
  final bool annulee;
  final String? motifAnnulation;
  final String? note;
  final String? auteurNom;
  final int? version;
  final RecordSyncStatus syncStatus;

  bool get refuse => syncStatus == RecordSyncStatus.syncError && version == null;
  Qte get nombreArticles => lignes.map((l) => l.quantite).somme;

  /// Somme des lignes, avant remise.
  int get sousTotal => total + remise;

  /// Reste dû au moment de la vente (le suivi des paiements fait foi ensuite).
  int get resteInitial => annulee ? 0 : total - montantPaye;

  Vente annuler({String? motif, required DateTime le, String? par}) => Vente(
        id: id,
        entrepriseId: entrepriseId,
        perimetreId: perimetreId,
        contactId: contactId,
        mode: mode,
        lignes: lignes,
        remise: remise,
        total: total,
        date: date,
        reglement: reglement,
        modePaiement: modePaiement,
        sessionId: sessionId,
        paiementId: paiementId,
        annulee: true,
        motifAnnulation: motif,
        note: note,
        auteurNom: auteurNom,
        version: version,
        syncStatus: syncStatus,
        numero: numero,
        dateCommerciale: dateCommerciale,
        poste: poste,
        sequence: sequence,
        montantPaye: montantPaye,
        annuleeLe: le,
        annuleeParNom: par,
      );

  Vente numerotee({required String poste, required int sequence, required String dateCommerciale}) => Vente(
        id: id,
        entrepriseId: entrepriseId,
        perimetreId: perimetreId,
        contactId: contactId,
        mode: mode,
        lignes: lignes,
        remise: remise,
        total: total,
        date: date,
        reglement: reglement,
        modePaiement: modePaiement,
        sessionId: sessionId,
        paiementId: paiementId,
        annulee: annulee,
        motifAnnulation: motifAnnulation,
        note: note,
        auteurNom: auteurNom,
        version: version,
        syncStatus: syncStatus,
        numero: numeroRecu(dateCommerciale, poste, sequence),
        dateCommerciale: dateCommerciale,
        poste: poste,
        sequence: sequence,
        montantPaye: montantPaye,
        annuleeLe: annuleeLe,
        annuleeParNom: annuleeParNom,
      );
}

/// « REC-20261007-A001 » — même formule que le serveur (app.numeroter_vente).
String numeroRecu(String dateCommerciale, String poste, int sequence) =>
    'REC-${dateCommerciale.replaceAll('-', '')}-$poste${sequence.toString().padLeft(3, '0')}';

/// Jour local « AAAA-MM-JJ ».
String jourCommercial(DateTime d) {
  final l = d.toLocal();
  return '${l.year.toString().padLeft(4, '0')}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}
