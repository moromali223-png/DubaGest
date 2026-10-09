import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/kpi_card.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../modules/domain/entities/app_module.dart';
import '../../../navigation/presentation/providers/navigation_providers.dart';
import '../../domain/entities/finances.dart';
import '../providers/finance_dashboard_providers.dart';
import '../providers/finances_providers.dart';
import '../widgets/caisse_dashboard_view.dart';
import '../widgets/card_creances_dettes.dart';
import '../widgets/card_performance_activites.dart';
import '../widgets/card_performance_boutiques.dart';
import '../widgets/card_prevision_tresorerie.dart';
import '../widgets/card_sante_financiere.dart';
import '../widgets/chart_depenses_categories.dart';
import '../widgets/chart_evolution_ca.dart';
import '../widgets/chart_evolution_tresorerie.dart';
import '../widgets/chart_marge_commerce.dart';
import '../widgets/chart_revenus_depenses.dart';
import '../widgets/finances_widgets.dart';
import '../widgets/header_filtres_financiers.dart';
import '../widgets/kpi_principaux_row.dart';
import '../widgets/section_alertes_financieres.dart';
import '../widgets/section_ce_qui_change.dart';
import '../widgets/dettes_vue_principale.dart';
import 'depenses_page.dart';

/// Module Finance Centralisé — Centre financier intelligent de DUBAGEST.
///
/// Sans [onglet] : la synthèse décisionnelle, avec plus bas l'accès aux
/// modules autorisés (pas de barre d'onglets en haut). Avec [onglet] : le
/// module seul, en plein écran, avec retour.
class FinancesPage extends ConsumerWidget {
  const FinancesPage({super.key, this.onglet});

  /// Code du module à ouvrir (`finances.caisse`…).
  final String? onglet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final modules = ref.watch(navigationModelProvider)?.modulesFinances ?? const <AppModule>[];
    if (modules.isEmpty) return const Scaffold(body: LoadingView());

    final module = modules.where((m) => m.code == onglet).firstOrNull;
    
    // Si on est dans un sous-module spécifique via le router, on garde la vue simple
    if (module != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.module(module.code)), actions: const [SyncStatusButton()]),
        body: switch (module.code) {
          ModuleCodes.financesCreances => const DettesVuePrincipale(),
          ModuleCodes.financesPaiements => const _OngletPaiements(),
          ModuleCodes.financesDepenses => const OngletDepenses(),
          _ => const _OngletCaisse(),
        },
      );
    }

    // Vue principale sans onglets en haut : Synthèse financière décisionnelle
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navFinances),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: 'Rapport financier',
            onPressed: () => context.push(Routes.financeRapport),
          ),
          const SyncStatusButton(),
        ],
      ),
      body: const _VueSyntheseFinances(),
    );
  }
}

/// Accès aux modules financiers autorisés : une carte par module, avec son
/// chiffre clé du moment. Placé sous les indicateurs, jamais en haut.
class _AccesModulesFinances extends ConsumerWidget {
  const _AccesModulesFinances();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final modules = ref.watch(navigationModelProvider)?.modulesFinances ?? const <AppModule>[];
    final resume = ref.watch(resumeFinancesProvider).value;
    final devise = ref.watch(deviseProvider);
    if (modules.isEmpty) return const SizedBox.shrink();

