import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../contacts/presentation/widgets/contact_avatar.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/bien_immobilier.dart';
import '../../domain/entities/location_immobilier.dart';
import '../providers/immobilier_providers.dart';
import 'immobilier_widgets.dart';

/// Badge élégant pour le statut d'une location.
class StatutLocationBadge extends StatelessWidget {
  const StatutLocationBadge({super.key, required this.statut});
  final StatutLocation statut;

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

/// En-tête de synthèse d'occupation du parc (taux, occupés, vacants, loyers totaux).
class OccupationStatsHeader extends StatelessWidget {
  const OccupationStatsHeader({
    super.key,
    required this.stats,
    required this.devise,
  });

  final ParcOccupationStatistiques stats;
  final String devise;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border, width: 1.2),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Taux d\'occupation du parc',
                      style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${stats.tauxOccupation.toStringAsFixed(1)} %',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${stats.nbOccupes}/${stats.totalBiens} biens)',
                          style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Volume loyers actifs',
                      style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.montant(stats.loyerTotalMensuel, devise),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: stats.totalBiens > 0 ? (stats.nbOccupes / stats.totalBiens) : 0,
                minHeight: 8,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              alignment: WrapAlignment.spaceAround,
              children: [
                _StatChip(
                  label: 'Occupés',
                  count: stats.nbOccupes,
                  color: const Color(0xFF10B981),
                  icon: Icons.check_circle_outline,
                ),
                _StatChip(
                  label: 'Vacants',
                  count: stats.nbVacants,
                  color: const Color(0xFF3B82F6),
                  icon: Icons.home_outlined,
                ),
                _StatChip(
                  label: 'Réservés',
                  count: stats.nbReserves,
                  color: const Color(0xFFDF9540),
                  icon: Icons.schedule_rounded,
                ),
                _StatChip(
                  label: 'Travaux',
                  count: stats.nbEnTravaux,
                  color: const Color(0xFFEF4444),
                  icon: Icons.build_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String label;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '$label: $count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Carte d'un bien affichant son état d'occupation en temps réel.
class BienOccupationCard extends ConsumerWidget {
  const BienOccupationCard({super.key, required this.bien});
  final BienImmobilier bien;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contexteActifProvider);
    final devise = ctx?.entreprise?.devise ?? 'FCFA';
    final l10n = context.l10n;

    // Récupérer la location active éventuelle
    final locationActive = ref.watch(locationActiveDuBienProvider(bien.id));
    final locataire = locationActive != null
        ? ref.watch(contactProvider(locationActive.locataireId)).value
        : null;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1.2),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne 1 : Type, nom et statut
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TypeBienBadge(type: bien.type),
                StatutBienBadge(statut: bien.statut),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(bien.type.icone, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bien.nom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Réf : ${bien.reference} • ${bien.adresseComplete}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: AppColors.border),

            // Ligne 2 : Détail d'occupation (Locataire ou Vacance)
            if (locationActive != null) ...[
              Row(
                children: [
                  if (locataire != null) ...[
                    ContactAvatar(contact: locataire, radius: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Occupant : ${locataire.nomAffiche}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            'Entrée le ${_formatDate(locationActive.dateDebut)} • ${l10n.montant(locationActive.totalMensuel, devise)}/mois',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    if (locataire.telephone != null && locataire.telephone!.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.phone_outlined, size: 20, color: AppColors.green),
                        onPressed: () => launchUrl(Uri.parse('tel:${locataire.telephone}')),
                      ),
                  ] else ...[
                    const CircularProgressIndicator(strokeWidth: 2),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Gérer l\'occupation', style: TextStyle(fontSize: 12)),
                    onPressed: () => context.push(Routes.locationDetails(locationActive.id)),
                  ),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Statut : Logement vacant',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                      Text(
                        'Loyer de référence : ${l10n.montant(bien.loyerReference, devise)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Louer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: () => context.push('${Routes.locationNouvelle}?bienId=${bien.id}'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Carte représentant une location dans la liste d'historique.
class LocationCard extends ConsumerWidget {
  const LocationCard({super.key, required this.location});
  final LocationImmobilier location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contexteActifProvider);
    final devise = ctx?.entreprise?.devise ?? 'FCFA';
    final l10n = context.l10n;

    final bienAsync = ref.watch(bienDetailsProvider(location.bienId));
    final locataireAsync = ref.watch(contactProvider(location.locataireId));

    final bien = bienAsync.value;
    final locataire = locataireAsync.value;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1.2),
      ),
      color: AppColors.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(Routes.locationDetails(location.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      bien?.nom ?? 'Bien en cours...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  StatutLocationBadge(statut: location.statut),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Locataire : ${locataire?.nomAffiche ?? 'Chargement...'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Text(
                    'Période : ${_formatDate(location.dateDebut)} → ${location.dateFinPrevue != null ? _formatDate(location.dateFinPrevue!) : 'Indéterminée'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
              const Divider(height: 18, color: AppColors.border),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Loyer : ${l10n.montant(location.loyerMensuel, devise)} / mois',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const Row(
                    children: [
                      Text(
                        'Détails',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
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

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Sélecteur modal d'un bien immobilier.
Future<BienImmobilier?> choisirBien(
  BuildContext context, {
  bool uniquementDisponibles = false,
}) =>
    showModalBottomSheet<BienImmobilier>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: _ChoixBienModal(uniquementDisponibles: uniquementDisponibles),
      ),
    );

class _ChoixBienModal extends ConsumerStatefulWidget {
  const _ChoixBienModal({this.uniquementDisponibles = false});
  final bool uniquementDisponibles;

  @override
  ConsumerState<_ChoixBienModal> createState() => _ChoixBienModalState();
}

class _ChoixBienModalState extends ConsumerState<_ChoixBienModal> {
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final tousLesBiens = ref.watch(biensListProvider).value ?? const [];
    final biensFiltres = tousLesBiens.where((b) {
      if (b.statut == StatutBien.archive) return false;
      if (widget.uniquementDisponibles && b.statut != StatutBien.disponible) return false;
      if (_recherche.trim().isNotEmpty) {
        final query = _recherche.toLowerCase();
        final matchNom = b.nom.toLowerCase().contains(query);
        final matchRef = b.reference.toLowerCase().contains(query);
        final matchVille = (b.ville ?? '').toLowerCase().contains(query);
        return matchNom || matchRef || matchVille;
      }
      return true;
    }).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.uniquementDisponibles
                        ? 'Choisir un bien disponible'
                        : 'Sélectionner un bien immobilier',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher par nom, référence, ville...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                suffixIcon: _recherche.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _recherche = ''),
                      )
                    : null,
              ),
              onChanged: (val) => setState(() => _recherche = val),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: biensFiltres.isEmpty
                ? const Center(
                    child: Text('Aucun bien correspondant trouvé'),
                  )
                : ListView.builder(
                    itemCount: biensFiltres.length,
                    itemBuilder: (context, index) {
                      final b = biensFiltres[index];
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(b.type.icone, color: AppColors.primary),
                        ),
                        title: Text(b.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${b.reference} · ${b.ville ?? 'Ville non précisée'}'),
                        trailing: StatutBienBadge(statut: b.statut),
                        onTap: () => Navigator.of(context).pop(b),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
