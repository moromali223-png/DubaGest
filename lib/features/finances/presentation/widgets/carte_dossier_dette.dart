import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/dossier_dette.dart';
import '../../domain/entities/finances.dart';
import '../providers/finances_providers.dart';
import 'dialog_recevoir_paiement_dossier.dart';
import 'finances_widgets.dart';
import 'releve_compte_modal.dart';

/// Carte de synthèse d'un client / fournisseur dans la liste principale des dettes.
/// « Une personne = une seule carte consolidée ».
class CarteDossierDette extends ConsumerWidget {
  const CarteDossierDette({
    super.key,
    required this.dossier,
    required this.onTap,
  });

  final DossierDette dossier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final devise = ref.watch(deviseProvider);
    final droits = ref.watch(droitsFinancesProvider);
    final estRecevoir = dossier.sens == SensEngagement.aRecevoir;

    // Statut & Couleurs
    final (fondStatut, couleurStatut, texteStatut, iconeStatut) = switch (dossier.statutGlobal) {
      StatutDossierDette.enRetard => (
          AppColors.negativeSoft,
          AppColors.negative,
          dossier.totalEnRetard > 0
              ? '${l10n.montant(dossier.totalEnRetard, devise)} en retard'
              : 'En retard',
          Icons.error_outline_rounded,
        ),
      StatutDossierDette.bientot => (
          AppColors.warningSoft,
          AppColors.warning,
          'À payer bientôt',
          Icons.schedule_rounded,
        ),
      StatutDossierDette.aJour => (
          AppColors.positiveSoft,
          AppColors.positive,
          'À jour',
          Icons.check_circle_outline_rounded,
        ),
      StatutDossierDette.regle => (
          AppColors.background,
          AppColors.muted,
          'Réglé',
          Icons.task_alt_rounded,
        ),
    };

    final initiales = dossier.nomAffiche.trim().isEmpty
        ? '?'
        : dossier.nomAffiche.trim().characters.first.toUpperCase();

    final nbEcheances = dossier.echeances.where((e) => e.montantReste > 0).length;
    final labelDettes = '${dossier.nbDettesActives} dette${dossier.nbDettesActives > 1 ? 's' : ''}';
    final labelEcheances = nbEcheances > 0 ? '$nbEcheances échéance${nbEcheances > 1 ? 's' : ''}' : null;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dossier.estEnRetard ? AppColors.negative.withValues(alpha: 0.35) : AppColors.border,
          width: dossier.estEnRetard ? 1.5 : 1,
        ),
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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. En-tête : Avatar + Nom + Téléphone + Menu d'actions rapides
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: dossier.estEnRetard
                          ? AppColors.negativeSoft
                          : const Color(0xFF01226C).withValues(alpha: 0.1),
                      foregroundColor: dossier.estEnRetard ? AppColors.negative : const Color(0xFF01226C),
                      child: Text(
                        initiales,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dossier.nomAffiche,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.ink,
                            ),
                          ),
                          if (dossier.telephone != null && dossier.telephone!.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              dossier.telephone!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Menu actions contextuelles rapides
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.muted),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (action) {
                        switch (action) {
                          case 'dossier':
                            onTap();
                            break;
                          case 'paiement':
                            DialogRecevoirPaiementDossier.show(context, dossier);
                            break;
                          case 'releve':
                            ReleveCompteModal.show(context, dossier);
                            break;
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'dossier',
                          child: Row(
                            children: [
                              Icon(Icons.folder_open_rounded, size: 18, color: Color(0xFF01226C)),
                              SizedBox(width: 8),
                              Text('Voir le dossier'),
                            ],
                          ),
                        ),
                        if (dossier.reste > 0 && (estRecevoir ? droits.encaisser : droits.decaisser))
                          PopupMenuItem(
                            value: 'paiement',
                            child: Row(
                              children: [
                                Icon(
                                  estRecevoir ? Icons.add_circle_outline_rounded : Icons.payment_rounded,
                                  size: 18,
                                  color: AppColors.green,
                                ),
                                const SizedBox(width: 8),
                                Text(estRecevoir ? 'Recevoir un paiement' : 'Effectuer un paiement'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'releve',
                          child: Row(
                            children: [
                              Icon(Icons.share_outlined, size: 18, color: AppColors.ink),
                              SizedBox(width: 8),
                              Text('Partager le relevé'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // 2. Montant restant + Badge de statut
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          estRecevoir ? 'À recevoir' : 'À payer',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.montant(dossier.reste, devise),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF01226C),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

                const Divider(height: 20, color: AppColors.border),

                // 3. Bas de carte : Nombre de dettes & Prochaine échéance
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      [labelDettes, ?labelEcheances].join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dossier.prochaineEcheance != null && dossier.reste > 0) ...[
                          const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.muted),
                          const SizedBox(width: 4),
                          Text(
                            'Échéance: ${l10n.date(dossier.prochaineEcheance!)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: dossier.estEnRetard ? AppColors.negative : AppColors.muted,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.muted,
                        ),
                      ],
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
