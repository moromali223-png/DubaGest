import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../domain/entities/contact.dart';
import '../providers/contacts_providers.dart';
import '../widgets/contact_avatar.dart';

/// Contacts de l'entreprise, toutes activités confondues. Recherche par nom,
/// téléphone, e-mail ou ville ; fonctionne hors-ligne.
class ContactsPage extends ConsumerWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final droits = ref.watch(droitsContactsProvider);
    final filtre = ref.watch(filtreContactsProvider);
    final contacts = ref.watch(contactsProvider);
    final filtreActif = filtre.recherche.trim().isNotEmpty || filtre.relation != null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.moduleCommunContacts), actions: const [SyncStatusButton()]),
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

    Widget puce(String label, RelationContact? relation) => Padding(
          padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
          child: ChoiceChip(
            label: Text(label),
            selected: filtre.relation == relation,
            onSelected: (_) => notifier.relation(relation),
          ),
        );

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
                puce(l10n.contactsFilterAll, null),
                for (final r in RelationContact.values) puce(l10n.relationContact(r), r),
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = contact;
    final details = [
      ...(c.relations.toList()..sort((a, b) => a.index.compareTo(b.index))).map(l10n.relationContact),
      if (c.telephone != null) c.telephone!,
      if (c.ville != null) c.ville!,
    ].join(' · ');

    return Card(
      child: ListTile(
        leading: ContactAvatar(contact: c),
        title: Row(
          children: [
            Flexible(child: Text(c.nomAffiche, maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (c.estArchive) ...[
              const SizedBox(width: AppSpacing.sm),
              _Etiquette(l10n.contactArchived),
            ],
          ],
        ),
        subtitle: details.isEmpty ? null : Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: RecordSyncBadge(status: c.syncStatus),
        onTap: () => context.push(Routes.contact(c.id)),
      ),
    );
  }
}

class _Etiquette extends StatelessWidget {
  const _Etiquette(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(6)),
        child: Text(texte, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.muted)),
      );
}
