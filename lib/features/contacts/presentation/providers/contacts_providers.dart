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

/// Statistiques globales du carnet d'adresses pour les filtres et le compteur.
class StatsCarnetContacts {
  const StatsCarnetContacts({
    this.total = 0,
    this.clients = 0,
    this.fournisseurs = 0,
    this.locataires = 0,
    this.proprietaires = 0,
    this.prestataires = 0,
    this.archives = 0,
  });

  final int total;
  final int clients;
  final int fournisseurs;
  final int locataires;
  final int proprietaires;
  final int prestataires;
  final int archives;

  int countFor(RelationContact? relation) => switch (relation) {
        null => total,
        RelationContact.client => clients,
        RelationContact.fournisseur => fournisseurs,
        RelationContact.locataire => locataires,
        RelationContact.proprietaire => proprietaires,
        RelationContact.prestataire => prestataires,
      };
}

final statsCarnetContactsProvider = StreamProvider.autoDispose<StatsCarnetContacts>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null) return Stream.value(const StatsCarnetContacts());
  return ref.watch(observerContactsProvider).call(ctx, const FiltreContacts(inclureArchives: true)).map((liste) {
    var total = 0, clients = 0, fournisseurs = 0, locataires = 0, proprietaires = 0, prestataires = 0, archives = 0;
    for (final c in liste) {
      if (c.estArchive) {
        archives++;
      } else {
        total++;
        if (c.relations.contains(RelationContact.client)) clients++;
        if (c.relations.contains(RelationContact.fournisseur)) fournisseurs++;
        if (c.relations.contains(RelationContact.locataire)) locataires++;
        if (c.relations.contains(RelationContact.proprietaire)) proprietaires++;
        if (c.relations.contains(RelationContact.prestataire)) prestataires++;
      }
    }
    return StatsCarnetContacts(
      total: total,
      clients: clients,
      fournisseurs: fournisseurs,
      locataires: locataires,
      proprietaires: proprietaires,
      prestataires: prestataires,
      archives: archives,
    );
  });
});

