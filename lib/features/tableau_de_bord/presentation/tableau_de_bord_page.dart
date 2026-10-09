import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../../app/localization/l10n.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/kpi_card.dart';
import '../../../shared/widgets/responsive_body.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/sync_status_button.dart';
import '../../entreprise/presentation/widgets/espace_selector.dart';
import '../../finances/presentation/providers/finances_providers.dart';
import '../../finances/presentation/widgets/finances_widgets.dart';
import '../../modules/domain/entities/app_module.dart';
import '../domain/tableau_de_bord.dart';

/// Couleurs des graphiques : paire catégorielle validée (daltonisme compris)
/// sur fond blanc. Le vert de la marque face à l'orange échoue au test de
/// séparation protan (ΔE 4,4) : il reste réservé à l'interface.
abstract final class CouleursGraphiques {
  static const entrees = Color(0xFF2A78D6);
  static const sorties = Color(0xFFEB6834);
  static const grille = Color(0xFFE1E8E4);
  static const axe = Color(0xFF898781);
}

class PeriodeNotifier extends Notifier<PeriodeTableau> {
  @override
  PeriodeTableau build() => PeriodeTableau.septJours;
  void choisir(PeriodeTableau p) => state = p;
}

final periodeTableauProvider = NotifierProvider<PeriodeNotifier, PeriodeTableau>(PeriodeNotifier.new);

final tableauDeBordProvider = Provider.autoDispose<AsyncValue<TableauDeBord>>((ref) {
  final periode = ref.watch(periodeTableauProvider);
  return ref
      .watch(etatFinancesEspaceProvider)
      .whenData((etat) => TableauDeBord.calculer(etat, periode: periode, maintenant: DateTime.now()));
});

/// Tableau de bord : chiffres réels de l'espace de travail choisi.
class TableauDeBordPage extends ConsumerWidget {
  const TableauDeBordPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final periode = ref.watch(periodeTableauProvider);
    final droits = ref.watch(droitsFinancesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dashboardTitle), actions: const [SyncStatusButton()]),
      body: ResponsiveBody(
        maxWidth: 960,
        child: AsyncValueView(
          value: ref.watch(tableauDeBordProvider),
          onRetry: () => ref.invalidate(etatFinancesProvider),
          data: (t) => ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // Filtres sur une seule ligne, au-dessus des graphiques.
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const EspaceSelector(),
                  SegmentedButton<PeriodeTableau>(
                    segments: [
                      ButtonSegment(value: PeriodeTableau.septJours, label: Text(l10n.dashboard7Days)),
                      ButtonSegment(value: PeriodeTableau.trenteJours, label: Text(l10n.dashboard30Days)),
                      ButtonSegment(value: PeriodeTableau.moisEnCours, label: Text(l10n.dashboardMonth)),
                    ],
                    selected: {periode},
                    onSelectionChanged: (s) => ref.read(periodeTableauProvider.notifier).choisir(s.first),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _Indicateurs(t: t),
              if (t.vide)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.lg),
                  child: EmptyView(icon: Icons.insights_outlined, message: l10n.dashboardEmpty),
                ),
              if (droits.voirPaiements && (t.encaisse > 0 || t.verse > 0)) ...[
                const SizedBox(height: AppSpacing.lg),
                _Carte(titre: l10n.dashboardFlows, child: _GraphiqueFlux(t: t)),
              ],
              if (droits.voirDepenses && t.parCategorie.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _Carte(titre: l10n.dashboardExpensesByCategory, child: _DepensesParCategorie(t: t)),
              ],
              if (droits.voirCreances && t.debiteurs.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _Carte(titre: l10n.dashboardTopDebtors, child: _Debiteurs(t: t)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Indicateurs extends ConsumerWidget {
  const _Indicateurs({required this.t});
  final TableauDeBord t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final droits = ref.watch(droitsFinancesProvider);
    final devise = ref.watch(deviseProvider);
    final unite = devise == 'XOF' ? 'FCFA' : devise;
    final r = t.resume;
    final cartes = [
      if (droits.voirPaiements) ...[
        KpiCard(label: l10n.dashboardCollected, value: l10n.nombre(t.encaisse), unit: unite, tone: KpiTone.primary),
        KpiCard(label: l10n.dashboardPaidOut, value: l10n.nombre(t.verse), unit: unite),
        KpiCard(
          label: l10n.dashboardNet,
          value: '${t.net < 0 ? '−' : ''}${l10n.nombre(t.net.abs())}',
          unit: unite,
          tone: KpiTone.dark,
        ),
      ],
      if (droits.voirDepenses) KpiCard(label: l10n.dashboardExpenses, value: l10n.nombre(t.depenses), unit: unite),
      if (droits.voirCreances) ...[
        KpiCard(
          label: l10n.financeToReceive,
          value: l10n.nombre(r.aRecevoir),
          unit: unite,
          trend: r.enRetard == 0
              ? null
              : KpiTrend(l10n.financeOverdueAmount(l10n.montant(r.enRetard, devise)), KpiTrendKind.bad),
        ),
        KpiCard(label: l10n.financeToPay, value: l10n.nombre(r.aPayer), unit: unite),
      ],
      if (droits.voirCaisse) KpiCard(label: l10n.financeInCash, value: l10n.nombre(r.enCaisse), unit: unite),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final colonnes = constraints.maxWidth >= 720 ? 4 : 2;
      final largeur = (constraints.maxWidth - AppSpacing.md * (colonnes - 1)) / colonnes;
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [for (final c in cartes) SizedBox(width: largeur, child: c)],
      );
    });
  }
}

