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
import '../widgets/card_sante_financiere.dart';
import '../widgets/finances_widgets.dart';
import '../widgets/header_filtres_financiers.dart';
import '../widgets/section_derniers_flux.dart';
import '../widgets/card_conseiller_cfo.dart';
import '../widgets/barre_raccourcis_finance.dart';
import '../widgets/section_comptes_tresorerie.dart';
import '../widgets/selecteur_analyse_focus.dart';
import '../widgets/dettes_vue_principale.dart';
import '../widgets/workspace_finances_vendeur.dart';
import '../widgets/workspace_finances_superviseur.dart';
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
    final nav = ref.watch(navigationModelProvider);

    // RESTRICTION RÔLE : Le Gestionnaire de Stock n'a pas accès aux dépenses ni à la trésorerie globale
    if (nav?.isWorkspaceGestionnaireStock == true) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Finances & Stock'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(Routes.home),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF01226C).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.inventory_2_rounded, size: 48, color: Color(0xFF01226C)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Accès Restreint — Espace Stock',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.ink),
                ),
                const SizedBox(height: 8),
                const Text(
                  'La consultation des dépenses de l\'entreprise et des flux de trésorerie généraux est strictement réservée à la direction.\nLa valorisation financière de vos marchandises est consultable directement depuis votre accueil.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 13.5, height: 1.4),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.go(Routes.home),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF01226C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.dashboard_rounded),
                  label: const Text('Retour à l\'accueil Stock'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final modules = nav?.modulesFinances ?? const <AppModule>[];
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

    // WORKSPACE VENDEUR DÉDIÉ (Point de caisse & Encaissements de la boutique)
    if (nav?.isWorkspaceVendeur == true) {
      return const WorkspaceFinancesVendeur();
    }

    // WORKSPACE SUPERVISEUR DÉDIÉ (Caisse, Dépenses, Créances boutique)
    if (nav?.isWorkspaceSuperviseur == true) {
      return const WorkspaceFinancesSuperviseur();
    }

    // Vue principale sans onglets en haut : Synthèse financière décisionnelle
    return Scaffold(
      backgroundColor: const Color(0xFF0C1412),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1412),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E7E4E).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_rounded, color: Color(0xFF2ECC71), size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              l10n.navFinances,
              style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined, color: Color(0xFFA5B8B1)),
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
class AccesModulesFinances extends ConsumerWidget {
  const AccesModulesFinances({super.key});

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
        resume == null || !ref.watch(droitsFinancesProvider).voirDepenses
            ? null
            : '${l10n.financeToPay} : ${l10n.montant(resume.aPayer, devise)}',
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
        Text(
          l10n.financeManage,
          style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 16),
        ),
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
      color: const Color(0xFF141E1B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFF223830)),
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
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E7E4E).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icone, color: const Color(0xFF2ECC71), size: 20),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF5A756D)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                titre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, height: 1.2, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                chiffre ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2ECC71), fontSize: 13),
              ),
              if (legende != null)
                Text(
                  legende,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFA5B8B1), fontSize: 11),
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
    final devise = ref.watch(deviseProvider);

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
                    estSurFondSombre: true,
                    onActualiser: () => ref.invalidate(etatFinancesProvider),
                    onExporter: () => context.push(Routes.financeRapport),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.insights_rounded, size: 48, color: Color(0xFF5A756D)),
                        SizedBox(height: AppSpacing.md),
                        Text(
                          'Pas encore assez de données',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        SizedBox(height: 6),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Les statistiques financières apparaîtront dès que votre activité aura enregistré ses premières opérations.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Color(0xFFA5B8B1), height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const AccesModulesFinances(),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 96),
              children: [
                // 1. En-tête exécutif DAF & Salutation
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Flexible(
                                child: Text(
                                  'Direction Financière',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Supervision stratégique & trésorerie en temps réel',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFA5B8B1),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Badge profil exécutif
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF2ECC71).withValues(alpha: 0.6), width: 1.5),
                      ),
                      child: const CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0xFF1B2A25),
                        child: Icon(Icons.person_rounded, color: Color(0xFF2ECC71), size: 24),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // 2. Filtres
                HeaderFiltresFinanciers(
                  estSurFondSombre: true,
                  onActualiser: () => ref.invalidate(etatFinancesProvider),
                  onExporter: () => context.push(Routes.financeRapport),
                ),
                const SizedBox(height: AppSpacing.md),

                // 3. Conseiller DAF IA (AI Coach card du mockup)
                CardConseillerCfo(
                  sante: data.sante,
                  previsions: data.previsions,
                  recouvrement: data.recouvrement,
                  devise: devise,
                  onTap: () => context.push(Routes.financeRapport),
                ),
                const SizedBox(height: AppSpacing.md),

                // 4. Santé financière (Jauge concentrique + 3 métriques clés)
                CardSanteFinanciere(
                  sante: data.sante,
                  chiffreAffaires: data.chiffreAffaires.valeurActuelle,
                  chiffreAffairesPrecedent: data.chiffreAffaires.valeurPrecedente,
                  tauxEvolutionCA: data.chiffreAffaires.tauxEvolution,
                  tresorerieDisponible: data.tresorerieDisponible.valeurActuelle,
                  tauxRecouvrement: data.recouvrement.tauxPourcent,
                  devise: devise,
                  periodeLabel: data.periode.libelleCourt(),
                  onTap: () => context.push(Routes.financeRapport),
                  onTapCA: () => context.push(Routes.financeRevenus),
                  onTapTresorerie: () => context.push(Routes.financeTresorerie),
                  onTapRecouvrement: () => context.push(Routes.financeCreancesDettes),
                ),
                const SizedBox(height: AppSpacing.md),

                // 5. Barre de Raccourcis Financement (Style Image 2 : Caisse, Dépenses, Dettes, Analyse)
                BarreRaccourcisFinance(
                  onTapCaisse: () => context.push(Routes.financesOnglet(ModuleCodes.financesCaisse)),
                  onTapDepenses: () => context.push(Routes.financesOnglet(ModuleCodes.financesDepenses)),
                  onTapDettes: () => context.push(Routes.financesOnglet(ModuleCodes.financesCreances)),
                  onTapAnalyse: () => context.push(Routes.financeRapport),
                ),
                const SizedBox(height: AppSpacing.md),

                // Modules financiers autorisés
                const AccesModulesFinances(),
                const SizedBox(height: AppSpacing.lg),

                // 6. Situation des Comptes & Trésorerie Active (Style Image 2 "CURRENT LOANS" card)
                SectionComptesTresorerie(
                  data: data,
                  devise: devise,
                  onTapCaisse: () => context.push(Routes.financesOnglet(ModuleCodes.financesCaisse)),
                  onTapCreances: () => context.push(Routes.financesOnglet(ModuleCodes.financesCreances)),
                  onTapDettes: () => context.push(Routes.financesOnglet(ModuleCodes.financesCreances)),
                  onActionPlus: () => context.push(Routes.financesOnglet(ModuleCodes.financesPaiements)),
                ),
                const SizedBox(height: AppSpacing.lg),

                // 7. Sélecteur d'Analyse Focalisée (Élimine le défilement infini !)
                SelecteurAnalyseFocus(
                  data: data,
                  devise: devise,
                  onTapDetailCA: () => context.push(Routes.financeRevenus),
                  onTapCreances: () => context.push(Routes.financeCreancesDettes),
                  onTapDettes: () => context.push(Routes.financeCreancesDettes),
                  onTapDetailCharges: () => context.push(Routes.financeCharges),
                ),
                const SizedBox(height: AppSpacing.md),

                // Passerelle vers Intelligence Commerciale (si module accessible)
                if (ref.watch(moduleAccessProvider(ModuleCodes.commerceIntelligence)).isAllowed) ...[
                  _BandeauPontIntelligenceCommerciale(
                    onTap: () => context.push(Routes.commerceIntelligence),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 8. Historique des Paiements & Flux Récents (Style Image 1 "Payment History")
                SectionDerniersFlux(
                  onVoirTout: () => context.push(Routes.financeRapport),
                ),
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

class _BandeauPontIntelligenceCommerciale extends StatelessWidget {
  const _BandeauPontIntelligenceCommerciale({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF141E1B),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF01226C).withValues(alpha: 0.5),
              width: 1.2,
            ),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF01226C).withValues(alpha: 0.25),
                const Color(0xFF141E1B),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF01226C),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF01226C).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.insights_rounded, color: Color(0xFFDF9540), size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Intelligence commerciale',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Marges réelles, vitesse des stocks et prévisions d’achats.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFDF9540)),
            ],
          ),
        ),
      ),
    );
  }
}
