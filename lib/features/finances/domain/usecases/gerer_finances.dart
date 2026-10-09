import 'package:uuid/uuid.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/permissions/access_decision.dart';
import '../../../../core/permissions/permission_codes.dart';
import '../../../../core/sync/sync_models.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../../entreprise/domain/entities/contexte_session.dart';
import '../../../modules/domain/entities/app_module.dart';
import '../entities/finances.dart';
import '../repositories/finances_repository.dart';
import '../services/etat_finances.dart';

const _uuid = Uuid();

/// Ce que l'utilisateur peut faire dans les finances (affichage des boutons).
/// Les mêmes règles sont appliquées par le serveur.
class DroitsFinances {
  const DroitsFinances({
    this.voirCreances = false,
    this.gererCreances = false,
    this.voirPaiements = false,
    this.encaisser = false,
    this.decaisser = false,
    this.annulerPaiements = false,
    this.voirCaisse = false,
    this.ouvrirCaisse = false,
    this.mouvementerCaisse = false,
    this.cloturerCaisse = false,
    this.gererCaisses = false,
    this.voirDepenses = false,
    this.saisirDepenses = false,
    this.modifierDepenses = false,
    this.annulerDepenses = false,
    this.gererDepensesCourantes = false,
    this.transferer = false,
    this.ajuster = false,
  });

  factory DroitsFinances.de(ContexteSession ctx) {
    bool peut(String module, String permission) => _peut(ctx, module, permission).isAllowed;
    final encaisser = peut(ModuleCodes.financesPaiements, PermissionCodes.paymentsCreate);
    final gererCreances = peut(ModuleCodes.financesCreances, PermissionCodes.receivablesManage);
    return DroitsFinances(
      voirCreances: peut(ModuleCodes.financesCreances, PermissionCodes.receivablesView),
      gererCreances: gererCreances,
      voirPaiements: peut(ModuleCodes.financesPaiements, PermissionCodes.paymentsView),
      encaisser: encaisser,
      decaisser: encaisser && gererCreances,
      annulerPaiements: peut(ModuleCodes.financesPaiements, PermissionCodes.paymentsCancel),
      voirCaisse: peut(ModuleCodes.financesCaisse, PermissionCodes.cashView),
      ouvrirCaisse: peut(ModuleCodes.financesCaisse, PermissionCodes.cashOpen),
      mouvementerCaisse: peut(ModuleCodes.financesCaisse, PermissionCodes.cashMove),
      cloturerCaisse: peut(ModuleCodes.financesCaisse, PermissionCodes.cashClose),
      gererCaisses: peut(ModuleCodes.financesCaisse, PermissionCodes.entrepriseManage),
      voirDepenses: peut(ModuleCodes.financesDepenses, PermissionCodes.expensesView),
      saisirDepenses: peut(ModuleCodes.financesDepenses, PermissionCodes.expensesCreate),
      modifierDepenses: peut(ModuleCodes.financesDepenses, PermissionCodes.expensesUpdate),
      annulerDepenses: peut(ModuleCodes.financesDepenses, PermissionCodes.expensesCancel),
      gererDepensesCourantes: peut(ModuleCodes.financesDepenses, PermissionCodes.expensesRecurring),
      transferer: peut(ModuleCodes.financesCaisse, PermissionCodes.cashTransfer),
      ajuster: peut(ModuleCodes.financesCaisse, PermissionCodes.cashAdjust),
    );
  }

  final bool voirCreances;
  final bool gererCreances;
  final bool voirPaiements;
  final bool encaisser;
  final bool decaisser;
  final bool annulerPaiements;
  final bool voirCaisse;
  final bool ouvrirCaisse;
  final bool mouvementerCaisse;
  final bool cloturerCaisse;
  final bool gererCaisses;
  final bool voirDepenses;
  final bool saisirDepenses;

  /// Modifier les dépenses et gérer les catégories.
  final bool modifierDepenses;

  /// Annuler une dépense (motif conservé, rien n'est effacé).
  final bool annulerDepenses;

  /// Créer, modifier, arrêter les dépenses courantes.
  final bool gererDepensesCourantes;

  /// Transférer entre boutiques ou moyens d'argent (cash.transfer).
  final bool transferer;

  /// Corriger un solde : ajustement, solde initial (cash.adjust).
  final bool ajuster;
}

