import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/dossier_dette.dart';
import '../../domain/entities/finances.dart';
import '../providers/dossiers_dettes_providers.dart';
import '../providers/finances_providers.dart';
import 'carte_dossier_dette.dart';
import 'finances_widgets.dart';

/// Vue principale et consolidée du module Dettes / À recevoir / À payer.
/// « Une personne = un dossier financier complet ».
class DettesVuePrincipale extends ConsumerStatefulWidget {
  const DettesVuePrincipale({super.key, this.sensInitial = SensEngagement.aRecevoir});

  final SensEngagement sensInitial;

  @override
  ConsumerState<DettesVuePrincipale> createState() => _DettesVuePrincipaleState();
}

class _DettesVuePrincipaleState extends ConsumerState<DettesVuePrincipale> {
  late SensEngagement _sens;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sens = widget.sensInitial;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final devise = ref.watch(deviseProvider);
    final droits = ref.watch(droitsFinancesProvider);
    final filtre = ref.watch(filtreDettesProvider);
    final filtreNotifier = ref.read(filtreDettesProvider.notifier);

    final tousDossiersAsync = ref.watch(tousDossiersDettesProvider(_sens));
    final dossiersFiltresAsync = ref.watch(dossiersDettesFiltresProvider(_sens));
    final echeancesAsync = ref.watch(echeancesChronologiquesProvider(_sens));

    final estRecevoir = _sens == SensEngagement.aRecevoir;

