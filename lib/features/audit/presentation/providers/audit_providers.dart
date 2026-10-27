import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/core_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../data/repositories/audit_repository_impl.dart';
import '../../domain/entities/entree_audit.dart';
import '../../domain/repositories/audit_repository.dart';
import '../../domain/usecases/consulter_journal.dart';

final auditRepositoryProvider =
    Provider<AuditRepository>((ref) => AuditRepositoryImpl(ref.watch(supabaseClientProvider)));

final consulterJournalProvider = Provider((ref) => ConsulterJournal(ref.watch(auditRepositoryProvider)));

final journalProvider = FutureProvider.autoDispose<List<EntreeAudit>>((ref) async {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null) return const [];
  return ref.watch(consulterJournalProvider).call(ctx);
});

final historiqueEntiteProvider = FutureProvider.autoDispose.family<List<EntreeAudit>, (String type, String id)>((ref, arg) async {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null) return const [];
  return ref.watch(consulterJournalProvider).call(ctx, entiteType: arg.$1, entiteId: arg.$2);
});
