import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/vitrine_config.dart';
import '../../domain/entities/vitrine_types.dart';
import '../providers/vitrine_providers.dart';
import 'vitrine_publique_page.dart';

/// Page dédiée complète pour la personnalisation de la vitrine avec UI/UX moderne
class VitrinePersonnalisationPage extends ConsumerStatefulWidget {
  const VitrinePersonnalisationPage({super.key, required this.vitrine});
  final VitrineConfig vitrine;

  @override
  ConsumerState<VitrinePersonnalisationPage> createState() => _VitrinePersonnalisationPageState();
}


class _ModeleECommerceItem {
  final ModeleVitrine modele;
  final String titre;
  final String nomCourt;
  final String secteur;
  final String description;
  final IconData icone;
  final Color couleurAccent;
  final Color couleurFond;
  final List<String> tags;
  final String titreHeroDefaut;
  final String sloganDefaut;
  final ThemeStyle styleRecommande;

  const _ModeleECommerceItem({
    required this.modele,
    required this.titre,
    required this.nomCourt,
    required this.secteur,
    required this.description,
    required this.icone,
    required this.couleurAccent,
    required this.couleurFond,
    required this.tags,
    required this.titreHeroDefaut,
    required this.sloganDefaut,
    required this.styleRecommande,
  });
}

const List<_ModeleECommerceItem> _modelesECommerceDisponibles = [
  _ModeleECommerceItem(
    modele: ModeleVitrine.modeleA,
    titre: 'Modèle 1 — MobileX & TechVerse',
    nomCourt: 'MobileX & TechVerse',
    secteur: 'Smartphones & High-Tech',
    description: 'Spécialisé smartphones, tablettes, Apple & Samsung. Bannières marques officielles, badges de réassurance et commande WhatsApp rapide.',
    icone: Icons.phone_iphone_rounded,
    couleurAccent: Color(0xFFEA580C),
    couleurFond: Color(0xFFFFF7ED),
    tags: ['Apple & Samsung', 'Fiches Tech', 'Haute Performance'],
    titreHeroDefaut: 'Derniers Smartphones & Haute Performance',
    sloganDefaut: 'Vitesse exceptionnelle, design élégant et innovation au meilleur prix à Bamako.',
    styleRecommande: ThemeStyle.commercialVert,
  ),
  _ModeleECommerceItem(
    modele: ModeleVitrine.modeleB,
    titre: 'Modèle 2 — TechNest',
    nomCourt: 'TechNest',
    secteur: 'Accessoires Intelligents & Électronique',
    description: 'Dark mode immersif et néon bleu high-tech. Idéal pour écouteurs sans fil, chargeurs rapides, hubs USB-C et batteries externes.',
    icone: Icons.headphones_rounded,
    couleurAccent: Color(0xFF2563EB),
    couleurFond: Color(0xFFEFF6FF),
    tags: ['Dark Mode & Néon', 'Accessoires Tendance', 'Jusqu\'à -30%'],
    titreHeroDefaut: 'Accessoires Intelligents pour Chaque Besoin',
    sloganDefaut: 'Qualité premium et technologies de pointe conçues pour booster votre style de vie.',
    styleRecommande: ThemeStyle.commercialVert,
  ),
  _ModeleECommerceItem(
    modele: ModeleVitrine.modeleD,
    titre: 'Modèle 3 — ASTERA',
    nomCourt: 'ASTERA',
    secteur: 'Mode Féminine & Prêt-à-Porter Chic',
    description: 'Palette pastel lilas et lavande d\'une grande douceur. Robes de soirée, tenues de travail élégantes et looks décontractés du week-end.',
    icone: Icons.dry_cleaning_rounded,
    couleurAccent: Color(0xFF7C3AED),
    couleurFond: Color(0xFFF5F3FF),
    tags: ['Lilas & Pastel', 'Robes & Tops', 'Élégance Féminine'],
    titreHeroDefaut: 'Style Moderne dans une Nuance Unique',
    sloganDefaut: 'Des pièces raffinées et intemporelles pour sublimer votre quotidien.',
    styleRecommande: ThemeStyle.elegantBeige,
  ),
  _ModeleECommerceItem(
    modele: ModeleVitrine.modeleE,
    titre: 'Modèle 4 — AND SHOP',
    nomCourt: 'AND SHOP',
    secteur: 'Fashion Urbain & Maroquinerie',
    description: 'Ambiance chaleureuse aux tons cognac, vestes tendance, maroquinerie, sacs à main et tenues coup de cœur.',
    icone: Icons.shopping_bag_outlined,
    couleurAccent: Color(0xFFEA580C),
    couleurFond: Color(0xFFFFF7ED),
    tags: ['Cognac & Terracotta', 'Sacs & Maroquinerie', 'Meilleures Ventes'],
    titreHeroDefaut: 'Vivez la Mode au Quotidien',
    sloganDefaut: 'Jusqu\'à -50% sur une sélection exclusive de sacs et articles de mode tendance.',
    styleRecommande: ThemeStyle.naturelChaud,
  ),
  _ModeleECommerceItem(
    modele: ModeleVitrine.modeleG,
    titre: 'Modèle 5 — ShopEase',
    nomCourt: 'ShopEase',
    secteur: 'Grand Magasin & Commerce Général',
    description: 'Tons miel et sable très accueillants. Tous rayons : Mode, Maison & Déco, Électronique, Beauté, Jouets et promotions du jour.',
    icone: Icons.storefront_rounded,
    couleurAccent: Color(0xFFD97706),
    couleurFond: Color(0xFFFEF3C7),
    tags: ['Commerce Général', 'Miel & Sable', 'Multi-Catégories'],
    titreHeroDefaut: 'Style, Qualité et Bonnes Affaires',
    sloganDefaut: 'Tout ce dont vous avez besoin au quotidien réuni en un seul endroit au meilleur prix.',
    styleRecommande: ThemeStyle.naturelChaud,
  ),
  _ModeleECommerceItem(
    modele: ModeleVitrine.modeleH,
    titre: 'Modèle 6 — NovaTrend',
    nomCourt: 'NovaTrend',
    secteur: 'Streetwear & Sneakers',
    description: 'Style streetwear dynamique en noir et orange énergique. Sneakers Nike/Jordan, hoodies urbains, ventes flash et chrono promo.',
    icone: Icons.local_fire_department_rounded,
    couleurAccent: Color(0xFF0F172A),
    couleurFond: Color(0xFFF1F5F9),
    tags: ['Streetwear & Baskets', 'Ventes Flash', 'Noir & Orange'],
    titreHeroDefaut: 'Streetwear Authentique & Baskets Tendance',
    sloganDefaut: 'Les dernières sorties urbaines en exclusivité avec livraison rapide et authenticité garantie.',
    styleRecommande: ThemeStyle.moderneMinimal,
  ),
];

