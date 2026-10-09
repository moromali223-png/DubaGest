import 'package:uuid/uuid.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/permissions/access_decision.dart';
import '../../../../core/permissions/permission_codes.dart';
import '../../../../core/sync/sync_models.dart';
import '../../../entreprise/domain/entities/contexte_session.dart';
import '../../../modules/domain/entities/app_module.dart';
import '../entities/agenda.dart';
import '../repositories/agenda_repository.dart';

const _uuid = Uuid();

class DroitsAgenda {
  const DroitsAgenda({this.voir = false, this.gerer = false});

  factory DroitsAgenda.de(ContexteSession ctx) {
    bool peut(String p) =>
        ctx.accessPolicy().canPerform(moduleCode: ModuleCodes.communAgenda, permission: p).isAllowed;
    return DroitsAgenda(voir: peut(PermissionCodes.agendaView), gerer: peut(PermissionCodes.agendaManage));
  }

  final bool voir;

  /// Créer, modifier, confier ; sans ce droit, on marque seulement « fait »
  /// les tâches qui nous sont confiées.
  final bool gerer;
}

class SaisieEcheance {
  const SaisieEcheance({
    required this.type,
    required this.titre,
    required this.dateHeure,
    this.note,
    this.rappelMinutes,
    this.responsableId,
    this.responsableNom,
    this.cibleType,
    this.cibleId,
  });

  final TypeEcheance type;
  final String titre;
  final DateTime dateHeure;
  final String? note;
  final int? rappelMinutes;
  final String? responsableId;
  final String? responsableNom;
  final CibleType? cibleType;
  final String? cibleId;
}

class GererEcheances {
  const GererEcheances(this._repository);
  final AgendaRepository _repository;

  Future<Echeance> creer(ContexteSession ctx, SaisieEcheance s) async {
    _verifier(_peut(ctx, PermissionCodes.agendaManage));
    final e = Echeance(
      id: _uuid.v4(),
      entrepriseId: ctx.entreprise!.id,
      type: s.type,
      titre: _titre(s.titre),
      note: _nul(s.note),
      dateHeure: s.dateHeure,
      rappelMinutes: s.rappelMinutes,
      responsableId: s.responsableId,
      responsableNom: s.responsableNom,
      cibleType: s.cibleId == null ? null : s.cibleType,
      cibleId: s.cibleType == null ? null : s.cibleId,
      createdBy: ctx.userId,
      syncStatus: RecordSyncStatus.pendingSync,
    );
    await _repository.creer(e);
    return e;
  }

  Future<void> modifier(ContexteSession ctx, Echeance e, SaisieEcheance s) async {
    _verifier(_peut(ctx, PermissionCodes.agendaManage));
    await _repository.modifier(
      e,
      e.copyWith(
        type: s.type,
        titre: _titre(s.titre),
        note: () => _nul(s.note),
        dateHeure: s.dateHeure,
        rappelMinutes: () => s.rappelMinutes,
        responsableId: () => s.responsableId,
        responsableNom: () => s.responsableNom,
      ),
    );
  }

  /// Fait / à refaire / annulé. Le responsable d'une tâche peut la marquer
  /// faite même sans le droit de gérer l'agenda (règle serveur identique).
  Future<void> changerStatut(ContexteSession ctx, Echeance e, StatutEcheance statut) async {
    final gerer = _peut(ctx, PermissionCodes.agendaManage).isAllowed;
    final responsable = e.responsableId == ctx.userId && statut != StatutEcheance.annule;
    if (!gerer && !responsable) _verifier(_peut(ctx, PermissionCodes.agendaManage));
    if (e.statut == statut) return;
    await _repository.modifier(e, e.copyWith(statut: statut));
  }

  Future<void> marquerLue(NotificationApp n) async {
    if (n.lue) return;
    await _repository.marquerLue(n);
  }

  Future<void> retirerRefusee(String id) => _repository.retirerRefusee(id);
}

AccessDecision _peut(ContexteSession ctx, String permission) =>
    ctx.accessPolicy().canPerform(moduleCode: ModuleCodes.communAgenda, permission: permission);

void _verifier(AccessDecision d) {
  if (d case AccessDenied()) throw d.toFailure();
}

String _titre(String t) {
  final v = t.trim();
  if (v.isEmpty || v.length > 200) throw const Failure.rule(RuleCodes.labelInvalid);
  return v;
}

String? _nul(String? v) {
  final t = v?.trim();
  return t == null || t.isEmpty ? null : t;
}
