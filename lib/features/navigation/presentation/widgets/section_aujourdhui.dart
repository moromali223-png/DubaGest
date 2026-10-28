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

import '../../../commerce/domain/entities/commerce.dart';
import '../../../commerce/presentation/commerce_providers.dart';

/// Section « Aujourd'hui » : 4 indicateurs clés dynamiques par activité avec montants réels et tendances calculées.
class SectionAujourdhui extends ConsumerWidget {
  const SectionAujourdhui({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final espace = ref.watch(espaceCourantProvider);
    final resume = ref.watch(resumeFinancesProvider).value;
    final etatFinances = ref.watch(etatFinancesEspaceProvider).value;
    final etatCommerce = ref.watch(etatCommerceProvider).value;
    final devise = ref.watch(deviseProvider);
    final unite = devise == 'XOF' ? 'FCFA' : devise;
    final canSales = ref.watch(moduleAccessProvider(ModuleCodes.commerceVentes)).isAllowed;
    final canExpenses = ref.watch(moduleAccessProvider(ModuleCodes.financesDepenses)).isAllowed;
    final canPayments = ref.watch(moduleAccessProvider(ModuleCodes.financesPaiements)).isAllowed;
    final canReceivables = ref.watch(moduleAccessProvider(ModuleCodes.financesCreances)).isAllowed;

    String fmt(int montant) => l10n.nombre(montant);

    final maintenant = DateTime.now();
    final jourAujourdhui = DateTime(maintenant.year, maintenant.month, maintenant.day);
    final jourHier = jourAujourdhui.subtract(const Duration(days: 1));
    final strJourAujourdhui = jourCommercial(maintenant);
    final strJourHier = jourCommercial(jourHier);

    bool estCeJour(DateTime d, DateTime cible) {
      final l = d.toLocal();
      return l.year == cible.year && l.month == cible.month && l.day == cible.day;
    }

    bool correspondJourVente(Vente v, DateTime cible, String strCible) {
      if (v.dateCommerciale != null && v.dateCommerciale!.isNotEmpty) {
        final dc = v.dateCommerciale!.replaceAll('-', '');
        final sc = strCible.replaceAll('-', '');
        if (dc == sc) return true;
      }
      return estCeJour(v.date, cible);
    }

    // 1. Calcul réel des ventes Commerce du jour vs hier
    final ventesAujourdhui = [
      if (etatCommerce != null)
        for (final v in etatCommerce.ventes)
          if (!v.annulee && !v.refuse && correspondJourVente(v, jourAujourdhui, strJourAujourdhui))
            if (espace.perimetreId == null || v.perimetreId == espace.perimetreId) v,
    ];
    final totalVentesAujourdhui = ventesAujourdhui.fold(0, (s, v) => s + v.total);

    final ventesHier = [
      if (etatCommerce != null)
        for (final v in etatCommerce.ventes)
          if (!v.annulee && !v.refuse && correspondJourVente(v, jourHier, strJourHier))
            if (espace.perimetreId == null || v.perimetreId == espace.perimetreId) v,
    ];
    final totalVentesHier = ventesHier.fold(0, (s, v) => s + v.total);

    final KpiTrend badgeVentesCommerce;
    if (totalVentesHier > 0) {
      final diff = ((totalVentesAujourdhui - totalVentesHier) / totalVentesHier * 100).round();
      if (diff > 0) {
        badgeVentesCommerce = KpiTrend('↑ +$diff %', KpiTrendKind.good);
      } else if (diff < 0) {
        badgeVentesCommerce = KpiTrend('↓ $diff %', KpiTrendKind.bad);
      } else {
        badgeVentesCommerce = const KpiTrend('• Stable', KpiTrendKind.neutral);
      }
    } else if (totalVentesAujourdhui > 0) {
      badgeVentesCommerce = const KpiTrend('↑ +100 %', KpiTrendKind.good);
    } else {
      badgeVentesCommerce = const KpiTrend('• 0 %', KpiTrendKind.neutral);
    }

    final int nbVentes = ventesAujourdhui.length;
    final KpiTrend trendVentesCommerce = KpiTrend(
      nbVentes > 0 ? '• $nbVentes vente${nbVentes > 1 ? "s" : ""} ce jour' : '• 0 vente ce jour',
      nbVentes > 0 ? KpiTrendKind.good : KpiTrendKind.neutral,
    );

    // 2. Encaissements réels du jour vs hier (Finances + Ventes directes réglées)
    final paiementsFinancesAujourdhui = [
      if (etatFinances != null)
        for (final p in etatFinances.paiements)
          if (etatFinances.compte(p) && p.sens == SensPaiement.entree && estCeJour(p.datePaiement, jourAujourdhui))
            if (espace.perimetreId == null || p.perimetreId == espace.perimetreId) p,
    ];
    final idsPaiementsAujourdhui = {for (final p in paiementsFinancesAujourdhui) p.id};
    final encaisseVentesDirectesAujourdhui = [
      for (final v in ventesAujourdhui)
        if (v.montantPaye > 0 && (v.paiementId == null || !idsPaiementsAujourdhui.contains(v.paiementId)))
          v.montantPaye,
    ].fold(0, (s, m) => s + m);
    final totalEncaisseAujourdhui =
        paiementsFinancesAujourdhui.fold(0, (s, p) => s + p.montant) + encaisseVentesDirectesAujourdhui;

    final paiementsFinancesHier = [
      if (etatFinances != null)
        for (final p in etatFinances.paiements)
          if (etatFinances.compte(p) && p.sens == SensPaiement.entree && estCeJour(p.datePaiement, jourHier))
            if (espace.perimetreId == null || p.perimetreId == espace.perimetreId) p,
    ];
    final idsPaiementsHier = {for (final p in paiementsFinancesHier) p.id};
    final encaisseVentesDirectesHier = [
      for (final v in ventesHier)
        if (v.montantPaye > 0 && (v.paiementId == null || !idsPaiementsHier.contains(v.paiementId)))
          v.montantPaye,
    ].fold(0, (s, m) => s + m);
    final totalEncaisseHier =
        paiementsFinancesHier.fold(0, (s, p) => s + p.montant) + encaisseVentesDirectesHier;

    final KpiTrend badgeEncaisse;
    if (totalEncaisseHier > 0) {
      final diff = ((totalEncaisseAujourdhui - totalEncaisseHier) / totalEncaisseHier * 100).round();
      if (diff > 0) {
        badgeEncaisse = KpiTrend('↑ +$diff %', KpiTrendKind.good);
      } else if (diff < 0) {
        badgeEncaisse = KpiTrend('↓ $diff %', KpiTrendKind.bad);
      } else {
        badgeEncaisse = const KpiTrend('• Stable', KpiTrendKind.neutral);
      }
    } else if (totalEncaisseAujourdhui > 0) {
      badgeEncaisse = const KpiTrend('↑ +100 %', KpiTrendKind.good);
    } else {
      badgeEncaisse = const KpiTrend('• 0 %', KpiTrendKind.neutral);
    }

    final KpiTrend trendEncaisse = KpiTrend(
      totalEncaisseAujourdhui > 0 ? '• Encaissé ce jour' : '• 0 encaissé ce jour',
      totalEncaisseAujourdhui > 0 ? KpiTrendKind.good : KpiTrendKind.neutral,
    );

    // 3. Dépenses réelles du mois vs mois précédent
    final depensesMois = etatFinances?.depenses
        .where((d) => etatFinances.depenseComptee(d) && d.dateDepense.toLocal().year == maintenant.year && d.dateDepense.toLocal().month == maintenant.month)
        .where((d) => espace.perimetreId == null || d.perimetreId == espace.perimetreId)
        .fold(0, (s, d) => s + d.montant) ?? (resume?.depensesDuMois ?? 0);

    final moisDernier = DateTime(maintenant.year, maintenant.month - 1, 1);
    final depensesMoisDernier = etatFinances?.depenses
        .where((d) => etatFinances.depenseComptee(d) && d.dateDepense.toLocal().year == moisDernier.year && d.dateDepense.toLocal().month == moisDernier.month)
        .where((d) => espace.perimetreId == null || d.perimetreId == espace.perimetreId)
        .fold(0, (s, d) => s + d.montant) ?? 0;

    final countDepensesMois = etatFinances?.depenses
        .where((d) => etatFinances.depenseComptee(d) && d.dateDepense.toLocal().year == maintenant.year && d.dateDepense.toLocal().month == maintenant.month)
        .where((d) => espace.perimetreId == null || d.perimetreId == espace.perimetreId)
        .length ?? 0;

    final KpiTrend badgeDepenses;
    if (depensesMoisDernier > 0) {
      final diff = ((depensesMois - depensesMoisDernier) / depensesMoisDernier * 100).round();
      if (diff > 0) {
        badgeDepenses = KpiTrend('↑ +$diff %', KpiTrendKind.warning);
      } else if (diff < 0) {
        badgeDepenses = KpiTrend('↓ $diff %', KpiTrendKind.good);
      } else {
        badgeDepenses = const KpiTrend('• Stable', KpiTrendKind.neutral);
      }
    } else if (depensesMois > 0) {
      badgeDepenses = const KpiTrend('• 1er mois', KpiTrendKind.neutral);
    } else {
      badgeDepenses = const KpiTrend('• 0 %', KpiTrendKind.neutral);
    }

    final KpiTrend trendDepenses = KpiTrend(
      countDepensesMois > 0
          ? '• $countDepensesMois dépense${countDepensesMois > 1 ? "s" : ""} ce mois'
          : '• 0 dépense ce mois',
      KpiTrendKind.neutral,
    );

    // 4. Créances / Impayés clients réels
    final aRecevoir = resume?.aRecevoir ?? 0;
    final enRetard = resume?.enRetard ?? 0;

    final KpiTrend badgeCreances;
    if (enRetard > 0) {
      badgeCreances = const KpiTrend('! Retard', KpiTrendKind.warning);
    } else if (aRecevoir > 0) {
      badgeCreances = const KpiTrend('• Stable', KpiTrendKind.neutral);
    } else {
      badgeCreances = const KpiTrend('• À jour', KpiTrendKind.good);
    }

    final KpiTrend trendCreances = aRecevoir == 0
        ? const KpiTrend('• Aucune créance', KpiTrendKind.good)
        : (enRetard == 0
            ? const KpiTrend('• Échéances à jour', KpiTrendKind.good)
            : KpiTrend('! ${l10n.montant(enRetard, devise)} en retard', KpiTrendKind.warning));

    // 5. Prestations Services réelles du jour vs hier
    final prestationsDuJour = [
      if (etatFinances != null)
        for (final e in etatFinances.engagements)
          if (!e.annule && !e.refuse && e.sens == SensEngagement.aRecevoir && (e.activite == ActiviteCode.services || e.origineType == 'PRESTATION' || e.origineType == 'INTERVENTION') && estCeJour(e.dateEngagement, jourAujourdhui))
            if (espace.perimetreId == null || e.perimetreId == espace.perimetreId) e,
    ];
    final totalPrestationsDuJour = prestationsDuJour.fold(0, (s, e) => s + e.montantTotal);
    final caServicesJour = totalPrestationsDuJour > 0 ? totalPrestationsDuJour : totalVentesAujourdhui;

    final prestationsHier = [
      if (etatFinances != null)
        for (final e in etatFinances.engagements)
          if (!e.annule && !e.refuse && e.sens == SensEngagement.aRecevoir && (e.activite == ActiviteCode.services || e.origineType == 'PRESTATION' || e.origineType == 'INTERVENTION') && estCeJour(e.dateEngagement, jourHier))
            if (espace.perimetreId == null || e.perimetreId == espace.perimetreId) e,
    ];
    final totalPrestationsHier = prestationsHier.fold(0, (s, e) => s + e.montantTotal);
    final caServicesHier = totalPrestationsHier > 0 ? totalPrestationsHier : totalVentesHier;

    final KpiTrend badgeServices;
    if (caServicesHier > 0) {
      final diff = ((caServicesJour - caServicesHier) / caServicesHier * 100).round();
      if (diff > 0) {
        badgeServices = KpiTrend('↑ +$diff %', KpiTrendKind.good);
      } else if (diff < 0) {
        badgeServices = KpiTrend('↓ $diff %', KpiTrendKind.bad);
      } else {
        badgeServices = const KpiTrend('• Stable', KpiTrendKind.neutral);
      }
    } else if (caServicesJour > 0) {
      badgeServices = const KpiTrend('↑ +100 %', KpiTrendKind.good);
    } else {
      badgeServices = const KpiTrend('• 0 %', KpiTrendKind.neutral);
    }

    final trendServices = caServicesJour > 0
        ? KpiTrend('• ${prestationsDuJour.isNotEmpty ? prestationsDuJour.length : nbVentes} acte(s) ce jour', KpiTrendKind.good)
        : const KpiTrend('• 0 prestation ce jour', KpiTrendKind.neutral);

    // 6. Loyers Immobilier
    final loyersMois = etatFinances?.paiements
        .where((p) => etatFinances.compte(p) && (p.activite == ActiviteCode.immobilier || p.nature == NaturePaiement.autre) && p.sens == SensPaiement.entree && p.datePaiement.toLocal().year == maintenant.year && p.datePaiement.toLocal().month == maintenant.month)
        .where((p) => espace.perimetreId == null || p.perimetreId == espace.perimetreId)
        .fold(0, (s, p) => s + p.montant) ?? 0;
    final loyersAVenir = etatFinances?.suivis
        .where((s) => !s.engagement.annule && !s.engagement.refuse && (s.engagement.activite == ActiviteCode.immobilier || s.engagement.origineType == 'LOYER') && s.engagement.sens == SensEngagement.aRecevoir)
        .where((s) => espace.perimetreId == null || s.engagement.perimetreId == espace.perimetreId)
        .fold(0, (sum, s) => sum + s.reste) ?? 0;
    final trendImmo = loyersMois > 0 ? const KpiTrend('• Encaissé ce mois', KpiTrendKind.good) : const KpiTrend('• Aucun loyer perçu', KpiTrendKind.neutral);

    final activite = espace.activite;

    // 4 indicateurs selon l'activité (Ordre maquette: Chiffre d'affaires, Encaissé, Dépenses, Impayés clients)
    final List<KpiCard> kpis = switch (activite) {
      ActiviteCode.commerce => [
          if (canSales)
            KpiCard(
              label: l10n.kpiRevenue,
              value: fmt(totalVentesAujourdhui),
              unit: unite,
              tone: KpiTone.primary,
              badge: badgeVentesCommerce,
              trend: trendVentesCommerce,
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
          if (canPayments)
            KpiCard(
              label: l10n.kpiCollected,
              value: fmt(totalEncaisseAujourdhui),
              unit: unite,
              tone: KpiTone.dark,
              badge: badgeEncaisse,
              trend: trendEncaisse,
              onTap: () => context.push(Routes.financesOnglet('finances.paiements')),
            )
          else
            KpiCard(
              label: 'Mouvements Stock',
              value: '${etatCommerce?.resume([if (espace.perimetreId != null) espace.perimetreId!]).mouvementsDuJour ?? 0}',
              unit: 'flux',
              tone: KpiTone.dark,
              trend: const KpiTrend('• Aujourd\'hui', KpiTrendKind.neutral),
              onTap: () => context.push(Routes.mouvementsStock),
            ),
          if (canExpenses)
            KpiCard(
              label: l10n.financeExpensesMonth,
              value: fmt(depensesMois),
              unit: unite,
              tone: KpiTone.light,
              badge: badgeDepenses,
              trend: trendDepenses,
              onTap: () => context.push(Routes.financesOnglet('finances.depenses')),
            )
          else
            KpiCard(
              label: 'Valeur Stock',
              value: fmt(etatCommerce?.resume([if (espace.perimetreId != null) espace.perimetreId!]).valeurStock ?? 0),
              unit: unite,
              tone: KpiTone.light,
              trend: const KpiTrend('• Valeur marchande', KpiTrendKind.good),
              onTap: () => context.push(Routes.stock),
            ),
          if (canReceivables)
            KpiCard(
              label: 'Impayés clients',
              value: fmt(aRecevoir),
              unit: unite,
              tone: KpiTone.light,
              badge: badgeCreances,
              trend: trendCreances,
              onTap: () => context.push(Routes.financesOnglet('finances.creances')),
            )
          else
            KpiCard(
              label: 'Articles en stock',
              value: '${etatCommerce?.resume([if (espace.perimetreId != null) espace.perimetreId!]).totalArticlesEnStock ?? 0}',
              unit: 'unités',
              tone: KpiTone.light,
              trend: const KpiTrend('• Stock disponible', KpiTrendKind.good),
              onTap: () => context.push(Routes.stock),
            ),
        ],
      ActiviteCode.services => [
          KpiCard(
            label: 'Prestations du jour',
            value: fmt(caServicesJour),
            unit: unite,
            tone: KpiTone.primary,
            badge: badgeServices,
            trend: trendServices,
            onTap: () => context.push(Routes.tableauDeBord),
          ),
          KpiCard(
            label: l10n.kpiCollected,
            value: fmt(totalEncaisseAujourdhui),
            unit: unite,
            tone: KpiTone.dark,
            badge: badgeEncaisse,
            trend: trendEncaisse,
            onTap: () => context.push(Routes.financesOnglet('finances.paiements')),
          ),
          KpiCard(
            label: l10n.financeExpensesMonth,
            value: fmt(depensesMois),
            unit: unite,
            tone: KpiTone.light,
            badge: badgeDepenses,
            trend: trendDepenses,
            onTap: () => context.push(Routes.financesOnglet('finances.depenses')),
          ),
          KpiCard(
            label: 'À recevoir',
            value: fmt(aRecevoir),
            unit: unite,
            tone: KpiTone.light,
            badge: badgeCreances,
            trend: trendCreances,
            onTap: () => context.push(Routes.financesOnglet('finances.creances')),
          ),
        ],
      ActiviteCode.immobilier => [
          KpiCard(
            label: 'Loyers encaissés',
            value: fmt(loyersMois),
            unit: unite,
            tone: KpiTone.primary,
            trend: trendImmo,
            onTap: () => context.push(Routes.immobilierLoyers),
          ),
          KpiCard(
            label: 'Loyers à venir',
            value: fmt(loyersAVenir),
            unit: unite,
            tone: KpiTone.dark,
            trend: const KpiTrend('• Échéances', KpiTrendKind.neutral),
            onTap: () => context.push(Routes.immobilierLoyers),
          ),
          KpiCard(
            label: l10n.financeExpensesMonth,
            value: fmt(depensesMois),
            unit: unite,
            tone: KpiTone.light,
            badge: badgeDepenses,
            trend: trendDepenses,
            onTap: () => context.push(Routes.financesOnglet('finances.depenses')),
          ),
          KpiCard(
            label: 'Impayés loyers',
            value: fmt(enRetard),
            unit: unite,
            tone: KpiTone.light,
            badge: badgeCreances,
            trend: trendCreances,
            onTap: () => context.push(Routes.immobilierLoyers),
          ),
        ],
      null => [
          if (canSales)
            KpiCard(
              label: l10n.kpiRevenue,
              value: fmt(totalVentesAujourdhui + totalPrestationsDuJour),
              unit: unite,
              tone: KpiTone.primary,
              badge: badgeVentesCommerce,
              trend: trendVentesCommerce,
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
            value: fmt(totalEncaisseAujourdhui),
            unit: unite,
            tone: KpiTone.dark,
            badge: badgeEncaisse,
            trend: trendEncaisse,
            onTap: () => context.push(Routes.financesOnglet('finances.paiements')),
          ),
          KpiCard(
            label: l10n.financeExpensesMonth,
            value: fmt(depensesMois),
            unit: unite,
            tone: KpiTone.light,
            badge: badgeDepenses,
            trend: trendDepenses,
            onTap: () => context.push(Routes.financesOnglet('finances.depenses')),
          ),
          KpiCard(
            label: 'Impayés clients',
            value: fmt(aRecevoir),
            unit: unite,
            tone: KpiTone.light,
            badge: badgeCreances,
            trend: trendCreances,
            onTap: () => context.push(Routes.financesOnglet('finances.creances')),
          ),
        ],
    };

    final estImmo = espace.activite == ActiviteCode.immobilier;

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
              onTap: () => context.push(estImmo ? Routes.immobilierDashboard : Routes.tableauDeBord),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      estImmo ? 'Tableau de bord immo' : 'Voir les finances',
                      style: const TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 15, color: AppColors.green),
                  ],
                ),
              ),
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 380;
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: isSmall ? 1.25 : 1.34,
              children: kpis,
            );
          },
        ),
      ],
    );
  }
}
