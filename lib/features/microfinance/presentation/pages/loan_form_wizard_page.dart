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
import '../../domain/services/loan_interest_calculator.dart';
import '../providers/microfinance_providers.dart';
import '../widgets/borrower_form_sheet.dart';

/// Assistant complet d'octroi / création d'un prêt Microfinance avec simulation obligatoire.
class LoanFormWizardPage extends ConsumerStatefulWidget {
  const LoanFormWizardPage({super.key, this.initialBorrowerId});

  final String? initialBorrowerId;

  @override
  ConsumerState<LoanFormWizardPage> createState() => _LoanFormWizardPageState();
}

class _LoanFormWizardPageState extends ConsumerState<LoanFormWizardPage> {
  final _formKey = GlobalKey<FormState>();
  final _montantCtrl = TextEditingController(text: '100000');
  final _tauxCtrl = TextEditingController(text: '10');
  final _interetFixeCtrl = TextEditingController(text: '15000');
  final _nbEcheancesCtrl = TextEditingController(text: '6');
  final _conditionsCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  String? _borrowerId;
  MethodeCalculInteret _methode = MethodeCalculInteret.pourcentageFixe;
  FrequenceRemboursement _frequence = FrequenceRemboursement.mensuelle;
  ModePaiementMicrofinance _mode = ModePaiementMicrofinance.especes;
  DateTime _dateOctroi = DateTime.now();
  DateTime _dateDebut = DateTime.now().add(const Duration(days: 30));
  bool _decaisserImmediatement = true;
  bool _voirEcheancierComplet = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _borrowerId = widget.initialBorrowerId;
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _tauxCtrl.dispose();
    _interetFixeCtrl.dispose();
    _nbEcheancesCtrl.dispose();
    _conditionsCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  int get _montant => int.tryParse(_montantCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  double get _taux => double.tryParse(_tauxCtrl.text.replaceAll(',', '.').trim()) ?? 0;
  int get _interetFixe => int.tryParse(_interetFixeCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  int get _nbEcheances => int.tryParse(_nbEcheancesCtrl.text.trim()) ?? 0;

  void _adapterDateDebutSelonFrequence(FrequenceRemboursement f) {
    final base = DateTime(_dateOctroi.year, _dateOctroi.month, _dateOctroi.day);
    setState(() {
      _frequence = f;
      _dateDebut = switch (f) {
        FrequenceRemboursement.quotidienne => base.add(const Duration(days: 1)),
        FrequenceRemboursement.hebdomadaire => base.add(const Duration(days: 7)),
        FrequenceRemboursement.mensuelle => LoanInterestCalculator.dateEcheance(base, f, 1),
      };
    });
  }

  SimulationPretResult? _simuler(String entrepriseId, String? borrowerId) {
    if (_montant <= 0 || _nbEcheances <= 0 || _taux < 0 || _interetFixe < 0) return null;
    try {
      return LoanInterestCalculator.simuler(
        entrepriseId: entrepriseId,
        loanId: 'preview',
        borrowerId: borrowerId ?? 'preview',
        montantAccorde: _montant,
        methode: _methode,
        tauxInteret: _taux,
        montantInteretFixe: _interetFixe,
        frequence: _frequence,
        nombreEcheances: _nbEcheances,
        dateDebut: _dateDebut,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _choisirDate({required bool estOctroi}) async {
    final init = estOctroi ? _dateOctroi : _dateDebut;
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (estOctroi) {
        _dateOctroi = picked;
        if (_dateDebut.isBefore(_dateOctroi)) {
          _adapterDateDebutSelonFrequence(_frequence);
        }
      } else {
        _dateDebut = picked;
      }
    });
  }

  Future<void> _valider({
    required MicrofinanceBorrower borrower,
    required SimulationPretResult simulation,
  }) async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final ctx = ref.read(contexteActifProvider);
    if (ctx?.entreprise == null) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(microfinanceRepositoryProvider);
      final loan = await repo.creerEtDecaisserPret(
        entrepriseId: ctx!.entreprise!.id,
        perimetreId: ctx.perimetres.firstOrNull?.id,
        borrowerId: borrower.id,
        accountId: '',
        montantAccorde: _montant,
        methodeInteret: _methode,
        tauxInteret: _methode == MethodeCalculInteret.montantFixe ? 0 : _taux,
        montantInteretFixe: _methode == MethodeCalculInteret.montantFixe ? _interetFixe : 0,
        frequence: _frequence,
        nombreEcheances: _nbEcheances,
        modeDecaissement: _mode,
        dateOctroi: _dateOctroi,
        dateDebut: _dateDebut,
        decaisserImmediatement: _decaisserImmediatement,
        conditionsParticulieres: _conditionsCtrl.text.trim().isEmpty ? null : _conditionsCtrl.text.trim(),
        observations: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Prêt ${loan.reference} enregistré avec succès.')),
      );
      context.go(Routes.microfinanceLoanDetails(loan.id));
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = l10n.localeName;
    final theme = Theme.of(context);
    final hasAccess = ref.watch(hasMicrofinanceAccessProvider);
    final ctx = ref.watch(contexteActifProvider);
    final entrepriseId = ctx?.entreprise?.id;
    final devise = ctx?.entreprise?.devise ?? 'XOF';

    if (!hasAccess || entrepriseId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.mfNewLoan)),
        body: Center(
          child: MessageView(
            icon: Icons.workspace_premium_outlined,
            title: 'Formule Pro requise',
            message: 'Le module Microfinance est réservé aux abonnements Pro actifs (5 000 FCFA).',
            action: FilledButton(
              onPressed: () => context.go(Routes.choixFormuleAbonnement),
              child: const Text('Voir les formules'),
            ),
          ),
        ),
      );
    }

