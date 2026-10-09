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
import '../../../documents/domain/entities/document.dart';
import '../../../fichiers/presentation/section_notes_pieces.dart';
import '../../../documents/presentation/providers/documents_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/finances.dart';
import '../../domain/services/etat_finances.dart';
import '../providers/finances_providers.dart';
import '../widgets/finances_widgets.dart';

/// Détail d'un paiement : jamais modifiable ; annulable par un paiement inverse.
class PaiementPage extends ConsumerWidget {
  const PaiementPage({super.key, required this.paiementId});
  final String paiementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.paymentDetailTitle), actions: const [SyncStatusButton()]),
      body: ResponsiveBody(
        child: AsyncValueView(
          value: ref.watch(etatFinancesProvider),
          onRetry: () => ref.invalidate(etatFinancesProvider),
          isEmpty: (e) => e.paiement(paiementId) == null,
          emptyMessage: l10n.financeNotFound,
          data: (e) => _Detail(etat: e, paiement: e.paiement(paiementId)!),
        ),
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.etat, required this.paiement});
  final EtatFinances etat;
  final Paiement paiement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final droits = ref.watch(droitsFinancesProvider);
    final contacts = ref.watch(contactsParIdProvider).value ?? const {};
    final p = paiement;
    final annule = etat.estAnnule(p);
    final annulation = etat.paiements.where((x) => x.annulePaiementId == p.id && !x.refuse).firstOrNull;
    final caisse = p.sessionId == null
        ? null
        : etat.caisses
              .where((c) => c.id == etat.sessions.where((s) => s.id == p.sessionId).firstOrNull?.caisseId)
              .firstOrNull;
    final entree = p.sens == SensPaiement.entree;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        EcritureRefuseeBanniere(
          status: p.syncStatus,
          onRetirer: p.version == null
              ? () async {
                  await ref.read(retirerEcritureProvider).call('paiements', p.id);
                  if (context.mounted) context.pop();
                }
              : null,
        ),
        Center(
          child: Column(
            children: [
              Text(
                p.estAnnulation ? l10n.paymentCancellation : (entree ? l10n.paymentIn : l10n.paymentOut),
                style: theme.textTheme.labelLarge?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 4),
              Montant(
                p.montant,
                signe: entree,
                barre: annule || p.refuse,
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (annule)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.paymentCancelled,
                    style: const TextStyle(color: AppColors.negative, fontWeight: FontWeight.w700),
                  ),
                ),
              if (p.enAttente)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(l10n.financePendingSync, style: const TextStyle(color: AppColors.warning)),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Column(
            children: [
              _Ligne(Icons.event_outlined, l10n.paymentDate, l10n.dateTime(p.datePaiement)),
              _Ligne(Icons.account_balance_wallet_outlined, l10n.paymentMode, l10n.modePaiement(p.mode)),
              if (p.contactId != null)
                _Ligne(
                  Icons.person_outline,
                  entree ? l10n.paymentFrom : l10n.paymentTo,
                  contacts[p.contactId]?.nomAffiche ?? '…',
                  onTap: contacts[p.contactId] == null ? null : () => context.push(Routes.contact(p.contactId!)),
                ),
              if (caisse != null) _Ligne(Icons.point_of_sale_outlined, l10n.paymentCashRegister, caisse.nom),
              if (p.reference != null) _Ligne(Icons.tag, l10n.paymentReference, p.reference!),
              if (p.note != null) _Ligne(Icons.notes_outlined, l10n.paymentNote, p.note!),
              if (p.estAnnulation)
                _Ligne(
                  Icons.undo,
                  l10n.paymentCancelsPayment,
                  l10n.paymentOpenOriginal,
                  onTap: () => context.push(Routes.paiement(p.annulePaiementId!)),
                ),
              if (annulation != null)
                _Ligne(
                  Icons.undo,
                  l10n.paymentCancelledBy,
                  l10n.dateTime(annulation.datePaiement),
                  onTap: () => context.push(Routes.paiement(annulation.id)),
                ),
            ],
          ),
        ),
        if (p.affectations.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            entree ? l10n.paymentSettlesReceivables : l10n.paymentSettlesPayables,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                for (final a in p.affectations)
                  ListTile(
                    title: Text(etat.engagements.where((e) => e.id == a.engagementId).firstOrNull?.libelle ?? '…'),
                    trailing: Montant(a.montant, barre: annule),
                    onTap: () => context.push(Routes.engagement(a.engagementId)),
                  ),
              ],
            ),
          ),
        ],
        if (entree && !p.estAnnulation && !p.refuse) _BoutonRecu(etat: etat, paiement: p, annule: annule),
        if (droits.annulerPaiements && !annule && !p.estAnnulation && !p.refuse) ...[
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            key: const Key('paiement-annuler'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.negative),
            onPressed: () => _annuler(context, ref),
            icon: const Icon(Icons.undo),
            label: Text(l10n.paymentCancel),
          ),
          const SizedBox(height: 4),
          Text(l10n.paymentCancelHint, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted)),
        ],
        if (!p.refuse && !p.estAnnulation) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionNotesPieces(type: CibleType.paiement, cibleId: p.id),
        ],
      ],
    );
  }

  Future<void> _annuler(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.paymentCancelTitle),
        content: Text(l10n.paymentCancelMessage(l10n.montant(paiement.montant, ref.read(deviseProvider)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l10n.commonCancel)),
          FilledButton(
            key: const Key('paiement-annuler-confirmer'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            onPressed: () => Navigator.pop(d, true),
            child: Text(l10n.paymentCancel),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(annulerPaiementProvider).call(ctx, etat, paiement);
    } catch (e) {
      if (context.mounted) showFailureSnackBar(context, e);
    }
  }
}

