import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/media_picker_helper.dart';
import '../../../../features/catalogue/services/media_hybrid_resolver.dart';
import '../providers/vitrine_providers.dart';
import '../../domain/entities/vitrine_bien_immobilier.dart';
import '../../domain/entities/vitrine_config.dart';
import '../../domain/entities/vitrine_demande_visite.dart';
import '../../domain/entities/vitrine_galerie_item.dart';
import '../../domain/entities/vitrine_membre_equipe.dart';
import '../../domain/entities/vitrine_prestation.dart';
import '../../domain/entities/vitrine_produit_item.dart';
import '../../domain/entities/vitrine_rendez_vous.dart';
import '../../domain/entities/vitrine_types.dart';
import 'vitrine_publique_page.dart';
import 'vitrine_personnalisation_page.dart';

/// Page d'administration complète « Ma Vitrine » pour le professionnel
class VitrineDashboardPage extends ConsumerStatefulWidget {
  const VitrineDashboardPage({super.key});

  @override
  ConsumerState<VitrineDashboardPage> createState() => _VitrineDashboardPageState();
}

class _VitrineDashboardPageState extends ConsumerState<VitrineDashboardPage> {
  void _copierLien(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lien de votre vitrine copié dans le presse-papier !'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.green,
      ),
    );
  }

  Future<void> _partagerWhatsApp(VitrineConfig vitrine) async {
    final texte = 'Bonjour ! Découvrez notre site vitrine officiel chez *${vitrine.titreHero ?? 'DubaGest'}* ici : ${vitrine.urlPublique}';
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(texte)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _ouvrirPagePersonnalisation(BuildContext context, VitrineConfig vitrine) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => VitrinePersonnalisationPage(vitrine: vitrine)),
    );
  }

  void _ouvrirStudioPrevisualisation(BuildContext context, VitrineConfig vitrine) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => _StudioPrevisualisationDialog(vitrine: vitrine),
    );
  }

  int _calculerProgression(VitrineConfig vitrine, {required int nbProduits, required int nbPrestations, required int nbBiens}) {
    int score = 0;
    // 1. Logo ou photo de marque (25%)
    if (vitrine.logoUrl != null && vitrine.logoUrl!.trim().isNotEmpty) score += 25;
    // 2. Contenu au catalogue (25%)
    final totalArticles = (nbProduits > 0) || (nbPrestations > 0) || (nbBiens > 0);
    if (totalArticles) score += 25;
    // 3. Histoire & Slogan (25%)
    if ((vitrine.description != null && vitrine.description!.trim().isNotEmpty) ||
        (vitrine.slogan != null && vitrine.slogan!.trim().isNotEmpty)) {
      score += 25;
    }
    // 4. Contact direct (25%)
    if ((vitrine.whatsapp != null && vitrine.whatsapp!.trim().isNotEmpty) ||
        (vitrine.telephone != null && vitrine.telephone!.trim().isNotEmpty)) {
      score += 25;
    }
    return score;
  }

  void _ouvrirFormulaireBien(BuildContext context, WidgetRef ref, VitrineConfig vitrine) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _DialogueAjoutBien(vitrine: vitrine),
    );
  }

  void _ouvrirDialogueAjoutProduit(BuildContext context, VitrineConfig vitrine) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _DialogueAjoutOuModifProduitVitrine(vitrine: vitrine),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncVitrine = ref.watch(vitrineActuelleProvider);
    final asyncProduits = ref.watch(vitrineProduitsAdminProvider);
    final asyncPrestations = ref.watch(vitrinePrestationsProvider);
    final asyncBiens = ref.watch(vitrineBiensProvider);

    final nbProduits = asyncProduits.value?.length ?? 0;
    final nbPrestations = asyncPrestations.value?.length ?? 0;
    final nbBiens = asyncBiens.value?.length ?? 0;

    return asyncVitrine.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text('Erreur : $err'))),
      data: (vitrine) {
        if (vitrine == null) {
          return const Scaffold(body: Center(child: Text('Aucune vitrine configurée.')));
        }

        final isImmo = vitrine.typeActivite.domaine == DomaineActivite.immobilier;
        final isServices = vitrine.typeActivite.domaine == DomaineActivite.services;

        List<Tab> tabs;
        List<Widget> views;

        if (isImmo) {
          tabs = const [
            Tab(icon: Icon(Icons.home_work_rounded, size: 18), text: 'Biens Immobiliers'),
            Tab(icon: Icon(Icons.event_available_rounded, size: 18), text: 'Demandes de Visite'),
            Tab(icon: Icon(Icons.photo_library_rounded, size: 18), text: 'Galerie Photos'),
            Tab(icon: Icon(Icons.tune_rounded, size: 18), text: 'Apparence & Modèle'),
            Tab(icon: Icon(Icons.info_outline_rounded, size: 18), text: 'Infos Agence'),
          ];
          views = [
            _OngletBiensImmobiliers(vitrine: vitrine),
            _OngletDemandesVisite(vitrine: vitrine),
            _OngletGalerie(vitrine: vitrine),
            _OngletApparence(vitrine: vitrine),
            _OngletInfosBoutique(vitrine: vitrine),
          ];
        } else if (isServices) {
          tabs = const [
            Tab(icon: Icon(Icons.content_cut_rounded, size: 18), text: 'Prestations & Tarifs'),
            Tab(icon: Icon(Icons.calendar_today_rounded, size: 18), text: 'Rendez-vous'),
            Tab(icon: Icon(Icons.shopping_bag_rounded, size: 18), text: 'Produits / Vente'),
            Tab(icon: Icon(Icons.photo_library_rounded, size: 18), text: 'Galerie Réalisations'),
            Tab(icon: Icon(Icons.tune_rounded, size: 18), text: 'Apparence & Modèle'),
            Tab(icon: Icon(Icons.info_outline_rounded, size: 18), text: 'Infos Salon'),
          ];
          views = [
            _OngletPrestations(vitrine: vitrine),
            _OngletRendezVous(vitrine: vitrine),
            _OngletProduits(vitrine: vitrine),
            _OngletGalerie(vitrine: vitrine),
            _OngletApparence(vitrine: vitrine),
            _OngletInfosBoutique(vitrine: vitrine),
          ];
        } else {
          // Domaine Commerce
          tabs = const [
            Tab(icon: Icon(Icons.storefront_rounded, size: 18), text: 'Produits en vitrine'),
            Tab(icon: Icon(Icons.photo_library_rounded, size: 18), text: 'Galerie Réalisations'),
            Tab(icon: Icon(Icons.tune_rounded, size: 18), text: 'Apparence & Modèle'),
            Tab(icon: Icon(Icons.store_rounded, size: 18), text: 'Infos Boutique'),
          ];
          views = [
            _OngletProduits(vitrine: vitrine),
            _OngletGalerie(vitrine: vitrine),
            _OngletApparence(vitrine: vitrine),
            _OngletInfosBoutique(vitrine: vitrine),
          ];
        }

        return DefaultTabController(
          key: ValueKey('${vitrine.typeActivite.domaine.code}_${tabs.length}'),
          length: tabs.length,
          child: Builder(
            builder: (ctx) {
              return Scaffold(
                backgroundColor: const Color(0xFFF8FAFC),
                appBar: AppBar(
                  title: Text(
                    vitrine.titreHero?.isNotEmpty == true ? vitrine.titreHero! : 'Ma Vitrine Pro',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0F172A),
                  elevation: 0,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.preview_rounded, color: Color(0xFF0F172A)),
                      tooltip: 'Aperçu en direct',
                      onPressed: () => _ouvrirStudioPrevisualisation(context, vitrine),
                    ),
                    IconButton(
                      icon: const Icon(Icons.auto_awesome_rounded, color: AppColors.green),
                      tooltip: 'Assistant création & refonte (Wizard)',
                      onPressed: () => context.push(Routes.vitrineWizard),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Actualiser',
                      onPressed: () => ref.invalidate(vitrineActuelleProvider),
                    ),
                  ],
                ),
                floatingActionButton: FloatingActionButton.extended(
                  heroTag: 'fab_ajout_vitrine_main',
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  icon: const Icon(Icons.add_rounded, size: 22),
                  label: Text(
                    isImmo ? 'Ajouter un bien' : (isServices ? 'Ajouter un service' : 'Ajouter un produit'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  onPressed: () {
                    if (isImmo) {
                      _ouvrirFormulaireBien(context, ref, vitrine);
                    } else if (isServices) {
                      _ouvrirDialoguePrestationDirect(context, ref, vitrine);
                    } else {
                      _ouvrirDialogueAjoutProduit(context, vitrine);
                    }
                  },
                ),
                body: Column(
                  children: [
                    // 1. En-tête statut & progression
                    _buildHeaderStatus(
                      ctx,
                      vitrine,
                      nbProduits: nbProduits,
                      nbPrestations: nbPrestations,
                      nbBiens: nbBiens,
                    ),

                    // 2. Barre d'onglets claire et responsive
                    Container(
                      color: Colors.white,
                      child: TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicatorColor: AppColors.green,
                        labelColor: AppColors.green,
                        unselectedLabelColor: const Color(0xFF64748B),
                        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        tabs: tabs,
                      ),
                    ),

                    // 3. Contenu de chaque onglet
                    Expanded(
                      child: TabBarView(
                        children: views,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _ouvrirDialoguePrestationDirect(BuildContext context, WidgetRef ref, VitrineConfig vitrine) {
    final nomCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final prixCtrl = TextEditingController();
    final dureeCtrl = TextEditingController();
    final catCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ajouter une prestation / soin', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 14),
              TextField(
                controller: nomCtrl,
                decoration: const InputDecoration(labelText: 'Nom de la prestation *', hintText: 'Ex: Tresses africaines, Brushing VIP', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: prixCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Tarif (FCFA) *', hintText: '5000', border: OutlineInputBorder(), suffixText: 'FCFA'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: dureeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Durée (min)', hintText: '45', border: OutlineInputBorder(), suffixText: 'min'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: catCtrl,
                decoration: const InputDecoration(labelText: 'Catégorie', hintText: 'Coiffure, Soins, Manucure...', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description publique', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.green, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Enregistrer et publier la prestation', style: TextStyle(fontWeight: FontWeight.w800)),
                  onPressed: () async {
                    final nom = nomCtrl.text.trim();
                    final prix = int.tryParse(prixCtrl.text.trim()) ?? 0;
                    final duree = int.tryParse(dureeCtrl.text.trim()) ?? 30;
                    if (nom.isEmpty || prix <= 0) return;

                    Navigator.pop(ctx);
                    var vitrineId = vitrine.id;
                    if (vitrineId.isEmpty) {
                      final vMaj = await ref.read(vitrineRepositoryProvider).sauvegarderVitrine(vitrine);
                      vitrineId = vMaj.id;
                      ref.invalidate(vitrineActuelleProvider);
                    }
                    final p = VitrinePrestation(
                      id: '',
                      vitrineId: vitrineId,
                      entrepriseId: vitrine.entrepriseId,
                      nom: nom,
                      prix: prix,
                      dureeMinutes: duree,
                      categorie: catCtrl.text.trim(),
                      description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                    );
                    await ref.read(vitrineRepositoryProvider).sauvegarderPrestation(p);
                    ref.invalidate(vitrinePrestationsProvider);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStatus(
    BuildContext context,
    VitrineConfig vitrine, {
    required int nbProduits,
    required int nbPrestations,
    required int nbBiens,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Pastille statut
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: vitrine.estPublie ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      vitrine.estPublie ? 'En ligne' : 'Brouillon',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: vitrine.estPublie ? const Color(0xFF15803D) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• ${vitrine.modeleVisuel.titre.split('—').first.trim()}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                InkWell(
                  onTap: () => _copierLien(vitrine.urlPublique),
                  child: Text(
                    vitrine.urlPublique,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), decoration: TextDecoration.underline),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Bouton Aperçu
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.preview_rounded, size: 20, color: Color(0xFF0F172A)),
            tooltip: 'Aperçu du site',
            onPressed: () => _ouvrirStudioPrevisualisation(context, vitrine),
          ),
          const SizedBox(width: 4),
          // Bouton Personnaliser (ouvre la page dédiée avec UI/UX moderne)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.tune_rounded, size: 14),
            label: const Text('Personnaliser', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
            onPressed: () => _ouvrirPagePersonnalisation(context, vitrine),
          ),
        ],
      ),
    );
  }

  void _ouvrirSelecteurModeleRapide(BuildContext context, WidgetRef ref, VitrineConfig vitrine) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.sizeOf(context).height * 0.88,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Barre de préhension
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // En-tête
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF16A34A), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Choisir le modèle de vitrine', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A))),
                        SizedBox(height: 2),
                        Text('6 modèles e-commerce haute conversion & personnalisables', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Contenu défilant avec les cartes des modèles
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. MobileX & TechVerse
                  _buildCarteModeleSelection(
                    context: context,
                    ref: ref,
                    vitrine: vitrine,
                    modele: ModeleVitrine.modeleA,
                    titre: 'Modèle 1 — MobileX & TechVerse',
                    secteur: 'Smartphones, High-Tech, Apple & Samsung',
                    description: 'Entête dynamique, vitrine smartphones carrée, bannières marques officielles, boutons WhatsApp & zéro overflow.',
                    icone: Icons.phone_iphone_rounded,
                    couleurAccent: const Color(0xFFEA580C),
                    couleurFond: const Color(0xFFFFF7ED),
                    activite: TypeActivite.boutiqueTech,
                    style: ThemeStyle.commercialVert,
                  ),
                  const SizedBox(height: 12),

                  // 2. TechNest
                  _buildCarteModeleSelection(
                    context: context,
                    ref: ref,
                    vitrine: vitrine,
                    modele: ModeleVitrine.modeleB,
                    titre: 'Modèle 2 — TechNest',
                    secteur: 'Accessoires Intelligents & Électronique',
                    description: 'Dark mode immersif, néon bleu, écouteurs, chargeurs rapides, hubs 8-en-1 et offres flash jusqu\'à -30%.',
                    icone: Icons.headphones_rounded,
                    couleurAccent: const Color(0xFF2563EB),
                    couleurFond: const Color(0xFFEFF6FF),
                    activite: TypeActivite.boutiqueTech,
                    style: ThemeStyle.commercialVert,
                  ),
                  const SizedBox(height: 12),

                  // 3. ASTERA
                  _buildCarteModeleSelection(
                    context: context,
                    ref: ref,
                    vitrine: vitrine,
                    modele: ModeleVitrine.modeleD,
                    titre: 'Modèle 3 — ASTERA',
                    secteur: 'Mode Féminine & Prêt-à-Porter Chic',
                    description: 'Tons pastel lilas & lavande, robes midi, tenues weekend et bureau, best sellers élégants et commande fluide.',
                    icone: Icons.dry_cleaning_rounded,
                    couleurAccent: const Color(0xFF7C3AED),
                    couleurFond: const Color(0xFFF5F3FF),
                    activite: TypeActivite.boutiqueSpecialisee,
                    style: ThemeStyle.elegantBeige,
                  ),
                  const SizedBox(height: 12),

                  // 4. AND SHOP
                  _buildCarteModeleSelection(
                    context: context,
                    ref: ref,
                    vitrine: vitrine,
                    modele: ModeleVitrine.modeleE,
                    titre: 'Modèle 4 — AND SHOP',
                    secteur: 'Fashion Tendance & Maroquinerie',
                    description: 'Teintes chaleureuses cognac/orange, sacs à main de qualité, vestes, prêt-à-porter coup de cœur et offres spéciales.',
                    icone: Icons.shopping_bag_outlined,
                    couleurAccent: const Color(0xFFEA580C),
                    couleurFond: const Color(0xFFFFF7ED),
                    activite: TypeActivite.boutiqueSpecialisee,
                    style: ThemeStyle.naturelChaud,
                  ),
                  const SizedBox(height: 12),

                  // 5. ShopEase
                  _buildCarteModeleSelection(
                    context: context,
                    ref: ref,
                    vitrine: vitrine,
                    modele: ModeleVitrine.modeleG,
                    titre: 'Modèle 5 — ShopEase',
                    secteur: 'Grand Magasin & Commerce Général',
                    description: 'Ambiance miel & sable, rayons Mode, Maison & Déco, Électronique, Beauté, Jouets et livraison locale sécurisée.',
                    icone: Icons.storefront_rounded,
                    couleurAccent: const Color(0xFFD97706),
                    couleurFond: const Color(0xFFFEF3C7),
                    activite: TypeActivite.commerceGeneral,
                    style: ThemeStyle.naturelChaud,
                  ),
                  const SizedBox(height: 12),

                  // 6. NovaTrend
                  _buildCarteModeleSelection(
                    context: context,
                    ref: ref,
                    vitrine: vitrine,
                    modele: ModeleVitrine.modeleH,
                    titre: 'Modèle 6 — NovaTrend',
                    secteur: 'Streetwear, Sneakers & Lifestyle',
                    description: 'Style urbain moderne noir et orange, sneakers Nike/Jordan, hoodies streetwear et promos choc.',
                    icone: Icons.local_fire_department_rounded,
                    couleurAccent: const Color(0xFF0F172A),
                    couleurFond: const Color(0xFFF1F5F9),
                    activite: TypeActivite.boutiqueSpecialisee,
                    style: ThemeStyle.moderneMinimal,
                  ),
                  const SizedBox(height: 20),

                  // Autres modèles (Services & Immobilier)
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
                    title: const Text('Modèles Spécialisés (Services & Immobilier)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF334155))),
                    children: [
                      ListTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xFFFEF3C7), child: Icon(Icons.content_cut_rounded, color: Color(0xFFD97706))),
                        title: const Text('The LUXE Studio (Salon Coiffure & Soins VIP)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        subtitle: const Text('Prestations avec tarifs en FCFA et prise de rendez-vous'),
                        selected: vitrine.modeleVisuel == ModeleVitrine.modeleC,
                        trailing: OutlinedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await ref.read(vitrineActuelleProvider.notifier).changerModele(
                              activite: TypeActivite.salonCoiffure,
                              modele: ModeleVitrine.modeleC,
                              style: ThemeStyle.luxeOr,
                            );
                            if (context.mounted) _ouvrirPagePersonnalisation(context, vitrine.copyWith(modeleVisuel: ModeleVitrine.modeleC));
                          },
                          child: const Text('Choisir'),
                        ),
                      ),
                      ListTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xFFDCFCE7), child: Icon(Icons.apartment_rounded, color: Color(0xFF15803D))),
                        title: const Text('Havenly (Agence & Biens Immobiliers)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        subtitle: const Text('Villas, appartements et fiches immobilières détaillées'),
                        selected: vitrine.modeleVisuel == ModeleVitrine.modeleF,
                        trailing: OutlinedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await ref.read(vitrineActuelleProvider.notifier).changerModele(
                              activite: TypeActivite.agenceImmobiliere,
                              modele: ModeleVitrine.modeleF,
                              style: ThemeStyle.naturelChaud,
                            );
                            if (context.mounted) _ouvrirPagePersonnalisation(context, vitrine.copyWith(modeleVisuel: ModeleVitrine.modeleF));
                          },
                          child: const Text('Choisir'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarteModeleSelection({
    required BuildContext context,
    required WidgetRef ref,
    required VitrineConfig vitrine,
    required ModeleVitrine modele,
    required String titre,
    required String secteur,
    required String description,
    required IconData icone,
    required Color couleurAccent,
    required Color couleurFond,
    required TypeActivite activite,
    required ThemeStyle style,
  }) {
    final estActif = vitrine.modeleVisuel == modele;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: estActif ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: estActif ? AppColors.green : const Color(0xFFE2E8F0),
          width: estActif ? 2.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: estActif ? AppColors.green.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
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
                  color: couleurFond,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icone, color: couleurAccent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text(secteur, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: couleurAccent)),
                  ],
                ),
              ),
              if (estActif)
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
                      Text('ACTIF', style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w900, fontSize: 10)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, height: 1.3)),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: estActif ? AppColors.green : const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 14),
                  label: Text(
                    estActif ? 'Personnaliser ce modèle' : 'Choisir & Personnaliser',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    await ref.read(vitrineActuelleProvider.notifier).changerModele(
                      activite: activite,
                      modele: modele,
                      style: style,
                    );
                    if (context.mounted) {
                      _ouvrirPagePersonnalisation(context, vitrine.copyWith(modeleVisuel: modele, typeActivite: activite, themeStyle: style));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  foregroundColor: const Color(0xFF334155),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.visibility_rounded, size: 14),
                label: const Text('Aperçu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                onPressed: () {
                  _ouvrirStudioPrevisualisation(context, vitrine.copyWith(modeleVisuel: modele));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
  }
}
// =============================================================================
// ONGLET 1 : GESTION DES RENDEZ-VOUS
// =============================================================================

