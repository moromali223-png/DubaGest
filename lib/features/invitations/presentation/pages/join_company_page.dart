import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/language_selector.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../authentication/domain/entities/auth_state.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/invitation.dart';
import '../providers/invitations_providers.dart';

final _acceptationControllerProvider =
    NotifierProvider.autoDispose<FormActionController, AsyncValue<void>>(FormActionController.new);

/// Rejoindre une entreprise avec une invitation (lien ou code).
/// Le rôle et les périmètres sont ceux de l'invitation : l'invité ne choisit rien.
class JoinCompanyPage extends ConsumerStatefulWidget {
  const JoinCompanyPage({super.key, this.tokenFromLink});
  final String? tokenFromLink;

  @override
  ConsumerState<JoinCompanyPage> createState() => _JoinCompanyPageState();
}

class _JoinCompanyPageState extends ConsumerState<JoinCompanyPage> {
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Le jeton du lien est conservé pour reprendre après connexion/inscription.
    final fromLink = widget.tokenFromLink;
    if (fromLink != null && fromLink.isNotEmpty) {
      Future.microtask(() => ref.read(invitationEnAttenteProvider.notifier).memoriser(fromLink));
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _accepter(String token) async {
    final accepter = ref.read(accepterInvitationProvider);
    final ok = await ref.read(_acceptationControllerProvider.notifier).run(() => accepter(token));
    if (!ok) return;
    ref.invalidate(invitationEnAttenteProvider);
    await ref.read(contexteSessionProvider.notifier).rafraichir();
    if (mounted) context.go(Routes.home);
  }

  Future<void> _ignorer() async {
    await ref.read(invitationEnAttenteProvider.notifier).oublier();
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final connecte = ref.watch(authStateProvider).value is Authenticated;
    final rawToken = (widget.tokenFromLink?.isNotEmpty ?? false)
        ? widget.tokenFromLink
        : ref.watch(invitationEnAttenteProvider);
    final token = rawToken?.trim().isNotEmpty == true ? rawToken!.trim() : null;
    ref.listen(_acceptationControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) showFailureSnackBar(context, error);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.onboardingJoinTitle),
        actions: const [LanguageMenuButton()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: token == null
                  ? _SaisieCode(
                      controller: _code,
                      onSubmit: () => ref.read(invitationEnAttenteProvider.notifier).memoriser(_code.text),
                    )
                  : _Apercu(
                      token: token,
                      connecte: connecte,
                      enCours: ref.watch(_acceptationControllerProvider).isLoading,
                      onAccepter: () => _accepter(token),
                      onIgnorer: _ignorer,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SaisieCode extends StatelessWidget {
  const _SaisieCode({required this.controller, required this.onSubmit});
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.joinCodeHelp),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const Key('join-code'),
          controller: controller,
          decoration: InputDecoration(labelText: l10n.joinCodeLabel),
          onSubmitted: (_) => onSubmit(),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(onPressed: onSubmit, child: Text(l10n.joinCheck)),
      ],
    );
  }
}

class _Apercu extends ConsumerWidget {
  const _Apercu({
    required this.token,
    required this.connecte,
    required this.enCours,
    required this.onAccepter,
    required this.onIgnorer,
  });

  final String token;
  final bool connecte;
  final bool enCours;
  final VoidCallback onAccepter;
  final VoidCallback onIgnorer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final apercu = ref.watch(apercuInvitationProvider(token));

    return AsyncValueView<InvitationApercu>(
      value: apercu,
      onRetry: () => ref.invalidate(apercuInvitationProvider(token)),
      data: (inv) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(inv.acceptable ? Icons.mark_email_unread_outlined : Icons.link_off,
              size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.md),
          if (!inv.acceptable) ...[
            Text(l10n.invitationRefus(inv.statut),
                textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          ] else ...[
            Text(l10n.joinInvitedTo(inv.entrepriseNom ?? ''),
                textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.joinRole(l10n.role(inv.roleCode ?? '')), textAlign: TextAlign.center),
            if (inv.emailMasque != null)
              Text(l10n.joinForEmail(inv.emailMasque!), textAlign: TextAlign.center),
            if (inv.expiresAt != null)
              Text(l10n.joinExpires(l10n.date(inv.expiresAt!)),
                  textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.lg),
            if (connecte)
              FilledButton(
                key: const Key('join-accept'),
                onPressed: enCours ? null : onAccepter,
                child: enCours
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.joinAccept),
              )
            else ...[
              Text(l10n.joinSignInToAccept, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              FilledButton(onPressed: () => context.go(Routes.login), child: Text(l10n.authSignInLink)),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                  onPressed: () => context.go(Routes.register), child: Text(l10n.authRegisterLink)),
            ],
          ],
          const SizedBox(height: AppSpacing.sm),
          TextButton(onPressed: onIgnorer, child: Text(l10n.joinIgnore)),
        ],
      ),
    );
  }
}
