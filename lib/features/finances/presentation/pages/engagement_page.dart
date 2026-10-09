import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../agenda/domain/entities/agenda.dart';
import '../../../agenda/presentation/widgets/bouton_relance.dart';
import '../../../fichiers/presentation/section_notes_pieces.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/finances.dart';
import '../../domain/services/etat_finances.dart';
import '../providers/finances_providers.dart';
import '../widgets/finances_widgets.dart';

/// Fiche d'une somme à recevoir / à payer : reste dû, paiements reçus,
/// actions (encaisser, modifier, annuler).
class EngagementPage extends ConsumerWidget {
  const EngagementPage({super.key, required this.engagementId});
  final String engagementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final etat = ref.watch(etatFinancesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.debtDetailTitle), actions: const [SyncStatusButton()]),
      body: ResponsiveBody(
        child: AsyncValueView(
          value: etat,
          onRetry: () => ref.invalidate(etatFinancesProvider),
          isEmpty: (e) => !e.engagements.any((x) => x.id == engagementId),
          emptyMessage: l10n.financeNotFound,
          data: (e) => _Fiche(etat: e, suivi: e.suivi(e.engagements.firstWhere((x) => x.id == engagementId))),
        ),
      ),
    );
  }
}

class _Fiche extends ConsumerWidget {
  const _Fiche({required this.etat, required this.suivi});
  final EtatFinances etat;
  final EngagementSuivi suivi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final droits = ref.watch(droitsFinancesProvider);
    final contacts = ref.watch(contactsParIdProvider).value ?? const {};
    final e = suivi.engagement;
    final recevoir = e.sens == SensEngagement.aRecevoir;
    final paiements = [
      for (final p in etat.paiementsSuivis)
        for (final a in p.paiement.affectations)
          if (a.engagementId == e.id) (suivi: p, part: a.montant),
    ];
    final progression = e.montantTotal == 0 ? 0.0 : suivi.regle / e.montantTotal;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        EcritureRefuseeBanniere(
          status: e.syncStatus,
          onRetirer: e.version == null
              ? () async {
                  await ref.read(retirerEcritureProvider).call('engagements', e.id);
                  if (context.mounted) context.pop();
                }
              : null,
        ),
        Text(
          recevoir ? l10n.financeToReceive : l10n.financeToPay,
          style: theme.textTheme.labelLarge?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 4),
        Text(e.libelle, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        if (e.contactId != null)
          TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: AlignmentDirectional.centerStart),
            onPressed: contacts[e.contactId] == null ? null : () => context.push(Routes.contact(e.contactId!)),
            icon: const Icon(Icons.person_outline, size: 18),
            label: Text(contacts[e.contactId]?.nomAffiche ?? '…'),
          ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(l10n.debtRemaining, style: theme.textTheme.bodyMedium)),
                    EtatReglementChip(etat: suivi.etat(DateTime.now()), sens: e.sens),
                  ],
                ),
                const SizedBox(height: 4),
                Montant(suivi.reste, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progression.clamp(0, 1),
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    color: AppColors.green,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(child: _Info(l10n.debtPaid, Montant(suivi.regle))),
                    Expanded(child: _Info(l10n.debtTotal, Montant(e.montantTotal))),
                  ],
                ),
                const Divider(height: AppSpacing.lg),
                _Info(l10n.debtDate, Text(l10n.date(e.dateEngagement))),
                if (e.echeance != null) _Info(l10n.debtDueDate, Text(l10n.date(e.echeance!))),
                if (e.annule && e.motifAnnulation != null) _Info(l10n.debtCancelReason, Text(e.motifAnnulation!)),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!e.annule && suivi.reste > 0 && (recevoir ? droits.encaisser : droits.decaisser))
          FilledButton.icon(
            key: const Key('engagement-regler'),
            onPressed: () => context.push(Routes.paiementNouveau(engagementId: e.id)),
            icon: Icon(recevoir ? Icons.south_west : Icons.north_east),
            label: Text(recevoir ? l10n.debtCollect : l10n.debtPay),
          ),
        if (!e.annule && suivi.reste > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          BoutonRelance(
            cibleType: CibleType.engagement,
            cibleId: e.id,
            titre: l10n.agendaFollowUpTitle(contacts[e.contactId]?.nomAffiche ?? e.libelle),
          ),
        ],
        if (e.origineType == 'DEPENSE') ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            key: const Key('engagement-voir-depense'),
            onPressed: () => context.push(Routes.depense(e.id)),
            icon: const Icon(Icons.receipt_long_outlined),
            label: Text(l10n.debtOpenExpense),
          ),
        ],
        if (!e.annule && !e.lie && droits.gererCreances) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('engagement-modifier'),
                  onPressed: () => context.push(Routes.engagementModifier(e.id)),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l10n.commonEdit),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('engagement-annuler'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.negative),
                  onPressed: () => _annuler(context, ref),
                  icon: const Icon(Icons.block),
                  label: Text(l10n.debtCancel),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.debtPayments, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        if (paiements.isEmpty)
          Text(l10n.debtNoPayment, style: const TextStyle(color: AppColors.muted))
        else
          Card(
            child: Column(
              children: [
                for (final (:suivi, :part) in paiements)
                  ListTile(
                    title: Text(l10n.modePaiement(suivi.paiement.mode)),
                    subtitle: Text(
                      [l10n.dateTime(suivi.paiement.datePaiement), if (suivi.annule) l10n.paymentCancelled].join(' · '),
                    ),
                    trailing: Montant(part, barre: suivi.annule || suivi.paiement.refuse),
                    onTap: () => context.push(Routes.paiement(suivi.paiement.id)),
                  ),
              ],
            ),
          ),
        // La somme liée à une dépense porte ses justificatifs sur la dépense.
        if (!e.lie && !e.refuse) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionNotesPieces(type: CibleType.engagement, cibleId: e.id),
        ],
      ],
    );
  }

  Future<void> _annuler(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    final motif = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.debtCancelTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.debtCancelMessage),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: motif,
              maxLength: 500,
              decoration: InputDecoration(labelText: l10n.debtCancelReason),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l10n.commonCancel)),
          FilledButton(
            key: const Key('engagement-annuler-confirmer'),
            onPressed: () => Navigator.pop(d, true),
            child: Text(l10n.debtCancel),
          ),
        ],
      ),
    );
    final texte = motif.text;
    motif.dispose();
    if (ok != true) return;
    try {
      await ref.read(modifierEngagementProvider).annuler(ctx, suivi, motif: texte);
    } catch (e) {
      if (context.mounted) showFailureSnackBar(context, e);
    }
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.valeur);
  final String label;
  final Widget valeur;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
        valeur,
      ],
    ),
  );
}
