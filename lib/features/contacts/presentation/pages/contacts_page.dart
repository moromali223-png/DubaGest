import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/recherche.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../domain/entities/contact.dart';
import '../providers/contacts_providers.dart';
import '../widgets/contact_avatar.dart';

/// Carnet d'adresses centralisé de l'entreprise (Module Commun).
/// Regroupe tous les contacts : Clients, Fournisseurs, Locataires, Propriétaires et Prestataires.
/// Filtrage multi-critères, recherche en direct, appels et messages WhatsApp rapides (fonctionne hors-ligne).
class ContactsPage extends ConsumerStatefulWidget {
  const ContactsPage({super.key, this.initialRelation});

  /// Filtre initial optionnel (ex: ouvert depuis Commerce ou Services)
  final RelationContact? initialRelation;

  @override
  ConsumerState<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends ConsumerState<ContactsPage> {
  @override
  void initState() {
    super.initState();
    if (widget.initialRelation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(filtreContactsProvider.notifier).relation(widget.initialRelation);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final droits = ref.watch(droitsContactsProvider);
    final filtre = ref.watch(filtreContactsProvider);
    final contacts = ref.watch(contactsProvider);
    final stats = ref.watch(statsCarnetContactsProvider).value ?? const StatsCarnetContacts();
    final filtreActif = filtre.recherche.trim().isNotEmpty || filtre.relation != null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.moduleCommunContacts, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(
              'Carnet d\'adresses centralisé · ${stats.total} contact${stats.total > 1 ? "s" : ""}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
        actions: const [SyncStatusButton()],
      ),
      floatingActionButton: !droits.creer
          ? null
          : FloatingActionButton.extended(
              key: const Key('contact-add'),
              onPressed: () => context.push(Routes.contactNew),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text(l10n.contactAdd),
            ),
      body: ResponsiveBody(
        child: Column(
          children: [
            const _BarreRecherche(),
            Expanded(
              child: AsyncValueView(
                value: contacts,
                isEmpty: (list) => list.isEmpty,
                emptyMessage: filtreActif ? l10n.contactsNoResult : l10n.contactsEmpty,
                onRetry: () => ref.invalidate(contactsProvider),
                data: (list) => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => _ContactTile(contact: list[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarreRecherche extends ConsumerStatefulWidget {
  const _BarreRecherche();

  @override
  ConsumerState<_BarreRecherche> createState() => _BarreRechercheState();
}

class _BarreRechercheState extends ConsumerState<_BarreRecherche> {
  late final _controller = TextEditingController(text: ref.read(filtreContactsProvider).recherche);
  Timer? _delai;

  @override
  void dispose() {
    _delai?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _surSaisie(String texte) {
    _delai?.cancel();
    _delai = Timer(const Duration(milliseconds: 250),
        () => ref.read(filtreContactsProvider.notifier).rechercher(texte));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filtre = ref.watch(filtreContactsProvider);
    final notifier = ref.read(filtreContactsProvider.notifier);
    final stats = ref.watch(statsCarnetContactsProvider).value ?? const StatsCarnetContacts();

    Widget puce({
      required String label,
      required RelationContact? relation,
      required IconData icon,
      required Color color,
      int? count,
    }) {
      final isSelected = filtre.relation == relation;
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
        child: ChoiceChip(
          avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : color),
          label: Text(label),
          selected: isSelected,
          onSelected: (_) => notifier.relation(relation),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('contacts-search'),
            controller: _controller,
            onChanged: _surSaisie,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.contactsSearchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l10n.commonClear,
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _controller.clear();
                        _surSaisie('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // 1. Tous les contacts
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                  child: ChoiceChip(
                    avatar: const Icon(Icons.people_alt_outlined, size: 16),
                    label: Text(l10n.contactsFilterAll),
                    selected: filtre.relation == null,
                    onSelected: (_) => notifier.relation(null),
                  ),
                ),
                // 2. Clients
                puce(
                  label: l10n.relationContact(RelationContact.client),
                  relation: RelationContact.client,
                  icon: Icons.person_pin_circle_outlined,
                  color: AppColors.green,
                  count: stats.clients,
                ),
                // 3. Fournisseurs
                puce(
                  label: l10n.relationContact(RelationContact.fournisseur),
                  relation: RelationContact.fournisseur,
                  icon: Icons.local_shipping_outlined,
                  color: const Color(0xFF3730A3),
                  count: stats.fournisseurs,
                ),
                // 4. Locataires
                puce(
                  label: l10n.relationContact(RelationContact.locataire),
                  relation: RelationContact.locataire,
                  icon: Icons.vpn_key_outlined,
                  color: const Color(0xFF6B21A8),
                  count: stats.locataires,
                ),
                // 5. Propriétaires
                puce(
                  label: l10n.relationContact(RelationContact.proprietaire),
                  relation: RelationContact.proprietaire,
                  icon: Icons.home_work_outlined,
                  color: const Color(0xFF92400E),
                  count: stats.proprietaires,
                ),
                // 6. Prestataires
                puce(
                  label: l10n.relationContact(RelationContact.prestataire),
                  relation: RelationContact.prestataire,
                  icon: Icons.handyman_outlined,
                  color: const Color(0xFF115E59),
                  count: stats.prestataires,
                ),
                // 7. Archivés
                FilterChip(
                  key: const Key('contacts-archived'),
                  avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: Text(l10n.contactsShowArchived),
                  selected: filtre.inclureArchives,
                  onSelected: notifier.archives,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact});
  final Contact contact;

  Future<void> _lancer(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.contactActionUnavailable)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final c = contact;
    final sortedRelations = c.relations.toList()..sort((a, b) => a.index.compareTo(b.index));

    final details = [
      ...sortedRelations.map(l10n.relationContact),
      if (c.telephone != null) c.telephone!,
      if (c.ville != null) c.ville!,
    ].join(' · ');

    final telNettoye = c.telephone?.replaceAll(' ', '');
    final waChiffres = chiffresSeuls(c.whatsapp ?? c.telephone);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1.1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(Routes.contact(c.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ligne 1 : Avatar + Nom + Organisation/Type + Synchronisation
              Row(
                children: [
                  ContactAvatar(contact: c, radius: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                c.nomAffiche,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15.5,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                            if (c.estArchive) ...[
                              const SizedBox(width: 6),
                              _Etiquette(l10n.contactArchived, color: AppColors.muted, bg: AppColors.border),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          details.isEmpty ? (c.typePersonne == TypePersonne.organisation ? 'Organisation' : 'Particulier') : details,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RecordSyncBadge(status: c.syncStatus),
                ],
              ),

              // Ligne 2 : Badges colorés de relations + Actions rapides Téléphone / WhatsApp
              const SizedBox(height: 10),
              Row(
                children: [
                  // Badges de relations
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final r in sortedRelations)
                          _BadgeRelation(relation: r, label: l10n.relationContact(r)),
                      ],
                    ),
                  ),

                  // Actions rapides directes sur la carte
                  if (telNettoye != null && telNettoye.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.call_outlined, size: 20),
                      style: IconButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.green,
                        backgroundColor: AppColors.greenSoft,
                      ),
                      tooltip: '${l10n.contactCall} (${c.telephone})',
                      onPressed: () => _lancer(context, Uri(scheme: 'tel', path: telNettoye)),
                    ),
                  ],
                  if (waChiffres.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19),
                      style: IconButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: const Color(0xFF059669),
                        backgroundColor: const Color(0xFFD1FAE5),
                      ),
                      tooltip: 'WhatsApp ($waChiffres)',
                      onPressed: () => _lancer(context, Uri.parse('https://wa.me/$waChiffres')),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeRelation extends StatelessWidget {
  const _BadgeRelation({required this.relation, required this.label});
  final RelationContact relation;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (bg, border, text, icon) = switch (relation) {
      RelationContact.client => (
          const Color(0xFFECFDF5),
          const Color(0xFFA7F3D0),
          const Color(0xFF065F46),
          Icons.person_pin_circle_outlined,
        ),
      RelationContact.fournisseur => (
          const Color(0xFFEEF2FF),
          const Color(0xFFC7D2FE),
          const Color(0xFF3730A3),
          Icons.local_shipping_outlined,
        ),
      RelationContact.locataire => (
          const Color(0xFFF5F3FF),
          const Color(0xFFDDD6FE),
          const Color(0xFF5B21B6),
          Icons.vpn_key_outlined,
        ),
      RelationContact.proprietaire => (
          const Color(0xFFFFFBEB),
          const Color(0xFFFDE68A),
          const Color(0xFF92400E),
          Icons.home_work_outlined,
        ),
      RelationContact.prestataire => (
          const Color(0xFFF0FDFA),
          const Color(0xFF99F6E4),
          const Color(0xFF115E59),
          Icons.handyman_outlined,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: text),
          ),
        ],
      ),
    );
  }
}

class _Etiquette extends StatelessWidget {
  const _Etiquette(this.texte, {this.color, this.bg});
  final String texte;
  final Color? color;
  final Color? bg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: bg ?? AppColors.border, borderRadius: BorderRadius.circular(6)),
        child: Text(texte, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color ?? AppColors.muted)),
      );
}
