import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/commerce.dart';
import '../../domain/services/etat_commerce.dart';
import '../commerce_providers.dart';
import '../widgets/commerce_widgets.dart';
import 'produit_form_page.dart' show editerCategorie;

/// Catégorie d'un modèle : (icône, nom, sous-catégories).
typedef _ModeleCategorie = (String, String Function(AppLocalizations), List<String Function(AppLocalizations)>);

/// Modèles de catégories par secteur : le commerçant ne part jamais d'une page blanche.
List<(String Function(AppLocalizations), IconData, List<_ModeleCategorie>)> _modeles() => [
      (
        (l) => l.comSectorHardware,
        Icons.handyman_outlined,
        [
          ('outils', (l) => l.comCatOutils, []),
          ('materiaux', (l) => l.comCatMateriaux, []),
          ('carrelage', (l) => l.comCatCarrelage, []),
          ('peinture', (l) => l.comCatPeinture, [
            (l) => l.comCatPeintureInterieur,
            (l) => l.comCatPeintureExterieur,
            (l) => l.comCatPeinturePrimaire,
            (l) => l.comCatPeintureVernis,
          ]),
          ('plomberie', (l) => l.comCatPlomberie, []),
          ('electricite', (l) => l.comCatElectricite, []),
          ('visserie', (l) => l.comCatVisserie, []),
          ('menuiserie', (l) => l.comCatMenuiserie, []),
          ('accessoires', (l) => l.comCatAccessoires, []),
        ],
      ),
      (
        (l) => l.comSectorGrocery,
        Icons.storefront_outlined,
        [
          ('boissons', (l) => l.comCatBoissons, []),
          ('epicerie', (l) => l.comCatEpicerie, []),
          ('frais', (l) => l.comCatFrais, []),
          ('boulangerie', (l) => l.comCatBoulangerie, []),
          ('hygiene', (l) => l.comCatHygiene, []),
          ('menage', (l) => l.comCatMenage, []),
        ],
      ),
      (
        (l) => l.comSectorSupermarket,
        Icons.local_grocery_store_outlined,
        [
          ('boissons', (l) => l.comCatBoissons, []),
          ('epicerie', (l) => l.comCatEpicerie, []),
          ('frais', (l) => l.comCatFrais, []),
          ('hygiene', (l) => l.comCatHygiene, []),
          ('menage', (l) => l.comCatMenage, []),
          ('cosmetique', (l) => l.comCatCosmetique, []),
          ('papeterie', (l) => l.comCatPapeterie, []),
        ],
      ),
      (
        (l) => l.comSectorTextile,
        Icons.checkroom_outlined,
        [
          ('vetements', (l) => l.comCatVetements, []),
          ('chaussures', (l) => l.comCatChaussures, []),
          ('accessoires', (l) => l.comCatAccessoires, []),
        ],
      ),
      (
        (l) => l.comSectorCosmetics,
        Icons.face_retouching_natural_outlined,
        [
          ('cosmetique', (l) => l.comCatCosmetique, []),
          ('hygiene', (l) => l.comCatHygiene, []),
          ('accessoires', (l) => l.comCatAccessoires, []),
        ],
      ),
      (
        (l) => l.comSectorElectronics,
        Icons.smartphone_outlined,
        [
          ('telephonie', (l) => l.comCatTelephonie, []),
          ('electronique', (l) => l.comCatElectronique, []),
          ('accessoires', (l) => l.comCatAccessoires, []),
        ],
      ),
    ];

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  Future<void> _appliquerModele(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final modeles = _modeles();
    final choix = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(l10n.comChooseSector, style: Theme.of(sheetContext).textTheme.titleLarge),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final (i, (nom, icone, cats)) in modeles.indexed)
                ListTile(
                  key: Key('modele-$i'),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.greenSoft,
                    child: Icon(icone, color: AppColors.green),
                  ),
                  title: Text(nom(l10n), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(cats.map((c) => c.$2(l10n)).join(', '), maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(sheetContext, i),
                ),
            ],
          ),
        ),
      ),
    );
    if (choix == null || !context.mounted) return;
    final ctx = ref.read(contexteActifProvider);
    final etat = ref.read(etatCommerceProvider).value;
    if (ctx == null || etat == null) return;
    final existantes = {for (final c in etat.categories) c.nom.toLowerCase()};
    final gerer = ref.read(gererCommerceProvider);
    try {
      for (final (i, (icone, nom, sous)) in modeles[choix].$3.indexed) {
        if (existantes.contains(nom(l10n).toLowerCase())) continue;
        final c = await gerer.creerCategorie(ctx,
            nom: nom(l10n),
            icone: icone,
            couleur: VisuelsCategories.couleurs[i % VisuelsCategories.couleurs.length],
            ordre: i + 1);
        for (final (j, s) in sous.indexed) {
          await gerer.creerCategorie(ctx, nom: s(l10n), parentId: c.id, ordre: j + 1);
        }
      }
      if (context.mounted) confirmer(context, l10n.comTemplateApplied);
    } catch (e) {
      if (context.mounted) signalerErreur(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final droits = ref.watch(droitsCommerceProvider);
    final peutGerer = droits.creerProduits || droits.modifierProduits;
    final etatAsync = ref.watch(etatCommerceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.comCategoriesTitle),
        actions: [
          if (droits.creerProduits)
            IconButton(
              tooltip: l10n.comUseTemplate,
              onPressed: () => _appliquerModele(context, ref),
              icon: const Icon(Icons.auto_awesome_outlined),
            ),
        ],
      ),
      floatingActionButton: !droits.creerProduits
          ? null
          : FloatingActionButton.extended(
              key: const Key('categorie-ajouter'),
              onPressed: () => editerCategorie(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.comNewCategory),
            ),
      body: ResponsiveBody(
        child: AsyncValueView(
          value: etatAsync,
          onRetry: () => ref.invalidate(etatCommerceProvider),
          data: (etat) {
            final racines = [for (final c in etat.categories) if (c.estRacine) c];
            if (racines.isEmpty) {
              return EtatVide(
                icone: Icons.category_outlined,
                titre: l10n.comCategoriesEmptyTitle,
                message: l10n.comCategoriesEmptyMessage,
                action: droits.creerProduits ? l10n.comUseTemplate : null,
                onAction: () => _appliquerModele(context, ref),
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                mainAxisExtent: 250,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
              ),
              itemCount: racines.length,
              itemBuilder: (_, i) {
                final c = racines[i];
                return _CarteCategorie(
                  key: ValueKey(c.id),
                  categorie: c,
                  etat: etat,
                  peutGerer: peutGerer,
                  peutCreer: droits.creerProduits,
                  onAction: (v) => _action(context, ref, c, v),
                  onSousCategorie: (s) => editerCategorie(context, ref, initiale: s),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _action(BuildContext context, WidgetRef ref, CategorieProduit c, String action) async {
    switch (action) {
      case 'produit':
        await context.push(Routes.produitNouveau(categorieId: c.id));
      case 'modifier':
        await editerCategorie(context, ref, initiale: c);
      case 'sous':
        await editerCategorie(context, ref, parentId: c.id);
      case 'active':
        final ctx = ref.read(contexteActifProvider);
        if (ctx == null) return;
        try {
          await ref.read(gererCommerceProvider).modifierCategorie(ctx, c, c.copyWith(estActive: !c.estActive));
        } catch (e) {
          if (context.mounted) signalerErreur(context, e);
        }
    }
  }
}

/// Carte d'une catégorie : photos réelles de ses produits (ou icône), nom,
/// nombre de produits et sous-catégories.
class _CarteCategorie extends StatelessWidget {
  const _CarteCategorie({
    super.key,
    required this.categorie,
    required this.etat,
    required this.peutGerer,
    required this.peutCreer,
    required this.onAction,
    required this.onSousCategorie,
  });

  final CategorieProduit categorie;
  final EtatCommerce etat;
  final bool peutGerer;
  final bool peutCreer;
  final ValueChanged<String> onAction;
  final ValueChanged<CategorieProduit> onSousCategorie;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = categorie;
    final teinte = VisuelsCategories.couleur(c.couleur);
    final sous = etat.categories.where((s) => s.parentId == c.id).toList();
    return Opacity(
      opacity: c.estActive ? 1 : 0.5,
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: peutGerer ? () => onAction('modifier') : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CategorieVisuel.banniere(categorie: c),
                    PositionedDirectional(
                      start: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(VisuelsCategories.iconeDe(c), size: 14, color: teinte),
                            const SizedBox(width: 4),
                            Text(l10n.comProductsCount(etat.nombreProduits(c.id)),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink)),
                          ],
                        ),
                      ),
                    ),
                    if (peutGerer)
                      PositionedDirectional(
                        top: 6,
                        end: 6,
                        child: Material(
                          color: AppColors.surface.withValues(alpha: 0.92),
                          shape: const CircleBorder(),
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_horiz_rounded, color: AppColors.ink),
                            onSelected: onAction,
                            itemBuilder: (_) => [
                              if (peutCreer)
                                PopupMenuItem(value: 'produit', child: Text(l10n.comAddProductHere)),
                              PopupMenuItem(value: 'modifier', child: Text(l10n.commonEdit)),
                              if (peutCreer) PopupMenuItem(value: 'sous', child: Text(l10n.comAddSubCategory)),
                              PopupMenuItem(value: 'active', child: Text(c.estActive ? l10n.comDisable : l10n.comEnable)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(height: 3, color: teinte),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.nom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink)),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 28,
                      child: sous.isEmpty
                          ? const SizedBox.shrink()
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: sous.length,
                              separatorBuilder: (_, _) => const SizedBox(width: 6),
                              itemBuilder: (_, i) {
                                final s = sous[i];
                                return ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  backgroundColor: teinte.withValues(alpha: 0.08),
                                  side: BorderSide(color: teinte.withValues(alpha: 0.25)),
                                  label: Text('${s.nom} · ${etat.nombreProduits(s.id)}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  onPressed: peutGerer ? () => onSousCategorie(s) : null,
                                );
                              },
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
