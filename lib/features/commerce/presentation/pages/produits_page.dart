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
import '../widgets/scanner.dart';

/// Catalogue visuel : photos, catégories, recherche et scan. Toutes les
/// routes (mot, rayon, code-barres, photo) mènent au même produit.
class ProduitsPage extends ConsumerStatefulWidget {
  const ProduitsPage({super.key});

  @override
  ConsumerState<ProduitsPage> createState() => _ProduitsPageState();
}

enum _Tri { nom, stock, prix, ventes }

class _ProduitsPageState extends ConsumerState<ProduitsPage> {
  String _recherche = '';
  String? _categorie;
  String? _sousCategorie;
  bool _grille = true;
  bool _archives = false;
  _Tri _tri = _Tri.nom;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final droits = ref.watch(droitsCommerceProvider);
    final etatAsync = ref.watch(etatCommerceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.comProductsTitle),
        actions: [
          BoutonScanner(onCode: (code) => traiterCodeScanne(context, ref, code)),
          IconButton(
            tooltip: _grille ? l10n.comListView : l10n.comGridView,
            onPressed: () => setState(() => _grille = !_grille),
            icon: Icon(_grille ? Icons.view_list_rounded : Icons.grid_view_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'categories':
                  context.push(Routes.categoriesProduits);
                case 'archives':
                  setState(() => _archives = !_archives);
                default:
                  setState(() => _tri = _Tri.values.byName(v));
              }
            },
            itemBuilder: (_) => [
              for (final (t, texte) in [
                (_Tri.nom, l10n.comSortName),
                (_Tri.stock, l10n.comSortStock),
                (_Tri.prix, l10n.comSortPrice),
                (_Tri.ventes, l10n.comSortBestSellers),
              ])
                CheckedPopupMenuItem(value: t.name, checked: _tri == t, child: Text(texte)),
              const PopupMenuDivider(),
              CheckedPopupMenuItem(value: 'archives', checked: _archives, child: Text(l10n.comShowArchived)),
              if (droits.modifierProduits || droits.creerProduits)
                PopupMenuItem(value: 'categories', child: Text(l10n.comManageCategories)),
            ],
          ),
          const SyncStatusButton(),
        ],
      ),
      floatingActionButton: !droits.creerProduits || (etatAsync.value?.catalogueVide ?? true)
          ? null
          : FloatingActionButton.extended(
              key: const Key('produit-ajouter'),
              onPressed: () => context.push(Routes.produitNouveau(categorieId: _sousCategorie ?? _categorie)),
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
              titre: l10n.comEmptyProductsTitle,
              message: l10n.comEmptyProductsMessage,
              action: droits.creerProduits ? l10n.comAddProduct : null,
              onAction: () => context.push(Routes.produitNouveau()),
            );
          }
          return _Catalogue(
            etat: etat,
            recherche: _recherche,
            categorie: _categorie,
            sousCategorie: _sousCategorie,
            grille: _grille,
            archives: _archives,
            tri: _tri,
            onRecherche: (t) => setState(() => _recherche = t),
            onCategorie: (c) => setState(() {
              _categorie = c;
              _sousCategorie = null;
            }),
            onSousCategorie: (c) => setState(() => _sousCategorie = c),
          );
        },
      ),
    );
  }
}

class _Catalogue extends ConsumerWidget {
  const _Catalogue({
    required this.etat,
    required this.recherche,
    required this.categorie,
    required this.sousCategorie,
    required this.grille,
    required this.archives,
    required this.tri,
    required this.onRecherche,
    required this.onCategorie,
    required this.onSousCategorie,
  });

  final EtatCommerce etat;
  final String recherche;
  final String? categorie;
  final String? sousCategorie;
  final bool grille;
  final bool archives;
  final _Tri tri;
  final ValueChanged<String> onRecherche;
  final ValueChanged<String?> onCategorie;
  final ValueChanged<String?> onSousCategorie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final droits = ref.watch(droitsCommerceProvider);
    final boutiques = ref.watch(boutiquesVisiblesProvider);
    final produits = etat
        .rechercher(recherche, categorieId: sousCategorie ?? categorie, inclureInactifs: archives)
        .where((p) => archives ? !p.estActif : true)
        .toList();
    switch (tri) {
      case _Tri.nom:
        break;
      case _Tri.stock:
        produits.sort((a, b) => etat.quantite(a.id, boutiques).brut.compareTo(etat.quantite(b.id, boutiques).brut));
      case _Tri.prix:
        produits.sort((a, b) => b.prixDetail.compareTo(a.prixDetail));
      case _Tri.ventes:
        final ordre = {for (final (i, p) in etat.plusVendus(limite: 1000).indexed) p.id: i};
        produits.sort((a, b) => (ordre[a.id] ?? 1 << 30).compareTo(ordre[b.id] ?? 1 << 30));
    }
    final sous = categorie == null ? const <CategorieProduit>[] : etat.sousCategories(categorie!);
    final nomCategorie = etat.categorie(sousCategorie ?? categorie)?.nom;
    final large = MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
            child: TextField(
              key: const Key('produits-recherche'),
              decoration: InputDecoration(hintText: l10n.comSearchHint, prefixIcon: const Icon(Icons.search)),
              onChanged: onRecherche,
            ),
          ),
        ),
        if (etat.categoriesRacines.isNotEmpty)
          SliverToBoxAdapter(
            child: _BandeCategories(etat: etat, selection: categorie, onChanged: onCategorie),
          ),
        if (sous.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                children: [
                  for (final s in sous)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                      child: FilterChip(
                        label: Text('${s.nom} · ${etat.nombreProduits(s.id)}'),
                        selected: sousCategorie == s.id,
                        onSelected: (v) => onSousCategorie(v ? s.id : null),
                      ),
                    ),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: Text(l10n.comProductsCount(produits.length),
                style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
          ),
        ),
        if (produits.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: nomCategorie != null && recherche.isEmpty
                ? EtatVide(
                    icone: Icons.category_outlined,
                    titre: l10n.comNoProductInCategory(nomCategorie),
                    message: l10n.comNoProductFoundHint,
                    action: droits.creerProduits ? l10n.comAddProductHere : null,
                    onAction: () => context.push(Routes.produitNouveau(categorieId: sousCategorie ?? categorie)),
                  )
                : EtatVide(
                    icone: Icons.search_off_rounded,
                    titre: l10n.comNoProductFound,
                    message: l10n.comNoProductFoundHint,
                  ),
          )
        else if (grille)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 96),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: large ? 220 : 200,
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
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 96),
            sliver: SliverList.separated(
              itemCount: produits.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => ProduitLigne(produit: produits[i]),
            ),
          ),
      ],
    );
  }
}