class ObserverFinances {
  const ObserverFinances(this._repository);
  final FinancesRepository _repository;

  Stream<EtatFinances> call(ContexteSession ctx) => _repository.watch(ctx.entreprise!.id);
}

// =============================================================================
// À recevoir / à payer
// =============================================================================

class SaisieEngagement {
  const SaisieEngagement({
    required this.sens,
    required this.libelle,
    required this.montant,
    this.contactId,
    this.echeance,
    this.perimetreId,
  });

  final SensEngagement sens;
  final String libelle;
  final int montant;
  final String? contactId;
  final DateTime? echeance;
  final String? perimetreId;
}

class CreerEngagement {
  const CreerEngagement(this._repository);
  final FinancesRepository _repository;

  Future<Engagement> call(ContexteSession ctx, SaisieEngagement s, {DateTime? aujourdhui}) async {
    _verifier(_peut(ctx, ModuleCodes.financesCreances, PermissionCodes.receivablesManage, s.perimetreId));
    final libelle = _valider(s.libelle, s.montant);
    final e = Engagement(
      id: _uuid.v4(),
      entrepriseId: ctx.entreprise!.id,
      activite: _activite(ctx, s.perimetreId),
      perimetreId: s.perimetreId,
      sens: s.sens,
      contactId: s.contactId,
      libelle: libelle,
      montantTotal: s.montant,
      dateEngagement: _jour(aujourdhui ?? DateTime.now()),
      echeance: s.echeance == null ? null : _jour(s.echeance!),
      syncStatus: RecordSyncStatus.pendingSync,
    );
    await _repository.creerEngagement(e);
    return e;
  }
}

class ModifierEngagement {
  const ModifierEngagement(this._repository);
  final FinancesRepository _repository;

  Future<void> call(ContexteSession ctx, EngagementSuivi suivi, SaisieEngagement s) async {
    final e = suivi.engagement;
    _verifier(_peut(ctx, ModuleCodes.financesCreances, PermissionCodes.receivablesManage, e.perimetreId));
    if (e.lie) throw const Failure.rule(RuleCodes.commitmentLinked);
    if (e.annule) throw const Failure.rule(RuleCodes.commitmentCancelled);
    final libelle = _valider(s.libelle, s.montant);
    if (s.montant < suivi.regle) throw Failure.rule(RuleCodes.totalBelowPaid, {'regle': suivi.regle});
    if (s.contactId != e.contactId && suivi.regle > 0) throw const Failure.rule(RuleCodes.commitmentPaid);
    await _repository.modifierEngagement(
      e,
      e.copyWith(
        libelle: libelle,
        montantTotal: s.montant,
        contactId: () => s.contactId,
        echeance: () => s.echeance == null ? null : _jour(s.echeance!),
      ),
    );
  }

  /// L'argent déjà reçu ne disparaît jamais : annuler d'abord les paiements.
  Future<void> annuler(ContexteSession ctx, EngagementSuivi suivi, {String? motif}) async {
    final e = suivi.engagement;
    _verifier(_peut(ctx, ModuleCodes.financesCreances, PermissionCodes.receivablesManage, e.perimetreId));
    if (e.lie) throw const Failure.rule(RuleCodes.commitmentLinked);
    if (e.annule) return;
    if (suivi.regle > 0) throw const Failure.rule(RuleCodes.commitmentPaid);
    await _repository.modifierEngagement(e, e.copyWith(annule: true, motifAnnulation: _nul(motif)));
  }
}

// =============================================================================
// Paiements
// =============================================================================

class SaisiePaiement {
  const SaisiePaiement({
    required this.sens,
    required this.montant,
    required this.mode,
    this.date,
    this.contactId,
    this.reference,
    this.note,
    this.perimetreId,
    this.sessionId,
    this.affectations = const {},
    this.nature,
  });

  /// Mouvement sans somme due (apport, retrait…) ; jamais avec des affectations.
  final NaturePaiement? nature;

  final SensPaiement sens;
  final int montant;
  final ModePaiement mode;
  final DateTime? date;
  final String? contactId;
  final String? reference;
  final String? note;
  final String? perimetreId;

  /// Session de caisse ouverte (espèces uniquement).
  final String? sessionId;

  /// Engagement → part du paiement qui le règle.
  final Map<String, int> affectations;
}

class EnregistrerPaiement {
  const EnregistrerPaiement(this._repository);
  final FinancesRepository _repository;

