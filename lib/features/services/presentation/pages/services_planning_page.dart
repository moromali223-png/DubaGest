import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../domain/entities/prestation.dart';
import '../services_providers.dart';
import '../widgets/prestation_rappel_dialog.dart';

/// Planning opérationnel multi-vues des prestations.
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
      locale: const Locale('fr', 'FR'),
    );
    if (d != null) {
      setState(() {
        _vue = 'date';
        _dateSelectionnee = d;
      });
    }
  }

  String get _titreDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(_dateSelectionnee.year, _dateSelectionnee.month, _dateSelectionnee.day);

    if (_vue == 'date') {
      if (target == today) return 'Aujourd’hui';
      if (target == today.add(const Duration(days: 1))) return 'Demain';
      if (target == today.subtract(const Duration(days: 1))) return 'Hier';
      return DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(_dateSelectionnee);
    }
    return DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(now);
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Planning & Agenda'),
        centerTitle: false,
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
          context.push(Routes.planningNouveauAvecDate(d));
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouvelle intervention'),
      ),
      body: AsyncValueView<List<Prestation>>(
        value: prestationsAsync,
        onRetry: () => ref.invalidate(prestationsProvider),
        data: (prestations) {
          // Isole strictement les interventions de terrain (exclut les contrats de service)
          final interventions = prestations.where((p) => p.estIntervention).toList();

          // Compteurs
          final nbAujourdhui = interventions.where((p) {
            if (p.statut == StatutPrestation.annulee) return false;
            final ech = p.dateEcheanceComplete;
            return (ech != null && ech.isAfter(debutJour) && ech.isBefore(finJour)) ||
                (moteur.calculerPriorite(p, now) == PrioriteEcheance.aujourdhui);
          }).length;

          final nbDemain = interventions.where((p) {
            if (p.statut == StatutPrestation.annulee) return false;
            final ech = p.dateEcheanceComplete;
            return ech != null && ech.isAfter(demainDebut) && ech.isBefore(demainFin);
          }).length;

          final nbSemaine = interventions.where((p) {
            if (p.statut == StatutPrestation.annulee) return false;
            final ech = p.dateEcheanceComplete;
            return ech != null && ech.isAfter(debutJour) && ech.isBefore(finSemaine);
          }).length;

          final nbRetard = interventions.where((p) {
            if (p.statut == StatutPrestation.annulee) return false;
            return moteur.calculerPriorite(p, now) == PrioriteEcheance.enRetard;
          }).length;

          // Filtrage
          final filtrees = interventions.where((p) {
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

          // Tri
          filtrees.sort((a, b) {
            final dateA = a.dateEcheanceComplete ?? DateTime(2099);
            final dateB = b.dateEcheanceComplete ?? DateTime(2099);
            return dateA.compareTo(dateB);
          });

          return Column(
            children: [
              // ─── HEADER OPÉRATIONNEL ───
              Container(
                width: double.infinity,
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  children: [
                    // Navigation jour
                    Row(
                      children: [
                        _NavIconButton(
                          icon: Icons.chevron_left_rounded,
                          onPressed: () => _changerDate(-1),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _choisirDate(context),
                            child: Column(
                              children: [
                                Text(
                                  _titreDate,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('d MMMM yyyy', 'fr_FR').format(
                                    _vue == 'date' ? _dateSelectionnee : now,
                                  ),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _NavIconButton(
                          icon: Icons.chevron_right_rounded,
                          onPressed: () => _changerDate(1),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Compteurs rapides (KPI strip)
                    Row(
                      children: [
                        _KpiChip(
                          label: 'Aujourd’hui',
                          value: nbAujourdhui,
                          selected: _vue == 'aujourdhui',
                          onTap: () => setState(() => _vue = 'aujourdhui'),
                        ),
                        const SizedBox(width: 8),
                        _KpiChip(
                          label: 'Demain',
                          value: nbDemain,
                          selected: _vue == 'demain',
                          onTap: () => setState(() => _vue = 'demain'),
                        ),
                        const SizedBox(width: 8),
                        _KpiChip(
                          label: 'Semaine',
                          value: nbSemaine,
                          selected: _vue == 'semaine',
                          onTap: () => setState(() => _vue = 'semaine'),
                        ),
                        const SizedBox(width: 8),
                        _KpiChip(
                          label: 'En retard',
                          value: nbRetard,
                          isAlert: true,
                          selected: _vue == 'retard',
                          onTap: () => setState(() => _vue = 'retard'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ─── FILTRES SECONDAIRES ───
              Container(
                width: double.infinity,
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _SecondaryFilter(
                        label: 'Ce mois',
                        selected: _vue == 'mois',
                        onTap: () => setState(() => _vue = 'mois'),
                      ),
                      const SizedBox(width: 8),
                      _SecondaryFilter(
                        label: 'Toutes',
                        selected: _vue == 'toutes',
                        onTap: () => setState(() => _vue = 'toutes'),
                      ),
                      if (_vue == 'date') ...[
                        const SizedBox(width: 8),
                        _SecondaryFilter(
                          label: 'Date précise',
                          selected: true,
                          onTap: () {},
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const Divider(height: 1),

              // ─── LISTE ───
              Expanded(
                child: filtrees.isEmpty
                    ? _EmptyPlanningState(
                        onCreate: () {
                          final d = _vue == 'date'
                              ? _dateSelectionnee
                              : DateTime.now();
                          context.push(Routes.planningNouveauAvecDate(d));
                        },
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: filtrees.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (_, idx) {
                          final p = filtrees[idx];
                          final priorite = moteur.calculerPriorite(p, now);

                          return _PlanningItem(
                            prestation: p,
                            priorite: priorite,
                            onTap: () => context.push('/services/prestations/${p.id}'),
                            onRappel: () => PrestationRappelDialog.afficher(context, p),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  COMPOSANTS SPÉCIFIQUES AU PLANNING
// ─────────────────────────────────────────────

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 22, color: AppColors.ink),
        ),
      ),
    );
  }
}

class _KpiChip extends StatelessWidget {
  const _KpiChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
    this.isAlert = false,
  });

  final String label;
  final int value;
  final bool selected;
  final VoidCallback onTap;
  final bool isAlert;

  @override
  Widget build(BuildContext context) {
    final activeColor = isAlert ? AppColors.negative : AppColors.primary;
    final bg = selected
        ? activeColor
        : (isAlert ? AppColors.negative.withValues(alpha: 0.08) : AppColors.background);
    final fg = selected ? Colors.white : (isAlert ? AppColors.negative : AppColors.ink);

    return Expanded(
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? activeColor
                    : (isAlert ? AppColors.negative.withValues(alpha: 0.25) : AppColors.border),
              ),
            ),
            child: Column(
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: fg,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white.withValues(alpha: 0.9) : AppColors.muted,
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

class _SecondaryFilter extends StatelessWidget {
  const _SecondaryFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _PlanningItem extends StatelessWidget {
  const _PlanningItem({
    required this.prestation,
    required this.priorite,
    required this.onTap,
    required this.onRappel,
  });

  final Prestation prestation;
  final PrioriteEcheance priorite;
  final VoidCallback onTap;
  final VoidCallback onRappel;

  Color get _accentColor {
    switch (priorite) {
      case PrioriteEcheance.enRetard:
        return AppColors.negative;
      case PrioriteEcheance.aujourdhui:
        return AppColors.primary;
      default:
        return AppColors.border;
    }
  }

  String get _prioriteLabel {
    switch (priorite) {
      case PrioriteEcheance.enRetard:
        return 'En retard';
      case PrioriteEcheance.aujourdhui:
        return 'Aujourd’hui';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final echeance = prestation.dateEcheanceComplete;
    final heure = echeance != null
        ? DateFormat('HH:mm').format(echeance)
        : '—';

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barre de priorité
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: _accentColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Heure
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                heure,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                            if (_prioriteLabel.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _accentColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _prioriteLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _accentColor,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.notifications_active_outlined, size: 18),
                              color: AppColors.primary,
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Envoyer un rappel',
                              onPressed: onRappel,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          prestation.titre,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (prestation.lieu != null && prestation.lieu!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.muted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  prestation.lieu!,
                                  style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        // Ligne financière & technicien
                        Row(
                          children: [
                            Text(
                              '${prestation.total} FCFA',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: Color(0xFF01226C),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (prestation.total > 0 && prestation.estPayeIntegralement)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_outline_rounded, size: 12, color: Color(0xFF059669)),
                                    SizedBox(width: 3),
                                    Text(
                                      'Encaissé',
                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                                    ),
                                  ],
                                ),
                              )
                            else if (prestation.total > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDF9540).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.pending_actions_rounded, size: 12, color: Color(0xFFB45309)),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Reste : ${prestation.soldeRestant} F',
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                                    ),
                                  ],
                                ),
                              ),
                            const Spacer(),
                            if (prestation.responsableNom != null && prestation.responsableNom!.isNotEmpty)
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.badge_outlined, size: 13, color: AppColors.muted),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        prestation.responsableNom!,
                                        style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyPlanningState extends StatelessWidget {
  const _EmptyPlanningState({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.event_available_rounded, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucune intervention planifiée',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Ce créneau est libre. Planifiez une nouvelle intervention ou consultez une autre vue.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Planifier une intervention'),
            ),
          ],
        ),
      ),
    );
  }
}