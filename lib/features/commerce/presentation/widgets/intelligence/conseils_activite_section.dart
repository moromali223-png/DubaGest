import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dubagest/app/theme/app_theme.dart';
import 'package:dubagest/features/commerce/domain/entities/intelligence_commerciale_data.dart';

class ConseilsActiviteSection extends StatefulWidget {
  const ConseilsActiviteSection({super.key, required this.conseils});
  final List<ConseilActiviteCommerciale> conseils;

  @override
  State<ConseilsActiviteSection> createState() => _ConseilsActiviteSectionState();
}

class _ConseilsActiviteSectionState extends State<ConseilsActiviteSection> {
  final Set<String> _traites = {};

  @override
  Widget build(BuildContext context) {
    final actifs = widget.conseils.where((c) => !_traites.contains(c.id)).toList();
    if (actifs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFDF9540).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.tips_and_updates_rounded, color: Color(0xFFDF9540), size: 16),
            ),
            const SizedBox(width: 8),
            const Text(
              'Conseils pour votre activité',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF01226C),
              ),
            ),
            const Spacer(),
            Text(
              '${actifs.length} recommandation(s)',
              style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: actifs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) {
              final conseil = actifs[i];
              return _ConseilCard(
                conseil: conseil,
                onTraite: () {
                  setState(() => _traites.add(conseil.id));
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ConseilCard extends StatelessWidget {
  const _ConseilCard({required this.conseil, required this.onTraite});
  final ConseilActiviteCommerciale conseil;
  final VoidCallback onTraite;

  @override
  Widget build(BuildContext context) {
    final (couleur, icone) = switch (conseil.priorite) {
      PrioriteConseil.urgent => (const Color(0xFFDC2626), Icons.warning_amber_rounded),
      PrioriteConseil.important => (const Color(0xFFDF9540), Icons.priority_high_rounded),
      PrioriteConseil.surveiller => (const Color(0xFF0284C7), Icons.visibility_outlined),
      PrioriteConseil.opportunite => (const Color(0xFF1E7E4E), Icons.auto_awesome_rounded),
    };

    return Container(
      width: 290,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: couleur.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: couleur.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icone, size: 12, color: couleur),
                    const SizedBox(width: 4),
                    Text(
                      conseil.priorite.libelle.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: couleur,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                conseil.niveauConfiance,
                style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            conseil.titre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              conseil.constat,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.ink,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (conseil.routeCible != null && conseil.boutonActionTitre != null)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      context.push(conseil.routeCible!);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF01226C),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                    child: Text(conseil.boutonActionTitre!),
                  ),
                ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.check_rounded, size: 16, color: AppColors.muted),
                tooltip: 'Marquer comme traité',
                onPressed: onTraite,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
