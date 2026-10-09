import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../commerce/presentation/widgets/commerce_widgets.dart' show montant;
import '../../domain/entities/service_catalogue.dart';
import '../services_providers.dart';

/// Catalogue des prestations types proposées par l'entreprise.
class ServicesCataloguePage extends ConsumerStatefulWidget {
  const ServicesCataloguePage({super.key});

  @override
  ConsumerState<ServicesCataloguePage> createState() => _ServicesCataloguePageState();
}

class _ServicesCataloguePageState extends ConsumerState<ServicesCataloguePage> {
  String _recherche = '';
  String? _categorieSelectionnee;

  @override
  Widget build(BuildContext context) {
    final droits = ref.watch(droitsServicesProvider);
    final catalogueAsync = ref.watch(servicesCatalogueProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogue des services'),
        actions: const [
          SyncStatusButton(),
        ],
      ),
      floatingActionButton: droits.peutCreerServices
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/services/catalogue/new'),
              icon: const Icon(Icons.add),
              label: const Text('Nouveau service'),
            )
          : null,
      body: AsyncValueView<List<ServiceCatalogue>>(
        value: catalogueAsync,
        onRetry: () => ref.invalidate(servicesCatalogueProvider),
        data: (services) {
          // Extraire toutes les catégories uniques
          final categories = services
              .map((s) => s.categorie?.trim())
              .where((c) => c != null && c.isNotEmpty)
              .cast<String>()
              .toSet()
              .toList()
            ..sort();

          final filtres = services.where((s) {
            // Filtre catégorie
            if (_categorieSelectionnee != null && s.categorie != _categorieSelectionnee) {
              return false;
            }
            // Filtre recherche textuelle
            if (_recherche.isNotEmpty) {
              final q = _recherche.toLowerCase();
              final matchNom = s.nom.toLowerCase().contains(q);
              final matchCat = s.categorie?.toLowerCase().contains(q) ?? false;
              final matchDesc = s.description?.toLowerCase().contains(q) ?? false;
              return matchNom || matchCat || matchDesc;
            }
            return true;
          }).toList();

          return ResponsiveBody(
            maxWidth: 860,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barre de recherche
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher un service (nom, catégorie)...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _recherche.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _recherche = ''))
                          : null,
                    ),
                    onChanged: (val) => setState(() => _recherche = val.trim()),
                  ),
                ),

                // Filtres par catégories
                if (categories.isNotEmpty)
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: const Text('Toutes'),
                            selected: _categorieSelectionnee == null,
                            onSelected: (_) => setState(() => _categorieSelectionnee = null),
                          ),
                        ),
                        for (final cat in categories)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(cat),
                              selected: _categorieSelectionnee == cat,
                              onSelected: (selected) =>
                                  setState(() => _categorieSelectionnee = selected ? cat : null),
                            ),
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 6),

                // Liste des prestations du catalogue
                Expanded(
                  child: filtres.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.category_outlined, size: 48, color: AppColors.muted),
                                const SizedBox(height: 12),
                                const Text(
                                  'Aucun service trouvé',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Ajoutez vos prestations et tarifs types pour accélérer la création des interventions.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: filtres.length,
                          itemBuilder: (_, idx) {
                            final s = filtres[idx];
                            return _ServiceCatalogueCard(
                              service: s,
                              onTap: droits.peutModifierServices
                                  ? () => context.push('/services/catalogue/${s.id}/edit')
                                  : null,
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

class _ServiceCatalogueCard extends ConsumerWidget {
  const _ServiceCatalogueCard({required this.service, this.onTap});
  final ServiceCatalogue service;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF01226C).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.handyman_outlined, color: Color(0xFF01226C), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.nom,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: AppColors.ink),
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (service.categorie != null && service.categorie!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDF9540).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                service.categorie!,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDF9540)),
                              ),
                            ),
                          if (service.dureeFormatee != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time_rounded, size: 12, color: AppColors.muted),
                                const SizedBox(width: 3),
                                Text(
                                  service.dureeFormatee!,
                                  style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      montant(context, ref, service.prix),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF01226C)),
                    ),
                    Text(
                      '/ ${service.unite.libelle}',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.muted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