class _Carte extends StatelessWidget {
  const _Carte({required this.titre, required this.child});
  final String titre;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(titre, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.md),
              child,
            ],
          ),
        ),
      );
}

/// Encaissé / versé par jour : colonnes groupées, une échelle, légende +
/// info-bulle au toucher (l'identité ne repose jamais sur la couleur seule).
class _GraphiqueFlux extends ConsumerWidget {
  const _GraphiqueFlux({required this.t});
  final TableauDeBord t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final devise = ref.watch(deviseProvider);
    final compact = NumberFormat.compact(locale: l10n.localeName);
    final jourCourt = DateFormat.d(l10n.localeName);
    final etiquetteJour = DateFormat.MMMd(l10n.localeName);
    final maxi = t.jours.fold(0, (m, j) => [m, j.entrees, j.sorties].reduce((a, b) => a > b ? a : b));
    final largeur = t.jours.length <= 7 ? 12.0 : 4.0;
    final pas = t.jours.length <= 7 ? 1 : 5;
    const style = TextStyle(fontSize: 11, color: CouleursGraphiques.axe);

    Widget legende(Color c, String texte) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            Text(texte, style: Theme.of(context).textTheme.bodySmall),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: AppSpacing.md, children: [
          legende(CouleursGraphiques.entrees, l10n.dashboardCollected),
          legende(CouleursGraphiques.sorties, l10n.dashboardPaidOut),
        ]),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 200,
          child: BarChart(
            key: const Key('graphique-flux'),
            BarChartData(
              maxY: maxi == 0 ? 1 : maxi * 1.15,
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(
                show: true,
                border: const Border(bottom: BorderSide(color: CouleursGraphiques.grille)),
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: maxi == 0 ? 1 : maxi * 1.15 / 4,
                getDrawingHorizontalLine: (_) => const FlLine(color: CouleursGraphiques.grille, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    // Quatre graduations : lisibles, sans chevauchement.
                    interval: maxi == 0 ? 1 : maxi * 1.15 / 4,
                    getTitlesWidget: (v, meta) => v == meta.max
                        ? const SizedBox.shrink()
                        : Text(compact.format(v), style: style, maxLines: 1, softWrap: false),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i % pas != 0 || i >= t.jours.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(jourCourt.format(t.jours[i].jour), style: style),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.ink,
                  getTooltipItem: (groupe, _, rod, indexRod) => BarTooltipItem(
                    '${etiquetteJour.format(t.jours[groupe.x].jour)}\n'
                    '${indexRod == 0 ? l10n.dashboardCollected : l10n.dashboardPaidOut} : '
                    '${l10n.montant(rod.toY.toInt(), devise)}',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              barGroups: [
                for (final (i, j) in t.jours.indexed)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 2,
                    barRods: [
                      for (final (valeur, couleur) in [
                        (j.entrees, CouleursGraphiques.entrees),
                        (j.sorties, CouleursGraphiques.sorties),
                      ])
                        BarChartRodData(
                          toY: valeur.toDouble(),
                          color: couleur,
                          width: largeur,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Une seule teinte (magnitude) ; barres triées avec montant écrit en clair
/// (sert aussi de vue tableau).
class _DepensesParCategorie extends StatelessWidget {
  const _DepensesParCategorie({required this.t});
  final TableauDeBord t;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final maxi = t.parCategorie.first.montant;
    return Column(
      children: [
        for (final p in t.parCategorie)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    p.categorie == null ? l10n.dashboardOtherCategories : l10n.categorieDepense(p.categorie),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) => Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                        height: 14,
                        width: (c.maxWidth * p.montant / maxi).clamp(4, c.maxWidth),
                        decoration: BoxDecoration(
                          color: CouleursGraphiques.entrees,
                          borderRadius: const BorderRadiusDirectional.horizontal(end: Radius.circular(4))
                              .resolve(Directionality.of(context)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Montant(p.montant, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Debiteurs extends ConsumerWidget {
  const _Debiteurs({required this.t});
  final TableauDeBord t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final contacts = ref.watch(contactsParIdProvider).value ?? const {};
    return Column(
      children: [
        for (final d in t.debiteurs)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(d.contactId == null ? l10n.financeNoContact : (contacts[d.contactId]?.nomAffiche ?? '…')),
            subtitle: !d.enRetard
                ? null
                : Row(children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.negative),
                    const SizedBox(width: 4),
                    Text(l10n.debtStateOverdue, style: const TextStyle(color: AppColors.negative)),
                  ]),
            trailing: Montant(d.montant),
            onTap: d.contactId == null ? null : () => context.push(Routes.contact(d.contactId!)),
          ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: () => context.go(Routes.financesOnglet(ModuleCodes.financesCreances)),
            child: Text(l10n.dashboardSeeAll),
          ),
        ),
      ],
    );
  }
}
