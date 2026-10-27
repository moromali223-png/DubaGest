import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dubagest/app/theme/app_theme.dart';
import 'package:dubagest/features/commerce/domain/entities/intelligence_commerciale_data.dart';
import 'package:dubagest/features/commerce/presentation/providers/intelligence_commerciale_providers.dart';

/// Modal bottom sheet pour choisir la période d'analyse décisionnelle.
Future<void> afficherSelecteurPeriode(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => const ModalSelectionPeriode(),
  );
}

class ModalSelectionPeriode extends ConsumerWidget {
  const ModalSelectionPeriode({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodeCourante = ref.watch(periodeAnalyseProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Période d’analyse',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Sélectionnez l’horizon temporel pour comparer vos performances.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final type in PeriodeAnalyseType.values)
                    if (type != PeriodeAnalyseType.personnalise)
                      _PeriodeOptionTile(
                        type: type,
                        selectionne: type == periodeCourante,
                        onTap: () {
                          ref.read(periodeAnalyseProvider.notifier).choisir(type);
                          Navigator.pop(context);
                        },
                      ),
                  _OptionPersonnaliseeTile(
                    selectionne: periodeCourante == PeriodeAnalyseType.personnalise,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodeOptionTile extends StatelessWidget {
  const _PeriodeOptionTile({
    required this.type,
    required this.selectionne,
    required this.onTap,
  });

  final PeriodeAnalyseType type;
  final bool selectionne;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: selectionne ? const Color(0xFF01226C).withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selectionne ? const Color(0xFF01226C) : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
        title: Text(
          type.libelle,
          style: TextStyle(
            fontWeight: selectionne ? FontWeight.w700 : FontWeight.w500,
            color: selectionne ? const Color(0xFF01226C) : AppColors.ink,
            fontSize: 14.5,
          ),
        ),
        trailing: selectionne
            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF01226C), size: 20)
            : const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 18),
      ),
    );
  }
}

class _OptionPersonnaliseeTile extends ConsumerWidget {
  const _OptionPersonnaliseeTile({required this.selectionne});
  final bool selectionne;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ({DateTime? debut, DateTime? fin}) perso = ref.watch(datesPersonnaliseesProvider);
    final aDates = perso.debut != null && perso.fin != null;

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 6),
      decoration: BoxDecoration(
        color: selectionne ? const Color(0xFF01226C).withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selectionne ? const Color(0xFF01226C) : AppColors.border,
          width: 1.2,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () async {
          final dates = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 1)),
            initialDateRange: aDates
                ? DateTimeRange(start: perso.debut!, end: perso.fin!)
                : DateTimeRange(
                    start: DateTime.now().subtract(const Duration(days: 7)),
                    end: DateTime.now(),
                  ),
            builder: (ctx, child) {
              return Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF01226C),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: AppColors.ink,
                  ),
                ),
                child: child!,
              );
            },
          );
          if (dates != null) {
            ref.read(datesPersonnaliseesProvider.notifier).definir(
              debut: DateTime(dates.start.year, dates.start.month, dates.start.day),
              fin: DateTime(dates.end.year, dates.end.month, dates.end.day, 23, 59, 59, 999),
            );
            ref.read(periodeAnalyseProvider.notifier).choisir(PeriodeAnalyseType.personnalise);
            if (context.mounted) Navigator.pop(context);
          }
        },
        leading: const Icon(Icons.date_range_rounded, color: Color(0xFFDF9540), size: 22),
        title: const Text(
          'Période personnalisée',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            fontSize: 14.5,
          ),
        ),
        subtitle: Text(
          aDates
              ? '${perso.debut!.day}/${perso.debut!.month}/${perso.debut!.year} → ${perso.fin!.day}/${perso.fin!.month}/${perso.fin!.year}'
              : 'Choisir les dates de début et fin',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        trailing: selectionne
            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF01226C), size: 20)
            : const Icon(Icons.edit_calendar_rounded, color: AppColors.muted, size: 18),
      ),
    );
  }
}
