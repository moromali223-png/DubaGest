import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../agenda/domain/entities/agenda.dart';
import '../../../agenda/presentation/widgets/bouton_relance.dart';
import '../../domain/entities/dossier_dette.dart';
import '../../domain/entities/finances.dart';
import '../providers/dossiers_dettes_providers.dart';
import '../providers/finances_providers.dart';
import '../widgets/dialog_recevoir_paiement_dossier.dart';
import '../widgets/finances_widgets.dart';
import '../widgets/releve_compte_modal.dart';

/// Page complète du Dossier Financier d'une personne (Client ou Fournisseur).
/// « Une personne = un dossier financier complet ».
class DossierDettePage extends ConsumerStatefulWidget {
  const DossierDettePage({
    super.key,
    required this.dossierKey,
    this.sens = SensEngagement.aRecevoir,
  });

  final String dossierKey;
  final SensEngagement sens;

  @override
  ConsumerState<DossierDettePage> createState() => _DossierDettePageState();
}

class _DossierDettePageState extends ConsumerState<DossierDettePage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dossierAsync = ref.watch(
      dossierDetteDetailsProvider((dossierKey: widget.dossierKey, sens: widget.sens)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.sens == SensEngagement.aRecevoir
              ? 'Dossier Créance Client'
              : 'Dossier Dette Fournisseur',
        ),
        actions: const [
          SyncStatusButton(),
        ],
      ),
      body: ResponsiveBody(
        maxWidth: 960,
        child: AsyncValueView<DossierDette?>(
          value: dossierAsync,
          onRetry: () => ref.invalidate(etatFinancesProvider),
          isEmpty: (d) => d == null,
          emptyMessage: l10n.financeNotFound,
          data: (dossier) {
            if (dossier == null) {
              return const EmptyView(icon: Icons.person_off_rounded, message: 'Dossier introuvable');
            }
            return _ContenuDossierDette(
              dossier: dossier,
              tabController: _tabController,
            );
          },
        ),
      ),
    );
  }
}

class _ContenuDossierDette extends ConsumerWidget {
  const _ContenuDossierDette({
    required this.dossier,
    required this.tabController,
  });

  final DossierDette dossier;
  final TabController tabController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final devise = ref.watch(deviseProvider);
    final droits = ref.watch(droitsFinancesProvider);
    final estRecevoir = dossier.sens == SensEngagement.aRecevoir;

    // Statut & couleurs
    final (fondStatut, couleurStatut, texteStatut, iconeStatut) = switch (dossier.statutGlobal) {
      StatutDossierDette.enRetard => (
          AppColors.negativeSoft,
          AppColors.negative,
          dossier.totalEnRetard > 0
              ? '🔴 ${l10n.montant(dossier.totalEnRetard, devise)} en retard'
              : '🔴 En retard',
          Icons.error_outline_rounded,
        ),
      StatutDossierDette.bientot => (
          AppColors.warningSoft,
          AppColors.warning,
          '🟠 À payer bientôt',
          Icons.schedule_rounded,
        ),
      StatutDossierDette.aJour => (
          AppColors.positiveSoft,
          AppColors.positive,
          '🟢 À jour',
          Icons.check_circle_outline_rounded,
        ),
      StatutDossierDette.regle => (
          AppColors.background,
          AppColors.muted,
          '✓ Réglé',
          Icons.task_alt_rounded,
        ),
    };

