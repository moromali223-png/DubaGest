import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/app_header_buttons.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../finances/presentation/widgets/finances_widgets.dart';
import '../../../modules/domain/entities/app_module.dart';
import '../../domain/entities/agenda.dart';
import '../providers/agenda_providers.dart';
import 'agenda_page.dart';

/// Cloche de l'en-tête : notifications non lues + alertes en cours.
class ClocheNotifications extends ConsumerWidget {
  const ClocheNotifications({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(compteurNotificationsProvider);
    return IconButton(
      key: const Key('cloche-notifications'),
      style: headerIconButtonStyle(context),
      tooltip: context.l10n.notificationsTitle,
      onPressed: () => context.push(Routes.notifications),
      icon: Badge(
        isLabelVisible: n > 0,
        label: Text(n > 99 ? '99+' : '$n'),
        child: const Icon(Icons.notifications_none),
      ),
    );
  }
}

/// À traiter (alertes calculées sur les vraies données) puis messages reçus.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final alertes = ref.watch(alertesProvider);
    final notifications = ref.watch(notificationsProvider).value ?? const <NotificationApp>[];
    final devise = ref.watch(deviseProvider);

    Widget alerte(Alerte a) => switch (a) {
          AlerteEcheance(:final echeance, :final enRetard) => _Ligne(
              icone: iconeEcheance(echeance.type),
              danger: enRetard,
              titre: echeance.titre,
              sousTitre: '${enRetard ? l10n.notifOverdue : l10n.notifDueSoon} · '
                  '${l10n.date(echeance.dateHeure)} ${l10n.heure(echeance.dateHeure)}',
              onTap: () => context.push(Routes.echeance(echeance.id)),
            ),
          AlerteCreancesEnRetard(:final nombre, :final montant) => _Ligne(
              icone: Icons.request_page_outlined,
              danger: true,
              titre: l10n.notifDebtsOverdue(nombre),
              sousTitre: l10n.montant(montant, devise),
              onTap: () => context.go(Routes.financesOnglet(ModuleCodes.financesCreances)),
            ),
          AlerteCaisseOuverte(:final caisse, :final depuis) => _Ligne(
              icone: Icons.point_of_sale_outlined,
              danger: false,
              titre: l10n.notifCashOpenLong(caisse.nom),
              sousTitre: l10n.cashOpenSince(l10n.dateTime(depuis)),
              onTap: () => context.push(Routes.caisse(caisse.id)),
            ),
          AlerteEcrituresRefusees(:final nombre) => _Ligne(
              icone: Icons.block,
              danger: true,
              titre: l10n.notifRejected(nombre),
              sousTitre: l10n.notifRejectedHint,
              onTap: () => context.go(Routes.finances),
            ),
        };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        actions: [
          if (notifications.any((n) => !n.lue))
            TextButton(
              key: const Key('notifications-tout-lu'),
              onPressed: () async {
                final g = ref.read(gererEcheancesProvider);
                for (final n in notifications.where((n) => !n.lue)) {
                  await g.marquerLue(n);
                }
              },
              child: Text(l10n.notificationsMarkAllRead),
            ),
        ],
      ),
      body: ResponsiveBody(
        child: alertes.isEmpty && notifications.isEmpty
            ? EmptyView(icon: Icons.notifications_none, message: l10n.notificationsEmpty)
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  if (alertes.isNotEmpty) ...[
                    _Titre(l10n.notificationsToHandle),
                    Card(child: Column(children: [for (final a in alertes) alerte(a)])),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (notifications.isNotEmpty) ...[
                    _Titre(l10n.notificationsReceived),
                    Card(
                      child: Column(
                        children: [
                          for (final n in notifications)
                            _Ligne(
                              icone: n.type == TypeNotification.echeanceFaite ? Icons.task_alt : Icons.assignment_ind,
                              danger: false,
                              nonLue: !n.lue,
                              titre: switch (n.type) {
                                TypeNotification.echeanceConfiee => l10n.notifAssigned(n.auteurNom ?? '…'),
                                TypeNotification.echeanceFaite => l10n.notifDone(n.auteurNom ?? '…'),
                                null => l10n.errorUnknown,
                              },
                              sousTitre: '${n.parametres['titre'] ?? ''} · ${l10n.dateTime(n.createdAt)}',
                              onTap: () async {
                                await ref.read(gererEcheancesProvider).marquerLue(n);
                                if (n.cibleId != null && context.mounted) await context.push(Routes.echeance(n.cibleId!));
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpacing.sm),
        child: Text(texte, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
      );
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.icone,
    required this.danger,
    required this.titre,
    required this.sousTitre,
    this.onTap,
    this.nonLue = false,
  });

  final IconData icone;
  final bool danger;
  final bool nonLue;
  final String titre;
  final String sousTitre;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: danger ? AppColors.negativeSoft : AppColors.greenSoft,
          foregroundColor: danger ? AppColors.negative : AppColors.green,
          child: Icon(icone, size: 20),
        ),
        title: Text(titre, style: TextStyle(fontWeight: nonLue ? FontWeight.w800 : FontWeight.w500)),
        subtitle: Text(sousTitre),
        trailing: nonLue
            ? Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle))
            : null,
      );
}
