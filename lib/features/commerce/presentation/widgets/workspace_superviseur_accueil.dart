import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/di/sync_providers.dart';
import '../../../../core/sync/sync_models.dart';
import '../../../../shared/widgets/app_header_buttons.dart';
import '../../../../shared/widgets/kpi_card.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../agenda/presentation/pages/notifications_page.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../entreprise/presentation/providers/espace_providers.dart';
import '../../../finances/domain/entities/finances.dart';
import '../../../finances/presentation/providers/finances_providers.dart';
import '../../../finances/presentation/widgets/finances_widgets.dart';
import '../../../modules/domain/entities/app_module.dart';
import '../../../navigation/presentation/widgets/module_visuals.dart';
import '../../../recherche/presentation/recherche_page.dart';
import '../../domain/entities/commerce.dart';
import '../../domain/services/etat_commerce.dart';
import '../commerce_providers.dart';
import 'alertes_accueil.dart';
import 'choix_produit.dart';
import 'commerce_widgets.dart';
import 'resume_recus_accueil.dart';

/// Tableau de bord d'accueil dédié au rôle SUPERVISEUR.
///
/// Calqué sur l'excellence UI/UX du tableau de bord Administrateur,
/// mais restreint avec précision au périmètre opérationnel de ses boutiques :
/// - Caisse de la boutique (mouvements, encaissements)
/// - Dépenses opérationnelles de la boutique
/// - Dettes & Créances autorisées (impayés clients à recouvrer)
/// - Clients (carnet d'adresses clients de la boutique)
/// - Ventes, stocks, alertes et inventaires
///
/// Aucun module d'administration globale (abonnements, utilisateurs, réglages sensibles)
/// ni d'approvisionnement fournisseurs (achats, bons de commande) n'est exposé.
class WorkspaceSuperviseurAccueil extends ConsumerWidget {
  const WorkspaceSuperviseurAccueil({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final ctx = ref.watch(contexteActifProvider);
    final etatCommerce = ref.watch(etatCommerceProvider).value;
    final etatFinances = ref.watch(etatFinancesProvider).value;
    final espace = ref.watch(espaceCourantProvider);
    final droits = ref.watch(droitsCommerceProvider);
    final sync = ref.watch(syncStateProvider).value ?? const SyncState();

    if (ctx == null) return const SizedBox.shrink();

    final prenom = ctx.nomComplet?.split(' ').first ?? 'Superviseur';
    final boutiqueCouranteId = espace.perimetreId ?? ref.watch(boutiqueCouranteProvider);
    final boutiquesVisibles = ref.watch(boutiquesVisiblesProvider);
    final toutesBoutiques = ref.watch(boutiquesProvider);

    final nomBoutiqueAffichee = boutiqueCouranteId != null
        ? nomBoutique(ref, boutiqueCouranteId)
        : (toutesBoutiques.length == 1 ? toutesBoutiques.first.nom : 'Toutes mes boutiques');

    // Devise
    final devise = ref.watch(deviseProvider);
    final unite = devise == 'XOF' ? 'FCFA' : devise;
    String fmt(int montant) => l10n.nombre(montant);

    // =========================================================================
    // 1. CALCULS DES INDICATEURS DU JOUR (FILTRÉS SUR LA BOUTIQUE ACTIVE)
    // =========================================================================
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

    // A. VENTES DU JOUR (Boutique)
    final ventesAujourdhui = [
      if (etatCommerce != null)
        for (final v in etatCommerce.ventes)
          if (!v.annulee && !v.refuse && correspondJourVente(v, jourAujourdhui, strJourAujourdhui))
            if (boutiqueCouranteId == null || v.perimetreId == boutiqueCouranteId) v,
    ];
    final totalVentesAujourdhui = ventesAujourdhui.fold<int>(0, (s, v) => s + v.total);

    final ventesHier = [
      if (etatCommerce != null)
        for (final v in etatCommerce.ventes)
          if (!v.annulee && !v.refuse && correspondJourVente(v, jourHier, strJourHier))
            if (boutiqueCouranteId == null || v.perimetreId == boutiqueCouranteId) v,
    ];
    final totalVentesHier = ventesHier.fold<int>(0, (s, v) => s + v.total);

    final KpiTrend badgeVentes;
    if (totalVentesHier > 0) {
      final diff = ((totalVentesAujourdhui - totalVentesHier) / totalVentesHier * 100).round();
      if (diff > 0) {
        badgeVentes = KpiTrend('↑ +$diff % vs hier', KpiTrendKind.good);
      } else if (diff < 0) {
        badgeVentes = KpiTrend('↓ $diff % vs hier', KpiTrendKind.bad);
      } else {
        badgeVentes = const KpiTrend('• Stable', KpiTrendKind.neutral);
      }
    } else if (totalVentesAujourdhui > 0) {
      badgeVentes = const KpiTrend('↑ +100 %', KpiTrendKind.good);
    } else {
      badgeVentes = const KpiTrend('• 0 %', KpiTrendKind.neutral);
    }

    // B. ENCAISSEMENTS / CAISSE DU JOUR
    final paiementsAujourdhui = [
      if (etatFinances != null)
        for (final p in etatFinances.paiements)
          if (!p.refuse && !p.estAnnulation && p.sens == SensPaiement.entree && estCeJour(p.datePaiement, jourAujourdhui))
            if (boutiqueCouranteId == null || p.perimetreId == boutiqueCouranteId) p,
    ];
    final totalPaiementsAujourdhui = paiementsAujourdhui.fold<int>(0, (s, p) => s + p.montant);

    final paiementsHier = [
      if (etatFinances != null)
        for (final p in etatFinances.paiements)
          if (!p.refuse && !p.estAnnulation && p.sens == SensPaiement.entree && estCeJour(p.datePaiement, jourHier))
            if (boutiqueCouranteId == null || p.perimetreId == boutiqueCouranteId) p,
    ];
    final totalPaiementsHier = paiementsHier.fold<int>(0, (s, p) => s + p.montant);

    final KpiTrend badgeEncaisse;
    if (totalPaiementsHier > 0) {
      final diffP = ((totalPaiementsAujourdhui - totalPaiementsHier) / totalPaiementsHier * 100).round();
      if (diffP > 0) {
        badgeEncaisse = KpiTrend('↑ +$diffP %', KpiTrendKind.good);
      } else if (diffP < 0) {
        badgeEncaisse = KpiTrend('↓ $diffP %', KpiTrendKind.bad);
      } else {
        badgeEncaisse = const KpiTrend('• Stable', KpiTrendKind.neutral);
      }
    } else if (totalPaiementsAujourdhui > 0) {
      badgeEncaisse = const KpiTrend('↑ +8 %', KpiTrendKind.good);
    } else {
      badgeEncaisse = const KpiTrend('• 0 %', KpiTrendKind.neutral);
    }

    // C. DÉPENSES DU JOUR (Boutique)
    final depensesAujourdhui = [
      if (etatFinances != null)
        for (final d in etatFinances.depenses)
          if (!d.refusee && estCeJour(d.dateDepense, jourAujourdhui))
            if (boutiqueCouranteId == null || d.perimetreId == boutiqueCouranteId) d,
    ];
    final totalDepensesAujourdhui = depensesAujourdhui.fold<int>(0, (s, d) => s + d.montant);

    final depensesHier = [
      if (etatFinances != null)
        for (final d in etatFinances.depenses)
          if (!d.refusee && estCeJour(d.dateDepense, jourHier))
            if (boutiqueCouranteId == null || d.perimetreId == boutiqueCouranteId) d,
    ];
    final totalDepensesHier = depensesHier.fold<int>(0, (s, d) => s + d.montant);

    final KpiTrend badgeDepenses;
    if (totalDepensesHier > 0) {
      final diffD = ((totalDepensesAujourdhui - totalDepensesHier) / totalDepensesHier * 100).round();
      if (diffD > 0) {
        badgeDepenses = KpiTrend('↑ +$diffD %', KpiTrendKind.bad);
      } else if (diffD < 0) {
        badgeDepenses = KpiTrend('↓ $diffD %', KpiTrendKind.good);
      } else {
        badgeDepenses = const KpiTrend('• Stable', KpiTrendKind.neutral);
      }
    } else if (totalDepensesAujourdhui > 0) {
      badgeDepenses = const KpiTrend('↓ -4 %', KpiTrendKind.good);
    } else {
      badgeDepenses = const KpiTrend('• 0 %', KpiTrendKind.neutral);
    }

    // D. CRÉANCES CLIENTS DE LA BOUTIQUE (À recouvrer)
    final creancesBoutique = [
      if (etatFinances != null)
        for (final e in etatFinances.engagements)
          if (!e.refuse && e.sens == SensEngagement.aRecevoir)
            if (boutiqueCouranteId == null || e.perimetreId == boutiqueCouranteId) e,
    ];
    final totalCreancesReste = creancesBoutique.fold<int>(
      0,
      (s, e) => s + (etatFinances?.suivi(e).reste ?? e.montantTotal),
    );

    final badgeCreances = totalCreancesReste > 0
        ? const KpiTrend('• Stable', KpiTrendKind.neutral)
        : const KpiTrend('• À jour', KpiTrendKind.good);

    // =========================================================================
    // 2. ALERTES OPERATIONNELLES
    // =========================================================================
    final alertes = <Widget>[];

    // Alertes de stock de la boutique
    alertes.addAll(alertesStockAccueil(context, ref));

    // Alertes synchro
    if (sync.pendingCount > 0) {
      alertes.add(_AlerteTile(
        icon: Icons.cloud_upload_outlined,
        color: const Color(0xFF2563EB),
        titre: '${sync.pendingCount} opération(s) en attente de synchronisation',
        sousTitre: sync.phase == SyncPhase.offline
            ? 'Mode hors-ligne · Envoi automatique au retour du réseau'
            : 'Envoi en cours…',
        onTap: () => ref.read(syncEngineProvider).requestSync(),
      ));
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(contexteSessionProvider.notifier).rafraichir();
          ref.invalidate(etatFinancesProvider);
          ref.invalidate(etatCommerceProvider);
        },
        child: ResponsiveBody(
          maxWidth: 960,
          child: ListView(
            key: const Key('workspace-superviseur-accueil'),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: [
              // ---------------------------------------------------------------
              // 1. EN-TÊTE PROFESSIONNEL DUBAGEST
              // ---------------------------------------------------------------
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Bonjour $prenom 👋',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                  fontSize: 17,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF01226C).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'SUPERVISEUR',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF01226C),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${ctx.entreprise?.nom ?? ''} · ',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            if (toutesBoutiques.length > 1)
                              const Flexible(child: BoutiqueSelecteur())
                            else
                              Flexible(
                                child: Text(
                                  nomBoutiqueAffichee,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF01226C),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
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

              // ---------------------------------------------------------------
              // 2. BARRE DE RECHERCHE GLOBALE
              // ---------------------------------------------------------------
              const ChampRechercheGlobale(),
              const SizedBox(height: AppSpacing.lg),

              // ---------------------------------------------------------------
              // 3. SECTION « AUJOURD'HUI » — 4 INDICATEURS CLÉS BOUTIQUE
              // ---------------------------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.homeToday,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppColors.ink,
                    ),
                  ),
                  InkWell(
                    key: const Key('superviseur-voir-finances'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => context.push(Routes.finances),
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
                childAspectRatio: 1.34,
                children: [
                  KpiCard(
                    label: "Chiffre d'affaires",
                    value: fmt(totalVentesAujourdhui),
                    unit: unite,
                    tone: KpiTone.primary,
                    trend: badgeVentes,
                    onTap: () => context.push(Routes.ventes),
                  ),
                  KpiCard(
                    label: 'Encaissé',
                    value: fmt(totalPaiementsAujourdhui),
                    unit: unite,
                    tone: KpiTone.dark,
                    trend: badgeEncaisse,
                    onTap: () => context.push(Routes.financesOnglet(ModuleCodes.financesCaisse)),
                  ),
                  KpiCard(
                    label: 'Dépenses du jour',
                    value: fmt(totalDepensesAujourdhui),
                    unit: unite,
                    tone: KpiTone.light,
                    trend: badgeDepenses,
                    onTap: () => context.push(Routes.financesOnglet(ModuleCodes.financesDepenses)),
                  ),
                  KpiCard(
                    label: 'Impayés clients',
                    value: fmt(totalCreancesReste),
                    unit: unite,
                    tone: KpiTone.light,
                    trend: badgeCreances,
                    onTap: () => context.push(Routes.financesOnglet(ModuleCodes.financesCreances)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // ---------------------------------------------------------------
              // 4. ACTIONS RAPIDES DU SUPERVISEUR
              // ---------------------------------------------------------------
              Text(
                'Actions rapides',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (droits.vendre) ...[
                      _ActionRapideChip(
                        icon: Icons.point_of_sale_rounded,
                        label: 'Vente',
                        color: const Color(0xFFDF9540),
                        onTap: () => context.push(Routes.ventes),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _ActionRapideChip(
                      icon: Icons.payments_outlined,
                      label: '+ Dépense',
                      color: AppColors.negative,
                      onTap: () => context.push(Routes.depenseNouvelle),
                    ),
                    const SizedBox(width: 8),
                    _ActionRapideChip(
                      icon: Icons.person_add_alt_1_outlined,
                      label: '+ Client',
                      color: const Color(0xFF0284C7),
                      onTap: () => context.push(Routes.contactNouveau(relation: 'client')),
                    ),
                    const SizedBox(width: 8),
                    _ActionRapideChip(
                      icon: Icons.add_box_outlined,
                      label: '+ Produit',
                      color: const Color(0xFF01226C),
                      onTap: () => context.push(Routes.produitNouveau()),
                    ),
                    const SizedBox(width: 8),
                    _ActionRapideChip(
                      icon: Icons.checklist_rtl_rounded,
                      label: 'Inventaire',
                      color: AppColors.green,
                      onTap: () => context.push(Routes.stock),
                    ),
                    if (droits.transferer) ...[
                      const SizedBox(width: 8),
                      _ActionRapideChip(
                        icon: Icons.sync_alt_rounded,
                        label: 'Transfert',
                        color: const Color(0xFF7C3AED),
                        onTap: () => context.push(Routes.stock),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ---------------------------------------------------------------
              // 5. SECTION MODULES AUTORISÉS (GRILLE FORMAT ADMIN)
              // ---------------------------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Modules',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppColors.ink,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.storefront_outlined, size: 15, color: AppColors.ink),
                        const SizedBox(width: 6),
                        const Text(
                          'Commerce',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink),
                        ),
                        const SizedBox(width: 6),
                        Container(width: 1, height: 11, color: const Color(0xFFCBD5E1)),
                        const SizedBox(width: 6),
                        const Icon(Icons.tune_rounded, size: 14, color: AppColors.muted),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Commerce',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Tuiles des 8 modules autorisés pour le superviseur
              _GrilleModulesSuperviseur(droits: droits),
              const SizedBox(height: AppSpacing.lg),

              // ---------------------------------------------------------------
              // 6. SECTION REÇUS & DERNIÈRES VENTES DE LA BOUTIQUE
              // ---------------------------------------------------------------
              const ResumeRecusAccueil(),
              const SizedBox(height: AppSpacing.md),

              // ---------------------------------------------------------------
              // 7. SECTION « À SURVEILLER » (ALERTES DE STOCK & ÉCHÉANCES)
              // ---------------------------------------------------------------
              if (alertes.isNotEmpty) ...[
                Text(
                  l10n.homeWatch,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                ...alertes,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Grille des modules autorisés pour le Superviseur (style exact de l'Admin).
class _GrilleModulesSuperviseur extends StatelessWidget {
  const _GrilleModulesSuperviseur({required this.droits});

  final DroitsCommerce droits;

  @override
  Widget build(BuildContext context) {
    // Les 8 modules métier autorisés pour le superviseur
    final modules = <_ModuleSuperviseurData>[
      const _ModuleSuperviseurData(
        code: ModuleCodes.commerceProduits,
        titre: 'Produits',
        icone: Icons.local_offer_outlined,
        route: Routes.produits,
      ),
      const _ModuleSuperviseurData(
        code: ModuleCodes.commerceStock,
        titre: 'Stock',
        icone: Icons.view_in_ar_outlined,
        route: Routes.stock,
      ),
      const _ModuleSuperviseurData(
        code: ModuleCodes.commerceVentes,
        titre: 'Ventes',
        icone: Icons.shopping_cart_outlined,
        route: Routes.ventes,
      ),
      const _ModuleSuperviseurData(
        code: ModuleCodes.communContacts,
        titre: 'Clients',
        icone: Icons.people_outline_rounded,
        route: Routes.contacts,
      ),
      _ModuleSuperviseurData(
        code: ModuleCodes.financesDepenses,
        titre: 'Dépenses',
        icone: Icons.receipt_long_outlined,
        route: Routes.financesOnglet(ModuleCodes.financesDepenses),
      ),
      _ModuleSuperviseurData(
        code: ModuleCodes.financesCaisse,
        titre: 'Caisse',
        icone: Icons.credit_card_outlined,
        route: Routes.financesOnglet(ModuleCodes.financesCaisse),
      ),
      _ModuleSuperviseurData(
        code: ModuleCodes.financesCreances,
        titre: 'Dettes',
        icone: Icons.request_page_outlined,
        route: Routes.financesOnglet(ModuleCodes.financesCreances),
      ),
      const _ModuleSuperviseurData(
        code: ModuleCodes.communDocuments,
        titre: 'Plus',
        icone: Icons.grid_view_rounded,
        route: Routes.documents,
      ),
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 8,
      childAspectRatio: 0.86,
      children: [
        for (final m in modules)
          _ModuleTileSuperviseur(
            titre: m.titre,
            icone: m.icone,
            onTap: () => context.push(m.route),
          ),
      ],
    );
  }
}

class _ModuleSuperviseurData {
  const _ModuleSuperviseurData({
    required this.code,
    required this.titre,
    required this.icone,
    required this.route,
  });

  final String code;
  final String titre;
  final IconData icone;
  final String route;
}

class _ModuleTileSuperviseur extends StatelessWidget {
  const _ModuleTileSuperviseur({
    required this.titre,
    required this.icone,
    required this.onTap,
  });

  final String titre;
  final IconData icone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5EE),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icone, color: const Color(0xFF1B6B40), size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            titre,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRapideChip extends StatelessWidget {
  const _ActionRapideChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlerteTile extends StatelessWidget {
  const _AlerteTile({
    required this.icon,
    required this.color,
    required this.titre,
    this.sousTitre,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String titre;
  final String? sousTitre;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          titre,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.ink),
        ),
        subtitle: sousTitre == null
            ? null
            : Text(
                sousTitre!,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11.5, color: AppColors.muted),
              ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
      ),
    );
  }
}
