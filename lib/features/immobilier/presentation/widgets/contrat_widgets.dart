import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/contrat_bail.dart';
import '../providers/immobilier_providers.dart';

/// Badge de statut d'un contrat de bail.
class StatutContratBadge extends StatelessWidget {
  const StatutContratBadge({super.key, required this.statut});
  final StatutContratBail statut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: statut.couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statut.couleur.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statut.icone, size: 12.5, color: statut.couleur),
          const SizedBox(width: 4),
          Text(
            statut.libelle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: statut.couleur,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge du type juridique de bail.
class TypeBailBadge extends StatelessWidget {
  const TypeBailBadge({super.key, required this.type});
  final TypeBail type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icone, size: 11.5, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            type.libelle,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicateur de signatures (Bailleur & Locataire).
class SignatureStatutIndicator extends StatelessWidget {
  const SignatureStatutIndicator({
    super.key,
    required this.signeBailleur,
    required this.signeLocataire,
  });

  final bool signeBailleur;
  final bool signeLocataire;

  @override
  Widget build(BuildContext context) {
    final entierementSigne = signeBailleur && signeLocataire;
    final auMoinsUn = signeBailleur || signeLocataire;

    final Color color = entierementSigne
        ? const Color(0xFF10B981)
        : auMoinsUn
            ? const Color(0xFFDF9540)
            : const Color(0xFF94A3B8);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            entierementSigne
                ? Icons.draw_rounded
                : Icons.hourglass_top_rounded,
            size: 11.5,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            entierementSigne
                ? 'Signé 2/2'
                : auMoinsUn
                    ? 'Signé 1/2'
                    : 'Non signé',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// En-tête KPI des contrats de bail.
class ContratsStatsHeader extends StatelessWidget {
  const ContratsStatsHeader({
    super.key,
    required this.contrats,
    required this.devise,
  });

  final List<ContratBail> contrats;
  final String devise;

  @override
  Widget build(BuildContext context) {
    final total = contrats.length;
    final actifs = contrats.where((c) => c.statut == StatutContratBail.actif).length;
    final preavis = contrats.where((c) => c.statut == StatutContratBail.enPreavis).length;
    final brouillons = contrats.where((c) => c.statut == StatutContratBail.brouillon).length;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.history_edu_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contrats de bail',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Sécurisation juridique & financière',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFDF9540),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$total au total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('Actifs', actifs, const Color(0xFF10B981)),
              _buildStatItem('En préavis', preavis, const Color(0xFFDF9540)),
              _buildStatItem('Brouillons', brouillons, Colors.white70),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Carte récapitulative d'un contrat de bail.
class ContratCard extends ConsumerWidget {
  const ContratCard({super.key, required this.contrat});
  final ContratBail contrat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contexteActifProvider);
    final devise = ctx?.entreprise?.devise ?? 'FCFA';

    final biens = ref.watch(biensListProvider).value ?? const [];
    final contacts = ref.watch(contactsProvider).value ?? const [];

    final bien = biens.where((b) => b.id == contrat.bienId).firstOrNull;
    final locataire = contacts.where((c) => c.id == contrat.locataireId).firstOrNull;

    final dateDebutFormat =
        '${contrat.dateDebut.day.toString().padLeft(2, '0')}/${contrat.dateDebut.month.toString().padLeft(2, '0')}/${contrat.dateDebut.year}';
    final dateFinFormat = contrat.dateFinPrevue != null
        ? '${contrat.dateFinPrevue!.day.toString().padLeft(2, '0')}/${contrat.dateFinPrevue!.month.toString().padLeft(2, '0')}/${contrat.dateFinPrevue!.year}'
        : 'Indéterminée';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border, width: 1.2),
      ),
      color: AppColors.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(Routes.contratDetails(contrat.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ligne 1: Référence, type de bail et statut
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.description_outlined, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contrat.reference,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        TypeBailBadge(type: contrat.typeBail),
                      ],
                    ),
                  ),
                  StatutContratBadge(statut: contrat.statut),
                ],
              ),
              const SizedBox(height: 12),

              // Ligne 2: Bien et Locataire
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
                        const Icon(Icons.home_work_outlined, size: 14, color: AppColors.muted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            bien?.nom ?? 'Bien (#${contrat.bienId.substring(0, 6)})',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.muted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            locataire?.nomAffiche ?? 'Locataire (#${contrat.locataireId.substring(0, 6)})',
                            style: const TextStyle(fontSize: 12, color: AppColors.ink),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Ligne 3: Période & Signatures
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.muted),
                      const SizedBox(width: 5),
                      Text(
                        '$dateDebutFormat → $dateFinFormat',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  SignatureStatutIndicator(
                    signeBailleur: contrat.signeParBailleur,
                    signeLocataire: contrat.signeParLocataire,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 8),

              // Ligne 4: Financier (Loyer + charges / Dépôt)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Loyer mensuel global',
                        style: TextStyle(fontSize: 10.5, color: AppColors.muted),
                      ),
                      Text(
                        context.l10n.montant(contrat.totalMensuel, devise),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  if (contrat.depotGarantie > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Dépôt de garantie',
                          style: TextStyle(fontSize: 10.5, color: AppColors.muted),
                        ),
                        Text(
                          context.l10n.montant(contrat.depotGarantie, devise),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDF9540),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
