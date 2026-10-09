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
import 'gerer_finances.dart';

const _uuid = Uuid();

/// Opérations propres à la Caisse. Tout reste un PAIEMENT (pas de second
/// système) : les ventes, dettes, achats et dépenses alimentent la caisse
/// d'eux-mêmes ; ici, seulement ce qui n'a pas d'autre source.
class GererOperationsCaisse {
  const GererOperationsCaisse(this._repository, this._enregistrer);
  final FinancesRepository _repository;
  final EnregistrerPaiement _enregistrer;

  /// Entrée ou sortie sans somme due : apport, retrait, remboursement, autre…
  /// En espèces, elle passe par la caisse ouverte de la boutique.
  Future<Paiement> ajouter(
    ContexteSession ctx,
    EtatFinances etat, {
    required SensPaiement sens,
    required NaturePaiement nature,
    required int montant,
    required ModePaiement mode,
    required String motif,
    String? perimetreId,
    DateTime? date,
    String? contactId,
  }) {
    final m = motif.trim();
    if (m.isEmpty) throw const Failure.rule(RuleCodes.reasonRequired);
    if (m.length > 500) throw const Failure.rule(RuleCodes.labelInvalid);
    return _enregistrer(
      ctx,
      etat,
      SaisiePaiement(
        sens: sens,
        montant: montant,
        mode: mode,
        date: date,
        contactId: contactId,
        note: m,
        perimetreId: perimetreId,
        sessionId: sessionPour(etat, mode, perimetreId)?.id,
        nature: nature,
      ),
    );
  }

  /// Transfert boutique → boutique et/ou moyen → moyen (espèces → banque…).
  /// Une seule opération envoyée : le serveur crée les deux jambes ensemble,
  /// jamais comptées comme entrée ou sortie ; le total ne change pas.
  Future<TransfertTresorerie> transferer(
    ContexteSession ctx,
    EtatFinances etat, {
    required int montant,
    required ModePaiement modeSource,
    required ModePaiement modeDest,
    String? perimetreSourceId,
    String? perimetreDestId,
    String? motif,
  }) async {
    _verifier(_peut(ctx, PermissionCodes.cashTransfer, perimetreSourceId));
    _verifier(_peut(ctx, PermissionCodes.cashTransfer, perimetreDestId));
    if (montant <= 0) throw const Failure.rule(RuleCodes.amountInvalid);
    if (perimetreSourceId == perimetreDestId && modeSource == modeDest) {
      throw const Failure.rule(RuleCodes.transferSame);
    }
    final source = sessionPour(etat, modeSource, perimetreSourceId);
    final dest = sessionPour(etat, modeDest, perimetreDestId);
    if (source != null && etat.solde(source) < montant) {
      throw Failure.rule(RuleCodes.cashInsufficient, {'solde': etat.solde(source)});
    }

    final t = TransfertTresorerie(
      id: _uuid.v4(),
      entrepriseId: ctx.entreprise!.id,
      perimetreSourceId: perimetreSourceId,
      perimetreDestId: perimetreDestId,
      modeSource: modeSource,
      modeDest: modeDest,
      montant: montant,
      sessionSourceId: source?.id,
      sessionDestId: dest?.id,
      sortieId: _uuid.v4(),
      entreeId: _uuid.v4(),
      dateTransfert: DateTime.now(),
      motif: _nul(motif),
      syncStatus: RecordSyncStatus.pendingSync,
    );
    Paiement jambe(String id, SensPaiement sens, String? site, ModePaiement mode, SessionCaisse? s) => Paiement(
      id: id,
      entrepriseId: t.entrepriseId,
      activite: _activite(ctx, site),
      perimetreId: site,
      sens: sens,
      montant: montant,
      mode: mode,
      datePaiement: t.dateTransfert,
      note: t.motif ?? 'Transfert',
      sessionId: s?.id,
      nature: NaturePaiement.transfert,
      transfertId: t.id,
      syncStatus: RecordSyncStatus.pendingSync,
    );
    final sortie = jambe(t.sortieId, SensPaiement.sortie, perimetreSourceId, modeSource, source);
    final entree = jambe(t.entreeId, SensPaiement.entree, perimetreDestId, modeDest, dest);
    await _repository.enregistrerTransfert(
      t,
      jambes: [
        (sortie, source == null ? null : _mouvement(sortie, source)),
        (entree, dest == null ? null : _mouvement(entree, dest)),
      ],
    );
    return t;
  }