    final borrowersAsync = ref.watch(mfBorrowersProvider);
    final borrowers = (borrowersAsync.value ?? const []).where((b) => b.deletedAt == null).toList();

    final selectedBorrower = borrowers.where((b) => b.id == _borrowerId).firstOrNull ??
        (borrowers.length == 1 ? borrowers.first : null);

    if (_borrowerId == null && selectedBorrower != null) {
      _borrowerId = selectedBorrower.id;
    }

    final sim = _simuler(entrepriseId, selectedBorrower?.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mfNewLoan),
      ),
      body: ResponsiveBody(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Sélection Emprunteur
              _SectionCard(
                title: '1. Emprunteur',
                trailing: TextButton.icon(
                  onPressed: () async {
                    final created = await afficherFormulaireEmprunteur(context);
                    if (created != null && mounted) {
                      setState(() => _borrowerId = created.id);
                    }
                  },
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Nouveau'),
                ),
                child: borrowers.isEmpty
                    ? ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.info_outline, color: AppColors.primary),
                        title: const Text('Aucun emprunteur enregistré'),
                        subtitle: const Text('Créez un profil emprunteur (sans caution obligatoire).'),
                        trailing: FilledButton(
                          onPressed: () async {
                            final b = await afficherFormulaireEmprunteur(context);
                            if (b != null && mounted) setState(() => _borrowerId = b.id);
                          },
                          child: const Text('Créer'),
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        initialValue: selectedBorrower?.id,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Sélectionner l\'emprunteur *',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        items: borrowers
                            .map((b) => DropdownMenuItem(
                                  value: b.id,
                                  child: Text('${b.nomComplet} • ${b.telephone}'),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _borrowerId = v),
                        validator: (v) => v == null ? 'Sélectionnez un emprunteur' : null,
                      ),
              ),
              const SizedBox(height: 14),

              // 2. Conditions financières & Calcul des intérêts
              _SectionCard(
                title: '2. Montant, intérêts & échéancier',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _montantCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Montant accordé (capital) *',
                        suffixText: devise == 'XOF' ? 'FCFA' : devise,
                        prefixIcon: const Icon(Icons.payments_outlined),
                      ),
                      validator: (v) {
                        final val = int.tryParse((v ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                        if (val <= 0) return 'Saisissez un montant valide > 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<MethodeCalculInteret>(
                      initialValue: _methode,
                      decoration: const InputDecoration(
                        labelText: 'Méthode de calcul des intérêts *',
                        prefixIcon: Icon(Icons.percent_rounded),
                      ),
                      items: MethodeCalculInteret.values
                          .map((m) => DropdownMenuItem(value: m, child: Text(m.libelle(locale))))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _methode = v);
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      switch (_methode) {
                        MethodeCalculInteret.pourcentageFixe =>
                          'Intérêt global = capital × taux (%) réparti à parts égales sur toutes les échéances.',
                        MethodeCalculInteret.montantFixe =>
                          'Montant d\'intérêt libre saisi manuellement en FCFA et réparti sur la durée.',
                        MethodeCalculInteret.degressif =>
                          'Amortissement du capital constant ; intérêt de chaque échéance calculé sur le capital restant dû.',
                      },
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    if (_methode == MethodeCalculInteret.montantFixe)
                      TextFormField(
                        controller: _interetFixeCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Montant d\'intérêt total fixe *',
                          suffixText: devise == 'XOF' ? 'FCFA' : devise,
                          prefixIcon: const Icon(Icons.monetization_on_outlined),
                        ),
                        validator: (v) {
                          final val = int.tryParse((v ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? -1;
                          if (val < 0) return 'Montant invalide';
                          return null;
                        },
                      )
                    else
                      TextFormField(
                        controller: _tauxCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: _methode == MethodeCalculInteret.degressif
                              ? 'Taux d\'intérêt par période (%) *'
                              : 'Taux d\'intérêt global (%) *',
                          suffixText: '%',
                          prefixIcon: const Icon(Icons.trending_up_rounded),
                        ),
                        validator: (v) {
                          final val = double.tryParse((v ?? '').replaceAll(',', '.').trim()) ?? -1;
                          if (val < 0) return 'Taux invalide';
                          return null;
                        },
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<FrequenceRemboursement>(
                            initialValue: _frequence,
                            decoration: const InputDecoration(labelText: 'Fréquence *'),
                            items: FrequenceRemboursement.values
                                .map((f) => DropdownMenuItem(value: f, child: Text(f.libelle(locale))))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) _adapterDateDebutSelonFrequence(v);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _nbEcheancesCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(labelText: 'Nb échéances *'),
                            validator: (v) {
                              final n = int.tryParse((v ?? '').trim()) ?? 0;
                              if (n <= 0 || n > 365) return 'Entre 1 et 365';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _choisirDate(estOctroi: true),
                            icon: const Icon(Icons.event_available_outlined, size: 18),
                            label: Text('Octroi : ${l10n.date(_dateOctroi)}'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _choisirDate(estOctroi: false),
                            icon: const Icon(Icons.calendar_today_outlined, size: 18),
                            label: Text('1re échéance : ${l10n.date(_dateDebut)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ModePaiementMicrofinance>(
                      initialValue: _mode,
                      decoration: const InputDecoration(
                        labelText: 'Mode de décaissement',
                        prefixIcon: Icon(Icons.account_balance_outlined),
                      ),
                      items: ModePaiementMicrofinance.values
                          .map((m) => DropdownMenuItem(value: m, child: Text(m.libelle(locale))))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _mode = v);
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _decaisserImmediatement,
                      onChanged: (v) => setState(() => _decaisserImmediatement = v),
                      title: const Text('Décaisser les fonds immédiatement'),
                      subtitle: Text(
                        _decaisserImmediatement
                            ? 'Active immédiatement le prêt et génère son échéancier de remboursement.'
                            : 'Enregistre le prêt en brouillon avant activation.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _conditionsCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Conditions particulières (optionnel)'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _obsCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Observations (optionnel)'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. RÉSUMÉ OBLIGATOIRE AVANT VALIDATION ET DÉCAISSEMENT
              if (sim != null)
                Card(
                  elevation: 0,
                  color: AppColors.primarySoft.withValues(alpha: theme.brightness == Brightness.dark ? 0.16 : 0.7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.primary, width: 1.2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.summarize_rounded, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Résumé financier obligatoire avant validation',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 18),
                        _SummaryRow('Montant emprunté (capital)', l10n.montant(sim.montantEmprunte, devise)),
                        _SummaryRow('Montant total des intérêts', l10n.montant(sim.montantInteretTotal, devise)),
                        _SummaryRow(
                          'Montant total à rembourser',
                          l10n.montant(sim.montantTotalARembourser, devise),
                          highlight: true,
                        ),
                        _SummaryRow(
                          'Durée / Nb d\'échéances',
                          '${sim.nombreEcheances} × ${_frequence.libelle(locale)}',
                        ),
                        _SummaryRow(
                          'Montant indicatif par échéance',
                          l10n.montant(sim.montantEcheanceStandard, devise),
                        ),
                        _SummaryRow('Coût total du crédit', l10n.montant(sim.coutTotalCredit, devise)),
                        _SummaryRow(
                          'Période prévue',
                          '${l10n.date(sim.dateDebut)} → ${l10n.date(sim.dateFinPrevue)}',
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => setState(() => _voirEcheancierComplet = !_voirEcheancierComplet),
                          icon: Icon(_voirEcheancierComplet ? Icons.expand_less : Icons.expand_more),
                          label: Text(_voirEcheancierComplet
                              ? 'Masquer le détail des échéances'
                              : 'Aperçu de l\'échéancier (${sim.echeances.length} échéances)'),
                        ),
                        if (_voirEcheancierComplet) ...[
                          const Divider(height: 12),
                          ...sim.echeances.map((e) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 34,
                                      child: Text('#${e.numeroEcheance}',
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                    ),
                                    Expanded(
                                      child: Text(l10n.date(e.datePrevue), style: const TextStyle(fontSize: 12)),
                                    ),
                                    Text(
                                      'Cap: ${l10n.montant(e.capitalPrevu, devise)} + Int: ${l10n.montant(e.interetPrevu, devise)}',
                                      style: theme.textTheme.labelSmall,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      l10n.montant(e.montantTotalAttendu, devise),
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: (_saving || selectedBorrower == null || sim == null)
                    ? null
                    : () => _valider(
                          borrower: selectedBorrower,
                          simulation: sim,
                        ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(_decaisserImmediatement ? Icons.send_rounded : Icons.save_outlined),
                label: Text(
                  _decaisserImmediatement
                      ? 'Valider et enregistrer le prêt'
                      : 'Enregistrer le prêt en brouillon',
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, this.trailing, required this.child});
  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
              fontSize: highlight ? 15 : 13.5,
              color: highlight ? AppColors.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