    final initiales = dossier.nomAffiche.trim().isEmpty
        ? '?'
        : dossier.nomAffiche.trim().characters.first.toUpperCase();

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. En-tête : Avatar + Nom + Téléphone + Badge statut global
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: dossier.estEnRetard
                          ? AppColors.negative.withValues(alpha: 0.3)
                          : AppColors.border,
                      width: dossier.estEnRetard ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: dossier.estEnRetard
                                ? AppColors.negativeSoft
                                : const Color(0xFF01226C).withValues(alpha: 0.1),
                            foregroundColor: dossier.estEnRetard ? AppColors.negative : const Color(0xFF01226C),
                            child: Text(
                              initiales,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dossier.nomAffiche,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    color: AppColors.ink,
                                  ),
                                ),
                                if (dossier.telephone != null && dossier.telephone!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    dossier.telephone!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: fondStatut,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(iconeStatut, size: 14, color: couleurStatut),
                                const SizedBox(width: 4),
                                Text(
                                  texteStatut,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: couleurStatut,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: AppColors.border),

                      // Montant principal en évidence
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                estRecevoir ? 'Reste à recevoir' : 'Reste à payer',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.montant(dossier.reste, devise),
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: dossier.estEnRetard ? AppColors.negative : const Color(0xFF01226C),
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          if (dossier.contactId != null)
                            TextButton.icon(
                              onPressed: () => context.push(Routes.contact(dossier.contactId!)),
                              icon: const Icon(Icons.person_outline_rounded, size: 16),
                              label: const Text('Fiche contact'),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Barre de progression du règlement
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: dossier.totalDu > 0 ? (dossier.totalPaye / dossier.totalDu).clamp(0.0, 1.0) : 1.0,
                          minHeight: 8,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            dossier.estEnRetard ? AppColors.warning : AppColors.green,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Taux de règlement : ${dossier.tauxReglement.toStringAsFixed(0)} %',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted),
                            ),
                          ),
                          if (dossier.prochaineEcheance != null && dossier.reste > 0) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                'Prochaine échéance : ${l10n.date(dossier.prochaineEcheance!)}',
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: dossier.estEnRetard ? AppColors.negative : AppColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 2. Les 4 KPI Clés du Dossier (Exigence 8 & 21)
                _GrilleKpisDossier(dossier: dossier),
                const SizedBox(height: AppSpacing.md),

                // 3. Actions Principales (Recevoir un paiement, Relevé, Relance)
                Row(
                  children: [
                    if (dossier.reste > 0 && (estRecevoir ? droits.encaisser : droits.decaisser))
                      Expanded(
                        flex: 3,
                        child: FilledButton.icon(
                          key: const Key('dossier-bouton-paiement'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF01226C),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => DialogRecevoirPaiementDossier.show(context, dossier),
                          icon: Icon(estRecevoir ? Icons.add_circle_outline_rounded : Icons.payment_rounded, size: 20),
                          label: Text(
                            estRecevoir ? '+ Recevoir un paiement' : '+ Effectuer un paiement',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ),
                      ),
                    if (dossier.reste > 0 && (estRecevoir ? droits.encaisser : droits.decaisser))
                      const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        key: const Key('dossier-bouton-releve'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => ReleveCompteModal.show(context, dossier),
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: const Text('Relevé', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
                if (dossier.contactId != null && dossier.reste > 0 && estRecevoir) ...[
                  const SizedBox(height: AppSpacing.xs),
                  BoutonRelance(
                    cibleType: CibleType.engagement,
                    cibleId: dossier.engagements.firstOrNull?.engagement.id ?? dossier.contactId!,
                    titre: l10n.agendaFollowUpTitle(dossier.nomAffiche),
                  ),
                ],
              ],
            ),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _SliverTabBarDelegate(
            TabBar(
              controller: tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: const Color(0xFF01226C),
              unselectedLabelColor: AppColors.muted,
              indicatorColor: const Color(0xFF01226C),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.description_outlined, size: 14),
                      const SizedBox(width: 4),
                      Text('Dettes (${dossier.nbDettesActives})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_note_rounded, size: 14),
                      const SizedBox(width: 4),
                      Text('Échéances (${dossier.echeances.where((e) => e.montantReste > 0).length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history_rounded, size: 14),
                      const SizedBox(width: 4),
                      Text('Historique (${dossier.timeline.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: tabController,
        children: [
          _SectionDettesEnCours(dossier: dossier),
          _SectionEcheancesDossier(dossier: dossier),
          _SectionHistoriqueTimeline(dossier: dossier),
        ],
      ),
    );
  }
}

/// Les 4 indicateurs majeurs du dossier : Total dû, Déjà payé, Reste, En retard
class _GrilleKpisDossier extends ConsumerWidget {
  const _GrilleKpisDossier({required this.dossier});
  final DossierDette dossier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final devise = ref.watch(deviseProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final colWidth = (constraints.maxWidth - AppSpacing.sm * 3) / 4;
        final compact = constraints.maxWidth < 480;

        if (compact) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _KpiBox(
                      titre: 'Total dû',
                      valeur: l10n.montant(dossier.totalDu, devise),
                      icone: Icons.receipt_rounded,
                      couleur: AppColors.ink,
                      fond: AppColors.background,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _KpiBox(
                      titre: 'Déjà payé',
                      valeur: l10n.montant(dossier.totalPaye, devise),
                      icone: Icons.check_circle_rounded,
                      couleur: AppColors.green,
                      fond: AppColors.greenSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _KpiBox(
                      titre: 'Reste',
                      valeur: l10n.montant(dossier.reste, devise),
                      icone: Icons.account_balance_wallet_rounded,
                      couleur: const Color(0xFF01226C),
                      fond: const Color(0xFF01226C).withValues(alpha: 0.08),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _KpiBox(
                      titre: 'En retard',
                      valeur: l10n.montant(dossier.totalEnRetard, devise),
                      icone: Icons.error_rounded,
                      couleur: dossier.totalEnRetard > 0 ? AppColors.negative : AppColors.muted,
                      fond: dossier.totalEnRetard > 0 ? AppColors.negativeSoft : AppColors.background,
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _KpiBox(
                titre: 'Total dû',
                valeur: l10n.montant(dossier.totalDu, devise),
                icone: Icons.receipt_rounded,
                couleur: AppColors.ink,
                fond: AppColors.background,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _KpiBox(
                titre: 'Déjà payé',
                valeur: l10n.montant(dossier.totalPaye, devise),
                icone: Icons.check_circle_rounded,
                couleur: AppColors.green,
                fond: AppColors.greenSoft,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _KpiBox(
                titre: 'Reste',
                valeur: l10n.montant(dossier.reste, devise),
                icone: Icons.account_balance_wallet_rounded,
                couleur: const Color(0xFF01226C),
                fond: const Color(0xFF01226C).withValues(alpha: 0.08),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _KpiBox(
                titre: 'En retard',
                valeur: l10n.montant(dossier.totalEnRetard, devise),
                icone: Icons.error_rounded,
                couleur: dossier.totalEnRetard > 0 ? AppColors.negative : AppColors.muted,
                fond: dossier.totalEnRetard > 0 ? AppColors.negativeSoft : AppColors.background,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _KpiBox extends StatelessWidget {
  const _KpiBox({
    required this.titre,
    required this.valeur,
    required this.icone,
    required this.couleur,
    required this.fond,
  });

  final String titre;
  final String valeur;
  final IconData icone;
  final Color couleur;
  final Color fond;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 14, color: couleur),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  titre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            valeur,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: couleur,
            ),
          ),
        ],
      ),
    );
  }
}

/// SECTION 1 : Dettes en cours avec traçabilité vers document source (REC-xxx, ACH-xxx, etc.)
class _SectionDettesEnCours extends ConsumerWidget {
  const _SectionDettesEnCours({required this.dossier});
  final DossierDette dossier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final devise = ref.watch(deviseProvider);
    final liste = dossier.engagements.where((x) => !x.engagement.annule).toList();

    if (liste.isEmpty) {
      return const Center(
        child: EmptyView(
          icon: Icons.task_alt_rounded,
          message: 'Aucune dette en cours. Tout est en règle !',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: liste.length,
      itemBuilder: (context, index) {
        final suivi = liste[index];
        final e = suivi.engagement;
        final etat = suivi.etat(DateTime.now());
        final estRetard = etat == EtatReglement.enRetard;

        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: estRetard ? AppColors.negative.withValues(alpha: 0.3) : AppColors.border,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.push(Routes.engagement(e.id)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ligne 1 : Titre + Badge d'état
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          e.libelle,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                      EtatReglementChip(etat: etat, sens: e.sens),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Tag d'origine traçable (Vente #REC, Loyer #LOC, etc.)
                  if (e.origineType != 'MANUEL') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF01226C).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Source : ${e.origineType}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF01226C),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Ligne 2 : Montants (Total, Payé, Reste)
                  Row(
                    children: [
                      Expanded(
                        child: _ColonneMontant(
                          titre: 'Total',
                          valeur: l10n.montant(e.montantTotal, devise),
                        ),
                      ),
                      Expanded(
                        child: _ColonneMontant(
                          titre: 'Payé',
                          valeur: l10n.montant(suivi.regle, devise),
                          couleur: AppColors.green,
                        ),
                      ),
                      Expanded(
                        child: _ColonneMontant(
                          titre: 'Reste',
                          valeur: l10n.montant(suivi.reste, devise),
                          couleur: estRetard ? AppColors.negative : const Color(0xFF01226C),
                          gras: true,
                        ),
                      ),
                    ],
                  ),

                  if (e.echeance != null) ...[
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Échéance : ${l10n.date(e.echeance!)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: estRetard ? AppColors.negative : AppColors.muted,
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.muted),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ColonneMontant extends StatelessWidget {
  const _ColonneMontant({
    required this.titre,
    required this.valeur,
    this.couleur,
    this.gras = false,
  });

  final String titre;
  final String valeur;
  final Color? couleur;
  final bool gras;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titre, style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(
          valeur,
          style: TextStyle(
            fontSize: 13,
            fontWeight: gras ? FontWeight.w900 : FontWeight.w700,
            color: couleur ?? AppColors.ink,
          ),
        ),
      ],
    );
  }
}

/// SECTION 2 : Échéances classées chronologiquement (Aujourd'hui, Cette semaine, En retard, etc.)
class _SectionEcheancesDossier extends ConsumerWidget {
  const _SectionEcheancesDossier({required this.dossier});
  final DossierDette dossier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final devise = ref.watch(deviseProvider);
    final liste = dossier.echeances.where((e) => e.montantReste > 0).toList();

    if (liste.isEmpty) {
      return const Center(
        child: EmptyView(
          icon: Icons.event_available_rounded,
          message: 'Aucune échéance à venir pour ce dossier.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: liste.length,
      itemBuilder: (context, index) {
        final ech = liste[index];
        final (fond, couleur, label) = switch (ech.statut) {
          StatutEcheanceItem.enRetard => (
              AppColors.negativeSoft,
              AppColors.negative,
              '🔴 ${ech.retardJours > 0 ? '${ech.retardJours} j de retard' : 'En retard'}',
            ),
          StatutEcheanceItem.aujourdhui => (
              AppColors.warningSoft,
              AppColors.warning,
              '🟠 Aujourd\'hui',
            ),
          StatutEcheanceItem.cetteSemaine => (
              AppColors.warningSoft,
              AppColors.warning,
              '🟠 Cette semaine',
            ),
          StatutEcheanceItem.semaineProchaine => (
              AppColors.positiveSoft,
              AppColors.positive,
              '🟢 Semaine prochaine',
            ),
          StatutEcheanceItem.plusTard => (
              AppColors.background,
              AppColors.muted,
              '🟢 À venir',
            ),
          StatutEcheanceItem.reglee => (
              AppColors.background,
              AppColors.muted,
              '✓ Réglée',
            ),
        };

        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: fond,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ech.dateEcheance.day.toString(),
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: couleur),
                  ),
                  Text(
                    l10n.date(ech.dateEcheance).split(' ').take(2).last.toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: couleur),
                  ),
                ],
              ),
            ),
            title: Text(
              ech.libelle,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            subtitle: Text(
              [
                l10n.date(ech.dateEcheance),
                if (ech.origineType != 'MANUEL') ech.origineType,
              ].join(' · '),
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  l10n.montant(ech.montantReste, devise),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: ech.estEnRetard ? AppColors.negative : const Color(0xFF01226C),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: couleur),
                  ),
                ),
              ],
            ),
            onTap: () => context.push(Routes.engagement(ech.engagementId)),
          ),
        );
      },
    );
  }
}

