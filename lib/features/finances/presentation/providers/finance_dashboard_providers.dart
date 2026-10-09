import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../activites/domain/entities/activite.dart';
import '../../../commerce/presentation/commerce_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/finance_dashboard_data.dart';
import '../../domain/entities/finance_period_filter.dart';
import '../../domain/services/calcul_finances_engine.dart';
import 'finances_providers.dart';

/// Notifier pour gérer la période financière sélectionnée.
class FinancePeriodNotifier extends Notifier<FiltrePeriodeFinance> {
  @override
  FiltrePeriodeFinance build() => const FiltrePeriodeFinance(type: TypePeriodeFinance.ceMois);

  void choisir(TypePeriodeFinance type, {DateTime? debut, DateTime? fin}) {
    state = FiltrePeriodeFinance(
      type: type,
      debutPersonnalise: debut,
      finPersonnalise: fin,
    );
  }
}

final financePeriodFilterProvider =
    NotifierProvider<FinancePeriodNotifier, FiltrePeriodeFinance>(FinancePeriodNotifier.new);

/// Notifier pour filtrer par activité (Commerce, Services, Immobilier, null = tout).
class FinanceActiviteFilterNotifier extends Notifier<ActiviteCode?> {
  @override
  ActiviteCode? build() => null;

  void filtrer(ActiviteCode? a) => state = a;
}

final financeActiviteFilterProvider =
    NotifierProvider<FinanceActiviteFilterNotifier, ActiviteCode?>(FinanceActiviteFilterNotifier.new);

/// Notifier pour filtrer par boutique / site (null = toutes les boutiques accessibles).
class FinancePerimetreFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void filtrer(String? perimetreId) => state = perimetreId;
}

final financePerimetreFilterProvider =
    NotifierProvider<FinancePerimetreFilterNotifier, String?>(FinancePerimetreFilterNotifier.new);

final calculFinancesEngineProvider = Provider((ref) => const CalculFinancesEngine());

/// Données financières consolidées et calculées du tableau de bord.
final financeDashboardDataProvider = Provider.autoDispose<AsyncValue<FinanceDashboardData>>((ref) {
  final etatFinancesAsync = ref.watch(etatFinancesProvider);
  final etatCommerceAsync = ref.watch(etatCommerceProvider);
  final ctx = ref.watch(contexteActifProvider);
  final engine = ref.watch(calculFinancesEngineProvider);
  final periode = ref.watch(financePeriodFilterProvider);
  final activiteFiltre = ref.watch(financeActiviteFilterProvider);
  final perimetreFiltre = ref.watch(financePerimetreFilterProvider);

  if (etatFinancesAsync.isLoading || (etatCommerceAsync.isLoading && ctx?.activites.any((a) => a.activite == ActiviteCode.commerce) == true)) {
    return const AsyncValue.loading();
  }

  if (etatFinancesAsync.hasError) {
    return AsyncValue.error(etatFinancesAsync.error!, etatFinancesAsync.stackTrace!);
  }

  final etatFinances = etatFinancesAsync.value;
  if (etatFinances == null) {
    return const AsyncValue.loading();
  }

  final etatCommerce = etatCommerceAsync.value;

  final nomsPerimetres = {
    if (ctx != null)
      for (final p in ctx.perimetres) p.id: p.nom,
  };

  final activiteDesPerimetres = {
    if (ctx != null)
      for (final p in ctx.perimetres) p.id: p.activite,
  };

  final data = engine.calculer(
    etatFinances: etatFinances,
    etatCommerce: etatCommerce,
    periodeFiltre: periode,
    maintenant: DateTime.now(),
    activiteFiltre: activiteFiltre,
    perimetreIdFiltre: perimetreFiltre,
    nomsPerimetres: nomsPerimetres,
    activiteDesPerimetres: activiteDesPerimetres,
  );

  return AsyncValue.data(data);
});
