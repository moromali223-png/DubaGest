import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../finances/domain/entities/finances.dart';
import '../../../finances/presentation/widgets/finances_widgets.dart';
import '../../domain/entities/agenda.dart';
import '../providers/agenda_providers.dart';

extension AgendaLabels on AppLocalizations {
  String typeEcheance(TypeEcheance t) => switch (t) {
        TypeEcheance.rappel => agendaTypeReminder,
        TypeEcheance.rendezVous => agendaTypeMeeting,
        TypeEcheance.tache => agendaTypeTask,
        TypeEcheance.relance => agendaTypeFollowUp,
      };

  String heure(DateTime d) {
    final l = d.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}

IconData iconeEcheance(TypeEcheance t) => switch (t) {
      TypeEcheance.rappel => Icons.alarm,
      TypeEcheance.rendezVous => Icons.event,
      TypeEcheance.tache => Icons.check_box_outlined,
      TypeEcheance.relance => Icons.phone_callback_outlined,
    };

/// Agenda : en retard, aujourd'hui, 7 prochains jours, plus tard. Les
/// échéances des sommes dues y figurent sans saisie.
class AgendaPage extends ConsumerWidget {
  const AgendaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final droits = ref.watch(droitsAgendaProvider);
    final mesTaches = ref.watch(mesTachesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.moduleCommunAgenda), actions: const [SyncStatusButton()]),
      floatingActionButton: !droits.gerer
          ? null
          : FloatingActionButton.extended(
              key: const Key('echeance-add'),
              onPressed: () => context.push(Routes.echeanceNouvelle()),
              icon: const Icon(Icons.add_alarm),
              label: Text(l10n.agendaNew),
            ),
      body: ResponsiveBody(
        child: AsyncValueView(
          value: ref.watch(agendaProvider),
          onRetry: () => ref.invalidate(echeancesProvider),
          data: (agenda) => ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilterChip(
                  key: const Key('agenda-mes-taches'),
                  avatar: const Icon(Icons.person_outline, size: 18),
                  label: Text(l10n.agendaMine),
                  selected: mesTaches,
                  onSelected: (_) => ref.read(mesTachesProvider.notifier).basculer(),
                ),
              ),
              if (agenda.vide)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  child: EmptyView(icon: Icons.event_available, message: l10n.agendaEmpty),
                ),
              _Section(titre: l10n.agendaOverdue, elements: agenda.enRetard, couleur: AppColors.negative),
              _Section(titre: l10n.agendaToday, elements: agenda.aujourdhui, couleur: AppColors.green),
              _Section(titre: l10n.agendaNextDays, elements: agenda.aVenir),
              _Section(titre: l10n.agendaLater, elements: agenda.plusTard),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.titre, required this.elements, this.couleur});
  final String titre;
  final List<ElementAgenda> elements;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    if (elements.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, AppSpacing.md, 4, AppSpacing.sm),
          child: Text('$titre · ${elements.length}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: couleur)),
        ),
        for (final e in elements)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: switch (e) {
              ElementEcheance(:final echeance) => EcheanceTile(echeance: echeance),
              ElementSommeDue(:final suivi) => _SommeDueTile(suivi: suivi),
            },
          ),
      ],
    );
  }
}

class EcheanceTile extends ConsumerWidget {
  const EcheanceTile({super.key, required this.echeance});
  final Echeance echeance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final e = echeance;
    final ctx = ref.watch(contexteActifProvider);
    final droits = ref.watch(droitsAgendaProvider);
    final peutCocher = droits.gerer || e.responsableId == ctx?.userId;
    return Card(
      child: ListTile(
        leading: Icon(iconeEcheance(e.type), color: AppColors.green),
        title: Text(e.titre, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text([
          '${l10n.date(e.dateHeure)} · ${l10n.heure(e.dateHeure)}',
          l10n.typeEcheance(e.type),
          if (e.responsableNom != null) l10n.agendaAssignedTo(e.responsableNom!),
          if (e.refusee) l10n.financeRejectedShort,
        ].join(' · ')),
        trailing: !peutCocher
            ? null
            : IconButton(
                key: Key('echeance-fait-${e.id}'),
                tooltip: l10n.agendaMarkDone,
                icon: const Icon(Icons.check_circle_outline),
                onPressed: () async {
                  try {
                    await ref.read(gererEcheancesProvider).changerStatut(ctx!, e, StatutEcheance.fait);
                  } catch (err) {
                    if (context.mounted) showFailureSnackBar(context, err);
                  }
                },
              ),
        onTap: () => context.push(Routes.echeance(e.id)),
      ),
    );
  }
}