class _OngletRendezVous extends ConsumerWidget {
  const _OngletRendezVous({required this.vitrine});
  final VitrineConfig vitrine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRdv = ref.watch(vitrineRendezVousProvider);

    return asyncRdv.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (liste) {
        if (liste.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), shape: BoxShape.circle),
                    child: const Icon(Icons.event_available_rounded, size: 48, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 16),
                  const Text('Aucune demande de rendez-vous', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text(
                    'Les demandes de rendez-vous envoyées par vos clients depuis votre site vitrine apparaîtront ici.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon: const Icon(Icons.language_rounded, size: 18),
                    label: const Text('Tester la réservation sur mon site'),
                    onPressed: () => context.push('/v/${vitrine.slug}'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.science_outlined, size: 16),
                    label: const Text('Créer un rendez-vous test d\'exemple'),
                    onPressed: () async {
                      var vitrineId = vitrine.id;
                      if (vitrineId.isEmpty) {
                        final vMaj = await ref.read(vitrineRepositoryProvider).sauvegarderVitrine(vitrine);
                        vitrineId = vMaj.id;
                        ref.invalidate(vitrineActuelleProvider);
                      }
                      final testRdv = VitrineRendezVous(
                        id: '',
                        vitrineId: vitrineId,
                        entrepriseId: vitrine.entrepriseId,
                        nomPrestation: 'Tresses & Brushing VIP',
                        dateSouhaitee: DateTime.now().add(const Duration(days: 1)),
                        heureSouhaitee: '14:30',
                        nomClient: 'Fatou Traoré (Client Test)',
                        telephoneClient: '+223 70 00 00 00',
                        messageClient: 'Bonjour, je souhaite confirmer ce créneau pour une coiffure complète.',
                        statut: StatutRendezVous.enAttente,
                      );
                      await ref.read(vitrineRepositoryProvider).creerDemandeRendezVous(testRdv);
                      ref.invalidate(vitrineRendezVousProvider);
                    },
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: liste.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final rdv = liste[i];
            return _RendezVousCard(rdv: rdv, vitrine: vitrine);
          },
        );
      },
    );
  }
}

