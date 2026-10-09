import 'package:uuid/uuid.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/permissions/access_decision.dart';
import '../../../../core/permissions/permission_codes.dart';
import '../../../../core/sync/sync_models.dart';
import '../../../entreprise/domain/entities/contexte_session.dart';
import '../../../modules/domain/entities/app_module.dart';
import '../entities/finances.dart';
import '../repositories/finances_repository.dart';
import '../services/etat_finances.dart';
import 'gerer_finances.dart';

const _uuid = Uuid();

class SaisieDepense {
  const SaisieDepense({
    required this.categorieId,
    required this.libelle,
    required this.montant,
    required this.payeeMaintenant,
    this.date,
    this.contactId,
    this.perimetreId,
    this.mode = ModePaiement.especes,
    this.sessionId,
    this.echeance,
    this.reference,
    this.note,
    this.beneficiaire,
    this.couranteId,
    this.echeancePrevue,
  });

  final String categorieId;
  final String libelle;
  final int montant;

  /// `true` : payée maintenant (paiement + caisse) ; `false` : à payer plus tard.
  final bool payeeMaintenant;
  final DateTime? date;
  final String? contactId;
  final String? perimetreId;
  final ModePaiement mode;
  final String? sessionId;
  final DateTime? echeance;
  final String? reference;
  final String? note;

  /// « Payé à », sans créer de contact.
  final String? beneficiaire;

  /// Paiement d'une échéance de dépense courante.
  final String? couranteId;
  final DateTime? echeancePrevue;
}

class EnregistrerDepense {
  const EnregistrerDepense(this._repository);
  final FinancesRepository _repository;

  Future<Depense> call(ContexteSession ctx, EtatFinances etat, SaisieDepense s) async {
    SessionCaisse? session;
    var perimetreId = s.perimetreId;
    if (s.payeeMaintenant && s.sessionId != null) {
      session = etat.sessions.where((x) => x.id == s.sessionId).firstOrNull;
      perimetreId ??= session?.perimetreId;
    }

    _verifier(_peut(ctx, ModuleCodes.financesDepenses, PermissionCodes.expensesCreate, perimetreId));
    if (s.payeeMaintenant) {
      _verifier(_peut(ctx, ModuleCodes.financesPaiements, PermissionCodes.paymentsCreate, perimetreId));
    }
    final libelle = s.libelle.trim();
    if (libelle.isEmpty || libelle.length > 200) throw const Failure.rule(RuleCodes.labelInvalid);
    if (s.montant <= 0) throw const Failure.rule(RuleCodes.amountInvalid);
    final categorie = etat.categorie(s.categorieId);
    if (categorie == null || !categorie.estActive) throw const Failure.rule(RuleCodes.categoryInvalid);
    final date = _jour(s.date ?? DateTime.now());
    if (date.isAfter(_jour(DateTime.now()).add(const Duration(days: 1)))) {
      throw const Failure.rule(RuleCodes.dateInvalid);
    }
    final beneficiaire = _nul(s.beneficiaire);
    if (beneficiaire != null && beneficiaire.length > 120) throw const Failure.rule(RuleCodes.nameInvalid);
    final echeance = s.echeancePrevue == null ? null : _jour(s.echeancePrevue!);
    if (s.couranteId != null) {
      if (echeance == null || etat.courante(s.couranteId!) == null) {
        throw const Failure.rule(RuleCodes.recurringExpenseInvalid);
      }
      if (etat.paiementEcheance(s.couranteId!, echeance) != null) throw const Failure.rule(RuleCodes.dueAlreadyPaid);
    }

    if (s.sessionId != null && s.payeeMaintenant) {
      if (session == null || !session.ouverte) throw const Failure.rule(RuleCodes.cashClosed);
      if (!s.mode.passeParCaisse) throw const Failure.rule(RuleCodes.modeWithoutCash);
      _verifier(_peut(ctx, ModuleCodes.financesCaisse, PermissionCodes.cashMove, session.perimetreId));
      if (etat.solde(session) < s.montant) {
        throw Failure.rule(RuleCodes.cashInsufficient, {'solde': etat.solde(session)});
      }
    }

    final id = _uuid.v4();
    final paiementId = s.payeeMaintenant ? _uuid.v4() : null;
    final activite = perimetreId == null
        ? null
        : ctx.perimetres.where((p) => p.id == perimetreId).firstOrNull?.activite;
    final depense = Depense(
      id: id,
      entrepriseId: ctx.entreprise!.id,
      activite: activite,
      perimetreId: perimetreId,
      categorieId: s.categorieId,
      libelle: libelle,
      montant: s.montant,
      dateDepense: date,
      contactId: s.contactId,
      payeeImmediatement: s.payeeMaintenant,
      mode: s.payeeMaintenant ? s.mode : null,
      sessionId: s.payeeMaintenant ? s.sessionId : null,
      paiementId: paiementId,
      echeance: s.payeeMaintenant || s.echeance == null ? null : _jour(s.echeance!),
      reference: _nul(s.reference),
      note: _nul(s.note),
      beneficiaire: beneficiaire,
      couranteId: s.couranteId,
      echeancePrevue: s.couranteId == null ? null : echeance,
      syncStatus: RecordSyncStatus.pendingSync,
    );

    // Copies locales de ce que le serveur créera, avec les mêmes identifiants.
    final engagement = Engagement(
      id: id,
      entrepriseId: depense.entrepriseId,
      activite: activite,
      perimetreId: perimetreId,
      sens: SensEngagement.aPayer,
      contactId: s.contactId,
      libelle: libelle,
      montantTotal: s.montant,
      dateEngagement: date,
      echeance: depense.echeance,
      origineType: 'DEPENSE',
    );
    Paiement? paiement;
    MouvementCaisse? mouvement;
    if (paiementId != null) {
      paiement = Paiement(
        id: paiementId,
        entrepriseId: depense.entrepriseId,
        activite: activite,
        perimetreId: perimetreId,
        sens: SensPaiement.sortie,
        montant: s.montant,
        mode: s.mode,
        datePaiement: DateTime.now(),
        contactId: s.contactId,
        reference: depense.reference,
        note: libelle,
        sessionId: depense.sessionId,
        affectations: [Affectation(id: paiementId, engagementId: id, montant: s.montant)],
        syncStatus: RecordSyncStatus.pendingSync,
      );
      if (session != null) {
        mouvement = MouvementCaisse(
          id: paiementId,
          sessionId: session.id,
          caisseId: session.caisseId,
          type: TypeMouvement.decaissement,
          montant: s.montant,
          paiementId: paiementId,
          createdAt: DateTime.now(),
        );
      }
    }
    await _repository.enregistrerDepense(depense, engagement: engagement, paiement: paiement, mouvement: mouvement);
    return depense;
  }
}

