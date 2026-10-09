import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_models.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../domain/entities/finances.dart';

typedef Json = Map<String, dynamic>;

/// « AAAA-MM-JJ » : une date sans heure ni fuseau.
String jourIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _jour(String s) => DateTime.parse(s.substring(0, 10));
DateTime? _date(Object? s) => s == null ? null : DateTime.parse(s as String);
int _int(Object? v) => (v as num?)?.toInt() ?? 0;
int? _intN(Object? v) => (v as num?)?.toInt();

abstract final class FinancesMapper {
  // --- Engagements ----------------------------------------------------------

  static Engagement engagement(EngagementRow r) => Engagement(
    id: r.id,
    entrepriseId: r.entrepriseId,
    activite: ActiviteCode.tryParse(r.activiteCode),
    perimetreId: r.perimetreId,
    sens: SensEngagement.parse(r.sens),
    contactId: r.contactId,
    libelle: r.libelle,
    montantTotal: r.montantTotal,
    montantRegle: r.montantRegle,
    dateEngagement: _jour(r.dateEngagement),
    echeance: r.echeance == null ? null : _jour(r.echeance!),
    origineType: r.origineType,
    annule: r.statut == 'ANNULE',
    motifAnnulation: r.motifAnnulation,
    version: r.version,
    syncStatus: RecordSyncStatus.fromWire(r.syncStatus),
  );

  static EngagementsCompanion engagementLocal(Engagement e, RecordSyncStatus statut) => EngagementsCompanion.insert(
    id: e.id,
    entrepriseId: e.entrepriseId,
    activiteCode: Value(e.activite?.code),
    perimetreId: Value(e.perimetreId),
    sens: e.sens.code,
    contactId: Value(e.contactId),
    libelle: e.libelle,
    montantTotal: e.montantTotal,
    montantRegle: Value(e.montantRegle),
    dateEngagement: jourIso(e.dateEngagement),
    echeance: Value(e.echeance == null ? null : jourIso(e.echeance!)),
    origineType: Value(e.origineType),
    statut: e.annule ? 'ANNULE' : 'OUVERT',
    motifAnnulation: Value(e.motifAnnulation),
    version: Value(e.version),
    syncStatus: statut.wire,
  );

  static EngagementsCompanion engagementServeur(Json j, RecordSyncStatus statut) => EngagementsCompanion.insert(
    id: j['id'] as String,
    entrepriseId: j['entreprise_id'] as String,
    activiteCode: Value(j['activite_code'] as String?),
    perimetreId: Value(j['perimetre_id'] as String?),
    sens: j['sens'] as String,
    contactId: Value(j['contact_id'] as String?),
    libelle: j['libelle'] as String,
    montantTotal: _int(j['montant_total']),
    montantRegle: Value(_int(j['montant_regle'])),
    dateEngagement: (j['date_engagement'] as String).substring(0, 10),
    echeance: Value((j['echeance'] as String?)?.substring(0, 10)),
    origineType: Value(j['origine_type'] as String? ?? 'MANUEL'),
    statut: j['statut'] as String? ?? 'OUVERT',
    motifAnnulation: Value(j['motif_annulation'] as String?),
    version: Value(_intN(j['version'])),
    updatedAt: Value(_date(j['updated_at'])),
    syncStatus: statut.wire,
  );

  static Json engagementCreation(Engagement e) => {
    'entreprise_id': e.entrepriseId,
    'activite_code': e.activite?.code,
    'perimetre_id': e.perimetreId,
    'sens': e.sens.code,
    'contact_id': e.contactId,
    'libelle': e.libelle,
    'montant_total': e.montantTotal,
    'date_engagement': jourIso(e.dateEngagement),
    'echeance': e.echeance == null ? null : jourIso(e.echeance!),
  };

  static Json engagementModification(Engagement e) => {
    'contact_id': e.contactId,
    'libelle': e.libelle,
    'montant_total': e.montantTotal,
    'echeance': e.echeance == null ? null : jourIso(e.echeance!),
    'statut': e.annule ? 'ANNULE' : 'OUVERT',
    'motif_annulation': e.motifAnnulation,
  };

