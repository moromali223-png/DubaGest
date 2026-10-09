import '../../../../core/sync/sync_models.dart';
import '../../../activites/domain/entities/activite.dart';

/// Énumérations à code serveur.
mixin _Code on Enum {
  String get code;
}

T _parse<T extends _Code>(List<T> values, String? code, T defaut) =>
    values.firstWhere((v) => v.code == code, orElse: () => defaut);

enum SensEngagement with _Code {
  aRecevoir('A_RECEVOIR'),
  aPayer('A_PAYER');

  const SensEngagement(this.code);
  @override
  final String code;
  static SensEngagement parse(String? c) => _parse(values, c, aRecevoir);

  /// Sens du paiement qui règle cet engagement.
  SensPaiement get sensReglement => this == aRecevoir ? SensPaiement.entree : SensPaiement.sortie;
}

enum SensPaiement with _Code {
  entree('ENTREE'),
  sortie('SORTIE');

  const SensPaiement(this.code);
  @override
  final String code;
  static SensPaiement parse(String? c) => _parse(values, c, entree);
  SensPaiement get inverse => this == entree ? sortie : entree;
}

enum ModePaiement with _Code {
  especes('ESPECES'),
  mobileMoney('MOBILE_MONEY'),
  carte('CARTE'),
  virement('VIREMENT'),
  cheque('CHEQUE'),
  autre('AUTRE');

  const ModePaiement(this.code);
  @override
  final String code;
  static ModePaiement parse(String? c) => _parse(values, c, autre);

  /// Seules les espèces passent par la caisse (règle serveur identique).
  bool get passeParCaisse => this == especes;
}

enum TypeMouvement with _Code {
  encaissement('ENCAISSEMENT'),
  decaissement('DECAISSEMENT'),
  depot('DEPOT'),
  retrait('RETRAIT');

  const TypeMouvement(this.code);
  @override
  final String code;
  static TypeMouvement parse(String? c) => _parse(values, c, depot);
  bool get estEntree => this == encaissement || this == depot;
}

/// Nature d'un paiement qui ne règle aucune somme due (les autres tirent leur
/// origine de la somme réglée : vente, achat, dépense, loyer…).
enum NaturePaiement with _Code {
  apport('APPORT'),
  retrait('RETRAIT'),
  transfert('TRANSFERT'),
  remboursement('REMBOURSEMENT'),
  ajustement('AJUSTEMENT'),
  soldeInitial('SOLDE_INITIAL'),
  autre('AUTRE');

  const NaturePaiement(this.code);
  @override
  final String code;
  static NaturePaiement? tryParse(String? c) => values.where((v) => v.code == c).firstOrNull;

  /// Correction d'un solde : droit propre (cash.adjust), motif obligatoire.
  bool get estCorrection => this == ajustement || this == soldeInitial;
}

/// Justification d'un écart constaté à la clôture d'une caisse.
enum MotifEcart with _Code {
  renduMonnaie('RENDU_MONNAIE'),
  depenseNonEnregistree('DEPENSE_NON_ENREGISTREE'),
  erreurComptage('ERREUR_COMPTAGE'),
  autre('AUTRE');

  const MotifEcart(this.code);
  @override
  final String code;
  static MotifEcart? tryParse(String? c) => values.where((v) => v.code == c).firstOrNull;
}

/// État de règlement affiché, calculé (jamais saisi).
enum EtatReglement { aRegler, partiel, enRetard, regle, annule }

/// Somme due par un contact (à recevoir) ou à un contact (à payer).
class Engagement {
  const Engagement({
    required this.id,
    required this.entrepriseId,
    required this.sens,
    required this.libelle,
    required this.montantTotal,
    required this.dateEngagement,
    this.activite,
    this.perimetreId,
    this.contactId,
    this.montantRegle = 0,
    this.echeance,
    this.origineType = 'MANUEL',
    this.annule = false,
    this.motifAnnulation,
    this.version,
    this.syncStatus = RecordSyncStatus.synced,
  });

