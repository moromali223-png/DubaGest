import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../contacts/presentation/widgets/contact_avatar.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/bien_immobilier.dart';
import '../providers/immobilier_providers.dart';

/// Badge coloré pour le statut d'un bien.
class StatutBienBadge extends StatelessWidget {
  const StatutBienBadge({super.key, required this.statut});
  final StatutBien statut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statut.couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statut.couleur.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statut.icone, size: 13, color: statut.couleur),
          const SizedBox(width: 4),
          Text(
            statut.libelle,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: statut.couleur,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge élégant pour le type de bien.
class TypeBienBadge extends StatelessWidget {
  const TypeBienBadge({super.key, required this.type});
  final TypeBien type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icone, size: 13, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            type.libelle,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte élégante pour afficher un bien dans une liste.
class BienCard extends ConsumerWidget {
  const BienCard({
    super.key,
    required this.bien,
    this.onTap,
  });

  final BienImmobilier bien;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contexteActifProvider);
    final devise = ctx?.entreprise?.devise ?? 'FCFA';
    final l10n = context.l10n;

    // Récupérer le nom du propriétaire
    final proprietaire = ref.watch(contactProvider(bien.proprietaireId)).value;
    final proprietaireNom = proprietaire?.nomAffiche ?? 'Propriétaire en cours...';

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
        onTap: onTap ?? () => context.push(Routes.bienDetails(bien.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ligne 1 : Type & Statut
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TypeBienBadge(type: bien.type),
                  StatutBienBadge(statut: bien.statut),
                ],
              ),
              const SizedBox(height: 10),

              // Ligne 2 : Titre et référence
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(bien.type.icone, color: AppColors.primary, size: 26),
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
                          'Réf : ${bien.reference} • ${bien.adresseComplete.isNotEmpty ? bien.adresseComplete : 'Adresse non précisée'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, color: AppColors.border),

              // Ligne 3 : Loyer et Propriétaire
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Loyer de référence',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                      Text(
                        '${l10n.montant(bien.loyerReference, devise)} / ${bien.periodicite.libelle.toLowerCase()}',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.person_pin_circle_outlined, size: 16, color: AppColors.muted),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(
                          proprietaireNom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
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

/// Carte élégante pour afficher un propriétaire.
class ProprietaireCard extends ConsumerWidget {
  const ProprietaireCard({
    super.key,
    required this.contact,
    this.onTap,
  });

  final Contact contact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final biensAsync = ref.watch(biensParProprietaireProvider(contact.id));
    final nbBiens = biensAsync.value?.length ?? 0;

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
        onTap: onTap ?? () => context.push(Routes.proprietaireDetails(contact.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ContactAvatar(contact: contact, radius: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.nomAffiche,
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
                      contact.telephone != null && contact.telephone!.isNotEmpty
                          ? contact.telephone!
                          : (contact.ville != null ? contact.ville! : 'Aucun contact'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDF9540).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$nbBiens bien(s) en gestion',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDF9540),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (contact.telephone != null && contact.telephone!.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.phone_outlined, color: AppColors.green),
                  onPressed: () => launchUrl(Uri.parse('tel:${contact.telephone}')),
                ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sélecteur de propriétaire dans une feuille inférieure modale.
Future<Contact?> choisirProprietaire(BuildContext context) =>
    showModalBottomSheet<Contact>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.85,
        child: _ChoixProprietaireModal(),
      ),
    );

class _ChoixProprietaireModal extends ConsumerStatefulWidget {
  const _ChoixProprietaireModal();

  @override
  ConsumerState<_ChoixProprietaireModal> createState() => _ChoixProprietaireModalState();
}

class _ChoixProprietaireModalState extends ConsumerState<_ChoixProprietaireModal> {
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final proprietaires = ref.watch(proprietairesListProvider).value ?? const [];
    final mots = _recherche.toLowerCase().split(' ').where((m) => m.isNotEmpty);
    final liste = [
      for (final p in proprietaires)
        if (mots.isEmpty || mots.every((m) => '${p.nomAffiche} ${p.telephone ?? ''}'.toLowerCase().contains(m)))
          p,
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Sélectionner un propriétaire',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher par nom ou téléphone...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (t) => setState(() => _recherche = t),
            ),
          ),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person_add_alt_1_outlined, color: Colors.white, size: 20),
            ),
            title: const Text(
              'Créer un nouveau propriétaire',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
            onTap: () {
              Navigator.pop(context);
              context.push(Routes.contactNouveau(relation: RelationContact.proprietaire.code));
            },
          ),
          const Divider(),
          Expanded(
            child: liste.isEmpty
                ? const Center(
                    child: Text('Aucun propriétaire trouvé', style: TextStyle(color: AppColors.muted)),
                  )
                : ListView.builder(
                    itemCount: liste.length,
                    itemBuilder: (_, i) {
                      final c = liste[i];
                      return ListTile(
                        leading: ContactAvatar(contact: c, radius: 20),
                        title: Text(c.nomAffiche, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(c.telephone ?? c.ville ?? 'Aucune coordonnée'),
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