  /// Annule un transfert d'un bloc (motif obligatoire) : deux paiements
  /// inverses, les originaux restent visibles.
  Future<void> annulerTransfert(
    ContexteSession ctx,
    EtatFinances etat,
    TransfertTresorerie t, {
    required String motif,
  }) async {
    _verifier(_peut(ctx, PermissionCodes.cashTransfer, t.perimetreSourceId));
    _verifier(_peut(ctx, PermissionCodes.cashTransfer, t.perimetreDestId));
    if (t.annule) throw const Failure.rule(RuleCodes.transferCancelled);
    final m = _nul(motif) ?? (throw const Failure.rule(RuleCodes.reasonRequired));

    // Espèces : l'inverse va dans la session ouverte de la même caisse.
    SessionCaisse? ouverte(String? sessionId) {
      if (sessionId == null) return null;
      final caisseId = etat.sessions.where((s) => s.id == sessionId).firstOrNull?.caisseId;
      final s = caisseId == null ? null : etat.sessionOuverte(caisseId);
      if (s == null) throw Failure.rule(RuleCodes.cashClosed, {'caisse': caisseId});
      return s;
    }

    final caisseDest = ouverte(t.sessionDestId);
    final caisseSource = ouverte(t.sessionSourceId);
    if (caisseDest != null && etat.solde(caisseDest) < t.montant) {
      throw Failure.rule(RuleCodes.cashInsufficient, {'solde': etat.solde(caisseDest)});
    }

    final apres = t.annulation(motif: m, sortieId: _uuid.v4(), entreeId: _uuid.v4());
    Paiement inverse(
      String id,
      String origineId,
      SensPaiement sens,
      String? site,
      ModePaiement mode,
      SessionCaisse? s,
    ) => Paiement(
      id: id,
      entrepriseId: t.entrepriseId,
      activite: _activite(ctx, site),
      perimetreId: site,
      sens: sens,
      montant: t.montant,
      mode: mode,
      datePaiement: DateTime.now(),
      sessionId: s?.id,
      annulePaiementId: origineId,
      nature: NaturePaiement.transfert,
      transfertId: t.id,
      syncStatus: RecordSyncStatus.pendingSync,
    );
    // Entrée reprise d'abord, puis sortie rendue (même ordre que le serveur).
    final repriseEntree = inverse(
      apres.annulationEntreeId!,
      t.entreeId,
      SensPaiement.sortie,
      t.perimetreDestId,
      t.modeDest,
      caisseDest,
    );
    final retourSortie = inverse(
      apres.annulationSortieId!,
      t.sortieId,
      SensPaiement.entree,
      t.perimetreSourceId,
      t.modeSource,
      caisseSource,
    );
    await _repository.annulerTransfert(
      t,
      apres,
      jambes: [
        (repriseEntree, caisseDest == null ? null : _mouvement(repriseEntree, caisseDest)),
        (retourSortie, caisseSource == null ? null : _mouvement(retourSortie, caisseSource)),
      ],
    );
  }

  /// Solde de départ d'un moyen d'argent (Mobile Money, banque…) ou correction
  /// exceptionnelle : droit propre, motif obligatoire, jamais un solde écrasé.
  Future<Paiement> corriger(
    ContexteSession ctx,
    EtatFinances etat, {
    required NaturePaiement nature,
    required SensPaiement sens,
    required int montant,
    required ModePaiement mode,
    required String motif,
    String? perimetreId,
  }) {
    if (!nature.estCorrection) throw const Failure.rule(RuleCodes.natureIncompatible);
    return ajouter(
      ctx,
      etat,
      sens: sens,
      nature: nature,
      montant: montant,
      mode: mode,
      motif: motif,
      perimetreId: perimetreId,
    );
  }

  /// Caisse ouverte de la boutique pour un paiement en espèces.
  static SessionCaisse? sessionPour(EtatFinances etat, ModePaiement mode, String? perimetreId) {
    if (!mode.passeParCaisse || perimetreId == null) return null;
    for (final c in etat.caisses.where((c) => c.perimetreId == perimetreId && c.estActive)) {
      final s = etat.sessionOuverte(c.id);
      if (s != null) return s;
    }
    return null;
  }

  static MouvementCaisse _mouvement(Paiement p, SessionCaisse s) => MouvementCaisse(
    id: p.id,
    sessionId: s.id,
    caisseId: s.caisseId,
    type: p.sens == SensPaiement.entree ? TypeMouvement.encaissement : TypeMouvement.decaissement,
    montant: p.montant,
    paiementId: p.id,
    createdAt: p.datePaiement,
  );

  static AccessDecision _peut(ContexteSession ctx, String permission, String? perimetreId) => ctx
      .accessPolicy()
      .canPerform(moduleCode: ModuleCodes.financesCaisse, permission: permission, perimetreId: perimetreId);

  static void _verifier(AccessDecision decision) {
    if (decision case AccessDenied()) throw decision.toFailure();
  }

  static ActiviteCode? _activite(ContexteSession ctx, String? perimetreId) =>
      perimetreId == null ? null : ctx.perimetres.where((p) => p.id == perimetreId).firstOrNull?.activite;

  static String? _nul(String? v) {
    final t = v?.trim();
    return t == null || t.isEmpty ? null : t;
  }
}
