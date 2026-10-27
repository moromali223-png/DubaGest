import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../contacts/domain/entities/contact.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../entreprise/presentation/providers/espace_providers.dart';
import '../../../finances/domain/services/etat_finances.dart';
import '../../../finances/presentation/providers/finances_providers.dart';
import '../../domain/entities/intelligence_commerciale_data.dart';
import '../../domain/services/calcul_intelligence_commerciale.dart';
import '../../domain/services/etat_commerce.dart';
import '../commerce_providers.dart';

/// Onglet d'analyse actif pour une consultation fluide sans défilement infini.
enum VueIntelligenceOnglet {
  ventes('Ventes', 'Évolution du CA et volumes'),
  produits('Produits', 'Classement, marges et tendances'),
  stocks('Stocks', 'Réapprovisionnement et couverture'),
  paniers('Paniers', 'Produits souvent achetés ensemble'),
  engagements('Engagements', 'Créances clients et dettes fournisseurs');

  const VueIntelligenceOnglet(this.titre, this.sousTitre);
  final String titre;
  final String sousTitre;
}

/// Notifier pour la période d'analyse.
class PeriodeAnalyseNotifier extends Notifier<PeriodeAnalyseType> {
  @override
  PeriodeAnalyseType build() => PeriodeAnalyseType.septDerniersJours;

  void choisir(PeriodeAnalyseType p) => state = p;
}

final periodeAnalyseProvider =
    NotifierProvider<PeriodeAnalyseNotifier, PeriodeAnalyseType>(PeriodeAnalyseNotifier.new);

/// Notifier pour les dates personnalisées.
class DatesPersonnaliseesNotifier extends Notifier<({DateTime? debut, DateTime? fin})> {
  @override
  ({DateTime? debut, DateTime? fin}) build() => (debut: null, fin: null);

  void definir({required DateTime debut, required DateTime fin}) {
    state = (debut: debut, fin: fin);
  }
}

final datesPersonnaliseesProvider =
    NotifierProvider<DatesPersonnaliseesNotifier, ({DateTime? debut, DateTime? fin})>(
  DatesPersonnaliseesNotifier.new,
);

/// Notifier pour la boutique / périmètre sélectionné.
class PerimetreSelectionneCommerceNotifier extends Notifier<String?> {
  @override
  String? build() {
    final perimetre = ref.watch(espaceCourantProvider).perimetreId;
    return perimetre;
  }

  void filtrer(String? perimetreId) => state = perimetreId;
}

final perimetreSelectionneCommerceProvider =
    NotifierProvider<PerimetreSelectionneCommerceNotifier, String?>(
  PerimetreSelectionneCommerceNotifier.new,
);

/// Notifier pour l'onglet d'exploration actif.
class VueActiveIntelligenceNotifier extends Notifier<VueIntelligenceOnglet> {
  @override
  VueIntelligenceOnglet build() => VueIntelligenceOnglet.ventes;

  void choisir(VueIntelligenceOnglet onglet) => state = onglet;
}

final vueActiveIntelligenceProvider =
    NotifierProvider<VueActiveIntelligenceNotifier, VueIntelligenceOnglet>(
  VueActiveIntelligenceNotifier.new,
);

/// Intervalle de dates résolu avec période précédente équivalente.
final intervalleAnalyseCourantProvider = Provider<IntervallePeriode>((ref) {
  final type = ref.watch(periodeAnalyseProvider);
  final perso = ref.watch(datesPersonnaliseesProvider);
  return CalculIntelligenceCommerciale.resoudreIntervalle(
    type,
    debutPerso: perso.debut,
    finPerso: perso.fin,
  );
});

/// État analytique global réactif aux modifications du commerce, des finances et des filtres.
final intelligenceCommercialeProvider = Provider<AsyncValue<EtatIntelligenceCommerciale>>((ref) {
  final AsyncValue<EtatCommerce> commerceAsync = ref.watch(etatCommerceProvider);
  final AsyncValue<EtatFinances> financesAsync = ref.watch(etatFinancesProvider);
  final List<Contact> contacts = ref.watch(contactsProvider).value ?? const <Contact>[];
  final IntervallePeriode intervalle = ref.watch(intervalleAnalyseCourantProvider);
  final String? perimetreId = ref.watch(perimetreSelectionneCommerceProvider);

  if (commerceAsync.isLoading || financesAsync.isLoading) {
    return const AsyncLoading();
  }

  if (commerceAsync.hasError) {
    return AsyncError(commerceAsync.error!, commerceAsync.stackTrace!);
  }
  if (financesAsync.hasError) {
    return AsyncError(financesAsync.error!, financesAsync.stackTrace!);
  }

  final EtatCommerce? commerce = commerceAsync.value;
  final EtatFinances? finances = financesAsync.value;

  if (commerce == null || finances == null) {
    return const AsyncLoading();
  }

  try {
    final etat = CalculIntelligenceCommerciale.calculer(
      commerce: commerce,
      finances: finances,
      contacts: contacts,
      intervalle: intervalle,
      perimetreId: perimetreId,
    );
    return AsyncData(etat);
  } catch (e, st) {
    return AsyncError(e, st);
  }
});