  final String id;
  final String entrepriseId;
  final ActiviteCode? activite;
  final String? perimetreId;
  final SensEngagement sens;
  final String? contactId;
  final String libelle;
  final int montantTotal;

  /// Réglé connu du serveur (dernière synchronisation).
  final int montantRegle;
  final DateTime dateEngagement;
  final DateTime? echeance;
  final String origineType;
  final bool annule;
  final String? motifAnnulation;
  final int? version;
  final RecordSyncStatus syncStatus;

  /// Refusé par le serveur et jamais accepté : compté nulle part.
  bool get refuse => syncStatus == RecordSyncStatus.syncError && version == null;

  /// Liée à une dépense (ou une vente…) : se gère depuis son origine.
  bool get lie => origineType != 'MANUEL';

  Engagement copyWith({
    String? libelle,
    int? montantTotal,
    String? Function()? contactId,
    DateTime? Function()? echeance,
    bool? annule,
    String? motifAnnulation,
  }) => Engagement(
    id: id,
    entrepriseId: entrepriseId,
    activite: activite,
    perimetreId: perimetreId,
    sens: sens,
    contactId: contactId == null ? this.contactId : contactId(),
    libelle: libelle ?? this.libelle,
    montantTotal: montantTotal ?? this.montantTotal,
    montantRegle: montantRegle,
    dateEngagement: dateEngagement,
    echeance: echeance == null ? this.echeance : echeance(),
    origineType: origineType,
    annule: annule ?? this.annule,
    motifAnnulation: motifAnnulation ?? this.motifAnnulation,
    version: version,
    syncStatus: syncStatus,
  );
}

/// Engagement avec son réglé effectif : serveur + paiements de l'appareil
/// pas encore envoyés − annulations pas encore envoyées.
class EngagementSuivi {
  const EngagementSuivi(this.engagement, {required this.regle});
  final Engagement engagement;
  final int regle;

  int get reste => engagement.annule ? 0 : (engagement.montantTotal - regle).clamp(0, engagement.montantTotal);

  EtatReglement etat(DateTime aujourdhui) {
    final e = engagement;
    if (e.annule) return EtatReglement.annule;
    if (reste == 0) return EtatReglement.regle;
    final jour = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day);
    if (e.echeance != null && e.echeance!.isBefore(jour)) return EtatReglement.enRetard;
    return regle > 0 ? EtatReglement.partiel : EtatReglement.aRegler;
  }
}

class Affectation {
  const Affectation({required this.id, required this.engagementId, required this.montant});
  final String id;
  final String engagementId;
  final int montant;
}

/// Argent reçu (entrée) ou versé (sortie). Jamais modifié : une annulation est
/// un paiement inverse portant [annulePaiementId].
class Paiement {
  const Paiement({
    required this.id,
    required this.entrepriseId,
    required this.sens,
    required this.montant,
    required this.mode,
    required this.datePaiement,
    this.activite,
    this.perimetreId,
    this.contactId,
    this.reference,
    this.note,
    this.sessionId,
    this.affectations = const [],
    this.annulePaiementId,
    this.annuleServeur = false,
    this.nature,
    this.transfertId,
    this.version,
    this.syncStatus = RecordSyncStatus.synced,
  });

  final String id;
  final String entrepriseId;
  final ActiviteCode? activite;
  final String? perimetreId;

  /// Mouvement sans somme due (apport, retrait, transfert…) ; `null` sinon.
  final NaturePaiement? nature;

  /// Jambe d'un [TransfertTresorerie] : ni entrée ni sortie réelle.
  final String? transfertId;
  final SensPaiement sens;
  final int montant;
  final ModePaiement mode;
  final DateTime datePaiement;
  final String? contactId;
  final String? reference;
  final String? note;
  final String? sessionId;
  final List<Affectation> affectations;
  final String? annulePaiementId;

  /// Statut ANNULE reçu du serveur.
  final bool annuleServeur;
  final int? version;
  final RecordSyncStatus syncStatus;

