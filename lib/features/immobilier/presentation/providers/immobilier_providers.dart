import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/di/core_providers.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../../core/sync/sync_contracts.dart';
import '../../data/datasources/immobilier_local_data_source.dart';
import '../../data/datasources/immobilier_remote_data_source.dart';
import '../../data/datasources/immobilier_sync_handlers.dart';
import '../../data/repositories/immobilier_repository_impl.dart';
import '../../domain/entities/bien_immobilier.dart';
import '../../domain/entities/contrat_bail.dart';
import '../../domain/entities/dashboard_immobilier.dart';
import '../../domain/entities/echeance_loyer.dart';
import '../../domain/entities/locataire_immobilier.dart';
import '../../domain/entities/location_immobilier.dart';
import '../../domain/repositories/immobilier_repository.dart';
import '../../domain/entities/resultat_encaissement_loyer.dart';
import '../../../finances/domain/entities/finances.dart';
import '../../../finances/presentation/providers/finances_providers.dart';
import '../../../documents/domain/entities/document.dart';
import '../../../documents/presentation/providers/documents_providers.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/permissions/access_decision.dart';
import '../../../../core/sync/sync_models.dart';
import 'package:uuid/uuid.dart';

// --- DATA SOURCES & REPOSITORY ---

final immobilierLocalDataSourceProvider = Provider<ImmobilierLocalDataSource>((ref) {
  return ImmobilierLocalDataSource(ref.watch(appDatabaseProvider));
});

final immobilierRemoteDataSourceProvider = Provider<ImmobilierRemoteDataSource>((ref) {
  return ImmobilierRemoteDataSource(ref.watch(supabaseClientProvider));
});

final immobilierRepositoryProvider = Provider<ImmobilierRepository>((ref) {
  return ImmobilierRepositoryImpl(
    remote: ref.watch(immobilierRemoteDataSourceProvider),
    local: ref.watch(immobilierLocalDataSourceProvider),
  );
});

final immobilierSyncHandlersProvider = Provider<List<SyncEntityHandler>>((ref) {
  return immobilierSyncHandlers(
    ref.watch(immobilierLocalDataSourceProvider),
    ref.watch(syncCursorStoreProvider),
  );
});

// --- FLUX DE DONNÉES BIENS ---

final biensListProvider = StreamProvider.autoDispose<List<BienImmobilier>>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null || ctx.entreprise == null) return Stream.value(const <BienImmobilier>[]);
  return ref.watch(immobilierRepositoryProvider).observerBiens(ctx.entreprise!.id);
});

final bienDetailsProvider = FutureProvider.autoDispose.family<BienImmobilier?, String>((ref, id) {
  return ref.watch(immobilierRepositoryProvider).getBien(id);
});

final biensParProprietaireProvider =
    StreamProvider.autoDispose.family<List<BienImmobilier>, String>((ref, proprietaireId) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null || ctx.entreprise == null) return const Stream.empty();
  return ref.watch(immobilierRepositoryProvider).observerBiensParProprietaire(
        ctx.entreprise!.id,
        proprietaireId,
      );
});

// --- FILTRAGE ET RECHERCHE BIENS ---

class FiltreBiens {
  const FiltreBiens({
    this.recherche = '',
    this.statut,
    this.type,
  });

  final String recherche;
  final StatutBien? statut;
  final TypeBien? type;

  FiltreBiens copyWith({
    String? recherche,
    StatutBien? Function()? statut,
    TypeBien? Function()? type,
  }) {
    return FiltreBiens(
      recherche: recherche ?? this.recherche,
      statut: statut != null ? statut() : this.statut,
      type: type != null ? type() : this.type,
    );
  }
}

class FiltreBiensNotifier extends Notifier<FiltreBiens> {
  @override
  FiltreBiens build() => const FiltreBiens();

  void rechercher(String query) => state = state.copyWith(recherche: query);
  void changerStatut(StatutBien? statut) => state = state.copyWith(statut: () => statut);
  void changerType(TypeBien? type) => state = state.copyWith(type: () => type);
}

final filtreBiensProvider =
    NotifierProvider<FiltreBiensNotifier, FiltreBiens>(FiltreBiensNotifier.new);

final biensFiltresProvider = Provider.autoDispose<List<BienImmobilier>>((ref) {
  final biensAsync = ref.watch(biensListProvider);
  final biens = biensAsync.value ?? const [];
  final filtre = ref.watch(filtreBiensProvider);
  final recherche = filtre.recherche.trim().toLowerCase();

  return biens.where((b) {
    if (filtre.statut != null && b.statut != filtre.statut) return false;
    if (filtre.type != null && b.type != filtre.type) return false;
    if (recherche.isNotEmpty) {
      final matchesNom = b.nom.toLowerCase().contains(recherche);
      final matchesRef = b.reference.toLowerCase().contains(recherche);
      final matchesVille = (b.ville ?? '').toLowerCase().contains(recherche);
      final matchesQuartier = (b.quartier ?? '').toLowerCase().contains(recherche);
      if (!matchesNom && !matchesRef && !matchesVille && !matchesQuartier) {
        return false;
      }
    }
    return true;
  }).toList();
});

// --- PROPRIÉTAIRES (Socle Contacts) ---

final proprietairesListProvider = StreamProvider.autoDispose<List<Contact>>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null) return const Stream.empty();
  return ref.watch(observerContactsProvider).call(
        ctx,
        const FiltreContacts(relation: RelationContact.proprietaire),
      );
});

class RechercheProprietaireNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

final rechercheProprietaireProvider =
    NotifierProvider<RechercheProprietaireNotifier, String>(RechercheProprietaireNotifier.new);

