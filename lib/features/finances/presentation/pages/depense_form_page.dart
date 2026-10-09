import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/forms/forms.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../entreprise/presentation/providers/espace_providers.dart';
import '../../domain/entities/finances.dart';
import '../../domain/services/etat_finances.dart';
import '../../domain/usecases/gerer_depenses.dart';
import '../providers/finances_providers.dart';
import '../widgets/finances_widgets.dart';

/// Nouvelle dépense : payée maintenant (mode, caisse) ou à payer plus tard.
class DepenseFormPage extends ConsumerWidget {
  const DepenseFormPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (ref.watch(etatFinancesProvider)) {
    AsyncData(:final value) => _Formulaire(etat: value),
    AsyncError(:final error) => Scaffold(
      appBar: AppBar(),
      body: ErrorView(error: error),
    ),
    _ => const Scaffold(body: LoadingView()),
  };
}

class _Formulaire extends ConsumerStatefulWidget {
  const _Formulaire({required this.etat});
  final EtatFinances etat;

  @override
  ConsumerState<_Formulaire> createState() => _FormulaireState();
}

class _FormulaireState extends ConsumerState<_Formulaire> {
  final _formKey = GlobalKey<FormState>();
  final _formController = SmartFormController(initialOpenIndex: 0);

  final _montant = TextEditingController();
  final _libelle = TextEditingController();
  final _reference = TextEditingController();
  String? _categorieId;
  String? _contactId;
  bool _payeeMaintenant = true;
  ModePaiement _mode = ModePaiement.especes;
  String? _sessionId;
  DateTime _date = DateTime.now();
  DateTime? _echeance;
  bool _enCours = false;
  bool _aEteModifie = false;

  EtatFinances get _etat => widget.etat;

  List<(SessionCaisse, Caisse)> get _sessions => [
    for (final c in _etat.caisses)
      if (_etat.sessionOuverte(c.id) case final s?) (s, c),
  ];

  @override
  void initState() {
    super.initState();
    final site = ref.read(espaceCourantProvider).perimetreId;
    final sessions = _sessions;
    _sessionId = (sessions.where((x) => x.$1.perimetreId == site).firstOrNull ?? sessions.firstOrNull)?.$1.id;
    _payeeMaintenant = ref.read(droitsFinancesProvider).encaisser;

    for (final c in [_montant, _libelle, _reference]) {
      c.addListener(() {
        if (!_aEteModifie) setState(() => _aEteModifie = true);
      });
    }
  }

  @override
  void dispose() {
    _formController.dispose();
    _montant.dispose();
    _libelle.dispose();
    _reference.dispose();
    super.dispose();
  }

  // --- Statuts et Résumés dynamiques des sections ---
  FormSectionStatus get _montantStatus {
    final m = ChampMontant.lire(_montant.text);
    if (m == null || m <= 0 || _categorieId == null) {
      return FormSectionStatus.emptyRequired;
    }
    return FormSectionStatus.complete;
  }

  String _montantSummary(AppLocalizations l10n, String devise) {
    final m = ChampMontant.lire(_montant.text);
    final cat = _categorieId != null
        ? _etat.categories.where((c) => c.id == _categorieId).firstOrNull
        : null;
    final catNom = cat != null ? l10n.categorieDepense(cat) : 'Catégorie non choisie';
    if (m == null || m <= 0) return 'Montant * • $catNom';
    return '${l10n.montant(m, devise)} • $catNom';
  }

  FormSectionStatus get _detailsStatus {
    if (_libelle.text.trim().isEmpty) return FormSectionStatus.emptyRequired;
    return FormSectionStatus.complete;
  }

  String _detailsSummary(AppLocalizations l10n) {
    final lib = _libelle.text.trim();
    final dateStr = l10n.date(_date);
    if (lib.isEmpty) return 'Motif de la dépense obligatoire • $dateStr';
    return '$lib • $dateStr';
  }

  FormSectionStatus get _reglementStatus => FormSectionStatus.complete;

  String _reglementSummary(AppLocalizations l10n, String devise) {
    if (!_payeeMaintenant) {
      if (_echeance == null) return 'À payer plus tard (Dette à régler)';
      return 'À payer le ${l10n.date(_echeance!)} (Dette à régler)';
    }
    final modeNom = l10n.modePaiement(_mode);
    if (_mode.passeParCaisse) {
      final session = _sessions.where((s) => s.$1.id == _sessionId).firstOrNull;
      if (session != null) {
        return '$modeNom • Caisse ${session.$2.nom}';
      }
      return '$modeNom • Sans caisse';
    }
    return modeNom;
  }

  FormSectionStatus get _beneficiaireStatus {
    if (_contactId != null || _reference.text.trim().isNotEmpty) return FormSectionStatus.complete;
    return FormSectionStatus.emptyOptional;
  }

