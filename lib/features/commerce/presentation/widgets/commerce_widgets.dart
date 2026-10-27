import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../finances/presentation/widgets/finances_widgets.dart' show deviseProvider;
import '../../domain/entities/commerce.dart';
import '../commerce_providers.dart';

export '../../../finances/presentation/widgets/finances_widgets.dart' show deviseProvider;

// =============================================================================
// Formats
// =============================================================================

/// « 12,5 » / « 1 250 » selon la langue (4 décimales au plus, sans zéros inutiles).
String formatQte(BuildContext context, Qte q) =>
    NumberFormat('#,##0.####', Localizations.localeOf(context).toString()).format(q.valeur);

/// Nom d'unité accordé en français (« 2 cartons ») ; tel quel ailleurs.
String nomUnite(BuildContext context, String nom, Qte q) {
  final fr = Localizations.localeOf(context).languageCode == 'fr';
  if (!fr || q <= Qte.un || nom.contains(' ') || RegExp(r'[sxz]$', caseSensitive: false).hasMatch(nom)) {
    return nom;
  }
  return '${nom}s';
}

String qteUnite(BuildContext context, Qte q, String unite) => '${formatQte(context, q)} ${nomUnite(context, unite, q)}';

/// Stock lisible dans la plus grande unité : « 97 cartons + 35 pièces ».
String quantiteLisible(BuildContext context, Produit p, Qte q) {
  if (!p.aPlusieursUnites || q <= Qte.zero) return qteUnite(context, q, p.uniteBase);
  final grande = p.plusGrandeUnite;
  final lots = q.lotsEntiers(grande.facteur);
  final reste = q - Qte(lots * grande.facteur.brut);
  if (lots == 0) return qteUnite(context, q, p.uniteBase);
  final texteLots = qteUnite(context, Qte(lots * Qte.echelle), grande.nom);
  return reste.estNul ? texteLots : '$texteLots + ${qteUnite(context, reste, p.uniteBase)}';
}

/// Équivalent en unité de base (« = 4 000 pièces »), si le produit a des lots.
String? equivalentBase(BuildContext context, Produit p, Qte q) =>
    p.aPlusieursUnites && q > Qte.zero ? '= ${qteUnite(context, q, p.uniteBase)}' : null;

String montant(BuildContext context, WidgetRef ref, int valeur) =>
    context.l10n.montant(valeur, ref.watch(deviseProvider));

// =============================================================================
// Catégories : icônes et couleurs
// =============================================================================

abstract final class VisuelsCategories {
  static const icones = <String, IconData>{
    'outils': Icons.handyman_outlined,
    'materiaux': Icons.foundation_outlined,
    'carrelage': Icons.grid_view_rounded,
    'peinture': Icons.format_paint_outlined,
    'plomberie': Icons.plumbing_outlined,
    'electricite': Icons.electrical_services_outlined,
    'visserie': Icons.hardware_outlined,
    'menuiserie': Icons.carpenter_outlined,
    'accessoires': Icons.home_repair_service_outlined,
    'boissons': Icons.local_drink_outlined,
    'alimentation': Icons.rice_bowl_outlined,
    'epicerie': Icons.shopping_basket_outlined,
    'frais': Icons.kitchen_outlined,
    'fruits': Icons.eco_outlined,
    'viande': Icons.set_meal_outlined,
    'boulangerie': Icons.bakery_dining_outlined,
    'hygiene': Icons.soap_outlined,
    'menage': Icons.cleaning_services_outlined,
    'cosmetique': Icons.face_retouching_natural_outlined,
    'bebe': Icons.child_friendly_outlined,
    'vetements': Icons.checkroom_outlined,
    'chaussures': Icons.directions_walk_outlined,
    'bijoux': Icons.diamond_outlined,
    'electronique': Icons.devices_other_outlined,
    'telephonie': Icons.smartphone_outlined,
    'informatique': Icons.computer_outlined,
    'electromenager': Icons.blender_outlined,
    'meubles': Icons.chair_outlined,
    'papeterie': Icons.edit_note_outlined,
    'pharmacie': Icons.medication_outlined,
    'jouets': Icons.toys_outlined,
    'sport': Icons.sports_soccer_outlined,
    'auto': Icons.directions_car_outlined,
    'jardin': Icons.yard_outlined,
    'autre': Icons.category_outlined,
  };