  static bool engagementIdentique(EngagementRow l, Json s) =>
      l.contactId == s['contact_id'] &&
      l.libelle == s['libelle'] &&
      l.montantTotal == _int(s['montant_total']) &&
      l.echeance == (s['echeance'] as String?)?.substring(0, 10) &&
      l.statut == (s['statut'] ?? 'OUVERT') &&
      l.motifAnnulation == s['motif_annulation'];

  // --- Paiements ------------------------------------------------------------

  static List<Affectation> _affectations(Object? json) => [
    for (final a in ((json is String ? jsonDecode(json) : json) as List? ?? const []).cast<Map>())
      Affectation(id: a['id'] as String, engagementId: a['engagement_id'] as String, montant: _int(a['montant'])),
  ];

  static String _affectationsJson(List<Affectation> list) => jsonEncode(_affectationsListe(list));

  static List<Json> _affectationsListe(List<Affectation> list) => [
    for (final a in list) {'id': a.id, 'engagement_id': a.engagementId, 'montant': a.montant},
  ];

  static Paiement paiement(PaiementRow r) => Paiement(
    id: r.id,
    entrepriseId: r.entrepriseId,
    activite: ActiviteCode.tryParse(r.activiteCode),
    perimetreId: r.perimetreId,
    sens: SensPaiement.parse(r.sens),
    montant: r.montant,
    mode: ModePaiement.parse(r.modeCode),
    datePaiement: r.datePaiement,
    contactId: r.contactId,
    reference: r.reference,
    note: r.note,
    sessionId: r.sessionId,
    affectations: _affectations(r.affectations),
    annulePaiementId: r.annulePaiementId,
    annuleServeur: r.statut == 'ANNULE',
    nature: NaturePaiement.tryParse(r.nature),
    transfertId: r.transfertId,
    version: r.version,
    syncStatus: RecordSyncStatus.fromWire(r.syncStatus),
  );

  static PaiementsCompanion paiementLocal(Paiement p, RecordSyncStatus statut) => PaiementsCompanion.insert(
    id: p.id,
    entrepriseId: p.entrepriseId,
    activiteCode: Value(p.activite?.code),
    perimetreId: Value(p.perimetreId),
    sens: p.sens.code,
    montant: p.montant,
    modeCode: p.mode.code,
    datePaiement: p.datePaiement,
    contactId: Value(p.contactId),
    reference: Value(p.reference),
    note: Value(p.note),
    sessionId: Value(p.sessionId),
    affectations: Value(_affectationsJson(p.affectations)),
    annulePaiementId: Value(p.annulePaiementId),
    statut: p.annuleServeur ? 'ANNULE' : 'VALIDE',
    nature: Value(p.nature?.code),
    transfertId: Value(p.transfertId),
    version: Value(p.version),
    syncStatus: statut.wire,
  );

  static PaiementsCompanion paiementServeur(Json j, RecordSyncStatus statut) => PaiementsCompanion.insert(
    id: j['id'] as String,
    entrepriseId: j['entreprise_id'] as String,
    activiteCode: Value(j['activite_code'] as String?),
    perimetreId: Value(j['perimetre_id'] as String?),
    sens: j['sens'] as String,
    montant: _int(j['montant']),
    modeCode: j['mode_code'] as String,
    datePaiement: DateTime.parse(j['date_paiement'] as String),
    contactId: Value(j['contact_id'] as String?),
    reference: Value(j['reference'] as String?),
    note: Value(j['note'] as String?),
    sessionId: Value(j['session_id'] as String?),
    affectations: Value(jsonEncode(j['affectations'] ?? const [])),
    annulePaiementId: Value(j['annule_paiement_id'] as String?),
    nature: Value(j['nature'] as String?),
    transfertId: Value(j['transfert_id'] as String?),
    statut: j['statut'] as String? ?? 'VALIDE',
    version: Value(_intN(j['version'])),
    updatedAt: Value(_date(j['updated_at'])),
    syncStatus: statut.wire,
  );

