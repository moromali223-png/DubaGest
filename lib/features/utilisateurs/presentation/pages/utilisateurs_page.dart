import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/permissions/access_decision.dart';
import '../../../../core/permissions/permission_codes.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../invitations/presentation/widgets/invitations_section.dart';
import '../../../invitations/presentation/widgets/inviter_sheet.dart';
import '../../domain/entities/membre.dart';
import '../providers/membres_providers.dart';
import '../widgets/affectations_sheet.dart';

class UtilisateursPage extends ConsumerWidget {
  const UtilisateursPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ctx = ref.watch(contexteActifProvider);
    final membres = ref.watch(membresProvider);
    if (ctx == null) return const Scaffold(body: LoadingView());

    final peutGerer = ctx.permissionEngine.has(PermissionCodes.usersManage);
    final peutInviter = ctx.permissionEngine.has(PermissionCodes.usersInvite);
    final limites = ctx.limites();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.moduleAdminUtilisateurs)),
      floatingActionButton: !peutInviter
          ? null
          : FloatingActionButton.extended(
              key: const Key('users-invite'),
              onPressed: () {
                final decision = ref.read(verifierAjoutMembreProvider).call(ctx);
                if (decision is AccessDenied) {
                  showMessageSnackBar(context, l10n.decision(decision));
                } else {
                  showInviterSheet(context);
                }
              },
              icon: const Icon(Icons.person_add_alt),
              label: Text(l10n.usersInvite),
            ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(membresProvider.future),
        child: ResponsiveBody(
          child: AsyncValueView(
            value: membres,
            isEmpty: (list) => list.isEmpty,
            emptyMessage: l10n.usersEmpty,
            onRetry: () => ref.invalidate(membresProvider),
            data: (list) => ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    '${l10n.subscriptionUsers} : '
                    '${l10n.usage(ctx.consommation.utilisateurs, limites.maxUtilisateurs)}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Card(
                  child: Column(
                    children: [
                      for (final m in list)
                        _MembreTile(
                          membre: m,
                          estMoi: m.userId == ctx.userId,
                          accesTous: ctx.roles[m.roleCode]?.accesTousPerimetres ?? false,
                          onTap: peutGerer ? () => showAffectationsSheet(context, m) : null,
                        ),
                    ],
                  ),
                ),
                if (peutInviter) const InvitationsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MembreTile extends StatelessWidget {
  const _MembreTile({
    required this.membre,
    required this.estMoi,
    required this.accesTous,
    this.onTap,
  });

  final Membre membre;
  final bool estMoi;
  final bool accesTous;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nom = membre.nomComplet ?? '—';
    final perimetres = accesTous
        ? l10n.usersAllPerimetres
        : membre.perimetreIds.isEmpty
            ? l10n.usersNoPerimetre
            : '${l10n.usersAssignments} : ${membre.perimetreIds.length}';
    return ListTile(
      leading: CircleAvatar(child: Text(nom.characters.first.toUpperCase())),
      title: Text(estMoi ? '$nom (${l10n.usersYou})' : nom),
      subtitle: Text('${l10n.role(membre.roleCode)} · $perimetres'
          '${membre.estActif ? '' : ' · ${l10n.commonInactive}'}'),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