  /// Mots-clés (fr / en, sans accents) qui désignent chaque icône.
  static const _motsCles = <String, List<String>>{
    'outils': ['outil', 'tool', 'marteau', 'pince'],
    'materiaux': ['materiau', 'ciment', 'beton', 'brique', 'sable', 'fer', 'construction', 'material'],
    'carrelage': ['carrel', 'tile', 'faience'],
    'peinture': ['peint', 'paint', 'vernis', 'primaire', 'enduit'],
    'plomberie': ['plomb', 'plumb', 'tuyau', 'robinet', 'sanitaire'],
    'electricite': ['electri', 'cable', 'ampoule', 'prise', 'eclairage', 'lampe'],
    'visserie': ['vis', 'boulon', 'clou', 'ecrou', 'quincaill', 'hardware', 'screw'],
    'menuiserie': ['menuis', 'bois', 'porte', 'fenetre', 'wood'],
    'boissons': ['boisson', 'drink', 'jus', 'eau', 'soda', 'water', 'juice', 'biere'],
    'alimentation': ['aliment', 'food', 'riz', 'cereale', 'rice'],
    'epicerie': ['epicer', 'grocer', 'conserve', 'huile', 'sucre'],
    'frais': ['frais', 'fresh', 'laitier', 'lait', 'yaourt', 'fromage', 'dairy', 'surgele'],
    'fruits': ['fruit', 'legume', 'vegetable'],
    'viande': ['viande', 'poisson', 'meat', 'fish', 'boucher', 'poulet'],
    'boulangerie': ['boulang', 'pain', 'bakery', 'bread', 'patisser', 'gateau'],
    'hygiene': ['hygien', 'savon', 'soap', 'dentifrice', 'shampo'],
    'menage': ['menage', 'nettoy', 'clean', 'detergent', 'entretien', 'lessive'],
    'cosmetique': ['cosmet', 'beaute', 'beauty', 'parfum', 'maquill', 'creme'],
    'bebe': ['bebe', 'baby', 'couche', 'enfant'],
    'vetements': ['vetement', 'habit', 'cloth', 'textile', 'mode', 'pagne', 'tissu', 'robe', 'chemise'],
    'chaussures': ['chaussure', 'shoe', 'sandale', 'basket'],
    'bijoux': ['bijou', 'jewel', 'montre'],
    'telephonie': ['telephon', 'phone', 'mobile', 'portable', 'smartphone'],
    'electronique': ['electroni', 'tele', 'tv', 'audio'],
    'informatique': ['informati', 'ordinateur', 'computer', 'laptop', 'pc'],
    'electromenager': ['electromenager', 'appliance', 'frigo', 'cuisine'],
    'meubles': ['meuble', 'furniture', 'chaise', 'table', 'canape'],
    'papeterie': ['papeter', 'stationery', 'cahier', 'stylo', 'fourniture', 'livre', 'scolaire'],
    'pharmacie': ['pharma', 'medic', 'sante', 'health'],
    'jouets': ['jouet', 'toy', 'jeu'],
    'sport': ['sport', 'fitness', 'ballon'],
    'auto': ['auto', 'voiture', 'moto', 'pneu'],
    'jardin': ['jardin', 'garden', 'plante', 'engrais'],
    'accessoires': ['accessoire', 'accessor', 'sac', 'bag'],
  };

  /// Icône la plus parlante pour un nom de catégorie (« Jus & sodas » → boissons) :
  /// un mot du nom doit commencer par un mot-clé.
  static String suggerer(String nom) {
    final mots = _sansAccents(nom.toLowerCase()).split(RegExp(r'[^a-z0-9]+')).where((m) => m.isNotEmpty);
    for (final MapEntry(key: code, value: cles) in _motsCles.entries) {
      if (mots.any((m) => cles.any(m.startsWith))) return code;
    }
    return 'autre';
  }