class ModifierDepense {
  const ModifierDepense(this._repository, this._annulerPaiement);
  final FinancesRepository _repository;
  final AnnulerPaiement _annulerPaiement;

  /// Texte, catégorie, date (le montant ne se modifie pas : annuler et ressaisir).
  Future<void> call(
    ContexteSession ctx,
    EtatFinances etat,
    Depense d, {
    required String categorieId,
    required String libelle,
    required DateTime date,
    String? reference,
    String? note,
    String? beneficiaire,
  }) async {
    _verifier(_peut(ctx, ModuleCodes.financesDepenses, PermissionCodes.expensesUpdate, d.perimetreId));
    if (d.annulee) throw const Failure.rule(RuleCodes.expenseCancelled);
    final l = libelle.trim();
    if (l.isEmpty || l.length > 200) throw const Failure.rule(RuleCodes.labelInvalid);
    final b = _nul(beneficiaire);
    if (b != null && b.length > 120) throw const Failure.rule(RuleCodes.nameInvalid);
    final categorie = etat.categorie(categorieId);
    if (categorieId != d.categorieId && (categorie == null || !categorie.estActive)) {
      throw const Failure.rule(RuleCodes.categoryInvalid);
    }
    await _repository.modifierDepense(
      d,
      d.copyWith(
        categorieId: categorieId,
        libelle: l,
        dateDepense: _jour(date),
        reference: () => _nul(reference),
        note: () => _nul(note),
        beneficiaire: () => b,
      ),
    );
  }