final proprietairesFiltresProvider = Provider.autoDispose<List<Contact>>((ref) {
  final proprietaires = ref.watch(proprietairesListProvider).value ?? const [];
  final recherche = ref.watch(rechercheProprietaireProvider).trim().toLowerCase();

  if (recherche.isEmpty) return proprietaires;

  return proprietaires.where((p) {
    final matchesNom = p.nomAffiche.toLowerCase().contains(recherche);
    final matchesTel = (p.telephone ?? '').toLowerCase().contains(recherche);
    final matchesVille = (p.ville ?? '').toLowerCase().contains(recherche);
    return matchesNom || matchesTel || matchesVille;
  }).toList();
});

// --- LOCATAIRES (Socle Contacts + Profils Locataires + Finances) ---

/// Liste de tous les contacts enregistrés avec la relation Locataire.
final locatairesListProvider = StreamProvider.autoDispose<List<Contact>>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null) return const Stream.empty();
  return ref.watch(observerContactsProvider).call(
        ctx,
        const FiltreContacts(relation: RelationContact.locataire),
      );
});

/// Flux réactif des profils locataires de l'entreprise.
final profilsLocatairesProvider = StreamProvider.autoDispose<List<ProfilLocataire>>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null || ctx.entreprise == null) return Stream.value(const <ProfilLocataire>[]);
  return ref.watch(immobilierRepositoryProvider).observerProfilsLocataires(ctx.entreprise!.id);
});

/// Dossier locataire d'un contact particulier.
final profilLocataireProvider =
    FutureProvider.autoDispose.family<ProfilLocataire?, String>((ref, contactId) {
  return ref.watch(immobilierRepositoryProvider).getProfilLocataire(contactId);
});

/// Situation financière en temps réel du locataire (calculée depuis les engagements/paiements).
final situationFinanciereLocataireProvider =
    Provider.autoDispose.family<SituationFinanciereLocataire, String>((ref, contactId) {
  final etatAsync = ref.watch(etatFinancesProvider);
  final etat = etatAsync.value;
  if (etat == null) return SituationFinanciereLocataire.vide();

  // Profil locataire pour vérifier s'il est en contentieux
  final profils = ref.watch(profilsLocatairesProvider).value ?? const [];
  final profil = profils.where((p) => p.contactId == contactId).firstOrNull;

  final suivis = etat.suivis
      .where((s) =>
          s.engagement.contactId == contactId &&
          s.engagement.sens == SensEngagement.aRecevoir &&
          !s.engagement.annule)
      .toList();

  int totalAppeles = 0;
  int totalRegle = 0;
  int totalImpayes = 0;
  bool aRetard = false;

  final aujourdhui = DateTime.now();
  for (final s in suivis) {
    totalAppeles += s.engagement.montantTotal;
    totalRegle += s.regle;
    totalImpayes += s.reste;
    if (s.etat(aujourdhui) == EtatReglement.enRetard) {
      aRetard = true;
    }
  }

  StatutFinancierLocataire statut;
  if (profil != null && profil.statutFinancier == StatutFinancierLocataire.contentieux) {
    statut = StatutFinancierLocataire.contentieux;
  } else if (aRetard) {
    statut = StatutFinancierLocataire.enRetard;
  } else {
    statut = StatutFinancierLocataire.aJour;
  }

  return SituationFinanciereLocataire(
    totalAppeles: totalAppeles,
    totalRegle: totalRegle,
    soldeDu: totalImpayes,
    impayes: totalImpayes,
    statut: statut,
  );
});

/// Filtres de recherche pour les locataires.
class FiltreLocataires {
  const FiltreLocataires({
    this.recherche = '',
    this.statutFinancier,
    this.typePersonne,
  });

  final String recherche;
  final StatutFinancierLocataire? statutFinancier;
  final TypePersonne? typePersonne;

  FiltreLocataires copyWith({
    String? recherche,
    StatutFinancierLocataire? Function()? statutFinancier,
    TypePersonne? Function()? typePersonne,
  }) {
    return FiltreLocataires(
      recherche: recherche ?? this.recherche,
      statutFinancier: statutFinancier != null ? statutFinancier() : this.statutFinancier,
      typePersonne: typePersonne != null ? typePersonne() : this.typePersonne,
    );
  }
}

class FiltreLocatairesNotifier extends Notifier<FiltreLocataires> {
  @override
  FiltreLocataires build() => const FiltreLocataires();

  void rechercher(String query) => state = state.copyWith(recherche: query);
  void changerStatut(StatutFinancierLocataire? statut) =>
      state = state.copyWith(statutFinancier: () => statut);
  void changerType(TypePersonne? type) => state = state.copyWith(typePersonne: () => type);
  void reinitialiser() => state = const FiltreLocataires();
}

final filtreLocatairesProvider =
    NotifierProvider<FiltreLocatairesNotifier, FiltreLocataires>(FiltreLocatairesNotifier.new);

final locatairesFiltresProvider = Provider.autoDispose<List<Contact>>((ref) {
  final locataires = ref.watch(locatairesListProvider).value ?? const [];
  final filtre = ref.watch(filtreLocatairesProvider);
  final recherche = filtre.recherche.trim().toLowerCase();

  return locataires.where((l) {
    if (filtre.typePersonne != null && l.typePersonne != filtre.typePersonne) {
      return false;
    }
    if (filtre.statutFinancier != null) {
      final situation = ref.watch(situationFinanciereLocataireProvider(l.id));
      if (situation.statut != filtre.statutFinancier) return false;
    }
    if (recherche.isNotEmpty) {
      final matchesNom = l.nomAffiche.toLowerCase().contains(recherche);
      final matchesTel = (l.telephone ?? '').toLowerCase().contains(recherche);
      final matchesEmail = (l.email ?? '').toLowerCase().contains(recherche);
      final matchesVille = (l.ville ?? '').toLowerCase().contains(recherche);
      if (!matchesNom && !matchesTel && !matchesEmail && !matchesVille) {
        return false;
      }
    }
    return true;
  }).toList();
});