/// Reçu du paiement : ouvrir celui qui existe, ou l'émettre (numéroté,
/// hors-ligne compris grâce aux numéros réservés par l'appareil).
class _BoutonRecu extends ConsumerStatefulWidget {
  const _BoutonRecu({required this.etat, required this.paiement, required this.annule});
  final EtatFinances etat;
  final Paiement paiement;
  final bool annule;

  @override
  ConsumerState<_BoutonRecu> createState() => _BoutonRecuState();
}

class _BoutonRecuState extends ConsumerState<_BoutonRecu> {
  bool _enCours = false;

  Future<void> _emettre() async {
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    setState(() => _enCours = true);
    try {
      final profil = await ref.read(profilEntrepriseProvider.future).catchError((_) => null);
      final document = await ref
          .read(emettreRecuProvider)
          .call(
            ctx,
            etat: widget.etat,
            paiement: widget.paiement,
            existants: ref.read(documentsProvider).value ?? const [],
            appareilId: ref.read(appareilIdProvider),
            profil: profil,
            contact: ref.read(contactsParIdProvider).value?[widget.paiement.contactId],
            emisPar: ctx.nomComplet,
          );
      if (mounted) await context.push(Routes.document(document.id));
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final droits = ref.watch(droitsDocumentsProvider);
    final recu = (ref.watch(documentsProvider).value ?? const <Document>[])
        .where((d) => d.origineId == widget.paiement.id && d.type == TypeDocument.recu && !d.refuse)
        .firstOrNull;
    if (recu != null && droits.voir) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: FilledButton.tonalIcon(
          key: const Key('paiement-voir-recu'),
          onPressed: () => context.push(Routes.document(recu.id)),
          icon: const Icon(Icons.receipt_outlined),
          label: Text(l10n.docOpenReceipt(recu.numero)),
        ),
      );
    }
    if (!droits.creer || widget.annule) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: FilledButton.icon(
        key: const Key('paiement-emettre-recu'),
        onPressed: _enCours ? null : _emettre,
        icon: _enCours
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.receipt_long_outlined),
        label: Text(l10n.docIssueReceipt),
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne(this.icon, this.label, this.valeur, {this.onTap});
  final IconData icon;
  final String label;
  final String valeur;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: AppColors.green),
    title: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
    subtitle: Text(valeur, style: Theme.of(context).textTheme.bodyLarge),
    trailing: onTap == null ? null : const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
