import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../../perimetres/domain/services/boutiques_naming_service.dart';
import '../../domain/entities/espace_courant.dart';
import '../providers/contexte_providers.dart';
import '../providers/espace_providers.dart';

/// Sélecteur moderne de Boutique / Périmètre opérationnel.
/// Respecte strictement les règles :
/// 1. Entreprise avec 1 seule boutique (ou utilisateur affecté à 1 seule boutique) :
///    Affichage direct et discret, sans dropdown inutile.
/// 2. Entreprise multi-boutiques avec utilisateur multi-boutiques/admin :
///    Sélecteur compact [ Toutes les boutiques ▼ ] ou [ Boutique A ▼ ].
/// 3. Distinction très claire entre « ▣ Toutes les boutiques (Vue consolidée) »
///    et les boutiques réelles « 🏪 Boutique A ».
class EspaceSelector extends ConsumerWidget {
  const EspaceSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ctx = ref.watch(contexteActifProvider);
    final espace = ref.watch(espaceCourantProvider);
    if (ctx == null) return const SizedBox.shrink();

    final sitesAutorises = EspaceCourant.sitesPour(ctx, espace.activite);
    final estMonosite = sitesAutorises.length <= 1;

    final estVueConsolidee = BoutiquesNamingService.estVueConsolidee(espace);
    final nomBoutique = BoutiquesNamingService.libelleBoutique(ctx: ctx, perimetreId: espace.perimetreId);

    // CAS 1 : 1 seule boutique accessible -> Affichage direct sans interaction superflue
    if (estMonosite) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF01226C).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF01226C).withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_rounded, size: 15, color: Color(0xFF01226C)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                nomBoutique,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF01226C),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // CAS 2 : Multi-boutiques -> Sélecteur interactif professionnel
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('espace-selector'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          useSafeArea: true,
          isScrollControlled: true,
          builder: (_) => const _EspaceSheet(),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: estVueConsolidee
                ? const Color(0xFF01226C).withValues(alpha: 0.08)
                : const Color(0xFFDF9540).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: estVueConsolidee
                  ? const Color(0xFF01226C).withValues(alpha: 0.2)
                  : const Color(0xFFDF9540).withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                estVueConsolidee ? Icons.grid_view_rounded : Icons.storefront_rounded,
                size: 15,
                color: estVueConsolidee ? const Color(0xFF01226C) : const Color(0xFF94570E),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  nomBoutique,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: estVueConsolidee ? const Color(0xFF01226C) : const Color(0xFF94570E),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: estVueConsolidee ? const Color(0xFF01226C) : const Color(0xFF94570E),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EspaceSheet extends ConsumerWidget {
  const _EspaceSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ctx = ref.watch(contexteActifProvider);
    final espace = ref.watch(espaceCourantProvider);
    final controller = ref.read(espaceCourantProvider.notifier);
    if (ctx == null) return const SizedBox.shrink();

    final sites = EspaceCourant.sitesPour(ctx, espace.activite);
    final estConsolidee = espace.perimetreId == null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Titre
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF01226C).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.store_mall_directory_rounded, color: Color(0xFF01226C), size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Sélectionner une boutique',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // 1. OPTION VUE CONSOLIDÉE
            Container(
              decoration: BoxDecoration(
                color: estConsolidee ? const Color(0xFF01226C).withValues(alpha: 0.08) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: estConsolidee ? const Color(0xFF01226C) : AppColors.border,
                  width: estConsolidee ? 1.5 : 1,
                ),
              ),
              child: ListTile(
                key: const Key('espace-site-tous'),
                onTap: () {
                  controller.choisirSite(null);
                  Navigator.pop(context);
                },
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: estConsolidee ? const Color(0xFF01226C) : AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.grid_view_rounded,
                    size: 20,
                    color: estConsolidee ? Colors.white : AppColors.muted,
                  ),
                ),
                title: const Text(
                  'Toutes les boutiques',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                subtitle: Text(
                  'Vue consolidée · Cumul des ${sites.length} boutiques actives',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                trailing: estConsolidee
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF01226C))
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Séparateur
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'BOUTIQUES PHYSIQUES (${sites.length})',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.5),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // 2. LISTE DES BOUTIQUES RÉELLES
            for (var i = 0; i < sites.length; i++) ...[
              Builder(builder: (context) {
                final p = sites[i];
                final estSelectionne = espace.perimetreId == p.id;
                final lettre = BoutiquesNamingService.lettreBoutique(i);

                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: estSelectionne ? const Color(0xFF01226C).withValues(alpha: 0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: estSelectionne ? const Color(0xFF01226C) : AppColors.border,
                      width: estSelectionne ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    key: Key('espace-site-${p.id}'),
                    onTap: () {
                      controller.choisirSite(p.id);
                      Navigator.pop(context);
                    },
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: estSelectionne ? const Color(0xFF01226C) : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        lettre,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: estSelectionne ? Colors.white : const Color(0xFF01226C),
                        ),
                      ),
                    ),
                    title: Text(
                      p.nom,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: estSelectionne ? const Color(0xFF01226C) : AppColors.ink,
                      ),
                    ),
                    subtitle: Text(
                      p.code != null ? 'Code: ${p.code} · ${l10n.activite(p.activite)}' : l10n.activite(p.activite),
                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                    trailing: estSelectionne
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF01226C))
                        : null,
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
