import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../contacts/presentation/widgets/contact_avatar.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/bien_immobilier.dart';
import '../providers/immobilier_providers.dart';
import '../widgets/immobilier_widgets.dart';

class BienDetailsPage extends ConsumerWidget {
  const BienDetailsPage({super.key, required this.bienId});
  final String bienId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bienAsync = ref.watch(bienDetailsProvider(bienId));
    final l10n = context.l10n;
    final ctx = ref.watch(contexteActifProvider);
    final devise = ctx?.entreprise?.devise ?? 'FCFA';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiche du bien'),
        actions: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => context.push(Routes.loyerRecevoirAvec(bienId: bienId)),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Recevoir loyer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier',
            onPressed: () => context.push(Routes.bienModifier(bienId)),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) async {
              if (val == 'statut') {
                _changerStatutModal(context, ref);
              } else if (val == 'archiver') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Archiver ce bien ?'),
                    content: const Text(
                      'Le bien sera retiré de la liste active mais restera accessible dans l\'historique.',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Archiver'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(immobilierRepositoryProvider).archiverBien(bienId);
                  ref.invalidate(biensListProvider);
                  ref.invalidate(bienDetailsProvider(bienId));
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'statut',
                child: Row(
                  children: [
                    Icon(Icons.sync_alt_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Changer le statut'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'archiver',
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.negative),
                    SizedBox(width: 8),
                    Text('Archiver le bien', style: TextStyle(color: AppColors.negative)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: bienAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => MessageView(
          icon: Icons.error_outline,
          title: 'Erreur',
          message: err.toString(),
          action: FilledButton.icon(
            onPressed: () => ref.invalidate(bienDetailsProvider(bienId)),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ),
        data: (bien) {
          if (bien == null) {
            return const MessageView(
              icon: Icons.search_off_rounded,
              title: 'Bien introuvable',
              message: 'Ce bien n\'existe pas ou a été supprimé.',
            );
          }

          final proprietaire = ref.watch(contactProvider(bien.proprietaireId)).value;
          final carac = bien.caracteristiques;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // En-tête : Nom, Réf, Badges
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: AppColors.border, width: 1.2),
                ),
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TypeBienBadge(type: bien.type),
                          StatutBienBadge(statut: bien.statut),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        bien.nom,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Réf : ${bien.reference} • ${bien.adresseComplete.isNotEmpty ? bien.adresseComplete : 'Adresse non renseignée'}',
                        style: const TextStyle(fontSize: 13.5, color: AppColors.muted),
                      ),
                      if (bien.description != null && bien.description!.isNotEmpty) ...[
                        const Divider(height: 24, color: AppColors.border),
                        Text(
                          bien.description!,
                          style: const TextStyle(fontSize: 14, color: AppColors.ink, height: 1.4),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Conditions financières
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border, width: 1.2),
                ),
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.account_balance_wallet_outlined, size: 20, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'Conditions Financières',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                          ),
                        ],
                      ),
                      const Divider(height: 20, color: AppColors.border),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoLigne(
                              titre: 'Loyer de référence',
                              valeur: '${l10n.montant(bien.loyerReference, devise)} / ${bien.periodicite.libelle.toLowerCase()}',
                              valeurCouleur: AppColors.primary,
                              estGras: true,
                            ),
                          ),
                          Expanded(
                            child: _InfoLigne(
                              titre: 'Dépôt de garantie prévu',
                              valeur: bien.depotGarantiePrevu > 0
                                  ? l10n.montant(bien.depotGarantiePrevu, devise)
                                  : 'Non spécifié',
                              valeurCouleur: const Color(0xFFDF9540),
                              estGras: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Propriétaire rattaché
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border, width: 1.2),
                ),
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.badge_outlined, size: 20, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'Propriétaire du bien',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                          ),
                        ],
                      ),
                      const Divider(height: 20, color: AppColors.border),
                      if (proprietaire != null) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ContactAvatar(contact: proprietaire, radius: 24),
                          title: Text(
                            proprietaire.nomAffiche,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          subtitle: Text(
                            proprietaire.telephone ?? proprietaire.ville ?? 'Aucune coordonnée',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                          onTap: () => context.push(Routes.proprietaireDetails(proprietaire.id)),
                        ),
                      ] else ...[
                        const Text(
                          'Propriétaire en cours de chargement...',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Caractéristiques techniques
              if (bien.type != TypeBien.terrain) ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border, width: 1.2),
                  ),
                  color: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.tune_rounded, size: 20, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text(
                              'Caractéristiques & Équipements',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                            ),
                          ],
                        ),
                        const Divider(height: 20, color: AppColors.border),
                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          children: [
                            if (carac.surfaceM2 != null)
                              _CaracItem(icone: Icons.straighten_rounded, label: '${carac.surfaceM2} m²'),
                            if (carac.nbPieces != null)
                              _CaracItem(icone: Icons.meeting_room_outlined, label: '${carac.nbPieces} pièces'),
                            if (carac.nbChambres != null)
                              _CaracItem(icone: Icons.bed_outlined, label: '${carac.nbChambres} chambres'),
                            if (carac.nbSallesDeBain != null)
                              _CaracItem(icone: Icons.bathtub_outlined, label: '${carac.nbSallesDeBain} SDB'),
                            if (carac.etage != null)
                              _CaracItem(icone: Icons.layers_outlined, label: 'Étage ${carac.etage}'),
                            if (carac.meuble)
                              const _CaracItem(icone: Icons.chair_outlined, label: 'Meublé'),
                            if (carac.climatisation)
                              const _CaracItem(icone: Icons.ac_unit_rounded, label: 'Climatisation'),
                            if (carac.parking)
                              const _CaracItem(icone: Icons.directions_car_outlined, label: 'Parking'),
                            if (carac.compteurEauIndependant)
                              const _CaracItem(icone: Icons.water_drop_outlined, label: 'Compteur eau dédié'),
                            if (carac.compteurElectriciteIndependant)
                              const _CaracItem(icone: Icons.electric_bolt_outlined, label: 'Compteur élec dédié'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Notes internes
              if (bien.notes != null && bien.notes!.isNotEmpty) ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border, width: 1.2),
                  ),
                  color: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.notes_outlined, size: 20, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text(
                              'Notes Internes',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                            ),
                          ],
                        ),
                        const Divider(height: 20, color: AppColors.border),
                        Text(
                          bien.notes!,
                          style: const TextStyle(fontSize: 14, color: AppColors.ink, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],
          );
        },
      ),
    );
  }

  void _changerStatutModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Modifier le statut du bien',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 12),
              for (final s in StatutBien.values)
                ListTile(
                  leading: Icon(s.icone, color: s.couleur),
                  title: Text(s.libelle, style: TextStyle(fontWeight: FontWeight.w700, color: s.couleur)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ref.read(immobilierRepositoryProvider).changerStatutBien(bienId, s);
                    ref.invalidate(bienDetailsProvider(bienId));
                    ref.invalidate(biensListProvider);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLigne extends StatelessWidget {
  const _InfoLigne({
    required this.titre,
    required this.valeur,
    this.valeurCouleur,
    this.estGras = false,
  });

  final String titre;
  final String valeur;
  final Color? valeurCouleur;
  final bool estGras;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titre, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
        const SizedBox(height: 3),
        Text(
          valeur,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: estGras ? FontWeight.w800 : FontWeight.w600,
            color: valeurCouleur ?? AppColors.ink,
          ),
        ),
      ],
    );
  }
}

class _CaracItem extends StatelessWidget {
  const _CaracItem({required this.icone, required this.label});
  final IconData icone;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