/// Catégories en points d'entrée : icône, couleur, nombre de produits, alertes.
class _BandeCategories extends ConsumerWidget {
  const _BandeCategories({required this.etat, required this.selection, required this.onChanged});
  final EtatCommerce etat;
  final String? selection;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final boutiques = ref.watch(boutiquesVisiblesProvider);
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
        children: [
          _TuileCategorie(
            libelle: l10n.comAllCategories,
            compteur: etat.produitsActifs.length,
            selection: selection == null,
            onTap: () => onChanged(null),
          ),
          for (final c in etat.categoriesRacines)
            _TuileCategorie(
              categorie: c,
              libelle: c.nom,
              compteur: etat.nombreProduits(c.id),
              alertes: etat
                  .aSurveiller(boutiques)
                  .where((p) => etat.dansCategorie(p, c.id))
                  .length,
              selection: selection == c.id,
              onTap: () => onChanged(selection == c.id ? null : c.id),
            ),
        ],
      ),
    );
  }
}

class _TuileCategorie extends StatelessWidget {
  const _TuileCategorie({
    required this.libelle,
    required this.compteur,
    required this.selection,
    required this.onTap,
    this.categorie,
    this.alertes = 0,
  });

  final CategorieProduit? categorie;
  final String libelle;
  final int compteur;
  final int alertes;
  final bool selection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final teinte = categorie == null ? AppColors.ink : VisuelsCategories.couleur(categorie!.couleur);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
      child: Material(
        color: selection ? teinte.withValues(alpha: 0.12) : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selection ? teinte : AppColors.border, width: selection ? 1.6 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            width: 132,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                categorie == null
                    ? Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(11)),
                        child: const Icon(Icons.apps_rounded, size: 20, color: AppColors.ink),
                      )
                    : CategorieVisuel(categorie: categorie!, taille: 36, rayon: 11),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(libelle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      Row(
                        children: [
                          Text('$compteur',
                              style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                          if (alertes > 0) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.warning_amber_rounded, size: 13, color: AppColors.warning),
                            Text(' $alertes',
                                style: const TextStyle(
                                    color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte produit (grille) : la photo domine.
class ProduitCarte extends ConsumerWidget {
  const ProduitCarte({super.key, required this.produit, this.onTap});
  final Produit produit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(etatCommerceProvider).value;
    final boutiques = ref.watch(boutiquesVisiblesProvider);
    final p = produit;
    final q = etat?.quantite(p.id, boutiques) ?? Qte.zero;
    final statut = etat?.statut(p, q) ?? StatutStock.rupture;
    final categorie = etat?.categorie(p.categorieId);

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('produit-${p.id}'),
        onTap: onTap ?? () => context.push(Routes.produit(p.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.1,
                  child: LayoutBuilder(
                    builder: (_, c) => Hero(
                      tag: 'photo-${p.id}',
                      child: ProduitImage(produit: p, taille: c.maxWidth, rayon: 0),
                    ),
                  ),
                ),
                PositionedDirectional(top: 8, start: 8, child: StockBadge(statut: statut, compact: true)),
                PositionedDirectional(top: 6, end: 6, child: RecordSyncBadge(status: p.syncStatus)),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nom,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, height: 1.2)),
                    if (categorie != null)
                      Text(categorie.nom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    const Spacer(),
                    Text(montant(context, ref, p.prixDetail),
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.green, fontSize: 14)),
                    Text(quantiteLisible(context, p, q),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ligne produit (liste) : petite photo et informations.
class ProduitLigne extends ConsumerWidget {
  const ProduitLigne({super.key, required this.produit, this.trailing, this.onTap});
  final Produit produit;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final etat = ref.watch(etatCommerceProvider).value;
    final boutiques = ref.watch(boutiquesVisiblesProvider);
    final p = produit;
    final q = etat?.quantite(p.id, boutiques) ?? Qte.zero;
    final statut = etat?.statut(p, q) ?? StatutStock.rupture;
    final categorie = etat?.categorie(p.categorieId);
    return Card(
      child: InkWell(
        key: Key('produit-${p.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap ?? () => context.push(Routes.produit(p.id)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ProduitImage(produit: p, taille: 60),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(p.nom,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                        if (!p.estActif) ...[
                          const SizedBox(width: 6),
                          Text(l10n.comArchived, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                        ],
                        const SizedBox(width: 4),
                        RecordSyncBadge(status: p.syncStatus),
                      ],
                    ),
                    Text(
                      [categorie?.nom, p.reference].whereType<String>().join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(quantiteLisible(context, p, q),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        StockBadge(statut: statut, compact: true),
                      ],
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
