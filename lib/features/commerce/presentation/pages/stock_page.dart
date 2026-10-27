import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../domain/entities/commerce.dart';
import '../../domain/services/etat_commerce.dart';
import '../commerce_providers.dart';
import '../widgets/commerce_widgets.dart';
import '../widgets/fiche_scan.dart';
import '../widgets/operation_stock.dart';
import '../widgets/scanner.dart';
import 'produits_page.dart' show ProduitCarte;

/// « Qu'est-ce que j'ai, et où ? » — indicateurs utiles, photo sur chaque
/// ligne, jauge par rapport au seuil, répartition par boutique.
class StockPage extends ConsumerStatefulWidget {
  const StockPage({super.key, this.statutInitial});
  final StatutStock? statutInitial;

  @override
  ConsumerState<StockPage> createState() => _StockPageState();
}

class _StockPageState extends ConsumerState<StockPage> {
  late StatutStock? _statut = widget.statutInitial;
  String _recherche = '';
  String? _categorie;
  bool _grille = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final droits = ref.watch(droitsCommerceProvider);
    final etatAsync = ref.watch(etatCommerceProvider);
    final boutiques = ref.watch(boutiquesVisiblesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.comStockTitle),
            Text(l10n.comStockSubtitle,
                style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          BoutonScanner(onCode: (code) => traiterCodeScanne(context, ref, code)),
          IconButton(
            tooltip: _grille ? l10n.comListView : l10n.comGridView,
            onPressed: () => setState(() => _grille = !_grille),
            icon: Icon(_grille ? Icons.view_list_rounded : Icons.grid_view_rounded),
          ),
          IconButton(
            key: const Key('stock-mouvements'),
            tooltip: l10n.comSeeMovements,
            onPressed: () => context.push(Routes.mouvementsStock),
            icon: const Icon(Icons.history_rounded),
          ),
          const SyncStatusButton(),
        ],
      ),
      floatingActionButton: !droits.creerProduits || (etatAsync.value?.catalogueVide ?? true)
          ? null
          : FloatingActionButton.extended(
              key: const Key('stock-produit-ajouter'),
              onPressed: () => context.push(Routes.produitNouveau()),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.comAddProduct),
            ),
      body: AsyncValueView(
        value: etatAsync,
        onRetry: () => ref.invalidate(etatCommerceProvider),
        data: (etat) {
          if (etat.catalogueVide) {
            return EtatVide(
              icone: Icons.inventory_2_outlined,
              titre: l10n.comStockEmptyTitle,
              message: l10n.comStockEmptyMessage,
              action: droits.creerProduits ? l10n.comAddProduct : null,
              onAction: () => context.push(Routes.produitNouveau()),
            );
          }
          final resume = etat.resume(boutiques);
          final boutiqueCourante = ref.watch(boutiqueCouranteProvider);
          final ensemble = boutiques.toSet();
          final produits = [
            for (final p in etat.rechercher(_recherche, categorieId: _categorie, boutiqueId: boutiqueCourante))
              if ((ensemble.isEmpty || ensemble.any(p.estVisibleDansBoutique)) &&
                  (_statut == null || etat.statutDans(p, boutiques) == _statut))
                p,
          ];
          if (_statut != null) {
            produits.sort((a, b) => etat.quantite(a.id, boutiques).brut.compareTo(etat.quantite(b.id, boutiques).brut));
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: TextField(
                          key: const Key('stock-recherche'),
                          decoration:
                              InputDecoration(hintText: l10n.comSearchHint, prefixIcon: const Icon(Icons.search)),
                          onChanged: (t) => setState(() => _recherche = t),
                        ),
                      ),
                      const BoutiqueSelecteur(),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 116,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                    children: [
                      IndicateurStock(
                        key: const Key('kpi-produits'),
                        valeur: '${resume.produits}',
                        libelle: l10n.comKpiProducts,
                        icone: Icons.inventory_2_outlined,
                        couleur: AppColors.green,
                        selectionne: _statut == null,
                        onTap: () => setState(() => _statut = null),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IndicateurStock(
                        key: const Key('kpi-faible'),
                        valeur: '${resume.faibles}',
                        libelle: l10n.comKpiLow,
                        icone: Icons.warning_amber_rounded,
                        couleur: AppColors.warning,
                        selectionne: _statut == StatutStock.faible,
                        onTap: () => setState(() => _statut = _statut == StatutStock.faible ? null : StatutStock.faible),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IndicateurStock(
                        key: const Key('kpi-rupture'),
                        valeur: '${resume.ruptures}',
                        libelle: l10n.comKpiOut,
                        icone: Icons.error_outline_rounded,
                        couleur: AppColors.negative,
                        selectionne: _statut == StatutStock.rupture,
                        onTap: () =>
                            setState(() => _statut = _statut == StatutStock.rupture ? null : StatutStock.rupture),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IndicateurStock(
                        valeur: '${resume.mouvementsDuJour}',
                        libelle: l10n.comKpiMovesToday,
                        icone: Icons.sync_alt_rounded,
                        couleur: const Color(0xFF2563EB),
                        onTap: () => context.push(Routes.mouvementsStock),
                      ),
                    ],
                  ),
                ),
              ),
              if (etat.categoriesRacines.isNotEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                          child: ChoiceChip(
                            label: Text(l10n.comAllCategories),
                            selected: _categorie == null,
                            onSelected: (_) => setState(() => _categorie = null),
                          ),
                        ),
                        for (final c in etat.categoriesRacines)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                            child: ChoiceChip(
                              avatar: Icon(VisuelsCategories.iconeDe(c),
                                  size: 18, color: VisuelsCategories.couleur(c.couleur)),
                              label: Text(c.nom),
                              selected: _categorie == c.id,
                              onSelected: (_) => setState(() => _categorie = _categorie == c.id ? null : c.id),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (produits.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _statut != null && _recherche.isEmpty && _categorie == null
                      ? EtatVide(
                          icone: Icons.verified_outlined,
                          titre: l10n.comNothingToReport,
                          message: l10n.comStockSubtitle,
                        )
                      : EtatVide(
                          icone: Icons.search_off_rounded,
                          titre: l10n.comNoProductFound,
                          message: l10n.comNoProductFoundHint,
                        ),
                )
              else if (_grille)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
                  sliver: SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded ? 220 : 200,
                      mainAxisSpacing: AppSpacing.md,
                      crossAxisSpacing: AppSpacing.md,
                      childAspectRatio: 0.66,
                    ),
                    itemCount: produits.length,
                    itemBuilder: (_, i) => ProduitCarte(produit: produits[i]),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
                  sliver: SliverList.separated(
                    itemCount: produits.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) => LigneStock(etat: etat, produit: produits[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Une ligne de stock : photo, quantité lisible, jauge, répartition, statut.
class LigneStock extends ConsumerWidget {
  const LigneStock({super.key, required this.etat, required this.produit});
  final EtatCommerce etat;
  final Produit produit;

  Future<void> _actions(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final d = ref.read(droitsCommerceProvider);
    final operations = [
      if (d.entreeSortie) (OperationStock.entree, l10n.comEntry, Icons.add_circle_outline),
      if (d.entreeSortie) (OperationStock.sortie, l10n.comExit, Icons.remove_circle_outline),
      if (d.transferer) (OperationStock.transfert, l10n.comTransfer, Icons.swap_horiz_rounded),
      if (d.ajuster) (OperationStock.inventaire, l10n.comInventory, Icons.fact_check_outlined),
    ];
    if (operations.isEmpty) return;
    final choix = await showModalBottomSheet<OperationStock>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: ProduitImage(produit: produit, taille: 44),
              title: Text(produit.nom, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(l10n.comStockActions),
            ),
            const Divider(),
            for (final (op, texte, icone) in operations)
              ListTile(leading: Icon(icone), title: Text(texte), onTap: () => Navigator.pop(context, op)),
          ],
        ),
      ),
    );
    if (choix != null && context.mounted) {
      final courante = ref.read(boutiqueCouranteProvider);
      await ouvrirOperationStock(context, produit: produit, operation: choix, perimetreId: courante);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = produit;
    final boutiques = ref.watch(boutiquesVisiblesProvider);
    final totalBoutiques = ref.watch(boutiquesProvider).length;
    final droits = ref.watch(droitsCommerceProvider);
    final q = etat.quantite(p.id, boutiques);
    final statut = etat.statut(p, q);
    final categorie = etat.categorie(p.categorieId);
    final repartition = etat.repartition(p.id, boutiques);
    final equivalent = equivalentBase(context, p, q);

    return Card(
      child: InkWell(
        key: Key('stock-${p.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(Routes.produit(p.id)),
        onLongPress: () => _actions(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProduitImage(produit: p, taille: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(p.nom,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                        StockBadge(statut: statut, compact: true),
                      ],
                    ),
                    Row(
                      children: [
                        if (categorie != null)
                          Text(categorie.nom, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                        if (totalBoutiques > 1) ...[
                          if (categorie != null)
                            const Text(' · ', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                          Text(
                            p.estGlobal
                                ? '🌐 Global'
                                : (p.perimetresIds.length > 1
                                    ? '🏪 ${p.perimetresIds.length} boutiques'
                                    : '🏪 ${nomBoutique(ref, p.perimetreId ?? "")}'),
                            style: TextStyle(
                              color: p.estGlobal ? const Color(0xFF01226C) : const Color(0xFFDF9540),
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: quantiteLisible(context, p, q),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        if (equivalent != null)
                          TextSpan(text: '  $equivalent', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                      ]),
                    ),
                    const SizedBox(height: 6),
                    StockJauge(quantite: q, seuil: p.seuilAlerte, statut: statut),
                    if (repartition.length > 1) ...[
                      const SizedBox(height: 6),
                      Text(
                        [
                          for (final MapEntry(key: b, value: qb) in repartition.entries)
                            '${nomBoutique(ref, b)} : ${quantiteLisible(context, p, qb)}',
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                      ),
                    ],
                    if (statut == StatutStock.rupture && droits.creerAchats)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton.icon(
                          key: Key('commander-${p.id}'),
                          onPressed: () => context.push(
                            Routes.achatNouveau(produitId: p.id, fournisseurId: p.fournisseurId),
                          ),
                          icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                          label: Text(l10n.comOrder),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
