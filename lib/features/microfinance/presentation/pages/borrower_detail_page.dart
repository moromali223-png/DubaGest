import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/microfinance_models.dart';
import '../../domain/services/delinquency_analyzer.dart';
import '../pdf/microfinance_pdf_generator.dart';
import '../providers/microfinance_providers.dart';
import '../widgets/borrower_form_sheet.dart';
import '../widgets/microfinance_shared_widgets.dart';
import '../widgets/repayment_form_sheet.dart';

/// Dossier complet d'un emprunteur Microfinance :
/// fiche signalétique, synthèse financière, prêts en cours et historique, encaissements & PDF.
class BorrowerDetailPage extends ConsumerWidget {
  const BorrowerDetailPage({super.key, required this.borrowerId});

  final String borrowerId;

  Future<void> _appeler(String tel) async {
    final clean = tel.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;
    await launchUrl(Uri.parse('tel:$clean'));
  }

  Future<void> _whatsapp(String tel, String nom) async {
    final digits = tel.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;
    final msg = Uri.encodeComponent('Bonjour $nom, suivi de votre dossier Microfinance.');
    await launchUrl(
      Uri.parse('https://wa.me/$digits?text=$msg'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
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
            message: 'Activez l\'abonnement Pro (5 000 FCFA) pour accéder aux fiches emprunteurs.',
            action: FilledButton(
              onPressed: () => context.go(Routes.choixFormuleAbonnement),
              child: const Text('Voir les formules'),
            ),
          ),
        ),
      );
    }

    final borrowersAsync = ref.watch(mfBorrowersProvider);
    final summaries = ref.watch(mfBorrowerSummariesProvider);
    final loans = ref.watch(mfLoansProvider).value ?? const [];
    final allInstallments = ref.watch(mfInstallmentsProvider).value ?? const [];
    final allRepayments = ref.watch(mfRepaymentsProvider).value ?? const [];
    final accounts = ref.watch(mfAccountsProvider).value ?? const [];

    return AsyncValueView<List<MicrofinanceBorrower>>(
      value: borrowersAsync,
      data: (borrowers) {
        final borrower = borrowers.where((b) => b.id == borrowerId && b.deletedAt == null).firstOrNull;
        if (borrower == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Emprunteur')),
            body: Center(
              child: MessageView(
                icon: Icons.person_off_outlined,
                title: 'Emprunteur introuvable',
                message: 'Cette fiche n\'existe plus dans cette entreprise.',
                action: FilledButton(
                  onPressed: () => context.go(Routes.commerceMicrofinance),
                  child: const Text('Retour'),
                ),
              ),
            ),
          );
        }

        final now = DateTime.now();
        final summary = summaries[borrower.id] ??
            DelinquencyAnalyzer.synthetiserEmprunteur(
              borrower: borrower,
              loans: loans,
              installments: allInstallments,
              now: now,
            );
        final borrowerLoans = loans
            .where((l) => l.borrowerId == borrower.id && l.deletedAt == null)
            .toList()
          ..sort((a, b) => b.dateOctroi.compareTo(a.dateOctroi));
        final borrowerRepayments = allRepayments
            .where((r) => r.borrowerId == borrower.id && r.deletedAt == null)
            .toList()
          ..sort((a, b) => b.datePaiement.compareTo(a.datePaiement));

        final loansById = {for (final l in borrowerLoans) l.id: l};
        final accountsById = {for (final a in accounts) a.id: a};
        final waNum = (borrower.whatsapp?.isNotEmpty ?? false) ? borrower.whatsapp! : borrower.telephone;

        return Scaffold(
          appBar: AppBar(
            title: Text(borrower.nomComplet),
            actions: [
              IconButton(
                tooltip: 'Modifier',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => afficherFormulaireEmprunteur(context, existant: borrower),
              ),
              IconButton(
                tooltip: 'Situation financière PDF',
                icon: const Icon(Icons.picture_as_pdf_outlined),
                onPressed: () => ouvrirApercuPdfMicrofinance(
                  context,
                  titre: 'Situation ${borrower.nomComplet}',
                  fileName: 'Situation_${borrower.codeEmprunteur}.pdf',
                  builder: () => MicrofinancePdfGenerator.genererSituationEmprunteurPdf(
                    entreprise: entreprise,
                    summary: summary,
                    loans: borrowerLoans,
                    repayments: borrowerRepayments,
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            onPressed: () => context.push('${Routes.microfinanceLoanNew}?borrowerId=${borrower.id}'),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.mfNewLoan),
          ),
          body: ResponsiveBody(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Profil emprunteur & contact rapide
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: AppColors.primarySoft,
                              child: Text(
                                borrower.initiales,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    borrower.nomComplet,
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    '${borrower.codeEmprunteur} • Inscrit le ${l10n.date(borrower.dateInscription)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.phone_outlined, size: 17, color: AppColors.primary),
                              label: Text(borrower.telephone),
                              onPressed: () => _appeler(borrower.telephone),
                            ),
                            if (waNum.isNotEmpty)
                              ActionChip(
                                avatar: const Icon(Icons.chat_outlined, size: 17, color: Color(0xFF16A34A)),
                                label: const Text('WhatsApp'),
                                onPressed: () => _whatsapp(waNum, borrower.nomComplet),
                              ),
                          ],
                        ),
                        if ((borrower.profession?.isNotEmpty ?? false) ||
                            (borrower.activite?.isNotEmpty ?? false) ||
                            (borrower.adresse?.isNotEmpty ?? false) ||
                            (borrower.referencePiece?.isNotEmpty ?? false)) ...[
                          const Divider(height: 20),
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            children: [
                              if (borrower.profession?.isNotEmpty ?? false)
                                _DetailKV('Profession', borrower.profession!),
                              if (borrower.activite?.isNotEmpty ?? false)
                                _DetailKV('Activité', borrower.activite!),
                              if (borrower.adresse?.isNotEmpty ?? false)
                                _DetailKV('Adresse', borrower.adresse!),
                              if (borrower.localisation?.isNotEmpty ?? false)
                                _DetailKV('Localisation', borrower.localisation!),
                              if (borrower.referencePiece?.isNotEmpty ?? false)
                                _DetailKV(
                                  borrower.typePiece ?? 'Pièce d\'identité',
                                  borrower.referencePiece!,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Synthèse financière
                GridView.count(
                  crossAxisCount: MediaQuery.sizeOf(context).width >= AppBreakpoints.medium ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.6,
                  children: [
                    MicrofinanceKpiCard(
                      titre: 'Total emprunté',
                      valeur: l10n.montant(summary.totalEmprunte, devise),
                      sousTitre: '${summary.nombrePretsTotal} prêt(s) dont ${summary.nombrePretsActifs} actif(s)',
                      icone: Icons.request_quote_outlined,
                      couleur: AppColors.primary,
                    ),
                    MicrofinanceKpiCard(
                      titre: 'Total remboursé',
                      valeur: l10n.montant(summary.totalRembourse, devise),
                      icone: Icons.verified_outlined,
                      couleur: const Color(0xFF16A34A),
                    ),
                    MicrofinanceKpiCard(
                      titre: 'Reste à payer',
                      valeur: l10n.montant(summary.resteAPayerTotal, devise),
                      icone: Icons.account_balance_wallet_outlined,
                      couleur: const Color(0xFF0284C7),
                    ),
                    MicrofinanceKpiCard(
                      titre: 'Impayés / Retard',
                      valeur: l10n.montant(summary.montantImpayes, devise),
                      sousTitre: summary.joursRetardMax > 0
                          ? '${summary.joursRetardMax} j max de retard'
                          : 'Aucun retard',
                      icone: Icons.warning_amber_rounded,
                      couleur: summary.montantImpayes > 0 ? AppColors.negative : const Color(0xFF16A34A),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 3. Prêts de l'emprunteur (multiples prêts simultanés pris en charge)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Prêts (${borrowerLoans.length})',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          context.push('${Routes.microfinanceLoanNew}?borrowerId=${borrower.id}'),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Accorder un prêt'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (borrowerLoans.isEmpty)
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Aucun prêt enregistré pour cet emprunteur.'),
                    ),
                  )
                else
                  ...borrowerLoans.map((loan) {
                    final echs = allInstallments
                        .where((e) => e.loanId == loan.id && e.deletedAt == null)
                        .toList();
                    final statut = DelinquencyAnalyzer.statutPretActuel(loan, echs, now);
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => context.push(Routes.microfinanceLoanDetails(loan.id)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${loan.reference} • ${l10n.montant(loan.montantAccorde, devise)}',
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  StatutPretBadge(statut: statut),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Total dû : ${l10n.montant(loan.montantTotalARembourser, devise)} • '
                                'Reste : ${l10n.montant(loan.resteAPayerTotal, devise)}',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: loan.progressionPourcent / 100,
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(4),
                                color: AppColors.primary,
                              ),
                              if (statut.estActifOuOuvert && loan.resteAPayerTotal > 0) ...[
                                const SizedBox(height: 6),
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: TextButton.icon(
                                    onPressed: () => afficherFormulaireRemboursement(
                                      context,
                                      loan: loan,
                                      installments: echs,
                                    ),
                                    icon: const Icon(Icons.payments_outlined, size: 18),
                                    label: const Text('Encaisser'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 18),

                // 4. Historique des remboursements
                Text(
                  'Historique des remboursements (${borrowerRepayments.length})',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                if (borrowerRepayments.isEmpty)
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Aucun remboursement enregistré.'),
                    ),
                  )
                else
                  ...borrowerRepayments.map((r) {
                    final rLoan = loansById[r.loanId];
                    final rAcc = accountsById[r.accountId];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      child: ListTile(
                        leading: Icon(
                          r.estAnnule ? Icons.undo_rounded : Icons.receipt_long_outlined,
                          color: r.estAnnule ? AppColors.negative : AppColors.primary,
                        ),
                        title: Text(
                          '${r.reference} • ${l10n.montant(r.montantEncaisse, devise)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            decoration: r.estAnnule ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Text(
                          '${l10n.dateTime(r.datePaiement)} • Prêt ${rLoan?.reference ?? ''}\n'
                          'Cap: ${l10n.montant(r.partCapital, devise)} | Int: ${l10n.montant(r.partInteret, devise)}',
                        ),
                        trailing: (rLoan != null && rAcc != null)
                            ? IconButton(
                                tooltip: 'Reçu PDF',
                                icon: const Icon(Icons.picture_as_pdf_outlined),
                                onPressed: () => ouvrirRecuRemboursementPdf(
                                  context,
                                  ref: ref,
                                  repayment: r,
                                  loan: rLoan,
                                  borrower: borrower,
                                  account: rAcc,
                                ),
                              )
                            : null,
                      ),
                    );
                  }),
                const SizedBox(height: 72),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailKV extends StatelessWidget {
  const _DetailKV(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