// --- LOCATIONS (Occupation, baux et historique) ---

/// Flux réactif de toutes les locations de l'entreprise.
final locationsListProvider = StreamProvider.autoDispose<List<LocationImmobilier>>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null || ctx.entreprise == null) return Stream.value(const <LocationImmobilier>[]);
  return ref.watch(immobilierRepositoryProvider).observerLocations(ctx.entreprise!.id);
});

/// Détail d'une location particulière.
final locationDetailsProvider =
    FutureProvider.autoDispose.family<LocationImmobilier?, String>((ref, id) {
  return ref.watch(immobilierRepositoryProvider).getLocation(id);
});

/// Locations d'un bien donné (historique d'occupation).
final locationsParBienProvider =
    StreamProvider.autoDispose.family<List<LocationImmobilier>, String>((ref, bienId) {
  return ref.watch(immobilierRepositoryProvider).observerLocationsParBien(bienId);
});

/// Locations d'un locataire donné.
final locationsParLocataireProvider =
    StreamProvider.autoDispose.family<List<LocationImmobilier>, String>((ref, locataireId) {
  return ref.watch(immobilierRepositoryProvider).observerLocationsParLocataire(locataireId);
});

/// Location active actuelle pour un bien donné (si occupé).
final locationActiveDuBienProvider =
    Provider.autoDispose.family<LocationImmobilier?, String>((ref, bienId) {
  final locations = ref.watch(locationsListProvider).value ?? const [];
  return locations
      .where((l) => l.bienId == bienId && (l.statut == StatutLocation.active || l.statut == StatutLocation.enAttente))
      .firstOrNull;
});

/// Statistiques consolidées d'occupation du parc immobilier.
final parcOccupationStatistiquesProvider = Provider.autoDispose<ParcOccupationStatistiques>((ref) {
  final biens = ref.watch(biensListProvider).value ?? const [];
  final locations = ref.watch(locationsListProvider).value ?? const [];

  final biensActifs = biens.where((b) => b.statut != StatutBien.archive).toList();
  final totalBiens = biensActifs.length;

  int nbOccupes = 0;
  int nbVacants = 0;
  int nbReserves = 0;
  int nbEnTravaux = 0;

  for (final b in biensActifs) {
    switch (b.statut) {
      case StatutBien.occupe:
        nbOccupes++;
        break;
      case StatutBien.disponible:
        nbVacants++;
        break;
      case StatutBien.reserve:
        nbReserves++;
        break;
      case StatutBien.enTravaux:
        nbEnTravaux++;
        break;
      case StatutBien.archive:
        break;
    }
  }

  final double taux = totalBiens > 0 ? (nbOccupes / totalBiens) * 100 : 0.0;

  // Calcul du volume mensuel des loyers actuellement actifs
  final loyerTotal = locations
      .where((l) => l.statut == StatutLocation.active)
      .fold<int>(0, (sum, l) => sum + l.totalMensuel);

  return ParcOccupationStatistiques(
    totalBiens: totalBiens,
    nbOccupes: nbOccupes,
    nbVacants: nbVacants,
    nbReserves: nbReserves,
    nbEnTravaux: nbEnTravaux,
    tauxOccupation: taux,
    loyerTotalMensuel: loyerTotal,
  );
});

/// Filtres pour la vue des locations.
class FiltreLocations {
  const FiltreLocations({
    this.recherche = '',
    this.statut,
    this.bienId,
  });

  final String recherche;
  final StatutLocation? statut;
  final String? bienId;

  FiltreLocations copyWith({
    String? recherche,
    StatutLocation? Function()? statut,
    String? Function()? bienId,
  }) {
    return FiltreLocations(
      recherche: recherche ?? this.recherche,
      statut: statut != null ? statut() : this.statut,
      bienId: bienId != null ? bienId() : this.bienId,
    );
  }
}

class FiltreLocationsNotifier extends Notifier<FiltreLocations> {
  @override
  FiltreLocations build() => const FiltreLocations();

  void rechercher(String query) => state = state.copyWith(recherche: query);
  void changerStatut(StatutLocation? statut) => state = state.copyWith(statut: () => statut);
  void changerBien(String? bienId) => state = state.copyWith(bienId: () => bienId);
  void reinitialiser() => state = const FiltreLocations();
}

final filtreLocationsProvider =
    NotifierProvider<FiltreLocationsNotifier, FiltreLocations>(FiltreLocationsNotifier.new);

final locationsFiltreesProvider = Provider.autoDispose<List<LocationImmobilier>>((ref) {
  final locations = ref.watch(locationsListProvider).value ?? const [];
  final filtre = ref.watch(filtreLocationsProvider);
  final recherche = filtre.recherche.trim().toLowerCase();

  return locations.where((l) {
    if (filtre.statut != null && l.statut != filtre.statut) return false;
    if (filtre.bienId != null && l.bienId != filtre.bienId) return false;
    if (recherche.isNotEmpty) {
      // Filtrage par ID ou autre élément textuel
      if (!l.id.toLowerCase().contains(recherche)) {
        return false;
      }
    }
    return true;
  }).toList();
});

// --- CONTRATS DE BAIL ---

final contratsListProvider = StreamProvider.autoDispose<List<ContratBail>>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null || ctx.entreprise == null) return Stream.value(const <ContratBail>[]);
  return ref.watch(immobilierRepositoryProvider).observerContrats(ctx.entreprise!.id);
});

final contratDetailsProvider = FutureProvider.autoDispose.family<ContratBail?, String>((ref, id) {
  return ref.watch(immobilierRepositoryProvider).getContrat(id);
});

