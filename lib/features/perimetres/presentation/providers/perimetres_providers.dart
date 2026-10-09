import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/core_providers.dart';
import '../../../../core/di/sync_providers.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../data/datasources/perimetre_local_data_source.dart';
import '../../data/repositories/perimetre_repository_impl.dart';
import '../../data/repositories/perimetres_sync_handler.dart';
import '../../domain/entities/perimetre.dart';
import '../../domain/repositories/perimetre_repository.dart';
import '../../domain/usecases/gerer_perimetres.dart';

final perimetreLocalDataSourceProvider =
    Provider((ref) => PerimetreLocalDataSource(ref.watch(appDatabaseProvider)));

final perimetresSyncHandlerProvider = Provider((ref) => PerimetresSyncHandler(
      ref.watch(perimetreLocalDataSourceProvider),
      ref.watch(syncCursorStoreProvider),
    ));

final perimetreRepositoryProvider = Provider<PerimetreRepository>((ref) => PerimetreRepositoryImpl(
      local: ref.watch(perimetreLocalDataSourceProvider),
      queue: ref.watch(syncQueueStoreProvider),
      transaction: ref.watch(localTransactionProvider),
      currentUserId: () => ref.read(currentUserIdProvider),
      requestSync: ref.watch(syncTriggerProvider),
    ));

final observerPerimetresProvider =
    Provider((ref) => ObserverPerimetres(ref.watch(perimetreRepositoryProvider)));
final creerPerimetreProvider = Provider((ref) => CreerPerimetre(ref.watch(perimetreRepositoryProvider)));
final modifierPerimetreProvider =
    Provider((ref) => ModifierPerimetre(ref.watch(perimetreRepositoryProvider)));
final supprimerPerimetreProvider =
    Provider((ref) => SupprimerPerimetre(ref.watch(perimetreRepositoryProvider)));

/// Liste locale (fonctionne hors-ligne), réactive aux écritures et à la sync.
final perimetresProvider = StreamProvider.autoDispose<List<Perimetre>>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null) return const Stream.empty();
  return ref.watch(observerPerimetresProvider).call(ctx);
});
