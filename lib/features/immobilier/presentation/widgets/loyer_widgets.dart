import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/echeance_loyer.dart';
import '../providers/immobilier_providers.dart';
import 'encaisser_loyer_dialog.dart';

/// Badge du statut de règlement de l'échéance de loyer.
class StatutEcheanceBadge extends StatelessWidget {
  const StatutEcheanceBadge({
    super.key,
    required this.statut,
    this.estEnRetard = false,
  });

  final StatutEcheanceLoyer statut;
  final bool estEnRetard;

  @override
  Widget build(BuildContext context) {
    final effectiveStatut = (estEnRetard && statut != StatutEcheanceLoyer.solde)
        ? StatutEcheanceLoyer.enRetard
        : statut;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: effectiveStatut.couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: effectiveStatut.couleur.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(effectiveStatut.icone, size: 12.5, color: effectiveStatut.couleur),
          const SizedBox(width: 4),
          Text(
            effectiveStatut.libelle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: effectiveStatut.couleur,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barre de progression du recouvrement pour une échéance.
class ProgressionReglementBar extends StatelessWidget {
  const ProgressionReglementBar({
    super.key,
    required this.montantRegle,
    required this.totalDu,
  });

  final int montantRegle;
  final int totalDu;

  @override
  Widget build(BuildContext context) {
    final ratio = totalDu > 0 ? (montantRegle / totalDu).clamp(0.0, 1.0) : 1.0;
    final solde = montantRegle >= totalDu;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(
              solde ? const Color(0xFF10B981) : const Color(0xFFDF9540),
            ),
          ),
        ),
      ],
    );
  }
}

/// En-tête KPI de recouvrement mensuel avec navigation par mois.
class RecouvrementStatsHeader extends ConsumerWidget {
  const RecouvrementStatsHeader({
    super.key,
    required this.stats,
    required this.devise,
  });

  final RecouvrementStatistiques stats;
  final String devise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtre = ref.watch(filtreLoyersProvider);
    final notifier = ref.read(filtreLoyersProvider.notifier);

    const moisNoms = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    final nomMois = moisNoms[(filtre.mois - 1).clamp(0, 11)];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E7E4E), Color(0xFF15633D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
          // Ligne 1: Sélecteur de période avec flèches
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
                onPressed: notifier.moisPrecedent,
                tooltip: 'Mois précédent',
              ),
              Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, color: Color(0xFFDF9540), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '$nomMois ${filtre.annee}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28),
                onPressed: notifier.moisSuivant,
                tooltip: 'Mois suivant',
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),

          // Ligne 2: Indicateurs KPI
          Row(
            children: [
              _buildKpiItem('Total appelé', context.l10n.montant(stats.totalAppele, devise), Colors.white),
              _buildKpiItem('Encaissé', context.l10n.montant(stats.totalEncaisse, devise), const Color(0xFF10B981)),
              _buildKpiItem('Reste dû', context.l10n.montant(stats.totalImpayes, devise), const Color(0xFFDF9540)),
            ],
          ),
          const SizedBox(height: 12),

          // Ligne 3: Taux global de recouvrement
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Taux de recouvrement du mois',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        Text(
                          '${stats.tauxRecouvrement.toStringAsFixed(1)} %',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: stats.tauxRecouvrement / 100,
                        minHeight: 5,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiItem(String label, String montant, Color couleur) {
    return Expanded(
      child: Column(
        children: [
          Text(
            montant,
            style: TextStyle(
              color: couleur,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Carte représentant une échéance de loyer mensuelle.
class EcheanceLoyerCard extends ConsumerWidget {
  const EcheanceLoyerCard({super.key, required this.echeance});
  final EcheanceLoyer echeance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contexteActifProvider);
    final devise = ctx?.entreprise?.devise ?? 'FCFA';

    final biens = ref.watch(biensListProvider).value ?? const [];
    final contacts = ref.watch(contactsProvider).value ?? const [];

    final bien = biens.where((b) => b.id == echeance.bienId).firstOrNull;
    final locataire = contacts.where((c) => c.id == echeance.locataireId).firstOrNull;

    final estEnRetard = echeance.estEnRetardCalcule(DateTime.now());
    final dateExigibiliteFormat =
        '${echeance.dateExigibilite.day.toString().padLeft(2, '0')}/${echeance.dateExigibilite.month.toString().padLeft(2, '0')}/${echeance.dateExigibilite.year}';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: estEnRetard && !echeance.estSolde
              ? const Color(0xFFEF4444).withValues(alpha: 0.5)
              : AppColors.border,
          width: estEnRetard && !echeance.estSolde ? 1.5 : 1.2,
        ),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne 1: Référence, statut et date limite
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      echeance.reference,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                StatutEcheanceBadge(statut: echeance.statut, estEnRetard: estEnRetard),
              ],
            ),
            const SizedBox(height: 10),

            // Ligne 2: Locataire et Bien loué
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.muted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          locataire?.nomAffiche ?? 'Locataire (#${echeance.locataireId.substring(0, 6)})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (locataire?.telephone != null)
                        Text(
                          locataire!.telephone!,
                          style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.home_work_outlined, size: 14, color: AppColors.muted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          bien?.nom ?? 'Bien (#${echeance.bienId.substring(0, 6)})',
                          style: const TextStyle(fontSize: 12, color: AppColors.ink),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            estEnRetard ? Icons.alarm_on_rounded : Icons.event_outlined,
                            size: 13,
                            color: estEnRetard ? const Color(0xFFEF4444) : AppColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Échéance : $dateExigibiliteFormat',
                            style: TextStyle(
                              fontSize: 11,
                              color: estEnRetard ? const Color(0xFFEF4444) : AppColors.muted,
                              fontWeight: estEnRetard ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Ligne 3: Jauge de recouvrement
            ProgressionReglementBar(
              montantRegle: echeance.montantRegle,
              totalDu: echeance.totalDu,
            ),
            const SizedBox(height: 10),

            // Ligne 4: Détail montants et bouton d'encaissement
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total dû : ${context.l10n.montant(echeance.totalDu, devise)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Réglé : ${context.l10n.montant(echeance.montantRegle, devise)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        if (!echeance.estSolde) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(Reste : ${context.l10n.montant(echeance.resteAPayer, devise)})',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: estEnRetard ? const Color(0xFFEF4444) : const Color(0xFFDF9540),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                if (!echeance.estSolde)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.payments_outlined, size: 16),
                    label: const Text('Encaisser'),
                    onPressed: () => afficherDialogueEncaissement(context, echeance),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 15, color: Color(0xFF10B981)),
                        SizedBox(width: 4),
                        Text(
                          'Quittance prête',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
