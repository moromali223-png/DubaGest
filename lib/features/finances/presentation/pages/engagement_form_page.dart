import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../perimetres/presentation/providers/perimetres_providers.dart';
import '../../domain/entities/finances.dart';
import '../../domain/usecases/gerer_finances.dart';
import '../providers/finances_providers.dart';
import '../widgets/finances_widgets.dart';

/// Nouvelle créance / dette ([engagementId] nul), ou modification.
class EngagementFormPage extends ConsumerWidget {
  const EngagementFormPage({super.key, this.engagementId, this.sens = SensEngagement.aRecevoir});
  final String? engagementId;
  final SensEngagement sens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (engagementId == null) return _Formulaire(sens: sens);
    final etat = ref.watch(etatFinancesProvider);
    final e = etat.value?.engagements.where((x) => x.id == engagementId).firstOrNull;
    if (e != null) return _Formulaire(sens: e.sens, suivi: etat.value!.suivi(e));
    return Scaffold(
      appBar: AppBar(),
      body: etat.isLoading ? const LoadingView() : EmptyView(message: context.l10n.financeNotFound),
    );
  }
}

class _Formulaire extends ConsumerStatefulWidget {
  const _Formulaire({required this.sens, this.suivi});
  final SensEngagement sens;
  final EngagementSuivi? suivi;

  @override
  ConsumerState<_Formulaire> createState() => _FormulaireState();
}

class _FormulaireState extends ConsumerState<_Formulaire> {
  final _formKey = GlobalKey<FormState>();
  Engagement? get _initial => widget.suivi?.engagement;
  late final _libelle = TextEditingController(text: _initial?.libelle);
  late final _montant = TextEditingController(text: _initial?.montantTotal.toString());
  late String? _contactId = _initial?.contactId;
  late DateTime? _echeance = _initial?.echeance;
  late String? _perimetreId = _initial?.perimetreId;
  bool _enCours = false;

  @override
  void dispose() {
    _libelle.dispose();
    _montant.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    final saisie = SaisieEngagement(
      sens: widget.sens,
      libelle: _libelle.text,
      montant: ChampMontant.lire(_montant.text) ?? 0,
      contactId: _contactId,
      echeance: _echeance,
      perimetreId: _perimetreId,
    );
    setState(() => _enCours = true);
    try {
      if (widget.suivi == null) {
        final e = await ref.read(creerEngagementProvider).call(ctx, saisie);
        if (!mounted) return;
        context.pushReplacement(Routes.engagement(e.id));
      } else {
        await ref.read(modifierEngagementProvider).call(ctx, widget.suivi!, saisie);
        if (mounted) context.pop();
      }
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final recevoir = widget.sens == SensEngagement.aRecevoir;
    final sites = ref.watch(perimetresProvider).value ?? const [];
    const espace = SizedBox(height: AppSpacing.md);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.suivi != null ? l10n.debtEdit : (recevoir ? l10n.debtNewReceivable : l10n.debtNewPayable)),
      ),
      body: ResponsiveBody(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              ChampContact(
                contactId: _contactId,
                label: recevoir ? l10n.debtWhoOwes : l10n.debtOwedTo,
                onChanged: (id) => setState(() => _contactId = id),
              ),
              espace,
              TextFormField(
                key: const Key('engagement-libelle'),
                controller: _libelle,
                maxLength: 200,
                decoration: InputDecoration(labelText: l10n.debtLabel, hintText: l10n.debtLabelHint, counterText: ''),
                validator: (v) => (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
              ),
              espace,
              ChampMontant(key: const Key('engagement-montant'), controller: _montant, label: l10n.debtTotal),
              if ((widget.suivi?.regle ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.debtAlreadyPaid(l10n.montant(widget.suivi!.regle, ref.watch(deviseProvider))),
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
              espace,
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _echeance ?? DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _echeance = d);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.debtDueDate,
                    prefixIcon: const Icon(Icons.event_outlined),
                    suffixIcon: _echeance == null
                        ? null
                        : IconButton(
                            tooltip: l10n.commonClear,
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _echeance = null),
                          ),
                  ),
                  child: Text(_echeance == null ? l10n.debtNoDueDate : l10n.date(_echeance!)),
                ),
              ),
              if (widget.suivi == null && sites.isNotEmpty) ...[
                espace,
                DropdownButtonFormField<String?>(
                  initialValue: _perimetreId,
                  decoration: InputDecoration(
                    labelText: l10n.financeSite,
                    prefixIcon: const Icon(Icons.storefront_outlined),
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text(l10n.financeAllSites)),
                    for (final p in sites) DropdownMenuItem(value: p.id, child: Text(p.nom)),
                  ],
                  onChanged: (v) => setState(() => _perimetreId = v),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                key: const Key('engagement-enregistrer'),
                onPressed: _enCours ? null : _enregistrer,
                child: _enCours
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.commonSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
