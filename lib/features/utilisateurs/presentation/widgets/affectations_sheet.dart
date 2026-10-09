import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/permissions/access_decision.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../perimetres/domain/entities/perimetre.dart';
import '../../../perimetres/presentation/providers/perimetres_providers.dart';
import '../../domain/entities/membre.dart';
import '../providers/membres_providers.dart';

Future<void> showAffectationsSheet(BuildContext context, Membre membre) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _AffectationsSheet(membre: membre),
    );

/// Fiche complète de gestion d'un membre d'entreprise :
/// - Modification du rôle
/// - Activation / Suspension
/// - Affectation aux boutiques / périmètres
/// - Retrait / Suppression de l'entreprise
class _AffectationsSheet extends ConsumerStatefulWidget {
  const _AffectationsSheet({required this.membre});
  final Membre membre;

  @override
  ConsumerState<_AffectationsSheet> createState() => _AffectationsSheetState();
}

class _AffectationsSheetState extends ConsumerState<_AffectationsSheet> {
  late Set<String> _affectes = {...widget.membre.perimetreIds};
  late String _roleActuel = widget.membre.roleCode;
  late MembreStatut _statutActuel = widget.membre.statut;
  String? _enCours;
  bool _actionEnCours = false;

  Future<void> _basculerPerimetre(Perimetre p, bool affecter) async {
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    setState(() => _enCours = p.id);
    try {
      if (affecter) {
        await ref.read(affecterPerimetreProvider).call(ctx, widget.membre, p);
        _affectes = {..._affectes, p.id};
      } else {
        await ref.read(retirerPerimetreProvider).call(ctx, widget.membre, p);
        _affectes = {..._affectes}..remove(p.id);
      }
      ref.invalidate(membresProvider);
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _enCours = null);
    }
  }

  Future<void> _changerRole(String nouveauRole) async {
    if (nouveauRole == _roleActuel) return;
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;

    setState(() => _actionEnCours = true);
    try {
      await ref.read(modifierRoleMembreProvider).call(ctx, widget.membre, nouveauRole);
      setState(() => _roleActuel = nouveauRole);
      ref.invalidate(membresProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rôle mis à jour avec succès')),
        );
      }
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _actionEnCours = false);
    }
  }

  Future<void> _basculerStatut(bool actif) async {
    final nouveauStatut = actif ? MembreStatut.actif : MembreStatut.suspendu;
    if (nouveauStatut == _statutActuel) return;
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;

    setState(() => _actionEnCours = true);
    try {
      await ref.read(modifierStatutMembreProvider).call(ctx, widget.membre, nouveauStatut);
      setState(() => _statutActuel = nouveauStatut);
      ref.invalidate(membresProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(actif ? 'Compte utilisateur activé' : 'Compte utilisateur suspendu'),
          ),
        );
      }
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _actionEnCours = false);
    }
  }

  Future<void> _confirmerSuppression() async {
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;

    final confirmer = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Supprimer cet utilisateur ?'),
        content: Text(
          'Voulez-vous vraiment retirer ${widget.membre.nomComplet ?? "cet utilisateur"} de l\'entreprise ? Ses accès seront immédiatement révoqués.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmer != true || !mounted) return;

    setState(() => _actionEnCours = true);
    try {
      await ref.read(supprimerMembreProvider).call(ctx, widget.membre);
      ref.invalidate(membresProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilisateur retiré de l\'entreprise')),
        );
      }
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _actionEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ctx = ref.watch(contexteActifProvider);
    final perimetres = ref.watch(perimetresProvider).value ?? const <Perimetre>[];
    final affecter = ref.watch(affecterPerimetreProvider);
    if (ctx == null) return const SizedBox.shrink();

    final estMoi = widget.membre.userId == ctx.userId;
    final nom = widget.membre.nomComplet ?? 'Utilisateur';
    final estActif = _statutActuel == MembreStatut.actif;

    // Rôles disponibles dans l'entreprise
    final rolesDisponibles = ctx.roles.keys.toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. En-tête avec avatar, nom, statut
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.greenSoft,
                  child: Text(
                    nom.characters.first.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.green),
                  ),
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
                              estMoi ? '$nom (Vous)' : nom,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: estActif ? AppColors.greenSoft : AppColors.warningSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              estActif ? 'Actif' : 'Suspendu',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: estActif ? AppColors.green : AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.md),

            // 2. Modification du rôle
            Text(
              'Rôle de l\'utilisateur',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              key: const Key('select-membre-role'),
              value: rolesDisponibles.contains(_roleActuel) ? _roleActuel : null,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.badge_outlined),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                for (final r in rolesDisponibles)
                  DropdownMenuItem(
                    value: r,
                    child: Text(l10n.role(r)),
                  ),
              ],
              onChanged: (_actionEnCours || estMoi)
                  ? null
                  : (nouveau) {
                      if (nouveau != null) _changerRole(nouveau);
                    },
            ),
            if (estMoi)
              const Padding(
                padding: EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  'Vous ne pouvez pas modifier votre propre rôle administrateur.',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
            const SizedBox(height: AppSpacing.md),

            // 3. Activation / Suspension
            SwitchListTile(
              key: const Key('switch-membre-statut'),
              contentPadding: EdgeInsets.zero,
              value: estActif,
              onChanged: (_actionEnCours || estMoi) ? null : (val) => _basculerStatut(val),
              title: const Text('Accès au compte', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                estActif
                    ? 'Le compte est actif et peut se connecter.'
                    : 'Le compte est suspendu. Tous ses accès sont bloqués.',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.md),

            // 4. Affectation aux boutiques / périmètres
            Text(
              l10n.usersAssignments,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (perimetres.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Aucune boutique créée.', style: TextStyle(color: AppColors.muted)),
              )
            else
              for (final p in perimetres)
                Builder(builder: (context) {
                  final decision = affecter.verifier(ctx, widget.membre, p);
                  final coche = _affectes.contains(p.id);
                  final modifiable = !_actionEnCours && _enCours == null && (coche || decision.isAllowed);
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: coche,
                    onChanged: modifiable ? (v) => _basculerPerimetre(p, v ?? false) : null,
                    title: Text(p.nom, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      decision is AccessDenied && !coche
                          ? l10n.decision(decision)
                          : l10n.activite(p.activite),
                      style: const TextStyle(fontSize: 12),
                    ),
                    secondary: _enCours == p.id
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : null,
                  );
                }),

            // 5. Supprimer / Retirer de l'entreprise
            if (!estMoi) ...[
              const SizedBox(height: AppSpacing.lg),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                key: const Key('btn-supprimer-membre'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.negative,
                  side: const BorderSide(color: AppColors.negative),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _actionEnCours ? null : _confirmerSuppression,
                icon: const Icon(Icons.delete_outline, size: 20),
                label: const Text('Supprimer de l\'entreprise', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
