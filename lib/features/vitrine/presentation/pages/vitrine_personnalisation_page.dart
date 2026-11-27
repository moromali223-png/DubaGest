import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/vitrine_config.dart';
import '../../domain/entities/vitrine_types.dart';
import '../providers/vitrine_providers.dart';

/// Page dédiée complète pour la personnalisation de la vitrine avec UI/UX moderne
class VitrinePersonnalisationPage extends ConsumerStatefulWidget {
  const VitrinePersonnalisationPage({super.key, required this.vitrine});
  final VitrineConfig vitrine;

  @override
  ConsumerState<VitrinePersonnalisationPage> createState() => _VitrinePersonnalisationPageState();
}

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

  Future<void> _enregistrerTout() async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Toutes les personnalisations ont été enregistrées avec succès !'),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
  // ONGLET 1 : DESIGN & MODÈLE
  // ---------------------------------------------------------------------------
  Widget _buildOngletDesign() {
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

        // Carte Partage du lien
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
                const Text('Lien officiel de votre site', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
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
        const SizedBox(height: 14),

        // Sélection du modèle visuel
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
                const Text('Choisir le modèle visuel adapté', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 4),
                const Text('Chaque modèle adapte la mise en page, les rayons et l\'ergonomie.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                const SizedBox(height: 14),
                for (final m in ModeleVitrine.values)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: _modeleChoisi == m ? const Color(0xFFF0FDF4) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _modeleChoisi == m ? AppColors.green : const Color(0xFFE2E8F0),
                        width: _modeleChoisi == m ? 2 : 1,
                      ),
                    ),
                    child: RadioListTile<ModeleVitrine>(
                      value: m,
                      groupValue: _modeleChoisi,
                      activeColor: AppColors.green,
                      title: Text(m.titre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      subtitle: Text(m.description, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      onChanged: (val) {
                        if (val != null) setState(() => _modeleChoisi = val);
                      },
                    ),
                  ),
                const Divider(),
                const SizedBox(height: 6),
                const Text('Palette de couleurs :', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 8),
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
      ],
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
