import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dubagest/app/theme/app_theme.dart';
import 'package:dubagest/features/commerce/presentation/providers/intelligence_commerciale_providers.dart';

class SelecteurOngletsIntelligence extends ConsumerWidget {
  const SelecteurOngletsIntelligence({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ongletActif = ref.watch(vueActiveIntelligenceProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final onglet in VueIntelligenceOnglet.values) ...[
            _OngletChip(
              onglet: onglet,
              actif: onglet == ongletActif,
              onTap: () {
                ref.read(vueActiveIntelligenceProvider.notifier).choisir(onglet);
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _OngletChip extends StatelessWidget {
  const _OngletChip({
    required this.onglet,
    required this.actif,
    required this.onTap,
  });

  final VueIntelligenceOnglet onglet;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icone = switch (onglet) {
      VueIntelligenceOnglet.ventes => Icons.trending_up_rounded,
      VueIntelligenceOnglet.produits => Icons.local_offer_outlined,
      VueIntelligenceOnglet.stocks => Icons.inventory_2_outlined,
      VueIntelligenceOnglet.paniers => Icons.shopping_basket_outlined,
      VueIntelligenceOnglet.engagements => Icons.handshake_outlined,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: actif ? const Color(0xFF01226C) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: actif ? const Color(0xFF01226C) : AppColors.border,
            width: 1.2,
          ),
          boxShadow: [
            if (actif)
              BoxShadow(
                color: const Color(0xFF01226C).withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icone,
              size: 16,
              color: actif ? const Color(0xFFDF9540) : AppColors.muted,
            ),
            const SizedBox(width: 8),
            Text(
              onglet.titre,
              style: TextStyle(
                fontSize: 13,
                fontWeight: actif ? FontWeight.w800 : FontWeight.w600,
                color: actif ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
