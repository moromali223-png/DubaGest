import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/bien_immobilier.dart';
import '../../domain/entities/location_immobilier.dart';
import '../providers/immobilier_providers.dart';
import '../widgets/location_widgets.dart';

enum _VueLocations { occupation, historique }

class LocationsPage extends ConsumerStatefulWidget {
  const LocationsPage({super.key});

  @override
  ConsumerState<LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends ConsumerState<LocationsPage> {
  _VueLocations _vue = _VueLocations.occupation;
  String _recherche = '';
  StatutBien? _filtreStatutBien;
  StatutLocation? _filtreStatutLocation;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ctx = ref.watch(contexteActifProvider);
    final devise = ctx?.entreprise?.devise ?? 'FCFA';

    final stats = ref.watch(parcOccupationStatistiquesProvider);
    final biensAsync = ref.watch(biensListProvider);
    final locationsAsync = ref.watch(locationsListProvider);

    final tousLesBiens = (biensAsync.value ?? const [])
        .where((b) => b.statut != StatutBien.archive)
        .toList();
    final toutesLesLocations = locationsAsync.value ?? const [];

    // Filtrage des biens pour la vue Occupation
    final biensFiltres = tousLesBiens.where((b) {
      if (_filtreStatutBien != null && b.statut != _filtreStatutBien) return false;
      if (_recherche.trim().isNotEmpty) {
        final query = _recherche.toLowerCase();
        final matchNom = b.nom.toLowerCase().contains(query);
        final matchRef = b.reference.toLowerCase().contains(query);
        final matchVille = (b.ville ?? '').toLowerCase().contains(query);
        return matchNom || matchRef || matchVille;
      }
      return true;
    }).toList();

    // Filtrage des locations pour la vue Historique
    final locationsFiltrees = toutesLesLocations.where((l) {
      if (_filtreStatutLocation != null && l.statut != _filtreStatutLocation) return false;
      if (_recherche.trim().isNotEmpty) {
        final query = _recherche.toLowerCase();
        return l.id.toLowerCase().contains(query);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.moduleImmobilierLocations),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_home_work_outlined),
            tooltip: 'Nouvelle location',
            onPressed: () => context.push(Routes.locationNouvelle),
          ),
        ],
      ),
      body: Column(
        children: [
          // En-tête KPI d'occupation
          OccupationStatsHeader(stats: stats, devise: devise),

          // Sélecteur de vue (Tableau d'occupation vs Historique des baux)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<_VueLocations>(
              segments: const [
                ButtonSegment(
                  value: _VueLocations.occupation,
                  icon: Icon(Icons.pie_chart_outline_rounded, size: 18),
                  label: Text('Tableau d\'occupation'),
                ),
                ButtonSegment(
                  value: _VueLocations.historique,
                  icon: Icon(Icons.history_rounded, size: 18),
                  label: Text('Historique des baux'),
                ),
              ],
              selected: {_vue},
              onSelectionChanged: (set) => setState(() => _vue = set.first),
            ),
          ),
          const SizedBox(height: 8),

          // Barre de recherche
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: _vue == _VueLocations.occupation
                    ? 'Rechercher un bien (nom, réf, ville...)...'
                    : 'Rechercher dans les locations...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                suffixIcon: _recherche.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _recherche = ''),
                      )
                    : null,
              ),
              onChanged: (val) => setState(() => _recherche = val),
            ),
          ),

          // Puces de filtres horizontales selon la vue active
          if (_vue == _VueLocations.occupation) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Tous'),
                    selected: _filtreStatutBien == null,
                    onSelected: (_) => setState(() => _filtreStatutBien = null),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Occupés'),
                    selected: _filtreStatutBien == StatutBien.occupe,
                    selectedColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                    onSelected: (sel) => setState(() => _filtreStatutBien = sel ? StatutBien.occupe : null),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Vacants'),
                    selected: _filtreStatutBien == StatutBien.disponible,
                    selectedColor: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    onSelected: (sel) => setState(() => _filtreStatutBien = sel ? StatutBien.disponible : null),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Réservés'),
                    selected: _filtreStatutBien == StatutBien.reserve,
                    selectedColor: const Color(0xFFDF9540).withValues(alpha: 0.15),
                    onSelected: (sel) => setState(() => _filtreStatutBien = sel ? StatutBien.reserve : null),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('En travaux'),
                    selected: _filtreStatutBien == StatutBien.enTravaux,
                    selectedColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    onSelected: (sel) => setState(() => _filtreStatutBien = sel ? StatutBien.enTravaux : null),
                  ),
                ],
              ),
            ),
          ] else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Toutes'),
                    selected: _filtreStatutLocation == null,
                    onSelected: (_) => setState(() => _filtreStatutLocation = null),
                  ),
                  const SizedBox(width: 8),
                  for (final s in StatutLocation.values) ...[
                    FilterChip(
                      avatar: Icon(s.icone, size: 14, color: s.couleur),
                      label: Text(s.libelle),
                      selected: _filtreStatutLocation == s,
                      selectedColor: s.couleur.withValues(alpha: 0.15),
                      onSelected: (sel) => setState(() => _filtreStatutLocation = sel ? s : null),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ],

          // Liste des résultats
          Expanded(
            child: _vue == _VueLocations.occupation
                ? _buildVueOccupation(biensAsync, tousLesBiens, biensFiltres)
                : _buildVueHistorique(locationsAsync, toutesLesLocations, locationsFiltrees),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_home_work_rounded),
        label: const Text('Nouvelle Location', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () => context.push(Routes.locationNouvelle),
      ),
    );
  }

  Widget _buildVueOccupation(
    AsyncValue<List<BienImmobilier>> biensAsync,
    List<BienImmobilier> tousLesBiens,
    List<BienImmobilier> biensFiltres,
  ) {
    return biensAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => MessageView(
        icon: Icons.error_outline,
        title: 'Erreur',
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
              message: 'Enregistrez d\'abord vos biens pour suivre leur état d\'occupation.',
              action: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Créer un bien'),
                onPressed: () => context.push(Routes.bienNouveau),
              ),
            ),
          );
        }

        if (biensFiltres.isEmpty) {
          return const Center(child: Text('Aucun bien ne correspond aux critères de filtre.'));
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(biensListProvider);
            ref.invalidate(locationsListProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 4, bottom: 80),
            itemCount: biensFiltres.length,
            itemBuilder: (context, index) {
              final bien = biensFiltres[index];
              return BienOccupationCard(bien: bien);
            },
          ),
        );
      },
    );
  }

  Widget _buildVueHistorique(
    AsyncValue<List<LocationImmobilier>> locationsAsync,
    List<LocationImmobilier> toutesLesLocations,
    List<LocationImmobilier> locationsFiltrees,
  ) {
    return locationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => MessageView(
        icon: Icons.error_outline,
        title: 'Erreur',
        message: err.toString(),
        action: FilledButton.icon(
          onPressed: () => ref.invalidate(locationsListProvider),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Réessayer'),
        ),
      ),
      data: (_) {
        if (toutesLesLocations.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 72),
            child: MessageView(
              icon: Icons.history_edu_outlined,
              title: 'Aucune location active ou archivée',
              message: 'Les baux et locations assignés apparaîtront dans cette liste.',
              action: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                icon: const Icon(Icons.add_home_work_rounded),
                label: const Text('Créer une location'),
                onPressed: () => context.push(Routes.locationNouvelle),
              ),
            ),
          );
        }

        if (locationsFiltrees.isEmpty) {
          return const Center(child: Text('Aucune location ne correspond aux critères.'));
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(locationsListProvider),
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 4, bottom: 80),
            itemCount: locationsFiltrees.length,
            itemBuilder: (context, index) {
              final location = locationsFiltrees[index];
              return LocationCard(location: location);
            },
          ),
        );
      },
    );
  }
}