  static String _sansAccents(String s) {
    const avec = 'àâäáãéèêëíìîïóòôöõúùûüçñ';
    const sans = 'aaaaaeeeeiiiiooooouuuucn';
    final b = StringBuffer();
    for (final ch in s.characters) {
      final i = avec.indexOf(ch);
      b.write(i < 0 ? ch : sans[i]);
    }
    return b.toString();
  }

  /// Teintes harmonisées avec la palette DubaGest (fond doux dérivé).
  static const couleurs = <String>[
    '#1E7E4E', '#D97706', '#2563EB', '#7C3AED', '#DB2777',
    '#0891B2', '#65A30D', '#DC2626', '#475569', '#B45309',
  ];

  static IconData icone(String? code) => icones[code] ?? Icons.category_outlined;

  /// Icône d'une catégorie ; sans choix explicite, déduite de son nom.
  static IconData iconeDe(CategorieProduit? c) {
    if (c == null) return Icons.category_outlined;
    final code = c.icone == null || c.icone == 'autre' ? suggerer(c.nom) : c.icone;
    return icone(code);
  }

  static Color couleur(String? hex) {
    if (hex == null || hex.length != 7) return AppColors.muted;
    return Color(int.parse('FF${hex.substring(1)}', radix: 16));
  }
}

// =============================================================================
// Photo du produit
// =============================================================================

/// Photo du produit ; à défaut, vignette aux couleurs de sa catégorie avec
/// son icône et les initiales du produit (jamais une icône grise anonyme).
class ProduitImage extends ConsumerWidget {
  const ProduitImage({
    super.key,
    required this.produit,
    this.taille = 56,
    this.largeur,
    this.hauteur,
    this.rayon = 12,
    this.chemin,
  });

  final Produit produit;
  final double taille;
  final double? largeur;
  final double? hauteur;
  final double rayon;

  /// Photo particulière (galerie) ; sinon la photo principale.
  final String? chemin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = chemin ?? produit.photoPrincipale;
    final etat = ref.watch(etatCommerceProvider).value;
    final categorie = etat?.racine(produit.categorieId) ?? etat?.categorie(produit.categorieId);
    final teinte = VisuelsCategories.couleur(categorie?.couleur ?? VisuelsCategories.couleurs.first);

    final dimRef = taille > 0 ? taille : 56.0;

    Widget vignette() => Container(
          color: teinte.withValues(alpha: 0.12),
          alignment: Alignment.center,
          child: dimRef < 48
              ? Icon(VisuelsCategories.iconeDe(categorie), color: teinte, size: dimRef * 0.5)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(VisuelsCategories.iconeDe(categorie), color: teinte, size: dimRef * 0.34),
                    SizedBox(height: dimRef * 0.04),
                    Text(
                      _initiales(produit.nom),
                      style: TextStyle(
                        color: teinte,
                        fontWeight: FontWeight.w800,
                        fontSize: (dimRef * 0.16).clamp(10, 22),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        );

    Widget contenu = vignette();
    if (photo != null) {
      final octets = ref.watch(photoProduitProvider(photo));
      contenu = switch (octets) {
        AsyncData(value: final o?) => Image.memory(o, fit: BoxFit.cover, gaplessPlayback: true,
            errorBuilder: (_, _, _) => vignette()),
        AsyncLoading() => Container(color: AppColors.border.withValues(alpha: 0.5)),
        _ => vignette(),
      };
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(rayon),
      child: SizedBox(
        width: largeur ?? taille,
        height: hauteur ?? taille,
        child: contenu,
      ),
    );
  }

  static String _initiales(String nom) {
    final mots = nom.trim().split(RegExp(r'\s+')).where((m) => m.isNotEmpty && RegExp(r'\p{L}', unicode: true).hasMatch(m));
    return mots.take(2).map((m) => m.characters.first.toUpperCase()).join();
  }
}

/// Pastille de catégorie (photo ou icône + couleur).
class CategorieIcone extends ConsumerWidget {
  const CategorieIcone({super.key, required this.categorie, this.taille = 40});
  final CategorieProduit? categorie;
  final double taille;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = categorie;
    final teinte = VisuelsCategories.couleur(c?.couleur ?? VisuelsCategories.couleurs.first);
    if (c != null && c.icone != null && c.icone!.startsWith('photo:')) {
      final chemin = c.icone!.substring(6);
      final octets = ref.watch(photoProduitProvider(chemin));
      final imageWidget = switch (octets) {
        AsyncData(value: final o?) => Image.memory(
            o,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => Icon(VisuelsCategories.iconeDe(c), color: teinte, size: taille * 0.52),
          ),
        AsyncLoading() => Container(color: AppColors.border.withValues(alpha: 0.5)),
        _ => Icon(VisuelsCategories.iconeDe(c), color: teinte, size: taille * 0.52),
      };
      return ClipRRect(
        borderRadius: BorderRadius.circular(taille / 3.2),
        child: SizedBox(
          width: taille,
          height: taille,
          child: Container(
            color: teinte.withValues(alpha: 0.12),
            child: imageWidget,
          ),
        ),
      );
    }
    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(taille / 3.2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [teinte.withValues(alpha: 0.20), teinte.withValues(alpha: 0.08)],
        ),
        border: Border.all(color: teinte.withValues(alpha: 0.18)),
      ),
      child: Icon(VisuelsCategories.iconeDe(categorie), color: teinte, size: taille * 0.52),
    );
  }
}