  /// Répartit un montant sur des engagements, du plus ancien au plus récent.
  static Map<String, int> repartir(int montant, List<EngagementSuivi> engagements) {
    final tries = [...engagements.where((e) => e.reste > 0)]
      ..sort(
        (a, b) => (a.engagement.echeance ?? a.engagement.dateEngagement).compareTo(
          b.engagement.echeance ?? b.engagement.dateEngagement,
        ),
      );
    final parts = <String, int>{};
    var restant = montant;
    for (final e in tries) {
      if (restant <= 0) break;
      final part = restant < e.reste ? restant : e.reste;
      parts[e.engagement.id] = part;
      restant -= part;
    }
    return parts;
  }

  Future<Paiement> call(ContexteSession ctx, EtatFinances etat, SaisiePaiement s) async {
    var perimetreId = s.perimetreId;
    SessionCaisse? session;
    if (s.sessionId != null) {
      session = etat.sessions.where((x) => x.id == s.sessionId).firstOrNull;
      perimetreId ??= session?.perimetreId;
    }

    _verifier(_peut(ctx, ModuleCodes.financesPaiements, PermissionCodes.paymentsCreate, perimetreId));
    if (s.sens == SensPaiement.sortie) {
      _verifier(_peut(ctx, ModuleCodes.financesCreances, PermissionCodes.receivablesManage, perimetreId));
    }
    if (s.montant <= 0) throw const Failure.rule(RuleCodes.amountInvalid);
    final date = s.date ?? DateTime.now();
    if (date.isAfter(DateTime.now().add(const Duration(days: 1)))) throw const Failure.rule(RuleCodes.dateInvalid);

    if (s.nature != null) {
      if (s.nature == NaturePaiement.transfert) throw const Failure.rule(RuleCodes.transferDirect);
      if (s.affectations.isNotEmpty) throw const Failure.rule(RuleCodes.natureIncompatible);
      if (s.nature!.estCorrection) {
        _verifier(_peut(ctx, ModuleCodes.financesCaisse, PermissionCodes.cashAdjust, perimetreId));
        if (_nul(s.note) == null) throw const Failure.rule(RuleCodes.reasonRequired);
      }
    }

    final total = s.affectations.values.fold(0, (t, m) => t + m);
    if (s.affectations.values.any((m) => m <= 0)) throw const Failure.rule(RuleCodes.amountInvalid);
    if (total > s.montant) throw const Failure.rule(RuleCodes.allocationAbovePayment);
    for (final MapEntry(key: id, value: part) in s.affectations.entries) {
      final e = etat.engagements.where((x) => x.id == id).firstOrNull;
      if (e == null) throw const Failure.rule('ENGAGEMENT_INTROUVABLE');
      final suivi = etat.suivi(e);
      if (e.annule) throw const Failure.rule(RuleCodes.commitmentCancelled);
      if (e.sens.sensReglement != s.sens) throw const Failure.rule(RuleCodes.allocationWrongDirection);
      if (s.contactId != null && e.contactId != null && s.contactId != e.contactId) {
        throw const Failure.rule(RuleCodes.allocationOtherContact);
      }
      if (part > suivi.reste) throw Failure.rule(RuleCodes.amountAboveRemaining, {'reste': suivi.reste});
    }

    MouvementCaisse? mouvement;
    if (s.sessionId != null) {
      if (session == null || !session.ouverte) throw const Failure.rule(RuleCodes.cashClosed);
      if (!s.mode.passeParCaisse) throw const Failure.rule(RuleCodes.modeWithoutCash);
      _verifier(_peut(ctx, ModuleCodes.financesCaisse, PermissionCodes.cashMove, session.perimetreId));
      if (s.sens == SensPaiement.sortie && etat.solde(session) < s.montant) {
        throw Failure.rule(RuleCodes.cashInsufficient, {'solde': etat.solde(session)});
      }
    }

    final id = _uuid.v4();
    final p = Paiement(
      id: id,
      entrepriseId: ctx.entreprise!.id,
      activite: _activite(ctx, perimetreId),
      perimetreId: perimetreId,
      sens: s.sens,
      montant: s.montant,
      mode: s.mode,
      datePaiement: date,
      contactId: s.contactId,
      reference: _nul(s.reference),
      note: _nul(s.note),
      sessionId: s.sessionId,
      affectations: [
        for (final MapEntry(key: engagementId, value: montant) in s.affectations.entries)
          Affectation(id: _uuid.v4(), engagementId: engagementId, montant: montant),
      ],
      nature: s.nature,
      syncStatus: RecordSyncStatus.pendingSync,
    );
    if (session != null) mouvement = _mouvementDe(p, session);
    await _repository.enregistrerPaiement(p, mouvement: mouvement);
    return p;
  }
}

