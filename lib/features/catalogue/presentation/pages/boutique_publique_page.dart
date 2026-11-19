import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_theme.dart';
import '../../services/media_hybrid_resolver.dart';
import '../../data/catalogue_repository.dart';
import '../../domain/entities/catalogue_public_data.dart';
import '../widgets/vocal_player_badge.dart';

/// Page web et mobile publique d'une boutique commerçante DubaGest V2.
/// Accessible sans compte (clients, prospects, réseaux sociaux) via `/boutique/:slug` ou `/c/:slug`.
class BoutiquePubliquePage extends ConsumerStatefulWidget {
  const BoutiquePubliquePage({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<BoutiquePubliquePage> createState() => _BoutiquePubliquePageState();
}

class _BoutiquePubliquePageState extends ConsumerState<BoutiquePubliquePage> {
  String? _collectionSelectionneeId;
  final Map<String, int> _panier = {}; // produitId -> quantite

  void _ajouterAuPanier(String produitId) {
    HapticFeedback.lightImpact();
    setState(() {
      _panier[produitId] = (_panier[produitId] ?? 0) + 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Article ajouté à la commande WhatsApp'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _retirerDuPanier(String produitId) {
    HapticFeedback.lightImpact();
    setState(() {
      final qte = _panier[produitId] ?? 0;
      if (qte <= 1) {
        _panier.remove(produitId);
      } else {
        _panier[produitId] = qte - 1;
      }
    });
  }

  int get _totalArticlesPanier => _panier.values.fold(0, (a, b) => a + b);

  int _calculerTotalPanier(List<ProduitCataloguePublic> produits) {
    var total = 0;
    for (final entry in _panier.entries) {
      final prod = produits.where((p) => p.id == entry.key).firstOrNull;
      if (prod != null) {
        total += prod.prix * entry.value;
      }
    }
    return total;
  }

  Future<void> _commanderWhatsAppPanier({
    required InfoEntreprisePublique boutique,
    required List<ProduitCataloguePublic> produits,
  }) async {
    final contact = boutique.whatsappContact;
    if (contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro WhatsApp du commerçant non disponible')),
      );
      return;
    }

    final cleanContact = contact.replaceAll(RegExp(r'[^0-9]'), '');
    final sb = StringBuffer();
    sb.writeln('Bonjour *${boutique.nom}*, je souhaite commander les articles suivants depuis votre catalogue :');
    sb.writeln('');

    var total = 0;
    for (final entry in _panier.entries) {
      final prod = produits.where((p) => p.id == entry.key).firstOrNull;
      if (prod != null) {
        final sousTotal = prod.prix * entry.value;
        total += sousTotal;
        sb.writeln('• ${entry.value}x *${prod.nom}* à ${prod.prix} FCFA = $sousTotal FCFA');
      }
    }

    sb.writeln('');
    sb.writeln('*Total commande : $total FCFA*');
    sb.writeln('Catalogue : https://dubagest.com/boutique/${boutique.slug ?? widget.slug}');

    final url = 'https://wa.me/$cleanContact?text=${Uri.encodeComponent(sb.toString())}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _partagerLien(InfoEntreprisePublique boutique) async {
    HapticFeedback.mediumImpact();
    final url = 'https://dubagest.com/boutique/${boutique.slug ?? widget.slug}';
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Lien copié : $url')),
            ],
          ),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _ouvrirFicheProduit(BuildContext context, ProduitCataloguePublic produit, InfoEntreprisePublique boutique) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FicheProduitSheet(
        produit: produit,
        boutique: boutique,
        slug: widget.slug,
        onAjouterPanier: () => _ajouterAuPanier(produit.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final boutiqueAsync = ref.watch(boutiquePubliqueProvider(widget.slug));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: boutiqueAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.green),
              SizedBox(height: 16),
              Text('Chargement de la vitrine...', style: TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storefront_outlined, size: 64, color: AppColors.muted),
                const SizedBox(height: 16),
                const Text(
                  'Boutique introuvable ou indisponible',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vérifiez le lien du catalogue ou réessayez ultérieurement.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted.withValues(alpha: 0.9)),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => ref.refresh(boutiquePubliqueProvider(widget.slug)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Réessayer'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          final boutique = data.entreprise;
          final produitsFiltres = _collectionSelectionneeId == null
              ? data.produits
              : data.produits.where((p) => p.collectionId == _collectionSelectionneeId).toList();

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // 1. En-tête profil inspiré des réseaux sociaux (TikTok / Instagram commerce)
                  SliverToBoxAdapter(
                    child: _BoutiqueHeader(
                      boutique: boutique,
                      totalProduits: data.produits.length,
                      onPartager: () => _partagerLien(boutique),
                    ),
                  ),

                  // 2. Nouveautés / Stories si disponibles
                  if (data.nouveautes.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _NouveautesSection(nouveautes: data.nouveautes),
                    ),

                  // 3. Barre de filtres par collection
                  if (data.collections.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _CollectionsBar(
                        collections: data.collections,
                        selectionId: _collectionSelectionneeId,
                        onSelect: (id) => setState(() => _collectionSelectionneeId = id),
                      ),
                    ),

                  // 4. Grille des produits
                  if (produitsFiltres.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Aucun produit disponible dans cette catégorie.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.68,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final prod = produitsFiltres[index];
                            final qte = _panier[prod.id] ?? 0;
                            return _ProduitCard(
                              produit: prod,
                              quantitePanier: qte,
                              onTap: () => _ouvrirFicheProduit(context, prod, boutique),
                              onAjouter: () => _ajouterAuPanier(prod.id),
                            );
                          },
                          childCount: produitsFiltres.length,
                        ),
                      ),
                    ),
                ],
              ),

              // 5. Barre Flottante Panier WhatsApp
              if (_panier.isNotEmpty)
                Positioned(
                  start: 16,
                  end: 16,
                  bottom: 20,
                  child: _PanierFloatingBar(
                    totalArticles: _totalArticlesPanier,
                    montantTotal: _calculerTotalPanier(data.produits),
                    onCommander: () => _commanderWhatsAppPanier(
                      boutique: boutique,
                      produits: data.produits,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Composants UI de la page boutique
// -----------------------------------------------------------------------------

class _BoutiqueHeader extends StatelessWidget {
  const _BoutiqueHeader({
    required this.boutique,
    required this.totalProduits,
    required this.onPartager,
  });

  final InfoEntreprisePublique boutique;
  final int totalProduits;
  final VoidCallback onPartager;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Couverture élégante DubaGest
          Container(
            height: 120,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                PositionedDirectional(
                  end: 12,
                  top: 12,
                  child: IconButton(
                    onPressed: onPartager,
                    icon: const Icon(Icons.share_rounded, color: Colors.white),
                    tooltip: 'Partager le catalogue',
                  ),
                ),
              ],
            ),
          ),

          // Profil & Identité commerciale
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Transform.translate(
                  offset: const Offset(0, -36),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: boutique.logoUrl != null && boutique.logoUrl!.isNotEmpty
                        ? Image.network(
                            MediaHybridResolver.resolvePublicUrl(boutique.logoUrl!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _avatarFallback(boutique.nom),
                          )
                        : _avatarFallback(boutique.nom),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              boutique.nom,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.ink),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, color: AppColors.green, size: 20),
                        ],
                      ),
                      if (boutique.ville != null && boutique.ville!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: AppColors.muted),
                            const SizedBox(width: 4),
                            Text(
                              boutique.ville!,
                              style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                      if (boutique.descriptionCommerciale != null && boutique.descriptionCommerciale!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          boutique.descriptionCommerciale!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13.5, color: AppColors.ink, height: 1.3),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _StatPill(icon: Icons.inventory_2_outlined, label: '$totalProduits produits'),
                          const SizedBox(width: 8),
                          const _StatPill(icon: Icons.chat_bubble_outline_rounded, label: 'Commandes WhatsApp'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String nom) {
    final initiale = nom.trim().isNotEmpty ? nom.trim()[0].toUpperCase() : 'D';
    return Container(
      color: AppColors.greenSoft,
      alignment: Alignment.center,
      child: Text(
        initiale,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 32, color: AppColors.greenPressed),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.muted),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _CollectionsBar extends StatelessWidget {
  const _CollectionsBar({
    required this.collections,
    required this.selectionId,
    required this.onSelect,
  });

  final List<CollectionPublique> collections;
  final String? selectionId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ChoiceChip(
            label: const Text('Tout'),
            selected: selectionId == null,
            onSelected: (_) => onSelect(null),
            selectedColor: AppColors.green,
            labelStyle: TextStyle(
              color: selectionId == null ? Colors.white : AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final coll in collections) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(coll.nom),
              selected: selectionId == coll.id,
              onSelected: (_) => onSelect(coll.id),
              selectedColor: AppColors.green,
              labelStyle: TextStyle(
                color: selectionId == coll.id ? Colors.white : AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NouveautesSection extends StatelessWidget {
  const _NouveautesSection({required this.nouveautes});
  final List<NouveautePublique> nouveautes;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign_rounded, color: Colors.amber, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nouveautes.first.titre,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.ink),
                ),
                if (nouveautes.first.message != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    nouveautes.first.message!,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProduitCard extends StatelessWidget {
  const _ProduitCard({
    required this.produit,
    required this.quantitePanier,
    required this.onTap,
    required this.onAjouter,
  });

  final ProduitCataloguePublic produit;
  final int quantitePanier;
  final VoidCallback onTap;
  final VoidCallback onAjouter;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Produit
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  produit.photoPrincipale != null
                      ? Image.network(
                          MediaHybridResolver.resolvePublicUrl(produit.photoPrincipale!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholder(),
                        )
                      : _placeholder(),

                  // Badge Promo
                  if (produit.aPromotion)
                    PositionedDirectional(
                      top: 8,
                      start: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.negative,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('PROMO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                    ),

                  // Badge Audio vocal
                  if (produit.audioPresentationUrl != null)
                    PositionedDirectional(
                      bottom: 8,
                      start: 8,
                      child: VocalPlayerBadge(audioUrl: produit.audioPresentationUrl!, compact: true),
                    ),
                ],
              ),
            ),

            // Infos Produit
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    produit.nom,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${produit.prix} F',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.greenPressed),
                      ),
                      if (produit.prixBarre != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${produit.prixBarre} F',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                      const Spacer(),
                      InkWell(
                        onTap: onAjouter,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.greenSoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_shopping_cart_rounded, size: 16, color: AppColors.green),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFFF1F5F9),
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, color: AppColors.muted, size: 36),
      );
}

class _FicheProduitSheet extends StatelessWidget {
  const _FicheProduitSheet({
    required this.produit,
    required this.boutique,
    required this.slug,
    required this.onAjouterPanier,
  });

  final ProduitCataloguePublic produit;
  final InfoEntreprisePublique boutique;
  final String slug;
  final VoidCallback onAjouterPanier;

  Future<void> _commanderDirectWhatsApp(BuildContext context) async {
    final contact = boutique.whatsappContact.replaceAll(RegExp(r'[^0-9]'), '');
    if (contact.isEmpty) return;

    final msg = 'Bonjour *${boutique.nom}*, je souhaite commander :\n'
        '• *${produit.nom}*\n'
        '• Prix : *${produit.prix} FCFA*\n'
        'Lien catalogue : https://dubagest.com/boutique/$slug';

    final uri = Uri.parse('https://wa.me/$contact?text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          // Galerie Photos (jusqu'à 5 photos)
          if (produit.photos.isNotEmpty)
            SizedBox(
              height: 200,
              child: PageView(
                children: [
                  for (final photo in produit.photos)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        MediaHybridResolver.resolvePublicUrl(photo),
                        fit: BoxFit.cover,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text(
            produit.nom,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${produit.prix} FCFA',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.greenPressed),
              ),
              if (produit.prixBarre != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${produit.prixBarre} FCFA',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.muted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),
          if (produit.audioPresentationUrl != null) ...[
            const SizedBox(height: 12),
            VocalPlayerBadge(audioUrl: produit.audioPresentationUrl!),
          ],
          if (produit.description != null && produit.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              produit.description!,
              style: const TextStyle(fontSize: 14, color: AppColors.ink, height: 1.4),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    onAjouterPanier();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: const Text('Au panier'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.green,
                    side: const BorderSide(color: AppColors.green),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _commanderDirectWhatsApp(context),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('Commander sur WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PanierFloatingBar extends StatelessWidget {
  const _PanierFloatingBar({
    required this.totalArticles,
    required this.montantTotal,
    required this.onCommander,
  });

  final int totalArticles;
  final int montantTotal;
  final VoidCallback onCommander;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$totalArticles article${totalArticles > 1 ? 's' : ''} sélectionné${totalArticles > 1 ? 's' : ''}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
              ),
              Text(
                '$montantTotal FCFA',
                style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: onCommander,
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Commander (WhatsApp)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
