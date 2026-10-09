import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/finance_period_filter.dart';
import '../providers/finance_dashboard_providers.dart';
import 'bottom_sheet_filtre_mobile.dart';

/// Header des filtres du centre financier (Période, Activité, Boutique/Site).
class HeaderFiltresFinanciers extends ConsumerWidget {
  const HeaderFiltresFinanciers({
    super.key,
    this.onActualiser,
    this.onExporter,
  });

  final VoidCallback? onActualiser;
  final VoidCallback? onExporter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ctx = ref.watch(contexteActifProvider);
    final periode = ref.watch(financePeriodFilterProvider);
    final activite = ref.watch(financeActiviteFilterProvider);
    final perimetreId = ref.watch(financePerimetreFilterProvider);

    final activitesActives = ctx?.activites.where((a) => a.estActive).toList() ?? [];
    final multiActivites = activitesActives.length > 1;

    final perimetres = ctx?.perimetres.where((p) => p.estActif).toList() ?? [];
    final multiPerimetres = perimetres.length > 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 720;

        if (isMobile) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: AppColors.border),
                      backgroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.tune_rounded, size: 20, color: AppColors.green),
                    label: Text(
                      '${periode.libelleCourt()}${activite != null ? ' · ${_nomActivite(activite)}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink),
                    ),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (_) => const BottomSheetFiltreMobile(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (onActualiser != null)
                  IconButton.filledTonal(
                    tooltip: 'Actualiser',
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: onActualiser,
                  ),
                if (onExporter != null)
                  IconButton.filledTonal(
                    tooltip: 'Exporter',
                    icon: const Icon(Icons.file_download_outlined, size: 20),
                    onPressed: onExporter,
                  ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Segment de périodes
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<TypePeriodeFinance>(
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  segments: const [
                    ButtonSegment(value: TypePeriodeFinance.aujourdhui, label: Text("Aujourd'hui")),
                    ButtonSegment(value: TypePeriodeFinance.cetteSemaine, label: Text('Semaine')),
                    ButtonSegment(value: TypePeriodeFinance.ceMois, label: Text('Mois')),
                    ButtonSegment(value: TypePeriodeFinance.ceTrimestre, label: Text('Trimestre')),
                    ButtonSegment(value: TypePeriodeFinance.cetteAnnee, label: Text('Année')),
                  ],
                  selected: {periode.type},
                  onSelectionChanged: (s) {
                    if (s.isNotEmpty) {
                      ref.read(financePeriodFilterProvider.notifier).choisir(s.first);
                    }
                  },
                ),
              ),

              // Sélecteurs Activité & Périmètre + Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (multiActivites) ...[
                    DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButton<ActiviteCode?>(
                          value: activite,
                          hint: const Text('Toutes activités', style: TextStyle(fontSize: 13)),
                          style: const TextStyle(fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.w500),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Toutes activités')),
                            for (final a in activitesActives)
                              DropdownMenuItem(value: a.activite, child: Text(_nomActivite(a.activite))),
                          ],
                          onChanged: (v) => ref.read(financeActiviteFilterProvider.notifier).filtrer(v),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],

                  if (multiPerimetres) ...[
                    DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButton<String?>(
                          value: perimetreId,
                          hint: const Text('Toutes les boutiques', style: TextStyle(fontSize: 13)),
                          style: const TextStyle(fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.w500),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Toutes boutiques')),
                            for (final p in perimetres) DropdownMenuItem(value: p.id, child: Text(p.nom)),
                          ],
                          onChanged: (v) => ref.read(financePerimetreFilterProvider.notifier).filtrer(v),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],

                  IconButton(
                    tooltip: 'Sélectionner une plage personnalisée',
                    icon: const Icon(Icons.date_range_rounded, size: 20, color: AppColors.muted),
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDateRange: DateTimeRange(
                          start: periode.resoudre(DateTime.now()).debut,
                          end: periode.resoudre(DateTime.now()).fin,
                        ),
                      );
                      if (picked != null) {
                        ref.read(financePeriodFilterProvider.notifier).choisir(
                              TypePeriodeFinance.personnalise,
                              debut: picked.start,
                              fin: picked.end,
                            );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _nomActivite(ActiviteCode code) => switch (code) {
        ActiviteCode.commerce => 'Commerce',
        ActiviteCode.services => 'Services',
        ActiviteCode.immobilier => 'Immobilier',
      };
}