  /// Rien n'est effacé : le paiement éventuel est d'abord annulé (paiement
  /// inverse, caisse ajustée), puis la dépense et sa somme à payer.
  Future<void> annuler(ContexteSession ctx, EtatFinances etat, Depense d, {String? motif}) async {
    _verifier(_peut(ctx, ModuleCodes.financesDepenses, PermissionCodes.expensesCancel, d.perimetreId));
    if (d.annulee) return;
    final suivi = etat.engagements.where((e) => e.id == d.id).map(etat.suivi).firstOrNull;
    final paiements = [
      for (final p in etat.paiements)
        if (etat.compte(p) && p.affectations.any((a) => a.engagementId == d.id)) p,
    ];
    if (paiements.isNotEmpty || (suivi?.regle ?? 0) > 0) {
      if (paiements.isEmpty) throw const Failure.rule(RuleCodes.expensePaid);
      for (final p in paiements) {
        await _annulerPaiement(ctx, etat, p);
      }
    }
    await _repository.modifierDepense(d, d.copyWith(annulee: true, motifAnnulation: _nul(motif)));
  }
}

class SaisieCourante {
  const SaisieCourante({
    required this.nom,
    required this.categorieId,
    required this.montantPrevu,
    required this.periode,
    this.intervalle = 1,
    this.montantVariable = false,
    this.prochaineEcheance,
    this.perimetreId,
    this.mode,
    this.beneficiaire,
    this.note,
  });

  final String nom;
  final String categorieId;
  final int montantPrevu;
  final PeriodeRecurrence periode;
  final int intervalle;
  final bool montantVariable;

  /// Première échéance (aujourd'hui par défaut) ; le rythme part de là.
  final DateTime? prochaineEcheance;

  /// `null` : toute l'entreprise.
  final String? perimetreId;
  final ModePaiement? mode;
  final String? beneficiaire;
  final String? note;
}

/// Dépenses courantes : modèles récurrents. Une échéance n'est comptée qu'une
/// fois payée par une vraie dépense ([payer]), avec son montant réel.
class GererDepensesCourantes {
  const GererDepensesCourantes(this._repository, this._enregistrer);
  final FinancesRepository _repository;
  final EnregistrerDepense _enregistrer;

  Future<DepenseCourante> creer(ContexteSession ctx, EtatFinances etat, SaisieCourante s) async {
    _verifier(_peut(ctx, ModuleCodes.financesDepenses, PermissionCodes.expensesRecurring, s.perimetreId));
    final (nom, beneficiaire, note) = _valider(etat, s);
    final debut = _jour(s.prochaineEcheance ?? DateTime.now());
    final c = DepenseCourante(
      id: _uuid.v4(),
      entrepriseId: ctx.entreprise!.id,
      activite: s.perimetreId == null ? null : ctx.perimetres.where((p) => p.id == s.perimetreId).firstOrNull?.activite,
      perimetreId: s.perimetreId,
      categorieId: s.categorieId,
      nom: nom,
      montantPrevu: s.montantPrevu,
      montantVariable: s.montantVariable,
      periode: s.periode,
      intervalle: s.intervalle,
      dateDebut: debut,
      prochaineEcheance: debut,
      mode: s.mode,
      beneficiaire: beneficiaire,
      note: note,
      syncStatus: RecordSyncStatus.pendingSync,
    );
    await _repository.creerCourante(c);
    return c;
  }

  /// Nom, montant, rythme, prochaine échéance… (affectation inchangée).
  Future<void> modifier(ContexteSession ctx, EtatFinances etat, DepenseCourante c, SaisieCourante s) async {
    _verifier(_peut(ctx, ModuleCodes.financesDepenses, PermissionCodes.expensesRecurring, c.perimetreId));
    final (nom, beneficiaire, note) = _valider(etat, s, ancienneCategorie: c.categorieId);
    final prochaine = _jour(s.prochaineEcheance ?? c.prochaineEcheance);
    final rythmeChange = s.periode != c.periode || s.intervalle != c.intervalle;
    await _repository.modifierCourante(
      c,
      c.copyWith(
        nom: nom,
        categorieId: s.categorieId,
        montantPrevu: s.montantPrevu,
        montantVariable: s.montantVariable,
        periode: s.periode,
        intervalle: s.intervalle,
        // Nouveau rythme : il repart de la prochaine échéance (règle serveur).
        dateDebut: rythmeChange || prochaine.isBefore(c.dateDebut) ? prochaine : null,
        prochaineEcheance: prochaine,
        mode: () => s.mode,
        beneficiaire: () => beneficiaire,
        note: () => note,
      ),
    );
  }

