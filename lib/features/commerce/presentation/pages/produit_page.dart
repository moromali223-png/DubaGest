import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/commerce.dart';
import '../../domain/services/etat_commerce.dart';
import '../commerce_providers.dart';
import '../widgets/choix_contact.dart';
import '../widgets/commerce_widgets.dart';
import '../widgets/historique_entite.dart';
import '../widgets/operation_stock.dart';
import 'produit_form_page.dart' show libelleAttribut;

/// Fiche produit : photos, stock et répartition, actions visibles,
/// prix par unité, mouvements et fournisseurs.
class ProduitPage extends ConsumerWidget {
  const ProduitPage({super.key, required this.produitId});
  final String produitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final etatAsync = ref.watch(etatCommerceProvider);
    return switch (etatAsync) {
      AsyncData(value: final etat) when etat.produit(produitId) != null =>
        _Fiche(etat: etat, produit: etat.produit(produitId)!),
      AsyncData() => Scaffold(appBar: AppBar(), body: EmptyView(message: l10n.comProductNotFound)),
      AsyncError(:final error) => Scaffold(appBar: AppBar(), body: ErrorView(error: error)),
      _ => Scaffold(appBar: AppBar(), body: const LoadingView()),
    };
  }
}

class _Fiche extends ConsumerWidget {
  const _Fiche({required this.etat, required this.produit});
  final EtatCommerce etat;
  final Produit produit;