class AnnulerPaiement {
  const AnnulerPaiement(this._repository);
  final FinancesRepository _repository;

  /// Paiement inverse : l'original reste visible, barré, avec son annulation.
  Future<Paiement> call(ContexteSession ctx, EtatFinances etat, Paiement origine) async {
    _verifier(_peut(ctx, ModuleCodes.financesPaiements, PermissionCodes.paymentsCancel, origine.perimetreId));
    if (origine.estAnnulation || origine.refuse) throw const Failure.rule('PAIEMENT_ANNULATION_INVALIDE');
    if (etat.estAnnule(origine)) throw const Failure.rule(RuleCodes.paymentAlreadyCancelled);
    // Une jambe de transfert s'annule avec son transfert, jamais seule.
    if (origine.estTransfert) throw const Failure.rule(RuleCodes.transferLinked);

    SessionCaisse? session;
    if (origine.sessionId != null) {
      final caisseId = etat.sessions.where((s) => s.id == origine.sessionId).firstOrNull?.caisseId;
      session = caisseId == null ? null : etat.sessionOuverte(caisseId);
      if (session == null) throw Failure.rule(RuleCodes.cashClosed, {'caisse': caisseId});
      final inverse = origine.sens.inverse;
      if (inverse == SensPaiement.sortie && etat.solde(session) < origine.montant) {
        throw Failure.rule(RuleCodes.cashInsufficient, {'solde': etat.solde(session)});
      }
    }

    final p = Paiement(
      id: _uuid.v4(),
      entrepriseId: origine.entrepriseId,
      activite: origine.activite,
      perimetreId: origine.perimetreId,
      sens: origine.sens.inverse,
      montant: origine.montant,
      mode: origine.mode,
      datePaiement: DateTime.now(),
      contactId: origine.contactId,
      sessionId: session?.id,
      annulePaiementId: origine.id,
      // L'inverse garde la nature de l'original (règle serveur).
      nature: origine.nature,
      syncStatus: RecordSyncStatus.pendingSync,
    );
    await _repository.enregistrerPaiement(p, mouvement: session == null ? null : _mouvementDe(p, session));
    return p;
  }
}

// =============================================================================
// Caisse
// =============================================================================

class GererCaisse {
  const GererCaisse(this._repository);
  final FinancesRepository _repository;

  Future<Caisse> creer(ContexteSession ctx, {required String perimetreId, required String nom}) async {
    _verifier(_peut(ctx, ModuleCodes.financesCaisse, PermissionCodes.entrepriseManage, perimetreId));
    final n = nom.trim();
    if (n.isEmpty || n.length > 80) throw const Failure.rule(RuleCodes.nameInvalid);
    final c = Caisse(
      id: _uuid.v4(),
      entrepriseId: ctx.entreprise!.id,
      perimetreId: perimetreId,
      nom: n,
      syncStatus: RecordSyncStatus.pendingSync,
    );
    await _repository.creerCaisse(c);
    return c;
  }

  Future<SessionCaisse> ouvrir(
    ContexteSession ctx,
    EtatFinances etat,
    Caisse caisse, {
    required int soldeInitial,
  }) async {
    _verifier(_peut(ctx, ModuleCodes.financesCaisse, PermissionCodes.cashOpen, caisse.perimetreId));
    if (!caisse.estActive) throw const Failure.rule(RuleCodes.cashInactive);
    if (etat.sessionOuverte(caisse.id) != null) throw const Failure.rule(RuleCodes.cashAlreadyOpen);
    if (soldeInitial < 0) throw const Failure.rule(RuleCodes.amountInvalid);
    final s = SessionCaisse(
      id: _uuid.v4(),
      entrepriseId: caisse.entrepriseId,
      caisseId: caisse.id,
      perimetreId: caisse.perimetreId,
      ouverte: true,
      soldeInitial: soldeInitial,
      ouverteLe: DateTime.now(),
      syncStatus: RecordSyncStatus.pendingSync,
    );
    await _repository.ouvrirSession(s);
    return s;
  }