  /// Arrêter (ou reprendre) : l'historique des paiements reste.
  Future<void> activer(ContexteSession ctx, DepenseCourante c, {required bool active}) async {
    _verifier(_peut(ctx, ModuleCodes.financesDepenses, PermissionCodes.expensesRecurring, c.perimetreId));
    if (c.estActive == active) return;
    await _repository.modifierCourante(c, c.copyWith(estActive: active));
  }

  /// « Pas cette fois » : l'échéance est sautée sans rien payer.
  Future<void> ignorerEcheance(ContexteSession ctx, DepenseCourante c) async {
    _verifier(_peut(ctx, ModuleCodes.financesDepenses, PermissionCodes.expensesRecurring, c.perimetreId));
    await _repository.modifierCourante(c, c.copyWith(prochaineEcheance: c.suivante(c.prochaineEcheance)));
  }

  /// Paie la prochaine échéance avec le montant réel : une dépense normale
  /// (somme à payer, paiement, caisse), et la courante passe à la suivante.
  Future<Depense> payer(
    ContexteSession ctx,
    EtatFinances etat,
    DepenseCourante c, {
    required int montant,
    required bool payeeMaintenant,
    DateTime? date,
    ModePaiement? mode,
    String? sessionId,
    String? note,
  }) => _enregistrer(
    ctx,
    etat,
    SaisieDepense(
      categorieId: c.categorieId,
      libelle: c.nom,
      montant: montant,
      payeeMaintenant: payeeMaintenant,
      date: date,
      perimetreId: c.perimetreId,
      mode: mode ?? c.mode ?? ModePaiement.especes,
      sessionId: sessionId,
      beneficiaire: c.beneficiaire,
      note: note,
      couranteId: c.id,
      echeancePrevue: c.prochaineEcheance,
    ),
  );

  (String, String?, String?) _valider(EtatFinances etat, SaisieCourante s, {String? ancienneCategorie}) {
    final nom = s.nom.trim();
    if (nom.isEmpty || nom.length > 120) throw const Failure.rule(RuleCodes.nameInvalid);
    if (s.montantPrevu <= 0) throw const Failure.rule(RuleCodes.amountInvalid);
    if (s.intervalle < 1 || s.intervalle > 366) throw const Failure.rule(RuleCodes.recurringExpenseInvalid);
    final categorie = etat.categorie(s.categorieId);
    if (s.categorieId != ancienneCategorie && (categorie == null || !categorie.estActive)) {
      throw const Failure.rule(RuleCodes.categoryInvalid);
    }
    final beneficiaire = _nul(s.beneficiaire);
    if (beneficiaire != null && beneficiaire.length > 120) throw const Failure.rule(RuleCodes.nameInvalid);
    final note = _nul(s.note);
    if (note != null && note.length > 500) throw const Failure.rule(RuleCodes.labelInvalid);
    return (nom, beneficiaire, note);
  }
}

class GererCategories {
  const GererCategories(this._repository);
  final FinancesRepository _repository;

  Future<CategorieDepense> creer(ContexteSession ctx, EtatFinances etat, String nom) async {
    _verifier(_peut(ctx, ModuleCodes.financesDepenses, PermissionCodes.expensesUpdate));
    final n = nom.trim();
    if (n.isEmpty || n.length > 60) throw const Failure.rule(RuleCodes.nameInvalid);
    final c = CategorieDepense(
      id: _uuid.v4(),
      entrepriseId: ctx.entreprise!.id,
      nom: n,
      ordre: 50,
      syncStatus: RecordSyncStatus.pendingSync,
    );
    await _repository.creerCategorie(c);
    return c;
  }

  Future<void> modifier(ContexteSession ctx, CategorieDepense c, {String? nom, bool? estActive}) async {
    _verifier(_peut(ctx, ModuleCodes.financesDepenses, PermissionCodes.expensesUpdate));
    final n = nom?.trim();
    if (n != null && (n.isEmpty || n.length > 60)) throw const Failure.rule(RuleCodes.nameInvalid);
    await _repository.modifierCategorie(c, nom: n, estActive: estActive);
  }
}

AccessDecision _peut(ContexteSession ctx, String module, String permission, [String? perimetreId]) =>
    ctx.accessPolicy().canPerform(moduleCode: module, permission: permission, perimetreId: perimetreId);

void _verifier(AccessDecision decision) {
  if (decision case AccessDenied()) throw decision.toFailure();
}

DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

String? _nul(String? v) {
  final t = v?.trim();
  return t == null || t.isEmpty ? null : t;
}
