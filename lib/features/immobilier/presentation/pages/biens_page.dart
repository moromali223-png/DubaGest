import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/bien_immobilier.dart';
import '../providers/immobilier_providers.dart';
import '../widgets/immobilier_widgets.dart';

class BiensPage extends ConsumerWidget {
  const BiensPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final biensAsync = ref.watch(biensListProvider);
    final biensFiltres = ref.watch(biensFiltresProvider);
    final tousLesBiens = biensAsync.value ?? const [];

    final filtre = ref.watch(filtreBiensProvider);
    final filtreStatut = filtre.statut;
    final filtreType = filtre.type;
    final recherche = filtre.recherche;

    final nbDisponibles = tousLesBiens.where((b) => b.estDisponible).length;
    final nbOccupes = tousLesBiens.where((b) => b.estOccupe).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.moduleImmobilierBiens),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_outlined),
            tooltip: 'Tableau de bord',
            onPressed: () => context.push(Routes.immobilierDashboard),
          ),
          IconButton(
            icon: const Icon(Icons.add_home_work_outlined),
            tooltip: 'Nouveau bien',
            onPressed: () => context.push(Routes.bienNouveau),
          ),
        ],
      ),
      body: Column(
        children: [
          // Bandeau récapitulatif supérieur
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _IndicateurCompact(
                    titre: 'Total biens',
                    valeur: '${tousLesBiens.length}',
                    couleur: AppColors.primary,
                  ),
                ),
                Container(width: 1, height: 28, color: AppColors.border),
                Expanded(
                  child: _IndicateurCompact(
                    titre: 'Disponibles',
                    valeur: '$nbDisponibles',
                    couleur: AppColors.green,
                  ),
                ),
                Container(width: 1, height: 28, color: AppColors.border),
                Expanded(
                  child: _IndicateurCompact(
                    titre: 'Occupés',
                    valeur: '$nbOccupes',
                    couleur: const Color(0xFFDF9540),
                  ),
                ),
              ],
            ),
          ),

          // Barre de recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un bien (nom, référence, ville...)...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: AppColors.surface,
                suffixIcon: recherche.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => ref.read(filtreBiensProvider.notifier).rechercher(''),
                      )
                    : null,
              ),
              onChanged: (val) => ref.read(filtreBiensProvider.notifier).rechercher(val),
            ),
          ),

          // Filtres par statut (Chips horizontaux)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Tous'),
                  selected: filtreStatut == null && filtreType == null,
                  onSelected: (_) {
                    ref.read(filtreBiensProvider.notifier).changerStatut(null);
                    ref.read(filtreBiensProvider.notifier).changerType(null);
                  },
                ),
                const SizedBox(width: 8),
                for (final statut in StatutBien.values) ...[
                  ChoiceChip(
                    avatar: Icon(statut.icone, size: 14, color: statut.couleur),
                    label: Text(statut.libelle),
                    selected: filtreStatut == statut,
                    onSelected: (sel) {
                      ref.read(filtreBiensProvider.notifier).changerStatut(sel ? statut : null);
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),

          // Liste des biens
          Expanded(
            child: biensAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => MessageView(
                icon: Icons.error_outline,
                title: 'Erreur de chargement',
                message: err.toString(),
                action: FilledButton.icon(
                  onPressed: () => ref.invalidate(biensListProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Réessayer'),
                ),
              ),
              data: (_) {
                if (tousLesBiens.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 72),
                    child: MessageView(
                      icon: Icons.home_work_outlined,
                      title: 'Aucun bien enregistré',
                      message:
                          'Commencez par enregistrer vos appartements, maisons, bureaux ou terrains pour démarrer votre gestion locative.',
                      action: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                        icon: const Icon(Icons.add_home_work_rounded),
                        label: const Text('Enregistrer mon premier bien'),
                        onPressed: () => context.push(Routes.bienNouveau),
                      ),
                    ),
                  );
                }

                if (biensFiltres.isEmpty) {
                  return const Center(
                    child: Text('Aucun bien ne correspond aux filtres.'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(biensListProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 6, bottom: 80),
                    itemCount: biensFiltres.length,
                    itemBuilder: (context, index) {
                      final bien = biensFiltres[index];
                      return BienCard(bien: bien);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouveau Bien', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () => context.push(Routes.bienNouveau),
      ),
    );
  }
}

class _IndicateurCompact extends StatelessWidget {
  const _IndicateurCompact({
    required this.titre,
    required this.valeur,
    required this.couleur,
  });

  final String titre;
  final String valeur;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          valeur,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: couleur,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          titre,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
