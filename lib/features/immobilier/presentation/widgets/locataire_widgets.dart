import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../contacts/presentation/widgets/contact_avatar.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../services/presentation/widgets/devis_contact_widgets.dart';
import '../../domain/entities/locataire_immobilier.dart';
import '../providers/immobilier_providers.dart';

/// Badge élégant affichant le statut financier d'un locataire.
class StatutFinancierBadge extends StatelessWidget {
  const StatutFinancierBadge({super.key, required this.statut});
  final StatutFinancierLocataire statut;

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

/// Carte représentant un locataire dans une liste ou un tableau de bord.
class LocataireCard extends ConsumerWidget {
  const LocataireCard({
    super.key,
    required this.contact,
    this.onTap,
  });

  final Contact contact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contexteActifProvider);
    final devise = ctx?.entreprise?.devise ?? 'FCFA';
    final l10n = context.l10n;

    final situation = ref.watch(situationFinanciereLocataireProvider(contact.id));

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
        onTap: onTap ?? () => context.push(Routes.locataireDetails(contact.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ContactAvatar(contact: contact, radius: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                contact.nomAffiche,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                            if (contact.typePersonne == TypePersonne.organisation) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Société',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
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
                        if (contact.email != null && contact.email!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            contact.email!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (contact.telephone != null && contact.telephone!.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.phone_outlined, color: AppColors.green),
                      tooltip: 'Appeler',
                      onPressed: () => launchUrl(Uri.parse('tel:${contact.telephone}')),
                    ),
                ],
              ),
              const Divider(height: 20, color: AppColors.border),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatutFinancierBadge(statut: situation.statut),
                  if (situation.soldeDu > 0)
                    Text(
                      'Solde : ${l10n.montant(situation.soldeDu, devise)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEF4444),
                      ),
                    )
                  else
                    const Text(
                      'Aucun impayé',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981),
                      ),
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

/// Carte récapitulative des finances du locataire.
class SituationFinanciereCard extends StatelessWidget {
  const SituationFinanciereCard({
    super.key,
    required this.situation,
    required this.devise,
  });

  final SituationFinanciereLocataire situation;
  final String devise;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Card(
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
                const Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 20, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Situation Financière',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                  ],
                ),
                StatutFinancierBadge(statut: situation.statut),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MetricItem(
                    label: 'Loyers appelés',
                    valeur: l10n.montant(situation.totalAppeles, devise),
                    couleur: AppColors.ink,
                  ),
                ),
                Container(width: 1, height: 38, color: AppColors.border),
                Expanded(
                  child: _MetricItem(
                    label: 'Total réglé',
                    valeur: l10n.montant(situation.totalRegle, devise),
                    couleur: const Color(0xFF10B981),
                  ),
                ),
                Container(width: 1, height: 38, color: AppColors.border),
                Expanded(
                  child: _MetricItem(
                    label: 'Solde dû',
                    valeur: l10n.montant(situation.soldeDu, devise),
                    couleur: situation.soldeDu > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
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

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.valeur,
    required this.couleur,
  });

  final String label;
  final String valeur;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          valeur,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: couleur,
          ),
        ),
      ],
    );
  }
}

/// Carte détaillée affichant les informations du dossier locatif (ID, Garant, Urgence, Travail).
class DossierLocataireCard extends StatelessWidget {
  const DossierLocataireCard({
    super.key,
    required this.profil,
    required this.onEdit,
  });

  final ProfilLocataire? profil;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
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
                const Row(
                  children: [
                    Icon(Icons.folder_shared_outlined, size: 20, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Dossier Locatif',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(profil == null ? 'Compléter' : 'Modifier'),
                  onPressed: onEdit,
                ),
              ],
            ),
            const Divider(height: 16, color: AppColors.border),

            // Pièce d'identité
            _DossierRow(
              icon: Icons.badge_outlined,
              title: 'Pièce d\'identité',
              subtitle: profil?.aPieceIdentite ?? false
                  ? '${profil!.typePiece.libelle} — N° ${profil!.numeroPiece}'
                  : 'Aucune pièce enregistrée',
              isEmphasized: profil?.aPieceIdentite ?? false,
            ),
            const SizedBox(height: 12),

            // Situation professionnelle
            _DossierRow(
              icon: Icons.work_outline_rounded,
              title: 'Situation professionnelle',
              subtitle: (profil?.profession?.trim().isNotEmpty ?? false)
                  ? '${profil!.profession}${profil?.employeur != null && profil!.employeur!.isNotEmpty ? ' chez ${profil!.employeur}' : ''}'
                  : 'Non précisée',
              isEmphasized: profil?.profession?.trim().isNotEmpty ?? false,
            ),
            const SizedBox(height: 12),