  /// Le solde n'est jamais corrigé en silence : un écart entre l'attendu et
  /// le compté reste visible, et doit être justifié (motif + note).
  Future<void> cloturer(
    ContexteSession ctx,
    EtatFinances etat,
    SessionCaisse session, {
    required int soldeReel,
    String? note,
    MotifEcart? motifEcart,
  }) async {
    _verifier(_peut(ctx, ModuleCodes.financesCaisse, PermissionCodes.cashClose, session.perimetreId));
    if (!session.ouverte) throw const Failure.rule(RuleCodes.cashClosed);
    if (soldeReel < 0) throw const Failure.rule(RuleCodes.amountInvalid);
    final ecart = soldeReel - etat.solde(session);
    if (ecart != 0 && _nul(note) == null) {
      throw Failure.rule(RuleCodes.discrepancyJustificationRequired, {'ecart': ecart});
    }
    await _repository.cloturerSession(
      session,
      soldeReel: soldeReel,
      note: _nul(note),
      motifEcart: ecart == 0 ? null : (motifEcart ?? MotifEcart.autre),
    );
  }

  /// Dépôt (apport d'espèces) ou retrait (vers la banque, le coffre…).
  Future<void> mouvement(
    ContexteSession ctx,
    EtatFinances etat,
    SessionCaisse session, {
    required TypeMouvement type,
    required int montant,
    String? motif,
  }) async {
    _verifier(_peut(ctx, ModuleCodes.financesCaisse, PermissionCodes.cashMove, session.perimetreId));
    if (type != TypeMouvement.depot && type != TypeMouvement.retrait) {
      throw const Failure.rule('TYPE_MOUVEMENT_INVALIDE');
    }
    if (!session.ouverte) throw const Failure.rule(RuleCodes.cashClosed);
    if (montant <= 0) throw const Failure.rule(RuleCodes.amountInvalid);
    if (type == TypeMouvement.retrait && etat.solde(session) < montant) {
      throw Failure.rule(RuleCodes.cashInsufficient, {'solde': etat.solde(session)});
    }
    await _repository.mouvementManuel(
      MouvementCaisse(
        id: _uuid.v4(),
        sessionId: session.id,
        caisseId: session.caisseId,
        type: type,
        montant: montant,
        motif: _nul(motif),
        createdAt: DateTime.now(),
        syncStatus: RecordSyncStatus.pendingSync,
      ),
      entrepriseId: session.entrepriseId,
    );
  }
}

/// Une écriture refusée par le serveur n'a jamais eu lieu : l'utilisateur la
/// retire de l'appareil après avoir lu le motif.
class RetirerEcritureRefusee {
  const RetirerEcritureRefusee(this._repository);
  final FinancesRepository _repository;

  Future<void> call(String table, String id) => _repository.retirerRefuse(table, id);
}

// =============================================================================

AccessDecision _peut(ContexteSession ctx, String module, String permission, [String? perimetreId]) =>
    ctx.accessPolicy().canPerform(moduleCode: module, permission: permission, perimetreId: perimetreId);

void _verifier(AccessDecision decision) {
  if (decision case AccessDenied()) throw decision.toFailure();
}

String _valider(String libelle, int montant) {
  final l = libelle.trim();
  if (l.isEmpty || l.length > 200) throw const Failure.rule(RuleCodes.labelInvalid);
  if (montant <= 0) throw const Failure.rule(RuleCodes.amountInvalid);
  return l;
}

ActiviteCode? _activite(ContexteSession ctx, String? perimetreId) =>
    perimetreId == null ? null : ctx.perimetres.where((p) => p.id == perimetreId).firstOrNull?.activite;

DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

String? _nul(String? v) {
  final t = v?.trim();
  return t == null || t.isEmpty ? null : t;
}

MouvementCaisse _mouvementDe(Paiement p, SessionCaisse session) => MouvementCaisse(
  // Même identifiant que celui que créera le serveur.
  id: p.id,
  sessionId: session.id,
  caisseId: session.caisseId,
  type: p.sens == SensPaiement.entree ? TypeMouvement.encaissement : TypeMouvement.decaissement,
  montant: p.montant,
  paiementId: p.id,
  createdAt: DateTime.now(),
);
