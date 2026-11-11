import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/core_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/benefice_commerce_data.dart';
import '../../domain/services/calcul_benefice_commerce.dart';
import '../commerce_providers.dart';
import '../../../finances/presentation/providers/finances_providers.dart';

/// Configuration du filtre temporel sélectionné.
class ConfigFiltreBenefice {
  const ConfigFiltreBenefice({
    this.type = TypeFiltreBenefice.ceMois,
    this.datePrecise,
    this.debutPerso,
    this.finPerso,
  });

  final TypeFiltreBenefice type;
  final DateTime? datePrecise;
  final DateTime? debutPerso;
  final DateTime? finPerso;

  ConfigFiltreBenefice copyWith({
    TypeFiltreBenefice? type,
    DateTime? datePrecise,
    DateTime? debutPerso,
    DateTime? finPerso,
  }) {
    return ConfigFiltreBenefice(
      type: type ?? this.type,
      datePrecise: datePrecise ?? this.datePrecise,
      debutPerso: debutPerso ?? this.debutPerso,
      finPerso: finPerso ?? this.finPerso,
    );
  }
}

class FiltreBeneficeNotifier extends Notifier<ConfigFiltreBenefice> {
  @override
  ConfigFiltreBenefice build() => const ConfigFiltreBenefice();

  void changerType(TypeFiltreBenefice type) {
    state = state.copyWith(type: type);
  }

  void definirDatePrecise(DateTime date) {
    state = state.copyWith(
      type: TypeFiltreBenefice.datePrecise,
      datePrecise: date,
    );
  }

  void definirPeriodePersonnalisee(DateTime debut, DateTime fin) {
    state = state.copyWith(
      type: TypeFiltreBenefice.personnalise,
      debutPerso: debut,
      finPerso: fin,
    );
  }
}

final filtreBeneficeProvider = NotifierProvider<FiltreBeneficeNotifier, ConfigFiltreBenefice>(
  FiltreBeneficeNotifier.new,
);

/// Boutique sélectionnée spécifiquement dans l'écran Bénéfice (`null` = Vue globale consolidée).
class BoutiqueBeneficeNotifier extends Notifier<String?> {
  @override
  String? build() {
    return ref.watch(boutiqueCouranteProvider);
  }

  void choisir(String? perimetreId) {
    state = perimetreId;
  }
}

final boutiqueBeneficeProvider = NotifierProvider<BoutiqueBeneficeNotifier, String?>(
  BoutiqueBeneficeNotifier.new,
);

/// Résolution de l'intervalle temporel courant.
final intervalleBeneficeCourantProvider = Provider<IntervalleBenefice>((ref) {
  final config = ref.watch(filtreBeneficeProvider);
  return CalculBeneficeCommerce.resoudreIntervalle(
    config.type,
    datePrecise: config.datePrecise,
    debutPerso: config.debutPerso,
    finPerso: config.finPerso,
  );
});

