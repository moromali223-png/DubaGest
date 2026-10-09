import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/permissions/access_decision.dart';
import '../../../../core/permissions/permission_codes.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../../entreprise/domain/entities/contexte_session.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../modules/domain/entities/app_module.dart';
import '../../../utilisateurs/presentation/providers/membres_providers.dart';
import '../../domain/entities/perimetre.dart';
import '../../domain/services/boutiques_naming_service.dart';
import '../providers/perimetres_providers.dart';
import '../widgets/affectations_boutique_sheet.dart';
import '../widgets/perimetre_form_sheet.dart';

/// Page principale de Gestion des Boutiques / Périmètres opérationnels.
/// Conforme au principe DUBAGEST :
/// « Une boutique = un point d'activité réel (Boutique A, Boutique B...).
///   Toutes les boutiques = une vue consolidée, jamais une vraie boutique. »
class PerimetresPage extends ConsumerWidget {
  const PerimetresPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ctx = ref.watch(contexteActifProvider);
    final perimetresAsync = ref.watch(perimetresProvider);
    final membres = ref.watch(membresProvider).value ?? const [];
    final peutGerer = ctx?.permissionEngine.has(PermissionCodes.perimetresManage) ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mes boutiques & sites'),
        actions: const [SyncStatusButton()],
      ),
      floatingActionButton: !peutGerer
          ? null
          : FloatingActionButton.extended(
              key: const Key('perimetre-add'),
              backgroundColor: const Color(0xFF01226C),
              foregroundColor: Colors.white,
              onPressed: () => _creer(context, ref, ctx!),
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Ajouter une boutique'),
            ),
      body: ResponsiveBody(
        child: AsyncValueView(
          value: perimetresAsync,
          isEmpty: (list) => list.isEmpty,
          emptyMessage: 'Aucune boutique configurée pour votre entreprise.',
          onRetry: () => ref.invalidate(perimetresProvider),
          data: (list) {
            final activitePrincipale = ctx?.activites.where((a) => a.estActive).firstOrNull?.activite ?? ActiviteCode.commerce;
            final limites = ctx?.limites();
            final maxAutorise = limites?.maxPerimetres(activitePrincipale);
            final nbActifs = list.where((p) => p.estActif).length;
            final quotaAtteint = maxAutorise != null && nbActifs >= maxAutorise;

            return ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
              children: [
                // 1. En-tête : Résumé Quotas & Plan d'abonnement
                _ResumePlanCard(
                  totalCrees: list.length,
                  totalActifs: nbActifs,
                  maxAutorise: maxAutorise,
                  planNom: ctx?.plan?.nom ?? 'Plan Dubagest',
                  quotaAtteint: quotaAtteint,
                  onUpgrade: () => context.push(ModuleRoutes.path(ModuleCodes.adminAbonnement)),
                ),
                const SizedBox(height: AppSpacing.md),

                // 2. Bannière explicative distinction Boutique vs Vue consolidée
                _BanniereConceptuelle(totalBoutiques: list.length),
                const SizedBox(height: AppSpacing.md),

                // 3. Titre de section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Boutiques enregistrées (${list.length})',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink),
                    ),
                    if (peutGerer && !quotaAtteint)
                      TextButton.icon(
                        onPressed: () => _creer(context, ref, ctx!),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Nouvelle'),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // 4. Liste des cartes de boutiques
                for (var i = 0; i < list.length; i++) ...[
                  _CarteBoutiqueCard(
                    perimetre: list[i],
                    index: i,
                    membresCount: membres.where((m) => m.perimetreIds.contains(list[i].id)).length,
                    peutGerer: peutGerer,
                    onModifier: () => _modifier(context, ref, ctx!, list[i]),
                    onAffecterMembres: () => showAffectationsBoutiqueSheet(context, list[i]),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  PerimetreType _typeParDefaut(ContexteSession ctx, ActiviteCode a) => PerimetreType.parse(
        ctx.activites.firstWhere((x) => x.activite == a).typePerimetreDefaut,
      );

  Future<void> _creer(BuildContext context, WidgetRef ref, ContexteSession ctx) async {
    final creer = ref.read(creerPerimetreProvider);
    try {
      final decisions = await creer.decisionsParActivite(ctx);
      final autorisees = [
        for (final e in decisions.entries)
          if (e.value.isAllowed) e.key,
      ];
      if (!context.mounted) return;
      if (autorisees.isEmpty) {
        final refus = decisions.values.whereType<AccessDenied>().firstOrNull ??
            const AccessDenied(RuleCodes.activityInactive);
        showMessageSnackBar(context, context.l10n.decision(refus));
        return;
      }

      final existants = ref.read(perimetresProvider).value ?? [];
      final result = await showPerimetreFormSheet(
        context,
        activites: autorisees,
        typeParDefaut: (a) => _typeParDefaut(ctx, a),
        existants: existants,
      );
      if (result == null) return;
      await creer(ctx, activite: result.activite, type: result.type, nom: result.nom, code: result.code);
    } catch (e) {
      if (context.mounted) showFailureSnackBar(context, e);
    }
  }

  Future<void> _modifier(BuildContext context, WidgetRef ref, ContexteSession ctx, Perimetre p) async {
    final l10n = context.l10n;
    final existants = ref.read(perimetresProvider).value ?? [];
    final result = await showPerimetreFormSheet(
      context,
      activites: [p.activite],
      typeParDefaut: (a) => _typeParDefaut(ctx, a),
      existants: existants,
      initial: p,
    );
    if (result == null || !context.mounted) return;
    try {
      if (result.supprimer) {
        final confirme = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.perimetreDeleteTitle),
            content: Text(l10n.perimetreDeleteMessage(p.nom)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.commonDelete),
              ),
            ],
          ),
        );
        if (confirme ?? false) await ref.read(supprimerPerimetreProvider).call(ctx, p);
      } else {
        await ref.read(modifierPerimetreProvider).call(
              ctx,
              p,
              nom: result.nom,
              code: result.code,
              type: result.type,
              estActif: result.estActif,
            );
      }
    } catch (e) {
      if (context.mounted) showFailureSnackBar(context, e);
    }
  }
}