final contratsParBienProvider =
    StreamProvider.autoDispose.family<List<ContratBail>, String>((ref, bienId) {
  return ref.watch(immobilierRepositoryProvider).observerContratsParBien(bienId);
});

final contratsParLocataireProvider =
    StreamProvider.autoDispose.family<List<ContratBail>, String>((ref, locataireId) {
  return ref.watch(immobilierRepositoryProvider).observerContratsParLocataire(locataireId);
});

class FiltreContrats {
  const FiltreContrats({
    this.recherche = '',
    this.typeBail,
    this.statut,
    this.bienId,
    this.locataireId,
  });

  final String recherche;
  final TypeBail? typeBail;
  final StatutContratBail? statut;
  final String? bienId;
  final String? locataireId;

  FiltreContrats copyWith({
    String? recherche,
    TypeBail? Function()? typeBail,
    StatutContratBail? Function()? statut,
    String? Function()? bienId,
    String? Function()? locataireId,
  }) {
    return FiltreContrats(
      recherche: recherche ?? this.recherche,
      typeBail: typeBail != null ? typeBail() : this.typeBail,
      statut: statut != null ? statut() : this.statut,
      bienId: bienId != null ? bienId() : this.bienId,
      locataireId: locataireId != null ? locataireId() : this.locataireId,
    );
  }
}

class FiltreContratsNotifier extends Notifier<FiltreContrats> {
  @override
  FiltreContrats build() => const FiltreContrats();

  void modifierRecherche(String query) => state = state.copyWith(recherche: query);
  void filtrerTypeBail(TypeBail? type) => state = state.copyWith(typeBail: () => type);
  void filtrerStatut(StatutContratBail? statut) => state = state.copyWith(statut: () => statut);
  void filtrerBien(String? bienId) => state = state.copyWith(bienId: () => bienId);
  void filtrerLocataire(String? locataireId) => state = state.copyWith(locataireId: () => locataireId);
  void reinitialiser() => state = const FiltreContrats();
}

final filtreContratsProvider =
    NotifierProvider<FiltreContratsNotifier, FiltreContrats>(FiltreContratsNotifier.new);

final contratsFiltresProvider = Provider.autoDispose<List<ContratBail>>((ref) {
  final contrats = ref.watch(contratsListProvider).value ?? const [];
  final filtre = ref.watch(filtreContratsProvider);
  final recherche = filtre.recherche.trim().toLowerCase();

  return contrats.where((c) {
    if (filtre.typeBail != null && c.typeBail != filtre.typeBail) return false;
    if (filtre.statut != null && c.statut != filtre.statut) return false;
    if (filtre.bienId != null && c.bienId != filtre.bienId) return false;
    if (filtre.locataireId != null && c.locataireId != filtre.locataireId) return false;
    if (recherche.isNotEmpty) {
      if (!c.reference.toLowerCase().contains(recherche)) {
        return false;
      }
    }
    return true;
  }).toList();
});

