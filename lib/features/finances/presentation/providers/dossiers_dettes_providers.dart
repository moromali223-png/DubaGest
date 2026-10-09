import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/dossier_dette.dart';
import '../../domain/entities/finances.dart';
import '../../domain/services/calcul_dossiers_dettes.dart';
import '../widgets/finances_widgets.dart';
import 'finances_providers.dart';

/// Filtre d'état sélectionnable
enum FiltreStatutDette {
  tous,
  enRetard,
  bientot,
  aJour,
  regle;

  String get label => switch (this) {
        FiltreStatutDette.tous => 'Tous',
        FiltreStatutDette.enRetard => 'En retard',
        FiltreStatutDette.bientot => 'Bientôt',
        FiltreStatutDette.aJour => 'À jour',
        FiltreStatutDette.regle => 'Réglés',
      };
}

/// Mode de vue principale
enum VueDettesMode {
  personnes,
  echeances;

  String get label => switch (this) {
        VueDettesMode.personnes => 'Clients',
        VueDettesMode.echeances => 'Échéances',
      };
}

class FiltreDettesState {
  const FiltreDettesState({
    this.recherche = '',
    this.statut = FiltreStatutDette.tous,
    this.modeVue = VueDettesMode.personnes,
    this.afficherSoldes = false,
  });

  final String recherche;
  final FiltreStatutDette statut;
  final VueDettesMode modeVue;
  final bool afficherSoldes;

  FiltreDettesState copyWith({
    String? recherche,
    FiltreStatutDette? statut,
    VueDettesMode? modeVue,
    bool? afficherSoldes,
  }) =>
      FiltreDettesState(
        recherche: recherche ?? this.recherche,
        statut: statut ?? this.statut,
        modeVue: modeVue ?? this.modeVue,
        afficherSoldes: afficherSoldes ?? this.afficherSoldes,
      );
}

class FiltreDettesNotifier extends Notifier<FiltreDettesState> {
  @override
  FiltreDettesState build() => const FiltreDettesState();

  void setRecherche(String query) => state = state.copyWith(recherche: query);
  void setStatut(FiltreStatutDette statut) => state = state.copyWith(statut: statut);
  void setModeVue(VueDettesMode mode) => state = state.copyWith(modeVue: mode);
  void toggleAfficherSoldes() => state = state.copyWith(afficherSoldes: !state.afficherSoldes);
  void reset() => state = const FiltreDettesState();
}

final filtreDettesProvider = NotifierProvider<FiltreDettesNotifier, FiltreDettesState>(FiltreDettesNotifier.new);

/// Tous les dossiers de dettes consolidés par personne pour un sens donné.
final tousDossiersDettesProvider =
    Provider.autoDispose.family<AsyncValue<List<DossierDette>>, SensEngagement>((ref, sens) {
  final etatAsync = ref.watch(etatFinancesProvider);
  final contactsAsync = ref.watch(contactsParIdProvider);

  if (etatAsync is AsyncLoading || contactsAsync is AsyncLoading) {
    return const AsyncLoading();
  }

  if (etatAsync is AsyncError) {
    return AsyncError(etatAsync.error ?? Exception('Erreur finances'), etatAsync.stackTrace ?? StackTrace.current);
  }

  final etat = etatAsync.value;
  if (etat == null) return const AsyncData([]);

  final contacts = contactsAsync.value ?? {};
  final dossiers = CalculDossiersDettes.consolider(
    etat: etat,
    contacts: contacts,
    sens: sens,
    maintenant: DateTime.now(),
  );

  return AsyncData(dossiers);
});

/// Dossiers de dettes filtrés par la recherche et l'état sélectionné.
final dossiersDettesFiltresProvider =
    Provider.autoDispose.family<AsyncValue<List<DossierDette>>, SensEngagement>((ref, sens) {
  final tousAsync = ref.watch(tousDossiersDettesProvider(sens));
  final filtre = ref.watch(filtreDettesProvider);

  return tousAsync.whenData((dossiers) {
    final motsRecherche = filtre.recherche.toLowerCase().trim().split(RegExp(r'\s+')).where((m) => m.isNotEmpty);

    return dossiers.where((d) {
      // 1. Filtrer les soldés
      if (!filtre.afficherSoldes && d.estSolde && filtre.statut != FiltreStatutDette.regle) {
        return false;
      }

      // 2. Filtre de statut
      switch (filtre.statut) {
        case FiltreStatutDette.tous:
          break;
        case FiltreStatutDette.enRetard:
          if (!d.estEnRetard) return false;
          break;
        case FiltreStatutDette.bientot:
          if (d.statutGlobal != StatutDossierDette.bientot) return false;
          break;
        case FiltreStatutDette.aJour:
          if (d.statutGlobal != StatutDossierDette.aJour) return false;
          break;
        case FiltreStatutDette.regle:
          if (!d.estSolde) return false;
          break;
      }

      // 3. Filtre de recherche
      if (motsRecherche.isNotEmpty) {
        final texteConcat = '${d.nomAffiche} ${d.telephone ?? ''} ${d.engagements.map((e) => e.engagement.libelle).join(' ')}'.toLowerCase();
        if (!motsRecherche.every((m) => texteConcat.contains(m))) {
          return false;
        }
      }

      return true;
    }).toList();
  });
});

/// Toutes les échéances individuelles consolidées et filtrées pour la vue calendrier/chronologique.
final echeancesChronologiquesProvider =
    Provider.autoDispose.family<AsyncValue<List<EcheanceDette>>, SensEngagement>((ref, sens) {
  final dossiersAsync = ref.watch(tousDossiersDettesProvider(sens));
  final filtre = ref.watch(filtreDettesProvider);

  return dossiersAsync.whenData((dossiers) {
    final toutes = <EcheanceDette>[];
    for (final d in dossiers) {
      toutes.addAll(d.echeances);
    }

    toutes.sort((a, b) => a.dateEcheance.compareTo(b.dateEcheance));

    final motsRecherche = filtre.recherche.toLowerCase().trim().split(RegExp(r'\s+')).where((m) => m.isNotEmpty);

    return toutes.where((e) {
      if (!filtre.afficherSoldes && e.montantReste <= 0) {
        return false;
      }

      if (filtre.statut == FiltreStatutDette.enRetard && !e.estEnRetard) {
        return false;
      }

      if (motsRecherche.isNotEmpty) {
        final texteConcat = '${e.nomContact ?? ''} ${e.libelle} ${e.origineType}'.toLowerCase();
        if (!motsRecherche.every((m) => texteConcat.contains(m))) {
          return false;
        }
      }

      return true;
    }).toList();
  });
});

/// Détail d'un dossier par sa clé (contactId ou clé de fallback).
final dossierDetteDetailsProvider =
    Provider.autoDispose.family<AsyncValue<DossierDette?>, ({String dossierKey, SensEngagement sens})>(
        (ref, params) {
  final tousAsync = ref.watch(tousDossiersDettesProvider(params.sens));
  return tousAsync.whenData((dossiers) {
    return dossiers.where((d) => d.dossierKey == params.dossierKey || d.contactId == params.dossierKey).firstOrNull;
  });
});