/// Carte récapitulative du Quota et de l'Abonnement de l'entreprise.
class _ResumePlanCard extends StatelessWidget {
  const _ResumePlanCard({
    required this.totalCrees,
    required this.totalActifs,
    required this.maxAutorise,
    required this.planNom,
    required this.quotaAtteint,
    required this.onUpgrade,
  });

  final int totalCrees;
  final int totalActifs;
  final int? maxAutorise;
  final String planNom;
  final bool quotaAtteint;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final ratio = maxAutorise == null ? 0.5 : (totalActifs / maxAutorise!).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: quotaAtteint ? AppColors.gold.withValues(alpha: 0.5) : AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF01226C).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.domain_rounded, color: Color(0xFF01226C), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Capacité d\'accueil',
                        style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        maxAutorise == null
                            ? '$totalActifs boutique${totalActifs > 1 ? 's' : ''} (Illimité)'
                            : '$totalActifs sur $maxAutorise boutique${maxAutorise! > 1 ? 's' : ''} autorisée${maxAutorise! > 1 ? 's' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDF9540).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  planNom,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB06F1E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Barre de progression
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: AppColors.background,
              valueColor: AlwaysStoppedAnimation<Color>(
                quotaAtteint ? AppColors.gold : const Color(0xFF01226C),
              ),
            ),
          ),

          // Alerte si quota atteint
          if (quotaAtteint) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: const Color(0xFFDF9540).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDF9540).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium_rounded, color: Color(0xFFB06F1E), size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Limite de votre abonnement atteinte. Passez à l\'abonnement supérieur pour ajouter une autre boutique.',
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
    );
  }
}

/// Bannière éducative clarifiant la différence entre Boutique réelle et Vue consolidée.
class _BanniereConceptuelle extends StatelessWidget {
  const _BanniereConceptuelle({required this.totalBoutiques});
  final int totalBoutiques;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xFF01226C).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF01226C).withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF01226C)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              totalBoutiques <= 1
                  ? 'Vos opérations (ventes, caisse, stock) sont automatiquement enregistrées sur votre boutique active.'
                  : 'Chaque vente et mouvement de stock est rattaché à sa boutique réelle. L\'option « Toutes les boutiques » vous offre une vue consolidée globale.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF01226C), fontWeight: FontWeight.w500, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte moderne d'une Boutique physique avec son code, statut et membres affectés.
class _CarteBoutiqueCard extends StatelessWidget {
  const _CarteBoutiqueCard({
    required this.perimetre,
    required this.index,
    required this.membresCount,
    required this.peutGerer,
    required this.onModifier,
    required this.onAffecterMembres,
  });

  final Perimetre perimetre;
  final int index;
  final int membresCount;
  final bool peutGerer;
  final VoidCallback onModifier;
  final VoidCallback onAffecterMembres;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = perimetre;
    final nomParDefaut = BoutiquesNamingService.nomParDefaut(index, type: p.type);
    final estRenommee = p.nom != nomParDefaut;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.estActif ? AppColors.border : AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: peutGerer ? onModifier : null,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar Boutique
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: p.estActif
                            ? const Color(0xFF01226C).withValues(alpha: 0.08)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        BoutiquesNamingService.lettreBoutique(index),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: p.estActif ? const Color(0xFF01226C) : AppColors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Nom & Désignation
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  p.nom,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: p.estActif ? AppColors.ink : AppColors.muted,
                                  ),
                                ),
                              ),
                              if (estRenommee) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    nomParDefaut,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.muted),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              l10n.activite(p.activite),
                              if (p.code != null) 'Code: ${p.code}',
                            ].join(' · '),
                            style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),

                    // Statut Pill + Menu d'actions
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: p.estActif ? AppColors.positiveSoft : AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            p.estActif ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: p.estActif ? AppColors.positive : AppColors.muted,
                            ),
                          ),
                        ),
                        if (peutGerer)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.muted),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (val) {
                              if (val == 'modifier') onModifier();
                              if (val == 'membres') onAffecterMembres();
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'modifier',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('Modifier la boutique'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'membres',
                                child: Row(
                                  children: [
                                    Icon(Icons.people_outline_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text('Membres affectés'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.sm),

                // Footer de la carte : Membres affectés
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.badge_outlined, size: 16, color: AppColors.muted),
                        const SizedBox(width: 6),
                        Text(
                          membresCount > 0
                              ? '$membresCount membre${membresCount > 1 ? 's' : ''} affecté${membresCount > 1 ? 's' : ''}'
                              : 'Aucun membre affecté',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
                        ),
                      ],
                    ),
                    if (peutGerer)
                      InkWell(
                        onTap: onAffecterMembres,
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Text(
                            'Gérer les accès ›',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF01226C),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