  static Json paiementCreation(Paiement p) => {
    'entreprise_id': p.entrepriseId,
    'activite_code': p.activite?.code,
    'perimetre_id': p.perimetreId,
    'sens': p.sens.code,
    'montant': p.montant,
    'mode_code': p.mode.code,
    'date_paiement': p.datePaiement.toUtc().toIso8601String(),
    'contact_id': p.contactId,
    'reference': p.reference,
    'note': p.note,
    'session_id': p.sessionId,
    'affectations': _affectationsListe(p.affectations),
    'annule_paiement_id': p.annulePaiementId,
    'nature': p.nature?.code,
  };

  static TransfertTresorerie transfert(TransfertRow r) => TransfertTresorerie(
    id: r.id,
    entrepriseId: r.entrepriseId,
    perimetreSourceId: r.perimetreSourceId,
    perimetreDestId: r.perimetreDestId,
    modeSource: ModePaiement.parse(r.modeSource),
    modeDest: ModePaiement.parse(r.modeDest),
    montant: r.montant,
    sessionSourceId: r.sessionSourceId,
    sessionDestId: r.sessionDestId,
    sortieId: r.sortieId,
    entreeId: r.entreeId,
    dateTransfert: r.dateTransfert,
    motif: r.motif,
    annule: r.statut == 'ANNULE',
    motifAnnulation: r.motifAnnulation,
    annulationSortieId: r.annulationSortieId,
    annulationEntreeId: r.annulationEntreeId,
    version: r.version,
    syncStatus: RecordSyncStatus.fromWire(r.syncStatus),
  );

  static TransfertsTresorerieCompanion transfertLocal(TransfertTresorerie t, RecordSyncStatus statut) =>
      TransfertsTresorerieCompanion.insert(
        id: t.id,
        entrepriseId: t.entrepriseId,
        perimetreSourceId: Value(t.perimetreSourceId),
        perimetreDestId: Value(t.perimetreDestId),
        modeSource: t.modeSource.code,
        modeDest: t.modeDest.code,
        montant: t.montant,
        sessionSourceId: Value(t.sessionSourceId),
        sessionDestId: Value(t.sessionDestId),
        sortieId: t.sortieId,
        entreeId: t.entreeId,
        dateTransfert: t.dateTransfert,
        motif: Value(t.motif),
        statut: t.annule ? 'ANNULE' : 'VALIDE',
        motifAnnulation: Value(t.motifAnnulation),
        annulationSortieId: Value(t.annulationSortieId),
        annulationEntreeId: Value(t.annulationEntreeId),
        version: Value(t.version),
        syncStatus: statut.wire,
      );

  static TransfertsTresorerieCompanion transfertServeur(Json j, RecordSyncStatus statut) =>
      TransfertsTresorerieCompanion.insert(
        id: j['id'] as String,
        entrepriseId: j['entreprise_id'] as String,
        perimetreSourceId: Value(j['perimetre_source_id'] as String?),
        perimetreDestId: Value(j['perimetre_dest_id'] as String?),
        modeSource: j['mode_source'] as String,
        modeDest: j['mode_dest'] as String,
        montant: _int(j['montant']),
        sessionSourceId: Value(j['session_source_id'] as String?),
        sessionDestId: Value(j['session_dest_id'] as String?),
        sortieId: j['sortie_id'] as String,
        entreeId: j['entree_id'] as String,
        dateTransfert: DateTime.parse(j['date_transfert'] as String),
        motif: Value(j['motif'] as String?),
        statut: j['statut'] as String? ?? 'VALIDE',
        motifAnnulation: Value(j['motif_annulation'] as String?),
        annulationSortieId: Value(j['annulation_sortie_id'] as String?),
        annulationEntreeId: Value(j['annulation_entree_id'] as String?),
        version: Value(_intN(j['version'])),
        updatedAt: Value(_date(j['updated_at'])),
        syncStatus: statut.wire,
      );

