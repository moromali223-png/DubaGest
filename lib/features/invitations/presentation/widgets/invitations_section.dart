import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/config_providers.dart';
import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../perimetres/domain/entities/perimetre.dart';
import '../../../perimetres/presentation/providers/perimetres_providers.dart';
import '../../domain/entities/invitation.dart';
import '../providers/invitations_providers.dart';
import 'inviter_sheet.dart';

/// Invitations récentes de l'entreprise, avec copie/régénération du lien et annulation.
class InvitationsSection extends ConsumerWidget {
  const InvitationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final invitations = ref.watch(invitationsProvider).value ?? const <Invitation>[];
    if (invitations.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();

    Future<void> copierEtRenvoyer(Invitation inv) async {
      final ctx = ref.read(contexteActifProvider);
      if (ctx == null) return;

      try {
        final tousPerimetres = ref.read(perimetresProvider).value ?? const <Perimetre>[];
        final perimetresDisponibles = tousPerimetres.isNotEmpty ? tousPerimetres : ctx.perimetres;
        final role = ctx.roles[inv.roleCode];
        final perimetresCompatibles = (role?.accesTousPerimetres ?? true)
            ? const <Perimetre>[]
            : (role?.activite != null
                ? perimetresDisponibles.where((p) => p.activite == role!.activite).toList()
                : perimetresDisponibles);

        final creee = await ref.read(creerInvitationProvider).call(
              ctx,
              email: inv.email,
              roleCode: inv.roleCode,
              perimetres: perimetresCompatibles,
            );
        final lien = ref.read(appConfigProvider).invitationLink(creee.token);
        await Clipboard.setData(ClipboardData(text: lien));

        if (context.mounted) {
          showMessageSnackBar(context, l10n.inviteCopied);
        }
        ref.invalidate(invitationsProvider);
      } catch (e) {
        if (context.mounted) showFailureSnackBar(context, e);
      }
    }

    Future<void> confirmerEtAnnuler(Invitation inv) async {
      final ctx = ref.read(contexteActifProvider);
      if (ctx == null) return;

      final confirmer = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Annuler l\'invitation ?'),
          content: Text(
            'Voulez-vous vraiment annuler l\'invitation envoyée à ${inv.email} ?\n'
            'Le lien d\'accès et le code seront immédiatement invalidés.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Retour'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Annuler l\'invitation'),
            ),
          ],
        ),
      );

      if (confirmer != true || !context.mounted) return;

      try {
        await ref.read(annulerInvitationProvider).call(ctx, inv);
        ref.invalidate(invitationsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invitation pour ${inv.email} annulée')),
          );
        }
      } catch (e) {
        if (context.mounted) showFailureSnackBar(context, e);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.outgoing_mail, size: 18, color: AppColors.green),
                const SizedBox(width: 8),
                Text(
                  l10n.invitationsTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (final (index, inv) in invitations.indexed)
                  Builder(builder: (_) {
                    final statut = inv.statutEffectif(now);
                    final estEnAttente = statut == InvitationStatut.pending;

                    Color badgeBg;
                    Color badgeText;
                    String badgeLabel;

                    switch (statut) {
                      case InvitationStatut.pending:
                        badgeBg = AppColors.warningSoft;
                        badgeText = AppColors.warning;
                        badgeLabel = 'En attente';
                        break;
                      case InvitationStatut.accepted:
                        badgeBg = AppColors.greenSoft;
                        badgeText = AppColors.green;
                        badgeLabel = 'Acceptée';
                        break;
                      case InvitationStatut.expired:
                        badgeBg = AppColors.negativeSoft;
                        badgeText = AppColors.negative;
                        badgeLabel = 'Expirée';
                        break;
                      case InvitationStatut.cancelled:
                      case InvitationStatut.invalid:
                        badgeBg = AppColors.border;
                        badgeText = AppColors.muted;
                        badgeLabel = 'Annulée';
                        break;
                    }

                    return Column(
                      children: [
                        if (index > 0) const Divider(height: 1),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.greenSoft,
                            child: const Icon(Icons.mail_outline_rounded, color: AppColors.green, size: 20),
                          ),
                          title: Text(
                            inv.email,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          subtitle: Row(
                            children: [
                              Text(
                                l10n.role(inv.roleCode),
                                style: const TextStyle(fontSize: 12, color: AppColors.muted),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  badgeLabel,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: badgeText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: estEnAttente
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      key: Key('btn-copy-invitation-${inv.id}'),
                                      tooltip: 'Copier / Renvoyer le lien d\'invitation',
                                      icon: const Icon(Icons.copy_rounded, color: AppColors.green, size: 20),
                                      onPressed: () => copierEtRenvoyer(inv),
                                    ),
                                    IconButton(
                                      key: Key('btn-cancel-invitation-${inv.id}'),
                                      tooltip: 'Annuler cette invitation',
                                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.negative, size: 20),
                                      onPressed: () => confirmerEtAnnuler(inv),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      ],
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