class _VitrinePersonnalisationPageState extends ConsumerState<VitrinePersonnalisationPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late final TextEditingController _titreHeroCtrl;
  late final TextEditingController _sloganCtrl;
  late final TextEditingController _logoUrlCtrl;
  late final TextEditingController _banniereUrlCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _telCtrl;
  late final TextEditingController _whatsappCtrl;
  late final TextEditingController _adresseCtrl;
  late final TextEditingController _villeCtrl;
  late final TextEditingController _facebookCtrl;
  late final TextEditingController _instagramCtrl;
  late final TextEditingController _tiktokCtrl;
  late final TextEditingController _horairesCtrl;
  late final TextEditingController _paiementCtrl;
  late final TextEditingController _livraisonCtrl;

  late bool _estPublie;
  late ModeleVitrine _modeleChoisi;
  late ThemeStyle _styleChoisi;
  late VitrineSections _sections;
  bool _enSauvegarde = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final v = widget.vitrine;
    final r = v.reseauxSociaux;

    _estPublie = v.estPublie;
    _modeleChoisi = v.modeleVisuel;
    _styleChoisi = v.themeStyle;
    _sections = v.sections;

    _titreHeroCtrl = TextEditingController(text: v.titreHero ?? '');
    _sloganCtrl = TextEditingController(text: v.slogan ?? '');
    _logoUrlCtrl = TextEditingController(text: v.logoUrl ?? '');
    _banniereUrlCtrl = TextEditingController(text: v.banniereUrl ?? '');
    _descCtrl = TextEditingController(text: v.description ?? '');
    _telCtrl = TextEditingController(text: v.telephone ?? '');
    _whatsappCtrl = TextEditingController(text: v.whatsapp ?? '');
    _adresseCtrl = TextEditingController(text: v.adresse ?? '');
    _villeCtrl = TextEditingController(text: v.ville ?? '');

    _facebookCtrl = TextEditingController(text: r['facebook']?.toString() ?? '');
    _instagramCtrl = TextEditingController(text: r['instagram']?.toString() ?? '');
    _tiktokCtrl = TextEditingController(text: r['tiktok']?.toString() ?? '');
    _horairesCtrl = TextEditingController(text: r['horaires']?.toString() ?? 'Lundi - Samedi : 08h30 - 20h00\nDimanche : 10h00 - 18h00');
    _paiementCtrl = TextEditingController(text: r['paiement']?.toString() ?? 'Orange Money, Wave, Espèces à la livraison');
    _livraisonCtrl = TextEditingController(text: r['livraison']?.toString() ?? 'Livraison rapide à Bamako en 2h. Expédition en région sous 24h.');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titreHeroCtrl.dispose();
    _sloganCtrl.dispose();
    _logoUrlCtrl.dispose();
    _banniereUrlCtrl.dispose();
    _descCtrl.dispose();
    _telCtrl.dispose();
    _whatsappCtrl.dispose();
    _adresseCtrl.dispose();
    _villeCtrl.dispose();
    _facebookCtrl.dispose();
    _instagramCtrl.dispose();
    _tiktokCtrl.dispose();
    _horairesCtrl.dispose();
    _paiementCtrl.dispose();
    _livraisonCtrl.dispose();
    super.dispose();
  }


  Future<void> _ouvrirApercuDirect() async {
    await _enregistrerTout(afficherNotification: false);
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: MediaQuery.sizeOf(context).height * 0.94,
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 25, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.smartphone_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Aperçu du site — ${_modeleChoisi.titre}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  child: VitrinePubliquePage(slug: widget.vitrine.slug),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectionnerEtAppliquerModele(_ModeleECommerceItem item) async {
    setState(() {
      _modeleChoisi = item.modele;
      _titreHeroCtrl.text = item.titreHeroDefaut;
      _sloganCtrl.text = item.sloganDefaut;
      _styleChoisi = item.styleRecommande;
    });
    // Enregistrement immédiat pour mise à jour instantanée du site et des aperçus
    await _enregistrerTout(afficherNotification: false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ ${item.nomCourt} activé avec succès ! Design et textes appliqués.'),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _appliquerSuggestionsModele(_ModeleECommerceItem item) {
    setState(() {
      _modeleChoisi = item.modele;
      _titreHeroCtrl.text = item.titreHeroDefaut;
      _sloganCtrl.text = item.sloganDefaut;
      _styleChoisi = item.styleRecommande;
    });
    _enregistrerTout(afficherNotification: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Réglages recommandés pour ${item.nomCourt} appliqués !'),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _choisirPresetBanniere(String url) {
    setState(() => _banniereUrlCtrl.text = url);
  }

  void _remplirTexteType() {
    final act = widget.vitrine.typeActivite;
    final nom = _titreHeroCtrl.text.trim().isNotEmpty ? _titreHeroCtrl.text.trim() : 'notre établissement';
    if (act == TypeActivite.salonCoiffure || act == TypeActivite.beauteEsthetique) {
      _descCtrl.text = 'Bienvenue chez $nom, votre salon de référence pour sublimer votre beauté. Nous sommes spécialisés dans les tresses soignées, la pose de perruques invisibles et les soins capillaires personnalisés avec des produits haut de gamme.';
    } else if (act == TypeActivite.boutiqueTech) {
      _descCtrl.text = 'Bienvenue chez $nom, votre expert en smartphones, accessoires high-tech et gadgets innovants à Bamako. Tous nos produits sont certifiés authentiques, garantis avec service après-vente dédié et livraison express.';
    } else {
      _descCtrl.text = 'Bienvenue chez $nom ! Découvrez notre large sélection d\'articles de qualité certifiée au meilleur prix. Service client à votre écoute 7j/7 et livraison express partout au Mali.';
    }
    setState(() {});
  }

  Future<void> _enregistrerTout({bool afficherNotification = true}) async {
    setState(() => _enSauvegarde = true);
    final v = widget.vitrine;
    final reseaux = Map<String, dynamic>.from(v.reseauxSociaux);
    reseaux['facebook'] = _facebookCtrl.text.trim();
    reseaux['instagram'] = _instagramCtrl.text.trim();
    reseaux['tiktok'] = _tiktokCtrl.text.trim();
    reseaux['horaires'] = _horairesCtrl.text.trim();
    reseaux['paiement'] = _paiementCtrl.text.trim();
    reseaux['livraison'] = _livraisonCtrl.text.trim();

    final maj = v.copyWith(
      estPublie: _estPublie,
      titreHero: _titreHeroCtrl.text.trim().isNotEmpty ? _titreHeroCtrl.text.trim() : null,
      slogan: _sloganCtrl.text.trim().isNotEmpty ? _sloganCtrl.text.trim() : null,
      logoUrl: _logoUrlCtrl.text.trim().isNotEmpty ? _logoUrlCtrl.text.trim() : null,
      banniereUrl: _banniereUrlCtrl.text.trim().isNotEmpty ? _banniereUrlCtrl.text.trim() : null,
      modeleVisuel: _modeleChoisi,
      themeStyle: _styleChoisi,
      sections: _sections,
      description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      telephone: _telCtrl.text.trim().isNotEmpty ? _telCtrl.text.trim() : null,
      whatsapp: _whatsappCtrl.text.trim().isNotEmpty ? _whatsappCtrl.text.trim() : null,
      adresse: _adresseCtrl.text.trim().isNotEmpty ? _adresseCtrl.text.trim() : null,
      ville: _villeCtrl.text.trim().isNotEmpty ? _villeCtrl.text.trim() : null,
      reseauxSociaux: reseaux,
    );

    await ref.read(vitrineActuelleProvider.notifier).sauvegarder(maj);
    if (mounted) {
      setState(() => _enSauvegarde = false);
      if (afficherNotification) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Toutes les personnalisations ont été enregistrées avec succès !'),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _copierLien() {
    Clipboard.setData(ClipboardData(text: widget.vitrine.urlPublique));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lien copié dans le presse-papier !'),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _partagerWhatsApp() async {
    final texte = 'Bonjour ! Découvrez notre site officiel ici : ${widget.vitrine.urlPublique}';
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(texte)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Studio de Personnalisation',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.green,
          labelColor: AppColors.green,
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_customize_rounded, size: 18), text: 'Design & Modèle'),
            Tab(icon: Icon(Icons.panorama_rounded, size: 18), text: 'Identité & Bannière'),
            Tab(icon: Icon(Icons.layers_rounded, size: 18), text: 'Sections Actives'),
            Tab(icon: Icon(Icons.store_rounded, size: 18), text: 'Infos & Contacts'),
          ],
        ),
        actions: [
          IconButton(
            icon: _enSauvegarde
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded, color: AppColors.green),
            tooltip: 'Enregistrer',
            onPressed: _enSauvegarde ? null : _enregistrerTout,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: SafeArea(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _enSauvegarde
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_circle_rounded),
            label: Text(
              _enSauvegarde ? 'Enregistrement en cours...' : 'Enregistrer les personnalisations',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            onPressed: _enSauvegarde ? null : _enregistrerTout,
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOngletDesign(),
          _buildOngletIdentite(),
          _buildOngletSections(),
          _buildOngletInfos(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ONGLET 1 : DESIGN & MODÈLE (SÉLECTION DES 6 MODÈLES E-COMMERCE & STYLE)
  // ---------------------------------------------------------------------------
  Widget _buildOngletDesign() {
    final itemActif = _modelesECommerceDisponibles.firstWhere(
      (it) => it.modele == _modeleChoisi,
      orElse: () => _modelesECommerceDisponibles.first,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Carte Statut en Ligne
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _estPublie ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _estPublie ? Icons.public_rounded : Icons.public_off_rounded,
                    color: _estPublie ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _estPublie ? 'Site public EN LIGNE' : 'Site public MASQUÉ (Brouillon)',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: _estPublie ? const Color(0xFF15803D) : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _estPublie ? 'Accessible par vos clients et sur WhatsApp' : 'Visible uniquement par vous',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _estPublie,
                  activeThumbColor: AppColors.green,
                  onChanged: (val) => setState(() => _estPublie = val),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Carte Partage du lien & Aperçu direct
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Lien officiel de votre site', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: const Icon(Icons.visibility_rounded, size: 14),
                      label: const Text('Aperçu direct', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      onPressed: _ouvrirApercuDirect,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded, size: 18, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.vitrine.urlPublique,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copier'),
                        onPressed: _copierLien,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w800)),
                        onPressed: _partagerWhatsApp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // EN-TÊTE DE SÉLECTION DES 6 MODÈLES E-COMMERCE
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F5132), Color(0xFF198754)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: const Color(0xFF0F5132).withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.store_mall_directory_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('6 Modèles E-commerce Haute Conversion', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                    SizedBox(height: 2),
                    Text('Sélectionnez votre type de boutique pour adapter immédiatement le design et personnaliser votre contenu.', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // LISTE VISUELLE DES 6 MODÈLES E-COMMERCE
        for (final item in _modelesECommerceDisponibles) ...[
          _buildCarteModeleECommerce(item),
          const SizedBox(height: 10),
        ],

        // SECTION MODÈLES SPÉCIALISÉS (SERVICES & IMMOBILIER)
        const SizedBox(height: 10),
        ExpansionTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white,
          leading: const Icon(Icons.room_service_outlined, color: Color(0xFF64748B)),
          title: const Text('Autres modèles (Services & Immobilier)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF334155))),
          subtitle: const Text('The LUXE Studio (Salon VIP) & Havenly (Immobilier)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  RadioListTile<ModeleVitrine>(
                    value: ModeleVitrine.modeleC,
                    groupValue: _modeleChoisi,
                    activeColor: AppColors.green,
                    title: const Text('The LUXE Studio (Salon Coiffure & Soins VIP)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    subtitle: const Text('Prestations avec tarifs en FCFA, réservation WhatsApp et galerie de réalisations', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    onChanged: (val) {
                      if (val != null) setState(() => _modeleChoisi = val);
                    },
                  ),
                  RadioListTile<ModeleVitrine>(
                    value: ModeleVitrine.modeleF,
                    groupValue: _modeleChoisi,
                    activeColor: AppColors.green,
                    title: const Text('Havenly (Agence & Biens Immobiliers)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    subtitle: const Text('Catalogue de villas, appartements, recherche par ville et demandes de visite', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    onChanged: (val) {
                      if (val != null) setState(() => _modeleChoisi = val);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // CARTE DE PERSONNALISATION DE LA PALETTE DE COULEURS
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Palette de couleurs :', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(height: 4),
                const Text('Ajustez les teintes principales selon l\'identité visuelle de votre marque.', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Commercial Vert'),
                      selected: _styleChoisi == ThemeStyle.commercialVert,
                      onSelected: (s) => setState(() => _styleChoisi = ThemeStyle.commercialVert),
                    ),
                    ChoiceChip(
                      label: const Text('Luxe Or & Noir'),
                      selected: _styleChoisi == ThemeStyle.luxeOr,
                      onSelected: (s) => setState(() => _styleChoisi = ThemeStyle.luxeOr),
                    ),
                    ChoiceChip(
                      label: const Text('Élégant Beige'),
                      selected: _styleChoisi == ThemeStyle.elegantBeige,
                      onSelected: (s) => setState(() => _styleChoisi = ThemeStyle.elegantBeige),
                    ),
                    ChoiceChip(
                      label: const Text('Moderne Minimal'),
                      selected: _styleChoisi == ThemeStyle.moderneMinimal,
                      onSelected: (s) => setState(() => _styleChoisi = ThemeStyle.moderneMinimal),
                    ),
                    ChoiceChip(
                      label: const Text('Naturel Chaud'),
                      selected: _styleChoisi == ThemeStyle.naturelChaud,
                      onSelected: (s) => setState(() => _styleChoisi = ThemeStyle.naturelChaud),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // BOUTON POUR PASSER À LA SUITE DE LA PERSONNALISATION
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppColors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Modèle actuel : ${itemActif.nomCourt}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF15803D)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Personnaliser le contenu (Titre, Slogan, Logo, Contacts) →', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                onPressed: () => _tabController.animateTo(1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildCarteModeleECommerce(_ModeleECommerceItem item) {
    final estSelectionne = _modeleChoisi == item.modele;

    return InkWell(
      onTap: () => _selectionnerEtAppliquerModele(item),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: estSelectionne ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: estSelectionne ? AppColors.green : const Color(0xFFE2E8F0),
            width: estSelectionne ? 2.5 : 1,
          ),
          boxShadow: estSelectionne
              ? [
                  BoxShadow(color: AppColors.green.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 3)),
                ]
              : [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: item.couleurFond,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icone, color: item.couleurAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.titre,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.secteur,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: item.couleurAccent),
                      ),
                    ],
                  ),
                ),
                if (estSelectionne)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 14),
                        SizedBox(width: 4),
                        Text('SÉLECTIONNÉ', style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w900, fontSize: 10)),
                      ],
                    ),
                  )
                else
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    onPressed: () => _selectionnerEtAppliquerModele(item),
                    child: const Text('Choisir', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.description,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, height: 1.3),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final tag in item.tags)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.couleurFond,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: item.couleurAccent),
                    ),
                  ),
              ],
            ),
            if (estSelectionne) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        side: const BorderSide(color: AppColors.green),
                        foregroundColor: AppColors.green,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 14),
                      label: const Text('Appliquer textes & couleurs suggérés', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                      onPressed: () => _appliquerSuggestionsModele(item),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Aperçu direct',
                    icon: const Icon(Icons.preview_rounded, color: Color(0xFF0F172A), size: 18),
                    onPressed: _ouvrirApercuDirect,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ONGLET 2 : IDENTITÉ & BANNIÈRE HERO
  // ---------------------------------------------------------------------------
  Widget _buildOngletIdentite() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('En-tête & Bannière d\'Accueil (Hero)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 4),
                const Text('Cette section constitue la première impression de vos visiteurs.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _titreHeroCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Grand titre d\'accroche (Hero) *',
                    hintText: 'Ex: Le temple du High-Tech, Maison de Beauté VIP',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sloganCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Slogan / Phrase de bienvenue',
                    hintText: 'Ex: La meilleure qualité au meilleur prix à Bamako',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _logoUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL de votre Logo',
                    hintText: 'https://...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _banniereUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Image de couverture Hero (Haute Définition)',
                    hintText: 'https://images.unsplash.com/...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.panorama_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Photos HD gratuites prêtes en 1 clic :', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.devices_rounded, size: 14),
                      label: const Text('High-Tech', style: TextStyle(fontSize: 11)),
                      onPressed: () => _choisirPresetBanniere('https://images.unsplash.com/photo-1550009158-9ebf69173e03?w=1600&q=80'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.checkroom_rounded, size: 14),
                      label: const Text('Mode', style: TextStyle(fontSize: 11)),
                      onPressed: () => _choisirPresetBanniere('https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=1600&q=80'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.content_cut_rounded, size: 14),
                      label: const Text('Coiffure', style: TextStyle(fontSize: 11)),
                      onPressed: () => _choisirPresetBanniere('https://images.unsplash.com/photo-1560066984-138dadb4c035?w=1600&q=80'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.spa_rounded, size: 14),
                      label: const Text('Beauté', style: TextStyle(fontSize: 11)),
                      onPressed: () => _choisirPresetBanniere('https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=1600&q=80'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.apartment_rounded, size: 14),
                      label: const Text('Immobilier', style: TextStyle(fontSize: 11)),
                      onPressed: () => _choisirPresetBanniere('https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=1600&q=80'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.build_rounded, size: 14),
                      label: const Text('Quincaillerie', style: TextStyle(fontSize: 11)),
                      onPressed: () => _choisirPresetBanniere('https://images.unsplash.com/photo-1581244277943-fe4a9c777189?w=1600&q=80'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ONGLET 3 : SECTIONS ACTIVES
  // ---------------------------------------------------------------------------
  Widget _buildOngletSections() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sections visibles sur votre site public', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 4),
                const Text('Activez ou masquez les sections selon vos besoins commerciaux.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bannière Hero d\'Accueil', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: const Text('Grande photo de couverture avec slogan et boutons WhatsApp', style: TextStyle(fontSize: 11)),
                  value: _sections.accueil,
                  activeThumbColor: AppColors.green,
                  onChanged: (v) => setState(() => _sections = _sections.copyWith(accueil: v)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Produits & Vente', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: const Text('Grille d\'articles avec photos, prix et commandes WhatsApp', style: TextStyle(fontSize: 11)),
                  value: _sections.produits,
                  activeThumbColor: AppColors.green,
                  onChanged: (v) => setState(() => _sections = _sections.copyWith(produits: v)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Prestations & Tarifs', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: const Text('Services, coiffures, soins et tarifs détaillés', style: TextStyle(fontSize: 11)),
                  value: _sections.prestations,
                  activeThumbColor: AppColors.green,
                  onChanged: (v) => setState(() => _sections = _sections.copyWith(prestations: v, tarifs: v)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Galerie Photos de Réalisations', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: const Text('Portfolio de vos réalisations et avant/après', style: TextStyle(fontSize: 11)),
                  value: _sections.galerie,
                  activeThumbColor: AppColors.green,
                  onChanged: (v) => setState(() => _sections = _sections.copyWith(galerie: v)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Avis & Témoignages Clients', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: const Text('Cartes d\'avis 5 étoiles pour inspirer confiance', style: TextStyle(fontSize: 11)),
                  value: _sections.temoignages,
                  activeThumbColor: AppColors.green,
                  onChanged: (v) => setState(() => _sections = _sections.copyWith(temoignages: v)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Présentation de l\'Équipe', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: const Text('Photos et rôles des professionnels de votre entreprise', style: TextStyle(fontSize: 11)),
                  value: _sections.equipe,
                  activeThumbColor: AppColors.green,
                  onChanged: (v) => setState(() => _sections = _sections.copyWith(equipe: v)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ONGLET 4 : INFOS & CONTACTS
  // ---------------------------------------------------------------------------
  Widget _buildOngletInfos() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // À propos
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('À propos de votre entreprise', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    TextButton.icon(
                      icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF4F46E5)),
                      label: const Text('Texte type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5))),
                      onPressed: _remplirTexteType,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Présentation publique',
                    hintText: 'Racontez votre histoire, votre savoir-faire et vos engagements...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Contacts & Réseaux
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Coordonnées & Réseaux Sociaux', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _whatsappCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'WhatsApp direct *',
                          hintText: '+223 70 00 00 00',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _telCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone direct',
                          hintText: '+223 60 00 00 00',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextFormField(
                        controller: _adresseCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Adresse physique',
                          hintText: 'Quartier, Rue, Porte',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: _villeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Ville',
                          hintText: 'Bamako',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _facebookCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Lien Page Facebook',
                    hintText: 'https://facebook.com/maboutique',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _instagramCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Lien Profil Instagram',
                    hintText: 'https://instagram.com/maboutique',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _tiktokCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Lien Compte TikTok',
                    hintText: 'https://tiktok.com/@maboutique',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Horaires, Paiement & Livraison
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Horaires, Paiement & Livraison', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _horairesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Horaires d\'ouverture',
                    hintText: 'Ex: Lundi - Samedi : 08h30 - 20h00',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _paiementCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Moyens de paiement acceptés',
                    hintText: 'Orange Money, Wave, Espèces à la livraison',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _livraisonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Conditions & Zones de livraison',
                    hintText: 'Livraison express à Bamako en 2h. Expédition sous 24h.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
