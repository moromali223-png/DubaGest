import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dubagest/app/theme/app_theme.dart';
import 'package:dubagest/features/commerce/domain/entities/benefice_commerce_data.dart';
import 'package:dubagest/features/commerce/presentation/providers/benefice_commerce_providers.dart';

/// Barre de filtres temporels rapides + bouton de calendrier et période personnalisée.
class SelecteurPeriodeBeneficeBar extends ConsumerWidget {
  const SelecteurPeriodeBeneficeBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(filtreBeneficeProvider);
    final intervalle = ref.watch(intervalleBeneficeCourantProvider);

    final optionsRapides = [
      TypeFiltreBenefice.aujourdhui,
      TypeFiltreBenefice.hier,
      TypeFiltreBenefice.cetteSemaine,
      TypeFiltreBenefice.semainePrecedente,
      TypeFiltreBenefice.ceMois,
      TypeFiltreBenefice.moisPrecedent,
      TypeFiltreBenefice.cetteAnnee,
      TypeFiltreBenefice.anneePrecedente,
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF1E7E4E)),
                    const SizedBox(width: 6),
                    Text(
                      intervalle.libelleAffiche,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E7E4E),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Date précise
                    IconButton(
                      tooltip: 'Date précise',
                      icon: const Icon(Icons.event, size: 18, color: Color(0xFF6B7280)),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: config.datePrecise ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Color(0xFF1E7E4E),
                                  onPrimary: Colors.white,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (date != null) {
                          ref.read(filtreBeneficeProvider.notifier).definirDatePrecise(date);
                        }
                      },
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    ),
                    const SizedBox(width: 4),
                    // Période personnalisée
                    IconButton(
                      tooltip: 'Période personnalisée',
                      icon: const Icon(Icons.date_range, size: 18, color: Color(0xFF6B7280)),
                      onPressed: () async {
                        final range = await showDateRangePicker(
                          context: context,
                          initialDateRange: DateTimeRange(
                            start: config.debutPerso ?? DateTime.now().subtract(const Duration(days: 30)),
                            end: config.finPerso ?? DateTime.now(),
                          ),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Color(0xFF1E7E4E),
                                  onPrimary: Colors.white,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (range != null) {
                          ref.read(filtreBeneficeProvider.notifier).definirPeriodePersonnalisee(range.start, range.end);
                        }
                      },
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final opt in optionsRapides) ...[
                  _FiltreChip(
                    label: opt.libelle,
                    actif: config.type == opt,
                    onTap: () => ref.read(filtreBeneficeProvider.notifier).changerType(opt),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltreChip extends StatelessWidget {
  const _FiltreChip({
    required this.label,
    required this.actif,
    required this.onTap,
  });

  final String label;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: actif ? const Color(0xFF1E7E4E) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: actif ? const Color(0xFF1E7E4E) : AppColors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
            color: actif ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}