  Future<void> _archiver(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    if (produit.estActif) {
      final stockRestant = etat.quantite(produit.id);
      if (stockRestant.estPositif) {
        final boutiquesVisibles = ref.read(boutiquesVisiblesProvider);
        final repartition = etat.repartition(produit.id, boutiquesVisibles);
        final details = [
          for (final MapEntry(key: b, value: qb) in repartition.entries)
            if (qb.estPositif) '• ${nomBoutique(ref, b)} : ${quantiteLisible(context, produit, qb)}',
        ];
        final courante = ref.read(boutiqueCouranteProvider);
        final choix = await showDialog<String>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            icon: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 40),
            title: const Text('Archivage du produit'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Le produit « ${produit.nom} » possède encore du stock disponible (${quantiteLisible(context, produit, stockRestant)}).\n\n'
                  'Conformément aux règles de gestion (règle 7.D), le stock restant doit être soldé ou régularisé avant l\'archivage.',
                  style: const TextStyle(fontSize: 14),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Détail du stock restant :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(details.join('\n'), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(null),
                child: Text(l10n.commonCancel),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(dialogCtx).pop('ajuster'),
                child: const Text('Ajuster manuellement'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.archive_outlined, size: 18),
                label: const Text('Solder le stock & Archiver'),
                onPressed: () => Navigator.of(dialogCtx).pop('solder'),
              ),
            ],
          ),
        );
        if (choix == null) return;
        if (choix == 'ajuster') {
          ouvrirOperationStock(
            context,
            produit: produit,
            operation: OperationStock.sortie,
            perimetreId: courante,
          );
          return;
        }
        if (choix == 'solder') {
          try {
            await ref.read(gererCommerceProvider).archiverProduit(ctx, etat, produit, solderStockSiNecessaire: true);
            if (context.mounted) {
              confirmer(context, 'Produit « ${produit.nom} » archivé avec succès (stock soldé)');
              context.pop();
            }
          } catch (e) {
            if (context.mounted) signalerErreur(context, e);
          }
          return;
        }
      }

      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: Text(l10n.comArchive),
          content: Text(
            'Voulez-vous archiver le produit « ${produit.nom} » ? Il ne sera plus proposé lors des nouveaux achats et ventes, mais restera consultable dans l\'historique.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(l10n.comArchive),
            ),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await ref.read(gererCommerceProvider).archiverProduit(ctx, etat, produit);
        if (context.mounted) {
          confirmer(context, 'Produit « ${produit.nom} » archivé avec succès');
          context.pop();
        }
      } catch (e) {
        if (context.mounted) signalerErreur(context, e);
      }
    } else {
      // Restauration d'un produit archivé
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: Text(l10n.comRestore),
          content: Text('Voulez-vous restaurer le produit « ${produit.nom} » dans le catalogue actif ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(l10n.comRestore),
            ),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await ref.read(gererCommerceProvider).restaurerProduit(ctx, etat, produit);
        if (context.mounted) {
          confirmer(context, 'Produit « ${produit.nom} » restauré dans le catalogue');
        }
      } catch (e) {
        if (context.mounted) signalerErreur(context, e);
      }
    }
  }

  Future<void> _supprimer(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.commonDelete),
        content: Text(l10n.comConfirmDeleteProduct(produit.nom)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(gererCommerceProvider).supprimerProduit(ctx, etat, produit);
      if (context.mounted) {
        confirmer(context, l10n.comProductDeleted);
        context.pop();
      }
    } catch (e) {
      if (context.mounted) signalerErreur(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = produit;
    final droits = ref.watch(droitsCommerceProvider);
    final visibles = ref.watch(boutiquesVisiblesProvider);
    final q = etat.quantite(p.id, visibles);
    final statut = etat.statut(p, q);
    final categorie = etat.categorie(p.categorieId);
    final racine = etat.racine(p.categorieId);
    final fournisseurs = {
      ?p.fournisseurId,
      for (final a in etat.achats)
        if (!a.annule && a.fournisseurId != null && a.lignes.any((l) => l.produitId == p.id)) a.fournisseurId!,
    };

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            actions: [
              const SyncStatusButton(),
              if (droits.modifierProduits)
                IconButton(
                  key: const Key('produit-modifier'),
                  tooltip: l10n.commonEdit,
                  onPressed: () => context.push(Routes.produitModifier(p.id)),
                  icon: const Icon(Icons.edit_outlined),
                ),
              if (droits.peutArchiverProduits)
                Builder(
                  builder: (context) {
                    final aDesMouvements = etat.mouvements.any((m) => m.produitId == p.id);
                    final aDesVentes = etat.ventes.any((v) => v.lignes.any((l) => l.produitId == p.id));
                    final aDesAchats = etat.achats.any((a) => a.lignes.any((l) => l.produitId == p.id));
                    final aDesLots = etat.lotsDe(p.id).isNotEmpty;
                    final aHistorique = aDesMouvements || aDesVentes || aDesAchats || aDesLots;

                    return PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'supprimer') {
                          _supprimer(context, ref);
                        } else if (action == 'archiver') {
                          _archiver(context, ref);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'archiver',
                          child: Text(p.estActif ? l10n.comArchive : l10n.comRestore),
                        ),
                        if (!aHistorique)
                          PopupMenuItem(
                            value: 'supprimer',
                            child: Text(
                              l10n.commonDelete,
                              style: const TextStyle(color: AppColors.negative),
                            ),
                          ),
                      ],
                    );
                  },
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(background: _Galerie(produit: p)),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppBreakpoints.contentMaxWidth),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(p.nom, style: Theme.of(context).textTheme.headlineSmall)),
                          StockBadge(statut: statut),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (racine != null) CategorieIcone(categorie: racine, taille: 22),
                          Text(
                            [
                              if (racine != null) racine.nom,
                              if (categorie != null && categorie.id != racine?.id) categorie.nom,
                            ].join(' › '),
                            style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
                          ),
                          if (p.reference != null)
                            Text('· ${p.reference}', style: const TextStyle(color: AppColors.muted)),
                          if (p.codeBarres != null)
                            Text('· ▥ ${p.codeBarres}', style: const TextStyle(color: AppColors.muted)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: p.estGlobal
                                  ? const Color(0xFF01226C).withValues(alpha: 0.08)
                                  : const Color(0xFFDF9540).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: p.estGlobal
                                    ? const Color(0xFF01226C).withValues(alpha: 0.2)
                                    : const Color(0xFFDF9540).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  p.estGlobal ? Icons.public_rounded : Icons.storefront_rounded,
                                  size: 13,
                                  color: p.estGlobal ? const Color(0xFF01226C) : const Color(0xFFDF9540),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  p.estGlobal
                                      ? 'Catalogue Global'
                                      : (p.perimetresIds.length > 1
                                          ? '${p.perimetresIds.length} boutiques'
                                          : nomBoutique(ref, p.perimetreId ?? '')),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: p.estGlobal ? const Color(0xFF01226C) : const Color(0xFFDF9540),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!p.estActif)
                            Chip(label: Text(l10n.comArchived), visualDensity: VisualDensity.compact),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _CarteStock(etat: etat, produit: p, visibles: visibles),
                      const SizedBox(height: AppSpacing.md),
                      _SectionLotsStock(etat: etat, produit: p, visibles: visibles),
                      const SizedBox(height: AppSpacing.md),
                      if (p.estActif) _Actions(produit: p),
                      const SizedBox(height: AppSpacing.md),
                      _CartePrix(produit: p),
                      if (p.attributs.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        SectionCarte(
                          titre: l10n.comCharacteristics,
                          icone: Icons.tune_rounded,
                          child: Column(
                            children: [
                              for (final MapEntry(:key, :value) in p.attributs.entries)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(libelleAttribut(l10n, key),
                                            style: const TextStyle(color: AppColors.muted)),
                                      ),
                                      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      if (fournisseurs.isNotEmpty && droits.voirFournisseurs) ...[
                        const SizedBox(height: AppSpacing.md),
                        SectionCarte(
                          titre: l10n.comSuppliers,
                          icone: Icons.local_shipping_outlined,
                          child: Column(
                            children: [
                              for (final f in fournisseurs)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.storefront_outlined),
                                  title: Text(nomContact(ref, f) ?? '—'),
                                  trailing: const Icon(Icons.chevron_right_rounded),
                                  onTap: () => context.push(Routes.fournisseur(f)),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      SectionCarte(
                        titre: l10n.rcpTraceability,
                        icone: Icons.history_rounded,
                        child: HistoriqueEntiteView(entiteType: 'PRODUIT', entiteId: p.id),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Galerie extends StatefulWidget {
  const _Galerie({required this.produit});
  final Produit produit;

  @override
  State<_Galerie> createState() => _GalerieState();
}

class _GalerieState extends State<_Galerie> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.produit;
    return LayoutBuilder(builder: (_, c) {
      final taille = c.maxWidth;
      if (p.photos.length <= 1) {
        return Hero(tag: 'photo-${p.id}', child: ProduitImage(produit: p, taille: taille, rayon: 0));
      }
      return Stack(
        children: [
          PageView(
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              for (final chemin in p.photos) ProduitImage(produit: p, chemin: chemin, taille: taille, rayon: 0),
            ],
          ),
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < p.photos.length; i++)
                  Container(
                    width: i == _page ? 18 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _page ? Colors.white : Colors.white54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _CarteStock extends ConsumerWidget {
  const _CarteStock({required this.etat, required this.produit, required this.visibles});
  final EtatCommerce etat;
  final Produit produit;
  final List<String> visibles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = produit;
    final q = etat.quantite(p.id, visibles);
    final statut = etat.statut(p, q);
    final repartition = etat.repartition(p.id, visibles);
    final equivalent = equivalentBase(context, p, q);
    return SectionCarte(
      titre: l10n.comStockCard,
      icone: Icons.inventory_2_outlined,
      action: const BoutiqueSelecteur(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(quantiteLisible(context, p, q),
              key: const Key('produit-stock'),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink)),
          if (equivalent != null)
            Text(equivalent, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
          if (q.estNegatif)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l10n.comToCheck,
                  style: const TextStyle(color: AppColors.negative, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: AppSpacing.sm),
          StockJauge(quantite: q, seuil: p.seuilAlerte, statut: statut),
          if (p.seuilAlerte.estPositif) ...[
            const SizedBox(height: 4),
            Text(l10n.comMinimumAlert(quantiteLisible(context, p, p.seuilAlerte)),
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
          if (repartition.length > 1) ...[
            const SizedBox(height: AppSpacing.md),
            Text(l10n.comDistribution, style: const TextStyle(fontWeight: FontWeight.w700)),
            for (final MapEntry(key: b, value: qb) in repartition.entries)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_outlined, size: 18, color: AppColors.muted),
                    const SizedBox(width: 8),
                    Expanded(child: Text(nomBoutique(ref, b))),
                    Text(quantiteLisible(context, p, qb), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    StockBadge(statut: etat.statut(p, qb), compact: true),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Les actions principales sont visibles, jamais cachées dans des menus.
class _Actions extends ConsumerWidget {
  const _Actions({required this.produit});
  final Produit produit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final d = ref.watch(droitsCommerceProvider);
    final courante = ref.watch(boutiqueCouranteProvider);
    final actions = <(String, IconData, Color, VoidCallback)>[
      if (d.vendre) (l10n.comSell, Icons.shopping_cart_outlined, AppColors.green, () => context.push(Routes.venteAvec(produit.id))),
      if (d.creerAchats)
        (l10n.comBuy, Icons.receipt_long_outlined, AppColors.gold, () => context.push(Routes.achatNouveau(produitId: produit.id))),
      if (d.entreeSortie) ...[
        (l10n.comEntry, Icons.add_circle_outline, AppColors.positive,
            () => ouvrirOperationStock(context, produit: produit, operation: OperationStock.entree, perimetreId: courante)),
        (l10n.comExit, Icons.remove_circle_outline, AppColors.negative,
            () => ouvrirOperationStock(context, produit: produit, operation: OperationStock.sortie, perimetreId: courante)),
      ],
      if (d.transferer)
        (l10n.comTransfer, Icons.swap_horiz_rounded, const Color(0xFF2563EB),
            () => ouvrirOperationStock(context, produit: produit, operation: OperationStock.transfert, perimetreId: courante)),
      if (d.ajuster)
        (l10n.comInventory, Icons.fact_check_outlined, AppColors.ink,
            () => ouvrirOperationStock(context, produit: produit, operation: OperationStock.inventaire, perimetreId: courante)),
    ];
    if (actions.isEmpty) return const SizedBox.shrink();
    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width >= AppBreakpoints.medium ? 6 : 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.25,
      children: [
        for (final (texte, icone, couleur, action) in actions)
          Material(
            color: couleur.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              key: Key('action-$texte'),
              borderRadius: BorderRadius.circular(14),
              onTap: action,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icone, color: couleur, size: 26),
                  const SizedBox(height: 6),
                  Text(texte,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: couleur, fontWeight: FontWeight.w800, fontSize: 13)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CartePrix extends ConsumerWidget {
  const _CartePrix({required this.produit});
  final Produit produit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = produit;
    final gros = p.venteEnGros;
    final achat = p.prixAchat != null || p.unites.any((u) => u.prixAchat != null);
    const entete = TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700);
    return SectionCarte(
      titre: l10n.comPricesAndUnits,
      icone: Icons.sell_outlined,
      child: Table(
        columnWidths: const {0: FlexColumnWidth(1.4)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(children: [
            Text(l10n.comUnit, style: entete),
            Text(l10n.comRetail, style: entete, textAlign: TextAlign.end),
            if (gros) Text(l10n.comWholesale, style: entete, textAlign: TextAlign.end),
            if (achat) Text(l10n.comProfit, style: entete, textAlign: TextAlign.end),
          ]),
          for (final u in p.toutesUnites)
            TableRow(children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (!u.estBase)
                      Text('= ${qteUnite(context, u.facteur, p.uniteBase)}',
                          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              Text(montant(context, ref, u.prixDetail),
                  textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.green)),
              if (gros)
                Text(u.prixGros == null ? '—' : montant(context, ref, u.prixGros!),
                    textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (achat)
                Text(
                  switch (CalculPrix.benefice(u.prixDetail, u.prixAchat)) {
                    final b? => montant(context, ref, b),
                    null => '—',
                  },
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
                ),
            ]),
        ],
      ),
    );
  }
}

class _SectionLotsStock extends ConsumerWidget {
  const _SectionLotsStock({required this.etat, required this.produit, required this.visibles});
  final EtatCommerce etat;
  final Produit produit;
  final List<String> visibles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var lots = etat.lotsDe(produit.id, visibles);
    if (lots.isEmpty) {
      // Si la boutique courante filtrée ne contient aucun lot mais que d'autres boutiques en ont,
      // on affiche l'ensemble des lots du produit pour ne pas masquer la traçabilité.
      lots = etat.lotsDe(produit.id);
    }
    if (lots.isEmpty) return const SizedBox.shrink();

    final cmp = etat.coutMoyenPondere(produit.id);

    return SectionCarte(
      titre: 'Approvisionnements et lots (${lots.length})',
      icone: Icons.batch_prediction_outlined,
      action: cmp != null
          ? Text('CMP : ${montant(context, ref, cmp)}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.muted))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < lots.length; i++) ...[
            if (i > 0) const Divider(height: 16),
            _TuileLot(lot: lots[i], produit: produit),
          ],
        ],
      ),
    );
  }
}

class _TuileLot extends ConsumerWidget {
  const _TuileLot({required this.lot, required this.produit});
  final LotStock lot;
  final Produit produit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estActif = lot.estDisponible;
    final date =
        '${lot.dateReception.day.toString().padLeft(2, '0')}/${lot.dateReception.month.toString().padLeft(2, '0')}/${lot.dateReception.year}';
    final nomBout = nomBoutique(ref, lot.perimetreId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                lot.reference,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: estActif ? AppColors.green.withValues(alpha: 0.12) : AppColors.muted.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                estActif ? 'Disponible' : 'Épuisé',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: estActif ? AppColors.green : AppColors.muted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.muted),
            const SizedBox(width: 4),
            Text(date, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            const Text(' · ', style: TextStyle(color: AppColors.muted)),
            const Icon(Icons.storefront_outlined, size: 13, color: AppColors.muted),
            const SizedBox(width: 4),
            Expanded(
              child: Text(nomBout,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text.rich(
              TextSpan(
                text: 'Reste : ',
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                children: [
                  TextSpan(
                    text: '${lot.quantiteRestante.valeur} / ${lot.quantiteInitiale.valeur} ${produit.uniteBase}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: estActif ? AppColors.ink : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Text.rich(
              TextSpan(
                text: 'Achat : ',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
                children: [
                  TextSpan(
                    text: montant(context, ref, lot.prixAchatUnitaire),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                  const TextSpan(text: '  ·  Vente : '),
                  TextSpan(
                    text: montant(context, ref, lot.prixVenteUnitaire),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.green),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (estActif) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () => context.push(Routes.venteAvec(produit.id, lotId: lot.id)),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.point_of_sale_rounded, size: 14, color: AppColors.green),
                    const SizedBox(width: 4),
                    Text(
                      'Vendre ce lot (${montant(context, ref, lot.prixVenteUnitaire)})',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.green),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