/// Visuel d'une catégorie : photo de la catégorie, ou vraies photos de ses
/// produits (une seule en plein cadre, sinon mosaïque 2 × 2), à défaut son icône.
class CategorieVisuel extends ConsumerWidget {
  const CategorieVisuel({super.key, required this.categorie, this.taille = 64, this.rayon = 16})
      : banniere = false;

  /// Occupe toute la place offerte (en-tête de carte).
  const CategorieVisuel.banniere({super.key, required this.categorie, this.rayon = 0})
      : taille = double.infinity,
        banniere = true;

  final CategorieProduit categorie;
  final double taille;
  final double rayon;
  final bool banniere;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(etatCommerceProvider).value;
    final photos = etat == null
        ? const <String>[]
        : [
            for (final p in etat.produitsActifs)
              if (p.photoPrincipale != null && etat.dansCategorie(p, categorie.id)) p.photoPrincipale!,
          ].take(4).toList();
    final teinte = VisuelsCategories.couleur(categorie.couleur);
    if (photos.isEmpty) {
      if (categorie.icone != null && categorie.icone!.startsWith('photo:')) {
        final chemin = categorie.icone!.substring(6);
        final octets = ref.watch(photoProduitProvider(chemin));
        final img = switch (octets) {
          AsyncData(value: final o?) => Image.memory(
              o,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => Icon(VisuelsCategories.iconeDe(categorie), color: teinte, size: banniere ? 48 : taille * 0.5),
            ),
          _ => Icon(VisuelsCategories.iconeDe(categorie), color: teinte, size: banniere ? 48 : taille * 0.5),
        };
        if (banniere) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(rayon),
            child: SizedBox(width: double.infinity, height: double.infinity, child: img),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(rayon),
          child: SizedBox(width: taille, height: taille, child: img),
        );
      }
      if (!banniere) return CategorieIcone(categorie: categorie, taille: taille);
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(rayon),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [teinte.withValues(alpha: 0.22), teinte.withValues(alpha: 0.06)],
          ),
        ),
        alignment: Alignment.center,
        child: Icon(VisuelsCategories.iconeDe(categorie), color: teinte, size: 48),
      );
    }

    Widget cellule(String? chemin) => chemin == null
        ? Container(
            color: teinte.withValues(alpha: 0.12),
            alignment: Alignment.center,
            child: Icon(VisuelsCategories.iconeDe(categorie), color: teinte, size: banniere ? 28 : taille * 0.24),
          )
        : _PhotoCellule(chemin: chemin, teinte: teinte);

    final Widget contenu;
    if (photos.length == 1) {
      contenu = cellule(photos.first);
    } else {
      final cases = [...photos, ...List<String?>.filled(4 - photos.length, null)];
      Widget ligne(String? a, String? b) => Expanded(
            child: Row(children: [Expanded(child: cellule(a)), const SizedBox(width: 2), Expanded(child: cellule(b))]),
          );
      contenu = Column(children: [ligne(cases[0], cases[1]), const SizedBox(height: 2), ligne(cases[2], cases[3])]);
    }
    if (banniere) return ClipRRect(borderRadius: BorderRadius.circular(rayon), child: contenu);
    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(rayon),
        border: Border.all(color: teinte.withValues(alpha: 0.25)),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(rayon - 1), child: contenu),
    );
  }
}