    return Scaffold(
      floatingActionButton: !droits.gererCreances
          ? null
          : FloatingActionButton.extended(
              key: const Key('engagement-add'),
              heroTag: 'engagement-add',
              backgroundColor: estRecevoir ? AppColors.green : AppColors.dette,
              foregroundColor: Colors.white,
              onPressed: () => context.push(Routes.engagementNouveau(_sens)),
              icon: const Icon(Icons.add_rounded),
              label: Text(estRecevoir ? '+ Nouvelle créance' : '+ Ajouter une dette'),
            ),
      body: ResponsiveBody(
        maxWidth: 960,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(etatFinancesProvider),
          child: CustomScrollView(
            slivers: [
              // 1. En-tête de synthèse consolidé
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Sélecteur À recevoir / À payer (affiché uniquement si l'utilisateur a le droit aux dépenses / dettes fournisseurs)
                      if (droits.voirDepenses) ...[
                        SegmentedButton<SensEngagement>(
                          segments: [
                            ButtonSegment(
                              value: SensEngagement.aRecevoir,
                              label: Text(l10n.financeToReceive, style: const TextStyle(fontWeight: FontWeight.w700)),
                              icon: const Icon(Icons.south_west_rounded, size: 16),
                            ),
                            ButtonSegment(
                              value: SensEngagement.aPayer,
                              label: Text(l10n.financeToPay, style: const TextStyle(fontWeight: FontWeight.w700)),
                              icon: const Icon(Icons.north_east_rounded, size: 16),
                            ),
                          ],
                          selected: {_sens},
                          onSelectionChanged: (s) {
                            setState(() => _sens = s.first);
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],

                      // Carte KPI Globale de la situation
                      tousDossiersAsync.maybeWhen(
                        data: (dossiers) {
                          final totalReste = dossiers.fold<int>(0, (sum, d) => sum + d.reste);
                          final totalRetard = dossiers.fold<int>(0, (sum, d) => sum + d.totalEnRetard);
                          final nbPersonnesActives = dossiers.where((d) => d.reste > 0).length;
                          final nbEcheancesRetard = dossiers.fold<int>(0, (sum, d) => sum + d.nbEcheancesEnRetard);

                          return Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: estRecevoir ? AppColors.green : AppColors.detteHeader,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: (estRecevoir ? AppColors.green : AppColors.detteHeader).withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  estRecevoir ? 'Total à recevoir (Créances)' : 'Total à payer (Dettes)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.montant(totalReste, devise),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const Divider(height: 20, color: Colors.white24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.people_alt_rounded, size: 16, color: Colors.white70),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$nbPersonnesActives ${estRecevoir ? 'clients' : 'fournisseurs'}',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                    if (nbEcheancesRetard > 0 || totalRetard > 0) ...[
                                      const SizedBox(width: AppSpacing.xs),
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.negative,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.error_outline_rounded, size: 13, color: Colors.white),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  '$nbEcheancesRetard en retard (${l10n.montant(totalRetard, devise)})',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                        orElse: () => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // 2. Barre de recherche intelligente
                      TextField(
                        controller: _searchController,
                        onChanged: (v) => filtreNotifier.setRecherche(v),
                        decoration: InputDecoration(
                          hintText: estRecevoir
                              ? '🔎 Rechercher un client (nom, reçu, tél...)'
                              : '🔎 Rechercher un fournisseur...',
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    filtreNotifier.setRecherche('');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // 3. Barre de filtres de statut + Sélecteur de mode de vue
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final st in FiltreStatutDette.values) ...[
                                    FilterChip(
                                      key: Key('filtre-statut-${st.name}'),
                                      label: Text(st.label),
                                      selected: filtre.statut == st,
                                      onSelected: (selected) {
                                        if (selected) {
                                          filtreNotifier.setStatut(st);
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          // Switcher Vue Personnes / Vue Échéances (Exigence 26, 27, 28)
                          SegmentedButton<VueDettesMode>(
                            style: SegmentedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            segments: [
                              ButtonSegment(
                                value: VueDettesMode.personnes,
                                label: Text(estRecevoir ? 'Clients' : 'Fournisseurs', style: const TextStyle(fontSize: 12)),
                                icon: const Icon(Icons.person_rounded, size: 14),
                              ),
                              const ButtonSegment(
                                value: VueDettesMode.echeances,
                                label: Text('Échéances', style: TextStyle(fontSize: 12)),
                                icon: Icon(Icons.calendar_month_rounded, size: 14),
                              ),
                            ],
                            selected: {filtre.modeVue},
                            onSelectionChanged: (m) => filtreNotifier.setModeVue(m.first),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Contenu selon le mode de vue sélectionné
              if (filtre.modeVue == VueDettesMode.personnes)
                _SliverListeDossiers(
                  dossiersAsync: dossiersFiltresAsync,
                  sens: _sens,
                )
              else
                _SliverListeEcheances(
                  echeancesAsync: echeancesAsync,
                  sens: _sens,
                ),

              // Espace pour le FAB
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vue liste consolidée par Personne (Client ou Fournisseur)
class _SliverListeDossiers extends ConsumerWidget {
  const _SliverListeDossiers({required this.dossiersAsync, required this.sens});
  final AsyncValue<List<DossierDette>> dossiersAsync;
  final SensEngagement sens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return dossiersAsync.when(
      loading: () => const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => SliverFillRemaining(
        child: Center(child: Text('Erreur: $e')),
      ),
      data: (dossiers) {
        if (dossiers.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: EmptyView(
                icon: Icons.person_search_rounded,
                message: sens == SensEngagement.aRecevoir
                    ? 'Aucun dossier client trouvé'
                    : 'Aucun dossier fournisseur trouvé',
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final dossier = dossiers[index];
                return CarteDossierDette(
                  key: Key('carte-dossier-${dossier.dossierKey}'),
                  dossier: dossier,
                  onTap: () {
                    context.push(Routes.dossierDette(dossier.dossierKey, sens: sens));
                  },
                );
              },
              childCount: dossiers.length,
            ),
          ),
        );
      },
    );
  }
}

/// Vue Échéances chronologiques groupées (Exigences 12, 14, 28)
class _SliverListeEcheances extends ConsumerWidget {
  const _SliverListeEcheances({required this.echeancesAsync, required this.sens});
  final AsyncValue<List<EcheanceDette>> echeancesAsync;
  final SensEngagement sens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final devise = ref.watch(deviseProvider);
    final estRecevoir = sens == SensEngagement.aRecevoir;

    return echeancesAsync.when(
      loading: () => const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => SliverFillRemaining(
        child: Center(child: Text('Erreur: $e')),
      ),
      data: (echeances) {
        if (echeances.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: EmptyView(
                icon: Icons.event_available_rounded,
                message: 'Aucune échéance trouvée',
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final ech = echeances[index];
                final estRetard = ech.estEnRetard;

                final (fond, couleur, label) = switch (ech.statut) {
                  StatutEcheanceItem.enRetard => (
                      AppColors.negativeSoft,
                      AppColors.negative,
                      '🔴 ${ech.retardJours > 0 ? '${ech.retardJours} j de retard' : 'En retard'}',
                    ),
                  StatutEcheanceItem.aujourdhui => (
                      AppColors.warningSoft,
                      AppColors.warning,
                      '🟠 Aujourd\'hui',
                    ),
                  StatutEcheanceItem.cetteSemaine => (
                      AppColors.warningSoft,
                      AppColors.warning,
                      '🟠 Cette semaine',
                    ),
                  StatutEcheanceItem.semaineProchaine => (
                      AppColors.positiveSoft,
                      AppColors.positive,
                      '🟢 Semaine prochaine',
                    ),
                  StatutEcheanceItem.plusTard => (
                      AppColors.background,
                      AppColors.muted,
                      '🟢 À venir',
                    ),
                  StatutEcheanceItem.reglee => (
                      AppColors.background,
                      AppColors.muted,
                      '✓ Réglée',
                    ),
                };

                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: estRetard ? AppColors.negative.withValues(alpha: 0.3) : AppColors.border,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: fond,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            ech.dateEcheance.day.toString(),
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: couleur),
                          ),
                          Text(
                            l10n.date(ech.dateEcheance).split(' ').take(2).last.toUpperCase(),
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: couleur),
                          ),
                        ],
                      ),
                    ),
                    title: Text(
                      ech.nomContact ?? ech.libelle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    subtitle: Text(
                      [
                        if (ech.nomContact != null) ech.libelle,
                        l10n.date(ech.dateEcheance),
                        if (ech.origineType != 'MANUEL') ech.origineType,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          l10n.montant(ech.montantReste, devise),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: estRetard ? AppColors.negative : (estRecevoir ? AppColors.green : AppColors.dette),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            label,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: couleur),
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      if (ech.contactId != null) {
                        context.push(Routes.dossierDette('contact_${ech.contactId}', sens: sens));
                      } else {
                        context.push(Routes.engagement(ech.engagementId));
                      }
                    },
                  ),
                );
              },
              childCount: echeances.length,
            ),
          ),
        );
      },
    );
  }
}