  bool get estAnnulation => annulePaiementId != null;
  bool get estTransfert => transfertId != null || nature == NaturePaiement.transfert;

  /// Refusé par le serveur : n'a jamais eu lieu, exclu de tous les totaux.
  bool get refuse => syncStatus == RecordSyncStatus.syncError;
  bool get enAttente => syncStatus == RecordSyncStatus.pendingSync;
}

/// Transfert d'argent (boutique → boutique, espèces → banque…) : deux jambes
/// ([sortieId], [entreeId]) créées ensemble, jamais comptées comme entrée ou
/// sortie ; le total de l'entreprise ne change pas.
class TransfertTresorerie {
  const TransfertTresorerie({
    required this.id,
    required this.entrepriseId,
    required this.modeSource,
    required this.modeDest,
    required this.montant,
    required this.sortieId,
    required this.entreeId,
    required this.dateTransfert,
    this.perimetreSourceId,
    this.perimetreDestId,
    this.sessionSourceId,
    this.sessionDestId,
    this.motif,
    this.annule = false,
    this.motifAnnulation,
    this.annulationSortieId,
    this.annulationEntreeId,
    this.version,
    this.syncStatus = RecordSyncStatus.synced,
  });

  final String id;
  final String entrepriseId;
  final String? perimetreSourceId;
  final String? perimetreDestId;
  final ModePaiement modeSource;
  final ModePaiement modeDest;
  final int montant;
  final String? sessionSourceId;
  final String? sessionDestId;
  final String sortieId;
  final String entreeId;
  final DateTime dateTransfert;
  final String? motif;
  final bool annule;
  final String? motifAnnulation;
  final String? annulationSortieId;
  final String? annulationEntreeId;
  final int? version;
  final RecordSyncStatus syncStatus;

  bool get refuse => syncStatus == RecordSyncStatus.syncError && version == null;

  TransfertTresorerie annulation({required String motif, required String sortieId, required String entreeId}) =>
      TransfertTresorerie(
        id: id,
        entrepriseId: entrepriseId,
        perimetreSourceId: perimetreSourceId,
        perimetreDestId: perimetreDestId,
        modeSource: modeSource,
        modeDest: modeDest,
        montant: montant,
        sessionSourceId: sessionSourceId,
        sessionDestId: sessionDestId,
        sortieId: this.sortieId,
        entreeId: this.entreeId,
        dateTransfert: dateTransfert,
        motif: this.motif,
        annule: true,
        motifAnnulation: motif,
        annulationSortieId: sortieId,
        annulationEntreeId: entreeId,
        version: version,
        syncStatus: syncStatus,
      );
}

/// Paiement tel qu'affiché : annulé si le serveur l'a annulé ou si une
/// annulation locale non refusée existe.
class PaiementSuivi {
  const PaiementSuivi(this.paiement, {required this.annule});
  final Paiement paiement;
  final bool annule;
}

class Caisse {
  const Caisse({
    required this.id,
    required this.entrepriseId,
    required this.perimetreId,
    required this.nom,
    this.estActive = true,
    this.version,
    this.syncStatus = RecordSyncStatus.synced,
  });

  final String id;
  final String entrepriseId;
  final String perimetreId;
  final String nom;
  final bool estActive;
  final int? version;
  final RecordSyncStatus syncStatus;
}

class SessionCaisse {
  const SessionCaisse({
    required this.id,
    required this.entrepriseId,
    required this.caisseId,
    required this.perimetreId,
    required this.ouverte,
    required this.soldeInitial,
    required this.ouverteLe,
    this.fermeeLe,
    this.soldeTheorique,
    this.soldeReel,
    this.ecart,
    this.noteCloture,
    this.motifEcart,
    this.version,
    this.syncStatus = RecordSyncStatus.synced,
  });

  /// Justification d'un écart à la clôture (obligatoire s'il y a un écart).
  final MotifEcart? motifEcart;

