import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/config_providers.dart';
import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/permissions/access_decision.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../authentication/presentation/widgets/auth_form_scaffold.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../perimetres/domain/entities/perimetre.dart';
import '../../../perimetres/presentation/providers/perimetres_providers.dart';
import '../../domain/entities/invitation.dart';
import '../providers/invitations_providers.dart';

/// Administrateur → Inviter : e-mail, rôle (parmi ceux du plan), périmètres.
Future<void> showInviterSheet(BuildContext context) async {
  final creee = await showModalBottomSheet<(String, InvitationCreee)>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => const _InviterForm(),
  );
  if (creee != null && context.mounted) {
    await showDialog<void>(
      context: context,
      builder: (_) => InvitationCreeeDialog(email: creee.$1, invitation: creee.$2),
    );
  }
}

class _InviterForm extends ConsumerStatefulWidget {
  const _InviterForm();

  @override
  ConsumerState<_InviterForm> createState() => _InviterFormState();
}

class _InviterFormState extends ConsumerState<_InviterForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  String? _role;
  final Set<String> _perimetres = {};
  bool _envoi = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit(List<Perimetre> tous) async {
    if (!_formKey.currentState!.validate() || _role == null) return;
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    setState(() => _envoi = true);
    try {
      final creee = await ref.read(creerInvitationProvider).call(
            ctx,
            email: _email.text,
            roleCode: _role!,
            perimetres: tous.where((p) => _perimetres.contains(p.id)).toList(),
          );
      ref.invalidate(invitationsProvider);
      if (mounted) Navigator.of(context).pop((_email.text.trim().toLowerCase(), creee));
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ctx = ref.watch(contexteActifProvider);
    if (ctx == null) return const SizedBox.shrink();
    final usecase = ref.watch(creerInvitationProvider);
    final roles = usecase.rolesProposables(ctx);
    final perimetres = ref.watch(perimetresProvider).value ?? const <Perimetre>[];
    final requis = _role != null && usecase.perimetresRequis(ctx, _role!);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.inviteTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('invite-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l10n.authEmail),
                validator: (v) => AuthValidators.email(v,
                    required: l10n.validationRequired, invalid: l10n.validationEmail),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.inviteRole, style: Theme.of(context).textTheme.titleSmall),
              if (roles.isEmpty) Text(l10n.inviteNoRole),
              // Seuls les rôles du plan sont proposés ; un rôle bloqué affiche sa raison.
              for (final e in roles.entries)
                ListTile(
                  key: ValueKey('invite-role-${e.key}'),
                  contentPadding: EdgeInsets.zero,
                  enabled: e.value.isAllowed,
                  leading: Icon(_role == e.key ? Icons.radio_button_checked : Icons.radio_button_off),
                  title: Text(l10n.role(e.key)),
                  subtitle: e.value is AccessDenied ? Text(l10n.decision(e.value as AccessDenied)) : null,
                  onTap: () => setState(() {
                    _role = e.key;
                    _perimetres.clear();
                  }),
                ),
              if (requis) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.invitePerimetres, style: Theme.of(context).textTheme.titleSmall),
                for (final p in perimetres)
                  Builder(builder: (_) {
                    final decision = usecase.peutAffecter(ctx, _role!, p);
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _perimetres.contains(p.id),
                      title: Text(p.nom),
                      subtitle: decision is AccessDenied
                          ? Text(l10n.decision(decision))
                          : Text(l10n.activite(p.activite)),
                      onChanged: decision.isAllowed
                          ? (v) => setState(() => v! ? _perimetres.add(p.id) : _perimetres.remove(p.id))
                          : null,
                    );
                  }),
              ],
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                key: const Key('invite-submit'),
                onPressed: _envoi || _role == null || (requis && _perimetres.isEmpty)
                    ? null
                    : () => _submit(perimetres),
                child: Text(l10n.inviteSend),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le jeton n'est affiché qu'une fois, juste après la création.
class InvitationCreeeDialog extends ConsumerWidget {
  const InvitationCreeeDialog({super.key, required this.email, required this.invitation});
  final String email;
  final InvitationCreee invitation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lien = ref.watch(appConfigProvider).invitationLink(invitation.token);

    Future<void> copier(String valeur) async {
      await Clipboard.setData(ClipboardData(text: valeur));
      if (context.mounted) showMessageSnackBar(context, l10n.inviteCopied);
    }

    return AlertDialog(
      title: Text(l10n.inviteCreatedTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.inviteCreatedMessage(email, l10n.date(invitation.expiresAt))),
          const SizedBox(height: AppSpacing.md),
          SelectableText(lien, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [
        TextButton(onPressed: () => copier(invitation.token), child: Text(l10n.inviteCopyCode)),
        FilledButton(onPressed: () => copier(lien), child: Text(l10n.inviteCopyLink)),
      ],
    );
  }
}
