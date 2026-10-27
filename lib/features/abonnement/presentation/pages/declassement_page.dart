import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../perimetres/domain/entities/perimetre.dart';
import '../../../perimetres/presentation/providers/perimetres_providers.dart';
import '../../../utilisateurs/presentation/providers/membres_providers.dart';
import '../../domain/entities/abonnement.dart';
import '../../domain/entities/declassement_models.dart';
import '../providers/declassement_providers.dart';

class DeclassementPage extends ConsumerStatefulWidget {
  const DeclassementPage({super.key});

  @override
  ConsumerState<DeclassementPage> createState() => _DeclassementPageState();
}

class _DeclassementPageState extends ConsumerState<DeclassementPage> {
  String? _selectedPlanCible;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initPage());
  }

  Future<void> _initPage() async {
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;

    final currentPlan = ctx.abonnement?.planCode ?? 'NORMAL';
    // Vérifier si une demande est déjà enregistrée
    final demandeExistante = await ref.read(demandeDeclassementEnCoursProvider.future);
    if (demandeExistante != null) {
      _selectedPlanCible = demandeExistante.planCibleCode;
      await ref.read(declassementNotifierProvider.notifier).chargerOuDemander(demandeExistante.planCibleCode);
    } else {
      // Déterminer le plan cible par défaut
      if (currentPlan == 'PRO') {
        _selectedPlanCible = 'MOYEN';
      } else if (currentPlan == 'MOYEN') {
        _selectedPlanCible = 'PRO';
      } else {
        _selectedPlanCible = 'MOYEN';
      }
      if (_selectedPlanCible != null) {
        await ref.read(declassementNotifierProvider.notifier).chargerOuDemander(_selectedPlanCible!);
      }
    }
  }

  void _onPlanSelected(String planCode) {
    setState(() => _selectedPlanCible = planCode);
    ref.read(declassementNotifierProvider.notifier).chargerOuDemander(planCode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ctx = ref.watch(contexteActifProvider);
    final state = ref.watch(declassementNotifierProvider);

    if (ctx == null) {
      return const Scaffold(body: LoadingView());
    }

    final currentPlanCode = ctx.abonnement?.planCode ?? 'NORMAL';

    // Tous les plans cibles disponibles (hors formule actuelle)
    final tousLesPlans = ['NORMAL', 'MOYEN', 'PRO'];
    final plansCibles = tousLesPlans.where((p) => p != currentPlanCode).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Changer de formule'),
      ),
      body: state.chargement && state.analyse == null
          ? const LoadingView(message: 'Analyse des formules en cours...')
          : ResponsiveBody(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  // Bannière informative
                  _buildHeaderBanner(context, ctx, currentPlanCode),
                  const SizedBox(height: AppSpacing.md),

                  // Sélection du plan cible
                  _buildSectionHeader('1. Choisissez la nouvelle formule'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildPlanSelector(context, plansCibles, currentPlanCode, state),
                  const SizedBox(height: AppSpacing.lg),

                  if (state.erreur != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: theme.colorScheme.error),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              state.erreur!,
                              style: TextStyle(color: theme.colorScheme.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  if (state.messageSucces != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              state.messageSucces!,
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  if (state.analyse != null) ...[
                    if (state.analyse!.estSurclassement) ...[
                      _buildSectionHeader('2. Avantages & Privilèges débloqués'),
                      const SizedBox(height: AppSpacing.sm),
                      _buildSurclassementCard(context, state.analyse!),
                      const SizedBox(height: AppSpacing.lg),
                    ] else ...[
                      _buildSectionHeader('2. Checklist de conformité des limites'),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Ajustez vos ressources pour respecter les quotas de la formule cible. Aucune donnée historique ne sera supprimée.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Statut global et barre de progression
                      _buildConformiteStatusBar(context, state.analyse!),
                      const SizedBox(height: AppSpacing.md),

                      // Cartes de préparation par critère
                      _buildUtilisateursCard(context, state.analyse!),
                      const SizedBox(height: AppSpacing.md),

                      _buildPerimetresCard(context, state.analyse!),
                      const SizedBox(height: AppSpacing.md),

                      _buildActivitesCard(context, state.analyse!),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // Récapitulatif et engagement financier
                    _buildFinancialSummary(context, state.analyse!),
                    const SizedBox(height: AppSpacing.lg),

                    // Boutons d'action
                    _buildActionButtons(context, state),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderBanner(BuildContext context, dynamic ctx, String currentPlanCode) {
    final theme = Theme.of(context);
    final abonnement = ctx.abonnement;
    final bool estSponsorise = switch (abonnement) {
      Abonnement a => a.estSponsorise,
      _ => false,
    };

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Formule actuelle : ${context.l10n.plan(currentPlanCode)}',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _planDescriptionCourte(currentPlanCode),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (estSponsorise)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.shade700),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium, size: 16, color: Colors.amber.shade900),
                        const SizedBox(width: 4),
                        Text(
                          'Sponsorisé (0 FCFA)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildPlanSelector(BuildContext context, List<String> plans, String currentPlanCode, DeclassementState state) {
    final theme = Theme.of(context);
    int ordre(String code) => switch (code) { 'PRO' => 3, 'MOYEN' => 2, _ => 1 };

    return Row(
      children: plans.map((planCode) {
        final isSelected = _selectedPlanCible == planCode;
        final prix = switch (planCode) {
          'PRO' => '5 000 FCFA',
          'MOYEN' => '2 000 FCFA',
          _ => '1 000 FCFA',
        };
        final estSurclassement = ordre(planCode) > ordre(currentPlanCode);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => _onPlanSelected(planCode),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                    width: isSelected ? 2 : 1,
                  ),
                  color: isSelected
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                      : theme.colorScheme.surface,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.l10n.plan(planCode),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isSelected ? theme.colorScheme.primary : null,
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle, size: 20, color: theme.colorScheme.primary),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: estSurclassement ? Colors.green.shade50 : Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        estSurclassement ? '▲ Surclassement' : '▼ Déclassement',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: estSurclassement ? Colors.green.shade800 : Colors.blueGrey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      prix,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _planLimitesResume(planCode),
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSurclassementCard(BuildContext context, AnalyseDeclassement analyse) {
    final theme = Theme.of(context);
    final planCode = analyse.planCible.code;

    final items = planCode == 'PRO'
        ? [
            'Toutes les activités (Commerce, Services, Immobilier) accessibles en simultané',
            'Utilisateurs actifs illimités sans restriction',
            'Boutiques, sites et agences illimités',
            'Intelligence commerciale avancée et synchronisation prioritaire',
          ]
        : [
            'Jusqu\'à 2 activités activables simultanément',
            'Jusqu\'à 7 utilisateurs actifs pour vos collaborateurs',
            'Jusqu\'à 2 boutiques / agences par activité',
          ];

    return Card(
      elevation: 0,
      color: Colors.green.shade50.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rocket_launch, color: Colors.green, size: 24),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Surclassement : Formule ${analyse.planCible.nom}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                ),
                Chip(
                  label: const Text(
                    'Plafonds étendus',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.green.shade200),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Aucun ajustement requis. Toutes vos ressources actuelles sont automatiquement compatibles et vos nouveaux quotas sont immédiatement disponibles après confirmation.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.green.shade900),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(),
            const SizedBox(height: AppSpacing.xs),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConformiteStatusBar(BuildContext context, AnalyseDeclassement analyse) {
    final theme = Theme.of(context);
    final conforme = analyse.conforme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: conforme ? Colors.green.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: conforme ? Colors.green.shade400 : Colors.amber.shade400),
      ),
      child: Row(
        children: [
          Icon(
            conforme ? Icons.check_circle : Icons.warning_amber_rounded,
            color: conforme ? Colors.green.shade700 : Colors.amber.shade900,
            size: 28,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conforme ? 'Toutes les limites sont respectées' : 'Ajustements requis avant activation',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: conforme ? Colors.green.shade900 : Colors.amber.shade900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  conforme
                      ? 'Votre entreprise est prête pour la bascule vers la formule ${analyse.planCible.nom}.'
                      : '${analyse.anomalies.length} point(s) à ajuster ci-dessous pour respecter les limites cibles.',
                  style: TextStyle(
                    fontSize: 12,
                    color: conforme ? Colors.green.shade800 : Colors.amber.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUtilisateursCard(BuildContext context, AnalyseDeclassement analyse) {
    final theme = Theme.of(context);
    final max = analyse.maxUtilisateursCible;
    final actuel = analyse.utilisateursActifs;
    final estExcede = max != null && actuel > max;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: estExcede ? Colors.orange.shade300 : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  estExcede ? Icons.warning_amber_rounded : Icons.people_outline,
                  color: estExcede ? Colors.orange.shade800 : theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Utilisateurs actifs ($actuel / ${max == null ? "Illimité" : max})',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text(
                    estExcede ? '${actuel - max!} en trop' : 'Conforme',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: estExcede ? Colors.orange.shade900 : Colors.green.shade900,
                    ),
                  ),
                  backgroundColor: estExcede ? Colors.orange.shade100 : Colors.green.shade100,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              estExcede
                  ? 'La formule ${analyse.planCible.nom} autorise jusqu\'à $max utilisateurs actifs. Veuillez suspendre les comptes excédentaires.'
                  : 'Le nombre d\'utilisateurs actifs respecte le quota de la formule cible.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _openMembresSheet(context),
                icon: const Icon(Icons.manage_accounts, size: 18),
                label: const Text('Gérer les utilisateurs'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerimetresCard(BuildContext context, AnalyseDeclassement analyse) {
    final theme = Theme.of(context);
    final anomaliesPerim = analyse.anomalies.where((a) => a.type == TypeAnomalieDeclassement.perimetresExcedentaires).toList();
    final estExcede = anomaliesPerim.isNotEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: estExcede ? Colors.orange.shade300 : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  estExcede ? Icons.warning_amber_rounded : Icons.store_outlined,
                  color: estExcede ? Colors.orange.shade800 : theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Boutiques, sites & agences',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text(
                    estExcede ? 'Dépassement' : 'Conforme',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: estExcede ? Colors.orange.shade900 : Colors.green.shade900,
                    ),
                  ),
                  backgroundColor: estExcede ? Colors.orange.shade100 : Colors.green.shade100,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            if (estExcede)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: anomaliesPerim.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(a.message, style: theme.textTheme.bodySmall),
                )).toList(),
              )
            else
              Text(
                'Toutes les boutiques et agences actives respectent les limites de la formule cible.',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _openPerimetresSheet(context),
                icon: const Icon(Icons.storefront, size: 18),
                label: const Text('Gérer les boutiques'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitesCard(BuildContext context, AnalyseDeclassement analyse) {
    final theme = Theme.of(context);
    final max = analyse.planCible.maxActivites;
    final actuel = analyse.nbActivitesActives;
    final anomaliesAct = analyse.anomalies.where((a) =>
        a.type == TypeAnomalieDeclassement.activitesExcedentaires ||
        a.type == TypeAnomalieDeclassement.activiteNonAutorisee).toList();
    final estExcede = anomaliesAct.isNotEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: estExcede ? Colors.orange.shade300 : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  estExcede ? Icons.warning_amber_rounded : Icons.business_center_outlined,
                  color: estExcede ? Colors.orange.shade800 : theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Activités actives ($actuel / $max max)',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text(
                    estExcede ? 'Ajustement requis' : 'Conforme',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: estExcede ? Colors.orange.shade900 : Colors.green.shade900,
                    ),
                  ),
                  backgroundColor: estExcede ? Colors.orange.shade100 : Colors.green.shade100,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            if (estExcede)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: anomaliesAct.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(a.message, style: theme.textTheme.bodySmall),
                )).toList(),
              )
            else
              Text(
                'Les activités actives sont parfaitement compatibles avec la formule cible.',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _openActivitesSheet(context, analyse),
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Choisir les activités'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSummary(BuildContext context, AnalyseDeclassement analyse) {
    final theme = Theme.of(context);
    final estSponsorise = analyse.estSponsorise;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('3. Synthèse et conditions d\'application', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tarif de référence formule cible :',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${analyse.planCible.prixMensuel} FCFA / mois',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Montant réellement facturé :',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  estSponsorise ? '0 FCFA (Sponsorisé)' : '${analyse.montantDu} FCFA / mois',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: estSponsorise ? Colors.green.shade700 : theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (estSponsorise) ...[
              const SizedBox(height: 6),
              Text(
                '⭐ Votre accès demeure 100% sponsorisé par DubaGest. Ce changement ne vous réclame aucun paiement.',
                style: TextStyle(fontSize: 12, color: Colors.green.shade800),
              ),
            ],
            const Divider(height: AppSpacing.lg),
            Row(
              children: [
                const Icon(Icons.security, size: 18, color: Colors.blue),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Aucune donnée métier n\'est supprimée : toutes vos anciennes ventes, stocks et justificatifs restent sécurisés et consultables.',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, DeclassementState state) {
    final conforme = state.analyse?.conforme == true;
    final estSurclassement = state.analyse?.estSurclassement == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: conforme && !state.chargement ? () => _confirmerEtFinaliser(context) : null,
          icon: Icon(estSurclassement ? Icons.rocket_launch : Icons.verified),
          label: Text(
            estSurclassement
                ? 'Confirmer et passer à la formule ${state.analyse?.planCible.nom ?? ""}'
                : (conforme ? 'Vérifier et finaliser le déclassement' : 'Ajustements nécessaires avant validation'),
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            backgroundColor: estSurclassement ? Colors.green.shade700 : null,
          ),
        ),
        if (state.demande != null) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: !state.chargement ? () => _annulerDemande(context) : null,
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Annuler la demande en cours'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ],
    );
  }

  // --- Modal Sheets pour ajustement guidé direct ---

  Future<void> _openMembresSheet(BuildContext context) async {
    final membres = ref.read(membresProvider).value ?? [];
    final notifier = ref.read(declassementNotifierProvider.notifier);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (ctx, scrollController) {
            return Consumer(
              builder: (context, ref, _) {
                final list = ref.watch(membresProvider).value ?? membres;
                final state = ref.watch(declassementNotifierProvider);

                return Column(
                  children: [
                    AppBar(
                      title: const Text('Sélection des utilisateurs actifs'),
                      automaticallyImplyLeading: false,
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Text(
                        'Désactiver un compte suspend son accès opérationnel tout en conservant son historique d\'actions. Le dernier administrateur ne peut être désactivé.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final membre = list[index];
                          final estActif = membre.estActif;

                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(membre.nomAffiche.isNotEmpty ? membre.nomAffiche[0].toUpperCase() : '?'),
                            ),
                            title: Text(membre.nomAffiche),
                            subtitle: Text('${context.l10n.role(membre.roleCode)} · ${estActif ? "Actif" : "Suspendu"}'),
                            trailing: Switch(
                              value: estActif,
                              onChanged: state.chargement
                                  ? null
                                  : (nouveauActif) async {
                                      final ok = await notifier.ajusterUtilisateur(
                                        membreId: membre.id,
                                        suspendre: !nouveauActif,
                                        planCibleCode: _selectedPlanCible ?? 'NORMAL',
                                      );
                                      if (!ok && mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Impossible de désactiver le dernier administrateur.'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openPerimetresSheet(BuildContext context) async {
    final perimetres = ref.read(perimetresProvider).value ?? [];
    final notifier = ref.read(declassementNotifierProvider.notifier);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (ctx, scrollController) {
            return Consumer(
              builder: (context, ref, _) {
                final list = ref.watch(perimetresProvider).value ?? perimetres;
                final state = ref.watch(declassementNotifierProvider);

                return Column(
                  children: [
                    AppBar(
                      title: const Text('Boutiques et Agences à conserver'),
                      automaticallyImplyLeading: false,
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Text(
                        'Une boutique désactivée n\'est pas supprimée : l\'historique des ventes, stocks et mouvements reste consultable.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final perimetre = list[index];
                          final estActif = perimetre.estActif;

                          return ListTile(
                            leading: Icon(
                              perimetre.type == PerimetreType.boutique ? Icons.store : Icons.apartment,
                              color: estActif ? Colors.green : Colors.grey,
                            ),
                            title: Text(perimetre.nom),
                            subtitle: Text('${context.l10n.activite(perimetre.activite)} · ${estActif ? "Active" : "Désactivée"}'),
                            trailing: Switch(
                              value: estActif,
                              onChanged: state.chargement
                                  ? null
                                  : (nouveauActif) async {
                                      await notifier.ajusterPerimetre(
                                        perimetreId: perimetre.id,
                                        desactiver: !nouveauActif,
                                        planCibleCode: _selectedPlanCible ?? 'NORMAL',
                                      );
                                    },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openActivitesSheet(BuildContext context, AnalyseDeclassement analyse) async {
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    final notifier = ref.read(declassementNotifierProvider.notifier);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctxModal) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Consumer(
              builder: (context, ref, _) {
                final state = ref.watch(declassementNotifierProvider);
                final activites = ref.watch(contexteActifProvider)?.activites ?? [];

                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Activités à conserver',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(ctxModal).pop(),
                          ),
                        ],
                      ),
                      Text(
                        'La formule ${analyse.planCible.nom} autorise au maximum ${analyse.planCible.maxActivites} activité(s).',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final a in activites)
                        SwitchListTile(
                          title: Text(context.l10n.activite(a.activite)),
                          subtitle: Text(a.estActive ? 'Active' : 'Désactivée'),
                          value: a.estActive,
                          onChanged: state.chargement
                              ? null
                              : (nouveauActif) async {
                                  await notifier.ajusterActivite(
                                    activiteCode: a.activite.code,
                                    desactiver: !nouveauActif,
                                    planCibleCode: _selectedPlanCible ?? 'NORMAL',
                                  );
                                  await ref.read(contexteSessionProvider.notifier).rafraichir();
                                  setModalState(() {});
                                },
                        ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _confirmerEtFinaliser(BuildContext context) async {
    final state = ref.read(declassementNotifierProvider);
    final analyse = state.analyse;
    if (analyse == null) return;
    final estSurclassement = analyse.estSurclassement;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(estSurclassement ? 'Passer à la formule supérieure' : 'Confirmer le déclassement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Êtes-vous sûr de vouloir basculer vers la formule ${analyse.planCible.nom} ?'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                analyse.estSponsorise
                    ? 'Votre accès reste 100% sponsorisé (0 FCFA).'
                    : 'Le nouveau tarif sera de ${analyse.planCible.prixMensuel} FCFA/mois.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                estSurclassement
                    ? 'Vos nouveaux plafonds et privilèges seront débloqués immédiatement. Vos données restent sécurisées.'
                    : 'Les règles et quotas de la nouvelle formule s\'appliqueront immédiatement. Vos données antérieures restent préservées.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: estSurclassement ? Colors.green.shade700 : null,
              ),
              child: Text(estSurclassement ? 'Confirmer et Surclasser' : 'Confirmer et Activer'),
            ),
          ],
        );
      },
    );

    if (confirme == true && mounted) {
      final succes = await ref.read(declassementNotifierProvider.notifier).finaliserDeclassement();
      if (succes && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(estSurclassement
                ? 'Félicitations ! Formule mise à niveau vers ${analyse.planCible.nom} !'
                : 'Formule déclassée avec succès vers ${analyse.planCible.nom} !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _annulerDemande(BuildContext context) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Annuler la demande'),
          content: const Text(
            'Voulez-vous annuler la demande de déclassement en cours ?\n\n'
            'Note : les utilisateurs ou boutiques éventuellement désactivés pendant la préparation ne seront pas réactivés automatiquement.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Non'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Oui, annuler'),
            ),
          ],
        );
      },
    );

    if (confirme == true && mounted) {
      await ref.read(declassementNotifierProvider.notifier).annulerDemande();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande de déclassement annulée.')),
        );
      }
    }
  }

  String _planDescriptionCourte(String planCode) {
    switch (planCode) {
      case 'PRO':
        return 'Toutes activités, utilisateurs et boutiques illimités.';
      case 'MOYEN':
        return 'Jusqu\'à 2 activités et 2 boutiques par activité.';
      case 'NORMAL':
        return 'Une seule activité, équipe et boutique restreinte.';
      default:
        return '';
    }
  }

  String _planLimitesResume(String planCode) {
    switch (planCode) {
      case 'MOYEN':
        return 'Max 2 activités · Jusqu\'à 7 utilisateurs · 2 boutiques';
      case 'NORMAL':
        return 'Max 1 activité · Jusqu\'à 3 utilisateurs · 1 boutique';
      default:
        return '';
    }
  }
}