class ImmobilierContratsController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<ContratBail> sauvegarderContrat(ContratBail contrat) async {
    state = const AsyncLoading();
    try {
      final res = await ref.read(immobilierRepositoryProvider).sauvegarderContrat(contrat);
      state = const AsyncData(null);
      return res;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> changerStatut(String id, StatutContratBail nouveauStatut) async {
    state = const AsyncLoading();
    try {
      await ref.read(immobilierRepositoryProvider).changerStatutContrat(id, nouveauStatut);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> signerContrat(String id, {bool bailleur = false, bool locataire = false}) async {
    state = const AsyncLoading();
    try {
      await ref.read(immobilierRepositoryProvider).signerContrat(
            id,
            bailleur: bailleur,
            locataire: locataire,
          );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final immobilierContratsControllerProvider =
    AsyncNotifierProvider<ImmobilierContratsController, void>(
  ImmobilierContratsController.new,
);

// --- ÉCHÉANCES DE LOYERS & ENCAISSEMENTS ---

final echeancesLoyersProvider = StreamProvider.autoDispose<List<EcheanceLoyer>>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null || ctx.entreprise == null) return Stream.value(const <EcheanceLoyer>[]);
  return ref.watch(immobilierRepositoryProvider).observerEcheancesLoyers(ctx.entreprise!.id);
});

final echeanceDetailsProvider =
    FutureProvider.autoDispose.family<EcheanceLoyer?, String>((ref, id) {
  return ref.watch(immobilierRepositoryProvider).getEcheanceLoyer(id);
});

final echeancesParLocataireProvider =
    StreamProvider.autoDispose.family<List<EcheanceLoyer>, String>((ref, locataireId) {
  return ref.watch(immobilierRepositoryProvider).observerEcheancesParLocataire(locataireId);
});

final echeancesParBienProvider =
    StreamProvider.autoDispose.family<List<EcheanceLoyer>, String>((ref, bienId) {
  return ref.watch(immobilierRepositoryProvider).observerEcheancesParBien(bienId);
});

class PeriodeFiltreLoyers {
  const PeriodeFiltreLoyers({
    required this.annee,
    required this.mois,
    this.statut,
    this.recherche = '',
  });

  final int annee;
  final int mois;
  final StatutEcheanceLoyer? statut;
  final String recherche;

  PeriodeFiltreLoyers copyWith({
    int? annee,
    int? mois,
    StatutEcheanceLoyer? Function()? statut,
    String? recherche,
  }) {
    return PeriodeFiltreLoyers(
      annee: annee ?? this.annee,
      mois: mois ?? this.mois,
      statut: statut != null ? statut() : this.statut,
      recherche: recherche ?? this.recherche,
    );
  }
}

class PeriodeFiltreLoyersNotifier extends Notifier<PeriodeFiltreLoyers> {
  @override
  PeriodeFiltreLoyers build() {
    final now = DateTime.now();
    return PeriodeFiltreLoyers(annee: now.year, mois: now.month);
  }

  void changerPeriode(int annee, int mois) =>
      state = state.copyWith(annee: annee, mois: mois);

  void moisSuivant() {
    if (state.mois == 12) {
      state = state.copyWith(annee: state.annee + 1, mois: 1);
    } else {
      state = state.copyWith(mois: state.mois + 1);
    }
  }

  void moisPrecedent() {
    if (state.mois == 1) {
      state = state.copyWith(annee: state.annee - 1, mois: 12);
    } else {
      state = state.copyWith(mois: state.mois - 1);
    }
  }

  void filtrerStatut(StatutEcheanceLoyer? statut) =>
      state = state.copyWith(statut: () => statut);

  void rechercher(String query) =>
      state = state.copyWith(recherche: query);

  void reinitialiser() {
    final now = DateTime.now();
    state = PeriodeFiltreLoyers(annee: now.year, mois: now.month);
  }
}

final filtreLoyersProvider =
    NotifierProvider<PeriodeFiltreLoyersNotifier, PeriodeFiltreLoyers>(
  PeriodeFiltreLoyersNotifier.new,
);

final echeancesFiltreesProvider = Provider.autoDispose<List<EcheanceLoyer>>((ref) {
  final toutes = ref.watch(echeancesLoyersProvider).value ?? const [];
  final filtre = ref.watch(filtreLoyersProvider);
  final recherche = filtre.recherche.trim().toLowerCase();
  final biens = ref.watch(biensListProvider).value ?? const [];
  final contacts = ref.watch(contactsProvider).value ?? const [];

  return toutes.where((e) {
    if (e.periodeAnnee != filtre.annee) return false;
    if (e.periodeMois != filtre.mois) return false;
    if (filtre.statut != null && e.statut != filtre.statut) return false;
    if (recherche.isNotEmpty) {
      final refMatch = e.reference.toLowerCase().contains(recherche);
      final bien = biens.where((b) => b.id == e.bienId).firstOrNull;
      final bienMatch = bien != null && bien.nom.toLowerCase().contains(recherche);
      final locataire = contacts.where((c) => c.id == e.locataireId).firstOrNull;
      final locataireMatch = locataire != null && locataire.nomAffiche.toLowerCase().contains(recherche);
      if (!refMatch && !bienMatch && !locataireMatch) {
        return false;
      }
    }
    return true;
  }).toList();
});

final recouvrementStatistiquesProvider = Provider.autoDispose<RecouvrementStatistiques>((ref) {
  final echeancesDuMois = ref.watch(echeancesFiltreesProvider);
  final now = DateTime.now();

  int totalAppele = 0;
  int totalEncaisse = 0;
  int nbSoldes = 0;
  int nbEnRetard = 0;

  for (final e in echeancesDuMois) {
    totalAppele += e.totalDu;
    totalEncaisse += e.montantRegle;
    if (e.estSolde) {
      nbSoldes++;
    } else if (e.estEnRetardCalcule(now)) {
      nbEnRetard++;
    }
  }

  final totalImpayes = (totalAppele - totalEncaisse).clamp(0, totalAppele);

  return RecouvrementStatistiques(
    totalAppele: totalAppele,
    totalEncaisse: totalEncaisse,
    totalImpayes: totalImpayes,
    nbEcheances: echeancesDuMois.length,
    nbSoldes: nbSoldes,
    nbEnRetard: nbEnRetard,
  );
});

class ImmobilierLoyersController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<List<EcheanceLoyer>> genererAppelsDuMois({
    required int mois,
    required int annee,
  }) async {
    state = const AsyncLoading();
    try {
      final ctx = ref.read(contexteActifProvider);
      if (ctx == null || ctx.entreprise == null) return const [];
      final res = await ref.read(immobilierRepositoryProvider).genererAppelsLoyersMensuels(
            entrepriseId: ctx.entreprise!.id,
            mois: mois,
            annee: annee,
          );
      state = const AsyncData(null);
      return res;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> encaisserLoyer({
    required String echeanceId,
    required int montantVerse,
    required String modePaiement,
    String? referencePaiement,
    String? note,
    DateTime? datePaiement,
    String? quittanceDocumentId,
    String? recuDocumentId,
  }) async {
    state = const AsyncLoading();
    try {
      await ref.read(immobilierRepositoryProvider).enregistrerPaiementLoyer(
            echeanceId: echeanceId,
            montantVerse: montantVerse,
            modePaiement: modePaiement,
            referencePaiement: referencePaiement,
            note: note,
            datePaiement: datePaiement,
            quittanceDocumentId: quittanceDocumentId,
            recuDocumentId: recuDocumentId,
          );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Encaissement métier complet d'un loyer :
  /// - Validation stricte des montants et prévention des doubles paiements.
  /// - Ventilation multi-périodes si montant > solde de l'échéance.
  /// - Écriture financière unique dans finances (avec mouvement de caisse si espèces & caisse ouverte).
  /// - Émission de quittance (si 100% soldé) ou reçu d'acompte (si partiel).
  /// - Mise à jour du référentiel immobilier, du solde dû et de la file de synchronisation.
  Future<ResultatEncaissementLoyer> recevoirLoyer({
    required String bienId,
    required String locataireId,
    String? contratId,
    String? echeanceId,
    required int montantVerse,
    required ModePaiement modePaiement,
    DateTime? datePaiement,
    String? referencePaiement,
    String? note,
    bool emettreDocument = true,
  }) async {
    if (montantVerse <= 0) {
      throw const Failure.rule(RuleCodes.amountInvalid);
    }

    state = const AsyncLoading();
    try {
      final ctx = ref.read(contexteActifProvider);
      if (ctx == null || ctx.entreprise == null) {
        throw Exception('Session entreprise active introuvable.');
      }
      final entrepriseId = ctx.entreprise!.id;
      final date = datePaiement ?? DateTime.now();

      // 1. Récupération des échéances cibles
      final toutesEcheances = ref.read(echeancesLoyersProvider).value ?? const [];
      final List<EcheanceLoyer> cibles = [];

      if (echeanceId != null) {
        final ech = toutesEcheances.where((x) => x.id == echeanceId).firstOrNull;
        if (ech != null) {
          cibles.add(ech);
        }
        final autres = toutesEcheances
            .where((x) =>
                x.id != echeanceId &&
                x.contratId == ech?.contratId &&
                x.resteAPayer > 0 &&
                x.statut != StatutEcheanceLoyer.annule)
            .toList()
          ..sort((a, b) => a.dateExigibilite.compareTo(b.dateExigibilite));
        cibles.addAll(autres);
      } else {
        cibles.addAll(toutesEcheances
            .where((x) =>
                x.bienId == bienId &&
                x.locataireId == locataireId &&
                x.resteAPayer > 0 &&
                x.statut != StatutEcheanceLoyer.annule)
            .toList()
          ..sort((a, b) => a.dateExigibilite.compareTo(b.dateExigibilite)));
      }

      if (cibles.isEmpty) {
        throw Exception('Aucune échéance de loyer impayée trouvée pour ce contrat/locataire.');
      }

      // 2. Ventilation du montant versé
      int restantAVentiler = montantVerse;
      final allocations = <AllocationLoyer>[];
      final affectationsFinancieres = <String, int>{};

      for (final ech in cibles) {
        if (restantAVentiler <= 0) break;
        final aPrendre = restantAVentiler > ech.resteAPayer ? ech.resteAPayer : restantAVentiler;
        final resteApres = (ech.resteAPayer - aPrendre).clamp(0, ech.totalDu);
        final solde = resteApres == 0;

        allocations.add(AllocationLoyer(
          echeanceId: ech.id,
          periodeLibelle: ech.periodeLibelle,
          montantAffecte: aPrendre,
          resteAvant: ech.resteAPayer,
          resteApres: resteApres,
          estSolde: solde,
        ));

        if (ech.engagementId.isNotEmpty) {
          affectationsFinancieres[ech.engagementId] = aPrendre;
        }

        restantAVentiler -= aPrendre;
      }

      final echeancePrincipale = cibles.first;
      final estSoldeTotal = allocations.every((a) => a.estSolde);

      // 3. Intégration financière (Écriture financière unique dans finances)
      final financesRepo = ref.read(financesRepositoryProvider);
      final etatFinances = await financesRepo.watch(entrepriseId).first;

      // Garantir la création de l'engagement comptable si absent
      for (final alloc in allocations) {
        final ech = cibles.firstWhere((x) => x.id == alloc.echeanceId);
        if (ech.engagementId.isNotEmpty) {
          final existe = etatFinances.engagements.any((e) => e.id == ech.engagementId);
          if (!existe) {
            final bien = (ref.read(biensListProvider).value ?? const []).where((b) => b.id == ech.bienId).firstOrNull;
            final eng = Engagement(
              id: ech.engagementId,
              entrepriseId: entrepriseId,
              activite: ActiviteCode.immobilier,
              sens: SensEngagement.aRecevoir,
              contactId: ech.locataireId,
              libelle: 'Loyer ${ech.periodeLibelle} - ${bien?.nom ?? 'Logement'}',
              montantTotal: ech.totalDu,
              dateEngagement: ech.dateEmission,
              echeance: ech.dateExigibilite,
              origineType: 'LOYER',
              syncStatus: RecordSyncStatus.pendingSync,
            );
            await financesRepo.creerEngagement(eng);
          }
        }
      }

      // Mouvement de caisse si espèces et session ouverte
      SessionCaisse? session;
      if (modePaiement.passeParCaisse) {
        session = etatFinances.sessions.where((s) => s.ouverte).firstOrNull;
      }

      final paiementId = const Uuid().v4();
      final bien = (ref.read(biensListProvider).value ?? const []).where((b) => b.id == echeancePrincipale.bienId).firstOrNull;
      final locataire = (ref.read(contactsProvider).value ?? const []).where((c) => c.id == echeancePrincipale.locataireId).firstOrNull;

      final p = Paiement(
        id: paiementId,
        entrepriseId: entrepriseId,
        activite: ActiviteCode.immobilier,
        sens: SensPaiement.entree,
        montant: montantVerse,
        mode: modePaiement,
        datePaiement: date,
        contactId: locataireId,
        reference: referencePaiement != null && referencePaiement.trim().isNotEmpty ? referencePaiement.trim() : null,
        note: note != null && note.trim().isNotEmpty
            ? note.trim()
            : 'Encaissement loyer ${echeancePrincipale.periodeLibelle} - ${bien?.nom ?? ''}',
        sessionId: session?.id,
        affectations: [
          for (final entry in affectationsFinancieres.entries)
            Affectation(id: const Uuid().v4(), engagementId: entry.key, montant: entry.value),
        ],
        syncStatus: RecordSyncStatus.pendingSync,
      );

      MouvementCaisse? mouv;
      if (session != null) {
        mouv = MouvementCaisse(
          id: paiementId,
          sessionId: session.id,
          caisseId: session.caisseId,
          type: TypeMouvement.encaissement,
          montant: montantVerse,
          paiementId: paiementId,
          motif: 'Encaissement loyer ${echeancePrincipale.periodeLibelle} - ${bien?.nom ?? ''}',
          createdAt: DateTime.now(),
        );
      }

      await financesRepo.enregistrerPaiement(p, mouvement: mouv);

      // 4. Émission du document professionnel (Quittance si 100% soldé, Reçu d'acompte si partiel)
      Document? documentGenere;
      String? quittanceDocId;
      String? recuDocId;

      if (emettreDocument) {
        final devise = ctx.entreprise?.devise ?? 'FCFA';
        final typeDoc = estSoldeTotal ? TypeDocument.quittance : TypeDocument.recu;
        final titreDoc = estSoldeTotal
            ? 'Quittance de loyer - ${echeancePrincipale.periodeLibelle}'
            : 'Reçu d\'acompte de loyer - ${echeancePrincipale.periodeLibelle}';

        final contenu = <String, dynamic>{
          'titre': titreDoc,
          'reference_metier': echeancePrincipale.reference,
          'periode_loyer': echeancePrincipale.periodeLibelle,
          'periode_mois': echeancePrincipale.periodeMois,
          'periode_annee': echeancePrincipale.periodeAnnee,
          'bien_nom': bien?.nom ?? 'Bien immobilier',
          'bien_adresse': bien?.adresseComplete ?? '',
          'locataire_nom': locataire?.nomAffiche ?? 'Locataire',
          'locataire_telephone': locataire?.telephone ?? '',
          'loyer_net': echeancePrincipale.loyerNet,
          'charges': echeancePrincipale.charges,
          'total_du': echeancePrincipale.totalDu,
          'montant_verse': montantVerse,
          'reste_a_payer': allocations.fold(0, (tot, a) => tot + a.resteApres),
          'mode_paiement': modePaiement.code,
          'reference_paiement': referencePaiement ?? '',
          'statut': estSoldeTotal ? 'PAYE' : 'PARTIEL',
          'devise': devise,
          'notes': note ?? '',
          'entreprise': {
            'nom': ctx.entreprise?.nom ?? 'DubaGest',
            'devise': devise,
          },
          'contact': {
            'nom': locataire?.nomAffiche ?? 'Locataire',
            'telephone': locataire?.telephone ?? '',
          },
          'allocations': [
            for (final a in allocations)
              {
                'periode': a.periodeLibelle,
                'montant': a.montantAffecte,
                'reste': a.resteApres,
                'statut': a.estSolde ? 'Soldé' : 'Partiel',
              }
          ],
          'lignes': [
            for (final a in allocations)
              {
                'description': 'Loyer - ${a.periodeLibelle} (${bien?.nom ?? ''})',
                'quantite': 1,
                'prix_unitaire': a.montantAffecte,
                'total': a.montantAffecte,
              }
          ],
        };

        try {
          final appareilId = ref.read(appareilIdProvider);
          documentGenere = await ref.read(emettreDocumentProvider).call(
                ctx,
                type: typeDoc,
                origineType: 'LOYER',
                origineId: echeancePrincipale.id,
                contactId: echeancePrincipale.locataireId,
                montant: montantVerse,
                contenu: contenu,
                appareilId: appareilId,
              );
          if (estSoldeTotal) {
            quittanceDocId = documentGenere.id;
          } else {
            recuDocId = documentGenere.id;
          }
        } catch (_) {
          // Document fallback pour impression / partage
          documentGenere = Document(
            id: const Uuid().v4(),
            entrepriseId: entrepriseId,
            type: typeDoc,
            numero: '${typeDoc.prefixeParDefaut}-${date.year}-${date.millisecondsSinceEpoch.toString().substring(7)}',
            blocId: 'offline-bloc',
            sequence: 1,
            langue: 'fr',
            date: date,
            montant: montantVerse,
            origineType: 'LOYER',
            origineId: echeancePrincipale.id,
            contactId: locataireId,
            contenu: contenu,
          );
        }
      }

      // 5. Mise à jour des échéances dans le repository
      for (final a in allocations) {
        await ref.read(immobilierRepositoryProvider).enregistrerPaiementLoyer(
              echeanceId: a.echeanceId,
              montantVerse: a.montantAffecte,
              modePaiement: modePaiement.code,
              referencePaiement: referencePaiement,
              note: note,
              datePaiement: date,
              quittanceDocumentId: a.estSolde ? (quittanceDocId ?? documentGenere?.id) : null,
              recuDocumentId: !a.estSolde ? (recuDocId ?? documentGenere?.id) : null,
            );
      }

      ref.invalidate(echeancesLoyersProvider);
      ref.invalidate(biensListProvider);

      state = const AsyncData(null);

      return ResultatEncaissementLoyer(
        echeancePrincipale: echeancePrincipale,
        allocations: allocations,
        montantTotalVerse: montantVerse,
        modePaiement: modePaiement,
        referencePaiement: referencePaiement,
        note: note,
        datePaiement: date,
        paiementFinancierId: paiementId,
        document: documentGenere,
        estSoldeTotal: estSoldeTotal,
      );
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final immobilierLoyersControllerProvider =
    AsyncNotifierProvider<ImmobilierLoyersController, void>(
  ImmobilierLoyersController.new,
);

// --- TABLEAU DE BORD IMMOBILIER & ALERTES MÉTIER ---

final dashboardImmobilierProvider =
    Provider.autoDispose<DashboardImmobilierData>((ref) {
  final biens = ref.watch(biensListProvider).value ?? const [];
  final contrats = ref.watch(contratsListProvider).value ?? const [];
  final echeances = ref.watch(echeancesLoyersProvider).value ?? const [];
  final contacts = ref.watch(contactsProvider).value ?? const [];

  final now = DateTime.now();

  // 1. Décomposition du parc de biens
  int nbOccupes = 0;
  int nbDisponibles = 0;
  int nbEnTravaux = 0;
  int nbReserves = 0;

  for (final bien in biens) {
    switch (bien.statut) {
      case StatutBien.occupe:
        nbOccupes++;
        break;
      case StatutBien.disponible:
        nbDisponibles++;
        break;
      case StatutBien.enTravaux:
        nbEnTravaux++;
        break;
      case StatutBien.reserve:
        nbReserves++;
        break;
      case StatutBien.archive:
        break;
    }
  }

  // 2. Contrats actifs & cautions en dépôt (strictement ségréguées)
  final contratsActifs =
      contrats.where((c) => c.statut == StatutContratBail.actif).toList();
  int totalCautions = 0;
  final locatairesActifsIds = <String>{};

  for (final c in contratsActifs) {
    totalCautions += c.depotGarantie;
    locatairesActifsIds.add(c.locataireId);
  }

  // 3. Recouvrement du mois en cours
  final echeancesDuMois = echeances
      .where((e) => e.periodeAnnee == now.year && e.periodeMois == now.month)
      .toList();
  int totalAppeleMois = 0;
  int totalEncaisseMois = 0;

  for (final e in echeancesDuMois) {
    totalAppeleMois += e.totalDu;
    totalEncaisseMois += e.montantRegle;
  }
  final totalImpayesMois =
      (totalAppeleMois - totalEncaisseMois).clamp(0, totalAppeleMois);

  // 4. Détection intelligente des Alertes Métier
  final alertes = <AlerteImmobilier>[];

  // A. Alertes Impayés & Retards de loyers
  for (final echeance in echeances) {
    if (!echeance.estSolde && echeance.estEnRetardCalcule(now)) {
      final joursRetard = now.difference(echeance.dateExigibilite).inDays;
      final locataire =
          contacts.where((c) => c.id == echeance.locataireId).firstOrNull;
      final bien = biens.where((b) => b.id == echeance.bienId).firstOrNull;
      final estCritique = joursRetard >= 15;

      alertes.add(
        AlerteImmobilier(
          id: 'retard-${echeance.id}',
          type: TypeAlerteImmobilier.loyerEnRetard,
          niveau: estCritique ? NiveauAlerte.critique : NiveauAlerte.avertissement,
          titre: 'Loyer en retard ($joursRetard j)',
          message:
              'Loyer de ${echeance.periodeLibelle} impayé par ${locataire?.nomAffiche ?? "Locataire"} pour ${bien?.nom ?? "Logement"}.',
          dateReference: echeance.dateExigibilite,
          montantConcerne: echeance.resteAPayer,
          bienId: echeance.bienId,
          bienNom: bien?.nom,
          locataireId: echeance.locataireId,
          locataireNom: locataire?.nomAffiche,
          echeanceId: echeance.id,
          actionRoute: Routes.loyerDetails(echeance.id),
          actionLibelle: 'Encaisser',
        ),
      );
    }
  }

  // B. Alertes Échéances de bail proches (dans les 60 jours)
  for (final contrat in contratsActifs) {
    if (contrat.dateFinPrevue != null) {
      final joursRestants = contrat.dateFinPrevue!.difference(now).inDays;
      if (joursRestants >= 0 && joursRestants <= 60) {
        final locataire =
            contacts.where((c) => c.id == contrat.locataireId).firstOrNull;
        final bien = biens.where((b) => b.id == contrat.bienId).firstOrNull;
        final estUrgent = joursRestants <= 30;

        alertes.add(
          AlerteImmobilier(
            id: 'fin-bail-${contrat.id}',
            type: TypeAlerteImmobilier.finBailProche,
            niveau:
                estUrgent ? NiveauAlerte.critique : NiveauAlerte.avertissement,
            titre: 'Bail à échéance ($joursRestants j)',
            message:
                'Le bail de ${locataire?.nomAffiche ?? "Locataire"} sur ${bien?.nom ?? "Bien"} expire prochainement.',
            dateReference: contrat.dateFinPrevue!,
            montantConcerne: contrat.loyerMensuel,
            bienId: contrat.bienId,
            bienNom: bien?.nom,
            locataireId: contrat.locataireId,
            locataireNom: locataire?.nomAffiche,
            contratId: contrat.id,
            actionRoute: Routes.contratDetails(contrat.id),
            actionLibelle: 'Voir le bail',
          ),
        );
      }
    }
  }

  // C. Alertes Biens vacants
  for (final bien in biens) {
    if (bien.statut == StatutBien.disponible) {
      alertes.add(
        AlerteImmobilier(
          id: 'bien-vacant-${bien.id}',
          type: TypeAlerteImmobilier.bienVacant,
          niveau: NiveauAlerte.information,
          titre: 'Bien vacant disponible',
          message:
              '${bien.nom} (${bien.type.libelle}) est actuellement sans locataire actif.',
          dateReference: now,
          montantConcerne: bien.loyerReference,
          bienId: bien.id,
          bienNom: bien.nom,
          actionRoute: Routes.bienDetails(bien.id),
          actionLibelle: 'Proposer à bail',
        ),
      );
    }
  }

  // Tri des alertes : critiques en premier, puis avertissements, puis informations
  alertes.sort((a, b) {
    final ordreNiveau = {
      NiveauAlerte.critique: 0,
      NiveauAlerte.avertissement: 1,
      NiveauAlerte.information: 2,
    };
    final comp =
        (ordreNiveau[a.niveau] ?? 3).compareTo(ordreNiveau[b.niveau] ?? 3);
    if (comp != 0) return comp;
    return a.dateReference.compareTo(b.dateReference);
  });

  return DashboardImmobilierData(
    totalBiens: biens.length,
    nbBiensOccupes: nbOccupes,
    nbBiensDisponibles: nbDisponibles,
    nbBiensEnTravaux: nbEnTravaux,
    nbBiensReserves: nbReserves,
    nbContratsActifs: contratsActifs.length,
    nbLocatairesActifs: locatairesActifsIds.length,
    totalLoyersAppelesMois: totalAppeleMois,
    totalLoyersEncaissesMois: totalEncaisseMois,
    totalImpayesMois: totalImpayesMois,
    totalCautionsEnDepot: totalCautions,
    alertes: alertes,
  );
});
