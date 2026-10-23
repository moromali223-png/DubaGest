import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../audit/domain/entities/entree_audit.dart';
import '../../../audit/presentation/pages/audit_page.dart' show libelleAction, libelleChamp, valeur;
import '../../../audit/presentation/providers/audit_providers.dart';
import '../../domain/entities/commerce.dart';
import '../commerce_providers.dart';
import 'commerce_widgets.dart';
import 'mouvement_tuile.dart';

/// Vue unifiée de l'historique d'une entité Commerce (Achat, Vente, Produit).
/// Fusionne les logs techniques (Audit) et les mouvements de stock physiques.
class HistoriqueEntiteView extends ConsumerWidget {
  const HistoriqueEntiteView({
    super.key,
    required this.entiteType,
    required this.entiteId,
    this.inclureMouvements = true,
  });

  final String entiteType;
  final String entiteId;
  final bool inclureMouvements;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final auditAsync = ref.watch(historiqueEntiteProvider((entiteType, entiteId)));
    final etatCommerce = ref.watch(etatCommerceProvider).value;

    return AsyncValueView<List<EntreeAudit>>(
      value: auditAsync,
      data: (entrees) {
        // 1. Récupérer les mouvements liés si nécessaire
        final mouvements = inclureMouvements && etatCommerce != null
            ? etatCommerce.mouvements.where((m) => m.origineId == entiteId).toList()
            : <MouvementStock>[];

        // 2. Fusionner et trier par date décroissante
        final timeline = <_ElementTimeline>[
          for (final e in entrees) _AuditTimeline(e),
          for (final m in mouvements) _MouvementTimeline(m),
        ]..sort((a, b) => b.date.compareTo(a.date));

        if (timeline.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history_outlined, size: 48, color: AppColors.muted),
                  const SizedBox(height: 12),
                  Text(l10n.auditEmpty, style: const TextStyle(color: AppColors.muted)),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: timeline.length,
          itemBuilder: (context, index) {
            final item = timeline[index];
            final estDernier = index == timeline.length - 1;
            
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Colonne de gauche : ligne de temps
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(top: 20),
                      decoration: BoxDecoration(
                        color: item.couleur,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                    if (!estDernier)
                      Container(
                        width: 2,
                        height: 60, // Ajustable selon le contenu
                        color: AppColors.border,
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Contenu
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: item.build(context, ref),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

abstract class _ElementTimeline {
  DateTime get date;
  Color get couleur;
  Widget build(BuildContext context, WidgetRef ref);
}

class _AuditTimeline implements _ElementTimeline {
  _AuditTimeline(this.entree);
  final EntreeAudit entree;

  @override
  DateTime get date => entree.date;

  @override
  Color get couleur => switch (entree.action) {
        AuditAction.creation => AppColors.positive,
        AuditAction.modification => AppColors.green,
        _ => AppColors.warning,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    
    final modifs = <String>[];
    if (entree.action == AuditAction.modification) {
      for (final champ in entree.champs) {
        final libelle = libelleChamp(l10n, champ);
        if (libelle != null) {
          modifs.add('$libelle : ${valeur(l10n, champ, entree.avant[champ])} → ${valeur(l10n, champ, entree.apres[champ])}');
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${libelleAction(l10n, entree.action)} · ${l10n.dateTime(entree.date)}',
          style: theme.textTheme.labelMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 2),
        Text(
          entree.auteurNom ?? l10n.auditSystem,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        for (final m in modifs)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(m, style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }
}

class _MouvementTimeline implements _ElementTimeline {
  _MouvementTimeline(this.mouvement);
  final MouvementStock mouvement;

  @override
  DateTime get date => mouvement.date;

  @override
  Color get couleur => visuelMouvement(mouvement).$1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Impact stock · ${l10n.dateTime(mouvement.date)}',
          style: theme.textTheme.labelMedium?.copyWith(color: AppColors.muted),
        ),
        MouvementTuile(mouvement: mouvement, avecProduit: false),
      ],
    );
  }
}
