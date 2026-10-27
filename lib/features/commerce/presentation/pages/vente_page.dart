import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../finances/domain/entities/finances.dart' show ModePaiement;
import '../../../finances/presentation/providers/finances_providers.dart';
import '../../../finances/presentation/widgets/finances_widgets.dart' show FinancesLabels;
import '../../domain/entities/commerce.dart';
import '../../domain/services/etat_commerce.dart';
import '../../domain/usecases/gerer_commerce.dart';
import '../commerce_providers.dart';
import '../widgets/champ_quantite.dart';
import '../widgets/choix_contact.dart';
import '../widgets/commerce_widgets.dart';
import '../widgets/scanner.dart';
import '../recus/recu_vente.dart';
import '../recus/recu_vente_widgets.dart';

const _couleurGros = Color(0xFF4338CA);
const _couleurGrosFond = Color(0xFFEEF2FF);

/// Une ligne du panier avec unité, quantité et prix personnalisé éventuel.
class _Ligne {
  _Ligne(this.produitId, this.unite, this.quantite);
  final String produitId;
  UniteVente unite;
  Qte quantite;
  int? prixPerso;

  int prixEffectif(ModeVente mode, Produit p) {
    if (prixPerso != null) return prixPerso!;
    final u = p.toutesUnites.where((x) => x.id == unite.id).firstOrNull ?? unite;
    return u.prix(mode);
  }

  bool aPrixPerso(ModeVente mode, Produit p) {
    if (prixPerso == null) return false;
    final u = p.toutesUnites.where((x) => x.id == unite.id).firstOrNull ?? unite;
    return prixPerso != u.prix(mode);
  }
}

/// Résultat retourné par l'éditeur de ligne (quantité, unité, prix personnalisé).
class _ResultatEditionLigne {
  const _ResultatEditionLigne({required this.quantite, required this.unite, this.prixPerso});
  final Qte quantite;
  final UniteVente unite;
  final int? prixPerso;
}

/// Vente au comptoir : rapide, visuelle, gestion gros / détail fluide,
/// modification de prix à la volée, multi-unités (pièces, cartons, litres, kg, sacs...).
class VentePage extends ConsumerStatefulWidget {
  const VentePage({super.key, this.produitId});
  final String? produitId;

  @override
  ConsumerState<VentePage> createState() => _VentePageState();
}

class _VentePageState extends ConsumerState<VentePage> {
  final List<_Ligne> _panier = [];
  String? _boutique;
  ModeVente _mode = ModeVente.detail;
  String _recherche = '';
  String? _categorie;
  bool _favoris = false;
  bool _initialise = false;

