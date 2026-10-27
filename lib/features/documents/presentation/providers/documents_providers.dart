import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/core_providers.dart';
import '../../../../core/di/sync_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../data/document_repository_impl.dart';
import '../../domain/entities/document.dart';
import '../../domain/repositories/document_repository.dart';
import '../../domain/usecases/gerer_documents.dart';

/// Identifiant de cette installation : les blocs de numéros lui sont réservés.
final appareilIdProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  const cle = 'appareil_id';
  final existant = prefs.getString(cle);
  if (existant != null) return existant;
  final id = const Uuid().v4();
  prefs.setString(cle, id);
  return id;
});

final documentLocalDataSourceProvider = Provider((ref) => DocumentLocalDataSource(ref.watch(appDatabaseProvider)));

final documentsSyncHandlerProvider = Provider(
  (ref) => documentsSyncHandler(ref.watch(documentLocalDataSourceProvider), ref.watch(syncCursorStoreProvider)),
);

final documentRepositoryProvider = Provider<DocumentRepository>((ref) => DocumentRepositoryImpl(
      local: ref.watch(documentLocalDataSourceProvider),
      queue: ref.watch(syncQueueStoreProvider),
      client: () => ref.read(supabaseClientProvider),
      requestSync: ref.watch(syncTriggerProvider),
    ));

final emettreRecuProvider = Provider((ref) => EmettreRecu(ref.watch(documentRepositoryProvider)));
final emettreDocumentProvider = Provider((ref) => EmettreDocument(ref.watch(documentRepositoryProvider)));
final assurerNumerosProvider = Provider((ref) => AssurerNumeros(ref.watch(documentRepositoryProvider)));
final retirerDocumentProvider = Provider((ref) => RetirerDocumentRefuse(ref.watch(documentRepositoryProvider)));

final droitsDocumentsProvider = Provider<DroitsDocuments>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  return ctx == null ? const DroitsDocuments() : DroitsDocuments.de(ctx);
});

final documentsProvider = StreamProvider.autoDispose<List<Document>>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null || !DroitsDocuments.de(ctx).voir) return Stream.value(const []);
  return ref.watch(documentRepositoryProvider).watch(ctx.entreprise!.id);
});