  final String id;
  final String entrepriseId;
  final String caisseId;
  final String perimetreId;
  final bool ouverte;
  final int soldeInitial;
  final DateTime ouverteLe;
  final DateTime? fermeeLe;
  final int? soldeTheorique;
  final int? soldeReel;
  final int? ecart;
  final String? noteCloture;
  final int? version;
  final RecordSyncStatus syncStatus;
}

class MouvementCaisse {
  const MouvementCaisse({
    required this.id,
    required this.sessionId,
    required this.caisseId,
    required this.type,
    required this.montant,
    required this.createdAt,
    this.paiementId,
    this.motif,
    this.syncStatus = RecordSyncStatus.synced,
  });

  final String id;
  final String sessionId;
  final String caisseId;
  final TypeMouvement type;
  final int montant;
  final String? paiementId;
  final String? motif;
  final DateTime createdAt;
  final RecordSyncStatus syncStatus;

  int get signe => type.estEntree ? montant : -montant;
}

/// Caisse avec sa session en cours (ou la dernière) et son solde courant.
class CaisseSuivi {
  const CaisseSuivi({required this.caisse, this.session, this.solde = 0, this.mouvements = const []});
  final Caisse caisse;
  final SessionCaisse? session;

  /// Solde courant de la session ouverte (initial ± mouvements valides).
  final int solde;
  final List<MouvementCaisse> mouvements;

  bool get ouverte => session?.ouverte ?? false;
}

/// Catégorie de dépense : fournie ([code], libellé traduit) ou créée par
/// l'entreprise ([nom]).
class CategorieDepense {
  const CategorieDepense({
    required this.id,
    required this.entrepriseId,
    this.code,
    this.nom,
    this.estActive = true,
    this.ordre = 100,
    this.version,
    this.syncStatus = RecordSyncStatus.synced,
  });

  final String id;
  final String entrepriseId;
  final String? code;
  final String? nom;
  final bool estActive;
  final int ordre;
  final int? version;
  final RecordSyncStatus syncStatus;
}

/// Dépense : crée toujours une somme à payer (même identifiant) ; payée
/// immédiatement, elle porte aussi son paiement ([paiementId]).
class Depense {
  const Depense({
    required this.id,
    required this.entrepriseId,
    required this.categorieId,
    required this.libelle,
    required this.montant,
    required this.dateDepense,
    required this.payeeImmediatement,
    this.activite,
    this.perimetreId,
    this.contactId,
    this.mode,
    this.sessionId,
    this.paiementId,
    this.echeance,
    this.reference,
    this.note,
    this.beneficiaire,
    this.couranteId,
    this.echeancePrevue,
    this.annulee = false,
    this.motifAnnulation,
    this.version,
    this.syncStatus = RecordSyncStatus.synced,
  });

  final String id;
  final String entrepriseId;
  final ActiviteCode? activite;
  final String? perimetreId;
  final String categorieId;
  final String libelle;
  final int montant;
  final DateTime dateDepense;
  final String? contactId;

  /// « Payé à » saisi librement (station, personne…) sans créer de contact.
  final String? beneficiaire;

  /// Échéance d'une dépense courante réglée par cette dépense.
  final String? couranteId;
  final DateTime? echeancePrevue;
  final bool payeeImmediatement;
  final ModePaiement? mode;
  final String? sessionId;
  final String? paiementId;
  final DateTime? echeance;
  final String? reference;
  final String? note;
  final bool annulee;
  final String? motifAnnulation;
  final int? version;
  final RecordSyncStatus syncStatus;

  /// Refusée par le serveur et jamais acceptée : comptée nulle part.
  bool get refusee => syncStatus == RecordSyncStatus.syncError && version == null;

