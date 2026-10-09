import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../domain/entities/prestation.dart';
import '../services_providers.dart';
import '../widgets/prestation_rappel_dialog.dart';
import '../widgets/services_widgets.dart';

/// Planning intelligent multi-vues des prestations (Aujourd'hui, Demain, Cette semaine, Ce mois, Date précise, En retard).
class ServicesPlanningPage extends ConsumerStatefulWidget {
  const ServicesPlanningPage({super.key, this.vueInitiale});
  final String? vueInitiale;

  @override
  ConsumerState<ServicesPlanningPage> createState() => _ServicesPlanningPageState();
}

class _ServicesPlanningPageState extends ConsumerState<ServicesPlanningPage> {
  late String _vue = widget.vueInitiale ?? 'aujourdhui';
  DateTime _dateSelectionnee = DateTime.now();

  void _changerDate(int deltaJours) {
    setState(() {
      _vue = 'date';
      _dateSelectionnee = _dateSelectionnee.add(Duration(days: deltaJours));
    });
  }

  Future<void> _choisirDate(BuildContext context) async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dateSelectionnee,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (d != null) {
      setState(() {
        _vue = 'date';
        _dateSelectionnee = d;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prestationsAsync = ref.watch(prestationsProvider);
    final moteur = ref.watch(moteurEcheancesProvider);
    final now = DateTime.now();

    final debutJour = DateTime(now.year, now.month, now.day);
    final finJour = debutJour.add(const Duration(days: 1));
    final demainDebut = finJour;
    final demainFin = demainDebut.add(const Duration(days: 1));
    final finSemaine = debutJour.add(Duration(days: 7 - debutJour.weekday + 1));
    final finMois = DateTime(now.year, now.month + 1, 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planning & Agenda'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Choisir une date',
            onPressed: () => _choisirDate(context),
          ),
          const SyncStatusButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final d = _vue == 'date'
              ? _dateSelectionnee
              : (_vue == 'demain' ? DateTime.now().add(const Duration(days: 1)) : DateTime.now());
          context.push('${Routes.prestationNouvelle}?date=${d.toIso8601String()}');
        },
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle intervention'),
      ),
      body: AsyncValueView<List<Prestation>>(
        value: prestationsAsync,
        onRetry: () => ref.invalidate(prestationsProvider),
        data: (prestations) {
          // Calcul des compteurs par vue
          final nbAujourdhui = prestations.where((p) {
            if (p.statut == StatutPrestation.annulee) return false;
            final ech = p.dateEcheanceComplete;
            return (ech != null && ech.isAfter(debutJour) && ech.isBefore(finJour)) ||
                (moteur.calculerPriorite(p, now) == PrioriteEcheance.aujourdhui);
          }).length;

          final nbDemain = prestations.where((p) {
            if (p.statut == StatutPrestation.annulee) return false;
            final ech = p.dateEcheanceComplete;
            return ech != null && ech.isAfter(demainDebut) && ech.isBefore(demainFin);
          }).length;

          final nbSemaine = prestations.where((p) {
            if (p.statut == StatutPrestation.annulee) return false;
            final ech = p.dateEcheanceComplete;
            return ech != null && ech.isAfter(debutJour) && ech.isBefore(finSemaine);
          }).length;

          final nbRetard = prestations.where((p) {
            if (p.statut == StatutPrestation.annulee) return false;
            return moteur.calculerPriorite(p, now) == PrioriteEcheance.enRetard;
          }).length;

          // Filtrage selon la vue active
          final filtrees = prestations.where((p) {
            if (p.statut == StatutPrestation.annulee) return false;
            final echeance = p.dateEcheanceComplete;

            if (_vue == 'retard') {
              return moteur.calculerPriorite(p, now) == PrioriteEcheance.enRetard;
            }

            if (_vue == 'date') {
              if (echeance == null) return false;
              final debutCible = DateTime(_dateSelectionnee.year, _dateSelectionnee.month, _dateSelectionnee.day);
              final finCible = debutCible.add(const Duration(days: 1));
              return echeance.isAfter(debutCible) && echeance.isBefore(finCible);
            }

            if (echeance == null) return _vue == 'toutes';

            if (_vue == 'aujourdhui') {
              return (echeance.isAfter(debutJour) && echeance.isBefore(finJour)) ||
                  (moteur.calculerPriorite(p, now) == PrioriteEcheance.aujourdhui);
            } else if (_vue == 'demain') {
              return echeance.isAfter(demainDebut) && echeance.isBefore(demainFin);
            } else if (_vue == 'semaine') {
              return echeance.isAfter(debutJour) && echeance.isBefore(finSemaine);
            } else if (_vue == 'mois') {
              return echeance.isAfter(debutJour) && echeance.isBefore(finMois);
            }

            return true;
          }).toList();

          // Tri chronologique
          filtrees.sort((a, b) {
            final dateA = a.dateEcheanceComplete ?? DateTime(2099);
            final dateB = b.dateEcheanceComplete ?? DateTime(2099);
            return dateA.compareTo(dateB);
          });

          return ResponsiveBody(
            maxWidth: 860,
            child: Column(
              children: [
                // Barre de navigation journalière
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        tooltip: 'Jour précédent',
                        onPressed: () => _changerDate(-1),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => _choisirDate(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.event_note_rounded, size: 18, color: Color(0xFF01226C)),
                                const SizedBox(width: 8),
                                Text(
                                  _vue == 'date'
                                      ? DateFormat('EEEE dd MMMM yyyy', 'fr_FR').format(_dateSelectionnee)
                                      : 'Aujourd\'hui : ${DateFormat('EEEE dd MMMM yyyy', 'fr_FR').format(now)}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.ink),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        tooltip: 'Jour suivant',
                        onPressed: () => _changerDate(1),
                      ),
                    ],
                  ),
                ),

                // Sélecteur de vues rapides
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _PlanningChip(
                        label: 'Aujourd\'hui ($nbAujourdhui)',
                        selected: _vue == 'aujourdhui',
                        onSelected: () => setState(() => _vue = 'aujourdhui'),
                      ),
                      const SizedBox(width: 8),
                      _PlanningChip(
                        label: 'Demain ($nbDemain)',
                        selected: _vue == 'demain',
                        onSelected: () => setState(() => _vue = 'demain'),
                      ),
                      const SizedBox(width: 8),
                      _PlanningChip(
                        label: 'Cette semaine ($nbSemaine)',
                        selected: _vue == 'semaine',
                        onSelected: () => setState(() => _vue = 'semaine'),
                      ),
                      const SizedBox(width: 8),
                      _PlanningChip(
                        label: 'Ce mois-ci',
                        selected: _vue == 'mois',
                        onSelected: () => setState(() => _vue = 'mois'),
                      ),
                      const SizedBox(width: 8),
                      _PlanningChip(
                        label: '⚠️ En retard ($nbRetard)',
                        couleur: AppColors.negative,
                        selected: _vue == 'retard',
                        onSelected: () => setState(() => _vue = 'retard'),
                      ),
                      const SizedBox(width: 8),
                      _PlanningChip(
                        label: 'Toutes (${prestations.length})',
                        selected: _vue == 'toutes',
                        onSelected: () => setState(() => _vue = 'toutes'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Liste du planning
                Expanded(
                  child: filtrees.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.event_available_rounded, size: 48, color: AppColors.muted),
                                const SizedBox(height: 12),
                                const Text(
                                  'Aucune prestation sur ce créneau',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Consultez les autres vues ou planifiez une nouvelle intervention.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.muted, fontSize: 13),
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
                            return Stack(
                              children: [
                                PrestationCard(
                                  prestation: p,
                                  onTap: () => context.push('/services/prestations/${p.id}'),
                                ),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: IconButton(
                                    icon: const Icon(Icons.notifications_active_outlined, size: 18, color: Color(0xFF01226C)),
                                    tooltip: 'Envoyer un rappel',
                                    onPressed: () => PrestationRappelDialog.afficher(context, p),
                                  ),
                                ),
                              ],
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

class _PlanningChip extends StatelessWidget {
  const _PlanningChip({
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
      backgroundColor: (couleur ?? AppColors.surface).withValues(alpha: selected ? 1.0 : 0.08),
      side: BorderSide(
        color: selected ? activeColor : (couleur?.withValues(alpha: 0.3) ?? AppColors.border),
      ),
      onSelected: (_) => onSelected(),
    );
  }
}
