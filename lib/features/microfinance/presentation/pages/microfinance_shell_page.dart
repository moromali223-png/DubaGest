import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/microfinance_enums.dart';
import '../../domain/entities/microfinance_models.dart';
import '../../domain/services/delinquency_analyzer.dart';
import '../pdf/microfinance_csv_exporter.dart';
import '../providers/microfinance_providers.dart';
import '../widgets/borrower_form_sheet.dart';
import '../widgets/microfinance_shared_widgets.dart';
import '../widgets/repayment_form_sheet.dart';

/// Page principale du module **DubaGest Microfinance** (Commerce → Tous les modules → Microfinance).
/// Exclusivement accessible aux entreprises disposant d'un abonnement Pro actif (5 000 FCFA).
class MicrofinanceShellPage extends ConsumerStatefulWidget {
  const MicrofinanceShellPage({super.key});

  @override
  ConsumerState<MicrofinanceShellPage> createState() => _MicrofinanceShellPageState();
}

class _MicrofinanceShellPageState extends ConsumerState<MicrofinanceShellPage> {
  String _recherchePret = '';
  StatutPret? _filtreStatutPret;

  String _rechercheEmprunteur = '';
  bool _uniquementAvecImpayes = false;

  StatutEcheance _segmentEcheance = StatutEcheance.enRetard;

  bool _syncing = false;

  Future<void> _rafraichir(String entrepriseId) async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await ref.read(microfinanceRepositoryProvider).refresh(entrepriseId);
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _lancerAppel(String tel) async {
    final clean = tel.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;
    await launchUrl(Uri.parse('tel:$clean'));
  }

