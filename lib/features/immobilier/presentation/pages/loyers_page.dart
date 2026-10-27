import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/echeance_loyer.dart';
import '../providers/immobilier_providers.dart';
import '../widgets/loyer_widgets.dart';

class LoyersPage extends ConsumerStatefulWidget {
  const LoyersPage({super.key});

  @override
  ConsumerState<LoyersPage> createState() => _LoyersPageState();
}

class _LoyersPageState extends ConsumerState<LoyersPage> {
  final TextEditingController _rechercheController = TextEditingController();

  @override
  void dispose() {
    _rechercheController.dispose();
    super.dispose();
  }

  Future<void> _genererAppels(BuildContext context) async {
    final filtre = ref.read(filtreLoyersProvider);
    const moisNoms = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    final nomMois = moisNoms[(filtre.mois - 1).clamp(0, 11)];

    final messenger = ScaffoldMessenger.of(context);
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('Générer les appels', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          'Voulez-vous générer les appels de loyer pour $nomMois ${filtre.annee} pour tous les contrats de bail actifs ?\n\n'
          'Cette opération est idempotente : aucune échéance existante ne sera dupliquée.',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
            label: const Text('Générer'),
          ),
        ],
      ),
    );

    if (confirmer != true || !mounted) return;

    try {
      final nouvelles = await ref.read(immobilierLoyersControllerProvider.notifier).genererAppelsDuMois(
            mois: filtre.mois,
            annee: filtre.annee,
          );
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              nouvelles.isEmpty
                  ? 'Toutes les échéances de $nomMois ${filtre.annee} sont déjà générées.'
                  : '${nouvelles.length} échéance(s) de loyer générée(s) pour $nomMois ${filtre.annee}.',
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la génération : $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = ref.watch(contexteActifProvider);
    final devise = ctx?.entreprise?.devise ?? 'FCFA';

    final filtre = ref.watch(filtreLoyersProvider);
    final filtreNotifier = ref.read(filtreLoyersProvider.notifier);
    final stats = ref.watch(recouvrementStatistiquesProvider);
    final echeances = ref.watch(echeancesFiltreesProvider);
    final echeancesAsync = ref.watch(echeancesLoyersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loyers & Recouvrement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_outlined),
            tooltip: 'Tableau de bord',
            onPressed: () => context.push(Routes.immobilierDashboard),
          ),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => _genererAppels(context),
            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
            label: const Text('Appels', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => context.push(Routes.loyerRecevoir),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Recevoir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: echeancesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => MessageView(
          icon: Icons.error_outline_rounded,
          title: 'Erreur de chargement',
          message: err.toString(),
        ),
        data: (_) => RefreshIndicator(
          onRefresh: () async => ref.refresh(echeancesLoyersProvider.future),
          child: CustomScrollView(
            slivers: [
              // 1. En-tête KPI Recouvrement avec navigation mensuelle
              SliverToBoxAdapter(
                child: RecouvrementStatsHeader(stats: stats, devise: devise),
              ),

              // 2. Barre de recherche
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TextField(
                    controller: _rechercheController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher par référence, locataire, bien...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _rechercheController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _rechercheController.clear();
                                filtreNotifier.rechercher('');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: filtreNotifier.rechercher,
                  ),
                ),
              ),

              // 3. Filtres par statut
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Toutes'),
                        selected: filtre.statut == null,
                        onSelected: (_) => filtreNotifier.filtrerStatut(null),
                      ),
                      const SizedBox(width: 8),
                      for (final s in StatutEcheanceLoyer.values) ...[
                        FilterChip(
                          label: Text(s.libelle),
                          avatar: Icon(s.icone, size: 14, color: s.couleur),
                          selected: filtre.statut == s,
                          onSelected: (_) => filtreNotifier.filtrerStatut(s),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // 4. Liste des échéances ou vue vide
              if (echeances.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: MessageView(
                    icon: Icons.receipt_long_outlined,
                    title: 'Aucune échéance pour ce mois',
                    message:
                        'Cliquez sur "Appels du mois" pour générer les avis d\'échéance des contrats de bail actifs.',
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final echeance = echeances[index];
                      return InkWell(
                        onTap: () => context.push(Routes.loyerDetails(echeance.id)),
                        borderRadius: BorderRadius.circular(14),
                        child: EcheanceLoyerCard(echeance: echeance),
                      );
                    },
                    childCount: echeances.length,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_card_rounded),
        label: const Text('Recevoir un loyer', style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: () => context.push(Routes.loyerRecevoir),
      ),
    );
  }
}
