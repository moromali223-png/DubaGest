import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/di/sync_providers.dart';
import '../../../../core/sync/sync_models.dart';
import '../../../../shared/widgets/app_header_buttons.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../abonnement/domain/entities/abonnement.dart';
import '../../../entreprise/domain/entities/contexte_session.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../entreprise/presentation/providers/espace_providers.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../../agenda/presentation/pages/notifications_page.dart';
import '../../../recherche/presentation/recherche_page.dart';
import '../../../entreprise/presentation/widgets/espace_selector.dart';
import '../../../modules/domain/entities/app_module.dart';
import '../../domain/entities/navigation_model.dart';
import '../providers/navigation_providers.dart';
import '../widgets/app_menu_drawer.dart';
import '../widgets/module_tile.dart';
import '../widgets/module_visuals.dart';
import '../widgets/section_aujourdhui.dart';

import '../../../agenda/domain/entities/agenda.dart';
import '../../../agenda/presentation/pages/agenda_page.dart';
import '../../../agenda/presentation/providers/agenda_providers.dart';
import '../../../finances/presentation/widgets/finances_widgets.dart';
import '../../../commerce/presentation/widgets/alertes_accueil.dart';
import '../../../commerce/presentation/widgets/resume_recus_accueil.dart';
import '../../../commerce/presentation/widgets/workspace_gestionnaire_stock_accueil.dart';
import '../../../commerce/presentation/widgets/workspace_vendeur_accueil.dart';

