import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:dubagest/app/theme/app_theme.dart';
import 'package:dubagest/features/commerce/domain/entities/intelligence_commerciale_data.dart';
import 'package:dubagest/features/commerce/presentation/providers/intelligence_commerciale_providers.dart';
import 'package:dubagest/features/entreprise/domain/entities/contexte_session.dart';
import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import 'package:dubagest/features/perimetres/domain/entities/perimetre.dart';
import 'modal_selection_periode.dart';

class HeaderIntelligence extends ConsumerWidget {
  const HeaderIntelligence({super.key, required this.dateCalcul});
  final DateTime dateCalcul;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ContexteSession? ctx = ref.watch(contexteActifProvider);
    final PeriodeAnalyseType periode = ref.watch(periodeAnalyseProvider);
    final String? perimetreId = ref.watch(perimetreSelectionneCommerceProvider);
    final List<Perimetre> perimetres = ctx?.perimetres ?? const <Perimetre>[];

    final heureMaj = DateFormat('HH:mm').format(dateCalcul);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF01226C), Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF01226C).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Color(0xFFDF9540),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Intelligence commerciale',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF01226C),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Comprenez vos ventes, anticipez vos besoins.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Badge statut synchro/offline
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E7E4E).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF1E7E4E).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, size: 13, color: Color(0xFF1E7E4E)),
                    const SizedBox(width: 4),
                    Text(
                      'Direct $heureMaj',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E7E4E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          // Barre de filtres (Période + Boutique)
          Row(
            children: [
              // Sélecteur de période interactif
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => afficherSelecteurPeriode(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF01226C).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF01226C).withValues(alpha: 0.2),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF01226C)),
                      const SizedBox(width: 8),
                      Text(
                        periode.libelle,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF01226C),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF01226C)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Sélecteur de Boutique si l'entreprise a plusieurs sites
              if (perimetres.length > 1)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 1.2),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: perimetreId,
                        isExpanded: true,
                        icon: const Icon(Icons.storefront_rounded, size: 17, color: AppColors.muted),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Toutes les boutiques'),
                          ),
                          for (final p in perimetres)
                            DropdownMenuItem<String?>(
                              value: p.id,
                              child: Text(p.nom, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (val) {
                          ref.read(perimetreSelectionneCommerceProvider.notifier).filtrer(val);
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
