import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/config_providers.dart';
import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/permissions/access_decision.dart';
import '../../../../core/permissions/permission_codes.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../invitations/domain/entities/invitation.dart';
import '../../../invitations/presentation/providers/invitations_providers.dart';
import '../../../invitations/presentation/widgets/inviter_sheet.dart';
import '../../../modules/domain/entities/app_module.dart';
import '../../../perimetres/domain/entities/perimetre.dart';
import '../../../perimetres/presentation/providers/perimetres_providers.dart';
import '../../domain/entities/membre.dart';
import '../providers/membres_providers.dart';
import '../widgets/affectations_sheet.dart';

class UtilisateursPage extends ConsumerStatefulWidget {
  const UtilisateursPage({super.key});

  @override
  ConsumerState<UtilisateursPage> createState() => _UtilisateursPageState();
}

class _UtilisateursPageState extends ConsumerState<UtilisateursPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _filtreStatut = 'TOUS'; // 'TOUS', 'ACTIF', 'SUSPENDU'
  String _filtreInvitation = 'TOUTES'; // 'TOUTES', 'PENDING', 'ARCHIVEES'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ctx = ref.watch(contexteActifProvider);
    final membresAsync = ref.watch(membresProvider);
    final invitationsAsync = ref.watch(invitationsProvider);

    if (ctx == null) return const Scaffold(body: LoadingView());

    final peutGerer = ctx.permissionEngine.has(PermissionCodes.usersManage);
    final peutInviter = ctx.permissionEngine.has(PermissionCodes.usersInvite);
    final limites = ctx.limites();
    final maxUtilisateurs = limites.maxUtilisateurs;
    final totalOccupes = ctx.consommation.totalOccupes;
    final actifs = ctx.consommation.actifs;
    final enAttente = ctx.consommation.enAttente;

    final estPlein = maxUtilisateurs != null && totalOccupes >= maxUtilisateurs;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.moduleAdminUtilisateurs),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.green,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.green,
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: const Icon(Icons.people_alt_rounded),
              text: 'Membres (${membresAsync.value?.length ?? 0})',
            ),
            Tab(
              icon: const Icon(Icons.mail_outline_rounded),
              text: 'Invitations (${invitationsAsync.value?.where((i) => i.statutEffectif(DateTime.now()) == InvitationStatut.pending).length ?? 0})',
            ),
            const Tab(
              icon: Icon(Icons.shield_outlined),
              text: 'Rôles & Droits',
            ),
          ],
        ),
      ),
      floatingActionButton: (!peutInviter || _tabController.index == 2)
          ? null
          : FloatingActionButton.extended(
              key: const Key('users-invite'),
              backgroundColor: estPlein ? AppColors.muted : AppColors.green,
              foregroundColor: Colors.white,
              onPressed: () {
                final decision = ref.read(verifierAjoutMembreProvider).call(ctx);
                if (decision is AccessDenied) {
                  showMessageSnackBar(context, l10n.decision(decision));
                } else {
                  showInviterSheet(context);
                }
              },
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(l10n.usersInvite),
            ),
      body: ResponsiveBody(
        child: Column(
          children: [
            // 1. Bandeau de capacité haute définition
            _CapaciteJaugeCard(
              totalOccupes: totalOccupes,
              maxUtilisateurs: maxUtilisateurs,
              actifs: actifs,
              enAttente: enAttente,
              planNom: ctx.plan?.nom ?? 'Standard',
              estPlein: estPlein,
              onUpgrade: () => context.push(ModuleRoutes.path(ModuleCodes.adminAbonnement)),
            ),

            // 2. Contenu des 3 onglets
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Onglet 1 : Membres
                  _MembresTab(
                    membresAsync: membresAsync,
                    ctx: ctx,
                    peutGerer: peutGerer,
                    searchController: _searchController,
                    filtreStatut: _filtreStatut,
                    onFiltreChanged: (val) => setState(() => _filtreStatut = val),
                    onRefresh: () => ref.refresh(membresProvider.future),
                    onRetry: () => ref.invalidate(membresProvider),
                  ),

                  // Onglet 2 : Invitations
                  _InvitationsTab(
                    invitationsAsync: invitationsAsync,
                    filtreInvitation: _filtreInvitation,
                    onFiltreChanged: (val) => setState(() => _filtreInvitation = val),
                    onRefresh: () => ref.refresh(invitationsProvider.future),
                    onRetry: () => ref.invalidate(invitationsProvider),
                  ),

                  // Onglet 3 : Matrice Rôles & Droits
                  _RolesTab(ctx: ctx),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte élégante avec jauge visuelle de quota d'utilisateurs
class _CapaciteJaugeCard extends StatelessWidget {
  const _CapaciteJaugeCard({
    required this.totalOccupes,
    required this.maxUtilisateurs,
    required this.actifs,
    required this.enAttente,
    required this.planNom,
    required this.estPlein,
    required this.onUpgrade,
  });

  final int totalOccupes;
  final int? maxUtilisateurs;
  final int actifs;
  final int enAttente;
  final String planNom;
  final bool estPlein;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final double ratio = maxUtilisateurs == null || maxUtilisateurs == 0
        ? 0.0
        : (totalOccupes / maxUtilisateurs!).clamp(0.0, 1.0);

    final Color jaugeColor = maxUtilisateurs == null
        ? AppColors.green
        : (ratio >= 1.0 ? AppColors.negative : (ratio >= 0.75 ? AppColors.warning : AppColors.green));

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: estPlein ? AppColors.negative.withOpacity(0.4) : AppColors.border,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: jaugeColor.withOpacity(0.12),
                    child: Icon(Icons.groups_rounded, size: 20, color: jaugeColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Capacité de l\'équipe',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Forfait $planNom',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: jaugeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      maxUtilisateurs != null ? '$totalOccupes / $maxUtilisateurs places' : '$totalOccupes (Illimité)',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: jaugeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: maxUtilisateurs == null ? 0.2 : ratio,
                  minHeight: 6,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(jaugeColor),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$actifs actif${actifs > 1 ? 's' : ''}'
                    '${enAttente > 0 ? ' · $enAttente invité${enAttente > 1 ? 's' : ''}' : ''}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                  if (maxUtilisateurs != null)
                    Text(
                      estPlein
                          ? 'Limite atteinte'
                          : '${maxUtilisateurs! - totalOccupes} place${(maxUtilisateurs! - totalOccupes) > 1 ? 's' : ''} libre${(maxUtilisateurs! - totalOccupes) > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: estPlein ? AppColors.negative : AppColors.muted,
                      ),
                    ),
                ],
              ),

              // Encart d'alerte aux tons dorés lorsque la limite est atteinte
              if (estPlein) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDF9540).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDF9540).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.workspace_premium_rounded, color: Color(0xFFB06F1E), size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Limite d\'utilisateurs atteinte. Passez au forfait supérieur pour ajouter de nouveaux collaborateurs.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8A5412)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFB06F1E),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: onUpgrade,
                        child: const Text('Offres', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Onglet 1 : Membres avec recherche, filtre et fiche d'actions
class _MembresTab extends StatelessWidget {
  const _MembresTab({
    required this.membresAsync,
    required this.ctx,
    required this.peutGerer,
    required this.searchController,
    required this.filtreStatut,
    required this.onFiltreChanged,
    required this.onRefresh,
    required this.onRetry,
  });

  final AsyncValue<List<Membre>> membresAsync;
  final dynamic ctx;
  final bool peutGerer;
  final TextEditingController searchController;
  final String filtreStatut;
  final ValueChanged<String> onFiltreChanged;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: AsyncValueView<List<Membre>>(
        value: membresAsync,
        onRetry: onRetry,
        emptyMessage: l10n.usersEmpty,
        data: (membres) {
          final query = searchController.text.trim().toLowerCase();
          final filtres = membres.where((m) {
            // Filtre statut
            if (filtreStatut == 'ACTIF' && !m.estActif) return false;
            if (filtreStatut == 'SUSPENDU' && m.estActif) return false;

            // Recherche texte
            if (query.isNotEmpty) {
              final nom = (m.nomComplet ?? '').toLowerCase();
              final role = l10n.role(m.roleCode).toLowerCase();
              if (!nom.contains(query) && !role.contains(query)) return false;
            }
            return true;
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, 96),
            children: [
              // Recherche et filtres rapides
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Rechercher un membre...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    searchController.clear();
                                    onFiltreChanged(filtreStatut);
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        onChanged: (_) => onFiltreChanged(filtreStatut),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _FiltreChip(
                    label: 'Tous (${membres.length})',
                    actif: filtreStatut == 'TOUS',
                    onTap: () => onFiltreChanged('TOUS'),
                  ),
                  const SizedBox(width: 8),
                  _FiltreChip(
                    label: 'Actifs (${membres.where((m) => m.estActif).length})',
                    actif: filtreStatut == 'ACTIF',
                    onTap: () => onFiltreChanged('ACTIF'),
                  ),
                  const SizedBox(width: 8),
                  _FiltreChip(
                    label: 'Suspendus (${membres.where((m) => !m.estActif).length})',
                    actif: filtreStatut == 'SUSPENDU',
                    onTap: () => onFiltreChanged('SUSPENDU'),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (filtres.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      'Aucun membre ne correspond aux critères',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                    ),
                  ),
                )
              else
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      for (final (index, m) in filtres.indexed) ...[
                        if (index > 0) const Divider(height: 1),
                        _MembreTileItem(
                          membre: m,
                          estMoi: m.userId == ctx.userId,
                          accesTous: ctx.roles[m.roleCode]?.accesTousPerimetres ?? false,
                          onTap: peutGerer ? () => showAffectationsSheet(context, m) : null,
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FiltreChip extends StatelessWidget {
  const _FiltreChip({required this.label, required this.actif, required this.onTap});
  final String label;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: actif ? AppColors.green : AppColors.border.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: actif ? FontWeight.w800 : FontWeight.w600,
            color: actif ? Colors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _MembreTileItem extends StatelessWidget {
  const _MembreTileItem({
    required this.membre,
    required this.estMoi,
    required this.accesTous,
    this.onTap,
  });

  final Membre membre;
  final bool estMoi;
  final bool accesTous;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nom = membre.nomComplet ?? '—';
    final perimetres = accesTous
        ? l10n.usersAllPerimetres
        : membre.perimetreIds.isEmpty
            ? l10n.usersNoPerimetre
            : '${l10n.usersAssignments} : ${membre.perimetreIds.length}';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: membre.estActif ? AppColors.greenSoft : AppColors.warningSoft,
        child: Text(
          nom.characters.first.toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: membre.estActif ? AppColors.green : AppColors.warning,
          ),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              estMoi ? '$nom (${l10n.usersYou})' : nom,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: membre.estActif ? AppColors.greenSoft : AppColors.warningSoft,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              membre.estActif ? 'Actif' : 'Suspendu',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: membre.estActif ? AppColors.green : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        '${l10n.role(membre.roleCode)} · $perimetres',
        style: const TextStyle(fontSize: 12, color: AppColors.muted),
      ),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right, color: AppColors.muted),
      onTap: onTap,
    );
  }
}

/// Onglet 2 : Liste des invitations avec actions directes
class _InvitationsTab extends ConsumerWidget {
  const _InvitationsTab({
    required this.invitationsAsync,
    required this.filtreInvitation,
    required this.onFiltreChanged,
    required this.onRefresh,
    required this.onRetry,
  });

  final AsyncValue<List<Invitation>> invitationsAsync;
  final String filtreInvitation;
  final ValueChanged<String> onFiltreChanged;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: AsyncValueView<List<Invitation>>(
        value: invitationsAsync,
        onRetry: onRetry,
        emptyMessage: 'Aucune invitation pour le moment',
        data: (invitations) {
          final filtres = invitations.where((inv) {
            final statut = inv.statutEffectif(now);
            if (filtreInvitation == 'PENDING' && statut != InvitationStatut.pending) return false;
            if (filtreInvitation == 'ARCHIVEES' && statut == InvitationStatut.pending) return false;
            return true;
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 96),
            children: [
              Row(
                children: [
                  _FiltreChip(
                    label: 'Toutes (${invitations.length})',
                    actif: filtreInvitation == 'TOUTES',
                    onTap: () => onFiltreChanged('TOUTES'),
                  ),
                  const SizedBox(width: 8),
                  _FiltreChip(
                    label: 'En attente (${invitations.where((i) => i.statutEffectif(now) == InvitationStatut.pending).length})',
                    actif: filtreInvitation == 'PENDING',
                    onTap: () => onFiltreChanged('PENDING'),
                  ),
                  const SizedBox(width: 8),
                  _FiltreChip(
                    label: 'Terminées / Expirées (${invitations.where((i) => i.statutEffectif(now) != InvitationStatut.pending).length})',
                    actif: filtreInvitation == 'ARCHIVEES',
                    onTap: () => onFiltreChanged('ARCHIVEES'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (filtres.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      'Aucune invitation dans cette section',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                    ),
                  ),
                )
              else
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      for (final (index, inv) in filtres.indexed) ...[
                        if (index > 0) const Divider(height: 1),
                        _InvitationItemTile(inv: inv, now: now),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _InvitationItemTile extends ConsumerWidget {
  const _InvitationItemTile({required this.inv, required this.now});
  final Invitation inv;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final statut = inv.statutEffectif(now);
    final estEnAttente = statut == InvitationStatut.pending;

    Color badgeBg;
    Color badgeText;
    String badgeLabel;

    switch (statut) {
      case InvitationStatut.pending:
        badgeBg = AppColors.warningSoft;
        badgeText = AppColors.warning;
        badgeLabel = 'En attente';
        break;
      case InvitationStatut.accepted:
        badgeBg = AppColors.greenSoft;
        badgeText = AppColors.green;
        badgeLabel = 'Acceptée';
        break;
      case InvitationStatut.expired:
        badgeBg = AppColors.negativeSoft;
        badgeText = AppColors.negative;
        badgeLabel = 'Expirée';
        break;
      case InvitationStatut.cancelled:
      case InvitationStatut.invalid:
        badgeBg = AppColors.border;
        badgeText = AppColors.muted;
        badgeLabel = 'Annulée';
        break;
    }

    Future<void> copierEtRenvoyer() async {
      final ctx = ref.read(contexteActifProvider);
      if (ctx == null) return;
      try {
        InvitationCreee creee;
        try {
          creee = await ref.read(renvoyerInvitationProvider).call(ctx, inv);
        } catch (_) {
          final tousPerimetres = ref.read(perimetresProvider).value ?? const <Perimetre>[];
          final perimetresDisponibles = tousPerimetres.isNotEmpty ? tousPerimetres : ctx.perimetres;
          final role = ctx.roles[inv.roleCode];
          final perimetresCompatibles = (role?.accesTousPerimetres ?? true)
              ? const <Perimetre>[]
              : (role?.activite != null
                  ? perimetresDisponibles.where((p) => p.activite == role!.activite).toList()
                  : perimetresDisponibles);

          creee = await ref.read(creerInvitationProvider).call(
                ctx,
                email: inv.email,
                roleCode: inv.roleCode,
                perimetres: perimetresCompatibles,
              );
        }
        final lien = ref.read(appConfigProvider).invitationLink(creee.token);
        await Clipboard.setData(ClipboardData(text: lien));
        if (context.mounted) showMessageSnackBar(context, l10n.inviteCopied);
        ref.invalidate(invitationsProvider);
      } catch (e) {
        if (context.mounted) showFailureSnackBar(context, e);
      }
    }

    Future<void> confirmerEtAnnuler() async {
      final ctx = ref.read(contexteActifProvider);
      if (ctx == null) return;

      final confirmer = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Annuler l\'invitation ?'),
          content: Text(
            'Voulez-vous annuler l\'invitation pour ${inv.email} ?\nLa place réservée sera immédiatement libérée.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Retour'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Annuler l\'invitation'),
            ),
          ],
        ),
      );

      if (confirmer != true || !context.mounted) return;
      try {
        await ref.read(annulerInvitationProvider).call(ctx, inv);
        ref.invalidate(invitationsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invitation pour ${inv.email} annulée')),
          );
        }
      } catch (e) {
        if (context.mounted) showFailureSnackBar(context, e);
      }
    }

    Future<void> confirmerEtSupprimer() async {
      final ctx = ref.read(contexteActifProvider);
      if (ctx == null) return;

      final confirmer = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Supprimer de l\'historique ?'),
          content: Text('Supprimer définitivement l\'invitation de ${inv.email} ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Retour'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Supprimer'),
            ),
          ],
        ),
      );

      if (confirmer != true || !context.mounted) return;
      try {
        await ref.read(supprimerInvitationProvider).call(ctx, inv);
        ref.invalidate(invitationsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invitation pour ${inv.email} supprimée')),
          );
        }
      } catch (e) {
        if (context.mounted) showFailureSnackBar(context, e);
      }
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: AppColors.greenSoft,
        child: const Icon(Icons.mail_outline_rounded, color: AppColors.green, size: 20),
      ),
      title: Text(
        inv.email,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      subtitle: Row(
        children: [
          Text(l10n.role(inv.roleCode), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
            child: Text(
              badgeLabel,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: badgeText),
            ),
          ),
        ],
      ),
      trailing: estEnAttente
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Copier / Renouveler le lien',
                  icon: const Icon(Icons.copy_rounded, color: AppColors.green, size: 20),
                  onPressed: copierEtRenvoyer,
                ),
                IconButton(
                  tooltip: 'Annuler',
                  icon: const Icon(Icons.cancel_outlined, color: AppColors.negative, size: 20),
                  onPressed: confirmerEtAnnuler,
                ),
              ],
            )
          : (statut == InvitationStatut.expired || statut == InvitationStatut.cancelled)
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Renvoyer',
                      icon: const Icon(Icons.refresh_rounded, color: AppColors.green, size: 20),
                      onPressed: copierEtRenvoyer,
                    ),
                    IconButton(
                      tooltip: 'Supprimer',
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.negative, size: 20),
                      onPressed: confirmerEtSupprimer,
                    ),
                  ],
                )
              : null,
    );
  }
}

/// Onglet 3 : Vue pédagogique de la matrice des rôles et permissions
class _RolesTab extends StatelessWidget {
  const _RolesTab({required this.ctx});
  final dynamic ctx;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final roles = ctx.roles.values.toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 96),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            'Rôles configurés pour votre entreprise',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        for (final r in roles)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.greenSoft,
                child: const Icon(Icons.security_rounded, color: AppColors.green, size: 20),
              ),
              title: Text(
                l10n.role(r.code),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              subtitle: Text(
                r.accesTousPerimetres
                    ? 'Accès global (toutes les boutiques/sites)'
                    : 'Périmètre restreint (boutiques assignées)',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      const SizedBox(height: 6),
                      Text(
                        'Activité liée : ${r.activite != null ? l10n.activite(r.activite!) : "Toutes"}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Code système : ${r.code}',
                        style: const TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
