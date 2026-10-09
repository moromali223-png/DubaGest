import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/core_providers.dart';
import '../../../../core/di/sync_providers.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../data/datasources/contact_local_data_source.dart';
import '../../data/repositories/contact_repository_impl.dart';
import '../../domain/entities/contact.dart';
import '../../domain/repositories/contact_repository.dart';
import '../../domain/usecases/gerer_contacts.dart';

final contactLocalDataSourceProvider =
    Provider((ref) => ContactLocalDataSource(ref.watch(appDatabaseProvider)));

final contactsSyncHandlerProvider = Provider((ref) => ContactsSyncHandler(
      ref.watch(contactLocalDataSourceProvider),
      ref.watch(syncCursorStoreProvider),
    ));

final contactRepositoryProvider = Provider<ContactRepository>((ref) => ContactRepositoryImpl(
      local: ref.watch(contactLocalDataSourceProvider),
      queue: ref.watch(syncQueueStoreProvider),
      currentUserId: () => ref.read(currentUserIdProvider),
      requestSync: ref.watch(syncTriggerProvider),
    ));

final observerContactsProvider = Provider((ref) => ObserverContacts(ref.watch(contactRepositoryProvider)));
final detecterDoublonsProvider = Provider((ref) => DetecterDoublons(ref.watch(contactRepositoryProvider)));
final creerContactProvider = Provider((ref) => CreerContact(ref.watch(contactRepositoryProvider)));
final modifierContactProvider = Provider((ref) => ModifierContact(ref.watch(contactRepositoryProvider)));
final archiverContactProvider = Provider((ref) => ArchiverContact(ref.watch(contactRepositoryProvider)));

/// Droits de l'utilisateur courant sur les contacts (boutons affichés ou non).
final droitsContactsProvider = Provider<DroitsContacts>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  return ctx == null
      ? const DroitsContacts(voir: false, creer: false, modifier: false, archiver: false)
      : DroitsContacts.de(ctx);
});

/// Recherche et filtres de la liste (conservés pendant la navigation).
class FiltreContactsNotifier extends Notifier<FiltreContacts> {
  @override
  FiltreContacts build() => const FiltreContacts();

  void rechercher(String texte) => state = state.copyWith(recherche: texte);
  void relation(RelationContact? relation) => state = state.copyWith(relation: () => relation);
  void archives(bool inclure) => state = state.copyWith(inclureArchives: inclure);
}

final filtreContactsProvider = NotifierProvider<FiltreContactsNotifier, FiltreContacts>(FiltreContactsNotifier.new);

/// Liste locale filtrée (hors-ligne), réactive aux écritures et à la sync.
final contactsProvider = StreamProvider.autoDispose<List<Contact>>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null) return const Stream.empty();
  return ref.watch(observerContactsProvider).call(ctx, ref.watch(filtreContactsProvider));
});

final contactProvider = StreamProvider.autoDispose.family<Contact?, String>((ref, id) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null) return const Stream.empty();
  return ref.watch(observerContactsProvider).un(ctx, id);
});
