import '../../../../core/permissions/access_decision.dart';
import '../../../entreprise/domain/entities/contexte_session.dart';
import '../entities/entree_audit.dart';
import '../repositories/audit_repository.dart';

class ConsulterJournal {
  const ConsulterJournal(this._repository);
  final AuditRepository _repository;

  static const permission = 'audit.view';

  Future<List<EntreeAudit>> call(
    ContexteSession ctx, {
    int? avantId,
    String? entiteType,
    String? entiteId,
  }) {
    final decision = ctx.permissionEngine.check(permission);
    if (decision case AccessDenied()) throw decision.toFailure();
    return _repository.lister(
      ctx.entreprise!.id,
      avantId: avantId,
      entiteType: entiteType,
      entiteId: entiteId,
    );
  }
}
