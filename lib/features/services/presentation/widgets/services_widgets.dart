import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../commerce/presentation/widgets/commerce_widgets.dart' show montant;
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../domain/entities/metier_template.dart';
import '../../domain/entities/prestation.dart';
import '../services_providers.dart';

/// Badge visuel du statut du travail (À faire, En cours, Terminée, Livrée, Annulée).
class StatutPrestationBadge extends StatelessWidget {
  const StatutPrestationBadge({super.key, required this.statut});
  final StatutPrestation statut;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (Color couleur, IconData icone) = switch (statut) {
      StatutPrestation.aFaire => (const Color(0xFF64748B), Icons.assignment_outlined),
      StatutPrestation.planifiee => (const Color(0xFF0284C7), Icons.event_outlined),
      StatutPrestation.enCours => (const Color(0xFFDF9540), Icons.play_circle_outline_rounded),
      StatutPrestation.terminee => (AppColors.green, Icons.check_circle_outline_rounded),
      StatutPrestation.livree => (const Color(0xFF7C3AED), Icons.task_alt_rounded),
      StatutPrestation.annulee => (AppColors.negative, Icons.cancel_outlined),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: couleur.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: couleur),
          const SizedBox(width: 4),
          Text(
            l10n.statutPrestation(statut),
            style: TextStyle(color: couleur, fontWeight: FontWeight.w800, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

/// Badge visuel du statut financier (Non payé, Acompte versé, Payé).
class StatutFinancierBadge extends ConsumerWidget {
  const StatutFinancierBadge({super.key, required this.prestation});
  final Prestation prestation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (prestation.total == 0) {
      return const SizedBox.shrink();
    }

    if (prestation.estPayeIntegralement) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          '✓ Payé',
          style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800, fontSize: 11.5),
        ),
      );
    }

    if (prestation.aAcomptePartiel) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFDF9540).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Acompte (${montant(context, ref, prestation.montantRegle)})',
          style: const TextStyle(color: Color(0xFFDF9540), fontWeight: FontWeight.w800, fontSize: 11),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.negative.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Reste ${montant(context, ref, prestation.soldeRestant)}',
        style: const TextStyle(color: AppColors.negative, fontWeight: FontWeight.w800, fontSize: 11),
      ),
    );
  }
}

/// Badge de priorité temporelle (Faible, J-2, J-1, Aujourd'hui, Retard).
class PrioriteEcheanceBadge extends ConsumerWidget {
  const PrioriteEcheanceBadge({super.key, required this.prestation, this.compact = false});
  final Prestation prestation;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moteur = ref.watch(moteurEcheancesProvider);
    final priorite = moteur.calculerPriorite(prestation);

    if (priorite == PrioriteEcheance.faible && !compact) {
      return const SizedBox.shrink();
    }

    final (Color couleur, IconData icone, String libelle) = switch (priorite) {
      PrioriteEcheance.enRetard => (AppColors.negative, Icons.error_outline_rounded, moteur.texteRetard(prestation)),
      PrioriteEcheance.aujourdhui => (
          const Color(0xFFDC2626),
          Icons.alarm_rounded,
          prestation.echeanceHeure != null && prestation.echeanceHeure!.isNotEmpty
              ? 'Aujourd\'hui ${prestation.echeanceHeure}'
              : 'Aujourd\'hui'
        ),
      PrioriteEcheance.urgent => (const Color(0xFFEA580C), Icons.warning_amber_rounded, 'Urgent (J-1)'),
      PrioriteEcheance.attention => (const Color(0xFFDF9540), Icons.access_time_rounded, 'Attention (J-2)'),
      PrioriteEcheance.faible => (AppColors.muted, Icons.calendar_today_outlined, moteur.texteDelai(prestation)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 13, color: couleur),
          const SizedBox(width: 4),
          Text(
            libelle,
            style: TextStyle(color: couleur, fontWeight: FontWeight.w800, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Carte élégante pour afficher une prestation dans une liste.
class PrestationCard extends ConsumerWidget {
  const PrestationCard({
    super.key,
    required this.prestation,
    required this.onTap,
  });

  final Prestation prestation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contact = prestation.contactId != null
        ? ref.watch(contactProvider(prestation.contactId!)).value
        : null;
    final contactNom = contact?.nomAffiche ?? (prestation.contactId != null ? 'Client...' : 'Client non assigné');

     return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.green.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Indicateur de statut vertical
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: _couleurStatut(prestation.statut),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                prestation.titre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: AppColors.ink,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatutPrestationBadge(statut: prestation.statut),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 14, color: AppColors.muted),
                            const SizedBox(width: 4),
                            Text(
                              contactNom,
                              style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        if (prestation.estContrat) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF01226C).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '📑 Contrat${prestation.metierCode != MetierCode.generique ? ' • ${prestation.metierCode.libelle}' : ''}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF01226C),
                                  ),
                                ),
                              ),
                              if (prestation.debutPrevu != null && prestation.echeanceJour != null) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${DateFormat('dd/MM/yy').format(prestation.debutPrevu!)} → ${DateFormat('dd/MM/yy').format(prestation.echeanceJour!)}'
                                    '${prestation.dureeEstimee != null ? ' (${prestation.dureeEstimee} ${prestation.uniteDuree.name})' : ''}',
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                PrioriteEcheanceBadge(prestation: prestation, compact: true),
                                if (prestation.responsableNom != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Resp: ${prestation.responsableNom}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                  ),
                                ],
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  montant(context, ref, prestation.total),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                    color: AppColors.green,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                StatutFinancierBadge(prestation: prestation),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _couleurStatut(StatutPrestation statut) {
    return switch (statut) {
      StatutPrestation.aFaire => const Color(0xFF64748B),
      StatutPrestation.planifiee => const Color(0xFF0284C7),
      StatutPrestation.enCours => AppColors.gold,
      StatutPrestation.terminee => AppColors.positive,
      StatutPrestation.livree => const Color(0xFF7C3AED),
      StatutPrestation.annulee => AppColors.negative,
    };
  }
}