  static Json transfertCreation(TransfertTresorerie t) => {
    'entreprise_id': t.entrepriseId,
    'perimetre_source_id': t.perimetreSourceId,
    'perimetre_dest_id': t.perimetreDestId,
    'mode_source': t.modeSource.code,
    'mode_dest': t.modeDest.code,
    'montant': t.montant,
    'session_source_id': t.sessionSourceId,
    'session_dest_id': t.sessionDestId,
    'sortie_id': t.sortieId,
    'entree_id': t.entreeId,
    'date_transfert': t.dateTransfert.toUtc().toIso8601String(),
    'motif': t.motif,
  };

  static bool transfertIdentique(TransfertRow l, Json s) =>
      l.statut == (s['statut'] ?? 'VALIDE') && l.motifAnnulation == s['motif_annulation'];

  static PaiementAffectationsCompanion affectationLocale(Paiement p, Affectation a) =>
      PaiementAffectationsCompanion.insert(
        id: a.id,
        entrepriseId: p.entrepriseId,
        paiementId: p.id,
        engagementId: a.engagementId,
        montant: a.montant,
        // Copie locale d'une ligne créée par le serveur : remplacée telle quelle.
        syncStatus: RecordSyncStatus.synced.wire,
      );

  static PaiementAffectationsCompanion affectationServeur(Json j, RecordSyncStatus statut) =>
      PaiementAffectationsCompanion.insert(
        id: j['id'] as String,
        entrepriseId: j['entreprise_id'] as String,
        paiementId: j['paiement_id'] as String,
        engagementId: j['engagement_id'] as String,
        montant: _int(j['montant']),
        version: Value(_intN(j['version'])),
        updatedAt: Value(_date(j['updated_at'])),
        syncStatus: statut.wire,
      );

  // --- Dépenses ------------------------------------------------------------

  static CategorieDepense categorie(CategorieDepenseRow r) => CategorieDepense(
    id: r.id,
    entrepriseId: r.entrepriseId,
    code: r.code,
    nom: r.nom,
    estActive: r.estActive,
    ordre: r.ordre,
    version: r.version,
    syncStatus: RecordSyncStatus.fromWire(r.syncStatus),
  );

  static DepenseCategoriesCompanion categorieLocale(CategorieDepense c, RecordSyncStatus statut) =>
      DepenseCategoriesCompanion.insert(
        id: c.id,
        entrepriseId: c.entrepriseId,
        code: Value(c.code),
        nom: Value(c.nom),
        estActive: Value(c.estActive),
        ordre: Value(c.ordre),
        version: Value(c.version),
        syncStatus: statut.wire,
      );

  static DepenseCategoriesCompanion categorieServeur(Json j, RecordSyncStatus statut) =>
      DepenseCategoriesCompanion.insert(
        id: j['id'] as String,
        entrepriseId: j['entreprise_id'] as String,
        code: Value(j['code'] as String?),
        nom: Value(j['nom'] as String?),
        estActive: Value(j['est_active'] as bool? ?? true),
        ordre: Value(_intN(j['ordre']) ?? 100),
        version: Value(_intN(j['version'])),
        updatedAt: Value(_date(j['updated_at'])),
        syncStatus: statut.wire,
      );

  static bool categorieIdentique(CategorieDepenseRow l, Json s) =>
      l.nom == s['nom'] && l.estActive == (s['est_active'] ?? true) && l.ordre == (_intN(s['ordre']) ?? 100);

  static Depense depense(DepenseRow r) => Depense(
    id: r.id,
    entrepriseId: r.entrepriseId,
    activite: ActiviteCode.tryParse(r.activiteCode),
    perimetreId: r.perimetreId,
    categorieId: r.categorieId,
    libelle: r.libelle,
    montant: r.montant,
    dateDepense: _jour(r.dateDepense),
    contactId: r.contactId,
    payeeImmediatement: r.reglement == 'IMMEDIAT',
    mode: r.modeCode == null ? null : ModePaiement.parse(r.modeCode),
    sessionId: r.sessionId,
    paiementId: r.paiementId,
    echeance: r.echeance == null ? null : _jour(r.echeance!),
    reference: r.reference,
    note: r.note,
    beneficiaire: r.beneficiaire,
    couranteId: r.couranteId,
    echeancePrevue: r.echeancePrevue == null ? null : _jour(r.echeancePrevue!),
    annulee: r.statut == 'ANNULEE',
    motifAnnulation: r.motifAnnulation,
    version: r.version,
    syncStatus: RecordSyncStatus.fromWire(r.syncStatus),
  );

