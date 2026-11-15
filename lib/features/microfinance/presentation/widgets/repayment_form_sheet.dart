import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/microfinance_enums.dart';
import '../../domain/entities/microfinance_models.dart';
import '../../domain/services/repayment_allocator.dart';
import '../pdf/microfinance_pdf_generator.dart';
import '../providers/microfinance_providers.dart';
import 'microfinance_shared_widgets.dart';

/// Feuille d'encaissement d'un remboursement (complet, partiel, anticipé, exceptionnel, multi-échéances)
/// avec aperçu en temps réel de la ventilation Capital / Intérêts et édition directe du reçu PDF.
Future<MicrofinanceRepayment?> afficherFormulaireRemboursement(
  BuildContext context, {
  required MicrofinanceLoan loan,
  required List<MicrofinanceInstallment> installments,
  MicrofinanceInstallment? installmentCible,
}) {
  return showModalBottomSheet<MicrofinanceRepayment>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => RepaymentFormSheet(
      loan: loan,
      installments: installments,
      installmentCible: installmentCible,
    ),
  );
}

class RepaymentFormSheet extends ConsumerStatefulWidget {
  const RepaymentFormSheet({
    super.key,
    required this.loan,
    required this.installments,
    this.installmentCible,
  });

  final MicrofinanceLoan loan;
  final List<MicrofinanceInstallment> installments;
  final MicrofinanceInstallment? installmentCible;

  @override
  ConsumerState<RepaymentFormSheet> createState() => _RepaymentFormSheetState();
}

class _RepaymentFormSheetState extends ConsumerState<RepaymentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _montantCtrl;
  late final TextEditingController _obsCtrl;

  String? _accountId;
  late TypeRemboursement _type;
  late ModePaiementMicrofinance _mode;
  DateTime _datePaiement = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _accountId = widget.loan.accountId;
    _mode = widget.loan.modeDecaissement;
    final cible = widget.installmentCible ??
        widget.installments
            .where((e) => !e.estSoldee)
            .fold<MicrofinanceInstallment?>(
              null,
              (prev, e) => prev == null || e.numeroEcheance < prev.numeroEcheance ? e : prev,
            );
    final defMontant = cible?.resteAPayer ?? widget.loan.resteAPayerTotal;
    _type = TypeRemboursement.complet;
    _montantCtrl = TextEditingController(text: defMontant.toString());
    _obsCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  int get _montantSaisi => int.tryParse(_montantCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  RepaymentAllocationResult? _simulerVentilation() {
    final montant = _montantSaisi;
    if (montant <= 0 || montant > widget.loan.resteAPayerTotal) return null;
    try {
      return RepaymentAllocator.allouer(
        loan: widget.loan,
        installments: widget.installments,
        montantEncaisse: montant,
        typeSouhaite: _type,
        installmentCibleId: widget.installmentCible?.id,
        datePaiement: _datePaiement,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _valider() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(microfinanceRepositoryProvider);
      final rep = await repo.enregistrerRemboursement(
        entrepriseId: widget.loan.entrepriseId,
        loanId: widget.loan.id,
        accountId: _accountId ?? widget.loan.accountId,
        montantEncaisse: _montantSaisi,
        typeRemboursement: _type,
        installmentCibleId: widget.installmentCible?.id,
        modePaiement: _mode,
        datePaiement: _datePaiement,
        observations: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, rep);
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ctx = ref.watch(contexteActifProvider);
    final devise = ctx?.entreprise?.devise ?? 'XOF';

    final prochaine = widget.installmentCible ??
        widget.installments
            .where((e) => !e.estSoldee)
            .fold<MicrofinanceInstallment?>(
              null,
              (prev, e) => prev == null || e.numeroEcheance < prev.numeroEcheance ? e : prev,
            );
    final apercu = _simulerVentilation();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Form(
          key: _formKey,
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Encaisser un remboursement (${widget.loan.reference})',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Reste à payer sur ce prêt : ${l10n.montant(widget.loan.resteAPayerTotal, devise)}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (prochaine != null)
                    ActionChip(
                      label: Text('Échéance #${prochaine.numeroEcheance} (${l10n.montant(prochaine.resteAPayer, devise)})'),
                      onPressed: () {
                        setState(() {
                          _montantCtrl.text = prochaine.resteAPayer.toString();
                          _type = TypeRemboursement.complet;
                        });
                      },
                    ),
                  ActionChip(
                    label: Text('Solde total (${l10n.montant(widget.loan.resteAPayerTotal, devise)})'),
                    onPressed: () {
                      setState(() {
                        _montantCtrl.text = widget.loan.resteAPayerTotal.toString();
                        _type = TypeRemboursement.anticipe;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TypeRemboursement>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type de remboursement'),
                items: [
                  for (final t in TypeRemboursement.values)
                    DropdownMenuItem(value: t, child: Text(t.libelle(l10n.localeName))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _type = v);
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _montantCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Montant encaissé ($devise) *',
                  prefixIcon: const Icon(Icons.payments_outlined),
                ),
                validator: (v) {
                  final m = int.tryParse((v ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                  if (m <= 0) return 'Montant invalide';
                  if (m > widget.loan.resteAPayerTotal) {
                    return 'Supérieur au reste à payer (${l10n.montant(widget.loan.resteAPayerTotal, devise)})';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<ModePaiementMicrofinance>(
                initialValue: _mode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Moyen de paiement'),
                items: [
                  for (final m in ModePaiementMicrofinance.values)
                    DropdownMenuItem(value: m, child: Text(m.libelle(l10n.localeName))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _mode = v);
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Date d\'encaissement'),
                subtitle: Text(l10n.dateTime(_datePaiement)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _datePaiement,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      _datePaiement = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        _datePaiement.hour,
                        _datePaiement.minute,
                      );
                    });
                  }
                },
              ),
              TextFormField(
                controller: _obsCtrl,
                decoration: const InputDecoration(labelText: 'Observations / Référence bordereau (facultatif)'),
              ),
              const SizedBox(height: 14),
              if (apercu != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ventilation comptable automatique',
                        style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Part Capital remboursé (réduit créance) :'),
                          Text(l10n.montant(apercu.partCapital, devise),
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Part Intérêts encaissés (revenu réel) :'),
                          Text(l10n.montant(apercu.partInteret, devise),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, color: AppColors.primary)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Échéances touchées :'),
                          Text('${apercu.allocations.length}'),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Nouveau reste à payer :'),
                          Text(l10n.montant(apercu.loanMisAJour.resteAPayerTotal, devise),
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _saving ? null : _valider,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: const Text('Confirmer l\'encaissement'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton rapide pour ouvrir le reçu PDF d'un remboursement.
Future<void> ouvrirRecuRemboursementPdf(
  BuildContext context, {
  required WidgetRef ref,
  required MicrofinanceRepayment repayment,
  required MicrofinanceLoan loan,
  required MicrofinanceBorrower borrower,
  required MicrofinanceAccount account,
}) {
  final entreprise = ref.read(contexteActifProvider)?.entreprise;
  return ouvrirApercuPdfMicrofinance(
    context,
    titre: 'Reçu ${repayment.reference}',
    fileName: '${repayment.reference}.pdf',
    builder: () => MicrofinancePdfGenerator.genererRecuRemboursementPdf(
      entreprise: entreprise,
      borrower: borrower,
      loan: loan,
      repayment: repayment,
      account: account,
    ),
  );
}