class _PhotoCellule extends ConsumerWidget {
  const _PhotoCellule({required this.chemin, required this.teinte});
  final String chemin;
  final Color teinte;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fond = Container(color: teinte.withValues(alpha: 0.10));
    return switch (ref.watch(photoProduitProvider(chemin))) {
      AsyncData(value: final o?) => Image.memory(o,
          fit: BoxFit.cover, width: double.infinity, height: double.infinity, gaplessPlayback: true,
          errorBuilder: (_, _, _) => fond),
      _ => fond,
    };
  }
}

// =============================================================================
// Statut et niveau de stock
// =============================================================================

(Color, Color, IconData) couleursStatut(StatutStock s) => switch (s) {
      StatutStock.enStock => (AppColors.positive, AppColors.positiveSoft, Icons.check_circle_rounded),
      StatutStock.faible => (AppColors.warning, AppColors.warningSoft, Icons.warning_amber_rounded),
      StatutStock.rupture => (AppColors.negative, AppColors.negativeSoft, Icons.error_rounded),
    };

String libelleStatut(AppLocalizations l10n, StatutStock s) => switch (s) {
      StatutStock.enStock => l10n.comStatusInStock,
      StatutStock.faible => l10n.comStatusLow,
      StatutStock.rupture => l10n.comStatusOut,
    };

/// Statut : toujours icône + texte + couleur (jamais la couleur seule).
class StockBadge extends StatelessWidget {
  const StockBadge({super.key, required this.statut, this.compact = false});
  final StatutStock statut;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (fg, bg, icone) = couleursStatut(statut);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: compact ? 12 : 14, color: fg),
          const SizedBox(width: 4),
          Text(
            libelleStatut(context.l10n, statut),
            style: TextStyle(color: fg, fontSize: compact ? 11 : 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Jauge du niveau de stock par rapport au seuil d'alerte (lecture sans calcul).
class StockJauge extends StatelessWidget {
  const StockJauge({super.key, required this.quantite, required this.seuil, required this.statut});
  final Qte quantite;
  final Qte seuil;
  final StatutStock statut;

  @override
  Widget build(BuildContext context) {
    final (fg, _, _) = couleursStatut(statut);
    // Le seuil occupe le premier tiers de la jauge : au-delà de 3 × seuil, elle est pleine.
    final reference = seuil.estPositif ? seuil.valeur * 3 : (quantite.valeur <= 0 ? 1.0 : quantite.valeur);
    final niveau = (quantite.valeur / reference).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: statut == StatutStock.rupture ? 0 : niveau.toDouble().clamp(0.04, 1.0),
        minHeight: 6,
        backgroundColor: AppColors.border,
        color: fg,
      ),
    );
  }
}

// =============================================================================
// Boutique
// =============================================================================

/// Sélecteur de boutique : affiché seulement s'il y a plusieurs boutiques.
class BoutiqueSelecteur extends ConsumerWidget {
  const BoutiqueSelecteur({super.key, this.toutes = true});