  Depense copyWith({
    String? categorieId,
    String? libelle,
    DateTime? dateDepense,
    String? Function()? reference,
    String? Function()? note,
    String? Function()? beneficiaire,
    bool? annulee,
    String? motifAnnulation,
  }) => Depense(
    id: id,
    entrepriseId: entrepriseId,
    activite: activite,
    perimetreId: perimetreId,
    categorieId: categorieId ?? this.categorieId,
    libelle: libelle ?? this.libelle,
    montant: montant,
    dateDepense: dateDepense ?? this.dateDepense,
    contactId: contactId,
    payeeImmediatement: payeeImmediatement,
    mode: mode,
    sessionId: sessionId,
    paiementId: paiementId,
    echeance: echeance,
    reference: reference == null ? this.reference : reference(),
    note: note == null ? this.note : note(),
    beneficiaire: beneficiaire == null ? this.beneficiaire : beneficiaire(),
    couranteId: couranteId,
    echeancePrevue: echeancePrevue,
    annulee: annulee ?? this.annulee,
    motifAnnulation: motifAnnulation ?? this.motifAnnulation,
    version: version,
    syncStatus: syncStatus,
  );
}

/// Rythme d'une dépense courante : tous les [intervalle] jours / semaines / mois / ans.
enum PeriodeRecurrence with _Code {
  jour('JOUR'),
  semaine('SEMAINE'),
  mois('MOIS'),
  an('AN');

  const PeriodeRecurrence(this.code);
  @override
  final String code;
  static PeriodeRecurrence parse(String? c) => _parse(values, c, mois);
}

/// Fréquences proposées en premier (le reste via « Personnalisé »).
enum Frequence {
  quotidienne(PeriodeRecurrence.jour, 1),
  hebdomadaire(PeriodeRecurrence.semaine, 1),
  bimensuelle(PeriodeRecurrence.semaine, 2),
  mensuelle(PeriodeRecurrence.mois, 1),
  trimestrielle(PeriodeRecurrence.mois, 3),
  semestrielle(PeriodeRecurrence.mois, 6),
  annuelle(PeriodeRecurrence.an, 1);

  const Frequence(this.periode, this.intervalle);
  final PeriodeRecurrence periode;
  final int intervalle;

  static Frequence? de(PeriodeRecurrence p, int n) =>
      values.where((f) => f.periode == p && f.intervalle == n).firstOrNull;
}

/// Premier jour d'échéance strictement après [apres], compté depuis [debut]
/// (même règle que le serveur : le 31 mensuel donne le 28 février puis le 31 mars).
DateTime echeanceSuivante(DateTime debut, PeriodeRecurrence periode, int intervalle, DateTime apres) {
  final d0 = DateTime(debut.year, debut.month, debut.day);
  final a = DateTime(apres.year, apres.month, apres.day);
  if (a.isBefore(d0)) return d0;
  DateTime nieme(int k) => switch (periode) {
    PeriodeRecurrence.jour => DateTime(d0.year, d0.month, d0.day + k * intervalle),
    PeriodeRecurrence.semaine => DateTime(d0.year, d0.month, d0.day + 7 * k * intervalle),
    PeriodeRecurrence.mois => _plusMois(d0, k * intervalle),
    PeriodeRecurrence.an => _plusMois(d0, 12 * k * intervalle),
  };
  var k = switch (periode) {
    PeriodeRecurrence.jour => a.difference(d0).inDays ~/ intervalle,
    PeriodeRecurrence.semaine => a.difference(d0).inDays ~/ (7 * intervalle),
    PeriodeRecurrence.mois => ((a.year - d0.year) * 12 + a.month - d0.month) ~/ intervalle,
    PeriodeRecurrence.an => (a.year - d0.year) ~/ intervalle,
  };
  // L'estimation peut dépasser d'un pas (fin de mois) : on recule puis on avance.
  while (k > 0 && nieme(k).isAfter(a)) {
    k--;
  }
  while (!nieme(k).isAfter(a)) {
    k++;
  }
  return nieme(k);
}

DateTime _plusMois(DateTime d, int mois) {
  final m = d.month - 1 + mois;
  final annee = d.year + m ~/ 12;
  final mo = m % 12 + 1;
  final dernier = DateTime(annee, mo + 1, 0).day;
  return DateTime(annee, mo, d.day > dernier ? dernier : d.day);
}

