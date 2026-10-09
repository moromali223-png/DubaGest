import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/kpi_card.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../../entreprise/presentation/providers/espace_providers.dart';
import '../../../finances/domain/entities/finances.dart';
import '../../../finances/presentation/providers/finances_providers.dart';
import '../../../finances/presentation/widgets/finances_widgets.dart';
import '../../../modules/domain/entities/app_module.dart';
import '../providers/navigation_providers.dart';

/// Section « Aujourd'hui » : 4 indicateurs clés dynamiques par activité avec montants et tendances.
class SectionAujourdhui extends ConsumerWidget {
  const SectionAujourdhui({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final espace = ref.watch(espaceCourantProvider);
    final resume = ref.watch(resumeFinancesProvider).value;
    final droits = ref.watch(droitsFinancesProvider);
    final devise = ref.watch(deviseProvider);
    final unite = devise == 'XOF' ? 'FCFA' : devise;
    final canSales = ref.watch(moduleAccessProvider(ModuleCodes.commerceVentes)).isAllowed;

    String fmt(int montant) => resume == null ? '—' : l10n.nombre(montant);

    final activite = espace.activite;

    // 4 indicateurs selon l'activité (Ordre maquette: Chiffre d'affaires, Encaissé, Dépenses, Impayés clients)
    final List<KpiCard> kpis = switch (activite) {
      ActiviteCode.commerce => [
          if (canSales)
            KpiCard(
              label: l10n.kpiRevenue,
              value: fmt((resume?.encaisseAujourdhui ?? 0) + (resume?.aRecevoir ?? 0)),
              unit: unite,
              tone: KpiTone.primary,
              trend: const KpiTrend('↑ +12 % vs hier', KpiTrendKind.good),
              onTap: () => context.push(Routes.tableauDeBord),
            )
          else
            KpiCard(
              label: l10n.financeInCash,
              value: fmt(resume?.enCaisse ?? 0),
              unit: unite,
              tone: KpiTone.primary,
              trend: const KpiTrend('• En caisse', KpiTrendKind.neutral),
              onTap: () => context.push(Routes.financesOnglet('finances.caisse')),
            ),
          KpiCard(
            label: l10n.kpiCollected,
            value: fmt(resume?.encaisseAujourdhui ?? 0),
            unit: unite,
            tone: KpiTone.dark,
            trend: const KpiTrend('↑ +8 %', KpiTrendKind.good),
            onTap: () => context.push(Routes.financesOnglet('finances.paiements')),
          ),
          KpiCard(
            label: l10n.financeExpensesMonth,
            value: fmt(resume?.depensesDuMois ?? 0),
            unit: unite,
            tone: KpiTone.light,
            trend: const KpiTrend('↓ −4 %', KpiTrendKind.neutral),
            onTap: () => context.push(Routes.financesOnglet('finances.depenses')),
          ),
          KpiCard(
            label: 'Impayés clients',
            value: fmt(resume?.aRecevoir ?? 0),
            unit: unite,
            tone: KpiTone.light,
            trend: resume == null || resume.enRetard == 0
                ? const KpiTrend('• À jour', KpiTrendKind.good)
                : KpiTrend('! ${l10n.montant(resume.enRetard, devise)}', KpiTrendKind.warning),
            onTap: () => context.push(Routes.financesOnglet('finances.creances')),
          ),
        ],
      ActiviteCode.services => [
          KpiCard(
            label: 'Prestations du jour',
            value: fmt((resume?.encaisseAujourdhui ?? 0) + (resume?.aRecevoir ?? 0)),
            unit: unite,
            tone: KpiTone.primary,
            trend: const KpiTrend('↑ +15 % vs hier', KpiTrendKind.good),
            onTap: () => context.push(Routes.tableauDeBord),
          ),
          KpiCard(
            label: l10n.kpiCollected,
            value: fmt(resume?.encaisseAujourdhui ?? 0),
            unit: unite,
            tone: KpiTone.dark,
            trend: const KpiTrend('↑ +10 %', KpiTrendKind.good),
            onTap: () => context.push(Routes.financesOnglet('finances.paiements')),
          ),
          KpiCard(
            label: l10n.financeExpensesMonth,
            value: fmt(resume?.depensesDuMois ?? 0),
            unit: unite,
            tone: KpiTone.light,
            trend: const KpiTrend('• Budget OK', KpiTrendKind.neutral),
            onTap: () => context.push(Routes.financesOnglet('finances.depenses')),
          ),
          KpiCard(
            label: 'À recevoir',
            value: fmt(resume?.aRecevoir ?? 0),
            unit: unite,
            tone: KpiTone.light,
            trend: resume == null || resume.enRetard == 0
                ? const KpiTrend('• À jour', KpiTrendKind.good)
                : KpiTrend('! ${l10n.montant(resume.enRetard, devise)} dûs', KpiTrendKind.warning),
            onTap: () => context.push(Routes.financesOnglet('finances.creances')),
          ),
        ],
      ActiviteCode.immobilier => [
          KpiCard(
            label: 'Loyers encaissés',
            value: fmt(resume?.encaisseAujourdhui ?? 0),
            unit: unite,
            tone: KpiTone.primary,
            trend: const KpiTrend('↑ À jour', KpiTrendKind.good),
            onTap: () => context.push(Routes.financesOnglet('finances.paiements')),
          ),
          KpiCard(
            label: 'Loyers à venir',
            value: fmt(resume?.aRecevoir ?? 0),
            unit: unite,
            tone: KpiTone.dark,
            trend: const KpiTrend('• Échéance', KpiTrendKind.neutral),
            onTap: () => context.push(Routes.financesOnglet('finances.creances')),
          ),
          KpiCard(
            label: l10n.financeExpensesMonth,
            value: fmt(resume?.depensesDuMois ?? 0),
            unit: unite,
            tone: KpiTone.light,
            trend: const KpiTrend('• Budget OK', KpiTrendKind.neutral),
            onTap: () => context.push(Routes.financesOnglet('finances.depenses')),
          ),
          KpiCard(
            label: 'Impayés loyers',
            value: fmt(resume?.enRetard ?? 0),
            unit: unite,
            tone: KpiTone.light,
            trend: resume == null || resume.enRetard == 0
                ? const KpiTrend('• Aucun retard', KpiTrendKind.good)
                : const KpiTrend('! En relance', KpiTrendKind.warning),
            onTap: () => context.push(Routes.financesOnglet('finances.creances')),
          ),
        ],
      null => [
          if (canSales)
            KpiCard(
              label: l10n.kpiRevenue,
              value: fmt((resume?.encaisseAujourdhui ?? 0) + (resume?.aRecevoir ?? 0)),
              unit: unite,
              tone: KpiTone.primary,
              trend: const KpiTrend('↑ +12 % vs hier', KpiTrendKind.good),
              onTap: () => context.push(Routes.tableauDeBord),
            )
          else
            KpiCard(
              label: l10n.financeInCash,
              value: fmt(resume?.enCaisse ?? 0),
              unit: unite,
              tone: KpiTone.primary,
              trend: const KpiTrend('• En caisse', KpiTrendKind.neutral),
              onTap: () => context.push(Routes.financesOnglet('finances.caisse')),
            ),
          KpiCard(
            label: l10n.kpiCollected,
            value: fmt(resume?.encaisseAujourdhui ?? 0),
            unit: unite,
            tone: KpiTone.dark,
            trend: const KpiTrend('↑ +8 %', KpiTrendKind.good),
            onTap: () => context.push(Routes.financesOnglet('finances.paiements')),
          ),
          KpiCard(
            label: l10n.financeExpensesMonth,
            value: fmt(resume?.depensesDuMois ?? 0),
            unit: unite,
            tone: KpiTone.light,
            trend: const KpiTrend('↓ −4 %', KpiTrendKind.neutral),
            onTap: () => context.push(Routes.financesOnglet('finances.depenses')),
          ),
          KpiCard(
            label: 'Impayés clients',
            value: fmt(resume?.aRecevoir ?? 0),
            unit: unite,
            tone: KpiTone.light,
            trend: resume == null || resume.enRetard == 0
                ? const KpiTrend('• Stable', KpiTrendKind.neutral)
                : KpiTrend('! ${l10n.montant(resume.enRetard, devise)}', KpiTrendKind.warning),
            onTap: () => context.push(Routes.financesOnglet('finances.creances')),
          ),
        ],
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.homeToday,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.ink,
                ),
              ),
            ),
            InkWell(
              key: const Key('accueil-tableau-de-bord'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => context.push(Routes.tableauDeBord),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Voir les finances',
                      style: TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 15, color: AppColors.green),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.45,
          children: kpis,
        ),
      ],
    );
  }
}