/// Accueil DUBAGEST : En-tête professionnel 3 lignes (☰ rond blanc, Bonjour Prénom,
/// Entreprise · Site, Sélecteur), Recherche globale, Section Aujourd'hui (4 KPIs),
/// Modules de l'activité avec 2 services communs sur la 2e ligne, et Alertes À surveiller.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ctx = ref.watch(contexteActifProvider);
    final nav = ref.watch(navigationModelProvider);
    final espace = ref.watch(espaceCourantProvider);
    if (ctx == null || nav == null) return const Scaffold(body: LoadingView());

    // WORKSPACE VENDEUR DÉDIÉ (Épuré, Rapide, Mobile-first)
    if (nav.isWorkspaceVendeur && espace.activite == ActiviteCode.commerce) {
      return const Scaffold(
        drawer: AppMenuDrawer(),
        body: SafeArea(
          bottom: false,
          child: WorkspaceVendeurAccueil(),
        ),
      );
    }

    // WORKSPACE GESTIONNAIRE DE STOCK DÉDIÉ (Stock, Alertes, Opérations, Inventaires)
    if (nav.isWorkspaceGestionnaireStock && espace.activite == ActiviteCode.commerce) {
      return const Scaffold(
        drawer: AppMenuDrawer(),
        body: SafeArea(
          bottom: false,
          child: WorkspaceGestionnaireStockAccueil(),
        ),
      );
    }

    final prenom = ctx.nomComplet?.split(' ').first;
    final voitChiffres = nav.modulesFinances.isNotEmpty;
    final alertes = _alertes(context, ref, ctx, nav.abonnementActif);

    final activesCount = ctx.activites.where((a) => a.estActive).length;
    final aPlusieursActivites = activesCount > 1;

    final siteActuel = espace.perimetreId == null
        ? l10n.usersAllPerimetres
        : (ctx.perimetres.where((p) => p.id == espace.perimetreId).firstOrNull?.nom ?? l10n.usersAllPerimetres);

    return Scaffold(
      drawer: const AppMenuDrawer(),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.read(contexteSessionProvider.notifier).rafraichir(),
          child: ResponsiveBody(
            maxWidth: 960,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                // 1. Header de l'Accueil (Organisation claire et professionnelle)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Builder(
                      builder: (scaffoldContext) =>
                          AppMenuButton(onPressed: () => Scaffold.of(scaffoldContext).openDrawer()),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ligne 1 : Bonjour [Prénom] en gras
                          Text(
                            prenom == null ? l10n.homeGreetingAnonymous : l10n.homeGreeting(prenom),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 1),
                          // Ligne 2 : Nom de l'entreprise + site actuel
                          Text(
                            '${ctx.entreprise!.nom} · $siteActuel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                          // Ligne 3 : Sélecteur d'activité + site (si plusieurs activités)
                          if (aPlusieursActivites) const EspaceSelector(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const ClocheNotifications(),
                    const SizedBox(width: 6),
                    const SyncStatusButton(boxed: true),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // 2. Barre de recherche globale
                const ChampRechercheGlobale(),

                // 3. Section « Aujourd'hui » (4 indicateurs clés dynamiques par activité)
                if (voitChiffres) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const SectionAujourdhui(),
                ],

                // Reçus du jour (Commerce) : résumé, trois dernières ventes.
                if (espace.activite == ActiviteCode.commerce) const ResumeRecusAccueil(),

                if (!nav.abonnementActif && nav.sections.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: EmptyView(message: l10n.homeSubscriptionInactive, icon: Icons.lock_outline),
                  )
                else if (nav.sections.isEmpty && nav.modulesCommuns.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: EmptyView(message: l10n.homeNoModules, icon: Icons.lock_outline),
                  ),

                // 4. Section Modules (Intelligente et Complétée par 2 services communs sur la ligne 2)
                if (nav.sections.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Text(
                        'Modules',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Spacer(),
                      if (aPlusieursActivites)
                        Flexible(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final a in ctx.activites.where((a) => a.estActive)) ...[
                                    _ActivitePill(
                                      activite: a.activite,
                                      nom: l10n.activite(a.activite),
                                      selected: espace.activite == a.activite,
                                      onTap: () => ref.read(espaceCourantProvider.notifier).choisirActivite(a.activite),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final (i, section) in _sectionsAccueil(nav.sections).indexed) ...[
                    if (nav.sections.length > 1) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.xs),
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 6),
                        child: Text(
                          l10n.activite(section.activite),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                    // Activité prioritaire : 2 lignes (métier + Dépenses, Caisse, Dettes) ;
                    // activité secondaire : 1 ligne. Le reste est dans « Plus ».
                    if (i == 0)
                      ModuleGrid(modules: _combinerModules(section.modules, nav.modulesFinances), maxItems: 7)
                    else
                      ModuleGrid(modules: section.modules, maxItems: 3),
                  ],
                ],

                // 5. Section « À surveiller » (Alertes actionnables et complètes)
                if (alertes.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.homeWatch,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.border, width: 1.2),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < alertes.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                          alertes[i],
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Ordre de priorité des activités à l'accueil : Commerce, puis Services, puis Immobilier.
  static const _prioriteActivites = [ActiviteCode.commerce, ActiviteCode.services, ActiviteCode.immobilier];

  /// Modules financiers communs à toutes les activités, affichés sur la 2e ligne.
  static const _financesAccueil = [ModuleCodes.financesDepenses, ModuleCodes.financesCaisse, ModuleCodes.financesCreances];

  /// Au plus deux activités à l'accueil, la plus prioritaire en premier.
  List<ModuleSection> _sectionsAccueil(List<ModuleSection> sections) =>
      ([...sections]..sort((a, b) => _prioriteActivites.indexOf(a.activite).compareTo(_prioriteActivites.indexOf(b.activite))))
          .take(2)
          .toList();

  /// 2 lignes avant « Plus » : 4 modules métier, puis Dépenses, Caisse, Dettes.
  /// Si un module financier n'est pas accessible, sa place revient au métier.
  List<AppModule> _combinerModules(List<AppModule> metier, List<AppModule> finances) {
    final communs = [
      for (final code in _financesAccueil) ...finances.where((f) => f.code == code),
    ];
    final nbMetier = 7 - communs.length;
    return [...metier.take(nbMetier), ...communs];
  }

  /// Uniquement des alertes réelles, issues du contexte, des finances, de l'agenda et de la synchro.
  List<Widget> _alertes(BuildContext context, WidgetRef ref, ContexteSession ctx, bool abonnementActif) {
    final l10n = context.l10n;
    final sync = ref.watch(syncStateProvider).value ?? const SyncState();
    final abonnement = ctx.abonnement;
    final agendaAlertes = ref.watch(alertesProvider);
    final devise = ref.watch(deviseProvider);
    final alertes = <Widget>[];

    // 1. Alertes d'abonnement / suspension
    if (!abonnementActif) {
      alertes.add(_Alerte(
        icon: Icons.lock_outline,
        tone: _AlerteTone.danger,
        titre: l10n.ruleSubscriptionInactive,
      ));
    } else if (abonnement != null && abonnement.statut == AbonnementStatut.essai && abonnement.dateFin != null) {
      final jours = abonnement.dateFin!.difference(DateTime.now()).inHours ~/ 24;
      final versAbonnement = ref.watch(moduleAccessProvider(ModuleCodes.adminAbonnement)).isAllowed;
      alertes.add(_Alerte(
        icon: Icons.workspace_premium_outlined,
        tone: jours <= 3 ? _AlerteTone.warning : _AlerteTone.info,
        titre: l10n.homeTrialDaysLeft(jours < 0 ? 0 : jours),
        sousTitre: l10n.homeTrialHint,
        onTap: versAbonnement ? () => context.go(ModuleRoutes.path(ModuleCodes.adminAbonnement)) : null,
      ));
    }

    // 2. Alertes réelles issues de l'agenda et des finances (échéances, impayés, caisses)
    for (final a in agendaAlertes) {
      switch (a) {
        case AlerteEcheance(:final echeance, :final enRetard):
          alertes.add(_Alerte(
            icon: iconeEcheance(echeance.type),
            tone: enRetard ? _AlerteTone.danger : _AlerteTone.warning,
            titre: echeance.titre,
            sousTitre: '${enRetard ? l10n.notifOverdue : l10n.notifDueSoon} · ${l10n.date(echeance.dateHeure)}',
            onTap: () => context.push(Routes.echeance(echeance.id)),
          ));
        case AlerteCreancesEnRetard(:final nombre, :final montant):
          alertes.add(_Alerte(
            icon: Icons.warning_amber_rounded,
            tone: _AlerteTone.warning,
            titre: '$nombre ${nombre > 1 ? "factures impayées" : "facture impayée"} en retard',
            sousTitre: '${l10n.montant(montant, devise)} à recouvrer',
            onTap: () => context.push(Routes.financesOnglet(ModuleCodes.financesCreances)),
          ));
        case AlerteCaisseOuverte(:final caisse, :final depuis):
          alertes.add(_Alerte(
            icon: Icons.point_of_sale_outlined,
            tone: _AlerteTone.warning,
            titre: 'Caisse ${caisse.nom} ouverte depuis plus de 24h',
            sousTitre: 'Clôture recommandée',
            onTap: () => context.push(Routes.caisse(caisse.id)),
          ));
        case AlerteEcrituresRefusees(:final nombre):
          alertes.add(_Alerte(
            icon: Icons.block,
            tone: _AlerteTone.danger,
            titre: l10n.notifRejected(nombre),
            sousTitre: l10n.notifRejectedHint,
            onTap: () => context.push(Routes.finances),
          ));
      }
    }

    // 3. Stock : produits en rupture ou en stock faible (avec leurs photos).
    alertes.addAll(alertesStockAccueil(context, ref));

    // 4. Alertes Synchronisation & Réseau
    if (sync.pendingCount > 0) {
      alertes.add(_Alerte(
        icon: Icons.cloud_upload_outlined,
        tone: _AlerteTone.info,
        titre: '${sync.pendingCount} ${sync.pendingCount > 1 ? "opérations en attente d'envoi" : "opération en attente d'envoi"}',
        sousTitre: sync.phase == SyncPhase.offline ? 'Mode hors-ligne · Envoi automatique dès reconnexion' : 'Synchronisation en cours…',
        onTap: () => ref.read(syncEngineProvider).requestSync(),
      ));
    }
    if (sync.phase == SyncPhase.error) {
      alertes.add(_Alerte(
        icon: Icons.sync_problem,
        tone: _AlerteTone.danger,
        titre: l10n.syncError,
        onTap: () => ref.read(syncEngineProvider).requestSync(),
      ));
    }
    if (ctx.depuisCache) {
      alertes.add(_Alerte(icon: Icons.cloud_off_outlined, tone: _AlerteTone.info, titre: l10n.contextOfflineCache));
    }
    return alertes;
  }
}

enum _AlerteTone { info, warning, danger }

class _Alerte extends StatelessWidget {
  const _Alerte({
    required this.icon,
    required this.tone,
    required this.titre,
    this.sousTitre,
    this.onTap,
  });

  final IconData icon;
  final _AlerteTone tone;
  final String titre;
  final String? sousTitre;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      _AlerteTone.info => (AppColors.greenSoft, AppColors.green),
      _AlerteTone.warning => (AppColors.warningSoft, AppColors.warning),
      _AlerteTone.danger => (AppColors.negativeSoft, AppColors.negative),
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: fg, size: 22),
      ),
      title: Text(
        titre,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.ink),
      ),
      subtitle: sousTitre == null
          ? null
          : Text(
              sousTitre!,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: AppColors.muted),
            ),
      trailing: onTap == null ? const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20) : const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
    );
  }
}

class _ActivitePill extends StatelessWidget {
  const _ActivitePill({
    required this.activite,
    required this.nom,
    required this.selected,
    required this.onTap,
  });

  final ActiviteCode activite;
  final String nom;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected ? AppColors.green : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  activiteIcon(activite),
                  size: 14,
                  color: selected ? Colors.white : AppColors.muted,
                ),
                const SizedBox(width: 5),
                Text(
                  nom,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.ink,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
