import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/microfinance_enums.dart';
import '../../domain/entities/microfinance_models.dart';
import '../../domain/services/delinquency_analyzer.dart';
import '../pdf/microfinance_pdf_generator.dart';
import '../providers/microfinance_providers.dart';
import '../widgets/microfinance_shared_widgets.dart';
import '../widgets/repayment_form_sheet.dart';

/// Page de détail complet d'un prêt Microfinance :
/// synthèse financière, échéancier, encaissements, contre-passations, statuts et éditions PDF.
class LoanDetailPage extends ConsumerWidget {
  const LoanDetailPage({super.key, required this.loanId});

  final String loanId;

  Future<String?> _demanderMotif(
    BuildContext context, {
    required String titre,
    required String message,
    required String labelBouton,
    Color? couleurBouton,
  }) async {
    final ctrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(titre),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Motif obligatoire *',
                hintText: 'Ex. Erreur de saisie, rétractation...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop(), child: const Text('Fermer')),
          FilledButton(
            style: couleurBouton == null
                ? null
                : FilledButton.styleFrom(backgroundColor: couleurBouton),
            onPressed: () {
              final m = ctrl.text.trim();
              if (m.isEmpty) return;
              Navigator.of(dCtx).pop(m);
            },
            child: Text(labelBouton),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return res;
  }

  Future<void> _decaisserBrouillon(
    BuildContext context,
    WidgetRef ref, {
    required String entrepriseId,
    required MicrofinanceLoan loan,
    required String devise,
  }) async {
    var selectedMode = loan.modeDecaissement;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Activer et décaisser ce prêt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Montant accordé : ${l10n.montant(loan.montantAccorde, devise)}'),
              const SizedBox(height: 12),
              DropdownButtonFormField<ModePaiementMicrofinance>(
                initialValue: selectedMode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Mode de décaissement'),
                items: ModePaiementMicrofinance.values
                    .map((m) => DropdownMenuItem(value: m, child: Text(m.libelle(l10n.localeName))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setLocal(() => selectedMode = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: const Text('Annuler')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => Navigator.of(dCtx).pop(true),
              child: const Text('Confirmer l\'activation'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(microfinanceRepositoryProvider).decaisserBrouillon(
            entrepriseId: entrepriseId,
            loanId: loan.id,
            accountId: loan.accountId,
            modeDecaissement: selectedMode,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prêt décaissé et activé.')),
        );
      }
    } catch (e) {
      if (context.mounted) showFailureSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = l10n.localeName;
    final theme = Theme.of(context);
    final hasAccess = ref.watch(hasMicrofinanceAccessProvider);
    final ctx = ref.watch(contexteActifProvider);
    final entreprise = ctx?.entreprise;
    final devise = entreprise?.devise ?? 'XOF';

    if (!hasAccess || entreprise == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.mfTitle)),
        body: Center(
          child: MessageView(
            icon: Icons.workspace_premium_outlined,
            title: 'Formule Pro requise',
            message: 'Activez l\'abonnement Pro (5 000 FCFA) pour consulter ce dossier de prêt.',
            action: FilledButton(
              onPressed: () => context.go(Routes.choixFormuleAbonnement),
              child: const Text('Voir les formules'),
            ),
          ),
        ),
      );
    }

    final loansAsync = ref.watch(mfLoansProvider);
    final borrowers = ref.watch(mfBorrowersProvider).value ?? const [];
    final accounts = ref.watch(mfAccountsProvider).value ?? const [];
    final allInstallments = ref.watch(mfInstallmentsProvider).value ?? const [];
    final allRepayments = ref.watch(mfRepaymentsProvider).value ?? const [];

    return AsyncValueView<List<MicrofinanceLoan>>(
      value: loansAsync,
      data: (loans) {
        final loan = loans.where((l) => l.id == loanId && l.deletedAt == null).firstOrNull;
        if (loan == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Dossier de prêt')),
            body: Center(
              child: MessageView(
                icon: Icons.search_off_rounded,
                title: 'Prêt introuvable',
                message: 'Ce dossier n\'existe plus ou n\'appartient pas à cette entreprise.',
                action: FilledButton(
                  onPressed: () => context.go(Routes.commerceMicrofinance),
                  child: const Text('Retour'),
                ),
              ),
            ),
          );
        }

        final borrower = borrowers.where((b) => b.id == loan.borrowerId).firstOrNull;
        final account = accounts.where((a) => a.id == loan.accountId).firstOrNull;
        final loanInstallments = allInstallments
            .where((e) => e.loanId == loan.id && e.deletedAt == null)
            .toList()
          ..sort((a, b) => a.numeroEcheance.compareTo(b.numeroEcheance));
        final loanRepayments = allRepayments
            .where((r) => r.loanId == loan.id && r.deletedAt == null)
            .toList()
          ..sort((a, b) => b.datePaiement.compareTo(a.datePaiement));

        final now = DateTime.now();
        final statutActuel = DelinquencyAnalyzer.statutPretActuel(loan, loanInstallments, now);

        return Scaffold(
          appBar: AppBar(
            title: Text(loan.reference),
            actions: [
              if (borrower != null)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  tooltip: 'Documents PDF',
                  onSelected: (v) async {
                    if (v == 'contrat') {
                      await ouvrirApercuPdfMicrofinance(
                        context,
                        titre: 'Contrat ${loan.reference}',
                        fileName: 'Contrat_${loan.reference}.pdf',
                        builder: () => MicrofinancePdfGenerator.genererContratPretPdf(
                          entreprise: entreprise,
                          borrower: borrower,
                          loan: loan,
                          installments: loanInstallments,
                        ),
                      );
                    } else if (v == 'echeancier') {
                      await ouvrirApercuPdfMicrofinance(
                        context,
                        titre: 'Échéancier ${loan.reference}',
                        fileName: 'Echeancier_${loan.reference}.pdf',
                        builder: () => MicrofinancePdfGenerator.genererEcheancierPdf(
                          entreprise: entreprise,
                          borrower: borrower,
                          loan: loan,
                          installments: loanInstallments,
                        ),
                      );
                    } else if (v == 'decaissement' && account != null) {
                      await ouvrirApercuPdfMicrofinance(
                        context,
                        titre: 'Reçu décaissement ${loan.reference}',
                        fileName: 'Decaissement_${loan.reference}.pdf',
                        builder: () => MicrofinancePdfGenerator.genererRecuDecaissementPdf(
                          entreprise: entreprise,
                          borrower: borrower,
                          loan: loan,
                          account: account,
                        ),
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'contrat', child: Text('Contrat de prêt (PDF)')),
                    const PopupMenuItem(value: 'echeancier', child: Text('Échéancier imprimable (PDF)')),
                    if (loan.statut != StatutPret.brouillon && account != null)
                      const PopupMenuItem(value: 'decaissement', child: Text('Reçu de décaissement (PDF)')),
                  ],
                ),
            ],
          ),
          body: ResponsiveBody(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. En-tête emprunteur & statut
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    onTap: borrower == null
                                        ? null
                                        : () => context.push(Routes.microfinanceBorrowerDetails(borrower.id)),
                                    child: Text(
                                      borrower?.nomComplet ?? 'Emprunteur inconnu',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: borrower != null ? AppColors.primary : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${borrower?.telephone ?? ''} • Caisse : ${account?.nom ?? '—'}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatutPretBadge(statut: statutActuel),
                          ],
                        ),
                        const SizedBox(height: 14),
                        LinearProgressIndicator(
                          value: loan.progressionPourcent / 100,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(6),
                          color: statutActuel == StatutPret.enRetard
                              ? AppColors.negative
                              : AppColors.primary,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recouvré : ${loan.progressionPourcent.toStringAsFixed(1)} %',
                              style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Reste à payer : ${l10n.montant(loan.resteAPayerTotal, devise)}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: loan.resteAPayerTotal > 0 ? AppColors.negative : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 22),
                        Wrap(
                          spacing: 16,
                          runSpacing: 10,
                          children: [
                            _InfoTile('Capital accordé', l10n.montant(loan.montantAccorde, devise)),
                            _InfoTile('Intérêts prévus', l10n.montant(loan.montantInteretTotal, devise)),
                            _InfoTile('Total à rembourser', l10n.montant(loan.montantTotalARembourser, devise)),
                            _InfoTile('Capital remboursé', l10n.montant(loan.capitalRembourse, devise)),
                            _InfoTile('Intérêts encaissés', l10n.montant(loan.interetRembourse, devise)),
                            _InfoTile('Capital restant', l10n.montant(loan.capitalRestantARecuperer, devise)),
                            _InfoTile('Méthode', loan.methodeInteret.libelle(locale)),
                            _InfoTile(
                              'Échéances',
                              '${loan.nombreEcheances} × ${loan.frequence.libelle(locale)}',
                            ),
                            _InfoTile('Date d\'octroi', l10n.date(loan.dateOctroi)),
                            _InfoTile('Fin prévue', l10n.date(loan.dateFinPrevue)),
                          ],
                        ),
                        if (loan.motifAnnulation != null && loan.motifAnnulation!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.negativeSoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Motif statut (${statutActuel.libelle(locale)}) : ${loan.motifAnnulation}',
                              style: const TextStyle(color: AppColors.negative, fontSize: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Actions métier disponibles
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (statutActuel == StatutPret.brouillon)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                        onPressed: () => _decaisserBrouillon(
                          context,
                          ref,
                          entrepriseId: entreprise.id,
                          loan: loan,
                          devise: devise,
                        ),
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Décaisser maintenant'),
                      ),
                    if (statutActuel.estActifOuOuvert && loan.resteAPayerTotal > 0)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                        onPressed: () => afficherFormulaireRemboursement(
                          context,
                          loan: loan,
                          installments: loanInstallments,
                        ),
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Encaisser un remboursement'),
                      ),
                    if (statutActuel.estActifOuOuvert && statutActuel != StatutPret.contentieux)
                      OutlinedButton.icon(
                        onPressed: () async {
                          final motif = await _demanderMotif(
                            context,
                            titre: 'Passer en contentieux',
                            message: 'Indiquez la raison du passage de ce prêt en contentieux / impayé critique.',
                            labelBouton: 'Confirmer',
                            couleurBouton: AppColors.negative,
                          );
                          if (motif == null || !context.mounted) return;
                          try {
                            await ref.read(microfinanceRepositoryProvider).passerEnContentieux(
                                  entrepriseId: entreprise.id,
                                  loanId: loan.id,
                                  motif: motif,
                                );
                          } catch (e) {
                            if (context.mounted) showFailureSnackBar(context, e);
                          }
                        },
                        icon: const Icon(Icons.gavel_outlined),
                        label: const Text('Passer en contentieux'),
                      ),
                    if ((statutActuel == StatutPret.brouillon ||
                            (statutActuel.estActifOuOuvert && loan.totalRembourse == 0)) &&
                        statutActuel != StatutPret.annule)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.negative),
                        onPressed: () async {
                          final motif = await _demanderMotif(
                            context,
                            titre: 'Annuler le prêt ${loan.reference}',
                            message: statutActuel == StatutPret.brouillon
                                ? 'Ce brouillon sera marqué annulé (conservé dans l\'audit).'
                                : 'Le décaissement sera contre-passé en trésorerie et les écritures seront archivées dans le journal.',
                            labelBouton: 'Annuler le prêt',
                            couleurBouton: AppColors.negative,
                          );
                          if (motif == null || !context.mounted) return;
                          try {
                            await ref.read(microfinanceRepositoryProvider).annulerPret(
                                  entrepriseId: entreprise.id,
                                  loanId: loan.id,
                                  motif: motif,
                                );
                          } catch (e) {
                            if (context.mounted) showFailureSnackBar(context, e);
                          }
                        },
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Annuler le prêt'),
                      ),
                  ],
                ),
                const SizedBox(height: 18),

                // 3. Échéancier complet
                Text(
                  'Échéancier (${loanInstallments.length} échéances)',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                if (loanInstallments.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Aucune échéance générée.'),
                    ),
                  )
                else
                  ...loanInstallments.map((e) {
                    final st = DelinquencyAnalyzer.statutEcheanceActuel(e, now);
                    final ret = DelinquencyAnalyzer.joursRetardEcheance(e, now);
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: st == StatutEcheance.enRetard
                              ? AppColors.negative.withValues(alpha: 0.45)
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: st == StatutEcheance.paye
                                  ? const Color(0xFFDCFCE7)
                                  : theme.colorScheme.surfaceContainerHighest,
                              child: Text(
                                '${e.numeroEcheance}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: st == StatutEcheance.paye
                                      ? const Color(0xFF15803D)
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(l10n.date(e.datePrevue),
                                          style: const TextStyle(fontWeight: FontWeight.w700)),
                                      const SizedBox(width: 8),
                                      StatutEcheanceBadge(statut: st, joursRetard: ret),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Attendu : ${l10n.montant(e.montantTotalAttendu, devise)} '
                                    '(Cap: ${l10n.montant(e.capitalPrevu, devise)}, Int: ${l10n.montant(e.interetPrevu, devise)})',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (e.montantDejaPaye > 0)
                                    Text(
                                      'Payé : ${l10n.montant(e.montantDejaPaye, devise)} • Reste : ${l10n.montant(e.resteAPayer, devise)}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: e.estSoldee ? AppColors.primary : AppColors.gold,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (!e.estSoldee &&
                                statutActuel.estActifOuOuvert &&
                                st != StatutEcheance.annule)
                              TextButton(
                                onPressed: () => afficherFormulaireRemboursement(
                                  context,
                                  loan: loan,
                                  installments: loanInstallments,
                                  installmentCible: e,
                                ),
                                child: const Text('Encaisser'),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 18),

                // 4. Historique des remboursements
                Text(
                  'Historique des remboursements (${loanRepayments.length})',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                if (loanRepayments.isEmpty)
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Aucun remboursement enregistré pour ce prêt.'),
                    ),
                  )
                else
                  ...loanRepayments.map((r) {
                    final rAcc = accounts.where((a) => a.id == r.accountId).firstOrNull;
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      child: ListTile(
                        leading: Icon(
                          r.estAnnule ? Icons.undo_rounded : Icons.check_circle_rounded,
                          color: r.estAnnule ? AppColors.negative : AppColors.primary,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${r.reference} • ${l10n.montant(r.montantEncaisse, devise)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  decoration: r.estAnnule ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                            if (r.estAnnule)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.negativeSoft,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Annulé',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.negative),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${l10n.dateTime(r.datePaiement)} • ${r.typeRemboursement.libelle(locale)} • ${r.modePaiement.libelle(locale)}',
                            ),
                            Text(
                              'Capital : ${l10n.montant(r.partCapital, devise)} | Intérêts : ${l10n.montant(r.partInteret, devise)}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (r.motifAnnulation != null && r.motifAnnulation!.isNotEmpty)
                              Text(
                                'Motif annulation : ${r.motifAnnulation}',
                                style: const TextStyle(color: AppColors.negative, fontSize: 11),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (borrower != null && rAcc != null)
                              IconButton(
                                tooltip: 'Reçu PDF',
                                icon: const Icon(Icons.picture_as_pdf_outlined),
                                onPressed: () => ouvrirRecuRemboursementPdf(
                                  context,
                                  ref: ref,
                                  repayment: r,
                                  loan: loan,
                                  borrower: borrower,
                                  account: rAcc,
                                ),
                              ),
                            if (!r.estAnnule)
                              IconButton(
                                tooltip: 'Contre-passer / Annuler',
                                icon: const Icon(Icons.undo_rounded, color: AppColors.negative),
                                onPressed: () async {
                                  final motif = await _demanderMotif(
                                    context,
                                    titre: 'Annuler le remboursement ${r.reference}',
                                    message:
                                        'Une contre-passation annulera l\'impact sur le prêt, l\'échéancier et la trésorerie tout en conservant la trace dans l\'audit.',
                                    labelBouton: 'Contre-passer',
                                    couleurBouton: AppColors.negative,
                                  );
                                  if (motif == null || !context.mounted) return;
                                  try {
                                    await ref.read(microfinanceRepositoryProvider).annulerRemboursement(
                                          entrepriseId: entreprise.id,
                                          repaymentId: r.id,
                                          motif: motif,
                                        );
                                  } catch (e) {
                                    if (context.mounted) showFailureSnackBar(context, e);
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  }),

                if ((loan.conditionsParticulieres?.isNotEmpty ?? false) ||
                    (loan.observations?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (loan.conditionsParticulieres?.isNotEmpty ?? false) ...[
                            const Text('Conditions particulières',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(loan.conditionsParticulieres!),
                            const SizedBox(height: 10),
                          ],
                          if (loan.observations?.isNotEmpty ?? false) ...[
                            const Text('Observations', style: TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(loan.observations!),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 155,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}