class _SommeDueTile extends ConsumerWidget {
  const _SommeDueTile({required this.suivi});
  final EngagementSuivi suivi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final e = suivi.engagement;
    final recevoir = e.sens == SensEngagement.aRecevoir;
    final contact = ref.watch(contactsParIdProvider).value?[e.contactId];
    return Card(
      child: ListTile(
        leading: Icon(recevoir ? Icons.south_west : Icons.north_east,
            color: recevoir ? AppColors.positive : AppColors.negative),
        title: Text(contact?.nomAffiche ?? e.libelle, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text([
          recevoir ? l10n.agendaDueToReceive : l10n.agendaDueToPay,
          l10n.date(e.echeance!),
        ].join(' · ')),
        trailing: Montant(suivi.reste),
        onTap: () => context.push(Routes.engagement(e.id)),
      ),
    );
  }
}

/// Détail d'une échéance : fait / à refaire / annuler, modifier.
class EcheancePage extends ConsumerWidget {
  const EcheancePage({super.key, required this.echeanceId});
  final String echeanceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final echeances = ref.watch(echeancesProvider);
    final e = echeances.value?.where((x) => x.id == echeanceId).firstOrNull;
    final ctx = ref.watch(contexteActifProvider);
    final droits = ref.watch(droitsAgendaProvider);
    final contacts = ref.watch(contactsParIdProvider).value ?? const {};
    final contact = e?.cibleType == CibleType.contact ? contacts[e!.cibleId] : null;

    Future<void> statut(StatutEcheance s) async {
      try {
        await ref.read(gererEcheancesProvider).changerStatut(ctx!, e!, s);
      } catch (err) {
        if (context.mounted) showFailureSnackBar(context, err);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(e == null ? l10n.moduleCommunAgenda : l10n.typeEcheance(e.type)),
        actions: [
          if (e != null && droits.gerer && e.aFaire)
            IconButton(
              key: const Key('echeance-modifier'),
              tooltip: l10n.commonEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(Routes.echeanceModifier(e.id)),
            ),
          const SyncStatusButton(),
        ],
      ),
      body: e == null
          ? (echeances.isLoading ? const LoadingView() : EmptyView(message: l10n.financeNotFound))
          : ResponsiveBody(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  EcritureRefuseeBanniere(
                    status: e.syncStatus,
                    onRetirer: e.version == null
                        ? () async {
                            await ref.read(gererEcheancesProvider).retirerRefusee(e.id);
                            if (context.mounted) context.pop();
                          }
                        : null,
                  ),
                  Text(e.titre, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.event_outlined, color: AppColors.green),
                          title: Text('${l10n.date(e.dateHeure)} · ${l10n.heure(e.dateHeure)}'),
                          subtitle: e.rappelMinutes == null ? null : Text(l10n.agendaReminderBefore(l10n.delai(e.rappelMinutes!))),
                        ),
                        if (e.responsableNom != null)
                          ListTile(
                            leading: const Icon(Icons.person_outline, color: AppColors.green),
                            title: Text(l10n.agendaAssignedTo(e.responsableNom!)),
                          ),
                        if (contact != null)
                          ListTile(
                            leading: const Icon(Icons.contact_page_outlined, color: AppColors.green),
                            title: Text(contact.nomAffiche),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(Routes.contact(contact.id)),
                          ),
                        if (e.cibleType == CibleType.engagement)
                          ListTile(
                            leading: const Icon(Icons.request_page_outlined, color: AppColors.green),
                            title: Text(l10n.agendaOpenDebt),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(Routes.engagement(e.cibleId!)),
                          ),
                        if (e.note != null)
                          ListTile(
                            leading: const Icon(Icons.notes_outlined, color: AppColors.green),
                            title: Text(e.note!),
                          ),
                        ListTile(
                          leading: Icon(
                            e.aFaire ? Icons.radio_button_unchecked : Icons.check_circle,
                            color: e.aFaire ? AppColors.muted : AppColors.positive,
                          ),
                          title: Text(switch (e.statut) {
                            StatutEcheance.aFaire => l10n.agendaStatusTodo,
                            StatutEcheance.fait => l10n.agendaStatusDone,
                            StatutEcheance.annule => l10n.agendaStatusCancelled,
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (e.aFaire && (droits.gerer || e.responsableId == ctx?.userId))
                    FilledButton.icon(
                      key: const Key('echeance-marquer-fait'),
                      onPressed: () => statut(StatutEcheance.fait),
                      icon: const Icon(Icons.check),
                      label: Text(l10n.agendaMarkDone),
                    ),
                  if (!e.aFaire && droits.gerer)
                    OutlinedButton.icon(
                      onPressed: () => statut(StatutEcheance.aFaire),
                      icon: const Icon(Icons.undo),
                      label: Text(l10n.agendaReopen),
                    ),
                  if (e.aFaire && droits.gerer) ...[
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      key: const Key('echeance-annuler'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.negative),
                      onPressed: () => statut(StatutEcheance.annule),
                      icon: const Icon(Icons.block),
                      label: Text(l10n.agendaCancel),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
