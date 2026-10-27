import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/dashboard_immobilier.dart';
import '../providers/immobilier_providers.dart';
import '../widgets/dashboard_widgets.dart';

class ImmobilierDashboardPage extends ConsumerStatefulWidget {
  const ImmobilierDashboardPage({super.key});

  @override
  ConsumerState<ImmobilierDashboardPage> createState() => _ImmobilierDashboardPageState();
}

class _ImmobilierDashboardPageState extends ConsumerState<ImmobilierDashboardPage> {
  NiveauAlerte? _filtreNiveau;

  @override
  Widget build(BuildContext context) {
    final ctx = ref.watch(contexteActifProvider);
    final devise = ctx?.entreprise?.devise ?? 'FCFA';
    final data = ref.watch(dashboardImmobilierProvider);

    final alertesAffichees = data.alertes.where((a) {
      if (_filtreNiveau != null && a.niveau != _filtreNiveau) return false;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de Bord Immobilier'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: () {
              ref.invalidate(biensListProvider);
              ref.invalidate(contratsListProvider);
              ref.invalidate(echeancesLoyersProvider);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(biensListProvider);
            ref.invalidate(contratsListProvider);
            ref.invalidate(echeancesLoyersProvider);
          },
          child: ResponsiveBody(
            maxWidth: 860,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // 1. Indicateurs clés de performance (KPIs)
                KpiImmobilierHeader(data: data, devise: devise),
                const SizedBox(height: 20),

                // 2. Navigation vers les 6 modules métiers
                _buildSectionTitre('Modules de Gestion Immobilière', Icons.grid_view_rounded),
                const SizedBox(height: 10),
                ModuleImmobilierGrid(data: data),
                const SizedBox(height: 20),

                // 3. Répartition du parc immobilier
                _buildSectionTitre('État du Parc', Icons.donut_large_rounded),
                const SizedBox(height: 10),
                RepartitionBiensBar(data: data),
                const SizedBox(height: 20),

                // 4. Alertes Métier & Actions prioritaires
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionTitre('Alertes & Échéances', Icons.notifications_active_outlined),
                    if (data.nbAlertesCritiques > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '${data.nbAlertesCritiques} urgente(s)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Filtres des alertes
                if (data.alertes.isNotEmpty) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        FilterChip(
                          label: Text('Toutes (${data.alertes.length})'),
                          selected: _filtreNiveau == null,
                          onSelected: (_) => setState(() => _filtreNiveau = null),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: Text('Urgentes (${data.nbAlertesCritiques})'),
                          avatar: const Icon(Icons.error_outline, size: 14, color: Color(0xFFEF4444)),
                          selected: _filtreNiveau == NiveauAlerte.critique,
                          onSelected: (_) => setState(() => _filtreNiveau = NiveauAlerte.critique),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Avertissements'),
                          avatar: const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFDF9540)),
                          selected: _filtreNiveau == NiveauAlerte.avertissement,
                          onSelected: (_) => setState(() => _filtreNiveau = NiveauAlerte.avertissement),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Informations'),
                          avatar: const Icon(Icons.info_outline, size: 14, color: Color(0xFF3B82F6)),
                          selected: _filtreNiveau == NiveauAlerte.information,
                          onSelected: (_) => setState(() => _filtreNiveau = NiveauAlerte.information),
                        ),
                      ],
                    ),
                  ),
                ],

                // Liste des alertes ou état vierge
                if (alertesAffichees.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 28),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Situation sous contrôle',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Aucun retard de loyer critique ni fin de bail imminente pour le moment.',
                                style: TextStyle(fontSize: 12, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final alerte in alertesAffichees)
                    AlerteImmobilierCard(alerte: alerte, devise: devise),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitre(String titre, IconData icone) {
    return Row(
      children: [
        Icon(icone, size: 18, color: const Color(0xFF01226C)),
        const SizedBox(width: 8),
        Text(
          titre,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}
