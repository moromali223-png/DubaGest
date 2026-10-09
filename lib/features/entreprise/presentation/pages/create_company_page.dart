import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/permissions/access_decision.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../domain/entities/offre_plan.dart';
import '../providers/contexte_providers.dart';

final _creationControllerProvider =
    NotifierProvider.autoDispose<FormActionController, AsyncValue<void>>(FormActionController.new);

/// « Créer mon entreprise » : nom, formule, activités. Le créateur devient
/// administrateur (côté serveur, dans la même transaction).
class CreateCompanyPage extends ConsumerStatefulWidget {
  const CreateCompanyPage({super.key});

  @override
  ConsumerState<CreateCompanyPage> createState() => _CreateCompanyPageState();
}

class _CreateCompanyPageState extends ConsumerState<CreateCompanyPage> {
  final _formKey = GlobalKey<FormState>();
  final _nom = TextEditingController();
  OffrePlan? _offre;
  final Set<ActiviteCode> _activites = {};

  @override
  void dispose() {
    _nom.dispose();
    super.dispose();
  }

  void _choisirOffre(OffrePlan offre) => setState(() {
        _offre = offre;
        // Garde une sélection compatible avec la nouvelle formule.
        _activites.retainAll(offre.activites);
        while (_activites.length > offre.maxActivites) {
          _activites.remove(_activites.last);
        }
      });

  void _basculer(ActiviteCode a, OffrePlan offre) => setState(() {
        if (_activites.contains(a)) {
          _activites.remove(a);
        } else {
          if (offre.maxActivites == 1) _activites.clear();
          if (_activites.length < offre.maxActivites) _activites.add(a);
        }
      });

  Future<void> _submit(OffrePlan offre) async {
    if (!_formKey.currentState!.validate()) return;
    final creer = ref.read(creerEntrepriseProvider);
    final ok = await ref.read(_creationControllerProvider.notifier).run(
          () => creer(nom: _nom.text, offre: offre, activites: _activites),
        );
    // Le contexte rechargé contient l'entreprise : le routeur ouvre l'application.
    if (ok) await ref.read(contexteSessionProvider.notifier).rafraichir();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final offres = ref.watch(offresPlanProvider);
    final action = ref.watch(_creationControllerProvider);
    ref.listen(_creationControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) showFailureSnackBar(context, error);
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.onboardingCreateTitle)),
      body: ResponsiveBody(
        child: AsyncValueView(
          value: offres,
          onRetry: () => ref.invalidate(offresPlanProvider),
          data: (liste) {
            final offre = _offre ?? liste.first;
            final decision = ref.read(creerEntrepriseProvider).verifier(offre, _activites);
            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  TextFormField(
                    key: const Key('company-name'),
                    controller: _nom,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: l10n.companyName),
                    validator: (v) => (v ?? '').trim().length < 2 ? l10n.ruleNameInvalid : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(l10n.companyPlan, style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<String>(
                    segments: [
                      for (final o in liste) ButtonSegment(value: o.code, label: Text(l10n.plan(o.code))),
                    ],
                    selected: {offre.code},
                    onSelectionChanged: (s) => _choisirOffre(liste.firstWhere((o) => o.code == s.first)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.companyPlanPrice(l10n.montant(offre.prixMensuel, offre.devisePrix)),
                    key: const Key('company-plan-price'),
                    style: theme.textTheme.titleMedium?.copyWith(color: AppColors.green, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(l10n.companyActivities, style: theme.textTheme.titleSmall),
                  Text(l10n.companyActivitiesHint(offre.maxActivites), style: theme.textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final a in offre.activites)
                        FilterChip(
                          key: ValueKey('activity-${a.code}'),
                          label: Text(l10n.activite(a)),
                          selected: _activites.contains(a),
                          onSelected: (_) => _basculer(a, offre),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Card(
                    color: theme.colorScheme.secondaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.workspace_premium_outlined),
                      title: Text(l10n.companyTrialInfo),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    key: const Key('company-submit'),
                    onPressed: action.isLoading || !decision.isAllowed ? null : () => _submit(offre),
                    child: action.isLoading
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l10n.companyCreateButton),
                  ),
                  if (decision case AccessDenied() when _activites.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(l10n.decision(decision),
                          style: TextStyle(color: theme.colorScheme.error)),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