  /// Propose « Toutes les boutiques ».
  final bool toutes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final boutiques = ref.watch(boutiquesProvider);
    if (boutiques.length < 2) return const SizedBox.shrink();
    final courante = ref.watch(boutiqueCouranteProvider);
    final nom = courante == null ? l10n.comAllShops : nomBoutique(ref, courante);
    return PopupMenuButton<String?>(
      key: const Key('boutique-selecteur'),
      tooltip: l10n.comChooseShop,
      onSelected: (id) => choisirBoutique(ref, id),
      itemBuilder: (_) => [
        if (toutes)
          CheckedPopupMenuItem(value: null, checked: courante == null, child: Text(l10n.comAllShops)),
        for (final b in boutiques) CheckedPopupMenuItem(value: b.id, checked: courante == b.id, child: Text(b.nom)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined, size: 18, color: AppColors.green),
            const SizedBox(width: 6),
            Flexible(
              child: Text(nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
            ),
            const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

/// Choix d'une boutique dans un formulaire (parmi celles autorisées pour l'action).
class ChampBoutique extends ConsumerWidget {
  const ChampBoutique({
    super.key,
    required this.valeur,
    required this.autorisees,
    required this.onChanged,
    this.label,
    this.exclure,
  });

  final String? valeur;
  final List<String> autorisees;
  final ValueChanged<String?> onChanged;
  final String? label;
  final String? exclure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boutiques = [
      for (final b in ref.watch(boutiquesProvider))
        if (autorisees.contains(b.id) && b.id != exclure) b,
    ];
    return DropdownButtonFormField<String>(
      initialValue: boutiques.any((b) => b.id == valeur) ? valeur : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label ?? context.l10n.comShop,
        prefixIcon: const Icon(Icons.storefront_outlined),
      ),
      items: [for (final b in boutiques) DropdownMenuItem(value: b.id, child: Text(b.nom))],
      onChanged: onChanged,
      validator: (v) => v == null ? context.l10n.comShopRequired : null,
    );
  }
}

// =============================================================================
// États, sections, aperçus
// =============================================================================

/// État vide pédagogique : une phrase, une seule action.
class EtatVide extends StatelessWidget {
  const EtatVide({
    super.key,
    required this.icone,
    required this.titre,
    required this.message,
    this.action,
    this.onAction,
  });

  final IconData icone;
  final String titre;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(color: AppColors.greenSoft, shape: BoxShape.circle),
              child: Icon(icone, size: 42, color: AppColors.green),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(titre, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted, height: 1.4)),
            if (action != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(action!),
                style: FilledButton.styleFrom(minimumSize: const Size(220, 52)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Carte de section titrée (fiches et formulaires).
class SectionCarte extends StatelessWidget {
  const SectionCarte({super.key, this.titre, this.icone, this.action, required this.child, this.padding});
  final String? titre;
  final IconData? icone;
  final Widget? action;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (titre != null) ...[
              Row(
                children: [
                  if (icone != null) ...[Icon(icone, size: 20, color: AppColors.green), const SizedBox(width: 8)],
                  Expanded(child: Text(titre!, style: Theme.of(context).textTheme.titleMedium)),
                  ?action,
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// « Stock actuel → Après » : affiché avant chaque validation.
class AvantApres extends StatelessWidget {
  const AvantApres({super.key, required this.titre, required this.avant, required this.apres, this.negatif = false});
  final String titre;
  final String avant;
  final String apres;

  /// L'opération mettrait le stock en dessous de zéro.
  final bool negatif;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final couleur = negatif ? AppColors.negative : AppColors.green;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (negatif ? AppColors.negativeSoft : AppColors.greenSoft).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.comBefore, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    Text(avant, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: couleur),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.comAfter, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    Text(apres, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: couleur)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Indicateur compact et cliquable (filtre) de l'écran Stock.
class IndicateurStock extends StatelessWidget {
  const IndicateurStock({
    super.key,
    required this.valeur,
    required this.libelle,
    required this.icone,
    required this.couleur,
    this.selectionne = false,
    this.onTap,
  });

  final String valeur;
  final String libelle;
  final IconData icone;
  final Color couleur;
  final bool selectionne;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selectionne ? couleur.withValues(alpha: 0.12) : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selectionne ? couleur : AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 108,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 18, color: couleur),
              const SizedBox(height: 4),
              Text(valeur,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, height: 1.15, fontWeight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 2),
              Text(libelle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, height: 1.15, color: AppColors.muted, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Message bref de confirmation (« ✓ Stock mis à jour »).
void confirmer(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: AppColors.greenOnDark),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ]),
    ));
}

/// Message d'erreur compréhensible (règle métier traduite, ou texte déjà prêt).
void signalerErreur(BuildContext context, Object erreur) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: AppColors.negative,
      content: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(erreur is String ? erreur : context.l10n.failure(erreur))),
      ]),
    ));
}
