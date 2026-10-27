import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/permissions/access_decision.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../authentication/presentation/widgets/duba_gest_brand_logo.dart';
import '../../domain/entities/offre_plan.dart';
import '../providers/contexte_providers.dart';

final _creationControllerProvider =
    NotifierProvider.autoDispose<FormActionController, AsyncValue<void>>(FormActionController.new);

/// « Créer mon entreprise » : nom, formule d'abonnement, activités métiers.
class CreateCompanyPage extends ConsumerStatefulWidget {
  const CreateCompanyPage({super.key});

  @override
  ConsumerState<CreateCompanyPage> createState() => _CreateCompanyPageState();
}

class _CreateCompanyPageState extends ConsumerState<CreateCompanyPage> {
  final _formKey = GlobalKey<FormState>();
  final _nom = TextEditingController();
  int _step = 1;
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

  void _continuerVersEtape2(OffrePlan offre) {
    if (!_formKey.currentState!.validate()) return;
    // Si aucune activité n'est sélectionnée, pré-sélectionner par défaut la première activité
    if (_activites.isEmpty && offre.activites.isNotEmpty) {
      _activites.add(offre.activites.first);
    }
    setState(() => _step = 2);
  }

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
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 860;

    ref.listen(_creationControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) showFailureSnackBar(context, error);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _step == 2
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Retour',
                onPressed: () => setState(() => _step = 1),
              )
            : null,
        title: const DubaGestBrandLogo(size: 32, showText: true),
        centerTitle: false,
      ),
      body: ResponsiveBody(
        maxWidth: 920,
        child: AsyncValueView(
          value: offres,
          onRetry: () => ref.invalidate(offresPlanProvider),
          data: (liste) {
            final offre = _offre ?? liste.first;
            final decision = ref.read(creerEntrepriseProvider).verifier(offre, _activites);

            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                children: [
                  // Barre de progression simplifiée et plus élégante
                  _StepProgressBar(
                    currentStep: _step,
                    step1Label: 'Identité',
                    step2Label: 'Activités',
                    onStepTap: (step) {
                      if (step == 1) {
                        setState(() => _step = 1);
                      } else if (_formKey.currentState?.validate() ?? false) {
                        _continuerVersEtape2(offre);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // =======================
                  // ÉTAPE 1 : NOM & FORMULE
                  // =======================
                  if (_step == 1) ...[
                    // En-tête épuré
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.onboardingCreateTitle,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configurez votre espace de travail en quelques secondes.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Nom de l'entreprise
                    Text(
                      l10n.companyName,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ce nom figurera sur vos devis, factures, reçus et contrats.',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      key: const Key('company-name'),
                      controller: _nom,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: l10n.companyName,
                        hintText: 'Ex: Duba Trading SARL',
                        prefixIcon: const Icon(Icons.storefront_rounded, color: AppColors.muted, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.green, width: 2),
                        ),
                      ),
                      validator: (v) => (v ?? '').trim().length < 2 ? l10n.ruleNameInvalid : null,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Formule d'abonnement
                    Text(
                      l10n.companyPlan,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sélectionnez une formule adaptée à votre volume d\'activités.',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Cartes comparatives des formules
                    if (isDesktop)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final o in liste) ...[
                              Expanded(
                                child: _PlanCard(
                                  plan: o,
                                  isSelected: offre.code == o.code,
                                  priceFormatted: l10n.companyPlanPrice(l10n.montant(o.prixMensuel, o.devisePrix)),
                                  planLabel: l10n.plan(o.code),
                                  onSelect: () => _choisirOffre(o),
                                ),
                              ),
                              if (o != liste.last) const SizedBox(width: AppSpacing.md),
                            ],
                          ],
                        ),
                      )
                    else
                      // Version Mobile : Sélecteur compact et dynamique
                      // Évite de devoir glisser de haut en bas indéfiniment
                      Column(
                        children: [
                          for (final o in liste) ...[
                            _CompactPlanTile(
                              plan: o,
                              isSelected: offre.code == o.code,
                              priceFormatted: l10n.companyPlanPrice(l10n.montant(o.prixMensuel, o.devisePrix)),
                              planLabel: l10n.plan(o.code),
                              onSelect: () => _choisirOffre(o),
                            ),
                            if (o != liste.last) const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    const SizedBox(height: AppSpacing.md),

                    // Récapitulatif tarifaire sélectionné & avantages (anti-overflow garanti)
                    _SelectedPlanSummaryCard(
                      plan: offre,
                      planLabel: l10n.plan(offre.code),
                      priceFormatted: l10n.companyPlanPrice(l10n.montant(offre.prixMensuel, offre.devisePrix)),
                      isDesktop: isDesktop,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Bouton Continuer vers Étape 2
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () => _continuerVersEtape2(offre),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Continuer vers les activités',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  ],

                  // ==========================
                  // ÉTAPE 2 : ACTIVITÉS & FIN
                  // ==========================
                  if (_step == 2) ...[
                    // Résumé de l'étape 1 cliquable pour modifier
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.greenLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded, color: AppColors.green, size: 20),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _nom.text.trim().isEmpty ? 'Nom de l\'entreprise' : _nom.text.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.ink),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Formule ${l10n.plan(offre.code)} • ${l10n.companyPlanPrice(l10n.montant(offre.prixMensuel, offre.devisePrix))}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.green,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            onPressed: () => setState(() => _step = 1),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Modifier', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Section Activités métiers
                    _SectionHeader(
                      stepNumber: '2',
                      title: l10n.companyActivities,
                      subtitle: '${l10n.companyActivitiesHint(offre.maxActivites)} (sélectionnées : ${_activites.length} / ${offre.maxActivites})',
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Cartes d'activités avec icônes et descriptions
                    Column(
                      children: [
                        for (final a in offre.activites)
                          _ActiviteCard(
                            key: ValueKey('activity-${a.code}'),
                            activite: a,
                            label: l10n.activite(a),
                            isSelected: _activites.contains(a),
                            onTap: () => _basculer(a, offre),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Bannière Essai Gratuit & Sécurité
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: AppColors.greenLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.workspace_premium_rounded, color: AppColors.green, size: 24),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.companyTrialInfo,
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Aucun prélèvement immédiat • Annulation sans frais à tout moment.',
                                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Ligne de boutons action
                    Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(120, 52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: const BorderSide(color: AppColors.border),
                            foregroundColor: AppColors.ink,
                          ),
                          onPressed: () => setState(() => _step = 1),
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text('Précédent', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: FilledButton(
                            key: const Key('company-submit'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              backgroundColor: AppColors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            onPressed: action.isLoading || !decision.isAllowed ? null : () => _submit(offre),
                            child: action.isLoading
                                ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                                : Text(
                                    l10n.companyCreateButton,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    if (decision case AccessDenied() when _activites.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          l10n.decision(decision),
                          style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Indicateur d'étapes (Stepper visuel moderne)
class _StepProgressBar extends StatelessWidget {
  const _StepProgressBar({
    required this.currentStep,
    required this.step1Label,
    required this.step2Label,
    required this.onStepTap,
  });

  final int currentStep;
  final String step1Label;
  final String step2Label;
  final ValueChanged<int> onStepTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _StepItem(
            label: step1Label,
            stepNumber: 1,
            isActive: currentStep == 1,
            isCompleted: currentStep > 1,
            onTap: () => onStepTap(1),
          ),
          _StepItem(
            label: step2Label,
            stepNumber: 2,
            isActive: currentStep == 2,
            isCompleted: false,
            onTap: () => onStepTap(2),
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.label,
    required this.stepNumber,
    required this.isActive,
    required this.isCompleted,
    required this.onTap,
  });

  final String label;
  final int stepNumber;
  final bool isActive;
  final bool isCompleted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isActive || isCompleted ? AppColors.green : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive || isCompleted ? AppColors.green : AppColors.muted,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 12)
                      : Text(
                          stepNumber.toString(),
                          style: TextStyle(
                            color: isActive ? Colors.white : AppColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? AppColors.ink : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.stepNumber,
    required this.title,
    required this.subtitle,
  });

  final String stepNumber;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.green,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  stepNumber,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.priceFormatted,
    required this.planLabel,
    required this.onSelect,
  });

  final OffrePlan plan;
  final bool isSelected;
  final String priceFormatted;
  final String planLabel;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final isPro = plan.code == 'PRO';
    final isMoyen = plan.code == 'MOYEN';

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppColors.green : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected ? AppColors.green.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.03),
            blurRadius: isSelected ? 16 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      planLabel,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? AppColors.green : AppColors.ink,
                      ),
                    ),
                    if (isPro || isMoyen)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPro ? AppColors.green : const Color(0xFFE0E7FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isPro ? 'RECOMMANDÉ' : 'POPULAIRE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isPro ? Colors.white : const Color(0xFF3730A3),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  priceFormatted,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.green,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  plan.maxActivites == 1
                      ? '1 activité incluse'
                      : '${plan.maxActivites} activités combinées',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: AppSpacing.sm),
                _FeatureItem('Mode 100% hors-ligne & synchronisation'),
                _FeatureItem('Multi-utilisateurs & autorisations'),
                if (plan.maxActivites >= 2) _FeatureItem('Exports comptables & bilans avancés'),
                if (plan.maxActivites >= 3) _FeatureItem('Support dédié prioritaire 7j/7'),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.greenLight : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        size: 16,
                        color: isSelected ? AppColors.green : AppColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isSelected ? 'Formule active' : 'Sélectionner',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? AppColors.green : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_rounded, size: 14, color: AppColors.green),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tuile de formule compacte moderne pour mobile (évite le scroll excessif)
class _CompactPlanTile extends StatelessWidget {
  const _CompactPlanTile({
    required this.plan,
    required this.isSelected,
    required this.priceFormatted,
    required this.planLabel,
    required this.onSelect,
  });

  final OffrePlan plan;
  final bool isSelected;
  final String priceFormatted;
  final String planLabel;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final isPro = plan.code == 'PRO';
    final isMoyen = plan.code == 'MOYEN';

    String subtitle;
    if (plan.maxActivites == 1) {
      subtitle = '1 activité incluse • Solo / TPE';
    } else if (plan.maxActivites == 2) {
      subtitle = '2 activités combinées';
    } else {
      subtitle = 'Activités illimitées & Multi-sites';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? AppColors.green : AppColors.border,
          width: isSelected ? 2 : 1.2,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: AppColors.green.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // Radio Custom
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.green : AppColors.muted.withValues(alpha: 0.5),
                      width: isSelected ? 7 : 2,
                    ),
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),

                // Contenu
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            planLabel,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: isSelected ? AppColors.green : AppColors.ink,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (isPro || isMoyen) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isPro ? AppColors.green : AppColors.greenSoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isPro ? 'RECOMMANDÉ' : 'POPULAIRE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: isPro ? Colors.white : AppColors.green,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Prix
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      priceFormatted.split(' ')[0], // Le montant
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? AppColors.green : AppColors.ink,
                      ),
                    ),
                    Text(
                      '/ mois',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte récapitulative dynamique de la formule sélectionnée avec protection anti-overflow
class _SelectedPlanSummaryCard extends StatelessWidget {
  const _SelectedPlanSummaryCard({
    required this.plan,
    required this.planLabel,
    required this.priceFormatted,
    this.isDesktop = false,
  });

  final OffrePlan plan;
  final String planLabel;
  final String priceFormatted;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.greenLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Formule : $planLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                priceFormatted,
                key: const Key('company-plan-price'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.green,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (!isDesktop) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFC7EBD9)),
            const SizedBox(height: 8),
            const _SummaryFeatureBullet('Mode 100% hors-ligne & synchronisation en arrière-plan'),
            const _SummaryFeatureBullet('Multi-utilisateurs & autorisations d’accès'),
            if (plan.maxActivites >= 2)
              const _SummaryFeatureBullet('Exports comptables & bilans périodiques'),
            if (plan.maxActivites >= 3)
              const _SummaryFeatureBullet('Support prioritaire VIP & accompagnement dédié'),
          ],
        ],
      ),
    );
  }
}

class _SummaryFeatureBullet extends StatelessWidget {
  const _SummaryFeatureBullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_rounded, size: 14, color: AppColors.green),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF2D3748),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiviteCard extends StatelessWidget {
  const _ActiviteCard({
    super.key,
    required this.activite,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final ActiviteCode activite;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  (IconData, String, Color) _getMeta() {
    switch (activite) {
      case ActiviteCode.commerce:
        return (
          Icons.storefront_rounded,
          'Comptoir caisse, stocks, inventaires, codes-barres et reçus officiels.',
          AppColors.green,
        );
      case ActiviteCode.services:
        return (
          Icons.design_services_rounded,
          'Catalogue de prestations, devis clients, chantiers et planning d’interventions.',
          const Color(0xFF2563EB),
        );
      case ActiviteCode.immobilier:
        return (
          Icons.apartment_rounded,
          'Gestion de biens et lots, baux locatifs, encaissement des loyers et quittances.',
          const Color(0xFFD97706),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, description, accentColor) = _getMeta();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor : AppColors.border,
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? accentColor.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: isSelected ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: accentColor, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? AppColors.ink : const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isSelected ? accentColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? accentColor : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