    (IconData, String?, String?) details(String code) => switch (code) {
      ModuleCodes.financesCreances => (
        Icons.swap_vert_rounded,
        resume == null ? null : '${l10n.financeToReceive} : ${l10n.montant(resume.aRecevoir, devise)}',
        resume == null ? null : '${l10n.financeToPay} : ${l10n.montant(resume.aPayer, devise)}',
      ),
      ModuleCodes.financesPaiements => (
        Icons.payments_outlined,
        resume == null ? null : '${l10n.kpiCollected} : ${l10n.montant(resume.encaisseAujourdhui, devise)}',
        l10n.periodToday,
      ),
      ModuleCodes.financesDepenses => (
        Icons.receipt_long_outlined,
        resume == null ? null : l10n.montant(resume.depensesDuMois, devise),
        l10n.financeExpensesMonth,
      ),
      _ => (
        Icons.point_of_sale_outlined,
        resume == null ? null : l10n.montant(resume.enCaisse, devise),
        l10n.financeInCash,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.financeManage, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, contraintes) {
            final colonnes = contraintes.maxWidth >= 720 ? 4 : 2;
            final largeur = (contraintes.maxWidth - AppSpacing.sm * (colonnes - 1)) / colonnes;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final m in modules)
                  SizedBox(
                    width: largeur,
                    child: _CarteModule(
                      key: Key('onglet-${m.code}'),
                      titre: l10n.module(m.code),
                      details: details(m.code),
                      onTap: () => context.push(Routes.financesOnglet(m.code)),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CarteModule extends StatelessWidget {
  const _CarteModule({super.key, required this.titre, required this.details, required this.onTap});
  final String titre;
  final (IconData, String?, String?) details;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icone, chiffre, legende) = details;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(12)),
                    child: Icon(icone, color: AppColors.green, size: 20),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.muted),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                titre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.2),
              ),
              const SizedBox(height: 4),
              Text(
                chiffre ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.green, fontSize: 13),
              ),
              if (legende != null)
                Text(
                  legende,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vue d'ensemble décisionnelle et intelligente (« Synthèse »).
class _VueSyntheseFinances extends ConsumerWidget {
  const _VueSyntheseFinances();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(financeDashboardDataProvider);

    return ResponsiveBody(
      maxWidth: 1040,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(etatFinancesProvider);
        },
        child: AsyncValueView(
          value: dataAsync,
          onRetry: () => ref.invalidate(etatFinancesProvider),
          data: (data) {
            if (data.donneesVides) {
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  HeaderFiltresFinanciers(
                    onActualiser: () => ref.invalidate(etatFinancesProvider),
                    onExporter: () => context.push(Routes.financeRapport),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.insights_rounded, size: 48, color: AppColors.muted),
                        SizedBox(height: AppSpacing.md),
                        Text(
                          'Pas encore assez de données',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                        ),
                        SizedBox(height: 6),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Les statistiques financières apparaîtront dès que votre activité aura enregistré ses premières opérations.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const _AccesModulesFinances(),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 96),
              children: [
                // 1. Filtres
                HeaderFiltresFinanciers(
                  onActualiser: () => ref.invalidate(etatFinancesProvider),
                  onExporter: () => context.push(Routes.financeRapport),
                ),
                const SizedBox(height: AppSpacing.md),

                // 2. Santé financière
                CardSanteFinanciere(sante: data.sante, onTap: () => context.push(Routes.financeRapport)),
                const SizedBox(height: AppSpacing.md),

                // 3. 5 KPI Majeurs
                KpiPrincipauxRow(
                  data: data,
                  onTapCA: () => context.push(Routes.financeRevenus),
                  onTapResultat: () => context.push(Routes.financeRapport),
                  onTapTresorerie: () => context.push(Routes.financeTresorerie),
                  onTapARecevoir: () => context.push(Routes.financeCreancesDettes),
                  onTapAPayer: () => context.push(Routes.financeCreancesDettes),
                ),
                const SizedBox(height: AppSpacing.lg),

                // 3 bis. Accès aux modules (sous les indicateurs, pas en haut)
                const _AccesModulesFinances(),
                const SizedBox(height: AppSpacing.lg),

                // 4. Évolution du CA
                ChartEvolutionCA(serie: data.serieEvolutionCA, onTapDetail: () => context.push(Routes.financeRevenus)),
                const SizedBox(height: AppSpacing.lg),

                // 5. Revenus vs Dépenses & Trésorerie
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoCols = constraints.maxWidth >= 720;
                    if (twoCols) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ChartRevenusDepenses(
                              totalRevenus: data.totalRevenus,
                              totalDepenses: data.totalDepenses,
                              onTapDetail: () => context.push(Routes.financeCharges),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: ChartEvolutionTresorerie(
                              serie: data.serieEvolutionTresorerie,
                              onTapDetail: () => context.push(Routes.financeTresorerie),
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        ChartRevenusDepenses(
                          totalRevenus: data.totalRevenus,
                          totalDepenses: data.totalDepenses,
                          onTapDetail: () => context.push(Routes.financeCharges),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ChartEvolutionTresorerie(
                          serie: data.serieEvolutionTresorerie,
                          onTapDetail: () => context.push(Routes.financeTresorerie),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // 6. Marge brute (si Commerce actif)
                if (data.margeCommerce != null && data.margeCommerce!.chiffreAffairesCommerce > 0) ...[
                  ChartMargeCommerce(marge: data.margeCommerce!),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // 7. Créances vs Dettes & Dépenses par catégorie
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoCols = constraints.maxWidth >= 720;
                    if (twoCols) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: CardCreancesDettes(
                              aRecevoir: data.aRecevoir.valeurActuelle,
                              nombreDebiteurs: data.nombreClientsDebiteurs,
                              creancesEnRetard: data.creancesEnRetard,
                              aPayer: data.aPayer.valeurActuelle,
                              nombreCreanciers: data.nombreFournisseursCreanciers,
                              dettesEnRetard: data.dettesEnRetard,
                              onTapCreances: () => context.push(Routes.financeCreancesDettes),
                              onTapDettes: () => context.push(Routes.financeCreancesDettes),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: ChartDepensesCategories(
                              categories: data.categoriesDepenses,
                              onTapDetail: () => context.push(Routes.financeCharges),
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        CardCreancesDettes(
                          aRecevoir: data.aRecevoir.valeurActuelle,
                          nombreDebiteurs: data.nombreClientsDebiteurs,
                          creancesEnRetard: data.creancesEnRetard,
                          aPayer: data.aPayer.valeurActuelle,
                          nombreCreanciers: data.nombreFournisseursCreanciers,
                          dettesEnRetard: data.dettesEnRetard,
                          onTapCreances: () => context.push(Routes.financeCreancesDettes),
                          onTapDettes: () => context.push(Routes.financeCreancesDettes),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ChartDepensesCategories(
                          categories: data.categoriesDepenses,
                          onTapDetail: () => context.push(Routes.financeCharges),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // 8. Performance Activités & Boutiques
                if (data.performancesActivites.length > 1) ...[
                  CardPerformanceActivites(performances: data.performancesActivites),
                  const SizedBox(height: AppSpacing.lg),
                ],

                if (data.performancesBoutiques.length > 1) ...[
                  CardPerformanceBoutiques(
                    performances: data.performancesBoutiques,
                    onTapBoutique: (pid) => ref.read(financePerimetreFilterProvider.notifier).filtrer(pid),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // 9. Prévision de trésorerie
                CardPrevisionTresorerie(previsions: data.previsions),
                const SizedBox(height: AppSpacing.lg),

                // 10. Ce qui change & Alertes
                if (data.faitsMarquants.isNotEmpty) ...[
                  SectionCeQuiChange(faits: data.faitsMarquants),
                  const SizedBox(height: AppSpacing.lg),
                ],

                if (data.alertes.isNotEmpty) ...[
                  SectionAlertesFinancieres(alertes: data.alertes),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Indicateurs réels : aucun chiffre inventé, « — » tant que rien n'est chargé.
class ResumeFinancesCartes extends ConsumerWidget {
  const ResumeFinancesCartes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final droits = ref.watch(droitsFinancesProvider);
    final resume = ref.watch(resumeFinancesProvider).value;
    final devise = ref.watch(deviseProvider);
    final unite = devise == 'XOF' ? 'FCFA' : devise;
    String v(int Function(ResumeFinances r) f) => resume == null ? '—' : l10n.nombre(f(resume));

    final cartes = [
      if (droits.voirPaiements)
        KpiCard(label: l10n.kpiCollected, value: v((r) => r.encaisseAujourdhui), unit: unite, tone: KpiTone.primary),
      if (droits.voirCaisse)
        KpiCard(label: l10n.financeInCash, value: v((r) => r.enCaisse), unit: unite, tone: KpiTone.dark),
      if (droits.voirCreances) ...[
        KpiCard(
          label: l10n.financeToReceive,
          value: v((r) => r.aRecevoir),
          unit: unite,
          trend: resume == null || resume.enRetard == 0
              ? null
              : KpiTrend(l10n.financeOverdueAmount(l10n.montant(resume.enRetard, devise)), KpiTrendKind.bad),
        ),
        KpiCard(label: l10n.financeToPay, value: v((r) => r.aPayer), unit: unite),
      ],
      if (droits.voirDepenses)
        KpiCard(label: l10n.financeExpensesMonth, value: v((r) => r.depensesDuMois), unit: unite),
    ];
    if (cartes.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final colonnes = constraints.maxWidth >= 640 ? 4 : 2;
        final largeur = (constraints.maxWidth - AppSpacing.md * (colonnes - 1)) / colonnes;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [for (final c in cartes) SizedBox(width: largeur, child: c)],
        );
      },
    );
  }
}

// =============================================================================

class _OngletPaiements extends ConsumerWidget {
  const _OngletPaiements();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final droits = ref.watch(droitsFinancesProvider);
    final etat = ref.watch(etatFinancesProvider).value;
    final paiements = etat?.paiementsSuivis ?? const [];
    final contacts = ref.watch(contactsParIdProvider).value ?? const {};

    return Scaffold(
      floatingActionButton: !droits.encaisser
          ? null
          : FloatingActionButton.extended(
              key: const Key('paiement-add'),
              heroTag: 'paiement-add',
              onPressed: () => context.push(Routes.paiementNouveau()),
              icon: const Icon(Icons.add),
              label: Text(l10n.paymentNew),
            ),
      body: ResponsiveBody(
        child: paiements.isEmpty
            ? Center(
                child: EmptyView(icon: Icons.payments_outlined, message: l10n.paymentsEmpty),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 96),
                itemCount: paiements.length,
                itemBuilder: (context, index) {
                  final p = paiements[index].paiement;
                  final date = p.datePaiement.toLocal();
                  final precedente = index == 0 ? null : paiements[index - 1].paiement.datePaiement.toLocal();
                  final nouveauJour =
                      precedente == null ||
                      precedente.year != date.year ||
                      precedente.month != date.month ||
                      precedente.day != date.day;
                  final entree = p.sens == SensPaiement.entree;
                  final nomContact = contacts[p.contactId]?.nomAffiche;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (nouveauJour)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, AppSpacing.md, 4, AppSpacing.xs),
                          child: Text(
                            l10n.date(date),
                            style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700),
                          ),
                        ),
                      Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: entree ? AppColors.positiveSoft : AppColors.negativeSoft,
                            child: Icon(
                              entree ? Icons.south_west_rounded : Icons.north_east_rounded,
                              color: entree ? AppColors.positive : AppColors.negative,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            nomContact ?? p.reference ?? p.note ?? l10n.modePaiement(p.mode),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            [
                              MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(date)),
                              l10n.modePaiement(p.mode),
                            ].join(' · '),
                          ),
                          trailing: Montant(
                            p.montant,
                            signe: entree,
                            barre: paiements[index].annule || p.estAnnulation,
                          ),
                          onTap: () => context.push(Routes.paiement(p.id)),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _OngletCaisse extends ConsumerWidget {
  const _OngletCaisse();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(etatFinancesProvider).value;
    if (etat == null) return const Scaffold(body: LoadingView());
    return Scaffold(
      body: ResponsiveBody(child: CaisseDashboardView(etat: etat)),
    );
  }
}
