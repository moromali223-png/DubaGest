import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/di/sync_providers.dart';
import '../../agenda/domain/entities/agenda.dart';
import '../../authentication/presentation/providers/auth_providers.dart';
import '../../entreprise/presentation/providers/contexte_providers.dart';
import '../data/fichiers_repository_impl.dart';
import '../domain/fichiers.dart';

final fichiersLocalDataSourceProvider = Provider((ref) => FichiersLocalDataSource(ref.watch(appDatabaseProvider)));

final fichiersSyncHandlersProvider = Provider(
  (ref) => fichiersSyncHandlers(ref.watch(fichiersLocalDataSourceProvider), ref.watch(syncCursorStoreProvider)),
);

final fichiersRepositoryProvider = Provider<FichiersRepository>((ref) => FichiersRepositoryImpl(
      local: ref.watch(fichiersLocalDataSourceProvider),
      queue: ref.watch(syncQueueStoreProvider),
      client: () => ref.read(supabaseClientProvider),
      currentUserId: () => ref.read(currentUserIdProvider),
      requestSync: ref.watch(syncTriggerProvider),
    ));

final gererFichiersProvider = Provider((ref) => GererFichiers(ref.watch(fichiersRepositoryProvider)));

typedef Fiche = ({CibleType type, String id});

final droitsFicheProvider = Provider.autoDispose.family<DroitsFiche, CibleType>((ref, type) {
  final ctx = ref.watch(contexteActifProvider);
  return ctx == null ? const DroitsFiche() : DroitsFiche.de(ctx, type);
});

final notesFicheProvider = StreamProvider.autoDispose.family<List<Note>, Fiche>(
  (ref, f) => ref.watch(fichiersRepositoryProvider).notes(f.type, f.id),
);

final piecesFicheProvider = StreamProvider.autoDispose.family<List<PieceJointe>, Fiche>(
  (ref, f) => ref.watch(fichiersRepositoryProvider).pieces(f.type, f.id),
);
