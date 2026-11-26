import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../features/catalogue/domain/entities/catalogue_public_data.dart';
import '../../../../features/catalogue/presentation/widgets/vocal_player_badge.dart';
import '../../../../features/catalogue/services/media_hybrid_resolver.dart';
import '../providers/vitrine_providers.dart';
import '../../domain/entities/vitrine_bien_immobilier.dart';
import '../../domain/entities/vitrine_config.dart';
import '../../domain/entities/vitrine_demande_visite.dart';
import '../../domain/entities/vitrine_galerie_item.dart';
import '../../domain/entities/vitrine_membre_equipe.dart';
import '../../domain/entities/vitrine_prestation.dart';
import '../../domain/entities/vitrine_publique_data.dart';
import '../../domain/entities/vitrine_rendez_vous.dart';
import '../../domain/entities/vitrine_types.dart';

/// Page web et mobile publique d'une vitrine DubaGest V2.
/// Adaptée intelligemment au métier (TechVerse, GizmoHub, The LUXE Studio, Hollis, Havenly).
/// Accessible sans compte via `/v/:slug` ou `/boutique/:slug`.
class VitrinePubliquePage extends ConsumerStatefulWidget {
  const VitrinePubliquePage({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<VitrinePubliquePage> createState() => _VitrinePubliquePageState();
}

class _VitrinePubliquePageState extends ConsumerState<VitrinePubliquePage> {
  // Panier de commande pour les produits
  final Map<String, int> _panier = {};

  // Filtre recherche et catégorie
  String _recherche = '';
  String? _filtreTypeBien; // Pour Immobilier (Villa, Appartement, etc.)
  String? _filtreOffreBien; // Location ou Vente

  // Clés de scroll pour navigation fluide
  final _keyPrestations = GlobalKey();
  final _keyRdv = GlobalKey();
  final _keyGalerie = GlobalKey();
  final _keyProduits = GlobalKey();
  final _keyBiens = GlobalKey();
  final _keyContact = GlobalKey();

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    }
  }

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

  Future<void> _commanderWhatsAppPanier({
    required VitrineConfig vitrine,
    required List<ProduitCataloguePublic> produits,
  }) async {
    final contact = vitrine.whatsappContact;
    if (contact.isEmpty) return;
    final clean = contact.replaceAll(RegExp(r'[^0-9]'), '');

    final sb = StringBuffer();
    sb.writeln('Bonjour *${vitrine.titreHero ?? "DubaGest"}*, je souhaite commander les articles suivants depuis votre vitrine :');
    sb.writeln('');

    var total = 0;
    for (final entry in _panier.entries) {
      final prod = produits.where((p) => p.id == entry.key).firstOrNull;
      if (prod != null) {
        final st = prod.prix * entry.value;
        total += st;
        sb.writeln('• ${entry.value}x *${prod.nom}* (${prod.prix} FCFA) = $st FCFA');
      }
    }
    sb.writeln('');
    sb.writeln('*Total commande : $total FCFA*');
    sb.writeln('Site : ${vitrine.urlPublique}');

    final uri = Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(sb.toString())}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(vitrinePubliqueDataProvider(widget.slug));

