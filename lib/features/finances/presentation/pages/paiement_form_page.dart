import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../entreprise/presentation/providers/espace_providers.dart';
import '../../domain/entities/finances.dart';
import '../../domain/services/etat_finances.dart';
import '../../domain/usecases/gerer_finances.dart';
import '../providers/finances_providers.dart';
import '../widgets/finances_widgets.dart';

/// Encaisser (entrée) ou payer (sortie), en réglant une ou plusieurs
/// sommes dues du contact. [engagementId] : ouvert depuis une créance.
class PaiementFormPage extends ConsumerWidget {
  const PaiementFormPage({super.key, this.engagementId, this.sens});
  final String? engagementId;
  final SensPaiement? sens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(etatFinancesProvider);
    return switch (etat) {
      AsyncData(:final value) => _Formulaire(etat: value, engagementId: engagementId, sensInitial: sens),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(error: error),
      ),
      _ => const Scaffold(body: LoadingView()),
    };
  }
}

class _Formulaire extends ConsumerStatefulWidget {
  const _Formulaire({required this.etat, this.engagementId, this.sensInitial});
  final EtatFinances etat;
  final String? engagementId;
  final SensPaiement? sensInitial;

  @override
  ConsumerState<_Formulaire> createState() => _FormulaireState();
}

class _FormulaireState extends ConsumerState<_Formulaire> {
  final _formKey = GlobalKey<FormState>();
  final _montant = TextEditingController();
  final _reference = TextEditingController();
  final _note = TextEditingController();
  late SensPaiement _sens;
  ModePaiement _mode = ModePaiement.especes;
  String? _contactId;
  String? _sessionId;
  final Set<String> _choisis = {};
  bool _enCours = false;

  EtatFinances get _etat => widget.etat;

  @override
  void initState() {
    super.initState();
    final e = widget.engagementId == null
        ? null
        : _etat.engagements.where((x) => x.id == widget.engagementId).firstOrNull;
    _sens = e?.sens.sensReglement ?? widget.sensInitial ?? SensPaiement.entree;
    if (e != null) {
      _contactId = e.contactId;
      _choisis.add(e.id);
      _montant.text = _etat.suivi(e).reste.toString();
    }
    _sessionId = _sessionParDefaut();
  }

