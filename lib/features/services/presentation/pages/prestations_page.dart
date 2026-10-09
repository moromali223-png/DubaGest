import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../domain/entities/prestation.dart';
import '../services_providers.dart';
import '../widgets/services_widgets.dart';

/// Écran principal de liste des prestations et ordres de travail.
class PrestationsPage extends ConsumerStatefulWidget {
  const PrestationsPage({super.key, this.statutInitial});
  final String? statutInitial;

  @override
  ConsumerState<PrestationsPage> createState() => _PrestationsPageState();
}

class _PrestationsPageState extends ConsumerState<PrestationsPage> {
  String _filtreStatut = 'TOUTES';
  String _recherche = '';

  @override
  void initState() {
    super.initState();
    if (widget.statutInitial != null && widget.statutInitial!.isNotEmpty) {
      _filtreStatut = widget.statutInitial!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final droits = ref.watch(droitsServicesProvider);
    final prestationsAsync = ref.watch(prestationsProvider);
    final moteur = ref.watch(moteurEcheancesProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prestations'),
        actions: const [
          SyncStatusButton(),
        ],
      ),
      floatingActionButton: droits.peutCreerPrestations
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/services/prestations/new'),
              icon: const Icon(Icons.add),
              label: const Text('Prestation'),
            )
          : null,
      body: AsyncValueView<List<Prestation>>(
        value: prestationsAsync,
        onRetry: () => ref.invalidate(prestationsProvider),
        data: (prestations) {
          final filtrees = prestations.where((p) {
            // Filtre statut
            if (_filtreStatut == 'A_FAIRE' && p.statut != StatutPrestation.aFaire && p.statut != StatutPrestation.planifiee) {
              return false;
            } else if (_filtreStatut == 'EN_COURS' && p.statut != StatutPrestation.enCours) {
              return false;
            } else if (_filtreStatut == 'TERMINEE' && !p.statut.estFinie) {
              return false;
            } else if (_filtreStatut == 'RETARD' && moteur.calculerPriorite(p, now) != PrioriteEcheance.enRetard) {
              return false;
            }

            // Recherche texte
            if (_recherche.isNotEmpty) {
              final query = _recherche.toLowerCase();
              final matchTitre = p.titre.toLowerCase().contains(query);
              final matchDesc = p.description?.toLowerCase().contains(query) ?? false;
              final matchResp = p.responsableNom?.toLowerCase().contains(query) ?? false;
              return matchTitre || matchDesc || matchResp;
            }

            return true;
          }).toList();

          return ResponsiveBody(
            maxWidth: 860,
            child: Column(
              children: [
                // Barre de recherche
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher une prestation...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _recherche.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _recherche = ''))
                          : null,
                    ),
                    onChanged: (val) => setState(() => _recherche = val.trim()),
                  ),
                ),

                // Onglets de filtre
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      _FiltreChip(
                        label: 'Toutes (${prestations.length})',
                        selected: _filtreStatut == 'TOUTES',
                        onSelected: () => setState(() => _filtreStatut = 'TOUTES'),
                      ),
                      const SizedBox(width: 8),
                      _FiltreChip(
                        label: 'À faire',
                        selected: _filtreStatut == 'A_FAIRE',
                        onSelected: () => setState(() => _filtreStatut = 'A_FAIRE'),
                      ),
                      const SizedBox(width: 8),
                      _FiltreChip(
                        label: 'En cours',
                        selected: _filtreStatut == 'EN_COURS',
                        onSelected: () => setState(() => _filtreStatut = 'EN_COURS'),
                      ),
                      const SizedBox(width: 8),
                      _FiltreChip(
                        label: 'Terminées',
                        selected: _filtreStatut == 'TERMINEE',
                        onSelected: () => setState(() => _filtreStatut = 'TERMINEE'),
                      ),
                      const SizedBox(width: 8),
                      _FiltreChip(
                        label: '⚠️ En retard',
                        couleur: AppColors.negative,
                        selected: _filtreStatut == 'RETARD',
                        onSelected: () => setState(() => _filtreStatut = 'RETARD'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Liste
                Expanded(
                  child: filtrees.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.assignment_late_outlined, size: 48, color: AppColors.muted),
                                const SizedBox(height: 12),
                                const Text(
                                  'Aucune prestation trouvée',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _recherche.isNotEmpty
                                      ? 'Modifiez votre recherche ou réinitialisez les filtres.'
                                      : 'Les prestations créées apparaîtront ici.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: filtrees.length,
                          itemBuilder: (_, idx) {
                            final p = filtrees[idx];
                            return PrestationCard(
                              prestation: p,
                              onTap: () => context.push('/services/prestations/${p.id}'),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FiltreChip extends StatelessWidget {
  const _FiltreChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.couleur,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final activeColor = couleur ?? const Color(0xFF01226C);
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : (couleur ?? AppColors.ink),
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
      selected: selected,
      selectedColor: activeColor,
      backgroundColor: AppColors.surface,
      side: BorderSide(color: selected ? activeColor : AppColors.border),
      onSelected: (_) => onSelected(),
    );
  }
}