  Future<void> _relancerWhatsApp(String tel, String message) async {
    final digits = tel.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;
    final encoded = Uri.encodeComponent(message);
    await launchUrl(
      Uri.parse('https://wa.me/$digits?text=$encoded'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = l10n.localeName;
    final hasAccess = ref.watch(hasMicrofinanceAccessProvider);
    final ctx = ref.watch(contexteActifProvider);
    final entreprise = ctx?.entreprise;
    final devise = entreprise?.devise ?? 'XOF';

    if (!hasAccess || entreprise == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.mfTitle)),
        body: Center(
          child: ResponsiveBody(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: MessageView(
                icon: Icons.workspace_premium_outlined,
                title: l10n.mfTitle,
                message: l10n.mfProOnlyMessage,
                action: FilledButton(
                  onPressed: () => context.go(Routes.choixFormuleAbonnement),
                  child: const Text('Voir les formules (Pro 5 000 FCFA)'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final borrowers = (ref.watch(mfBorrowersProvider).value ?? const [])
        .where((b) => b.deletedAt == null)
        .toList();
    final loans = (ref.watch(mfLoansProvider).value ?? const [])
        .where((l) => l.deletedAt == null)
        .toList();
    final installments = (ref.watch(mfInstallmentsProvider).value ?? const [])
        .where((e) => e.deletedAt == null)
        .toList();

    final stats = ref.watch(mfDashboardStatsProvider);
    final pState = ref.watch(mfPeriodeProvider);
    final summaries = ref.watch(mfBorrowerSummariesProvider);

    final borrowersById = {for (final b in borrowers) b.id: b};
    final loansById = {for (final l in loans) l.id: l};

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.mfTitle),
          actions: [
            IconButton(
              tooltip: 'Synchroniser',
              onPressed: _syncing ? null : () => _rafraichir(entreprise.id),
              icon: _syncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: const Icon(Icons.dashboard_outlined, size: 18), text: l10n.mfTabDashboard),
              Tab(icon: const Icon(Icons.account_balance_outlined, size: 18), text: l10n.mfTabLoans),
              Tab(icon: const Icon(Icons.people_outline_rounded, size: 18), text: l10n.mfTabBorrowers),
              Tab(icon: const Icon(Icons.event_repeat_outlined, size: 18), text: l10n.mfTabInstallments),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: () => context.push(Routes.microfinanceLoanNew),
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.mfNewLoan),
        ),
        body: TabBarView(
          children: [
            // TAB 1 : TABLEAU DE BORD
            _buildDashboardTab(
              context,
              l10n: l10n,
              locale: locale,
              devise: devise,
              stats: stats,
              pState: pState,
              loans: loans,
              borrowersById: borrowersById,
            ),

            // TAB 2 : PRÊTS
            _buildLoansTab(
              context,
              l10n: l10n,
              locale: locale,
              devise: devise,
              loans: loans,
              installments: installments,
              borrowersById: borrowersById,
            ),

            // TAB 3 : EMPRUNTEURS
            _buildBorrowersTab(
              context,
              l10n: l10n,
              devise: devise,
              borrowers: borrowers,
              summaries: summaries,
            ),

            // TAB 4 : ÉCHÉANCES & IMPAYÉS
            _buildInstallmentsTab(
              context,
              l10n: l10n,
              devise: devise,
              installments: installments,
              loansById: loansById,
              borrowersById: borrowersById,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectionnerPeriode(
    BuildContext context,
    PeriodeMicrofinance p,
    MfPeriodeState pState,
  ) async {
    if (p == PeriodeMicrofinance.personnalise) {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDateRange: (pState.debutCustom != null && pState.finCustom != null)
            ? DateTimeRange(start: pState.debutCustom!, end: pState.finCustom!)
            : null,
      );
      if (range != null) {
        ref.read(mfPeriodeProvider.notifier).choisir(
              p,
              debut: range.start,
              fin: range.end,
            );
      }
      return;
    }
    ref.read(mfPeriodeProvider.notifier).choisir(p);
  }

  Widget _buildDashboardTab(
    BuildContext context, {
    required AppLocalizations l10n,
    required String locale,
    required String devise,
    required MicrofinanceDashboardStats stats,
    required MfPeriodeState pState,
    required List<MicrofinanceLoan> loans,
    required Map<String, MicrofinanceBorrower> borrowersById,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= AppBreakpoints.expanded
        ? 4
        : (width >= AppBreakpoints.medium ? 3 : 2);
    final periodeLabel = (pState.periode == PeriodeMicrofinance.personnalise &&
            pState.debutCustom != null &&
            pState.finCustom != null)
        ? '${l10n.date(pState.debutCustom!)} → ${l10n.date(pState.finCustom!)}'
        : pState.periode.libelle(locale);

    return ResponsiveBody(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          if (loans.isEmpty && borrowersById.isEmpty)
            Card(
              elevation: 0,
              color: AppColors.primarySoft.withValues(alpha: isDark ? 0.16 : 0.7),
              margin: const EdgeInsets.only(bottom: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.primary),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Démarrer votre activité Microfinance',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Enregistrez votre premier emprunteur et accordez un prêt directement.',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                          onPressed: () => context.push(Routes.microfinanceLoanNew),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(l10n.mfNewLoan),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => afficherFormulaireEmprunteur(context),
                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                          label: const Text('Nouvel emprunteur'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Bloc 1 : Filtre par Jour / Semaine / Mois / Année / Personnalisé
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.date_range_outlined, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Période : $periodeLabel',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (pState.periode == PeriodeMicrofinance.personnalise)
                        TextButton.icon(
                          onPressed: () => _selectionnerPeriode(
                            context,
                            PeriodeMicrofinance.personnalise,
                            pState,
                          ),
                          icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                          label: const Text('Dates'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final p in PeriodeMicrofinance.values)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: ChoiceChip(
                              selected: pState.periode == p,
                              label: Text(p.libelle(locale)),
                              onSelected: (_) => _selectionnerPeriode(context, p, pState),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Bloc 2 : Bilan de la période sélectionnée
          _DashboardSectionHeader(
            titre: 'Activité de la période ($periodeLabel)',
            icone: Icons.analytics_outlined,
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primarySoft.withValues(alpha: isDark ? 0.16 : 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: _PeriodeHighlightStat(
                    titre: 'Prêts accordés',
                    valeurPrincipale: '${stats.nombrePretsAccordes} prêt(s)',
                    sousValeur: l10n.montant(stats.totalMontantsDecaisses, devise),
                    couleur: AppColors.primary,
                  ),
                ),
                Container(
                  width: 1,
                  height: 52,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
                Expanded(
                  child: _PeriodeHighlightStat(
                    titre: 'Total payé / remboursé',
                    valeurPrincipale: l10n.montant(stats.totalRemboursementsRecus, devise),
                    sousValeur: '${stats.nombreRemboursementsRecus} paiement(s) reçu(s)',
                    couleur: const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: cols >= 3 ? 1.55 : 1.38,
            children: [
              MicrofinanceKpiCard(
                titre: 'Nombre de prêts accordés',
                valeur: '${stats.nombrePretsAccordes}',
                sousTitre: 'Total global : ${stats.nombrePretsTotalPortefeuille} prêt(s)',
                icone: Icons.assignment_turned_in_outlined,
                couleur: AppColors.primary,
              ),
              MicrofinanceKpiCard(
                titre: 'Total payé ($periodeLabel)',
                valeur: l10n.montant(stats.totalRemboursementsRecus, devise),
                sousTitre: '${stats.nombreRemboursementsRecus} paiement(s) reçu(s)',
                icone: Icons.payments_rounded,
                couleur: const Color(0xFF16A34A),
              ),
              MicrofinanceKpiCard(
                titre: 'Montant total prêté',
                valeur: l10n.montant(stats.totalMontantsDecaisses, devise),
                sousTitre: 'Sur la période sélectionnée',
                icone: Icons.outbound_outlined,
                couleur: const Color(0xFF6366F1),
              ),
              MicrofinanceKpiCard(
                titre: 'Intérêts encaissés',
                valeur: l10n.montant(stats.totalInteretsEncaisses, devise),
                sousTitre: 'Prévus : ${l10n.montant(stats.totalInteretsPrevus, devise)}',
                icone: Icons.trending_up_rounded,
                couleur: const Color(0xFF8B5CF6),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Bloc 3 : Situation globale du portefeuille & Recouvrement
          const _DashboardSectionHeader(
            titre: 'Situation du portefeuille & Recouvrement',
            icone: Icons.account_balance_outlined,
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: cols >= 3 ? 1.55 : 1.38,
            children: [
              MicrofinanceKpiCard(
                titre: 'Reste total à payer',
                valeur: l10n.montant(stats.resteAPayerTotal, devise),
                sousTitre: 'Capital restant : ${l10n.montant(stats.capitalRestantARecuperer, devise)}',
                icone: Icons.hourglass_bottom_rounded,
                couleur: const Color(0xFF0284C7),
              ),
              MicrofinanceKpiCard(
                titre: 'Prêts actifs / soldés',
                valeur: '${stats.nombrePretsActifs} / ${stats.nombrePretsSoldes}',
                sousTitre: 'Recouvrement : ${stats.tauxRecouvrementGlobal.toStringAsFixed(1)} %',
                icone: Icons.assignment_outlined,
                couleur: AppColors.primary,
              ),
              MicrofinanceKpiCard(
                titre: 'Montant des impayés',
                valeur: l10n.montant(stats.montantTotalImpayes, devise),
                sousTitre: '${stats.nombrePretsEnRetard} prêt(s) • ${stats.nombreEcheancesEnRetard} éch. en retard',
                icone: Icons.warning_amber_rounded,
                couleur: stats.montantTotalImpayes > 0 ? AppColors.negative : const Color(0xFF16A34A),
              ),
              MicrofinanceKpiCard(
                titre: 'Échéances du jour',
                valeur: l10n.montant(stats.montantEcheancesAujourdhui, devise),
                sousTitre: '${stats.nombreEcheancesAujourdhui} à encaisser aujourd\'hui',
                icone: Icons.today_outlined,
                couleur: AppColors.gold,
              ),
              MicrofinanceKpiCard(
                titre: 'Emprunteurs',
                valeur: l10n.nombre(stats.nombreEmprunteurs),
                sousTitre: 'Clients enregistrés',
                icone: Icons.groups_outlined,
                couleur: const Color(0xFF0F766E),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bloc 4 : Graphique comparatif
          MicrofinancePortfolioChart(stats: stats, devise: devise),
          const SizedBox(height: 14),

          // Actions rapides
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () => context.push(Routes.microfinanceLoanNew),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.mfNewLoan),
              ),
              OutlinedButton.icon(
                onPressed: () => afficherFormulaireEmprunteur(context),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Nouvel emprunteur'),
              ),
              OutlinedButton.icon(
                onPressed: () => MicrofinanceCsvExporter.afficherEtExporter(
                  context,
                  titre: 'Export Prêts Microfinance (.CSV)',
                  csvContent: MicrofinanceCsvExporter.exporterPrets(
                    loans: loans,
                    borrowersById: borrowersById,
                  ),
                ),
                icon: const Icon(Icons.table_chart_outlined, size: 18),
                label: const Text('Exporter prêts (CSV)'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoansTab(
    BuildContext context, {
    required AppLocalizations l10n,
    required String locale,
    required String devise,
    required List<MicrofinanceLoan> loans,
    required List<MicrofinanceInstallment> installments,
    required Map<String, MicrofinanceBorrower> borrowersById,
  }) {
    final now = DateTime.now();
    final theme = Theme.of(context);
    final q = _recherchePret.trim().toLowerCase();

    final echsParPret = <String, List<MicrofinanceInstallment>>{};
    for (final e in installments) {
      echsParPret.putIfAbsent(e.loanId, () => []).add(e);
    }

    final filtres = loans.where((l) {
      final st = DelinquencyAnalyzer.statutPretActuel(l, echsParPret[l.id] ?? const [], now);
      if (_filtreStatutPret != null && st != _filtreStatutPret) return false;
      if (q.isEmpty) return true;
      final b = borrowersById[l.borrowerId];
      return l.reference.toLowerCase().contains(q) ||
          (b?.nomComplet.toLowerCase().contains(q) ?? false) ||
          (b?.telephone.toLowerCase().contains(q) ?? false);
    }).toList()
      ..sort((a, b) => b.dateOctroi.compareTo(a.dateOctroi));

    return ResponsiveBody(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un prêt (référence, emprunteur, tél.)',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _recherchePret = v),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Exporter CSV',
                  icon: const Icon(Icons.download_outlined),
                  onPressed: () => MicrofinanceCsvExporter.afficherEtExporter(
                    context,
                    titre: 'Prêts Microfinance (.CSV)',
                    csvContent: MicrofinanceCsvExporter.exporterPrets(
                      loans: filtres,
                      borrowersById: borrowersById,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: ChoiceChip(
                    selected: _filtreStatutPret == null,
                    label: Text('Tous (${loans.length})'),
                    onSelected: (_) => setState(() => _filtreStatutPret = null),
                  ),
                ),
                for (final s in StatutPret.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: ChoiceChip(
                      selected: _filtreStatutPret == s,
                      label: Text(s.libelle(locale)),
                      onSelected: (_) =>
                          setState(() => _filtreStatutPret = _filtreStatutPret == s ? null : s),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: filtres.isEmpty
                ? Center(
                    child: MessageView(
                      icon: Icons.account_balance_outlined,
                      title: 'Aucun prêt trouvé',
                      message: 'Créez votre premier dossier de prêt avec simulation détaillée.',
                      action: FilledButton(
                        onPressed: () => context.push(Routes.microfinanceLoanNew),
                        child: Text(l10n.mfNewLoan),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    itemCount: filtres.length,
                    itemBuilder: (_, i) {
                      final l = filtres[i];
                      final b = borrowersById[l.borrowerId];
                      final echs = echsParPret[l.id] ?? const [];
                      final statut = DelinquencyAnalyzer.statutPretActuel(l, echs, now);

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: theme.colorScheme.outlineVariant),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => context.push(Routes.microfinanceLoanDetails(l.id)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            b?.nomComplet ?? 'Emprunteur',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800, fontSize: 15),
                                          ),
                                          Text(
                                            '${l.reference} • ${l10n.date(l.dateOctroi)}',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    StatutPretBadge(statut: statut),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Accordé : ${l10n.montant(l.montantAccorde, devise)}',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      'Reste : ${l10n.montant(l.resteAPayerTotal, devise)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: l.resteAPayerTotal > 0
                                            ? AppColors.negative
                                            : AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: l.progressionPourcent / 100,
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(4),
                                  color: statut == StatutPret.enRetard
                                      ? AppColors.negative
                                      : AppColors.primary,
                                ),
                                if (statut.estActifOuOuvert && l.resteAPayerTotal > 0) ...[
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: TextButton.icon(
                                      onPressed: () => afficherFormulaireRemboursement(
                                        context,
                                        loan: l,
                                        installments: echs,
                                      ),
                                      icon: const Icon(Icons.payments_outlined, size: 18),
                                      label: const Text('Encaisser'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBorrowersTab(
    BuildContext context, {
    required AppLocalizations l10n,
    required String devise,
    required List<MicrofinanceBorrower> borrowers,
    required Map<String, MicrofinanceBorrowerSummary> summaries,
  }) {
    final theme = Theme.of(context);
    final q = _rechercheEmprunteur.trim().toLowerCase();

    final filtres = borrowers.where((b) {
      final sum = summaries[b.id];
      if (_uniquementAvecImpayes && (sum?.montantImpayes ?? 0) <= 0) return false;
      if (q.isEmpty) return true;
      return b.nomComplet.toLowerCase().contains(q) ||
          b.codeEmprunteur.toLowerCase().contains(q) ||
          b.telephone.toLowerCase().contains(q) ||
          (b.profession?.toLowerCase().contains(q) ?? false);
    }).toList()
      ..sort((a, b) => a.nomComplet.compareTo(b.nomComplet));

    return ResponsiveBody(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un emprunteur (nom, code, tél.)',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _rechercheEmprunteur = v),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () => afficherFormulaireEmprunteur(context),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  selected: _uniquementAvecImpayes,
                  label: const Text('Uniquement avec impayés'),
                  onSelected: (v) => setState(() => _uniquementAvecImpayes = v),
                ),
                const Spacer(),
                Text('${filtres.length} emprunteur(s)', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Expanded(
            child: filtres.isEmpty
                ? Center(
                    child: MessageView(
                      icon: Icons.people_outline_rounded,
                      title: 'Aucun emprunteur',
                      message: 'Enregistrez vos clients emprunteurs (import possible depuis Contacts).',
                      action: FilledButton(
                        onPressed: () => afficherFormulaireEmprunteur(context),
                        child: const Text('Nouvel emprunteur'),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    itemCount: filtres.length,
                    itemBuilder: (_, i) {
                      final b = filtres[i];
                      final sum = summaries[b.id];
                      final waNum = (b.whatsapp?.isNotEmpty ?? false) ? b.whatsapp! : b.telephone;
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: theme.colorScheme.outlineVariant),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => context.push(Routes.microfinanceBorrowerDetails(b.id)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.primarySoft,
                                  child: Text(
                                    b.initiales,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(b.nomComplet,
                                          style: const TextStyle(fontWeight: FontWeight.w800)),
                                      Text(
                                        '${b.codeEmprunteur} • ${b.telephone}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      if (sum != null)
                                        Text(
                                          'Actifs: ${sum.nombrePretsActifs} • Reste: ${l10n.montant(sum.resteAPayerTotal, devise)}'
                                          '${sum.montantImpayes > 0 ? ' • Impayés: ${l10n.montant(sum.montantImpayes, devise)}' : ''}',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: sum.montantImpayes > 0
                                                ? AppColors.negative
                                                : AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Appeler',
                                  icon: const Icon(Icons.phone_outlined, size: 20),
                                  onPressed: () => _lancerAppel(b.telephone),
                                ),
                                if (waNum.isNotEmpty)
                                  IconButton(
                                    tooltip: 'WhatsApp',
                                    icon: const Icon(Icons.chat_outlined,
                                        size: 20, color: Color(0xFF16A34A)),
                                    onPressed: () => _relancerWhatsApp(
                                      waNum,
                                      'Bonjour ${b.nomComplet}, suivi de votre prêt Microfinance.',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallmentsTab(
    BuildContext context, {
    required AppLocalizations l10n,
    required String devise,
    required List<MicrofinanceInstallment> installments,
    required Map<String, MicrofinanceLoan> loansById,
    required Map<String, MicrofinanceBorrower> borrowersById,
  }) {
    final now = DateTime.now();
    final theme = Theme.of(context);
    final locale = l10n.localeName;

    final echsParPret = <String, List<MicrofinanceInstallment>>{};
    for (final e in installments) {
      echsParPret.putIfAbsent(e.loanId, () => []).add(e);
    }

    final categories = [
      StatutEcheance.enRetard,
      StatutEcheance.aujourdHui,
      StatutEcheance.partiel,
      StatutEcheance.aVenir,
      StatutEcheance.paye,
    ];

    final actives = installments.where((e) {
      final loan = loansById[e.loanId];
      return loan != null && loan.statut != StatutPret.annule && loan.statut != StatutPret.brouillon;
    }).toList();

    final compteurs = <StatutEcheance, int>{for (final s in categories) s: 0};
    final filtrees = <MicrofinanceInstallment>[];

    for (final e in actives) {
      final st = DelinquencyAnalyzer.statutEcheanceActuel(e, now);
      compteurs[st] = (compteurs[st] ?? 0) + 1;
      if (st == _segmentEcheance) filtrees.add(e);
    }

    filtrees.sort((a, b) => a.datePrevue.compareTo(b.datePrevue));

    return ResponsiveBody(
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                for (final s in categories)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      selected: _segmentEcheance == s,
                      label: Text('${s.libelle(locale)} (${compteurs[s] ?? 0})'),
                      onSelected: (_) => setState(() => _segmentEcheance = s),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: filtrees.isEmpty
                ? Center(
                    child: MessageView(
                      icon: Icons.event_available_rounded,
                      title: 'Aucune échéance « ${_segmentEcheance.libelle(locale)} »',
                      message: 'Tout est à jour dans cette catégorie.',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                    itemCount: filtrees.length,
                    itemBuilder: (_, i) {
                      final e = filtrees[i];
                      final loan = loansById[e.loanId]!;
                      final borrower = borrowersById[e.borrowerId];
                      final ret = DelinquencyAnalyzer.joursRetardEcheance(e, now);
                      final st = DelinquencyAnalyzer.statutEcheanceActuel(e, now);
                      final waNum = (borrower?.whatsapp?.isNotEmpty ?? false)
                          ? borrower!.whatsapp!
                          : (borrower?.telephone ?? '');

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: st == StatutEcheance.enRetard
                                ? AppColors.negative.withValues(alpha: 0.45)
                                : theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => context.push(Routes.microfinanceLoanDetails(loan.id)),
                                      child: Text(
                                        '${borrower?.nomComplet ?? 'Emprunteur'} • ${loan.reference}',
                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ),
                                  StatutEcheanceBadge(statut: st, joursRetard: ret),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Échéance #${e.numeroEcheance} du ${l10n.date(e.datePrevue)} • '
                                'Attendu : ${l10n.montant(e.montantTotalAttendu, devise)}',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                e.estSoldee
                                    ? 'Payée intégralement'
                                    : 'Reste à encaisser : ${l10n.montant(e.resteAPayer, devise)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: e.estSoldee ? AppColors.primary : AppColors.negative,
                                ),
                              ),
                              if (!e.estSoldee && loan.statut.estActifOuOuvert) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (borrower != null && borrower.telephone.isNotEmpty)
                                      IconButton(
                                        tooltip: 'Appeler',
                                        icon: const Icon(Icons.phone_outlined, size: 19),
                                        onPressed: () => _lancerAppel(borrower.telephone),
                                      ),
                                    if (waNum.isNotEmpty)
                                      IconButton(
                                        tooltip: 'Relancer WhatsApp',
                                        icon: const Icon(Icons.chat_outlined,
                                            size: 19, color: Color(0xFF16A34A)),
                                        onPressed: () => _relancerWhatsApp(
                                          waNum,
                                          'Bonjour ${borrower?.nomComplet ?? ''}, rappel concernant votre échéance #${e.numeroEcheance} du ${l10n.date(e.datePrevue)} (Prêt ${loan.reference}) : reste à payer ${l10n.montant(e.resteAPayer, devise)}.',
                                        ),
                                      ),
                                    const SizedBox(width: 6),
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                                      onPressed: () => afficherFormulaireRemboursement(
                                        context,
                                        loan: loan,
                                        installments: echsParPret[loan.id] ?? const [],
                                        installmentCible: e,
                                      ),
                                      icon: const Icon(Icons.payments_outlined, size: 17),
                                      label: const Text('Encaisser'),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSectionHeader extends StatelessWidget {
  const _DashboardSectionHeader({required this.titre, required this.icone});

  final String titre;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icone, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            titre,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _PeriodeHighlightStat extends StatelessWidget {
  const _PeriodeHighlightStat({
    required this.titre,
    required this.valeurPrincipale,
    required this.sousValeur,
    required this.couleur,
  });

  final String titre;
  final String valeurPrincipale;
  final String sousValeur;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            valeurPrincipale,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: couleur,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sousValeur,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

