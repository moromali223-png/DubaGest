import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/commerce.dart';
import '../commerce_providers.dart';
import 'commerce_widgets.dart';
import 'scanner.dart';

/// Choisir un produit : recherche, catégorie, scan ou photo. Les produits
/// [suggestions] (habituels du fournisseur…) sont proposés en premier.
Future<Produit?> choisirProduit(
  BuildContext context, {
  String? titre,
  List<Produit> suggestions = const [],
  String? boutiqueId,
  VoidCallback? onCreer,
}) =>
    showModalBottomSheet<Produit>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: _ChoixProduit(
          titre: titre,
          suggestions: suggestions,
          boutiqueId: boutiqueId,
          onCreer: onCreer,
        ),
      ),
    );

class _ChoixProduit extends ConsumerStatefulWidget {
  const _ChoixProduit({
    this.titre,
    required this.suggestions,
    this.boutiqueId,
    this.onCreer,
  });
  final String? titre;
  final List<Produit> suggestions;
  final String? boutiqueId;
  final VoidCallback? onCreer;

  @override
  ConsumerState<_ChoixProduit> createState() => _ChoixProduitState();
}

class _ChoixProduitState extends ConsumerState<_ChoixProduit> {
  String _recherche = '';
  String? _categorie;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final etat = ref.watch(etatCommerceProvider).value;
    if (etat == null) return const Center(child: CircularProgressIndicator());
    final produits = etat.rechercher(_recherche, categorieId: _categorie, boutiqueId: widget.boutiqueId);
    final suggestions = _recherche.isEmpty && _categorie == null
        ? [
            for (final p in widget.suggestions)
              if (widget.boutiqueId == null || p.estVisibleDansBoutique(widget.boutiqueId!)) p,
          ]
        : const <Produit>[];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(widget.titre ?? l10n.comChooseProduct, style: Theme.of(context).textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('choix-produit-recherche'),
                    autofocus: false,
                    decoration: InputDecoration(hintText: l10n.comSearchHint, prefixIcon: const Icon(Icons.search)),
                    onChanged: (t) => setState(() => _recherche = t),
                  ),
                ),
                BoutonScanner(
                  boxed: true,
                  onCode: (code) {
                    final p = etat.parCodeBarres(code, boutiqueId: widget.boutiqueId);
                    if (p != null) {
                      Navigator.of(context).pop(p);
                    } else {
                      signalerErreur(context, l10n.comBarcodeUnknown);
                    }
                  },
                ),
              ],
            ),
          ),
          if (etat.categoriesRacines.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
                        avatar: Icon(VisuelsCategories.iconeDe(c), size: 18),
                        label: Text(c.nom),
                        selected: _categorie == c.id,
                        onSelected: (_) => setState(() => _categorie = c.id),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: produits.isEmpty && suggestions.isEmpty
                ? EtatVide(
                    icone: Icons.search_off_rounded,
                    titre: l10n.comNoProductFound,
                    message: l10n.comNoProductFoundHint,
                    action: widget.onCreer == null ? null : l10n.comAddProduct,
                    onAction: widget.onCreer == null
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            widget.onCreer!();
                          },
                  )
                : CustomScrollView(
                    slivers: [
                      if (suggestions.isNotEmpty) ...[
                        _Titre(l10n.comUsualProducts),
                        _Grille(produits: suggestions, boutiqueId: widget.boutiqueId),
                        _Titre(l10n.comAllProducts),
                      ],
                      _Grille(produits: produits, boutiqueId: widget.boutiqueId),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
        sliver: SliverToBoxAdapter(
          child: Text(texte, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted)),
        ),
      );
}

class _Grille extends ConsumerWidget {
  const _Grille({required this.produits, this.boutiqueId});
  final List<Produit> produits;
  final String? boutiqueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(etatCommerceProvider).value;
    final boutiques = ref.watch(boutiquesVisiblesProvider);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 160,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 0.65,
        ),
        itemCount: produits.length,
        itemBuilder: (_, i) {
          final p = produits[i];
          final q = boutiqueId != null
              ? (etat?.quantiteBoutique(p.id, boutiqueId!) ?? Qte.zero)
              : (etat?.quantite(p.id, boutiques) ?? Qte.zero);
          return Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: Key('choix-${p.id}'),
              onTap: () => Navigator.of(context).pop(p),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ProduitImage(
                      produit: p,
                      largeur: double.infinity,
                      hauteur: double.infinity,
                      rayon: 0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                    child: Text(
                      p.nom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, height: 1.2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                    child: Text(
                      quantiteLisible(context, p, q),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