/// SECTION 3 : Historique / Timeline financière avec solde progressif
class _SectionHistoriqueTimeline extends ConsumerWidget {
  const _SectionHistoriqueTimeline({required this.dossier});
  final DossierDette dossier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final devise = ref.watch(deviseProvider);
    final timeline = dossier.timeline;

    if (timeline.isEmpty) {
      return const Center(
        child: EmptyView(
          icon: Icons.history_toggle_off_rounded,
          message: 'Aucun historique financier pour le moment.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: timeline.length,
      itemBuilder: (context, index) {
        final ev = timeline[index];
        final estPaiement = ev.estPaiement;
        final estAnnule = ev.type == TypeEvenementDette.annulation;

        final (icone, couleur, fond) = switch (ev.type) {
          TypeEvenementDette.paiementRecu => (Icons.south_west_rounded, AppColors.green, AppColors.greenSoft),
          TypeEvenementDette.paiementEmis => (Icons.north_east_rounded, AppColors.negative, AppColors.negativeSoft),
          TypeEvenementDette.creationDette => (Icons.add_shopping_cart_rounded, const Color(0xFF01226C), const Color(0xFF01226C).withValues(alpha: 0.08)),
          TypeEvenementDette.annulation => (Icons.block_rounded, AppColors.muted, AppColors.background),
        };

        final signe = estPaiement ? '-' : '+';

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicateur timeline
              Column(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: fond,
                    foregroundColor: couleur,
                    child: Icon(icone, size: 18),
                  ),
                  if (index < timeline.length - 1)
                    Container(
                      width: 2,
                      height: 40,
                      color: AppColors.border,
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),

              // Carte de l'événement
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            ev.type.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: couleur,
                            ),
                          ),
                          Text(
                            '$signe ${l10n.montant(ev.montant, devise)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: couleur,
                              decoration: estAnnule ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ev.libelle,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            [
                              l10n.dateTime(ev.date),
                              if (ev.mode != null) l10n.modePaiement(ev.mode!),
                            ].join(' · '),
                            style: const TextStyle(fontSize: 11, color: AppColors.muted),
                          ),
                          Text(
                            'Solde dû : ${l10n.montant(ev.soldeProgressif, devise)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF01226C),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: AppColors.surface,
      elevation: overlapsContent ? 2 : 0,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
