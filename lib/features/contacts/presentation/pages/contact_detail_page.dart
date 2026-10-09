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
import '../../../agenda/domain/entities/agenda.dart';
import '../../../agenda/presentation/widgets/bouton_relance.dart';
import '../../../fichiers/presentation/section_notes_pieces.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../finances/presentation/widgets/historique_contact.dart';
import '../../../services/presentation/widgets/historique_services_contact.dart';
import '../../domain/entities/contact.dart';
import '../providers/contacts_providers.dart';
import '../widgets/contact_avatar.dart';

/// Fiche contact : coordonnées, relations, actions rapides (appel, WhatsApp,
/// e-mail) et historique (alimenté par les modules financiers à venir).
class ContactDetailPage extends ConsumerWidget {
  const ContactDetailPage({super.key, required this.contactId});
  final String contactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final contact = ref.watch(contactProvider(contactId));
    final droits = ref.watch(droitsContactsProvider);
    final c = contact.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.contactDetailTitle),
        actions: [
          if (c != null && droits.modifier)
            IconButton(
              key: const Key('contact-edit'),
              tooltip: l10n.contactEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(Routes.contactEdit(c.id)),
            ),
          if (c != null && droits.archiver)
            PopupMenuButton<void>(
              itemBuilder: (_) => [
                PopupMenuItem(
                  key: const Key('contact-archive'),
                  onTap: () => _archiver(context, ref, c),
                  child: Text(c.estArchive ? l10n.contactRestore : l10n.contactArchive),
                ),
              ],
            ),
          const SyncStatusButton(),
        ],
      ),
      body: ResponsiveBody(
        child: AsyncValueView(
          value: contact,
          isEmpty: (c) => c == null,
          emptyMessage: l10n.contactNotFound,
          onRetry: () => ref.invalidate(contactProvider(contactId)),
          data: (c) => _Fiche(contact: c!),
        ),
      ),
    );
  }

  Future<void> _archiver(BuildContext context, WidgetRef ref, Contact c) async {
    final l10n = context.l10n;
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    final archiver = !c.estArchive;
    if (archiver) {
      final confirme = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.contactArchiveTitle),
          content: Text(l10n.contactArchiveMessage(c.nomAffiche)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.commonCancel)),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.contactArchive)),
          ],
        ),
      );
      if (confirme != true) return;
    }
    try {
      await ref.read(archiverContactProvider).call(ctx, c, archiver: archiver);
    } catch (e) {
      if (context.mounted) showFailureSnackBar(context, e);
    }
  }
}

class _Fiche extends StatelessWidget {
  const _Fiche({required this.contact});
  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final c = contact;
    final relations = c.relations.toList()..sort((a, b) => a.index.compareTo(b.index));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Row(
          children: [
            ContactAvatar(contact: c, radius: 30),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.nomAffiche, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  Text(
                    [
                      c.typePersonne == TypePersonne.personne ? l10n.contactTypePersonne : l10n.contactTypeOrganisation,
                      if (c.estArchive) l10n.contactArchived,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            RecordSyncBadge(status: c.syncStatus),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: relations.isEmpty
              ? [Text(l10n.contactRelationsNone, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted))]
              : [for (final r in relations) Chip(label: Text(l10n.relationContact(r)))],
        ),
        const SizedBox(height: AppSpacing.md),
        _ActionsRapides(contact: c),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: BoutonRelance(
            cibleType: CibleType.contact,
            cibleId: c.id,
            titre: l10n.agendaFollowUpTitle(c.nomAffiche),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Column(
            children: [
              _Ligne(Icons.phone_outlined, l10n.contactFieldTelephone, c.telephone),
              _Ligne(Icons.chat_outlined, l10n.contactFieldWhatsapp, c.whatsapp),
              _Ligne(Icons.mail_outline, l10n.contactFieldEmail, c.email),
              _Ligne(Icons.location_on_outlined, l10n.contactFieldAdresse,
                  [c.adresse, c.ville].whereType<String>().join(', ')),
              _Ligne(Icons.notes_outlined, l10n.contactFieldRemarque, c.remarque),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Prestations & Services du client
        HistoriqueServicesContact(contactId: c.id),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.contactHistoryTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        // Données réelles : créances, dettes et paiements de ce contact.
        HistoriqueFinancierContact(contactId: c.id),
        const SizedBox(height: AppSpacing.lg),
        SectionNotesPieces(type: CibleType.contact, cibleId: c.id),
      ],
    );
  }
}

class _ActionsRapides extends StatelessWidget {
  const _ActionsRapides({required this.contact});
  final Contact contact;

  Future<void> _ouvrir(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && context.mounted) showMessageSnackBar(context, context.l10n.contactActionUnavailable);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = contact;
    final whatsapp = chiffresSeuls(c.whatsapp ?? c.telephone);

    Widget action(Key key, IconData icon, String label, Uri? uri) => Expanded(
          child: OutlinedButton.icon(
            key: key,
            onPressed: uri == null ? null : () => _ouvrir(context, uri),
            icon: Icon(icon, size: 18),
            label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        );

    return Row(
      children: [
        action(const Key('contact-call'), Icons.call_outlined, l10n.contactCall,
            c.telephone == null ? null : Uri(scheme: 'tel', path: c.telephone!.replaceAll(' ', ''))),
        const SizedBox(width: AppSpacing.sm),
        action(const Key('contact-whatsapp'), Icons.chat_outlined, l10n.contactWhatsapp,
            whatsapp.length < 6 ? null : Uri.https('wa.me', '/$whatsapp')),
        const SizedBox(width: AppSpacing.sm),
        action(const Key('contact-mail'), Icons.mail_outline, l10n.contactEmailAction,
            c.email == null ? null : Uri(scheme: 'mailto', path: c.email)),
      ],
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne(this.icon, this.label, this.valeur);
  final IconData icon;
  final String label;
  final String? valeur;

  @override
  Widget build(BuildContext context) {
    final v = valeur?.trim();
    if (v == null || v.isEmpty) return const SizedBox.shrink();
    return ListTile(
      leading: Icon(icon, color: AppColors.green),
      title: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
      subtitle: SelectableText(v, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}