  @override
  void initState() {
    super.initState();
    final autorisees = ref.read(droitsCommerceProvider).boutiquesVente;
    final courante = ref.read(boutiqueCouranteProvider);
    _boutique = autorisees.contains(courante) ? courante : autorisees.firstOrNull;
    if (_boutique == null) {
      final perimetres = ref.read(boutiquesProvider);
      if (perimetres.length == 1) {
        _boutique = perimetres.single.id;
      }
    }
    if (_boutique != null && courante != _boutique) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) choisirBoutique(ref, _boutique);
      });
    }
  }

  void majPanier(VoidCallback f) => setState(f);

  Qte _dansPanier(String produitId) => _panier.where((l) => l.produitId == produitId).map((l) => l.quantite.fois(l.unite.facteur)).somme;

  Qte _disponible(EtatCommerce etat, Produit p) =>
      _boutique == null ? Qte.zero : etat.quantiteBoutique(p.id, _boutique!) - _dansPanier(p.id);

  void _ajouter(EtatCommerce etat, Produit p) {
    final l10n = context.l10n;
    final memo = ref.read(unitesMemoriseesProvider.notifier).pour('vente', p.id);
    final unite = p.unite(memo ?? UniteVente.idBase);
    const pas = Qte.un;

    // Si en mode gros et que le produit n'a pas de prix de gros défini,
    // on ouvre directement l'éditeur pour permettre la saisie immédiate du prix.
    final sansPrixGros = _mode == ModeVente.gros && p.prixGros == null && unite.prixGros == null;
    final existante = _panier.where((l) => l.produitId == p.id && l.unite.id == unite.id).firstOrNull;

    if (sansPrixGros && existante == null) {
      final dispo = _disponible(etat, p);
      if (dispo < pas.fois(unite.facteur)) {
        signalerErreur(context, l10n.comStockInsufficientInline(quantiteLisible(context, p, dispo.max(Qte.zero))));
        return;
      }
      final nouvelle = _Ligne(p.id, unite, pas);
      _editer(etat, nouvelle, estNouvelle: true);
      return;
    }

    if (_disponible(etat, p) < pas.fois(unite.facteur)) {
      signalerErreur(context, l10n.comStockInsufficientInline(quantiteLisible(context, p, _disponible(etat, p).max(Qte.zero))));
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      if (existante != null) {
        existante.quantite = existante.quantite + pas;
      } else {
        _panier.add(_Ligne(p.id, unite, pas));
      }
    });
  }

  /// Annule un ajout fait par erreur : retire une unité du produit (ligne la plus
  /// récente) et supprime la ligne quand elle tombe à zéro.
  void _retirer(String produitId) {
    final ligne = _panier.where((l) => l.produitId == produitId).lastOrNull;
    if (ligne == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      final reste = ligne.quantite - Qte.un;
      if (reste.estPositif) {
        ligne.quantite = reste;
      } else {
        _panier.remove(ligne);
      }
    });
  }

  Future<void> _editer(EtatCommerce etat, _Ligne ligne, {bool estNouvelle = false}) async {
    final p = etat.produit(ligne.produitId);
    if (p == null) return;
    final dispoLigne = _disponible(etat, p) + (estNouvelle ? Qte.zero : ligne.quantite.fois(ligne.unite.facteur));

    final resultat = await showModalBottomSheet<_ResultatEditionLigne?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _EditeurQuantite(produit: p, ligne: ligne, mode: _mode, disponible: dispoLigne),
    );
    if (resultat == null || !mounted) return;
    setState(() {
      ligne
        ..quantite = resultat.quantite
        ..unite = resultat.unite
        ..prixPerso = resultat.prixPerso;

      if (estNouvelle && !_panier.contains(ligne)) {
        _panier.add(ligne);
      }
    });
    ref.read(unitesMemoriseesProvider.notifier).retenir('vente', p.id, resultat.unite.id);
  }

  int _total(EtatCommerce etat) => _panier.fold(0, (s, l) {
    final p = etat.produit(l.produitId);
    if (p == null) return s;
    return s + l.quantite.montant(l.prixEffectif(_mode, p));
  });

  Future<void> _encaisser(EtatCommerce etat) async {
    final total = _total(etat);
    final lignes = [
      for (final l in _panier)
        if (etat.produit(l.produitId) case final p?)
          LigneOperation(
            id: const Uuid().v4(),
            produitId: p.id,
            unite: l.unite.nom,
            facteur: l.unite.facteur,
            quantite: l.quantite,
            prixUnitaire: l.prixEffectif(_mode, p),
          ),
    ];
    final vente = await showModalBottomSheet<Vente>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _Encaissement(perimetreId: _boutique!, lignes: lignes, mode: _mode, total: total),
    );
    if (vente == null || !mounted) return;
    for (final l in _panier) {
      ref.read(unitesMemoriseesProvider.notifier).retenir('vente', l.produitId, l.unite.id);
    }
    setState(_panier.clear);
    // La vente est devenue un reçu : le voir, le partager, l'imprimer.
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _VenteTerminee(vente: vente),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final droits = ref.watch(droitsCommerceProvider);
    final etatAsync = ref.watch(etatCommerceProvider);
    final large = MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;

    if (!_initialise && etatAsync.value != null && widget.produitId != null) {
      _initialise = true;
      final p = etatAsync.value!.produit(widget.produitId!);
      if (p != null) WidgetsBinding.instance.addPostFrameCallback((_) => _ajouter(etatAsync.value!, p));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.comSalesTitle),
        actions: [
          if (etatAsync.value case final etat?)
            BoutonScanner(
              onCode: (code) {
                final p = etat.parCodeBarres(code, boutiqueId: _boutique);
                if (p == null) {
                  signalerErreur(context, l10n.comBarcodeUnknown);
                } else {
                  _ajouter(etat, p);
                }
              },
            ),
          if (droits.voirVentes)
            IconButton(
              key: const Key('ventes-historique'),
              tooltip: l10n.rcpTitle,
              onPressed: () => context.push(Routes.historiqueVentes),
              icon: const Icon(Icons.receipt_long_outlined),
            ),
          const SyncStatusButton(),
        ],
      ),
      body: AsyncValueView(
        value: etatAsync,
        onRetry: () => ref.invalidate(etatCommerceProvider),
        data: (etat) {
          if (_boutique == null) {
            final boutiques = droits.boutiquesVente;
            if (boutiques.isNotEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.storefront_rounded, size: 48, color: AppColors.primary),
                          const SizedBox(height: AppSpacing.md),
                          const Text(
                            'Sélectionnez une boutique',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.ink),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const Text(
                            'Toute vente réelle doit être enregistrée dans une boutique précise pour la tenue du stock.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final bId in boutiques)
                                ActionChip(
                                  avatar: const Icon(Icons.store_rounded, size: 18, color: AppColors.primary),
                                  label: Text(nomBoutique(ref, bId), style: const TextStyle(fontWeight: FontWeight.w700)),
                                  onPressed: () {
                                    setState(() => _boutique = bId);
                                    choisirBoutique(ref, bId);
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }
            return EtatVide(icone: Icons.storefront_outlined, titre: l10n.comNoShopAllowed, message: '');
          }
          if (etat.catalogueVide) {
            return EtatVide(
              icone: Icons.inventory_2_outlined,
              titre: l10n.comEmptyProductsTitle,
              message: l10n.comEmptyProductsMessage,
              action: droits.creerProduits ? l10n.comAddProduct : null,
              onAction: () => context.push(Routes.produitNouveau()),
            );
          }
          final catalogue = Column(
            children: [
              _barreHaut(etat, droits),
              Expanded(child: _grille(etat)),
              if (!large && _panier.isNotEmpty) _barrePanier(etat),
            ],
          );
          if (!large) return catalogue;
          return Row(
            children: [
              Expanded(child: catalogue),
              const VerticalDivider(width: 1),
              SizedBox(
                width: 380,
                child: _PanneauPanier(page: this, etat: etat),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _barreHaut(EtatCommerce etat, DroitsCommerce droits) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                if (droits.boutiquesVente.length > 1)
                  Expanded(
                    child: ChampBoutique(
                      valeur: _boutique,
                      autorisees: droits.boutiquesVente,
                      onChanged: (v) {
                        if (v == null) return;
                        choisirBoutique(ref, v);
                        setState(() {
                          _boutique = v;
                          _panier.clear();
                        });
                      },
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: AppSpacing.sm),
                SegmentedButton<ModeVente>(
                  key: const Key('vente-mode'),
                  showSelectedIcon: true,
                  segments: [
                    ButtonSegment(
                      value: ModeVente.detail,
                      icon: const Icon(Icons.storefront_outlined, size: 16),
                      label: Text(l10n.comRetail),
                    ),
                    ButtonSegment(
                      value: ModeVente.gros,
                      icon: const Icon(Icons.inventory_2_outlined, size: 16),
                      label: Text(l10n.comWholesale),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
              ],
            ),
          ),
          TextField(
            key: const Key('vente-recherche'),
            decoration: InputDecoration(hintText: l10n.comSearchHint, prefixIcon: const Icon(Icons.search), isDense: true),
            onChanged: (t) => setState(() => _recherche = t),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              children: [
                if (etat.plusVendus().isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                    child: ChoiceChip(
                      avatar: const Icon(Icons.star_rounded, size: 18, color: AppColors.gold),
                      label: Text(l10n.comBestSellers),
                      selected: _favoris,
                      onSelected: (_) => setState(() {
                        _favoris = !_favoris;
                        _categorie = null;
                      }),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(l10n.comAllCategories),
                    selected: _categorie == null && !_favoris,
                    onSelected: (_) => setState(() {
                      _categorie = null;
                      _favoris = false;
                    }),
                  ),
                ),
                for (final c in etat.categoriesRacines)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                    child: ChoiceChip(
                      avatar: CategorieVisuel(categorie: c, taille: 18),
                      label: Text(c.nom),
                      selected: _categorie == c.id,
                      onSelected: (_) => setState(() {
                        _categorie = c.id;
                        _favoris = false;
                      }),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _grille(EtatCommerce etat) {
    final l10n = context.l10n;
    final produits = _favoris && _recherche.isEmpty
        ? etat.plusVendus(limite: 60, boutiqueId: _boutique)
        : etat.rechercher(_recherche, categorieId: _categorie, boutiqueId: _boutique);
    if (produits.isEmpty) {
      return EtatVide(icone: Icons.search_off_rounded, titre: l10n.comNoProductFound, message: l10n.comNoProductFoundHint);
    }
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 175,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.68,
      ),
      itemCount: produits.length,
      itemBuilder: (_, i) {
        final p = produits[i];
        final disponible = _disponible(etat, p);
        final dansPanier = _dansPanier(p.id);
        final rupture = disponible <= Qte.zero;
        final unite = p.unite(ref.read(unitesMemoriseesProvider.notifier).pour('vente', p.id) ?? UniteVente.idBase);
        final sansPrixGros = _mode == ModeVente.gros && p.prixGros == null && unite.prixGros == null;

        return Opacity(
          opacity: rupture && dansPanier.estNul ? 0.45 : 1,
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: dansPanier.estPositif
                    ? AppColors.green
                    : sansPrixGros
                    ? AppColors.gold.withValues(alpha: 0.6)
                    : AppColors.border,
                width: dansPanier.estPositif ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: Key('vente-produit-${p.id}'),
              onTap: () => _ajouter(etat, p),
              onLongPress: () async {
                if (_panier.where((l) => l.produitId == p.id).firstOrNull case final l?) {
                  await _editer(etat, l);
                } else {
                  final nouvelle = _Ligne(p.id, unite, Qte.un);
                  await _editer(etat, nouvelle, estNouvelle: true);
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 1.05,
                        child: LayoutBuilder(
                          builder: (_, c) => ProduitImage(produit: p, taille: c.maxWidth, rayon: 0),
                        ),
                      ),
                      if (dansPanier.estPositif)
                        PositionedDirectional(
                          top: 6,
                          end: 6,
                          // Compteur + bouton « − » pour annuler un toucher par erreur.
                          child: Material(
                            color: AppColors.green,
                            shape: const StadiumBorder(),
                            elevation: 2,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tooltip(
                                  message: 'Retirer 1',
                                  child: InkWell(
                                    key: Key('vente-retirer-${p.id}'),
                                    customBorder: const StadiumBorder(),
                                    onTap: () => _retirer(p.id),
                                    child: const SizedBox(
                                      width: 32,
                                      height: 30,
                                      child: Icon(Icons.remove_rounded, size: 18, color: Colors.white),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(end: 10),
                                  child: Text(
                                    formatQte(context, dansPanier.divisePar(unite.facteur)),
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (rupture && dansPanier.estNul)
                        PositionedDirectional(top: 6, start: 6, child: StockBadge(statut: StatutStock.rupture, compact: true)),
                      if (sansPrixGros && !rupture)
                        PositionedDirectional(
                          top: 6,
                          start: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(6)),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_outlined, size: 11, color: Colors.black87),
                                SizedBox(width: 3),
                                Text(
                                  'Gros à définir',
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                    child: Text(
                      p.nom,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, height: 1.2),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_mode == ModeVente.gros && sansPrixGros) ...[
                          Text(
                            '${montant(context, ref, unite.prixDetail)} (détail)',
                            style: const TextStyle(fontSize: 11, color: AppColors.muted, decoration: TextDecoration.lineThrough),
                          ),
                          const Text(
                            'Toucher pour saisir',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.goldDark),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${montant(context, ref, unite.prix(_mode))} / ${unite.nom}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: _mode == ModeVente.gros ? _couleurGros : AppColors.green,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                              if (_mode == ModeVente.gros && unite.prixGros != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(color: _couleurGrosFond, borderRadius: BorderRadius.circular(4)),
                                  child: const Text(
                                    'GROS',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _couleurGros),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _barrePanier(EtatCommerce etat) {
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                key: const Key('vente-panier'),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  showDragHandle: true,
                  builder: (_) => FractionallySizedBox(
                    heightFactor: 0.85,
                    child: Consumer(
                      builder: (_, ref, _) {
                        final e = ref.watch(etatCommerceProvider).value ?? etat;
                        return StatefulBuilder(
                          builder: (_, setLocal) => _PanneauPanier(page: this, etat: e, rafraichir: () => setLocal(() {})),
                        );
                      },
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Badge(
                      label: Text('${_panier.length}'),
                      backgroundColor: _mode == ModeVente.gros ? _couleurGros : AppColors.green,
                      child: const Icon(Icons.shopping_cart_outlined, size: 28, color: AppColors.ink),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(l10n.comCartCount(_panier.length), style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                            if (_mode == ModeVente.gros) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(color: _couleurGrosFond, borderRadius: BorderRadius.circular(4)),
                                child: const Text(
                                  'GROS',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _couleurGros),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          montant(context, ref, _total(etat)),
                          key: const Key('vente-total'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                      ],
                    ),
                    const Icon(Icons.expand_less_rounded, color: AppColors.muted),
                  ],
                ),
              ),
            ),
            FilledButton.icon(
              key: const Key('vente-encaisser'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(140, 52),
                backgroundColor: _mode == ModeVente.gros ? _couleurGros : null,
              ),
              onPressed: () => _encaisser(etat),
              icon: const Icon(Icons.point_of_sale_rounded),
              label: Text(l10n.comCheckout),
            ),
          ],
        ),
      ),
    );
  }
}

/// Panier : lignes modifiables (+ / − / unité / prix personnalisé), total, bouton Encaisser.
class _PanneauPanier extends ConsumerWidget {
  const _PanneauPanier({required this.page, required this.etat, this.rafraichir});
  final _VentePageState page;
  final EtatCommerce etat;
  final VoidCallback? rafraichir;

  void _maj(VoidCallback f) {
    page.majPanier(f);
    rafraichir?.call();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final panier = page._panier;
    final mode = page._mode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.sm, 0),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(l10n.comCart, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: mode == ModeVente.gros ? _couleurGrosFond : AppColors.greenSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        mode == ModeVente.gros ? 'VENTE EN GROS' : 'VENTE AU DÉTAIL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: mode == ModeVente.gros ? _couleurGros : AppColors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (panier.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (dlg) => AlertDialog(
                        title: Text(l10n.comClearCart),
                        content: const Text('Retirer tous les articles du panier ?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dlg, false), child: Text(l10n.commonCancel)),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
                            onPressed: () => Navigator.pop(dlg, true),
                            child: Text(l10n.comClearCart),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) _maj(panier.clear);
                  },
                  child: Text(l10n.comClearCart),
                ),
            ],
          ),
        ),
        Expanded(
          child: panier.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.remove_shopping_cart_outlined, size: 48, color: AppColors.muted.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text(
                          l10n.comCartEmpty,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: panier.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final l = panier[i];
                    final p = etat.produit(l.produitId);
                    if (p == null) return const SizedBox.shrink();
                    final prix = l.prixEffectif(mode, p);
                    final aPrixPerso = l.aPrixPerso(mode, p);
                    final pas = p.venteFractionnee ? p.pasMinimum.divisePar(l.unite.facteur).max(const Qte(1)) : Qte.un;

                    final derniere = l.quantite <= pas;

                    return Dismissible(
                      key: ObjectKey(l),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: AlignmentDirectional.centerEnd,
                        padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
                        color: AppColors.negative,
                        child: const Icon(Icons.delete_outline, color: Colors.white),
                      ),
                      onDismissed: (_) => _maj(() => panier.remove(l)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            ProduitImage(produit: p, taille: 48),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () async {
                                  await page._editer(etat, l);
                                  rafraichir?.call();
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.nom,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 6,
                                      children: [
                                        Text(
                                          '${qteUnite(context, l.quantite, l.unite.nom)} × ${montant(context, ref, prix)}',
                                          style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                                        ),
                                        if (aPrixPerso)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: AppColors.goldSoft,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 0.8),
                                            ),
                                            child: const Text(
                                              'Prix modifié',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.goldDark),
                                            ),
                                          ),
                                      ],
                                    ),
                                    Text(
                                      '= ${montant(context, ref, l.quantite.montant(prix))}',
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.ink),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Modifier quantité / prix / unité',
                              onPressed: () async {
                                await page._editer(etat, l);
                                rafraichir?.call();
                              },
                              icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.muted),
                            ),
                            IconButton(
                              key: Key('panier-retirer-${l.produitId}-${l.unite.id}'),
                              visualDensity: VisualDensity.compact,
                              tooltip: derniere ? 'Retirer du panier' : 'Retirer 1',
                              onPressed: () => _maj(() {
                                l.quantite = l.quantite - pas;
                                if (!l.quantite.estPositif) panier.remove(l);
                              }),
                              icon: derniere
                                  ? const Icon(Icons.delete_outline, color: AppColors.negative)
                                  : const Icon(Icons.remove_circle_outline),
                            ),
                            Text(formatQte(context, l.quantite), style: const TextStyle(fontWeight: FontWeight.w800)),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: page._disponible(etat, p) >= pas.fois(l.unite.facteur)
                                  ? () => _maj(() => l.quantite = l.quantite + pas)
                                  : null,
                              icon: const Icon(Icons.add_circle_outline, color: AppColors.green),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    l10n.comTotal,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted),
                  ),
                  const Spacer(),
                  Text(montant(context, ref, page._total(etat)), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: mode == ModeVente.gros ? _couleurGros : null),
                onPressed: panier.isEmpty
                    ? null
                    : () async {
                        if (rafraichir != null) Navigator.pop(context);
                        await page._encaisser(etat);
                      },
                icon: const Icon(Icons.point_of_sale_rounded),
                label: Text(l10n.comCheckout),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Éditeur complet de ligne : Quantité, Unités multiples (pièces, cartons, litres, kg...)
/// et Modification de prix (gros / détail / prix personnalisé).
class _EditeurQuantite extends ConsumerStatefulWidget {
  const _EditeurQuantite({required this.produit, required this.ligne, required this.mode, required this.disponible});

  final Produit produit;
  final _Ligne ligne;
  final ModeVente mode;
  final Qte disponible;

  @override
  ConsumerState<_EditeurQuantite> createState() => _EditeurQuantiteState();
}

class _EditeurQuantiteState extends ConsumerState<_EditeurQuantite> {
  late Qte? _q = widget.ligne.quantite;
  late UniteVente _u = widget.ligne.unite;
  late final TextEditingController _prixController;
  late final List<UniteVente> _unites;
  bool _sauvegarderPrixDefaut = false;

  @override
  void initState() {
    super.initState();
    _unites = List.of(widget.produit.toutesUnites);
    if (!_unites.any((u) => u.id == _u.id)) {
      _unites.add(_u);
    }
    final prixInitial = widget.ligne.prixPerso ?? _u.prix(widget.mode);
    _prixController = TextEditingController(text: prixInitial > 0 ? '$prixInitial' : '');
  }

  @override
  void dispose() {
    _prixController.dispose();
    super.dispose();
  }

  int? get _prixSaisi {
    final t = _prixController.text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  int get _prixCatalogue => _u.prix(widget.mode);

  void _ajouterNouvelleUnite() async {
    final p = widget.produit;
    final l10n = context.l10n;
    final nomCtrl = TextEditingController();
    final facteurCtrl = TextEditingController();
    final prixDetailCtrl = TextEditingController();
    final prixGrosCtrl = TextEditingController();

    const presets = ['Carton', 'Sac', 'Paquet', 'Boîte', 'Litre', 'Kg', 'Bouteille', 'Pack', 'Rame', 'Mètre'];

    final res = await showDialog<UniteVente?>(
      context: context,
      builder: (dlgContext) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_circle_outline, color: AppColors.green),
              SizedBox(width: 8),
              Text('Ajouter une unité de vente', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pour le produit : ${p.nom}',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final preset in presets) ActionChip(label: Text(preset), onPressed: () => setLocal(() => nomCtrl.text = preset)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: nomCtrl,
                  decoration: const InputDecoration(labelText: 'Nom de l\'unité (ex: Carton, Kg, Litre)', isDense: true),
                  onChanged: (_) => setLocal(() {}),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: facteurCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Contenance / Facteur (en ${p.uniteBase})',
                    hintText: 'ex: 24 pour un carton de 24 ${p.uniteBase}',
                    isDense: true,
                  ),
                  onChanged: (v) {
                    final f = Qte.lire(v);
                    if (f != null && f.estPositif) {
                      setLocal(() {
                        prixDetailCtrl.text = '${CalculPrix.lot(p.prixDetail, f)}';
                        if (p.prixGros != null) {
                          prixGrosCtrl.text = '${CalculPrix.lot(p.prixGros!, f)}';
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: prixDetailCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Prix de détail de cette unité (F CFA)', isDense: true),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: prixGrosCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Prix de gros de cette unité (facultatif)', isDense: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dlgContext), child: Text(l10n.commonCancel)),
            FilledButton(
              onPressed: () {
                final nom = nomCtrl.text.trim();
                final facteur = Qte.lire(facteurCtrl.text);
                if (nom.isEmpty || facteur == null || !facteur.estPositif) return;
                final pDetail = int.tryParse(prixDetailCtrl.text) ?? CalculPrix.lot(p.prixDetail, facteur);
                final pGros = int.tryParse(prixGrosCtrl.text) ?? (p.prixGros != null ? CalculPrix.lot(p.prixGros!, facteur) : null);

                final nouvelleUnite = UniteVente(
                  id: 'u_${DateTime.now().millisecondsSinceEpoch}',
                  nom: nom,
                  facteur: facteur,
                  prixDetail: pDetail,
                  prixGros: pGros,
                );
                Navigator.pop(dlgContext, nouvelleUnite);
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );

    if (res != null && mounted) {
      setState(() {
        _unites.add(res);
        _u = res;
        _prixController.text = '${res.prix(widget.mode)}';
      });
    }
  }

  Future<void> _validerEtAppliquer() async {
    final q = _q;
    if (q == null || !q.estPositif) return;
    final prixChoisi = _prixSaisi ?? _prixCatalogue;

    // Si demandé et si l'utilisateur a le droit, enregistrer le prix / l'unité par défaut sur le produit
    if (_sauvegarderPrixDefaut && mounted) {
      try {
        final ctx = ref.read(contexteActifProvider);
        final etat = ref.read(etatCommerceProvider).value;
        final droits = ref.read(droitsCommerceProvider);
        if (ctx != null && etat != null && droits.modifierProduits) {
          final p = widget.produit;
          if (_u.estBase) {
            final modifie = widget.mode == ModeVente.gros ? p.copyWith(prixGros: () => prixChoisi) : p.copyWith(prixDetail: prixChoisi);
            await ref.read(gererCommerceProvider).modifierProduit(ctx, etat, p, modifie);
          } else {
            // Unité additionnelle
            final unitesApres = [
              for (final u in p.unites)
                if (u.id == _u.id || u.nom.toLowerCase() == _u.nom.toLowerCase())
                  UniteProduit(
                    id: u.id,
                    nom: u.nom,
                    facteur: u.facteur,
                    prixDetail: widget.mode == ModeVente.detail ? prixChoisi : u.prixDetail,
                    prixGros: widget.mode == ModeVente.gros ? prixChoisi : u.prixGros,
                  )
                else
                  u,
            ];
            if (!p.unites.any((u) => u.id == _u.id || u.nom.toLowerCase() == _u.nom.toLowerCase())) {
              unitesApres.add(
                UniteProduit(
                  id: _u.id,
                  nom: _u.nom,
                  facteur: _u.facteur,
                  prixDetail: widget.mode == ModeVente.detail ? prixChoisi : _u.prixDetail,
                  prixGros: widget.mode == ModeVente.gros ? prixChoisi : _u.prixGros,
                ),
              );
            }
            final modifie = p.copyWith(unites: unitesApres);
            await ref.read(gererCommerceProvider).modifierProduit(ctx, etat, p, modifie);
          }
        }
      } catch (_) {
        // Enregistrement facultatif en tâche de fond, ne bloque pas la vente
      }
    }

    if (mounted) {
      final prixPerso = prixChoisi != _prixCatalogue ? prixChoisi : null;
      Navigator.pop(context, _ResultatEditionLigne(quantite: q, unite: _u, prixPerso: prixPerso));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = widget.produit;
    final base = _q?.fois(_u.facteur);
    final trop = base != null && base > widget.disponible;
    final valide =
        _q != null &&
        _q!.estPositif &&
        !trop &&
        (p.venteFractionnee ? base!.estMultipleDe(p.pasMinimum) : base!.estEntier) &&
        (_prixSaisi == null || _prixSaisi! >= 0);

    final prixActuel = _prixSaisi ?? _prixCatalogue;
    final sousTotal = (_q != null && _q!.estPositif) ? _q!.montant(prixActuel) : 0;
    final estPrixPerso = _prixSaisi != null && _prixSaisi != _prixCatalogue;
    final sansPrixGrosOrigine = widget.mode == ModeVente.gros && p.prixGros == null && _u.prixGros == null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Entête produit
            Row(
              children: [
                ProduitImage(produit: p, taille: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.nom, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: widget.mode == ModeVente.gros ? _couleurGrosFond : AppColors.greenSoft,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.mode == ModeVente.gros ? 'VENTE EN GROS' : 'VENTE AU DÉTAIL',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: widget.mode == ModeVente.gros ? _couleurGros : AppColors.green,
                              ),
                            ),
                          ),
                          Text(
                            l10n.comAvailable(quantiteLisible(context, p, widget.disponible.max(Qte.zero))),
                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Alerte si prix de gros manquant
            if (sansPrixGrosOrigine)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.goldSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.goldDark, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ce produit n\'a pas de prix de gros par défaut. Saisissez le prix de vente pour cette ligne.',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.goldDark),
                      ),
                    ),
                  ],
                ),
              ),

            // Sélecteur d'unités (Pièces, Cartons, Litres, Kg, Sacs...)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        'Unité de mesure & vente',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _ajouterNouvelleUnite,
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: const Text('Autre unité', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final u in _unites)
                      ChoiceChip(
                        key: Key('unite-${u.nom}'),
                        label: Text(u.estBase ? u.nom : '${u.nom} (${formatQte(context, u.facteur)} ${p.uniteBase})'),
                        selected: u.id == _u.id,
                        onSelected: (_) {
                          setState(() {
                            _u = u;
                            _prixController.text = '${u.prix(widget.mode)}';
                          });
                        },
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Saisie de la quantité
            ChampQuantite(
              champKey: const Key('vente-quantite'),
              produit: p,
              uniteInitiale: _u,
              quantiteInitiale: _q,
              autofocus: true,
              afficherSelecteurUnites: false,
              onChanged: (q, u) => setState(() {
                _q = q;
                _u = u;
              }),
            ),

            if (trop) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.comStockInsufficientInline(quantiteLisible(context, p, widget.disponible.max(Qte.zero))),
                style: const TextStyle(color: AppColors.negative, fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ],

            const SizedBox(height: AppSpacing.md),

            // Modification du Prix Unitaire
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: estPrixPerso ? AppColors.gold : AppColors.border, width: estPrixPerso ? 1.5 : 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          widget.mode == ModeVente.gros ? 'Prix de gros unitaire (F CFA)' : 'Prix de détail unitaire (F CFA)',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (estPrixPerso)
                        TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            setState(() {
                              _prixController.text = '$_prixCatalogue';
                            });
                          },
                          child: const Text('Rétablir catalogue', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _prixController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    decoration: InputDecoration(
                      hintText: '$_prixCatalogue',
                      suffixText: 'F CFA / ${_u.nom}',
                      isDense: true,
                      helperText: 'Prix catalogue par défaut : ${montant(context, ref, _prixCatalogue)}',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (sansPrixGrosOrigine || estPrixPerso) ...[
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      value: _sauvegarderPrixDefaut,
                      onChanged: (v) => setState(() => _sauvegarderPrixDefaut = v ?? false),
                      title: Text(
                        widget.mode == ModeVente.gros
                            ? 'Mémoriser comme nouveau prix de gros standard du produit'
                            : 'Mémoriser comme nouveau prix standard du produit',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Carte récapitulative de la ligne
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Text(
                    'Sous-total ligne :',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted),
                  ),
                  const Spacer(),
                  Text(
                    montant(context, ref, sousTotal),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: AppColors.ink),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            FilledButton(
              key: const Key('vente-quantite-valider'),
              style: FilledButton.styleFrom(
                backgroundColor: widget.mode == ModeVente.gros ? _couleurGros : null,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: valide ? _validerEtAppliquer : null,
              child: const Text('Appliquer à la vente', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Encaissement : payé maintenant (mode) ou à crédit (client), remise, total.
class _Encaissement extends ConsumerStatefulWidget {
  const _Encaissement({required this.perimetreId, required this.lignes, required this.mode, required this.total});
  final String perimetreId;
  final List<LigneOperation> lignes;
  final ModeVente mode;
  final int total;

  @override
  ConsumerState<_Encaissement> createState() => _EncaissementState();
}

class _EncaissementState extends ConsumerState<_Encaissement> {
  ReglementVente _reglement = ReglementVente.immediat;
  ModePaiement _modePaiement = ModePaiement.especes;
  String? _client;
  final _remise = TextEditingController();
  final _acompte = TextEditingController();
  bool _enCours = false;

  @override
  void dispose() {
    _remise.dispose();
    _acompte.dispose();
    super.dispose();
  }

  int get _montantRemise => int.tryParse(_remise.text) ?? 0;
  int get _montantAcompte => _reglement == ReglementVente.credit ? int.tryParse(_acompte.text) ?? 0 : 0;

  Future<void> _valider() async {
    final ctx = ref.read(contexteActifProvider);
    final etat = ref.read(etatCommerceProvider).value;
    if (ctx == null || etat == null) return;
    setState(() => _enCours = true);
    try {
      final vente = await ref
          .read(gererCommerceProvider)
          .vendre(
            ctx,
            etat,
            ref.read(etatFinancesProvider).value,
            SaisieVente(
              perimetreId: widget.perimetreId,
              lignes: widget.lignes,
              mode: widget.mode,
              remise: _montantRemise,
              reglement: _reglement,
              modePaiement: _modePaiement,
              contactId: _client,
              acompte: _montantAcompte,
            ),
          );
      if (mounted) Navigator.pop(context, vente);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enCours = false);
      signalerErreur(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final modes = ref.watch(modesPaiementProvider);
    final finances = ref.watch(etatFinancesProvider).value;
    final caisseOuverte =
        finances != null &&
        finances.caisses.where((c) => c.perimetreId == widget.perimetreId && c.estActive).any((c) => finances.sessionOuverte(c.id) != null);
    final aPayer = widget.total - _montantRemise;
    final credit = _reglement == ReglementVente.credit;
    final acompteValide = !credit || _montantAcompte == 0 || _montantAcompte < aPayer;
    final valide = aPayer >= 0 && (!credit || _client != null) && acompteValide && !_enCours;
    final choixMode = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final m in modes)
          ChoiceChip(label: Text(l10n.modePaiement(m)), selected: _modePaiement == m, onSelected: (_) => setState(() => _modePaiement = m)),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(l10n.comCheckout, style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.mode == ModeVente.gros ? _couleurGrosFond : AppColors.greenSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.mode == ModeVente.gros ? 'VENTE EN GROS' : 'VENTE AU DÉTAIL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: widget.mode == ModeVente.gros ? _couleurGros : AppColors.green,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<ReglementVente>(
              segments: [
                ButtonSegment(value: ReglementVente.immediat, icon: const Icon(Icons.payments_outlined), label: Text(l10n.comPayNow)),
                ButtonSegment(value: ReglementVente.credit, icon: const Icon(Icons.schedule_outlined), label: Text(l10n.comOnCredit)),
              ],
              selected: {_reglement},
              onSelectionChanged: (s) => setState(() => _reglement = s.first),
            ),
            if (!credit) ...[
              const SizedBox(height: AppSpacing.md),
              choixMode,
              if (_modePaiement.passeParCaisse) ...[
                const SizedBox(height: 6),
                Text(
                  caisseOuverte ? l10n.comCashOpen : l10n.comNoCashOpen,
                  style: TextStyle(color: caisseOuverte ? AppColors.green : AppColors.muted, fontSize: 12.5),
                ),
              ],
            ],
            const SizedBox(height: AppSpacing.md),
            _ChoixClient(clientId: _client, obligatoire: credit, onChanged: (id) => setState(() => _client = id)),
            if (credit) ...[
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('vente-acompte'),
                controller: _acompte,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.rcpDeposit,
                  helperText: l10n.rcpDepositHint,
                  errorText: acompteValide ? null : l10n.validationAmount,
                  prefixIcon: const Icon(Icons.payments_outlined),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_montantAcompte > 0) ...[const SizedBox(height: AppSpacing.sm), choixMode],
            ],
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _remise,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l10n.comDiscount, prefixIcon: const Icon(Icons.discount_outlined)),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Text(
                  l10n.comToPay,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted, fontSize: 16),
                ),
                const Spacer(),
                Text(
                  montant(context, ref, aPayer < 0 ? 0 : aPayer),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 28, color: AppColors.ink),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('vente-valider'),
              style: FilledButton.styleFrom(backgroundColor: widget.mode == ModeVente.gros ? _couleurGros : null),
              onPressed: valide ? _valider : null,
              child: _enCours
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Text(l10n.comConfirmSale),
            ),
          ],
        ),
      ),
    );
  }
}

/// Client de la vente, sans ralentir le comptoir : client comptoir (par
/// défaut), client existant, ou simple nom ajouté en deux secondes.
class _ChoixClient extends ConsumerWidget {
  const _ChoixClient({required this.clientId, required this.obligatoire, required this.onChanged});
  final String? clientId;

  /// Vente à crédit : un client identifiable est exigé.
  final bool obligatoire;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final client = clientId == null ? null : ref.watch(tousContactsProvider).value?.where((c) => c.id == clientId).firstOrNull;
    final peutCreer = ref.watch(droitsCommerceProvider).creerContacts;

    Future<void> selectionner() async {
      final c = await choisirContact(context, RelationContact.client);
      if (c != null) onChanged(c.id);
    }

    Future<void> ajouter() async {
      final c = await ajouterClientRapide(context, ref);
      if (c != null) onChanged(c.id);
    }

    Widget option(IconData icone, String libelle, {required bool choisi, required VoidCallback onTap, Key? key}) => Expanded(
      child: Material(
        color: choisi ? AppColors.greenSoft : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: choisi ? AppColors.green : AppColors.border, width: choisi ? 1.6 : 1),
        ),
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icone, color: choisi ? AppColors.green : AppColors.ink),
                const SizedBox(height: 4),
                Text(
                  libelle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: choisi ? AppColors.greenPressed : AppColors.ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.comCustomer,
          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted),
        ),
        const SizedBox(height: 6),
        if (client != null)
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              key: const Key('vente-client'),
              leading: const CircleAvatar(
                backgroundColor: AppColors.greenSoft,
                child: Icon(Icons.person_rounded, color: AppColors.green),
              ),
              title: Text(client.nomAffiche, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: client.telephone == null ? null : Text(client.telephone!),
              trailing: IconButton(tooltip: l10n.rcpCounterCustomer, icon: const Icon(Icons.close), onPressed: () => onChanged(null)),
              onTap: selectionner,
            ),
          )
        else
          Row(
            children: [
              if (!obligatoire) ...[
                option(
                  Icons.person_outline_rounded,
                  l10n.rcpCounterCustomer,
                  choisi: true,
                  onTap: () => onChanged(null),
                  key: const Key('vente-client-comptoir'),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              option(Icons.search_rounded, l10n.rcpSelectCustomer, choisi: false, onTap: selectionner, key: const Key('vente-client')),
              if (peutCreer) ...[
                const SizedBox(width: AppSpacing.sm),
                option(
                  Icons.person_add_alt_1_outlined,
                  l10n.rcpAddName,
                  choisi: false,
                  onTap: ajouter,
                  key: const Key('vente-client-ajouter'),
                ),
              ],
            ],
          ),
        if (obligatoire && client == null) ...[
          const SizedBox(height: 6),
          Text(
            l10n.rcpCreditNeedsCustomer,
            style: const TextStyle(color: AppColors.negative, fontWeight: FontWeight.w600, fontSize: 12.5),
          ),
        ],
      ],
    );
  }
}

/// Après la validation : la vente est devenue un reçu. Client → reçu →
/// total → paiement → actions (voir, partager, imprimer).
class _VenteTerminee extends ConsumerWidget {
  const _VenteTerminee({required this.vente});
  final Vente vente;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Version à jour (numéro attribué par le serveur après synchronisation).
    final v = ref.watch(etatCommerceProvider).value?.vente(vente.id) ?? vente;
    final recu = donneesRecu(context, ref, v);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.greenSoft,
              child: Icon(Icons.check_rounded, size: 36, color: AppColors.green),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.rcpSaleSaved,
            key: const Key('vente-terminee'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            recu.numero ?? l10n.rcpNumberPending,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: recu.numero == null ? 13 : 18,
              color: recu.numero == null ? AppColors.muted : CouleursRecu.bleu,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  _ligneResume(l10n.comCustomer, recu.client ?? l10n.rcpCounterCustomer),
                  const Divider(height: 20),
                  _ligneResume(l10n.comTotal, l10n.montant(recu.total, recu.devise), fort: true),
                  if (recu.paiement case final p? when p.isNotEmpty) ...[const SizedBox(height: 6), _ligneResume(l10n.comPayment, p)],
                  if (recu.reste > 0) ...[
                    const SizedBox(height: 6),
                    _ligneResume(l10n.rcpRemainingToPay, l10n.montant(recu.reste, recu.devise), couleur: AppColors.warning),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ActionsRecu(
            recu: recu,
            onVoir: () {
              Navigator.pop(context);
              context.push(Routes.vente(v.id));
            },
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            key: const Key('vente-nouvelle'),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.add_shopping_cart_rounded),
            label: Text(l10n.rcpNewSale),
          ),
        ],
      ),
    );
  }

  static Widget _ligneResume(String label, String valeur, {bool fort = false, Color? couleur}) => Row(
    children: [
      Text(label, style: const TextStyle(color: AppColors.muted)),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          valeur,
          textAlign: TextAlign.end,
          style: TextStyle(fontWeight: fort ? FontWeight.w900 : FontWeight.w700, fontSize: fort ? 22 : 15, color: couleur ?? AppColors.ink),
        ),
      ),
    ],
  );
}
