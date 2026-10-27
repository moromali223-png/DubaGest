import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/app_header_buttons.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../entreprise/presentation/providers/espace_providers.dart';
import '../../../commerce/presentation/widgets/commerce_widgets.dart' show montant;
import '../services_providers.dart';
import '../widgets/services_widgets.dart';

/// Tableau de bord central du module Services — Conçu pour les entreprises de prestations.
/// Simple, visuel, mobile-first : Savoir quoi faire, quand, pour qui, et ce qui reste à encaisser.
class ServicesAccueilPage extends ConsumerWidget {
  const ServicesAccueilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ctx = ref.watch(contexteActifProvider);
    final espace = ref.watch(espaceCourantProvider);
    final synthese = ref.watch(syntheseServicesProvider);
    final prestationsAsync = ref.watch(prestationsProvider);
    final alertes = ref.watch(alertesServicesProvider);
    final droits = ref.watch(droitsServicesProvider);

    if (ctx == null) return const SizedBox.shrink();

    final prenom = ctx.nomComplet?.split(' ').first ?? 'Prestataire';
    final nomSite = espace.perimetreId != null
        ? (ctx.perimetres.where((p) => p.id == espace.perimetreId).firstOrNull?.nom ?? 'Site')
        : 'Tous les sites';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.read(contexteSessionProvider.notifier).rafraichir(),
          child: ResponsiveBody(
            maxWidth: 860,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // 1. Header Services
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Builder(
                      builder: (scaffoldContext) =>
                          AppMenuButton(onPressed: () => Scaffold.of(scaffoldContext).openDrawer()),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bonjour $prenom 👋',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF01226C).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.handyman_rounded, size: 14, color: Color(0xFF01226C)),
                                    const SizedBox(width: 4),
                                    Text(
                                      nomSite,
                                      style: const TextStyle(
                                        color: Color(0xFF01226C),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
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
                    const SyncStatusButton(boxed: true),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // 2. Grille des 4 KPIs Essentiels
                Row(
                  children: [
                    Expanded(
                      child: _KpiServicesCard(
                        titre: 'Aujourd\'hui',
                        valeur: '${synthese?.prestationsAujourdhui ?? 0}',
                        icone: Icons.today_rounded,
                        couleur: const Color(0xFF01226C),
                        onTap: () => context.push('/services/planning?vue=aujourdhui'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _KpiServicesCard(
                        titre: 'En cours',
                        valeur: '${synthese?.prestationsEnCours ?? 0}',
                        icone: Icons.play_circle_outline_rounded,
                        couleur: const Color(0xFFDF9540),
                        onTap: () => context.push('/services/prestations?statut=EN_COURS'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _KpiServicesCard(
                        titre: 'Alertes / Retards',
                        valeur: '${(synthese?.prestationsEnRetard ?? 0) + (synthese?.prestationsUrgentes ?? 0)}',
                        icone: Icons.warning_amber_rounded,
                        couleur: (synthese?.prestationsEnRetard ?? 0) > 0 ? AppColors.negative : const Color(0xFFEA580C),
                        onTap: () => context.push('/services/planning?vue=retard'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _KpiServicesCard(
                        titre: 'Reste à recevoir',
                        valeur: montant(context, ref, synthese?.totalARecevoir ?? 0),
                        icone: Icons.account_balance_wallet_outlined,
                        couleur: AppColors.green,
                        onTap: () => context.push(Routes.finances),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // 3. Actions Rapides
                Text(
                  'Actions rapides',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _ActionBouton(
                        titre: '+ Prestation',
                        sousTitre: 'Nouveau contrat de service',
                        icone: Icons.add_circle_outline_rounded,
                        couleur: const Color(0xFF01226C),
                        onTap: droits.peutCreerPrestations ? () => context.push(Routes.prestationNouvelle) : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionBouton(
                        titre: '📑 Contrats de service',
                        sousTitre: 'Locations & suivis actifs',
                        icone: Icons.assignment_outlined,
                        couleur: const Color(0xFF1E3A8A),
                        onTap: droits.peutVoirPrestations ? () => context.push(Routes.servicesPrestations) : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ActionBouton(
                        titre: '📅 Planning',
                        sousTitre: 'Missions terrain & planning',
                        icone: Icons.calendar_today_outlined,
                        couleur: const Color(0xFF0284C7),
                        onTap: droits.peutVoirPrestations ? () => context.push(Routes.servicesPlanning) : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionBouton(
                        titre: '🏷️ Catalogue',
                        sousTitre: 'Référentiel des tarifs',
                        icone: Icons.category_outlined,
                        couleur: const Color(0xFFDF9540),
                        onTap: droits.peutVoirServices ? () => context.push(Routes.servicesCatalogue) : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ActionBouton(
                        titre: '📝 Devis',
                        sousTitre: 'Chiffrer & relancer',
                        icone: Icons.request_quote_outlined,
                        couleur: const Color(0xFF7C3AED),
                        onTap: droits.peutVoirDevis ? () => context.push(Routes.servicesDevis) : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionBouton(
                        titre: '📊 Rentabilité',
                        sousTitre: 'CA, marge & conversion',
                        icone: Icons.analytics_outlined,
                        couleur: const Color(0xFF0F766E),
                        onTap: (droits.peutVoirServices || droits.peutVoirPrestations)
                            ? () => context.push(Routes.servicesRapports)
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // 4. Section « ⚠️ À suivre & Alertes »
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '⚠️ À suivre & Échéances',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    if (alertes.isNotEmpty)
                      TextButton(
                        onPressed: () => context.push('/services/planning?vue=retard'),
                        child: const Text('Voir tout', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                if (alertes.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.green.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, color: AppColors.green, size: 28),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tout est sous contrôle',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.green),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Aucune prestation urgente ou en retard pour le moment.',
                                style: TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      for (final p in alertes.take(3))
                        PrestationCard(
                          prestation: p,
                          onTap: () => context.push('/services/prestations/${p.id}'),
                        ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.xl),

                // 5. Prestations Récentes
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Derniers contrats & interventions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/services/prestations'),
                      child: const Text('Toutes', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                prestationsAsync.when(
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                  error: (e, _) => Text('Erreur : $e', style: const TextStyle(color: AppColors.negative)),
                  data: (prestations) {
                    if (prestations.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.build_circle_outlined, size: 40, color: AppColors.muted),
                            SizedBox(height: 8),
                            Text(
                              'Aucune prestation enregistrée',
                              style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: 15),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Créez votre première intervention pour démarrer le suivi.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: [
                        for (final p in prestations.take(5))
                          PrestationCard(
                            prestation: p,
                            onTap: () => context.push('/services/prestations/${p.id}'),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiServicesCard extends StatelessWidget {
  const _KpiServicesCard({
    required this.titre,
    required this.valeur,
    required this.icone,
    required this.couleur,
    required this.onTap,
  });

  final String titre;
  final String valeur;
  final IconData icone;
  final Color couleur;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icone, color: couleur, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      valeur,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionBouton extends StatelessWidget {
  const _ActionBouton({
    required this.titre,
    required this.sousTitre,
    required this.icone,
    required this.couleur,
    this.onTap,
  });

  final String titre;
  final String sousTitre;
  final IconData icone;
  final Color couleur;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: couleur.withValues(alpha: enabled ? 0.25 : 0.1)),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: couleur.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icone, color: couleur, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titre,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: couleur,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      sousTitre,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.muted,
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