class _RendezVousCard extends ConsumerWidget {
  const _RendezVousCard({required this.rdv, required this.vitrine});
  final VitrineRendezVous rdv;
  final VitrineConfig vitrine;

  Future<void> _confirmerParWhatsApp(BuildContext context, WidgetRef ref) async {
    final cleanPhone = rdv.telephoneClient.replaceAll(RegExp(r'[^0-9]'), '');
    final dateStr = '${rdv.dateSouhaitee.day.toString().padLeft(2, '0')}/${rdv.dateSouhaitee.month.toString().padLeft(2, '0')}/${rdv.dateSouhaitee.year}';
    final message = 'Bonjour *${rdv.nomClient}*, votre rendez-vous pour *${rdv.nomPrestation}* le *$dateStr* à *${rdv.heureSouhaitee}* chez *${vitrine.titreHero ?? "notre salon"}* est bien *CONFIRMÉ* ! À très bientôt.';

    final uri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    await ref.read(vitrineRendezVousProvider.notifier).changerStatut(rdv.id, StatutRendezVous.confirme);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color badgeColor;
    Color badgeTextColor;
    switch (rdv.statut) {
      case StatutRendezVous.enAttente:
        badgeColor = const Color(0xFFFEF3C7);
        badgeTextColor = const Color(0xFFD97706);
        break;
      case StatutRendezVous.confirme:
        badgeColor = const Color(0xFFDCFCE7);
        badgeTextColor = const Color(0xFF16A34A);
        break;
      case StatutRendezVous.refuse:
        badgeColor = const Color(0xFFFEE2E2);
        badgeTextColor = const Color(0xFFDC2626);
        break;
      case StatutRendezVous.termine:
        badgeColor = const Color(0xFFF1F5F9);
        badgeTextColor = const Color(0xFF475569);
        break;
    }

    final dateStr = '${rdv.dateSouhaitee.day.toString().padLeft(2, '0')}/${rdv.dateSouhaitee.month.toString().padLeft(2, '0')}/${rdv.dateSouhaitee.year}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rdv.nomPrestation,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(6)),
                child: Text(
                  rdv.statut.libelle,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: badgeTextColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 15, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text('$dateStr à ${rdv.heureSouhaitee}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
              const Spacer(),
              const Icon(Icons.person_rounded, size: 15, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(rdv.nomClient, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
            ],
          ),
          if (rdv.messageClient != null && rdv.messageClient!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Message: "${rdv.messageClient}"', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Color(0xFF64748B))),
          ],
          const Divider(height: 18),
          Row(
            children: [
              Text('📞 ${rdv.telephoneClient}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const Spacer(),
              if (rdv.statut == StatutRendezVous.enAttente) ...[
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 10)),
                  onPressed: () => ref.read(vitrineRendezVousProvider.notifier).changerStatut(rdv.id, StatutRendezVous.refuse),
                  child: const Text('Refuser'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366), padding: const EdgeInsets.symmetric(horizontal: 12)),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Confirmer & WhatsApp'),
                  onPressed: () => _confirmerParWhatsApp(context, ref),
                ),
              ] else ...[
                TextButton(
                  onPressed: () => ref.read(vitrineRendezVousProvider.notifier).changerStatut(rdv.id, StatutRendezVous.termine),
                  child: const Text('Marquer terminé'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// ONGLET 2 : PRESTATIONS & TARIFS
// =============================================================================

class _OngletPrestations extends ConsumerWidget {
  const _OngletPrestations({required this.vitrine});
  final VitrineConfig vitrine;

  Future<void> _ajouterPrestationRapide(
    BuildContext context,
    WidgetRef ref,
    String nom,
    int prix,
    int duree,
    String categorie,
  ) async {
    var vitrineId = vitrine.id;
    if (vitrineId.isEmpty) {
      final vMaj = await ref.read(vitrineRepositoryProvider).sauvegarderVitrine(vitrine);
      vitrineId = vMaj.id;
      ref.invalidate(vitrineActuelleProvider);
    }
    final p = VitrinePrestation(
      id: '',
      vitrineId: vitrineId,
      entrepriseId: vitrine.entrepriseId,
      nom: nom,
      prix: prix,
      dureeMinutes: duree,
      categorie: categorie,
    );
    await ref.read(vitrineRepositoryProvider).sauvegarderPrestation(p);
    ref.invalidate(vitrinePrestationsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Prestation « $nom » ajoutée avec succès !'),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _ouvrirDialoguePrestation(BuildContext context, WidgetRef ref, [VitrinePrestation? prestation]) {
    final nomCtrl = TextEditingController(text: prestation?.nom ?? '');
    final descCtrl = TextEditingController(text: prestation?.description ?? '');
    final prixCtrl = TextEditingController(text: prestation != null ? '${prestation.prix}' : '');
    final dureeCtrl = TextEditingController(text: prestation?.dureeMinutes != null ? '${prestation!.dureeMinutes}' : '');
    final catCtrl = TextEditingController(text: prestation?.categorie ?? '');

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(prestation == null ? 'Ajouter une prestation' : 'Modifier la prestation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomCtrl,
                decoration: const InputDecoration(labelText: 'Nom de la prestation *', hintText: 'ex: Tresses Braids, Brushing...'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: catCtrl,
                decoration: const InputDecoration(labelText: 'Catégorie', hintText: 'ex: Tresses, Soins, Coupes...'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: prixCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Prix en FCFA *', suffixText: 'FCFA'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dureeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Durée estimée (minutes)', hintText: 'ex: 45, 90, 120'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description (facultatif)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: () async {
              if (nomCtrl.text.trim().isEmpty || prixCtrl.text.trim().isEmpty) return;
              var vitrineId = vitrine.id;
              if (vitrineId.isEmpty) {
                final vMaj = await ref.read(vitrineRepositoryProvider).sauvegarderVitrine(vitrine);
                vitrineId = vMaj.id;
                ref.invalidate(vitrineActuelleProvider);
              }
              final p = VitrinePrestation(
                id: prestation?.id ?? '',
                vitrineId: vitrineId,
                entrepriseId: vitrine.entrepriseId,
                nom: nomCtrl.text.trim(),
                description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                prix: int.tryParse(prixCtrl.text.trim()) ?? 0,
                dureeMinutes: int.tryParse(dureeCtrl.text.trim()),
                categorie: catCtrl.text.trim().isEmpty ? null : catCtrl.text.trim(),
              );
              await ref.read(vitrineRepositoryProvider).sauvegarderPrestation(p);
              ref.invalidate(vitrinePrestationsProvider);
              if (context.mounted) Navigator.pop(dlgCtx);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPrestas = ref.watch(vitrinePrestationsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter une prestation'),
        onPressed: () => _ouvrirDialoguePrestation(context, ref),
      ),
      body: asyncPrestas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (prestations) {
          if (prestations.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.content_cut_rounded, size: 48, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    const Text('Aucune prestation enregistrée', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 6),
                    const Text('Ajoutez vos prestations de coiffure, soins ou services avec leurs tarifs en FCFA.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Créer ma première prestation'),
                      onPressed: () => _ouvrirDialoguePrestation(context, ref),
                    ),
                    const SizedBox(height: 24),
                    const Text('Ou ajoutez des modèles prêts en 1 clic :', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF475569))),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.content_cut_rounded, size: 16, color: AppColors.green),
                          label: const Text('Tresses Braids (15 000 F)'),
                          onPressed: () => _ajouterPrestationRapide(context, ref, 'Tresses Braids', 15000, 120, 'Tresses'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.content_cut_rounded, size: 16, color: AppColors.green),
                          label: const Text('Coupe & Dégradé (3 000 F)'),
                          onPressed: () => _ajouterPrestationRapide(context, ref, 'Coupe & Dégradé', 3000, 30, 'Coupes'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.spa_rounded, size: 16, color: AppColors.green),
                          label: const Text('Brushing & Soin (8 000 F)'),
                          onPressed: () => _ajouterPrestationRapide(context, ref, 'Brushing & Soin', 8000, 60, 'Soins'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.face_rounded, size: 16, color: AppColors.green),
                          label: const Text('Pose Perruque (10 000 F)'),
                          onPressed: () => _ajouterPrestationRapide(context, ref, 'Pose Perruque', 10000, 90, 'Perruques'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: prestations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final p = prestations[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.spa_rounded, color: AppColors.green),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.nom, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                          if (p.categorie != null)
                            Text(p.categorie!, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('${p.prix} FCFA', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.green, fontSize: 14)),
                              if (p.dureeFormatee != null) ...[
                                const Text(' · ', style: TextStyle(color: Color(0xFF94A3B8))),
                                Text(p.dureeFormatee!, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _ouvrirDialoguePrestation(context, ref, p),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                      onPressed: () async {
                        await ref.read(vitrineRepositoryProvider).supprimerPrestation(p.id);
                        ref.invalidate(vitrinePrestationsProvider);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// =============================================================================
// ONGLET 3 : GALERIE DE RÉALISATIONS
// =============================================================================

class _OngletGalerie extends ConsumerWidget {
  const _OngletGalerie({required this.vitrine});
  final VitrineConfig vitrine;

  Future<void> _ajouterPhotoExemple(
    BuildContext context,
    WidgetRef ref,
    String titre,
    String categorie,
    String url,
  ) async {
    var vitrineId = vitrine.id;
    if (vitrineId.isEmpty) {
      final vMaj = await ref.read(vitrineRepositoryProvider).sauvegarderVitrine(vitrine);
      vitrineId = vMaj.id;
      ref.invalidate(vitrineActuelleProvider);
    }
    final item = VitrineGalerieItem(
      id: '',
      vitrineId: vitrineId,
      entrepriseId: vitrine.entrepriseId,
      titre: titre,
      categorie: categorie,
      photoUrl: url,
    );
    await ref.read(vitrineRepositoryProvider).ajouterPhotoGalerie(item);
    ref.invalidate(vitrineGalerieProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo « $titre » ajoutée avec succès !'),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _ajouterPhoto(BuildContext context, WidgetRef ref) {
    final catCtrl = TextEditingController(text: 'Coiffures');
    final titreCtrl = TextEditingController(text: 'Réalisation');
    final urlCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ajouter une photo à la galerie'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titreCtrl, decoration: const InputDecoration(labelText: 'Titre (ex: Tresses Braids, Dégradé...)')),
              const SizedBox(height: 10),
              TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Catégorie (ex: Nattes, Coupes, Soins)')),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.green),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
                icon: const Icon(Icons.add_a_photo_rounded, color: AppColors.green),
                label: const Text('Prendre ou choisir une photo'),
                onPressed: () async {
                  final p = await MediaPickerHelper.choisirPhotoDetail(context);
                  if (p != null) {
                    // Upload ou photo directe
                    urlCtrl.text = 'https://images.unsplash.com/photo-1560869713-7d0a49430803?w=600&auto=format&fit=crop&q=80';
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'Lien ou chemin de la photo (facultatif)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: () async {
              var vitrineId = vitrine.id;
              if (vitrineId.isEmpty) {
                final vMaj = await ref.read(vitrineRepositoryProvider).sauvegarderVitrine(vitrine);
                vitrineId = vMaj.id;
                ref.invalidate(vitrineActuelleProvider);
              }
              final finalUrl = urlCtrl.text.trim().isNotEmpty
                  ? urlCtrl.text.trim()
                  : 'https://images.unsplash.com/photo-1560869713-7d0a49430803?w=600&auto=format&fit=crop&q=80';
              final item = VitrineGalerieItem(
                id: '',
                vitrineId: vitrineId,
                entrepriseId: vitrine.entrepriseId,
                titre: titreCtrl.text.trim().isEmpty ? null : titreCtrl.text.trim(),
                categorie: catCtrl.text.trim().isEmpty ? null : catCtrl.text.trim(),
                photoUrl: finalUrl,
              );
              await ref.read(vitrineRepositoryProvider).ajouterPhotoGalerie(item);
              ref.invalidate(vitrineGalerieProvider);
              if (context.mounted) Navigator.pop(dlgCtx);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncGalerie = ref.watch(vitrineGalerieProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo_rounded),
        label: const Text('Ajouter une photo'),
        onPressed: () => _ajouterPhoto(context, ref),
      ),
      body: asyncGalerie.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (photos) {
          if (photos.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_library_outlined, size: 48, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    const Text('Galerie vide', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 6),
                    const Text('Ajoutez des photos de vos réalisations pour séduire vos clients.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                      icon: const Icon(Icons.add_a_photo_rounded),
                      label: const Text('Ajouter une photo'),
                      onPressed: () => _ajouterPhoto(context, ref),
                    ),
                    const SizedBox(height: 24),
                    const Text('Ou ajoutez des photos d\'exemple en 1 clic :', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF475569))),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFFD97706)),
                          label: const Text('+ Tresses Braids'),
                          onPressed: () => _ajouterPhotoExemple(
                            context,
                            ref,
                            'Tresses Braids',
                            'Tresses',
                            'https://images.unsplash.com/photo-1560869713-7d0a49430803?w=600&auto=format&fit=crop&q=80',
                          ),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF2563EB)),
                          label: const Text('+ Dégradé Homme'),
                          onPressed: () => _ajouterPhotoExemple(
                            context,
                            ref,
                            'Dégradé Waves',
                            'Coupes',
                            'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=600&auto=format&fit=crop&q=80',
                          ),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFFDB2777)),
                          label: const Text('+ Brushing & Soin'),
                          onPressed: () => _ajouterPhotoExemple(
                            context,
                            ref,
                            'Brushing & Soin',
                            'Soins',
                            'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=600&auto=format&fit=crop&q=80',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: photos.length,
            itemBuilder: (ctx, i) {
              final g = photos[i];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                        child: Image.network(
                          MediaHybridResolver.resolvePublicUrl(g.photoUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(color: const Color(0xFFF1F5F9), child: const Icon(Icons.image_not_supported_rounded, color: Color(0xFF94A3B8))),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(g.titre ?? 'Réalisation', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13), maxLines: 1),
                                if (g.categorie != null)
                                  Text(g.categorie!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                            onPressed: () async {
                              await ref.read(vitrineRepositoryProvider).supprimerPhotoGalerie(g.id);
                              ref.invalidate(vitrineGalerieProvider);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// =============================================================================
// ONGLET 4 : NOTRE ÉQUIPE
// =============================================================================

class _OngletEquipe extends ConsumerWidget {
  const _OngletEquipe({required this.vitrine});
  final VitrineConfig vitrine;

  Future<void> _ajouterMembreRapide(
    BuildContext context,
    WidgetRef ref,
    String nom,
    String role,
  ) async {
    var vitrineId = vitrine.id;
    if (vitrineId.isEmpty) {
      final vMaj = await ref.read(vitrineRepositoryProvider).sauvegarderVitrine(vitrine);
      vitrineId = vMaj.id;
      ref.invalidate(vitrineActuelleProvider);
    }
    final m = VitrineMembreEquipe(
      id: '',
      vitrineId: vitrineId,
      entrepriseId: vitrine.entrepriseId,
      nom: nom,
      roleSpecialite: role,
      presentation: 'Spécialiste qualifié(e) chez ${vitrine.titreHero ?? "notre établissement"}.',
    );
    await ref.read(vitrineRepositoryProvider).sauvegarderMembreEquipe(m);
    ref.invalidate(vitrineEquipeProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Membre « $nom » ajouté à l\'équipe !'),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _ajouterMembre(BuildContext context, WidgetRef ref) {
    final nomCtrl = TextEditingController();
    final roleCtrl = TextEditingController(text: 'Coiffeur / Coiffeuse');
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ajouter un membre à l\'équipe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nomCtrl, decoration: const InputDecoration(labelText: 'Nom et prénom *', hintText: 'ex: Aminata Diallo')),
            const SizedBox(height: 10),
            TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: 'Rôle ou spécialité', hintText: 'ex: Spécialiste Locks, Coloriste...')),
            const SizedBox(height: 10),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Présentation')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: () async {
              if (nomCtrl.text.trim().isEmpty) return;
              var vitrineId = vitrine.id;
              if (vitrineId.isEmpty) {
                final vMaj = await ref.read(vitrineRepositoryProvider).sauvegarderVitrine(vitrine);
                vitrineId = vMaj.id;
                ref.invalidate(vitrineActuelleProvider);
              }
              final m = VitrineMembreEquipe(
                id: '',
                vitrineId: vitrineId,
                entrepriseId: vitrine.entrepriseId,
                nom: nomCtrl.text.trim(),
                roleSpecialite: roleCtrl.text.trim(),
                presentation: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
              );
              await ref.read(vitrineRepositoryProvider).sauvegarderMembreEquipe(m);
              ref.invalidate(vitrineEquipeProvider);
              if (context.mounted) Navigator.pop(dlgCtx);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEquipe = ref.watch(vitrineEquipeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Ajouter un membre'),
        onPressed: () => _ajouterMembre(context, ref),
      ),
      body: asyncEquipe.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (membres) {
          if (membres.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.groups_rounded, size: 48, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    const Text('Aucun membre dans l\'équipe', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 6),
                    const Text('Présentez vos coiffeurs, maquilleurs et spécialistes pour rassurer vos clients.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                      icon: const Icon(Icons.person_add_rounded),
                      label: const Text('Ajouter un professionnel'),
                      onPressed: () => _ajouterMembre(context, ref),
                    ),
                    const SizedBox(height: 24),
                    const Text('Ou ajoutez un profil prêt en 1 clic :', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF475569))),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.green),
                          label: const Text('+ Aminata Diallo (Coiffeuse & Tresses)'),
                          onPressed: () => _ajouterMembreRapide(context, ref, 'Aminata Diallo', 'Coiffeuse & Spécialiste Tresses'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF2563EB)),
                          label: const Text('+ Moussa Traoré (Barbier & Coupe)'),
                          onPressed: () => _ajouterMembreRapide(context, ref, 'Moussa Traoré', 'Barbier & Maître Coupe'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: membres.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final m = membres[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFE2E8F0),
                      child: Text(m.nom.isNotEmpty ? m.nom.characters.first.toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.nom, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                          if (m.roleSpecialite != null)
                            Text(m.roleSpecialite!, style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700, fontSize: 13)),
                          if (m.presentation != null)
                            Text(m.presentation!, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      onPressed: () async {
                        await ref.read(vitrineRepositoryProvider).supprimerMembreEquipe(m.id);
                        ref.invalidate(vitrineEquipeProvider);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// =============================================================================
// ONGLET 5 : PRODUITS EN VITRINE
// =============================================================================

class _OngletProduits extends ConsumerStatefulWidget {
  const _OngletProduits({required this.vitrine});
  final VitrineConfig vitrine;

  @override
  ConsumerState<_OngletProduits> createState() => _OngletProduitsState();
}

class _OngletProduitsState extends ConsumerState<_OngletProduits> {
  final TextEditingController _rechercheCtrl = TextEditingController();
  String _filtre = 'tous'; // 'tous', 'en_ligne', 'masques', 'en_promo'

  @override
  void dispose() {
    _rechercheCtrl.dispose();
    super.dispose();
  }

  void _ouvrirDialogueProduit(BuildContext context, [VitrineProduitItem? produit]) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _DialogueAjoutOuModifProduitVitrine(vitrine: widget.vitrine, produit: produit),
    );
  }

  Future<void> _toutPublier(List<VitrineProduitItem> liste) async {
    final notifier = ref.read(vitrineProduitsAdminProvider.notifier);
    final aPublier = liste.where((p) => !p.estPublie).toList();
    if (aPublier.isEmpty) return;
    for (final p in aPublier) {
      await notifier.basculerPublication(p.id, true);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${aPublier.length} produit(s) publié(s) en ligne avec succès !'),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toutMasquer(List<VitrineProduitItem> liste) async {
    final notifier = ref.read(vitrineProduitsAdminProvider.notifier);
    final aMasquer = liste.where((p) => p.estPublie).toList();
    if (aMasquer.isEmpty) return;
    for (final p in aMasquer) {
      await notifier.basculerPublication(p.id, false);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${aMasquer.length} produit(s) masqué(s) de la vitrine.'),
          backgroundColor: const Color(0xFF64748B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _chargerExemplesDemo(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(vitrineProduitsAdminProvider.notifier);
    final isTech = widget.vitrine.typeActivite == TypeActivite.boutiqueTech || widget.vitrine.modeleVisuel == ModeleVitrine.modeleB;
    final isBeauty = widget.vitrine.typeActivite == TypeActivite.cosmetiqueBeaute || widget.vitrine.typeActivite == TypeActivite.salonCoiffure;

    final exemples = isBeauty
        ? [
            const VitrineProduitItem(
              id: '',
              nom: 'Crème Hydratante Bio Éclat Karité',
              description: 'Formule 100% naturelle enrichie au beurre de karité et aloe vera.',
              prix: 8500,
              prixBarre: 12000,
              photoUrl: 'https://images.unsplash.com/photo-1556228720-195a672e8a03?w=600&q=80',
              estPublie: true,
            ),
            const VitrineProduitItem(
              id: '',
              nom: 'Sérum Réparateur Nuit Argan Pur',
              description: 'Nourrit en profondeur, régénère et apporte un éclat radieux au réveil.',
              prix: 14000,
              prixBarre: 18000,
              photoUrl: 'https://images.unsplash.com/photo-1620916566398-39f1143ab7be?w=600&q=80',
              estPublie: true,
            ),
            const VitrineProduitItem(
              id: '',
              nom: 'Perruque Lace Front HD Ondulée 24"',
              description: 'Mèches 100% Raw Hair vierges, dentelle invisible indétectable.',
              prix: 75000,
              prixBarre: 95000,
              photoUrl: 'https://images.unsplash.com/photo-1560066984-138dadb4c035?w=600&q=80',
              estPublie: true,
            ),
            const VitrineProduitItem(
              id: '',
              nom: 'Shampoing Clarifiant Sans Sulfate',
              description: 'Nettoie en douceur sans agresser le cuir chevelu. Idéal pour mèches.',
              prix: 6500,
              photoUrl: 'https://images.unsplash.com/photo-1535585209827-a15fcdbc4c2d?w=600&q=80',
              estPublie: true,
            ),
          ]
        : isTech
            ? [
                const VitrineProduitItem(
                  id: '',
                  nom: 'Écouteurs Wireless ANC Pro 2',
                  description: 'Réduction de bruit active, autonomie 30h, son spatial haute fidélité.',
                  prix: 18500,
                  prixBarre: 25000,
                  photoUrl: 'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?w=600&q=80',
                  estPublie: true,
                ),
                const VitrineProduitItem(
                  id: '',
                  nom: 'Smartwatch Ultra Sport Active',
                  description: 'Écran AMOLED HD, suivi cardiaque, sommeil, notifications WhatsApp.',
                  prix: 28000,
                  prixBarre: 38000,
                  photoUrl: 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=600&q=80',
                  estPublie: true,
                ),
                const VitrineProduitItem(
                  id: '',
                  nom: 'Enceinte Portable Bluetooth BoomBass',
                  description: 'Waterproof IPX7, basses profondes 360°, batterie 20h non-stop.',
                  prix: 22000,
                  prixBarre: 30000,
                  photoUrl: 'https://images.unsplash.com/photo-1545454675-3531b543be5d?w=600&q=80',
                  estPublie: true,
                ),
                const VitrineProduitItem(
                  id: '',
                  nom: 'Power Bank Rapide 20 000 mAh 65W',
                  description: 'Recharge express pour smartphones, iPhone, tablettes et PC portables.',
                  prix: 14500,
                  prixBarre: 19000,
                  photoUrl: 'https://images.unsplash.com/photo-1609592806596-b38466632488?w=600&q=80',
                  estPublie: true,
                ),
                const VitrineProduitItem(
                  id: '',
                  nom: 'Station de Charge 3-en-1 Sans Fil',
                  description: 'Charge simultanément votre téléphone, montre et écouteurs sans fil.',
                  prix: 16000,
                  prixBarre: 22000,
                  photoUrl: 'https://images.unsplash.com/photo-1586953208448-b95a79798f07?w=600&q=80',
                  estPublie: true,
                ),
                const VitrineProduitItem(
                  id: '',
                  nom: 'Drone Compact 4K Ultra HD',
                  description: 'Stabilisation 3 axes, retour automatique GPS, double batterie incluse.',
                  prix: 55000,
                  prixBarre: 75000,
                  photoUrl: 'https://images.unsplash.com/photo-1527977966376-1c8408f9f108?w=600&q=80',
                  estPublie: true,
                ),
              ]
            : [
                const VitrineProduitItem(
                  id: '',
                  nom: 'Pack Tendance Mode & Style',
                  description: 'Qualité premium, finitions soignées, disponible en plusieurs tailles.',
                  prix: 15000,
                  prixBarre: 20000,
                  photoUrl: 'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=600&q=80',
                  estPublie: true,
                ),
                const VitrineProduitItem(
                  id: '',
                  nom: 'Chaussures Sneaker Urban Confort',
                  description: 'Semelle ergonomique respirante, style urbain intemporel.',
                  prix: 22000,
                  prixBarre: 28000,
                  photoUrl: 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=600&q=80',
                  estPublie: true,
                ),
                const VitrineProduitItem(
                  id: '',
                  nom: 'Sac Élégance Cuir Citadin',
                  description: 'Design épuré, compartiments multiples pour ordinateur et effets.',
                  prix: 25000,
                  prixBarre: 35000,
                  photoUrl: 'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=600&q=80',
                  estPublie: true,
                ),
                const VitrineProduitItem(
                  id: '',
                  nom: 'Lunettes de Soleil Polarisées UV400',
                  description: 'Protection totale contre les reflets et UV, monture ultra-légère.',
                  prix: 9500,
                  prixBarre: 14000,
                  photoUrl: 'https://images.unsplash.com/photo-1511499767150-a48a237f0083?w=600&q=80',
                  estPublie: true,
                ),
              ];

    for (final ex in exemples) {
      await notifier.sauvegarderProduit(ex);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${exemples.length} produits exemples ajoutés avec succès !'),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncProduits = ref.watch(vitrineProduitsAdminProvider);

    return asyncProduits.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text('Erreur de chargement des produits : $err', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(vitrineProduitsAdminProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
      data: (produits) {
        final totalPublies = produits.where((p) => p.estPublie).length;
        final totalMasques = produits.length - totalPublies;
        final totalPromos = produits.where((p) => p.aPromotion && p.prixBarre != null && p.prixBarre! > p.prix).length;

        // Filtrage dynamique
        final query = _rechercheCtrl.text.trim().toLowerCase();
        List<VitrineProduitItem> filtres = produits;
        if (query.isNotEmpty) {
          filtres = filtres.where((p) =>
            p.nom.toLowerCase().contains(query) || (p.description?.toLowerCase().contains(query) ?? false)
          ).toList();
        }
        if (_filtre == 'en_ligne') {
          filtres = filtres.where((p) => p.estPublie).toList();
        } else if (_filtre == 'masques') {
          filtres = filtres.where((p) => !p.estPublie).toList();
        } else if (_filtre == 'en_promo') {
          filtres = filtres.where((p) => p.aPromotion && p.prixBarre != null && p.prixBarre! > p.prix).toList();
        }

        return Column(
          children: [
            // Barre supérieure : Recherche + Filtres + Actions de masse
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Champ de recherche
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: _rechercheCtrl,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Rechercher parmi vos ${produits.length} produits...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                        suffixIcon: _rechercheCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  _rechercheCtrl.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Chips de filtrage rapide
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('tous', 'Tous (${produits.length})'),
                        const SizedBox(width: 6),
                        _buildFilterChip('en_ligne', 'En ligne ($totalPublies)'),
                        const SizedBox(width: 6),
                        _buildFilterChip('masques', 'Masqués ($totalMasques)'),
                        const SizedBox(width: 6),
                        _buildFilterChip('en_promo', 'En promo ($totalPromos)'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Barre d'actions en masse (Tout publier en 1 clic)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$totalPublies en ligne sur ${produits.length}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                        ),
                      ),
                      if (totalMasques > 0)
                        InkWell(
                          onTap: () => _toutPublier(produits),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.flash_on_rounded, size: 13, color: Color(0xFF15803D)),
                                SizedBox(width: 4),
                                Text('⚡ Tout publier', style: TextStyle(color: Color(0xFF15803D), fontSize: 11, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ),
                      if (totalMasques > 0 && totalPublies > 0) const SizedBox(width: 6),
                      if (totalPublies > 0)
                        InkWell(
                          onTap: () => _toutMasquer(produits),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.visibility_off_outlined, size: 13, color: Color(0xFF64748B)),
                                SizedBox(width: 4),
                                Text('Tout masquer', style: TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Liste des produits ou état vide
            Expanded(
              child: filtres.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                              child: const Icon(Icons.storefront_rounded, size: 54, color: AppColors.green),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              query.isNotEmpty || _filtre != 'tous'
                                  ? 'Aucun produit ne correspond au filtre'
                                  : 'Aucun produit dans votre catalogue vitrine',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              query.isNotEmpty || _filtre != 'tous'
                                  ? 'Essayez de réinitialiser la recherche ou le filtre.'
                                  : 'Ajoutez directement vos articles avec photo et prix en FCFA.\nVos clients pourront les commander en un clic sur WhatsApp !',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 20),
                              label: const Text('Ajouter un produit', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                              onPressed: () => _ouvrirDialogueProduit(context),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF4F46E5),
                                side: const BorderSide(color: Color(0xFF818CF8)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                              label: const Text('⚡ Charger 6 produits démo de qualité', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                              onPressed: () => _chargerExemplesDemo(context, ref),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtres.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final p = filtres[i];
                        return _CarteProduitVitrine(
                          produit: p,
                          onEditer: () => _ouvrirDialogueProduit(context, p),
                          onBasculerPublie: (val) {
                            ref.read(vitrineProduitsAdminProvider.notifier).basculerPublication(p.id, val);
                          },
                          onSupprimer: () async {
                            final conf = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('Retirer ce produit ?'),
                                content: Text('Voulez-vous retirer "${p.nom}" de votre vitrine ?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
                                  FilledButton(
                                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('Retirer'),
                                  ),
                                ],
                              ),
                            );
                            if (conf == true) {
                              await ref.read(vitrineProduitsAdminProvider.notifier).supprimerProduit(p.id);
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String cle, String label) {
    final actif = _filtre == cle;
    return InkWell(
      onTap: () => setState(() => _filtre = cle),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: actif ? AppColors.green : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: actif ? AppColors.green : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: actif ? FontWeight.w800 : FontWeight.w600,
            color: actif ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

class _CarteProduitVitrine extends StatelessWidget {
  const _CarteProduitVitrine({
    required this.produit,
    required this.onEditer,
    required this.onBasculerPublie,
    required this.onSupprimer,
  });

  final VitrineProduitItem produit;
  final VoidCallback onEditer;
  final ValueChanged<bool> onBasculerPublie;
  final VoidCallback onSupprimer;

  @override
  Widget build(BuildContext context) {
    final photo = produit.photoPrincipale;
    final aVraiePromo = produit.aPromotion && produit.prixBarre != null && produit.prixBarre! > produit.prix;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: produit.estPublie ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo du produit (carré 72x72)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 72,
              height: 72,
              child: photo != null && photo.isNotEmpty
                  ? Image.network(
                      MediaHybridResolver.resolvePublicUrl(photo),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xFFF1F5F9),
                        child: const Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8)),
                      ),
                    )
                  : Container(
                      color: const Color(0xFFF1F5F9),
                      child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF94A3B8), size: 30),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Détails du produit
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre sur 2 lignes complètes sans coupure prématurée
                Text(
                  produit.nom,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A), height: 1.25),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (produit.description != null && produit.description!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    produit.description!,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${produit.prix} FCFA',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.green),
                    ),
                    if (aVraiePromo) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${produit.prixBarre} F',
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(4)),
                        child: const Text('PROMO', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w900, fontSize: 9)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      produit.estPublie ? 'Visible' : 'Masqué',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: produit.estPublie ? AppColors.green : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: produit.estPublie,
                        activeThumbColor: AppColors.green,
                        onChanged: onBasculerPublie,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF475569)),
                      tooltip: 'Modifier',
                      onPressed: onEditer,
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                      tooltip: 'Retirer',
                      onPressed: onSupprimer,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogueAjoutOuModifProduitVitrine extends ConsumerStatefulWidget {
  const _DialogueAjoutOuModifProduitVitrine({required this.vitrine, this.produit});
  final VitrineConfig vitrine;
  final VitrineProduitItem? produit;

  @override
  ConsumerState<_DialogueAjoutOuModifProduitVitrine> createState() => _DialogueAjoutOuModifProduitVitrineState();
}

class _DialogueAjoutOuModifProduitVitrineState extends ConsumerState<_DialogueAjoutOuModifProduitVitrine> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomCtrl;
  late final TextEditingController _prixCtrl;
  late final TextEditingController _prixBarreCtrl;
  late final TextEditingController _photoUrlCtrl;
  late final TextEditingController _descCtrl;
  bool _estPublie = true;
  bool _enSauvegarde = false;

  @override
  void initState() {
    super.initState();
    final p = widget.produit;
    _nomCtrl = TextEditingController(text: p?.nom ?? '');
    _prixCtrl = TextEditingController(text: p != null ? p.prix.toString() : '');
    _prixBarreCtrl = TextEditingController(text: p?.prixBarre != null ? p!.prixBarre.toString() : '');
    _photoUrlCtrl = TextEditingController(text: p?.photoPrincipale ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _estPublie = p?.estPublie ?? true;
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prixCtrl.dispose();
    _prixBarreCtrl.dispose();
    _photoUrlCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _choisirPhotoLocale() async {
    final res = await MediaPickerHelper.choisirPhotoDetail(context);
    if (res != null) {
      setState(() => _photoUrlCtrl.text = 'https://images.unsplash.com/photo-1526738549149-8e07eca6c147?w=600&auto=format&fit=crop&q=80');
    }
  }

  void _choisirPhotoSuggestion(String url) {
    setState(() => _photoUrlCtrl.text = url);
  }

  Future<void> _validerEtEnregistrer() async {
    if (!_formKey.currentState!.validate()) return;

    final prix = int.tryParse(_prixCtrl.text.trim()) ?? 0;
    final prixBarre = int.tryParse(_prixBarreCtrl.text.trim());

    setState(() => _enSauvegarde = true);

    final item = VitrineProduitItem(
      id: widget.produit?.id ?? '',
      nom: _nomCtrl.text.trim(),
      description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      prix: prix,
      prixBarre: prixBarre,
      photoUrl: _photoUrlCtrl.text.trim().isNotEmpty ? _photoUrlCtrl.text.trim() : null,
      estPublie: _estPublie,
    );

    try {
      await ref.read(vitrineProduitsAdminProvider.notifier).sauvegarderProduit(item);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.produit == null ? 'Produit ajouté et publié en vitrine !' : 'Produit mis à jour !'),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _enSauvegarde = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final estModif = widget.produit != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    estModif ? 'Modifier le produit' : 'Ajouter un produit en vitrine',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Nom
              TextFormField(
                controller: _nomCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom du produit *',
                  hintText: 'Ex: Écouteurs sans fil Pro, Robe Wax, Perruque HD',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shopping_bag_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Veuillez saisir un nom' : null,
              ),
              const SizedBox(height: 12),

              // Prix et Promo
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _prixCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Prix public (FCFA) *',
                        hintText: 'Ex: 15000',
                        border: OutlineInputBorder(),
                        suffixText: 'FCFA',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Prix requis';
                        if (int.tryParse(v.trim()) == null) return 'Prix invalide';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _prixBarreCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Prix barré (promo)',
                        hintText: 'Ex: 20000',
                        border: OutlineInputBorder(),
                        suffixText: 'FCFA',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Photo
              TextFormField(
                controller: _photoUrlCtrl,
                decoration: InputDecoration(
                  labelText: 'Photo (URL ou fichier)',
                  hintText: 'https://... ou fichier local',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.photo_outlined),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add_photo_alternate_rounded, color: AppColors.green),
                    tooltip: 'Choisir depuis l\'appareil',
                    onPressed: _choisirPhotoLocale,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Suggestions de photos prédéfinies de qualité pro
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.headphones_rounded, size: 14),
                    label: const Text('Audio', style: TextStyle(fontSize: 11)),
                    onPressed: () => _choisirPhotoSuggestion('https://images.unsplash.com/photo-1590658268037-6bf12165a8df?w=600&q=80'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.watch_rounded, size: 14),
                    label: const Text('Montre', style: TextStyle(fontSize: 11)),
                    onPressed: () => _choisirPhotoSuggestion('https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=600&q=80'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.spa_rounded, size: 14),
                    label: const Text('Cosmétique', style: TextStyle(fontSize: 11)),
                    onPressed: () => _choisirPhotoSuggestion('https://images.unsplash.com/photo-1556228720-195a672e8a03?w=600&q=80'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.checkroom_rounded, size: 14),
                    label: const Text('Mode', style: TextStyle(fontSize: 11)),
                    onPressed: () => _choisirPhotoSuggestion('https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=600&q=80'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description publique',
                  hintText: 'Points forts, caractéristiques, garantie...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),

              // Publication switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Publier immédiatement sur la vitrine', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                subtitle: const Text('Le produit sera visible par vos clients et commandable par WhatsApp', style: TextStyle(fontSize: 11)),
                value: _estPublie,
                activeThumbColor: AppColors.green,
                onChanged: (v) => setState(() => _estPublie = v),
              ),
              const SizedBox(height: 16),

              // Bouton Enregistrer
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _enSauvegarde ? null : _validerEtEnregistrer,
                  child: _enSauvegarde
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          estModif ? 'Enregistrer les modifications' : 'Ajouter et publier en vitrine',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
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

// =============================================================================
// ONGLET 6 : RÉGLAGES & SECTIONS
// =============================================================================

class _OngletApparence extends ConsumerStatefulWidget {
  const _OngletApparence({required this.vitrine});
  final VitrineConfig vitrine;

  @override
  ConsumerState<_OngletApparence> createState() => _OngletApparenceState();
}

class _OngletApparenceState extends ConsumerState<_OngletApparence> {
  late final TextEditingController _titreHeroCtrl;
  late final TextEditingController _sloganCtrl;
  late final TextEditingController _logoUrlCtrl;
  late final TextEditingController _banniereUrlCtrl;
  late ModeleVitrine _modeleChoisi;
  late ThemeStyle _styleChoisi;
  late VitrineSections _sections;
  bool _enSauvegarde = false;

  @override
  void initState() {
    super.initState();
    final v = widget.vitrine;
    _titreHeroCtrl = TextEditingController(text: v.titreHero ?? '');
    _sloganCtrl = TextEditingController(text: v.slogan ?? '');
    _logoUrlCtrl = TextEditingController(text: v.logoUrl ?? '');
    _banniereUrlCtrl = TextEditingController(text: v.banniereUrl ?? '');
    _modeleChoisi = v.modeleVisuel;
    _styleChoisi = v.themeStyle;
    _sections = v.sections;
  }

  @override
  void dispose() {
    _titreHeroCtrl.dispose();
    _sloganCtrl.dispose();
    _logoUrlCtrl.dispose();
    _banniereUrlCtrl.dispose();
    super.dispose();
  }

  void _choisirPresetBanniere(String url) {
    setState(() => _banniereUrlCtrl.text = url);
  }

  Future<void> _enregistrerApparence() async {
    setState(() => _enSauvegarde = true);
    final v = widget.vitrine;
    final maj = v.copyWith(
      titreHero: _titreHeroCtrl.text.trim().isNotEmpty ? _titreHeroCtrl.text.trim() : null,
      slogan: _sloganCtrl.text.trim().isNotEmpty ? _sloganCtrl.text.trim() : null,
      logoUrl: _logoUrlCtrl.text.trim().isNotEmpty ? _logoUrlCtrl.text.trim() : null,
      banniereUrl: _banniereUrlCtrl.text.trim().isNotEmpty ? _banniereUrlCtrl.text.trim() : null,
      modeleVisuel: _modeleChoisi,
      themeStyle: _styleChoisi,
      sections: _sections,
    );

    await ref.read(vitrineActuelleProvider.notifier).sauvegarder(maj);
    if (mounted) {
      setState(() => _enSauvegarde = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Apparence de votre site enregistrée avec succès !'),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Carte 1 : Identité & Bannière d'Accueil (Hero)
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.storefront_rounded, color: Color(0xFF15803D), size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text('Identité & Bannière d\'Accueil', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
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
                    labelText: 'URL du logo',
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
                const SizedBox(height: 8),
                const Text('Photos HD prêtes en 1 clic selon votre activité :', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
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
        const SizedBox(height: 14),

        // Carte 2 : Choix du Modèle Visuel
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.palette_rounded, color: Color(0xFF4F46E5), size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text('Modèle Visuel & Style de Design', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                for (final m in ModeleVitrine.values)
                  RadioListTile<ModeleVitrine>(
                    contentPadding: EdgeInsets.zero,
                    value: m,
                    groupValue: _modeleChoisi,
                    title: Text(m.titre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    subtitle: Text(m.description, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    activeColor: AppColors.green,
                    onChanged: (v) {
                      if (v != null) setState(() => _modeleChoisi = v);
                    },
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
        const SizedBox(height: 14),

        // Carte 3 : Organisation des Sections Actives
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.layers_rounded, color: Color(0xFFD97706), size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text('Organisation des Sections', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
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
                  title: const Text('Prestations & Services', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: const Text('Coiffures, soins, rendez-vous et interventions', style: TextStyle(fontSize: 11)),
                  value: _sections.prestations,
                  activeThumbColor: AppColors.green,
                  onChanged: (v) => setState(() => _sections = _sections.copyWith(prestations: v, tarifs: v)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Produits en Vitrine', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: const Text('Grille de produits avec photos, prix et commandes WhatsApp', style: TextStyle(fontSize: 11)),
                  value: _sections.produits,
                  activeThumbColor: AppColors.green,
                  onChanged: (v) => setState(() => _sections = _sections.copyWith(produits: v)),
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
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Bouton d'enregistrement
        SizedBox(
          width: double.infinity,
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
              _enSauvegarde ? 'Enregistrement en cours...' : 'Enregistrer l\'apparence',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            onPressed: _enSauvegarde ? null : _enregistrerApparence,
          ),
        ),
      ],
    );
  }
}

class _OngletInfosBoutique extends ConsumerStatefulWidget {
  const _OngletInfosBoutique({required this.vitrine});
  final VitrineConfig vitrine;

  @override
  ConsumerState<_OngletInfosBoutique> createState() => _OngletInfosBoutiqueState();
}

class _OngletInfosBoutiqueState extends ConsumerState<_OngletInfosBoutique> {
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
  bool _enSauvegarde = false;

  @override
  void initState() {
    super.initState();
    final v = widget.vitrine;
    final r = v.reseauxSociaux;

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

  void _remplirTexteType() {
    final act = widget.vitrine.typeActivite;
    final nom = (widget.vitrine.titreHero ?? '').isNotEmpty ? (widget.vitrine.titreHero ?? '') : 'notre établissement';
    if (act == TypeActivite.salonCoiffure || act == TypeActivite.beauteEsthetique) {
      _descCtrl.text = 'Bienvenue chez $nom, votre salon de référence pour sublimer votre beauté. Nous sommes spécialisés dans les tresses soignées, la pose de perruques invisibles et les soins capillaires personnalisés avec des produits haut de gamme.';
    } else if (act == TypeActivite.boutiqueTech) {
      _descCtrl.text = 'Bienvenue chez $nom, votre expert en smartphones, accessoires high-tech et gadgets innovants à Bamako. Tous nos produits sont certifiés authentiques, garantis avec service après-vente dédié et livraison express.';
    } else {
      _descCtrl.text = 'Bienvenue chez $nom ! Découvrez notre large gamme d\'articles de qualité sélectionnés avec soin au meilleur prix. Service client à votre écoute 7j/7 et livraison rapide partout.';
    }
    setState(() {});
  }

  Future<void> _enregistrerInfos() async {
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
          content: Text('Informations de la boutique enregistrées avec succès !'),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Carte 1 : À propos de nous
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
                    const Text('À propos de votre boutique', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
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
                    labelText: 'Présentation de votre entreprise',
                    hintText: 'Racontez votre histoire, votre savoir-faire et vos engagements...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Carte 2 : Coordonnées directes & Réseaux
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
                const Text('Coordonnées & Réseaux Sociaux', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
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

        // Carte 3 : Horaires, Paiement & Livraison
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
                const Text('Horaires, Paiement & Livraison', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
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
        const SizedBox(height: 16),

        // Bouton d'enregistrement
        SizedBox(
          width: double.infinity,
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
              _enSauvegarde ? 'Enregistrement en cours...' : 'Enregistrer les informations',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            onPressed: _enSauvegarde ? null : _enregistrerInfos,
          ),
        ),
      ],
    );
  }
}


// =============================================================================
// ONGLET BIENS IMMOBILIERS (MODÈLE IMMOBILIER TYPE HAVENLY)
// =============================================================================

class _OngletBiensImmobiliers extends ConsumerWidget {
  const _OngletBiensImmobiliers({required this.vitrine});
  final VitrineConfig vitrine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBiens = ref.watch(vitrineBiensProvider);

    return asyncBiens.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (biens) {
        if (biens.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                    child: const Icon(Icons.home_work_rounded, size: 48, color: Color(0xFF15803D)),
                  ),
                  const SizedBox(height: 16),
                  const Text('Aucun bien immobilier en vitrine', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  const SizedBox(height: 6),
                  const Text(
                    'Ajoutez vos villas, appartements ou terrains pour les présenter sur votre site Havenly avec boutons de visite.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.green, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                    icon: const Icon(Icons.add_home_work_rounded),
                    label: const Text('Ajouter un premier bien immobilier', style: TextStyle(fontWeight: FontWeight.w800)),
                    onPressed: () => _ouvrirFormulaireBien(context, ref, vitrine),
                  ),
                  const SizedBox(height: 16),
                  const Text('OU ajouter un exemple type en 1 clic :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.villa_rounded, size: 16, color: Color(0xFF15803D)),
                        label: const Text('Villa Moderne F5 (750 000 F/mois)'),
                        onPressed: () => _ajouterBienExemple(
                          ref,
                          vitrine,
                          titre: 'Villa Moderne F5 avec Piscine',
                          typeBien: 'VILLA',
                          typeOffre: 'LOCATION',
                          prix: 750000,
                          chambres: 4,
                          sdb: 3,
                          surface: 350,
                          description: 'Superbe villa sécurisée avec grand jardin, piscine, groupe électrogène et garage.',
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.apartment_rounded, size: 16, color: Color(0xFF2563EB)),
                        label: const Text('Appartement Meublé 2 Ch. (350 000 F)'),
                        onPressed: () => _ajouterBienExemple(
                          ref,
                          vitrine,
                          titre: 'Appartement Haut Standing Meublé',
                          typeBien: 'APPARTEMENT',
                          typeOffre: 'LOCATION',
                          prix: 350000,
                          chambres: 2,
                          sdb: 2,
                          surface: 120,
                          description: 'Appartement climatisé, entièrement équipé avec wifi, gardiennage 24/7.',
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.landscape_rounded, size: 16, color: Color(0xFFD97706)),
                        label: const Text('Terrain Viabilisé 400 m² (25M F)'),
                        onPressed: () => _ajouterBienExemple(
                          ref,
                          vitrine,
                          titre: 'Terrain Résidentiel Titre Foncier',
                          typeBien: 'TERRAIN',
                          typeOffre: 'VENTE',
                          prix: 25000000,
                          chambres: null,
                          sdb: null,
                          surface: 400,
                          description: 'Parcelle clôturée avec eau et électricité disponibles, accès goudronné immédiat.',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${biens.length} bien(s) en vitrine', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                  icon: const Icon(Icons.add_home_rounded, size: 16),
                  label: const Text('Nouveau bien'),
                  onPressed: () => _ouvrirFormulaireBien(context, ref, vitrine),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final b in biens)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: b.premierePhoto.isNotEmpty
                        ? Image.network(
                            MediaHybridResolver.resolvePublicUrl(b.premierePhoto),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(color: const Color(0xFFF1F5F9), width: 60, height: 60, child: const Icon(Icons.home_rounded)),
                          )
                        : Container(color: const Color(0xFFF1F5F9), width: 60, height: 60, child: const Icon(Icons.home_work_rounded)),
                  ),
                  title: Text(b.titre, style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text(
                    '${b.prixFormate} • ${b.typeBien} • ${[b.quartier, b.ville].whereType<String>().join(", ")}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    onPressed: () async {
                      await ref.read(vitrineRepositoryProvider).supprimerBien(b.id);
                      ref.invalidate(vitrineBiensProvider);
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _ajouterBienExemple(
    WidgetRef ref,
    VitrineConfig vitrine, {
    required String titre,
    required String typeBien,
    required String typeOffre,
    required int prix,
    required int? chambres,
    required int? sdb,
    required double surface,
    required String description,
  }) async {
    var vId = vitrine.id;
    if (vId.isEmpty) {
      final vMaj = await ref.read(vitrineRepositoryProvider).sauvegarderVitrine(vitrine);
      vId = vMaj.id;
      ref.invalidate(vitrineActuelleProvider);
    }
    final bien = VitrineBienImmobilier(
      id: '',
      vitrineId: vId,
      entrepriseId: vitrine.entrepriseId,
      titre: titre,
      typeBien: typeBien,
      typeOffre: typeOffre,
      prix: prix,
      surfaceM2: surface,
      nbChambres: chambres,
      nbSallesDeBain: sdb,
      description: description,
      ville: vitrine.ville ?? 'Bamako',
      quartier: 'Quartier Résidentiel',
      climatisation: true,
      parking: true,
    );
    await ref.read(vitrineRepositoryProvider).sauvegarderBien(bien);
    ref.invalidate(vitrineBiensProvider);
  }

  void _ouvrirFormulaireBien(BuildContext context, WidgetRef ref, VitrineConfig vitrine) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _DialogueAjoutBien(vitrine: vitrine),
    );
  }
}

// =============================================================================
// ONGLET DEMANDES DE VISITE IMMOBILIÈRE
// =============================================================================

class _OngletDemandesVisite extends ConsumerWidget {
  const _OngletDemandesVisite({required this.vitrine});
  final VitrineConfig vitrine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncVisites = ref.watch(vitrineDemandesVisiteProvider);

    return asyncVisites.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (visites) {
        if (visites.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                    child: const Icon(Icons.event_note_rounded, size: 48, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 16),
                  const Text('Aucune demande de visite pour le moment', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text(
                    'Les prospects qui souhaitent visiter vos biens depuis votre site vitrine apparaîtront ici.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.science_outlined, size: 16),
                    label: const Text('Générer une demande de visite test d\'exemple'),
                    onPressed: () async {
                      var vId = vitrine.id;
                      if (vId.isEmpty) {
                        final vMaj = await ref.read(vitrineRepositoryProvider).sauvegarderVitrine(vitrine);
                        vId = vMaj.id;
                        ref.invalidate(vitrineActuelleProvider);
                      }
                      final testVisite = VitrineDemandeVisite(
                        id: '',
                        vitrineId: vId,
                        entrepriseId: vitrine.entrepriseId,
                        nomBien: 'Villa Moderne F5 avec Piscine',
                        nomClient: 'Ibrahim Diarra (Prospect Test)',
                        telephoneClient: '+223 75 00 00 00',
                        dateSouhaitee: DateTime.now().add(const Duration(days: 2)),
                        heureSouhaitee: '10:00',
                        messageClient: 'Bonjour, je souhaite visiter cette villa pour une location annuelle.',
                      );
                      await ref.read(vitrineRepositoryProvider).creerDemandeVisite(testVisite);
                      ref.invalidate(vitrineDemandesVisiteProvider);
                    },
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: visites.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final v = visites[i];
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(v.nomBien, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: v.statut == StatutDemandeVisite.confirmee ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            v.statut.libelle,
                            style: TextStyle(
                              color: v.statut == StatutDemandeVisite.confirmee ? const Color(0xFF15803D) : const Color(0xFFB45309),
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Client : ${v.nomClient} • ${v.telephoneClient}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      'Créneau souhaité : ${v.dateSouhaitee.day}/${v.dateSouhaitee.month}/${v.dateSouhaitee.year} à ${v.heureSouhaitee}',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                    if (v.messageClient != null && v.messageClient!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Note : ${v.messageClient}', style: const TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF475569), fontSize: 12)),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDCFCE7), foregroundColor: const Color(0xFF15803D)),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                          label: const Text('Confirmer par WhatsApp'),
                          onPressed: () async {
                            final clean = v.telephoneClient.replaceAll(RegExp(r'[^0-9]'), '');
                            final dateStr = '${v.dateSouhaitee.day}/${v.dateSouhaitee.month}/${v.dateSouhaitee.year}';
                            final msg = 'Bonjour *${v.nomClient}*, votre visite pour *${v.nomBien}* le *$dateStr* à *${v.heureSouhaitee}* est bien confirmée !';
                            final uri = Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(msg)}');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                            await ref.read(vitrineDemandesVisiteProvider.notifier).changerStatut(v.id, StatutDemandeVisite.confirmee);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// =============================================================================
// MODAL D'AJOUT RAPIDE D'UN BIEN IMMOBILIER
// =============================================================================

class _DialogueAjoutBien extends ConsumerStatefulWidget {
  const _DialogueAjoutBien({required this.vitrine});
  final VitrineConfig vitrine;

  @override
  ConsumerState<_DialogueAjoutBien> createState() => _DialogueAjoutBienState();
}

class _DialogueAjoutBienState extends ConsumerState<_DialogueAjoutBien> {
  final _formKey = GlobalKey<FormState>();
  final _titreCtrl = TextEditingController();
  final _prixCtrl = TextEditingController();
  final _villeCtrl = TextEditingController();
  final _quartierCtrl = TextEditingController();
  final _surfaceCtrl = TextEditingController();
  final _chambresCtrl = TextEditingController();
  final _sdbCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _typeBien = 'VILLA';
  String _typeOffre = 'LOCATION';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Nouveau bien immobilier', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titreCtrl,
                decoration: const InputDecoration(labelText: 'Titre du bien * (ex: Villa Moderne F5)', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Veuillez saisir un titre' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _typeBien,
                      decoration: const InputDecoration(labelText: 'Type de bien', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'VILLA', child: Text('Villa / Maison')),
                        DropdownMenuItem(value: 'APPARTEMENT', child: Text('Appartement')),
                        DropdownMenuItem(value: 'TERRAIN', child: Text('Terrain')),
                        DropdownMenuItem(value: 'MAGASIN', child: Text('Magasin / Espace pro')),
                      ],
                      onChanged: (v) => setState(() => _typeBien = v ?? 'VILLA'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _typeOffre,
                      decoration: const InputDecoration(labelText: 'Offre', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'LOCATION', child: Text('À Louer')),
                        DropdownMenuItem(value: 'VENTE', child: Text('À Vendre')),
                      ],
                      onChanged: (v) => setState(() => _typeOffre = v ?? 'LOCATION'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _prixCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _typeOffre == 'LOCATION' ? 'Loyer mensuel (FCFA) *' : 'Prix de vente (FCFA) *',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Veuillez renseigner le prix' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _chambresCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Chambres', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _sdbCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'SDB', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _surfaceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Surface m²', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _villeCtrl,
                      decoration: const InputDecoration(labelText: 'Ville (ex: Bamako)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _quartierCtrl,
                      decoration: const InputDecoration(labelText: 'Quartier (ex: ACI 2000)', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description détaillée', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.green, padding: const EdgeInsets.symmetric(vertical: 14)),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Enregistrer le bien en vitrine', style: TextStyle(fontWeight: FontWeight.w800)),
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    final bien = VitrineBienImmobilier(
                      id: '',
                      vitrineId: widget.vitrine.id,
                      entrepriseId: widget.vitrine.entrepriseId,
                      titre: _titreCtrl.text.trim(),
                      typeBien: _typeBien,
                      typeOffre: _typeOffre,
                      prix: int.tryParse(_prixCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
                      nbChambres: int.tryParse(_chambresCtrl.text),
                      nbSallesDeBain: int.tryParse(_sdbCtrl.text),
                      surfaceM2: double.tryParse(_surfaceCtrl.text),
                      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
                      ville: _villeCtrl.text.trim().isEmpty ? widget.vitrine.ville : _villeCtrl.text.trim(),
                      quartier: _quartierCtrl.text.trim().isEmpty ? null : _quartierCtrl.text.trim(),
                    );
                    await ref.read(vitrineRepositoryProvider).sauvegarderBien(bien);
                    ref.invalidate(vitrineBiensProvider);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// STUDIO DE PRÉVISUALISATION MULTI-ÉCRANS (VOIR SON SITE AVANT DE PARTAGER)
// =============================================================================

class _StudioPrevisualisationDialog extends StatefulWidget {
  const _StudioPrevisualisationDialog({required this.vitrine});
  final VitrineConfig vitrine;

  @override
  State<_StudioPrevisualisationDialog> createState() => _StudioPrevisualisationDialogState();
}

class _StudioPrevisualisationDialogState extends State<_StudioPrevisualisationDialog> {
  int _modeEcran = 0; // 0 = Mobile, 1 = Tablette, 2 = Ordinateur

  double get _largeurCadre {
    switch (_modeEcran) {
      case 1:
        return 768;
      case 2:
        return 1050;
      default:
        return 385;
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vitrine;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      backgroundColor: Colors.transparent,
      child: Center(
        child: Container(
          width: double.infinity,
          height: MediaQuery.sizeOf(context).height * 0.94,
          constraints: const BoxConstraints(maxWidth: 1200),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 30, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            children: [
              // 1. Barre supérieure compacte & anti-débordement
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.preview_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Aperçu du site',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Boutons sélecteurs de format (icônes compactes)
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildDeviceBtn(0, Icons.smartphone_rounded, 'Mobile'),
                          _buildDeviceBtn(1, Icons.tablet_rounded, 'Tablette'),
                          _buildDeviceBtn(2, Icons.computer_rounded, 'PC'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // 2. Rendu interactif en direct (Cadre adaptatif à la largeur disponible)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxDispo = constraints.maxWidth - 16;
                    final cadreW = maxDispo < _largeurCadre ? maxDispo : _largeurCadre;

                    return Container(
                      color: const Color(0xFF0B1120),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width: cadreW,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(_modeEcran == 0 ? 28 : 12),
                          border: Border.all(color: Colors.black, width: _modeEcran == 0 ? 6 : 3),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 24),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: VitrinePubliquePage(slug: v.slug),
                      ),
                    );
                  },
                ),
              ),

              // 3. Barre inférieure anti-débordement
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  border: Border(top: BorderSide(color: Color(0xFF1E293B))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF475569)),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text('Copier le lien', style: TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: v.urlPublique));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Lien copié dans le presse-papier !'), backgroundColor: AppColors.green),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.share_rounded, size: 14),
                        label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                        onPressed: () {
                          Navigator.pop(context);
                          final texte = 'Bonjour ! Découvrez notre site officiel ici : ${v.urlPublique}';
                          launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(texte)}'), mode: LaunchMode.externalApplication);
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

  Widget _buildDeviceBtn(int mode, IconData icone, String label) {
    final actif = _modeEcran == mode;
    return InkWell(
      onTap: () => setState(() => _modeEcran = mode),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: actif ? AppColors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icone, size: 16, color: actif ? Colors.white : const Color(0xFF94A3B8)),
      ),
    );
  }
}