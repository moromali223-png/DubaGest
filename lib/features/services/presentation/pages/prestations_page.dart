import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../commerce/presentation/widgets/commerce_widgets.dart' show montant;
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
        title: const Text('Contrats de service'),
        actions: const [
          SyncStatusButton(),
        ],
      ),
      floatingActionButton: droits.peutCreerPrestations
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/services/prestations/new'),
              icon: const Icon(Icons.add),
              label: const Text('Nouveau contrat'),
            )
          : null,
      body: AsyncValueView<List<Prestation>>(
        value: prestationsAsync,
        onRetry: () => ref.invalidate(prestationsProvider),
        data: (prestations) {
          // Isole les contrats de service (exclut les interventions de terrain explicitement marquées)
          final contrats = prestations
              .where((p) => p.champsMetier['type_dossier'] != 'INTERVENTION' && (p.dureeMinutes == null || p.dureeMinutes == 0))
              .toList();

          final filtrees = contrats.where((p) {
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

          // Calcul des indicateurs dédiés aux contrats
          final enCours = contrats.where((p) => p.statut == StatutPrestation.enCours).length;
          final aFaire = contrats.where((p) => p.statut == StatutPrestation.aFaire || p.statut == StatutPrestation.planifiee).length;
          final totalReste = contrats.fold<int>(0, (sum, p) => sum + p.soldeRestant);

          return ResponsiveBody(
            maxWidth: 900,
            child: Column(
              children: [
                // Zone des indicateurs
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      _StatMiniCard(
                        label: 'À réaliser',
                        value: aFaire.toString(),
                        icon: Icons.assignment_late_outlined,
                        color: AppColors.green,
                        onTap: () => setState(() => _filtreStatut = 'A_FAIRE'),
                      ),
                      const SizedBox(width: 12),
                      _StatMiniCard(
                        label: 'En cours',
                        value: enCours.toString(),
                        icon: Icons.pending_actions_rounded,
                        color: AppColors.gold,
                        onTap: () => setState(() => _filtreStatut = 'EN_COURS'),
                      ),
                      const SizedBox(width: 12),
                      _StatMiniCard(
                        label: 'Reste à percevoir',
                        value: montant(context, ref, totalReste),
                        icon: Icons.account_balance_wallet_outlined,
                        color: AppColors.positive,
                        isLarge: true,
                      ),
                    ],
                  ),
                ),

                // Barre de recherche
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher un client, une référence...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.green),
                      fillColor: AppColors.surface,
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
                        label: 'Tous (${contrats.length})',
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
                        label: 'Terminés',
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
                                const Icon(Icons.assignment_outlined, size: 48, color: AppColors.muted),
                                const SizedBox(height: 12),
                                const Text(
                                  'Aucun contrat de service trouvé',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _recherche.isNotEmpty
                                      ? 'Modifiez votre recherche ou réinitialisez les filtres.'
                                      : 'Les contrats de service créés (locations, suivis, couvaisons) apparaîtront ici.',
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

class _StatMiniCard extends StatelessWidget {
  const _StatMiniCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isLarge = false,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isLarge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: isLarge ? 2 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isLarge ? 18 : 16,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color.withValues(alpha: 0.8),
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
    final activeColor = couleur ?? AppColors.green;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : (couleur ?? AppColors.ink),
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
          letterSpacing: -0.5,
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