  static DepensesCompanion depenseLocale(Depense d, RecordSyncStatus statut) => DepensesCompanion.insert(
    id: d.id,
    entrepriseId: d.entrepriseId,
    activiteCode: Value(d.activite?.code),
    perimetreId: Value(d.perimetreId),
    categorieId: d.categorieId,
    libelle: d.libelle,
    montant: d.montant,
    dateDepense: jourIso(d.dateDepense),
    contactId: Value(d.contactId),
    reglement: d.payeeImmediatement ? 'IMMEDIAT' : 'DIFFERE',
    modeCode: Value(d.mode?.code),
    sessionId: Value(d.sessionId),
    paiementId: Value(d.paiementId),
    echeance: Value(d.echeance == null ? null : jourIso(d.echeance!)),
    reference: Value(d.reference),
    note: Value(d.note),
    beneficiaire: Value(d.beneficiaire),
    couranteId: Value(d.couranteId),
    echeancePrevue: Value(d.echeancePrevue == null ? null : jourIso(d.echeancePrevue!)),
    statut: d.annulee ? 'ANNULEE' : 'ENREGISTREE',
    motifAnnulation: Value(d.motifAnnulation),
    version: Value(d.version),
    syncStatus: statut.wire,
  );

  static DepensesCompanion depenseServeur(Json j, RecordSyncStatus statut) => DepensesCompanion.insert(
    id: j['id'] as String,
    entrepriseId: j['entreprise_id'] as String,
    activiteCode: Value(j['activite_code'] as String?),
    perimetreId: Value(j['perimetre_id'] as String?),
    categorieId: j['categorie_id'] as String,
    libelle: j['libelle'] as String,
    montant: _int(j['montant']),
    dateDepense: ((j['date_depense'] as String?) ?? jourIso(DateTime.now())).substring(0, 10),
    contactId: Value(j['contact_id'] as String?),
    reglement: j['reglement'] as String,
    modeCode: Value(j['mode_code'] as String?),
    sessionId: Value(j['session_id'] as String?),
    paiementId: Value(j['paiement_id'] as String?),
    echeance: Value((j['echeance'] as String?)?.substring(0, 10)),
    reference: Value(j['reference'] as String?),
    note: Value(j['note'] as String?),
    beneficiaire: Value(j['beneficiaire'] as String?),
    couranteId: Value(j['courante_id'] as String?),
    echeancePrevue: Value((j['echeance_prevue'] as String?)?.substring(0, 10)),
    statut: j['statut'] as String? ?? 'ENREGISTREE',
    motifAnnulation: Value(j['motif_annulation'] as String?),
    version: Value(_intN(j['version'])),
    updatedAt: Value(_date(j['updated_at'])),
    syncStatus: statut.wire,
  );

  static Json depenseCreation(Depense d) => {
    'entreprise_id': d.entrepriseId,
    'activite_code': d.activite?.code,
    'perimetre_id': d.perimetreId,
    'categorie_id': d.categorieId,
    'libelle': d.libelle,
    'montant': d.montant,
    'date_depense': jourIso(d.dateDepense),
    'contact_id': d.contactId,
    'reglement': d.payeeImmediatement ? 'IMMEDIAT' : 'DIFFERE',
    'mode_code': d.mode?.code,
    'session_id': d.sessionId,
    'paiement_id': d.paiementId,
    'echeance': d.echeance == null ? null : jourIso(d.echeance!),
    'reference': d.reference,
    'note': d.note,
    'beneficiaire': d.beneficiaire,
    'courante_id': d.couranteId,
    'echeance_prevue': d.echeancePrevue == null ? null : jourIso(d.echeancePrevue!),
  };