    return Scaffold(
      backgroundColor: Colors.white,
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storefront_outlined, size: 54, color: Color(0xFF94A3B8)),
                const SizedBox(height: 14),
                const Text('Vitrine introuvable ou indisponible', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 6),
                Text('$err', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        data: (data) => _buildVitrineComplete(data),
      ),
      bottomNavigationBar: _totalArticlesPanier > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -2)),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.shopping_bag_rounded, color: Color(0xFF15803D)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$_totalArticlesPanier article(s) dans le panier', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          const Text('Prêt à commander par WhatsApp', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Commander (WhatsApp)'),
                      onPressed: () {
                        final v = asyncData.value?.vitrine;
                        final p = asyncData.value?.produits ?? [];
                        if (v != null) _commanderWhatsAppPanier(vitrine: v, produits: p);
                      },
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildVitrineComplete(VitrinePubliqueData data) {
    final vitrine = data.vitrine;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;

    // Aiguillage selon le modèle visuel ou le domaine
    if (vitrine.modeleVisuel == ModeleVitrine.modeleF || vitrine.typeActivite.domaine == DomaineActivite.immobilier) {
      return _buildModeleHavenlyImmobilier(data, isDesktop, width);
    } else if (vitrine.modeleVisuel == ModeleVitrine.modeleC || vitrine.typeActivite == TypeActivite.salonCoiffure) {
      return _buildModeleLuxeStudioCoiffure(data, isDesktop, width);
    } else if (vitrine.modeleVisuel == ModeleVitrine.modeleB || vitrine.typeActivite == TypeActivite.boutiqueTech) {
      return _buildModeleGizmoHubTech(data, isDesktop, width);
    } else if (vitrine.modeleVisuel == ModeleVitrine.modeleD || vitrine.typeActivite == TypeActivite.cosmetiqueBeaute) {
      return _buildModeleHollisCosmetique(data, isDesktop, width);
    }

    // Par défaut : Modèle A (TechVerse / Commerce Général)
    return _buildModeleTechVerseCommerce(data, isDesktop, width);
  }

  // ===========================================================================
  // MODÈLE F : HAVENLY (IMMOBILIER — VILLAS, APPARTEMENTS, VISITES)
  // ===========================================================================

  Widget _buildModeleHavenlyImmobilier(VitrinePubliqueData data, bool isDesktop, double width) {
    final vitrine = data.vitrine;
    final style = vitrine.themeStyle;
    final biens = data.biens;

    // Filtrage des biens
    final biensFiltres = biens.where((b) {
      if (_filtreTypeBien != null && _filtreTypeBien!.isNotEmpty) {
        if (b.typeBien.toUpperCase() != _filtreTypeBien!.toUpperCase()) return false;
      }
      if (_filtreOffreBien != null && _filtreOffreBien!.isNotEmpty) {
        if (b.typeOffre.toUpperCase() != _filtreOffreBien!.toUpperCase()) return false;
      }
      if (_recherche.isNotEmpty) {
        final query = _recherche.toLowerCase();
        final match = b.titre.toLowerCase().contains(query) ||
            (b.ville ?? '').toLowerCase().contains(query) ||
            (b.quartier ?? '').toLowerCase().contains(query) ||
            (b.description ?? '').toLowerCase().contains(query);
        if (!match) return false;
      }
      return true;
    }).toList();

    final bool aFiltre = _recherche.isNotEmpty || _filtreTypeBien != null || _filtreOffreBien != null;
    final List<VitrineBienImmobilier> biensAffiches = (biens.isNotEmpty || aFiltre)
        ? biensFiltres
        : _obtenirBiensModelesParDefaut(vitrine);

    return Container(
      color: style.fond,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barre d'annonce
            _buildBarreAnnonce('🏛️ AGENCE IMMOBILIÈRE AGRÉÉE • Vente & Location • Visites accompagnées 7j/7', style),

            // Navigation bar Havenly
            _buildNavBar(vitrine, style, isDesktop),

            // Grand Hero Banner Havenly : "Discover Your Perfect Home"
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 20, vertical: isDesktop ? 80 : 40),
              decoration: BoxDecoration(
                color: style.secondaire.withValues(alpha: 0.3),
                image: vitrine.banniereUrl != null && vitrine.banniereUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(MediaHybridResolver.resolvePublicUrl(vitrine.banniereUrl!)),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.5), BlendMode.darken),
                      )
                    : null,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'TROUVEZ VOTRE BIEN IDÉAL',
                          style: TextStyle(color: style.primaire, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        vitrine.titreHero ?? 'Discover Your Perfect Home',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isDesktop ? 44 : 30,
                          fontWeight: FontWeight.w900,
                          color: vitrine.banniereUrl != null ? Colors.white : style.texte,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        vitrine.slogan ?? 'Propriétés d\'exception, emplacements de premier choix.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: vitrine.banniereUrl != null ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Barre de recherche intégrée type Havenly
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.center,
                          children: [
                            SizedBox(
                              width: isDesktop ? 220 : double.infinity,
                              child: TextField(
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                                  hintText: 'Ville, quartier...',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                onChanged: (v) => setState(() => _recherche = v),
                              ),
                            ),
                            if (isDesktop) Container(width: 1, height: 30, color: const Color(0xFFE2E8F0)),
                            DropdownButton<String>(
                              value: _filtreTypeBien,
                              hint: const Text('Type de bien'),
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: null, child: Text('Tous les types')),
                                DropdownMenuItem(value: 'VILLA', child: Text('Villas & Maisons')),
                                DropdownMenuItem(value: 'APPARTEMENT', child: Text('Appartements')),
                                DropdownMenuItem(value: 'TERRAIN', child: Text('Terrains & Parcelles')),
                                DropdownMenuItem(value: 'MAGASIN', child: Text('Magasins & Bureaux')),
                              ],
                              onChanged: (val) => setState(() => _filtreTypeBien = val),
                            ),
                            if (isDesktop) Container(width: 1, height: 30, color: const Color(0xFFE2E8F0)),
                            DropdownButton<String>(
                              value: _filtreOffreBien,
                              hint: const Text('Offre'),
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: null, child: Text('Location & Vente')),
                                DropdownMenuItem(value: 'LOCATION', child: Text('À Louer')),
                                DropdownMenuItem(value: 'VENTE', child: Text('À Vendre')),
                              ],
                              onChanged: (val) => setState(() => _filtreOffreBien = val),
                            ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: style.primaire,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.search_rounded, size: 18),
                              label: const Text('Rechercher'),
                              onPressed: () => _scrollTo(_keyBiens),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bande d'engagements Havenly
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              color: Colors.white,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildEngagementItem(Icons.verified_user_outlined, 'Agence Agréée', 'Transactions sécurisées', style),
                      _buildEngagementItem(Icons.home_outlined, 'Biens Vérifiés', 'Visites accompagnées', style),
                      _buildEngagementItem(Icons.support_agent_outlined, 'Support 7j/7', 'Conseils personnalisés', style),
                    ],
                  ),
                ),
              ),
            ),

            // Section Audio de présentation si disponible
            if (vitrine.audioPresentationUrl != null && vitrine.audioPresentationUrl!.isNotEmpty)
              _buildAudioPresentation(vitrine, style),

            // Section Biens Disponibles (Featured Properties)
            Container(
              key: _keyBiens,
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 20, vertical: 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('NOS BIENS IMMOBILIERS', style: TextStyle(color: style.primaire, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                              const SizedBox(height: 4),
                              Text('Biens d\'exception disponibles', style: TextStyle(fontSize: isDesktop ? 28 : 22, fontWeight: FontWeight.w900, color: style.texte)),
                            ],
                          ),
                          Text('${biensAffiches.length} bien(s)', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      if (biensAffiches.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(40),
                          width: double.infinity,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                          child: const Center(
                            child: Column(
                              children: [
                                Icon(Icons.home_work_outlined, size: 48, color: Color(0xFF94A3B8)),
                                SizedBox(height: 12),
                                Text('Aucun bien ne correspond aux critères', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              ],
                            ),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isDesktop ? 3 : (width > 600 ? 2 : 1),
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 20,
                            childAspectRatio: 0.78,
                          ),
                          itemCount: biensAffiches.length,
                          itemBuilder: (ctx, i) => _buildCarteBienImmobilier(biensAffiches[i], vitrine, style),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Avis clients
            _buildSectionAvisClients(style, isDesktop),

            // Section Galerie photos de l'agence
            if (vitrine.sections.galerie && data.galerie.isNotEmpty)
              _buildSectionGalerie(data.galerie, style, key: _keyGalerie),

            // Section Équipe de l'agence
            if (vitrine.sections.equipe && data.equipe.isNotEmpty)
              _buildSectionEquipe(data.equipe, style),

            // Section Contact & Horaires
            _buildSectionContact(vitrine, style, key: _keyContact),

            // Footer
            _buildFooter(vitrine, style),
          ],
        ),
      ),
    );
  }

  Widget _buildCarteBienImmobilier(VitrineBienImmobilier bien, VitrineConfig vitrine, ThemeStyle style) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image du bien avec badges
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (bien.premierePhoto.isNotEmpty)
                  Image.network(
                    MediaHybridResolver.resolvePublicUrl(bien.premierePhoto),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFFF1F5F9),
                      child: const Icon(Icons.home_rounded, size: 48, color: Color(0xFF94A3B8)),
                    ),
                  )
                else
                  Container(
                    color: const Color(0xFFF1F5F9),
                    child: const Icon(Icons.home_work_rounded, size: 48, color: Color(0xFF94A3B8)),
                  ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: bien.typeOffre == 'LOCATION' ? const Color(0xFF1E7E4E) : const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      bien.typeOffre == 'LOCATION' ? 'À LOUER' : 'À VENDRE',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      bien.typeBien,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Détails
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bien.prixFormate,
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: style.primaire),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bien.titre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      if (bien.ville != null || bien.quartier != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                [bien.quartier, bien.ville].whereType<String>().join(', '),
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),

                  // Caractéristiques : Chambres, SDB, Surface
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFF1F5F9)), bottom: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        if (bien.nbChambres != null)
                          Row(children: [
                            const Icon(Icons.bed_outlined, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text('${bien.nbChambres} Ch.', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          ]),
                        if (bien.nbSallesDeBain != null)
                          Row(children: [
                            const Icon(Icons.bathtub_outlined, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text('${bien.nbSallesDeBain} SDB', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          ]),
                        if (bien.surfaceM2 != null)
                          Row(children: [
                            const Icon(Icons.square_foot_rounded, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text('${bien.surfaceM2!.toInt()} m²', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          ]),
                      ],
                    ),
                  ),

                  // Bouton Demander une visite
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: style.primaire,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.calendar_today_rounded, size: 14),
                      label: const Text('Demander une visite', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      onPressed: () => _ouvrirDialogueDemandeVisite(context, bien, vitrine),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MODÈLE C : THE LUXE STUDIO (SALON DE COIFFURE, RAW HAIR & SOINS VIP)
  // ===========================================================================

  Widget _buildModeleLuxeStudioCoiffure(VitrinePubliqueData data, bool isDesktop, double width) {
    final vitrine = data.vitrine;
    final style = vitrine.themeStyle; // Typiquement Noir & Or ou Beige & Blanc

    return Container(
      color: style.fond,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barre VIP en haut
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: style.primaire,
              child: const Center(
                child: Text(
                  '✨ Salon de Coiffure VIP • Coiffure Mixte • Raw Hair & Wigs • Prestations sur Rendez-vous',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // Navigation bar Luxe
            _buildNavBar(vitrine, style, isDesktop),

            // Hero Banner The LUXE Studio
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 20, vertical: isDesktop ? 90 : 50),
              decoration: BoxDecoration(
                color: style.secondaire.withValues(alpha: 0.4),
                image: vitrine.banniereUrl != null && vitrine.banniereUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(MediaHybridResolver.resolvePublicUrl(vitrine.banniereUrl!)),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.6), BlendMode.darken),
                      )
                    : null,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: style.primaire.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: style.primaire),
                        ),
                        child: Text(
                          'WHERE STYLE MEETS PERFECTION',
                          style: TextStyle(color: vitrine.banniereUrl != null ? Colors.white : style.primaire, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        vitrine.titreHero ?? 'THE LUXE STUDIO',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isDesktop ? 46 : 32,
                          fontWeight: FontWeight.w900,
                          color: vitrine.banniereUrl != null ? Colors.white : style.texte,
                          letterSpacing: 2,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        vitrine.slogan ?? 'Sublimez votre beauté avec des coiffures uniques et un savoir-faire d\'exception.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: vitrine.banniereUrl != null ? Colors.white.withValues(alpha: 0.9) : style.texte.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Wrap(
                        spacing: 14,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: style.primaire,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.calendar_today_rounded, size: 16),
                            label: const Text('Prendre rendez-vous', style: TextStyle(fontWeight: FontWeight.w900)),
                            onPressed: () => _scrollTo(_keyRdv),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: vitrine.banniereUrl != null ? Colors.white : style.texte,
                              side: BorderSide(color: style.primaire, width: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.content_cut_rounded, size: 16),
                            label: const Text('Nos Prestations & Tarifs', style: TextStyle(fontWeight: FontWeight.w900)),
                            onPressed: () => _scrollTo(_keyPrestations),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bandeau de réassurance
            _buildBandeauReassurance(style, isDesktop),

            // Catégories salon
            _buildBarreCategories(style, isDesktop),

            // Message audio du salon
            if (vitrine.audioPresentationUrl != null && vitrine.audioPresentationUrl!.isNotEmpty)
              _buildAudioPresentation(vitrine, style),

            // Section Prestations & Tarifs (Tresses, Nattes, Braids, Coupes, Soins)
            _buildSectionPrestations(data.prestations, vitrine, style, key: _keyPrestations),

            // Bannière Promo Salon
            _buildBannierePromotionnelle(vitrine, style, isDesktop),

            // Section Rendez-vous intégrée
            if (vitrine.sections.rdv)
              _buildSectionRendezVous(vitrine, data.prestations, style, key: _keyRdv),

            // Avis clients
            _buildSectionAvisClients(style, isDesktop),

            // Section Galerie de Réalisations & Avant/Après
            if (vitrine.sections.galerie && data.galerie.isNotEmpty)
              _buildSectionGalerie(data.galerie, style, key: _keyGalerie),

            // Section Wigs & Produits capillaires si activée
            if (vitrine.sections.produits)
              _buildSectionProduits(data.produits, vitrine, style, key: _keyProduits),

            // Équipe coiffeurs
            if (vitrine.sections.equipe && data.equipe.isNotEmpty)
              _buildSectionEquipe(data.equipe, style),

            // Contact & Horaires
            _buildSectionContact(vitrine, style, key: _keyContact),

            // Footer Luxe
            _buildFooter(vitrine, style),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // MODÈLE B : GIZMOHUB & TECHNEST (HIGH-TECH, SMARTPHONES, SOMBRE)
  // ===========================================================================

  Widget _buildModeleGizmoHubTech(VitrinePubliqueData data, bool isDesktop, double width) {
    final vitrine = data.vitrine;
    final style = vitrine.themeStyle; // Sombre & Bleu électrique

    return Container(
      color: const Color(0xFF0A0E1A),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Barre d'annonce Tech
            _buildBarreAnnonce('⚡ VENTE FLASH HIGH-TECH : Accessoires & Nouveautés en stock • Expédition express 24h', style),

            // 2. Navbar Dark
            _buildNavBar(vitrine, style, isDesktop),

            // 3. Hero GizmoHub avec visuel haute qualité
            _buildHeroSection(vitrine, style, isDesktop),

            // 4. Bandeau de réassurance
            _buildBandeauReassurance(style, isDesktop),

            // 5. Catégories High-Tech
            _buildBarreCategories(style, isDesktop),

            // 6. Audio vocal de présentation si disponible
            if (vitrine.audioPresentationUrl != null && vitrine.audioPresentationUrl!.isNotEmpty)
              _buildAudioPresentation(vitrine, style),

            // 7. Produits Tech en vitrine (avec starters pro si vide)
            _buildSectionProduits(data.produits, vitrine, style, key: _keyProduits),

            // 8. Bannière promotionnelle
            _buildBannierePromotionnelle(vitrine, style, isDesktop),

            // 9. Avis clients
            _buildSectionAvisClients(style, isDesktop),

            // 10. À propos
            _buildSectionAPropos(vitrine, style),

            // 11. Contact & Horaires
            _buildSectionContact(vitrine, style, key: _keyContact),

            // 12. Footer
            _buildFooter(vitrine, style),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // MODÈLE D : HOLLIS BODY CARE (COSMÉTIQUES, SOINS, CRÈMES & NUDE)
  // ===========================================================================

  Widget _buildModeleHollisCosmetique(VitrinePubliqueData data, bool isDesktop, double width) {
    final vitrine = data.vitrine;
    final style = vitrine.themeStyle; // Crème & Nude épuré

    return Container(
      color: const Color(0xFFFBF8F5),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Barre d'annonce Beauté
            _buildBarreAnnonce('🌿 SOINS NATURELS & INGRÉDIENTS PURS • Livraison offerte dès 25 000 FCFA', style),

            // 2. Navbar Hollis
            _buildNavBar(vitrine, style, isDesktop),

            // 3. Hero Beauté
            _buildHeroSection(vitrine, style, isDesktop),

            // 4. Réassurance
            _buildBandeauReassurance(style, isDesktop),

            // 5. Catégories Beauté
            _buildBarreCategories(style, isDesktop),

            // 6. Audio vocal si disponible
            if (vitrine.audioPresentationUrl != null && vitrine.audioPresentationUrl!.isNotEmpty)
              _buildAudioPresentation(vitrine, style),

            // 7. Grille des soins et produits
            _buildSectionProduits(data.produits, vitrine, style, key: _keyProduits),

            // 8. Bannière Promo
            _buildBannierePromotionnelle(vitrine, style, isDesktop),

            // 9. Avis Clients
            _buildSectionAvisClients(style, isDesktop),

            // 10. À propos
            _buildSectionAPropos(vitrine, style),

            // 11. Contact
            _buildSectionContact(vitrine, style, key: _keyContact),

            // 12. Footer
            _buildFooter(vitrine, style),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // MODÈLE A : TECHVERSE (COMMERCE GÉNÉRAL, PROMOTIONS & POPULAIRES)
  // ===========================================================================

  Widget _buildModeleTechVerseCommerce(VitrinePubliqueData data, bool isDesktop, double width) {
    final vitrine = data.vitrine;
    final style = vitrine.themeStyle;

    return Container(
      color: style.fond,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Barre d'annonce
            _buildBarreAnnonce('📦 LIVRAISON RAPIDE PARTOUT • PAIEMENT SÉCURISÉ & CASH À LA LIVRAISON • SERVICE CLIENT WHATSAPP 7J/7', style),

            // 2. Barre de navigation
            _buildNavBar(vitrine, style, isDesktop),

            // 3. Bannière Hero TechVerse plein écran
            _buildHeroSection(vitrine, style, isDesktop),

            // 4. Bandeau de réassurance (4 piliers)
            _buildBandeauReassurance(style, isDesktop),

            // 5. Catégories interactives
            _buildBarreCategories(style, isDesktop),

            // 6. Audio vocal de présentation si disponible
            if (vitrine.audioPresentationUrl != null && vitrine.audioPresentationUrl!.isNotEmpty)
              _buildAudioPresentation(vitrine, style),

            // 7. Section Principale : Produits en vitrine (avec starters démo pro si vide)
            _buildSectionProduits(data.produits, vitrine, style, key: _keyProduits),

            // 8. Bannière promotionnelle exclusive
            _buildBannierePromotionnelle(vitrine, style, isDesktop),

            // 9. Avis & Témoignages clients vérifiés (5 étoiles)
            _buildSectionAvisClients(style, isDesktop),

            // 10. Section À propos
            _buildSectionAPropos(vitrine, style),

            // 11. Galerie photos
            if (vitrine.sections.galerie && data.galerie.isNotEmpty)
              _buildSectionGalerie(data.galerie, style, key: _keyGalerie),

            // 12. Contact & Horaires & WhatsApp
            _buildSectionContact(vitrine, style, key: _keyContact),

            // 13. Footer complet multi-colonnes
            _buildFooter(vitrine, style),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // COMPOSANTS COMMUNS RÉUTILISABLES & HAUTE FIDÉLITÉ
  // ===========================================================================

  Widget _buildBarreAnnonce(String texte, ThemeStyle style) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: style.primaire,
      child: Center(
        child: Text(
          texte,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.3),
        ),
      ),
    );
  }

  Widget _buildBandeauReassurance(ThemeStyle style, bool isDesktop) {
    final items = [
      (Icons.local_shipping_outlined, 'Livraison Rapide', 'À domicile & points relais'),
      (Icons.security_outlined, 'Paiement Sécurisé', 'À la livraison, OM, Wave, Cash'),
      (Icons.published_with_changes_rounded, 'Retours Faciles', 'Échange garanti sous 48h'),
      (Icons.headset_mic_outlined, 'Service Client 24/7', 'Assistance WhatsApp directe'),
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: style.secondaire.withValues(alpha: 0.15))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Wrap(
            spacing: 24,
            runSpacing: 16,
            alignment: WrapAlignment.spaceAround,
            children: [
              for (final it in items)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: style.primaire.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(it.$1, color: style.primaire, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.$2, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: style.texte)),
                        Text(it.$3, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarreCategories(ThemeStyle style, bool isDesktop) {
    final categories = [
      ('🎧 Audio & Casques', Icons.headphones_rounded),
      ('⌚ Montres Connectées', Icons.watch_rounded),
      ('⚡ Énergie & Chargeurs', Icons.bolt_rounded),
      ('📱 Accessoires & Coques', Icons.phone_android_rounded),
      ('🎒 Sacs & Mode', Icons.shopping_bag_rounded),
      ('🔥 Nouveautés', Icons.local_fire_department_rounded),
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 16, vertical: 16),
      color: style.fond,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final cat in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _scrollTo(_keyProduits),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: style.secondaire.withValues(alpha: 0.2)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(cat.$1, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: style.texte)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBannierePromotionnelle(VitrineConfig vitrine, ThemeStyle style, bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 16, vertical: 30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Container(
            padding: EdgeInsets.all(isDesktop ? 36 : 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [style.primaire, style.secondaire],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: style.primaire.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'OFFRE SPÉCIALE DU MOIS',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Boostez votre style & équipement',
                        style: TextStyle(fontSize: isDesktop ? 26 : 20, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Commandez directement sur WhatsApp et profitez d\'un cadeau surprise ou d\'une réduction immédiate !',
                        style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: style.primaire,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                        label: const Text('Commander sur WhatsApp', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                        onPressed: () {
                          final clean = vitrine.whatsappContact.replaceAll(RegExp(r'[^0-9]'), '');
                          final uri = Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent("Bonjour ! Je souhaite profiter de votre offre spéciale sur votre vitrine.")}');
                          launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                      ),
                    ],
                  ),
                ),
                if (isDesktop) ...[
                  const SizedBox(width: 24),
                  const Icon(Icons.stars_rounded, color: Colors.white24, size: 120),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionAvisClients(ThemeStyle style, bool isDesktop) {
    final avis = [
      (
        'Produits 100% conformes à la description, livraison très rapide à Bamako ACI 2000. Je recommande vivement !',
        'Aminata D.',
        'Bamako ACI 2000',
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&q=80',
      ),
      (
        'Service client au top sur WhatsApp. Réponse en 5 minutes et commande livrée le jour même.',
        'Ibrahim K.',
        'Hamdallaye',
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&q=80',
      ),
      (
        'Très satisfaite de la qualité. Paiement sécurisé à la livraison sans aucun souci. Merci DubaGest !',
        'Fatou S.',
        'Sotuba',
        'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=150&q=80',
      ),
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 16, vertical: 36),
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AVIS & TÉMOIGNAGES', style: TextStyle(color: style.primaire, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 6),
              Text('Ce que disent nos clients satisfaits', style: TextStyle(fontSize: isDesktop ? 26 : 22, fontWeight: FontWeight.w900, color: style.texte)),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final a in avis)
                        Container(
                          width: isDesktop ? 340 : double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  for (int i = 0; i < 5; i++)
                                    const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 18),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '"${a.$1}"',
                                style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF334155), fontStyle: FontStyle.italic),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundImage: NetworkImage(a.$4),
                                    backgroundColor: const Color(0xFFE2E8F0),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(a.$2, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A))),
                                      Text(a.$3, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEngagementItem(IconData icon, String titre, String sousTitre, ThemeStyle style) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: style.secondaire.withValues(alpha: 0.2), shape: BoxShape.circle),
          child: Icon(icon, color: style.primaire, size: 20),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            Text(sousTitre, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _buildNavBar(VitrineConfig vitrine, ThemeStyle style, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: style.fond,
        border: Border(bottom: BorderSide(color: style.secondaire.withValues(alpha: 0.15))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Row(
            children: [
              if (vitrine.logoUrl != null && vitrine.logoUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    MediaHybridResolver.resolvePublicUrl(vitrine.logoUrl!),
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.storefront_rounded),
                  ),
                )
              else
                Icon(Icons.storefront_rounded, color: style.primaire, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  vitrine.titreHero ?? 'DubaGest',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: style.texte),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isDesktop) ...[
                if (vitrine.sections.biens)
                  TextButton(onPressed: () => _scrollTo(_keyBiens), child: Text('Biens', style: TextStyle(color: style.texte, fontWeight: FontWeight.w700))),
                if (vitrine.sections.prestations)
                  TextButton(onPressed: () => _scrollTo(_keyPrestations), child: Text('Prestations', style: TextStyle(color: style.texte, fontWeight: FontWeight.w700))),
                if (vitrine.sections.galerie)
                  TextButton(onPressed: () => _scrollTo(_keyGalerie), child: Text('Réalisations', style: TextStyle(color: style.texte, fontWeight: FontWeight.w700))),
                if (vitrine.sections.produits)
                  TextButton(onPressed: () => _scrollTo(_keyProduits), child: Text('Catalogue', style: TextStyle(color: style.texte, fontWeight: FontWeight.w700))),
                TextButton(onPressed: () => _scrollTo(_keyContact), child: Text('Contact', style: TextStyle(color: style.texte, fontWeight: FontWeight.w700))),
              ],
              if (vitrine.sections.rdv) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: style.primaire, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                  icon: const Icon(Icons.calendar_today_rounded, size: 14),
                  label: const Text('Rendez-vous', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  onPressed: () => _scrollTo(_keyRdv),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(VitrineConfig vitrine, ThemeStyle style, bool isDesktop) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280),
      decoration: BoxDecoration(
        color: style.fond,
        image: vitrine.banniereUrl != null && vitrine.banniereUrl!.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(MediaHybridResolver.resolvePublicUrl(vitrine.banniereUrl!)),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.55), BlendMode.darken),
              )
            : null,
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: style.primaire.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: style.primaire.withValues(alpha: 0.5)),
                ),
                child: Text(
                  vitrine.typeActivite.libelle.toUpperCase(),
                  style: TextStyle(color: vitrine.banniereUrl != null ? Colors.white : style.primaire, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                vitrine.titreHero ?? 'Bienvenue',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isDesktop ? 36 : 28,
                  fontWeight: FontWeight.w900,
                  color: vitrine.banniereUrl != null ? Colors.white : style.texte,
                  height: 1.2,
                ),
              ),
              if (vitrine.slogan != null && vitrine.slogan!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  vitrine.slogan!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: vitrine.banniereUrl != null ? Colors.white.withValues(alpha: 0.9) : style.texte.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: style.primaire,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                    label: const Text('Commander nos produits', style: TextStyle(fontWeight: FontWeight.w800)),
                    onPressed: () => _scrollTo(_keyProduits),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioPresentation(VitrineConfig vitrine, ThemeStyle style) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: style.secondaire.withValues(alpha: 0.2),
      child: Center(
        child: VocalPlayerBadge(
          audioUrl: vitrine.audioPresentationUrl!,
        ),
      ),
    );
  }

  Widget _buildSectionAPropos(VitrineConfig vitrine, ThemeStyle style) {
    final nom = vitrine.titreHero ?? 'notre établissement';
    final descOriginale = vitrine.description?.trim();
    final estTexteGenerique = descOriginale == null ||
        descOriginale.isEmpty ||
        descOriginale.contains("Découvrez nos prestations") ||
        descOriginale.contains("d'exception");

    final descAffichee = estTexteGenerique
        ? 'Bienvenue sur la boutique officielle de $nom. Nous sélectionnons avec passion des articles et prestations d\'excellence, alliant authenticité, modernité et finitions soignées. Notre engagement : un accompagnement sur mesure, une transparence totale sur les tarifs et une disponibilité permanente via WhatsApp.'
        : descOriginale;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('À PROPOS DE NOUS', style: TextStyle(color: style.primaire, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Text(
                'L\'excellence et la satisfaction client au cœur de nos engagements',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: style.texte),
              ),
              const SizedBox(height: 12),
              Text(
                descAffichee,
                style: TextStyle(fontSize: 15, height: 1.7, color: style.texte.withValues(alpha: 0.85)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<VitrinePrestation> _obtenirPrestationsModelesParDefaut(VitrineConfig vitrine) {
    return const [
      VitrinePrestation(
        id: 'starter_p1',
        vitrineId: '',
        entrepriseId: '',
        nom: 'Tresses Américaines & Knotless Braids',
        description: 'Tressage soigné sans tension sur le cuir chevelu, mèches fournies ou apportées.',
        prix: 15000,
        prixBarre: 20000,
        dureeMinutes: 120,
        categorie: 'Tresses',
        photoUrl: 'https://images.unsplash.com/photo-1560066984-138dadb4c035?w=500&q=80',
      ),
      VitrinePrestation(
        id: 'starter_p2',
        vitrineId: '',
        entrepriseId: '',
        nom: 'Pose Perruque Lace Front & Customisation',
        description: 'Blanchiment des nœuds, collage HD invisible et coiffage personnalisé.',
        prix: 20000,
        prixBarre: 28000,
        dureeMinutes: 90,
        categorie: 'Wigs',
        photoUrl: 'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=500&q=80',
      ),
      VitrinePrestation(
        id: 'starter_p3',
        vitrineId: '',
        entrepriseId: '',
        nom: 'Soin Capillaire Profond & Brushing',
        description: 'Hydratation intense aux huiles naturelles, massage crânien et brushing soyeux.',
        prix: 10000,
        dureeMinutes: 60,
        categorie: 'Soins',
        photoUrl: 'https://images.unsplash.com/photo-1519699047748-de8e457a634e?w=500&q=80',
      ),
      VitrinePrestation(
        id: 'starter_p4',
        vitrineId: '',
        entrepriseId: '',
        nom: 'Coloration & Balayage Lumineux',
        description: 'Teinte sur-mesure respectant la fibre capillaire, reflets éclatants.',
        prix: 25000,
        prixBarre: 32000,
        dureeMinutes: 150,
        categorie: 'Coloration',
        photoUrl: 'https://images.unsplash.com/photo-1580618672591-eb180b1a973f?w=500&q=80',
      ),
    ];
  }

  Widget _buildSectionPrestations(List<VitrinePrestation> prestations, VitrineConfig vitrine, ThemeStyle style, {Key? key}) {
    final listeAffichee = prestations.isNotEmpty ? prestations : _obtenirPrestationsModelesParDefaut(vitrine);

    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NOS PRESTATIONS & TARIFS', style: TextStyle(color: style.primaire, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 6),
              Text('Découvrez notre savoir-faire d\'exception', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: style.texte)),
              const SizedBox(height: 20),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: listeAffichee.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final p = listeAffichee[i];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: style.secondaire.withValues(alpha: 0.15)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      children: [
                        if (p.photoUrl != null && p.photoUrl!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              MediaHybridResolver.resolvePublicUrl(p.photoUrl!),
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(Icons.content_cut_rounded),
                            ),
                          )
                        else
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(color: style.secondaire.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                            child: Icon(Icons.content_cut_rounded, color: style.primaire),
                          ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.nom, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                              if (p.description != null && p.description!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(p.description!, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ],
                              if (p.dureeFormatee != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 4),
                                    Text(p.dureeFormatee!, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(p.prixFormate, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: style.primaire)),
                            if (p.prixBarre != null)
                              Text('${p.prixBarre} F', style: const TextStyle(decoration: TextDecoration.lineThrough, color: Color(0xFF94A3B8), fontSize: 11)),
                            const SizedBox(height: 6),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: style.primaire, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                              child: const Text('Choisir', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                              onPressed: () => _scrollTo(_keyRdv),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionRendezVous(VitrineConfig vitrine, List<VitrinePrestation> prestations, ThemeStyle style, {Key? key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      color: style.secondaire.withValues(alpha: 0.1),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: _FormulaireRendezVousPublic(vitrine: vitrine, prestations: prestations, style: style),
        ),
      ),
    );
  }

  Widget _buildSectionGalerie(List<VitrineGalerieItem> galerie, ThemeStyle style, {Key? key}) {
    final galerieAffichee = galerie.isNotEmpty
        ? galerie
        : const [
            VitrineGalerieItem(
              id: 'starter_gal_1',
              vitrineId: '',
              entrepriseId: '',
              photoUrl: 'https://images.unsplash.com/photo-1560066984-138dadb4c035?w=600&q=80',
              titre: 'Tresses Artistiques & Knotless',
            ),
            VitrineGalerieItem(
              id: 'starter_gal_2',
              vitrineId: '',
              entrepriseId: '',
              photoUrl: 'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=600&q=80',
              titre: 'Customisation Lace Front HD',
            ),
            VitrineGalerieItem(
              id: 'starter_gal_3',
              vitrineId: '',
              entrepriseId: '',
              photoUrl: 'https://images.unsplash.com/photo-1519699047748-de8e457a634e?w=600&q=80',
              titre: 'Soin & Brushing Soyeux',
            ),
            VitrineGalerieItem(
              id: 'starter_gal_4',
              vitrineId: '',
              entrepriseId: '',
              photoUrl: 'https://images.unsplash.com/photo-1580618672591-eb180b1a973f?w=600&q=80',
              titre: 'Coloration Tendance & Balayage',
            ),
          ];

    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GALERIE & RÉALISATIONS', style: TextStyle(color: style.primaire, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 6),
              Text('Nos plus belles réalisations', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: style.texte)),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: galerieAffichee.length,
                itemBuilder: (ctx, i) {
                  final item = galerieAffichee[i];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          MediaHybridResolver.resolvePublicUrl(item.photoUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(color: const Color(0xFFF1F5F9)),
                        ),
                        if (item.titre != null && item.titre!.isNotEmpty)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              color: Colors.black.withValues(alpha: 0.6),
                              child: Text(
                                item.titre!,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionEquipe(List<VitrineMembreEquipe> equipe, ThemeStyle style) {
    final equipeAffichee = equipe.isNotEmpty
        ? equipe
        : const [
            VitrineMembreEquipe(
              id: 'starter_eq_1',
              vitrineId: '',
              entrepriseId: '',
              nom: 'Aminata Diallo',
              roleSpecialite: 'Coiffeuse Visagiste & Coloriste',
              photoUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=300&q=80',
            ),
            VitrineMembreEquipe(
              id: 'starter_eq_2',
              vitrineId: '',
              entrepriseId: '',
              nom: 'Fatou Traoré',
              roleSpecialite: 'Spécialiste Braids & Wigs',
              photoUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&q=80',
            ),
          ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NOTRE ÉQUIPE D\'EXPERTS', style: TextStyle(color: style.primaire, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 6),
              Text('Des professionnels à votre écoute', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: style.texte)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final m in equipeAffichee)
                    Container(
                      width: 200,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: style.secondaire.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundImage: m.photoUrl != null && m.photoUrl!.isNotEmpty
                                ? NetworkImage(MediaHybridResolver.resolvePublicUrl(m.photoUrl!))
                                : null,
                            child: m.photoUrl == null || m.photoUrl!.isEmpty ? const Icon(Icons.person_rounded, size: 36) : null,
                          ),
                          const SizedBox(height: 10),
                          Text(m.nom, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15), textAlign: TextAlign.center),
                          if (m.roleSpecialite != null) ...[
                            const SizedBox(height: 2),
                            Text(m.roleSpecialite!, style: TextStyle(color: style.primaire, fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<VitrineBienImmobilier> _obtenirBiensModelesParDefaut(VitrineConfig vitrine) {
    return [
      VitrineBienImmobilier(
        id: 'starter_bien_1',
        vitrineId: vitrine.id,
        entrepriseId: vitrine.entrepriseId,
        titre: 'Villa Duplex Contemporaine F5 avec Piscine',
        typeBien: 'VILLA',
        typeOffre: 'LOCATION',
        prix: 650000,
        ville: vitrine.ville ?? 'Bamako',
        quartier: 'ACI 2000',
        nbChambres: 4,
        nbSallesDeBain: 3,
        surfaceM2: 320,
        description: 'Superbe villa moderne climatisée, finitions haut de gamme, piscine privée, groupe électrogène et sécurité 24h/24.',
        photos: const ['https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=700&q=80'],
      ),
      VitrineBienImmobilier(
        id: 'starter_bien_2',
        vitrineId: vitrine.id,
        entrepriseId: vitrine.entrepriseId,
        titre: 'Appartement F4 Standing Vue Panoramique',
        typeBien: 'APPARTEMENT',
        typeOffre: 'LOCATION',
        prix: 350000,
        ville: vitrine.ville ?? 'Bamako',
        quartier: 'Hamdallaye ACI',
        nbChambres: 3,
        nbSallesDeBain: 2,
        surfaceM2: 160,
        description: 'Appartement lumineux avec ascenseur, balcon filant, cuisine équipée et parking en sous-sol.',
        photos: const ['https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=700&q=80'],
      ),
      VitrineBienImmobilier(
        id: 'starter_bien_3',
        vitrineId: vitrine.id,
        entrepriseId: vitrine.entrepriseId,
        titre: 'Résidence Familiale avec Jardin Arboré',
        typeBien: 'VILLA',
        typeOffre: 'VENTE',
        prix: 120000000,
        ville: vitrine.ville ?? 'Bamako',
        quartier: 'Sotuba ACI',
        nbChambres: 5,
        nbSallesDeBain: 4,
        surfaceM2: 600,
        description: 'Propriété sécurisée titre foncier en règle, cour spacieuse pour plusieurs véhicules, quartier calme et résidentiel.',
        photos: const ['https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=700&q=80'],
      ),
    ];
  }

  List<ProduitCataloguePublic> _obtenirProduitsModelesParDefaut(VitrineConfig vitrine) {
    final isBeauty = vitrine.typeActivite == TypeActivite.cosmetiqueBeaute || vitrine.typeActivite == TypeActivite.salonCoiffure;

    if (isBeauty) {
      return const [
        ProduitCataloguePublic(
          id: 'starter_prod_1',
          nom: 'Crème Hydratante Bio Éclat Karité',
          description: 'Soin 100% naturel enrichi au beurre de karité bio pour une peau lumineuse.',
          prix: 8500,
          prixBarre: 12000,
          photos: ['https://images.unsplash.com/photo-1556228720-195a672e8a03?w=600&q=80'],
        ),
        ProduitCataloguePublic(
          id: 'starter_prod_2',
          nom: 'Sérum Nuit Réparateur Argan Pur',
          description: 'Régénère la peau pendant la nuit, hydrate intensément.',
          prix: 14000,
          prixBarre: 18000,
          photos: ['https://images.unsplash.com/photo-1620916566398-39f1143ab7be?w=600&q=80'],
        ),
        ProduitCataloguePublic(
          id: 'starter_prod_3',
          nom: 'Perruque Lace Front HD Ondulée 24"',
          description: '100% Raw Hair de qualité exceptionnelle, tulle indétectable.',
          prix: 75000,
          prixBarre: 95000,
          photos: ['https://images.unsplash.com/photo-1560066984-138dadb4c035?w=600&q=80'],
        ),
        ProduitCataloguePublic(
          id: 'starter_prod_4',
          nom: 'Shampoing Clarifiant Sans Sulfate',
          description: 'Nettoie en douceur sans agresser le cuir chevelu. Idéal après tresses.',
          prix: 6500,
          photos: ['https://images.unsplash.com/photo-1535585209827-a15fcdbc4c2d?w=600&q=80'],
        ),
        ProduitCataloguePublic(
          id: 'starter_prod_5',
          nom: 'Huile Pure de Ricin Fortifiante',
          description: 'Stimule la pousse, fortifie les racines et fait briller les cheveux.',
          prix: 5000,
          photos: ['https://images.unsplash.com/photo-1608248597359-563229b16ea9?w=600&q=80'],
        ),
        ProduitCataloguePublic(
          id: 'starter_prod_6',
          nom: 'Masque Capillaire Régénérant Intense',
          description: 'Nourrit en profondeur les pointes sèches et abîmées.',
          prix: 11000,
          photos: ['https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=600&q=80'],
        ),
      ];
    }

    // Par défaut : High-Tech & Accessoires Pro (GizmoHub / TechVerse)
    return const [
      ProduitCataloguePublic(
        id: 'starter_prod_tech_1',
        nom: 'Écouteurs Wireless ANC Pro 2',
        description: 'Réduction de bruit active, autonomie 30h, son immersif haute définition.',
        prix: 18500,
        prixBarre: 25000,
        photos: ['https://images.unsplash.com/photo-1590658268037-6bf12165a8df?w=600&q=80'],
      ),
      ProduitCataloguePublic(
        id: 'starter_prod_tech_2',
        nom: 'Smartwatch Ultra Sport Active',
        description: 'Écran AMOLED HD, suivi cardiaque, sommeil et notifications WhatsApp.',
        prix: 28000,
        prixBarre: 38000,
        photos: ['https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=600&q=80'],
      ),
      ProduitCataloguePublic(
        id: 'starter_prod_tech_3',
        nom: 'Enceinte Portable Bluetooth BoomBass',
        description: 'Waterproof IPX7, basses 360°, batterie 20h non-stop.',
        prix: 22000,
        prixBarre: 30000,
        photos: ['https://images.unsplash.com/photo-1545454675-3531b543be5d?w=600&q=80'],
      ),
      ProduitCataloguePublic(
        id: 'starter_prod_tech_4',
        nom: 'Power Bank Rapide 20 000 mAh 65W',
        description: 'Recharge express pour téléphones, iPhones et ordinateurs.',
        prix: 14500,
        prixBarre: 19000,
        photos: ['https://images.unsplash.com/photo-1609592806596-b38466632488?w=600&q=80'],
      ),
      ProduitCataloguePublic(
        id: 'starter_prod_tech_5',
        nom: 'Station de Charge 3-en-1 Sans Fil',
        description: 'Charge simultanément votre téléphone, montre et écouteurs sans fil.',
        prix: 16000,
        prixBarre: 22000,
        photos: ['https://images.unsplash.com/photo-1586953208448-b95a79798f07?w=600&q=80'],
      ),
      ProduitCataloguePublic(
        id: 'starter_prod_tech_6',
        nom: 'Drone Compact 4K Ultra HD',
        description: 'Double caméra stabilisée, retour automatique GPS, double batterie.',
        prix: 55000,
        prixBarre: 75000,
        photos: ['https://images.unsplash.com/photo-1527977966376-1c8408f9f108?w=600&q=80'],
      ),
    ];
  }

  Widget _buildSectionProduits(List<ProduitCataloguePublic> produits, VitrineConfig vitrine, ThemeStyle style, {Key? key}) {
    // Si la liste de l'entreprise est vide, injecter les produits modèles de haute qualité pour garantir zéro page vide
    final listeAffichee = produits.isNotEmpty ? produits : _obtenirProduitsModelesParDefaut(vitrine);

    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PRODUITS EN VITRINE', style: TextStyle(color: style.primaire, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 6),
              Text('Commandez directement par WhatsApp', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: style.texte)),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.72,
                ),
                itemCount: listeAffichee.length,
                itemBuilder: (ctx, i) {
                  final p = listeAffichee[i];
                  final qte = _panier[p.id] ?? 0;

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: style.secondaire.withValues(alpha: 0.15)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (p.photoPrincipale != null && p.photoPrincipale!.isNotEmpty)
                                Image.network(
                                  MediaHybridResolver.resolvePublicUrl(p.photoPrincipale!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(Icons.shopping_bag_outlined),
                                )
                              else
                                const Icon(Icons.shopping_bag_outlined, size: 48, color: Color(0xFF94A3B8)),
                              if (p.prixBarre != null)
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(6)),
                                    child: const Text('PROMO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.nom, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('${p.prix} FCFA', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: style.primaire)),
                                  if (p.prixBarre != null) ...[
                                    const SizedBox(width: 6),
                                    Text('${p.prixBarre} F', style: const TextStyle(decoration: TextDecoration.lineThrough, color: Color(0xFF94A3B8), fontSize: 11)),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (qte == 0)
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: style.primaire,
                                      side: BorderSide(color: style.primaire),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                                    label: const Text('Ajouter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                    onPressed: () => _ajouterAuPanier(p.id),
                                  ),
                                )
                              else
                                Container(
                                  decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_rounded, size: 16, color: Color(0xFF15803D)),
                                        onPressed: () => _retirerDuPanier(p.id),
                                      ),
                                      Text('$qte', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF15803D))),
                                      IconButton(
                                        icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF15803D)),
                                        onPressed: () => _ajouterAuPanier(p.id),
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
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionContact(VitrineConfig vitrine, ThemeStyle style, {Key? key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      color: style.secondaire.withValues(alpha: 0.12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('HORAIRES & CONTACT', style: TextStyle(color: style.primaire, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 6),
              Text('Nous rendre visite ou nous contacter', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: style.texte)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 24,
                runSpacing: 20,
                children: [
                  if (vitrine.adresse != null || vitrine.ville != null)
                    _buildContactItem(Icons.location_on_rounded, 'Adresse', [vitrine.adresse, vitrine.ville].whereType<String>().join(', '), style),
                  if (vitrine.telephone != null)
                    _buildContactItem(Icons.phone_rounded, 'Téléphone', vitrine.telephone!, style),
                  if (vitrine.whatsapp != null)
                    _buildContactItem(Icons.chat_bubble_rounded, 'WhatsApp', vitrine.whatsapp!, style),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String titre, String valeur, ThemeStyle style) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(backgroundColor: style.primaire, radius: 18, child: Icon(icon, color: Colors.white, size: 18)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF64748B))),
            Text(valeur, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          ],
        ),
      ],
    );
  }

  Widget _buildFooter(VitrineConfig vitrine, ThemeStyle style) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      color: const Color(0xFF0F172A),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              Wrap(
                spacing: 32,
                runSpacing: 24,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  // Colonne 1 : Entreprise & Slogan
                  SizedBox(
                    width: 260,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vitrine.titreHero ?? 'DubaGest',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          vitrine.slogan ?? 'Votre boutique de confiance avec commande directe WhatsApp.',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.5),
                        ),
                      ],
                    ),
                  ),

                  // Colonne 2 : Coordonnées
                  SizedBox(
                    width: 260,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CONTACT & HORAIRES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        if (vitrine.adresse != null || vitrine.ville != null)
                          Text('📍 ${[vitrine.adresse, vitrine.ville].whereType<String>().join(", ")}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        if (vitrine.telephone != null)
                          Text('📞 ${vitrine.telephone}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        Text('💬 WhatsApp : ${vitrine.whatsappContact}', style: const TextStyle(color: Color(0xFF25D366), fontSize: 12, fontWeight: FontWeight.w700)),
                        const Text('🕒 Ouvert Lun - Sam : 08h00 - 20h00', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      ],
                    ),
                  ),

                  // Colonne 3 : Reassurance
                  SizedBox(
                    width: 260,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PAIEMENT & LIVRAISON', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        const Text('✓ Paiement à la livraison', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        const Text('✓ Orange Money, Moov, Wave acceptés', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        const Text('✓ Expédition rapide & soignée', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const Divider(color: Color(0xFF1E293B)),
              const SizedBox(height: 16),
              Text('© ${DateTime.now().year} ${vitrine.titreHero ?? "DubaGest"}. Tous droits réservés.', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
              const SizedBox(height: 4),
              const Text('Propulsé par DubaGest V2 — Créateur de Vitrines Professionnelles', style: TextStyle(color: Color(0xFF475569), fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  void _ouvrirDialogueDemandeVisite(BuildContext context, VitrineBienImmobilier bien, VitrineConfig vitrine) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _DialogueDemandeVisite(bien: bien, vitrine: vitrine),
    );
  }
}

// =============================================================================
// FORMULAIRE PUBLIC DEMANDE DE RENDEZ-VOUS (SALON / BEAUTÉ)
// =============================================================================

class _FormulaireRendezVousPublic extends StatefulWidget {
  const _FormulaireRendezVousPublic({required this.vitrine, required this.prestations, required this.style});
  final VitrineConfig vitrine;
  final List<VitrinePrestation> prestations;
  final ThemeStyle style;

  @override
  State<_FormulaireRendezVousPublic> createState() => _FormulaireRendezVousPublicState();
}

class _FormulaireRendezVousPublicState extends State<_FormulaireRendezVousPublic> {
  final _formKey = GlobalKey<FormState>();
  String? _prestationChoisie;
  final _nomCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  String _heure = '14:00';
  bool _envoye = false;

  @override
  Widget build(BuildContext context) {
    if (_envoye) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 48, color: Color(0xFF15803D)),
            const SizedBox(height: 12),
            const Text('Demande envoyée avec succès !', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 6),
            const Text('Le salon a bien reçu votre demande et vous confirmera le créneau par WhatsApp.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PRENDRE RENDEZ-VOUS', style: TextStyle(color: widget.style.primaire, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 4),
            const Text('Réservez votre créneau en 1 minute', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 16),
            if (widget.prestations.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _prestationChoisie,
                decoration: const InputDecoration(labelText: 'Prestation souhaitée *', border: OutlineInputBorder()),
                items: [
                  for (final p in widget.prestations)
                    DropdownMenuItem(value: p.nom, child: Text('${p.nom} (${p.prixFormate})')),
                ],
                onChanged: (v) => setState(() => _prestationChoisie = v),
                validator: (v) => v == null ? 'Veuillez choisir une prestation' : null,
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nomCtrl,
              decoration: const InputDecoration(labelText: 'Votre nom complet *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Veuillez renseigner votre nom' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Numéro de téléphone WhatsApp *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().length < 5) ? 'Veuillez renseigner un numéro valide' : null,
            ),
            const SizedBox(height: 16),
            Consumer(
              builder: (ctx, ref, _) => SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.style.primaire,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Confirmer la demande de rendez-vous', style: TextStyle(fontWeight: FontWeight.w800)),
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    final rdv = VitrineRendezVous(
                      id: '',
                      vitrineId: widget.vitrine.id,
                      entrepriseId: widget.vitrine.entrepriseId,
                      nomPrestation: _prestationChoisie ?? 'Prestation générale',
                      dateSouhaitee: _date,
                      heureSouhaitee: _heure,
                      nomClient: _nomCtrl.text.trim(),
                      telephoneClient: _telCtrl.text.trim(),
                      statut: StatutRendezVous.enAttente,
                    );
                    await ref.read(vitrineRepositoryProvider).creerDemandeRendezVous(rdv);
                    setState(() => _envoye = true);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// MODAL DEMANDE DE VISITE IMMOBILIÈRE (HAVENLY)
// =============================================================================

class _DialogueDemandeVisite extends StatefulWidget {
  const _DialogueDemandeVisite({required this.bien, required this.vitrine});
  final VitrineBienImmobilier bien;
  final VitrineConfig vitrine;

  @override
  State<_DialogueDemandeVisite> createState() => _DialogueDemandeVisiteState();
}

class _DialogueDemandeVisiteState extends State<_DialogueDemandeVisite> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  String _heure = '10:00';
  bool _envoye = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: _envoye
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, size: 54, color: Color(0xFF15803D)),
                const SizedBox(height: 12),
                const Text('Demande de visite enregistrée !', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 6),
                Text('L\'agence immobilière ${widget.vitrine.titreHero ?? ""} prendra contact avec vous sur WhatsApp pour confirmer la visite.', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B))),
                const SizedBox(height: 20),
                FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
              ],
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Demander une visite', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    Text(widget.bien.titre, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                    Text(widget.bien.prixFormate, style: const TextStyle(color: Color(0xFF1E7E4E), fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nomCtrl,
                      decoration: const InputDecoration(labelText: 'Votre nom complet *', border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Veuillez renseigner votre nom' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _telCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Votre téléphone WhatsApp *', border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().length < 5) ? 'Veuillez renseigner un numéro valide' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _msgCtrl,
                      decoration: const InputDecoration(labelText: 'Message ou créneau préféré (facultatif)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    Consumer(
                      builder: (ctx, ref, _) => SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1B3B2B),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: const Text('Envoyer la demande de visite', style: TextStyle(fontWeight: FontWeight.w800)),
                          onPressed: () async {
                            if (!_formKey.currentState!.validate()) return;
                            final visite = VitrineDemandeVisite(
                              id: '',
                              vitrineId: widget.vitrine.id,
                              entrepriseId: widget.vitrine.entrepriseId,
                              bienId: widget.bien.id,
                              nomBien: widget.bien.titre,
                              nomClient: _nomCtrl.text.trim(),
                              telephoneClient: _telCtrl.text.trim(),
                              dateSouhaitee: _date,
                              heureSouhaitee: _heure,
                              messageClient: _msgCtrl.text.trim().isEmpty ? null : _msgCtrl.text.trim(),
                              statut: StatutDemandeVisite.enAttente,
                            );
                            await ref.read(vitrineRepositoryProvider).creerDemandeVisite(visite);
                            setState(() => _envoye = true);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
