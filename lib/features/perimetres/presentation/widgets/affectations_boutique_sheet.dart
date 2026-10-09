import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/permissions/access_decision.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../utilisateurs/domain/entities/membre.dart';
import '../../../utilisateurs/presentation/providers/membres_providers.dart';
import '../../domain/entities/perimetre.dart';

/// Modal permettant d'affecter les utilisateurs (vendeurs, gestionnaires...) à une boutique donnée.
Future<void> showAffectationsBoutiqueSheet(BuildContext context, Perimetre perimetre) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _AffectationsBoutiqueSheet(perimetre: perimetre),
    );

class _AffectationsBoutiqueSheet extends ConsumerStatefulWidget {
  const _AffectationsBoutiqueSheet({required this.perimetre});
  final Perimetre perimetre;

  @override
  ConsumerState<_AffectationsBoutiqueSheet> createState() => _AffectationsBoutiqueSheetState();
}

class _AffectationsBoutiqueSheetState extends ConsumerState<_AffectationsBoutiqueSheet> {
  String? _enCoursMembreId;

  Future<void> _basculer(Membre membre, bool affecter) async {
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    setState(() => _enCoursMembreId = membre.id);
    try {
      if (affecter) {
        await ref.read(affecterPerimetreProvider).call(ctx, membre, widget.perimetre);
      } else {
        await ref.read(retirerPerimetreProvider).call(ctx, membre, widget.perimetre);
      }
      ref.invalidate(membresProvider);
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _enCoursMembreId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ctx = ref.watch(contexteActifProvider);
    final membresAsync = ref.watch(membresProvider);
    final affecter = ref.watch(affecterPerimetreProvider);
    if (ctx == null) return const SizedBox.shrink();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF01226C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.people_alt_rounded, color: Color(0xFF01226C), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Membres affectés · ${widget.perimetre.nom}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const Text(
                          'Cochez les vendeurs ou gestionnaires autorisés sur cette boutique',
                          style: TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(),
            membresAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text('Erreur : $err', style: const TextStyle(color: AppColors.negative)),
              ),
              data: (membres) {
                if (membres.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(
                      child: Text('Aucun membre dans l\'entreprise', style: TextStyle(color: AppColors.muted)),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: membres.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final m = membres[index];
                    final decision = affecter.verifier(ctx, m, widget.perimetre);
                    final estAffecte = m.perimetreIds.contains(widget.perimetre.id);
                    final modifiable = _enCoursMembreId == null && (estAffecte || decision.isAllowed);
                    final roleNom = l10n.role(m.roleCode);

                    final nomMembre = m.nomComplet?.isNotEmpty == true ? m.nomComplet! : 'Utilisateur #${m.userId.substring(0, m.userId.length > 6 ? 6 : m.userId.length)}';
                    final premiereLettre = nomMembre.isNotEmpty ? nomMembre.characters.first.toUpperCase() : 'U';

                    return CheckboxListTile(
                      value: estAffecte,
                      onChanged: modifiable ? (v) => _basculer(m, v ?? false) : null,
                      title: Text(
                        nomMembre,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      subtitle: Text(
                        decision is AccessDenied && !estAffecte
                            ? l10n.decision(decision)
                            : '$roleNom',
                        style: TextStyle(
                          fontSize: 12,
                          color: decision is AccessDenied && !estAffecte ? AppColors.negative : AppColors.muted,
                        ),
                      ),
                      secondary: _enCoursMembreId == m.id
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : CircleAvatar(
                              backgroundColor: AppColors.background,
                              child: Text(
                                premiereLettre,
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF01226C)),
                              ),
                            ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