  static Json depenseModification(Depense d) => {
    'categorie_id': d.categorieId,
    'libelle': d.libelle,
    'date_depense': jourIso(d.dateDepense),
    'reference': d.reference,
    'note': d.note,
    'beneficiaire': d.beneficiaire,
    'statut': d.annulee ? 'ANNULEE' : 'ENREGISTREE',
    'motif_annulation': d.motifAnnulation,
  };

  static bool depenseIdentique(DepenseRow l, Json s) =>
      l.categorieId == s['categorie_id'] &&
      l.libelle == s['libelle'] &&
      l.dateDepense == (s['date_depense'] as String?)?.substring(0, 10) &&
      l.reference == s['reference'] &&
      l.note == s['note'] &&
      l.beneficiaire == s['beneficiaire'] &&
      l.statut == (s['statut'] ?? 'ENREGISTREE') &&
      l.motifAnnulation == s['motif_annulation'];

  // --- Dépenses courantes ---------------------------------------------------

  static DepenseCourante courante(DepenseCouranteRow r) => DepenseCourante(
    id: r.id,
    entrepriseId: r.entrepriseId,
    activite: ActiviteCode.tryParse(r.activiteCode),
    perimetreId: r.perimetreId,
    categorieId: r.categorieId,
    nom: r.nom,
    montantPrevu: r.montantPrevu,
    montantVariable: r.typeMontant == 'VARIABLE',
    periode: PeriodeRecurrence.parse(r.periode),
    intervalle: r.intervalle,
    dateDebut: _jour(r.dateDebut),
    prochaineEcheance: _jour(r.prochaineEcheance),
    mode: r.modeCode == null ? null : ModePaiement.parse(r.modeCode),
    beneficiaire: r.beneficiaire,
    note: r.note,
    estActive: r.estActive,
    version: r.version,
    syncStatus: RecordSyncStatus.fromWire(r.syncStatus),
  );

  static DepensesCourantesCompanion couranteLocale(DepenseCourante c, RecordSyncStatus statut) =>
      DepensesCourantesCompanion.insert(
        id: c.id,
        entrepriseId: c.entrepriseId,
        activiteCode: Value(c.activite?.code),
        perimetreId: Value(c.perimetreId),
        categorieId: c.categorieId,
        nom: c.nom,
        montantPrevu: c.montantPrevu,
        typeMontant: c.montantVariable ? 'VARIABLE' : 'FIXE',
        periode: c.periode.code,
        intervalle: Value(c.intervalle),
        dateDebut: jourIso(c.dateDebut),
        prochaineEcheance: jourIso(c.prochaineEcheance),
        modeCode: Value(c.mode?.code),
        beneficiaire: Value(c.beneficiaire),
        note: Value(c.note),
        estActive: Value(c.estActive),
        version: Value(c.version),
        syncStatus: statut.wire,
      );

  static DepensesCourantesCompanion couranteServeur(Json j, RecordSyncStatus statut) =>
      DepensesCourantesCompanion.insert(
        id: j['id'] as String,
        entrepriseId: j['entreprise_id'] as String,
        activiteCode: Value(j['activite_code'] as String?),
        perimetreId: Value(j['perimetre_id'] as String?),
        categorieId: j['categorie_id'] as String,
        nom: j['nom'] as String,
        montantPrevu: _int(j['montant_prevu']),
        typeMontant: j['type_montant'] as String? ?? 'FIXE',
        periode: j['periode'] as String,
        intervalle: Value(_intN(j['intervalle']) ?? 1),
        dateDebut: (j['date_debut'] as String).substring(0, 10),
        prochaineEcheance: (j['prochaine_echeance'] as String).substring(0, 10),
        modeCode: Value(j['mode_code'] as String?),
        beneficiaire: Value(j['beneficiaire'] as String?),
        note: Value(j['note'] as String?),
        estActive: Value(j['est_active'] as bool? ?? true),
        version: Value(_intN(j['version'])),
        updatedAt: Value(_date(j['updated_at'])),
        syncStatus: statut.wire,
      );

