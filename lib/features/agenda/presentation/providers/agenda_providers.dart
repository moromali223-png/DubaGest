import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/core_providers.dart';
import '../../../../core/di/sync_providers.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../finances/presentation/providers/finances_providers.dart';
import '../../../utilisateurs/domain/entities/membre.dart';
import '../../../utilisateurs/presentation/providers/membres_providers.dart';
import '../../data/agenda_repository_impl.dart';
import '../../domain/entities/agenda.dart';
import '../../domain/repositories/agenda_repository.dart';
import '../../domain/services/agenda_service.dart';
import '../../domain/usecases/gerer_agenda.dart';

final agendaLocalDataSourceProvider = Provider((ref) => AgendaLocalDataSource(ref.watch(appDatabaseProvider)));

final agendaSyncHandlersProvider = Provider(
  (ref) => agendaSyncHandlers(ref.watch(agendaLocalDataSourceProvider), ref.watch(syncCursorStoreProvider)),
);

final agendaRepositoryProvider = Provider<AgendaRepository>((ref) => AgendaRepositoryImpl(
      local: ref.watch(agendaLocalDataSourceProvider),
      queue: ref.watch(syncQueueStoreProvider),
      currentUserId: () => ref.read(currentUserIdProvider),
      requestSync: ref.watch(syncTriggerProvider),
    ));

final gererEcheancesProvider = Provider((ref) => GererEcheances(ref.watch(agendaRepositoryProvider)));

final droitsAgendaProvider = Provider<DroitsAgenda>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  return ctx == null ? const DroitsAgenda() : DroitsAgenda.de(ctx);
});

final echeancesProvider = StreamProvider.autoDispose<List<Echeance>>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null || !DroitsAgenda.de(ctx).voir) return Stream.value(const []);
  return ref.watch(agendaRepositoryProvider).watchEcheances(ctx.entreprise!.id);
});

final notificationsProvider = StreamProvider.autoDispose<List<NotificationApp>>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null) return Stream.value(const []);
  return ref.watch(agendaRepositoryProvider).watchNotifications(ctx.entreprise!.id, ctx.userId);
});

/// Filtre « mes tâches » de l'agenda.
class MesTachesNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void basculer() => state = !state;
}

final mesTachesProvider = NotifierProvider<MesTachesNotifier, bool>(MesTachesNotifier.new);

/// Agenda : échéances saisies + échéances des sommes dues (si l'utilisateur
/// voit les créances).
final agendaProvider = Provider.autoDispose<AsyncValue<Agenda>>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  final echeances = ref.watch(echeancesProvider);
  final voirCreances = ref.watch(droitsFinancesProvider).voirCreances;
  final finances = voirCreances ? ref.watch(etatFinancesProvider).value : null;
  return echeances.whenData((list) => AgendaService.construire(
        echeances: list,
        maintenant: DateTime.now(),
        userId: ctx?.userId ?? '',
        finances: finances,
        mesTaches: ref.watch(mesTachesProvider),
      ));
});

/// Alertes calculées à partir des vraies données de l'utilisateur.
final alertesProvider = Provider.autoDispose<List<Alerte>>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null) return const [];
  final droits = ref.watch(droitsFinancesProvider);
  final voitFinances = droits.voirCreances || droits.voirCaisse || droits.voirPaiements;
  return AgendaService.alertes(
    echeances: ref.watch(echeancesProvider).value ?? const [],
    maintenant: DateTime.now(),
    userId: ctx.userId,
    finances: voitFinances ? ref.watch(etatFinancesProvider).value : null,
    voirCreances: droits.voirCreances,
    voirCaisse: droits.voirCaisse,
  );
});

/// Badge de la cloche : notifications non lues + alertes en cours.
final compteurNotificationsProvider = Provider.autoDispose<int>((ref) {
  final nonLues = (ref.watch(notificationsProvider).value ?? const []).where((n) => !n.lue).length;
  return nonLues + ref.watch(alertesProvider).length;
});

/// Membres à qui confier une tâche (lisibles par tout membre de l'entreprise).
final membresAssignablesProvider = FutureProvider.autoDispose<List<Membre>>((ref) async {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null) return const [];
  try {
    final membres = await ref.watch(membreRepositoryProvider).lister(ctx.entreprise!.id);
    return membres.where((m) => m.statut == MembreStatut.actif).toList();
  } catch (_) {
    return const [];
  }
});