/// Calcul réactif complet du bénéfice commercial.
/// Fonctionne hors-ligne immédiatement sur l'état local, et synchronise avec Supabase si connecté.
final beneficeCommerceProvider = FutureProvider<EtatBeneficeCommerce>((ref) async {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null) throw StateError('Aucun contexte actif');

  final intervalle = ref.watch(intervalleBeneficeCourantProvider);
  final perimetreId = ref.watch(boutiqueBeneficeProvider);

  // 1. Récupération des états locaux pour réactivité instantanée
  final asyncCommerce = ref.watch(etatCommerceProvider);
  final asyncFinances = ref.watch(etatFinancesProvider);

  final commerce = asyncCommerce.value;
  final finances = asyncFinances.value;

  // Calcul local disponible en premier
  EtatBeneficeCommerce? resultatLocal;
  if (commerce != null && finances != null) {
    resultatLocal = CalculBeneficeCommerce.calculer(
      commerce: commerce,
      finances: finances,
      intervalle: intervalle,
      perimetreId: perimetreId,
    );
  }

  // 2. Si client Supabase disponible et connecté, tenter l'interrogation RPC pour validation serveur
  try {
    final client = ref.read(supabaseClientProvider);
    final entrepriseId = ctx.entreprise?.id;

    if (client.auth.currentSession != null && entrepriseId != null) {
      final res = await client.rpc('calculer_benefice_commerce', params: {
        'p_entreprise_id': entrepriseId,
        'p_perimetre_id': perimetreId,
        'p_date_debut': intervalle.debut.toIso8601String(),
        'p_date_fin': intervalle.fin.toIso8601String(),
      }).select().single();

      if (res != null && res['succes'] == true) {
        final kpiJson = res['kpi'] as Map<String, dynamic>;
        final tresoJson = res['tresorerie'] as Map<String, dynamic>;
        final repJson = (res['repartition_depenses'] as List<dynamic>?) ?? [];
        final prodRentJson = (res['produits_rentabilite'] as List<dynamic>?) ?? [];
        final prodManqJson = (res['produits_cout_manquant'] as List<dynamic>?) ?? [];
        final evolJson = (res['evolution'] as List<dynamic>?) ?? [];

        return EtatBeneficeCommerce(
          intervalle: intervalle,
          perimetreId: perimetreId,
          kpi: KpiBeneficeCommerce(
            chiffreAffairesBrut: (kpiJson['chiffre_affaires_brut'] as num?)?.toInt() ?? 0,
            remises: (kpiJson['remises'] as num?)?.toInt() ?? 0,
            chiffreAffairesNet: (kpiJson['chiffre_affaires_net'] as num?)?.toInt() ?? 0,
            chiffreAffairesPrecedent: (kpiJson['chiffre_affaires_precedent'] as num?)?.toInt() ?? 0,
            nombreVentes: (kpiJson['nombre_ventes'] as num?)?.toInt() ?? 0,
            cogs: (kpiJson['cogs'] as num?)?.toInt() ?? 0,
            cogsPrecedent: (kpiJson['cogs_precedent'] as num?)?.toInt() ?? 0,
            margeBrute: (kpiJson['marge_brute'] as num?)?.toInt() ?? 0,
            margeBrutePrecedente: (kpiJson['marge_brute_precedente'] as num?)?.toInt() ?? 0,
            tauxMarge: (kpiJson['taux_marge'] as num?)?.toDouble() ?? 0.0,
            depensesCommerciales: (kpiJson['depenses_commerciales'] as num?)?.toInt() ?? 0,
            depensesPrecedentes: (kpiJson['depenses_precedentes'] as num?)?.toInt() ?? 0,
            beneficeNetEstime: (kpiJson['benefice_net_estime'] as num?)?.toInt() ?? 0,
            beneficeNetPrecedent: (kpiJson['benefice_net_precedent'] as num?)?.toInt() ?? 0,
            tauxBeneficeNet: (kpiJson['taux_benefice_net'] as num?)?.toDouble() ?? 0.0,
            tauxCouvertureCout: (kpiJson['taux_couverture_cout'] as num?)?.toDouble() ?? 100.0,
            lignesTotal: (kpiJson['lignes_total'] as num?)?.toInt() ?? 0,
            lignesAvecCout: (kpiJson['lignes_avec_cout'] as num?)?.toInt() ?? 0,
          ),
          tresorerie: TresorerieReelleCommerce(
            totalEncaisse: (tresoJson['total_encaisse'] as num?)?.toInt() ?? 0,
            totalDecaisse: (tresoJson['total_decaisse'] as num?)?.toInt() ?? 0,
            soldeNetFlux: (tresoJson['solde_net_flux'] as num?)?.toInt() ?? 0,
            creancesClientsRestantes: (tresoJson['creances_clients_restantes'] as num?)?.toInt() ?? 0,
          ),
          repartitionDepenses: [
            for (final item in repJson)
              RepartitionDepenseItem(
                categorieId: item['categorie_id']?.toString() ?? '',
                categorieNom: item['categorie_nom']?.toString() ?? 'Charges',
                total: (item['total'] as num?)?.toInt() ?? 0,
                pourcentage: (item['pourcentage'] as num?)?.toDouble() ?? 0.0,
                icone: item['icone']?.toString(),
                couleur: item['couleur']?.toString(),
              ),
          ],
          produitsRentabilite: [
            for (final item in prodRentJson)
              ProduitRentabiliteItem(
                produitId: item['produit_id']?.toString() ?? '',
                nom: item['nom']?.toString() ?? '',
                uniteBase: item['unite_base']?.toString() ?? 'Pièce',
                quantiteVendue: (item['quantite_vendue'] as num?)?.toDouble() ?? 0.0,
                chiffreAffaires: (item['chiffre_affaires'] as num?)?.toInt() ?? 0,
                coutAchatUnitaire: (item['cout_achat_unitaire'] as num?)?.toInt(),
                cogs: (item['cogs'] as num?)?.toInt() ?? 0,
                margeBrute: (item['marge_brute'] as num?)?.toInt() ?? 0,
                coutManquant: item['cout_manquant'] == true,
                reference: item['reference']?.toString(),
              ),
          ],
          produitsCoutManquant: [
            for (final item in prodManqJson)
              ProduitCoutManquantItem(
                produitId: item['produit_id']?.toString() ?? '',
                nom: item['nom']?.toString() ?? '',
                uniteBase: item['unite_base']?.toString() ?? 'Pièce',
                reference: item['reference']?.toString(),
              ),
          ],
          pointsEvolution: [
            for (final item in evolJson)
              PointEvolutionBenefice(
                date: DateTime.tryParse(item['date']?.toString() ?? '') ?? DateTime.now(),
                label: item['label']?.toString() ?? '',
                chiffreAffaires: (item['chiffre_affaires'] as num?)?.toInt() ?? 0,
                cogs: (item['cogs'] as num?)?.toInt() ?? 0,
                margeBrute: (item['marge_brute'] as num?)?.toInt() ?? 0,
                depenses: (item['depenses'] as num?)?.toInt() ?? 0,
                beneficeNet: (item['benefice_net'] as num?)?.toInt() ?? 0,
              ),
          ],
          dateCalcul: DateTime.now(),
        );
      }
    }
  } catch (_) {
    // En cas de non-réponse du serveur ou mode hors-ligne, fallback transparent sur le calcul local
  }

  if (resultatLocal != null) {
    return resultatLocal;
  }

  throw StateError('Données en attente de synchronisation');
});