  static Json couranteCreation(DepenseCourante c) => {
    'entreprise_id': c.entrepriseId,
    'activite_code': c.activite?.code,
    'perimetre_id': c.perimetreId,
    ...couranteModification(c)..remove('est_active'),
    'date_debut': jourIso(c.dateDebut),
  };

  static Json couranteModification(DepenseCourante c) => {
    'categorie_id': c.categorieId,
    'nom': c.nom,
    'montant_prevu': c.montantPrevu,
    'type_montant': c.montantVariable ? 'VARIABLE' : 'FIXE',
    'periode': c.periode.code,
    'intervalle': c.intervalle,
    'prochaine_echeance': jourIso(c.prochaineEcheance),
    'mode_code': c.mode?.code,
    'beneficiaire': c.beneficiaire,
    'note': c.note,
    'est_active': c.estActive,
  };

  static bool couranteIdentique(DepenseCouranteRow l, Json s) =>
      l.categorieId == s['categorie_id'] &&
      l.nom == s['nom'] &&
      l.montantPrevu == _int(s['montant_prevu']) &&
      l.typeMontant == s['type_montant'] &&
      l.periode == s['periode'] &&
      l.intervalle == _int(s['intervalle']) &&
      l.prochaineEcheance == (s['prochaine_echeance'] as String?)?.substring(0, 10) &&
      l.modeCode == s['mode_code'] &&
      l.beneficiaire == s['beneficiaire'] &&
      l.note == s['note'] &&
      l.estActive == (s['est_active'] ?? true);

  // --- Caisses --------------------------------------------------------------

  static Caisse caisse(CaisseRow r) => Caisse(
    id: r.id,
    entrepriseId: r.entrepriseId,
    perimetreId: r.perimetreId,
    nom: r.nom,
    estActive: r.estActive,
    version: r.version,
    syncStatus: RecordSyncStatus.fromWire(r.syncStatus),
  );

  static CaissesCompanion caisseLocale(Caisse c, RecordSyncStatus statut) => CaissesCompanion.insert(
    id: c.id,
    entrepriseId: c.entrepriseId,
    perimetreId: c.perimetreId,
    nom: c.nom,
    estActive: Value(c.estActive),
    version: Value(c.version),
    syncStatus: statut.wire,
  );

  static CaissesCompanion caisseServeur(Json j, RecordSyncStatus statut) => CaissesCompanion.insert(
    id: j['id'] as String,
    entrepriseId: j['entreprise_id'] as String,
    perimetreId: j['perimetre_id'] as String,
    nom: j['nom'] as String,
    estActive: Value(j['est_active'] as bool? ?? true),
    version: Value(_intN(j['version'])),
    updatedAt: Value(_date(j['updated_at'])),
    syncStatus: statut.wire,
  );

  static bool caisseIdentique(CaisseRow l, Json s) => l.nom == s['nom'] && l.estActive == s['est_active'];

  static SessionCaisse session(SessionCaisseRow r) => SessionCaisse(
    id: r.id,
    entrepriseId: r.entrepriseId,
    caisseId: r.caisseId,
    perimetreId: r.perimetreId,
    ouverte: r.statut == 'OUVERTE',
    soldeInitial: r.soldeInitial,
    ouverteLe: r.ouverteLe,
    fermeeLe: r.fermeeLe,
    soldeTheorique: r.soldeTheorique,
    soldeReel: r.soldeReel,
    ecart: r.ecart,
    noteCloture: r.noteCloture,
    motifEcart: MotifEcart.tryParse(r.motifEcart),
    version: r.version,
    syncStatus: RecordSyncStatus.fromWire(r.syncStatus),
  );