            // Personne d'urgence
            _DossierRow(
              icon: Icons.emergency_outlined,
              title: 'Contact d\'urgence',
              subtitle: (profil?.aContactUrgence ?? false)
                  ? '${profil!.nomUrgence ?? ''} (${profil!.telephoneUrgence ?? ''})'
                  : 'Non renseigné',
              isEmphasized: profil?.aContactUrgence ?? false,
            ),
            const SizedBox(height: 12),

            // Cautionnaire / Garant
            _DossierRow(
              icon: Icons.shield_outlined,
              title: 'Garant / Cautionnaire',
              subtitle: (profil?.aGarant ?? false)
                  ? '${profil!.nomGarant ?? ''} (${profil!.telephoneGarant ?? ''})${profil!.lienGarant != null ? ' · Lien: ${profil!.lienGarant}' : ''}'
                  : 'Aucun garant désigné',
              isEmphasized: profil?.aGarant ?? false,
            ),

            if (profil?.notesLocatives != null && profil!.notesLocatives!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _DossierRow(
                icon: Icons.notes_rounded,
                title: 'Notes & observations',
                subtitle: profil!.notesLocatives!,
                isEmphasized: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DossierRow extends StatelessWidget {
  const _DossierRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isEmphasized,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isEmphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: isEmphasized ? AppColors.primary : AppColors.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isEmphasized ? FontWeight.w700 : FontWeight.w400,
                  color: isEmphasized ? AppColors.ink : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Sélecteur modal d'un locataire (pour baux, loyers ou assignations).
Future<Contact?> choisirLocataire(BuildContext context) => showModalBottomSheet<Contact>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.85,
        child: _ChoixLocataireModal(),
      ),
    );

class _ChoixLocataireModal extends ConsumerStatefulWidget {
  const _ChoixLocataireModal();

  @override
  ConsumerState<_ChoixLocataireModal> createState() => _ChoixLocataireModalState();
}

class _ChoixLocataireModalState extends ConsumerState<_ChoixLocataireModal> {
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final locataires = ref.watch(locatairesListProvider).value ?? const [];
    final mots = _recherche.toLowerCase().split(' ').where((m) => m.isNotEmpty);
    final liste = [
      for (final l in locataires)
        if (mots.isEmpty || mots.every((m) => '${l.nomAffiche} ${l.telephone ?? ''}'.toLowerCase().contains(m)))
          l,
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Sélectionner un locataire',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.person_add_rounded, size: 18, color: AppColors.primary),
                  label: const Text('Nouveau locataire', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                  onPressed: () async {
                    final nouveau = await DialogueNouveauContactDevis.afficher(
                      context,
                      nomInitial: _recherche.trim().isNotEmpty ? _recherche.trim() : null,
                      relation: RelationContact.locataire,
                    );
                    if (nouveau != null && mounted) {
                      ref.invalidate(locatairesListProvider);
                      Navigator.of(context).pop(nouveau);
                    }
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher par nom, téléphone...',
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
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.greenSoft,
              child: Icon(Icons.person_add_alt_1_rounded, color: AppColors.green),
            ),
            title: Text(
              _recherche.trim().isNotEmpty
                  ? 'Créer « ${_recherche.trim()} »'
                  : 'Créer un nouveau locataire / client',
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.green),
            ),
            subtitle: const Text(
              'Ajout direct sans quitter le contrat',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            onTap: () async {
              final nouveau = await DialogueNouveauContactDevis.afficher(
                context,
                nomInitial: _recherche.trim().isNotEmpty ? _recherche.trim() : null,
                relation: RelationContact.locataire,
              );
              if (nouveau != null && mounted) {
                ref.invalidate(locatairesListProvider);
                Navigator.of(context).pop(nouveau);
              }
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: liste.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_search_outlined, size: 40, color: AppColors.muted),
                          const SizedBox(height: 8),
                          Text(
                            _recherche.trim().isNotEmpty
                                ? 'Aucun locataire trouvé pour « ${_recherche.trim()} »'
                                : 'Aucun locataire enregistré',
                            style: const TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                            onPressed: () async {
                              final nouveau = await DialogueNouveauContactDevis.afficher(
                                context,
                                nomInitial: _recherche.trim().isNotEmpty ? _recherche.trim() : null,
                                relation: RelationContact.locataire,
                              );
                              if (nouveau != null && mounted) {
                                ref.invalidate(locatairesListProvider);
                                Navigator.of(context).pop(nouveau);
                              }
                            },
                            icon: const Icon(Icons.person_add_rounded, size: 18),
                            label: Text(
                              _recherche.trim().isNotEmpty
                                  ? 'Créer « ${_recherche.trim()} »'
                                  : 'Créer un nouveau locataire',
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: liste.length,
                    itemBuilder: (context, index) {
                      final c = liste[index];
                      return ListTile(
                        leading: ContactAvatar(contact: c, radius: 20),
                        title: Text(c.nomAffiche, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(c.telephone ?? c.ville ?? 'Aucun contact'),
                        onTap: () => Navigator.of(context).pop(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