  @override
  void dispose() {
    _montant.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Sessions ouvertes visibles ; celle du site de travail en premier.
  List<(SessionCaisse, Caisse)> get _sessions => [
    for (final c in _etat.caisses)
      if (_etat.sessionOuverte(c.id) case final s?) (s, c),
  ];

  String? _sessionParDefaut() {
    final site = ref.read(espaceCourantProvider).perimetreId;
    final sessions = _sessions;
    return (sessions.where((x) => x.$1.perimetreId == site).firstOrNull ?? sessions.firstOrNull)?.$1.id;
  }

  /// Sommes dues ouvertes réglables par ce paiement.
  List<EngagementSuivi> get _ouverts {
    final sensEngagement = _sens == SensPaiement.entree ? SensEngagement.aRecevoir : SensEngagement.aPayer;
    return [
      for (final s in _etat.suivis)
        if (s.engagement.sens == sensEngagement &&
            !s.engagement.annule &&
            s.reste > 0 &&
            (s.engagement.contactId == _contactId || s.engagement.id == widget.engagementId) &&
            (_contactId != null || s.engagement.id == widget.engagementId))
          s,
    ];
  }

  Map<String, int> get _repartition => EnregistrerPaiement.repartir(
    ChampMontant.lire(_montant.text) ?? 0,
    _ouverts.where((s) => _choisis.contains(s.engagement.id)).toList(),
  );

  Future<void> _enregistrer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    setState(() => _enCours = true);
    try {
      final p = await ref
          .read(enregistrerPaiementProvider)
          .call(
            ctx,
            _etat,
            SaisiePaiement(
              sens: _sens,
              montant: ChampMontant.lire(_montant.text) ?? 0,
              mode: _mode,
              contactId: _contactId,
              reference: _reference.text,
              note: _note.text,
              perimetreId: _mode.passeParCaisse && _sessionId != null
                  ? null
                  : ref.read(espaceCourantProvider).perimetreId,
              sessionId: _mode.passeParCaisse ? _sessionId : null,
              affectations: _repartition,
            ),
          );
      if (!mounted) return;
      showMessageSnackBar(context, context.l10n.paymentSaved);
      context.pushReplacement(Routes.paiement(p.id));
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final droits = ref.watch(droitsFinancesProvider);
    final devise = ref.watch(deviseProvider);
    final modes = ref.watch(modesPaiementProvider);
    // Mode retiré par l'entreprise (ou profil lu après coup) : le premier proposé.
    if (!modes.contains(_mode)) _mode = modes.first;
    final ouverts = _ouverts;
    final repartition = _repartition;
    final montant = ChampMontant.lire(_montant.text) ?? 0;
    final affecte = repartition.values.fold(0, (t, m) => t + m);
    const espace = SizedBox(height: AppSpacing.md);

    return Scaffold(
      appBar: AppBar(title: Text(_sens == SensPaiement.entree ? l10n.paymentNewIn : l10n.paymentNewOut)),
      body: ResponsiveBody(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (droits.decaisser && widget.engagementId == null) ...[
                SegmentedButton<SensPaiement>(
                  segments: [
                    ButtonSegment(
                      value: SensPaiement.entree,
                      icon: const Icon(Icons.south_west),
                      label: Text(l10n.paymentIn),
                    ),
                    ButtonSegment(
                      value: SensPaiement.sortie,
                      icon: const Icon(Icons.north_east),
                      label: Text(l10n.paymentOut),
                    ),
                  ],
                  selected: {_sens},
                  onSelectionChanged: (s) => setState(() {
                    _sens = s.first;
                    _choisis.clear();
                  }),
                ),
                espace,
              ],
              ChampContact(
                contactId: _contactId,
                label: _sens == SensPaiement.entree ? l10n.paymentFrom : l10n.paymentTo,
                onChanged: (id) => setState(() {
                  _contactId = id;
                  _choisis
                    ..clear()
                    ..addAll(_ouverts.map((s) => s.engagement.id));
                }),
              ),
              espace,
              ChampMontant(
                key: const Key('paiement-montant'),
                controller: _montant,
                label: l10n.paymentAmount,
                autofocus: widget.engagementId == null,
                onChanged: (_) => setState(() {}),
              ),
              espace,
              Text(l10n.paymentMode, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final m in modes)
                    ChoiceChip(
                      key: Key('mode-${m.code}'),
                      label: Text(l10n.modePaiement(m)),
                      selected: _mode == m,
                      onSelected: (_) => setState(() => _mode = m),
                    ),
                ],
              ),
              if (_mode.passeParCaisse) ...[
                espace,
                DropdownButtonFormField<String?>(
                  key: const Key('paiement-caisse'),
                  initialValue: _sessionId,
                  decoration: InputDecoration(
                    labelText: l10n.paymentCashRegister,
                    prefixIcon: const Icon(Icons.point_of_sale_outlined),
                  ),
                  items: [
                    for (final (s, c) in _sessions) DropdownMenuItem(value: s.id, child: Text(c.nom)),
                    DropdownMenuItem(value: null, child: Text(l10n.paymentNoCashRegister)),
                  ],
                  onChanged: (v) => setState(() => _sessionId = v),
                ),
                if (_sessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(l10n.paymentNoOpenRegister, style: const TextStyle(color: AppColors.warning)),
                  ),
              ],
              if (ouverts.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  _sens == SensPaiement.entree ? l10n.paymentSettlesReceivables : l10n.paymentSettlesPayables,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.sm),
                Card(
                  child: Column(
                    children: [
                      for (final s in ouverts)
                        CheckboxListTile(
                          key: Key('affecter-${s.engagement.id}'),
                          value: _choisis.contains(s.engagement.id),
                          onChanged: (v) => setState(
                            () => v == true ? _choisis.add(s.engagement.id) : _choisis.remove(s.engagement.id),
                          ),
                          title: Text(s.engagement.libelle),
                          subtitle: Text(l10n.paymentRemainingOf(l10n.montant(s.reste, devise))),
                          secondary: repartition[s.engagement.id] == null
                              ? null
                              : Montant(repartition[s.engagement.id]!, signe: _sens == SensPaiement.entree),
                        ),
                    ],
                  ),
                ),
                if (montant > affecte && affecte > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.paymentUnallocated(l10n.montant(montant - affecte, devise)),
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
              ],
              espace,
              TextFormField(
                controller: _reference,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: l10n.paymentReference,
                  hintText: l10n.paymentReferenceHint,
                  counterText: '',
                ),
              ),
              espace,
              TextFormField(
                controller: _note,
                maxLength: 500,
                maxLines: 2,
                decoration: InputDecoration(labelText: l10n.paymentNote, counterText: ''),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                key: const Key('paiement-enregistrer'),
                onPressed: _enCours ? null : _enregistrer,
                icon: _enCours
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: Text(
                  montant == 0
                      ? l10n.commonSave
                      : (_sens == SensPaiement.entree
                            ? l10n.paymentConfirmIn(l10n.montant(montant, devise))
                            : l10n.paymentConfirmOut(l10n.montant(montant, devise))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