  static CaisseSessionsCompanion sessionLocale(SessionCaisse s, RecordSyncStatus statut) =>
      CaisseSessionsCompanion.insert(
        id: s.id,
        entrepriseId: s.entrepriseId,
        caisseId: s.caisseId,
        perimetreId: s.perimetreId,
        statut: s.ouverte ? 'OUVERTE' : 'FERMEE',
        soldeInitial: s.soldeInitial,
        ouverteLe: s.ouverteLe,
        fermeeLe: Value(s.fermeeLe),
        soldeTheorique: Value(s.soldeTheorique),
        soldeReel: Value(s.soldeReel),
        ecart: Value(s.ecart),
        noteCloture: Value(s.noteCloture),
        motifEcart: Value(s.motifEcart?.code),
        version: Value(s.version),
        syncStatus: statut.wire,
      );

  static CaisseSessionsCompanion sessionServeur(Json j, RecordSyncStatus statut) => CaisseSessionsCompanion.insert(
    id: j['id'] as String,
    entrepriseId: j['entreprise_id'] as String,
    caisseId: j['caisse_id'] as String,
    perimetreId: j['perimetre_id'] as String,
    statut: j['statut'] as String? ?? 'OUVERTE',
    soldeInitial: _int(j['solde_initial']),
    ouverteLe: DateTime.parse(j['ouverte_le'] as String),
    ouvertePar: Value(j['ouverte_par'] as String?),
    fermeeLe: Value(_date(j['fermee_le'])),
    fermeePar: Value(j['fermee_par'] as String?),
    soldeTheorique: Value(_intN(j['solde_theorique'])),
    soldeReel: Value(_intN(j['solde_reel'])),
    ecart: Value(_intN(j['ecart'])),
    noteCloture: Value(j['note_cloture'] as String?),
    motifEcart: Value(j['motif_ecart'] as String?),
    version: Value(_intN(j['version'])),
    updatedAt: Value(_date(j['updated_at'])),
    syncStatus: statut.wire,
  );

  static bool sessionIdentique(SessionCaisseRow l, Json s) =>
      l.statut == s['statut'] &&
      l.soldeReel == _intN(s['solde_reel']) &&
      l.noteCloture == s['note_cloture'] &&
      l.motifEcart == s['motif_ecart'];

  static MouvementCaisse mouvement(MouvementCaisseRow r) => MouvementCaisse(
    id: r.id,
    sessionId: r.sessionId,
    caisseId: r.caisseId,
    type: TypeMouvement.parse(r.type),
    montant: r.montant,
    paiementId: r.paiementId,
    motif: r.motif,
    createdAt: r.createdAt,
    syncStatus: RecordSyncStatus.fromWire(r.syncStatus),
  );

  static CaisseMouvementsCompanion mouvementLocal(
    MouvementCaisse m, {
    required String entrepriseId,
    required String perimetreId,
    required RecordSyncStatus statut,
  }) => CaisseMouvementsCompanion.insert(
    id: m.id,
    entrepriseId: entrepriseId,
    sessionId: m.sessionId,
    caisseId: m.caisseId,
    perimetreId: perimetreId,
    type: m.type.code,
    sens: m.type.estEntree ? 'ENTREE' : 'SORTIE',
    montant: m.montant,
    paiementId: Value(m.paiementId),
    motif: Value(m.motif),
    createdAt: m.createdAt,
    syncStatus: statut.wire,
  );

  static CaisseMouvementsCompanion mouvementServeur(Json j, RecordSyncStatus statut) =>
      CaisseMouvementsCompanion.insert(
        id: j['id'] as String,
        entrepriseId: j['entreprise_id'] as String,
        sessionId: j['session_id'] as String,
        caisseId: j['caisse_id'] as String,
        perimetreId: j['perimetre_id'] as String,
        type: j['type'] as String,
        sens: j['sens'] as String,
        montant: _int(j['montant']),
        paiementId: Value(j['paiement_id'] as String?),
        motif: Value(j['motif'] as String?),
        createdAt: DateTime.parse(j['created_at'] as String),
        version: Value(_intN(j['version'])),
        updatedAt: Value(_date(j['updated_at'])),
        syncStatus: statut.wire,
      );
}