  String get _beneficiaireSummary {
    final elements = [
      if (_contactId != null)
        (ref.read(contactsParIdProvider).value?[_contactId]?.nomAffiche ?? 'Fournisseur sélectionné')
      else
        'Sans contact',
      if (_reference.text.trim().isNotEmpty) 'Réf: ${_reference.text.trim()}',
    ];
    return elements.join(' • ');
  }

  Future<void> _enregistrer() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      if (ChampMontant.lire(_montant.text) == null || _categorieId == null) {
        _formController.scrollToSection(0);
      } else if (_libelle.text.trim().isEmpty) {
        _formController.scrollToSection(1);
      }
      return;
    }
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    setState(() => _enCours = true);
    try {
      final especesEnCaisse = _payeeMaintenant && _mode.passeParCaisse && _sessionId != null;
      final d = await ref
          .read(enregistrerDepenseProvider)
          .call(
            ctx,
            _etat,
            SaisieDepense(
              categorieId: _categorieId!,
              libelle: _libelle.text,
              montant: ChampMontant.lire(_montant.text) ?? 0,
              payeeMaintenant: _payeeMaintenant,
              date: _date,
              contactId: _contactId,
              perimetreId: especesEnCaisse ? null : ref.read(espaceCourantProvider).perimetreId,
              mode: _mode,
              sessionId: especesEnCaisse ? _sessionId : null,
              echeance: _echeance,
              reference: _reference.text,
            ),
          );
      if (!mounted) return;
      _aEteModifie = false;
      showMessageSnackBar(context, context.l10n.expenseSaved);
      context.pushReplacement(Routes.depense(d.id));
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<DateTime?> _choisirDate(DateTime initiale, {bool futur = false}) => showDatePicker(
    context: context,
    initialDate: initiale,
    firstDate: DateTime(2000),
    lastDate: futur ? DateTime(2100) : DateTime.now(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final droits = ref.watch(droitsFinancesProvider);
    final categories = _etat.categories.where((c) => c.estActive).toList();
    final modes = ref.watch(modesPaiementProvider);
    final devise = ref.watch(deviseProvider);
    if (!modes.contains(_mode)) _mode = modes.first;
    const espace = SizedBox(height: AppSpacing.md);

    return UnsavedChangesScope(
      hasUnsavedChanges: _aEteModifie && !_enCours,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text(l10n.expenseNew)),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SmartFormContainer(
                    controller: _formController,
                    children: [
                      // Section 1 : Montant & Catégorie (Obligatoire)
                      CollapsibleFormSection(
                        key: _formController.registerSectionKey(0),
                        title: 'Montant & Catégorie',
                        icon: Icons.payments_rounded,
                        summary: _montantSummary(l10n, devise),
                        status: _montantStatus,
                        isRequired: true,
                        isExpanded: _formController.isSectionOpen(0),
                        onToggle: () => setState(() => _formController.toggleSection(0)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ChampMontant(
                              key: const Key('depense-montant'),
                              controller: _montant,
                              label: '${l10n.paymentAmount} *',
                              autofocus: true,
                              onChanged: (_) => setState(() => _aEteModifie = true),
                            ),
                            espace,
                            Text(
                              '${l10n.expenseCategory} *',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            FormField<String>(
                              initialValue: _categorieId,
                              validator: (_) => _categorieId == null ? l10n.validationRequired : null,
                              builder: (field) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: AppSpacing.sm,
                                    runSpacing: AppSpacing.sm,
                                    children: [
                                      for (final c in categories)
                                        ChoiceChip(
                                          key: Key('depense-categorie-${c.code ?? c.id}'),
                                          avatar: Icon(iconeCategorie(c), size: 18),
                                          label: Text(l10n.categorieDepense(c)),
                                          selected: _categorieId == c.id,
                                          onSelected: (_) {
                                            setState(() {
                                              _categorieId = c.id;
                                              _aEteModifie = true;
                                            });
                                            field.didChange(c.id);
                                          },
                                        ),
                                    ],
                                  ),
                                  if (field.hasError)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        field.errorText!,
                                        style: const TextStyle(color: AppColors.negative, fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Section 2 : Motif & Date (Obligatoire)
                      CollapsibleFormSection(
                        key: _formController.registerSectionKey(1),
                        title: 'Motif & Date',
                        icon: Icons.edit_calendar_rounded,
                        summary: _detailsSummary(l10n),
                        status: _detailsStatus,
                        isRequired: true,
                        isExpanded: _formController.isSectionOpen(1),
                        onToggle: () => setState(() => _formController.toggleSection(1)),
                        child: Column(
                          children: [
                            TextFormField(
                              key: const Key('depense-libelle'),
                              controller: _libelle,
                              maxLength: 200,
                              decoration: InputDecoration(
                                labelText: '${l10n.expenseLabel} *',
                                hintText: l10n.expenseLabelHint,
                                counterText: '',
                              ),
                              validator: (v) => (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
                            ),
                            espace,
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                final d = await _choisirDate(_date);
                                if (d != null) {
                                  setState(() {
                                    _date = d;
                                    _aEteModifie = true;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: l10n.expenseDate,
                                  prefixIcon: const Icon(Icons.event_outlined),
                                ),
                                child: Text(l10n.date(_date)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Section 3 : Règlement & Caisse
                      CollapsibleFormSection(
                        key: _formController.registerSectionKey(2),
                        title: 'Mode de règlement & Caisse',
                        icon: Icons.account_balance_wallet_rounded,
                        summary: _reglementSummary(l10n, devise),
                        status: _reglementStatus,
                        isExpanded: _formController.isSectionOpen(2),
                        onToggle: () => setState(() => _formController.toggleSection(2)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SegmentedButton<bool>(
                              segments: [
                                ButtonSegment(
                                  value: true,
                                  enabled: droits.encaisser,
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: Text(l10n.expensePaidNow),
                                ),
                                ButtonSegment(
                                  value: false,
                                  icon: const Icon(Icons.schedule),
                                  label: Text(l10n.expensePayLater),
                                ),
                              ],
                              selected: {_payeeMaintenant},
                              onSelectionChanged: (s) => setState(() {
                                _payeeMaintenant = s.first;
                                _aEteModifie = true;
                              }),
                            ),
                            espace,
                            if (_payeeMaintenant) ...[
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: [
                                  for (final m in modes)
                                    ChoiceChip(
                                      key: Key('depense-mode-${m.code}'),
                                      label: Text(l10n.modePaiement(m)),
                                      selected: _mode == m,
                                      onSelected: (_) => setState(() {
                                        _mode = m;
                                        _aEteModifie = true;
                                      }),
                                    ),
                                ],
                              ),
                              if (_mode.passeParCaisse) ...[
                                espace,
                                DropdownButtonFormField<String?>(
                                  key: const Key('depense-caisse'),
                                  initialValue: _sessionId,
                                  decoration: InputDecoration(
                                    labelText: l10n.paymentCashRegister,
                                    prefixIcon: const Icon(Icons.point_of_sale_outlined),
                                  ),
                                  items: [
                                    for (final (s, c) in _sessions)
                                      DropdownMenuItem(
                                        value: s.id,
                                        child: Text('${c.nom} · ${l10n.montant(_etat.solde(s), devise)}'),
                                      ),
                                    DropdownMenuItem(value: null, child: Text(l10n.paymentNoCashRegister)),
                                  ],
                                  onChanged: (v) => setState(() {
                                    _sessionId = v;
                                    _aEteModifie = true;
                                  }),
                                ),
                              ],
                            ] else ...[
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  final d = await _choisirDate(
                                    _echeance ?? DateTime.now().add(const Duration(days: 30)),
                                    futur: true,
                                  );
                                  if (d != null) {
                                    setState(() {
                                      _echeance = d;
                                      _aEteModifie = true;
                                    });
                                  }
                                },
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: l10n.debtDueDate,
                                    prefixIcon: const Icon(Icons.event_outlined),
                                  ),
                                  child: Text(_echeance == null ? l10n.debtNoDueDate : l10n.date(_echeance!)),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF01226C).withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF01226C).withValues(alpha: 0.12)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF01226C)),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Cette dépense non payée sera enregistrée dans les Dettes (« À payer »).',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF01226C),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Section 4 : Bénéficiaire & Référence (Facultatif)
                      CollapsibleFormSection(
                        key: _formController.registerSectionKey(3),
                        title: 'Bénéficiaire & Référence',
                        icon: Icons.receipt_long_rounded,
                        summary: _beneficiaireSummary,
                        status: _beneficiaireStatus,
                        isExpanded: _formController.isSectionOpen(3),
                        onToggle: () => setState(() => _formController.toggleSection(3)),
                        child: Column(
                          children: [
                            ChampContact(
                              contactId: _contactId,
                              label: '${l10n.expenseSupplier} (Facultatif)',
                              relation: RelationContact.fournisseur,
                              onChanged: (id) => setState(() {
                                _contactId = id;
                                _aEteModifie = true;
                              }),
                            ),
                            espace,
                            TextFormField(
                              controller: _reference,
                              maxLength: 100,
                              decoration: InputDecoration(
                                labelText: l10n.paymentReference,
                                hintText: l10n.expenseReferenceHint,
                                prefixIcon: const Icon(Icons.tag_rounded),
                                counterText: '',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Barre d'actions fixe
              StickyFormActions(
                submitKey: const Key('depense-enregistrer'),
                onSubmit: _enCours ? null : _enregistrer,
                onCancel: () => Navigator.of(context).maybePop(),
                isLoading: _enCours,
                submitLabel: l10n.commonSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