/// Dépense courante : un MODÈLE (loyer, électricité, carburant…) jamais compté
/// comme payé. Payer une échéance = une [Depense] portant [id] et l'échéance.
class DepenseCourante {
  const DepenseCourante({
    required this.id,
    required this.entrepriseId,
    required this.categorieId,
    required this.nom,
    required this.montantPrevu,
    required this.periode,
    required this.dateDebut,
    required this.prochaineEcheance,
    this.intervalle = 1,
    this.montantVariable = false,
    this.activite,
    this.perimetreId,
    this.mode,
    this.beneficiaire,
    this.note,
    this.estActive = true,
    this.version,
    this.syncStatus = RecordSyncStatus.synced,
  });

  final String id;
  final String entrepriseId;
  final ActiviteCode? activite;

  /// `null` : toute l'entreprise.
  final String? perimetreId;
  final String categorieId;
  final String nom;
  final int montantPrevu;

  /// Montant variable (électricité…) : [montantPrevu] est une prévision.
  final bool montantVariable;
  final PeriodeRecurrence periode;
  final int intervalle;
  final DateTime dateDebut;

  /// Première échéance non payée.
  final DateTime prochaineEcheance;
  final ModePaiement? mode;
  final String? beneficiaire;
  final String? note;
  final bool estActive;
  final int? version;
  final RecordSyncStatus syncStatus;

  Frequence? get frequence => Frequence.de(periode, intervalle);

  DateTime suivante(DateTime apres) => echeanceSuivante(dateDebut, periode, intervalle, apres);

  /// Échéances non payées jusqu'au [jusquau] inclus (à partir de la prochaine).
  List<DateTime> echeancesJusqua(DateTime jusquau, {int max = 400}) {
    final fin = DateTime(jusquau.year, jusquau.month, jusquau.day);
    final r = <DateTime>[];
    var e = prochaineEcheance;
    while (!e.isAfter(fin) && r.length < max) {
      r.add(e);
      e = suivante(e);
    }
    return r;
  }

  DepenseCourante copyWith({
    String? categorieId,
    String? nom,
    int? montantPrevu,
    bool? montantVariable,
    PeriodeRecurrence? periode,
    int? intervalle,
    DateTime? dateDebut,
    DateTime? prochaineEcheance,
    ModePaiement? Function()? mode,
    String? Function()? beneficiaire,
    String? Function()? note,
    bool? estActive,
  }) => DepenseCourante(
    id: id,
    entrepriseId: entrepriseId,
    activite: activite,
    perimetreId: perimetreId,
    categorieId: categorieId ?? this.categorieId,
    nom: nom ?? this.nom,
    montantPrevu: montantPrevu ?? this.montantPrevu,
    montantVariable: montantVariable ?? this.montantVariable,
    periode: periode ?? this.periode,
    intervalle: intervalle ?? this.intervalle,
    dateDebut: dateDebut ?? this.dateDebut,
    prochaineEcheance: prochaineEcheance ?? this.prochaineEcheance,
    mode: mode == null ? this.mode : mode(),
    beneficiaire: beneficiaire == null ? this.beneficiaire : beneficiaire(),
    note: note == null ? this.note : note(),
    estActive: estActive ?? this.estActive,
    version: version,
    syncStatus: syncStatus,
  );
}

/// État affiché d'une échéance (calculé, jamais stocké).
enum EtatEcheance { aVenir, aujourdhui, enRetard, payee }

/// Chiffres réels de l'onglet Finances.
class ResumeFinances {
  const ResumeFinances({
    this.aRecevoir = 0,
    this.aPayer = 0,
    this.enRetard = 0,
    this.encaisseAujourdhui = 0,
    this.decaisseAujourdhui = 0,
    this.enCaisse = 0,
    this.depensesDuMois = 0,
  });

  final int aRecevoir;
  final int aPayer;
  final int enRetard;
  final int encaisseAujourdhui;
  final int decaisseAujourdhui;
  final int enCaisse;

  /// Dépenses du mois en cours (payées ou non, hors annulées / refusées).
  final int depensesDuMois;
}
