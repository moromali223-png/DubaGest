import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../features/catalogue/presentation/widgets/vocal_presentation_widget.dart';
import '../../../../features/catalogue/services/media_hybrid_resolver.dart';
import '../providers/vitrine_providers.dart';
import '../../domain/entities/vitrine_types.dart';
import 'vitrine_publique_page.dart';

/// Créateur de site vitrine professionnel en 8 étapes pour DubaGest V2
class VitrineWizardPage extends ConsumerStatefulWidget {
  const VitrineWizardPage({super.key});

  @override
  ConsumerState<VitrineWizardPage> createState() => _VitrineWizardPageState();
}

class _VitrineWizardPageState extends ConsumerState<VitrineWizardPage> {
  int _currentStep = 1;

  // États du formulaire
  TypeActivite _activite = TypeActivite.salonCoiffure;
  ModeleVitrine _modele = ModeleVitrine.modeleC;
  ThemeStyle _style = ThemeStyle.luxeOr;
  final _titreCtrl = TextEditingController();
  final _sloganCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _telephoneCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();
  String? _logoUrl;
  String? _banniereUrl;
  String? _audioUrl;
  bool _activerPrestations = true;
  bool _activerProduits = false;

  // Aperçu responsive (step 7)
  int _devicePreviewIndex = 0; // 0: Mobile, 1: Tablette, 2: Ordinateur

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final v = ref.read(vitrineActuelleProvider).value;
      if (v != null) {
        setState(() {
          _activite = v.typeActivite;
          _modele = v.modeleVisuel;
          _style = v.themeStyle;
          _titreCtrl.text = v.titreHero ?? '';
          _sloganCtrl.text = v.slogan ?? '';
          _descriptionCtrl.text = v.description ?? '';
          _whatsappCtrl.text = v.whatsapp ?? '';
          _telephoneCtrl.text = v.telephone ?? '';
          _adresseCtrl.text = v.adresse ?? '';
          _logoUrl = v.logoUrl;
          _banniereUrl = v.banniereUrl;
          _audioUrl = v.audioPresentationUrl;
          _activerPrestations = v.sections.prestations;
          _activerProduits = v.sections.produits;
        });
      }
    });
  }

  @override
  void dispose() {
    _titreCtrl.dispose();
    _sloganCtrl.dispose();
    _descriptionCtrl.dispose();
    _whatsappCtrl.dispose();
    _telephoneCtrl.dispose();
    _adresseCtrl.dispose();
    super.dispose();
  }

  void _onSelectActivite(TypeActivite act) {
    setState(() {
      _activite = act;
      _modele = ModeleVitrine.recommanderPour(act);
      if (act == TypeActivite.salonCoiffure) {
        _style = ThemeStyle.luxeOr;
        _activerPrestations = true;
        _activerProduits = false;
      } else if (act == TypeActivite.beauteEsthetique) {
        _style = ThemeStyle.elegantBeige;
        _activerPrestations = true;
        _activerProduits = false;
      } else if (act == TypeActivite.commerceGeneral) {
        _style = ThemeStyle.commercialVert;
        _activerPrestations = false;
        _activerProduits = true;
      } else if (act == TypeActivite.boutiqueSpecialisee) {
        _style = ThemeStyle.sombrePro;
        _activerPrestations = false;
        _activerProduits = true;
      }
    });
  }

  Future<void> _finaliserEtPublier() async {
    final v = ref.read(vitrineActuelleProvider).value;
    if (v == null) return;

    final baseSlug = (_titreCtrl.text.trim().isNotEmpty ? _titreCtrl.text : v.slug)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final slugFinal = baseSlug.isNotEmpty ? baseSlug : v.slug;

    final config = v.copyWith(
      slug: slugFinal,
      typeActivite: _activite,
      modeleVisuel: _modele,
      themeStyle: _style,
      couleurPrincipale: '#${_style.primaire.toARGB32().toRadixString(16).substring(2)}',
      couleurSecondaire: '#${_style.secondaire.toARGB32().toRadixString(16).substring(2)}',
      titreHero: _titreCtrl.text.trim(),
      slogan: _sloganCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      whatsapp: _whatsappCtrl.text.trim(),
      telephone: _telephoneCtrl.text.trim(),
      adresse: _adresseCtrl.text.trim(),
      logoUrl: _logoUrl,
      banniereUrl: _banniereUrl,
      audioPresentationUrl: _audioUrl,
      sections: v.sections.copyWith(
        prestations: _activerPrestations,
        tarifs: _activerPrestations,
        rdv: _activite == TypeActivite.salonCoiffure || _activite == TypeActivite.beauteEsthetique,
        galerie: true,
        equipe: _activite == TypeActivite.salonCoiffure || _activite == TypeActivite.beauteEsthetique,
        produits: _activerProduits,
      ),
      estPublie: true,
    );

    await ref.read(vitrineActuelleProvider.notifier).sauvegarder(config);
    setState(() => _currentStep = 8);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Créateur de Vitrine — Étape $_currentStep/8',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_currentStep > 1 && _currentStep < 8) {
              setState(() => _currentStep--);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: Column(
        children: [
          // Barre de progression
          LinearProgressIndicator(
            value: _currentStep / 8,
            backgroundColor: const Color(0xFFE2E8F0),
            color: AppColors.green,
            minHeight: 4,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildStepContent(),
            ),
          ),
          // Barre d'actions suivante / précédente
          if (_currentStep < 8) _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1Activite();
      case 2:
        return _buildStep2Modele();
      case 3:
        return _buildStep3Theme();
      case 4:
        return _buildStep4Medias();
      case 5:
        return _buildStep5Infos();
      case 6:
        return _buildStep6Mixte();
      case 7:
        return _buildStep7Preview();
      case 8:
        return _buildStep8Succes();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          if (_currentStep > 1)
            OutlinedButton(
              onPressed: () => setState(() => _currentStep--),
              child: const Text('Précédent'),
            ),
          const Spacer(),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.green,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: Icon(_currentStep == 7 ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded, size: 18),
            label: Text(_currentStep == 7 ? 'Publier ma vitrine' : 'Continuer'),
            onPressed: () {
              if (_currentStep == 7) {
                _finaliserEtPublier();
              } else {
                setState(() => _currentStep++);
              }
            },
          ),
        ],
      ),
    );
  }

  // --- ÉTAPE 1 : CHOISIR SON ACTIVITÉ ---
  Widget _buildStep1Activite() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Étape 1 sur 8', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 4),
        const Text('Quel est votre type d\'activité ?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        const Text(
          'DubaGest V2 adapte la mise en page, les rubriques et les fonctionnalités selon votre métier.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
        const SizedBox(height: 20),
        for (final act in TypeActivite.values)
          _OptionCard(
            titre: act.libelle,
            description: act.description,
            icone: _iconeActivite(act),
            selectionne: _activite == act,
            onTap: () => _onSelectActivite(act),
          ),
      ],
    );
  }

  IconData _iconeActivite(TypeActivite act) {
    switch (act) {
      case TypeActivite.commerceGeneral:
        return Icons.storefront_rounded;
      case TypeActivite.boutiqueSpecialisee:
        return Icons.shopping_bag_rounded;
      case TypeActivite.salonCoiffure:
        return Icons.content_cut_rounded;
      case TypeActivite.beauteEsthetique:
        return Icons.spa_rounded;
      case TypeActivite.prestataireServices:
        return Icons.handyman_rounded;
      case TypeActivite.autre:
        return Icons.business_center_rounded;
    }
  }

  // --- ÉTAPE 2 : CHOISIR LE MODÈLE VISUEL ---
  Widget _buildStep2Modele() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Étape 2 sur 8', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 4),
        const Text('Choisissez le modèle visuel de votre site', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        const Text(
          'Chaque modèle est optimisé pour mettre en valeur votre savoir-faire ou vos articles.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
        const SizedBox(height: 20),
        for (final m in ModeleVitrine.values)
          _OptionCard(
            titre: m.titre,
            description: m.description,
            badge: m == ModeleVitrine.recommanderPour(_activite) ? 'RECOMMANDÉ' : null,
            icone: _iconeModele(m),
            selectionne: _modele == m,
            onTap: () => setState(() => _modele = m),
          ),
      ],
    );
  }

  IconData _iconeModele(ModeleVitrine m) {
    switch (m) {
      case ModeleVitrine.modeleA:
        return Icons.store_mall_directory_rounded;
      case ModeleVitrine.modeleB:
        return Icons.local_mall_rounded;
      case ModeleVitrine.modeleC:
        return Icons.cut_rounded;
      case ModeleVitrine.modeleD:
        return Icons.auto_awesome_rounded;
      case ModeleVitrine.modeleE:
        return Icons.work_outline_rounded;
    }
  }

  // --- ÉTAPE 3 : PALETTE & STYLE GRAPHIQUE ---
  Widget _buildStep3Theme() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Étape 3 sur 8', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 4),
        const Text('Quelle ambiance visuelle souhaitez-vous ?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        const Text(
          'Sélectionnez une palette professionnelle adaptée à l\'image de marque de votre établissement.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
        const SizedBox(height: 20),
        for (final st in ThemeStyle.values)
          GestureDetector(
            onTap: () => setState(() => _style = st),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _style == st ? AppColors.green : const Color(0xFFE2E8F0),
                  width: _style == st ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: st.fond,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Center(
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(color: st.primaire, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(st.nom, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _ColorChip(color: st.primaire, label: 'Primaire'),
                            const SizedBox(width: 8),
                            _ColorChip(color: st.secondaire, label: 'Secondaire'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_style == st) const Icon(Icons.check_circle_rounded, color: AppColors.green),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // --- ÉTAPE 4 : LOGO ET PHOTOS ---
  Widget _buildStep4Medias() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Étape 4 sur 8', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 4),
        const Text('Logo et bannière de couverture', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        const Text(
          'Les photos sont stockées de façon sécurisée et distribuées ultra-rapidement via Cloudflare R2.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
        const SizedBox(height: 20),
        // Bannière
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(16),
            image: _banniereUrl != null && _banniereUrl!.isNotEmpty
                ? DecorationImage(image: NetworkImage(MediaHybridResolver.resolvePublicUrl(_banniereUrl!)), fit: BoxFit.cover)
                : null,
          ),
          child: Stack(
            children: [
              if (_banniereUrl == null || _banniereUrl!.isEmpty)
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_photo_alternate_rounded, size: 40, color: Color(0xFF94A3B8)),
                      SizedBox(height: 6),
                      Text('Grande photo de couverture', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              Positioned(
                bottom: 10,
                right: 10,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white),
                  icon: const Icon(Icons.upload_rounded, size: 16),
                  label: const Text('Changer la bannière'),
                  onPressed: () {
                    final dummy = MediaHybridResolver.createR2VitrineMedia(
                      entrepriseId: ref.read(vitrineActuelleProvider).value?.entrepriseId ?? 'ent',
                      type: 'banniere',
                    );
                    setState(() => _banniereUrl = dummy);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Logo
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E8F0))),
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFE2E8F0),
            backgroundImage: _logoUrl != null ? NetworkImage(MediaHybridResolver.resolvePublicUrl(_logoUrl!)) : null,
            child: _logoUrl == null ? const Icon(Icons.storefront_rounded, color: Color(0xFF64748B)) : null,
          ),
          title: const Text('Logo de l\'établissement', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('Format carré ou circulaire recommandé'),
          trailing: TextButton(
            child: const Text('Modifier'),
            onPressed: () {
              final dummy = MediaHybridResolver.createR2VitrineMedia(
                entrepriseId: ref.read(vitrineActuelleProvider).value?.entrepriseId ?? 'ent',
                type: 'logo',
              );
              setState(() => _logoUrl = dummy);
            },
          ),
        ),
      ],
    );
  }

  // --- ÉTAPE 5 : INFORMATIONS ET MESSAGE VOCAL ---
  Widget _buildStep5Infos() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Étape 5 sur 8', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 4),
        const Text('Informations & Présentation vocale', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        const Text(
          'Décrivez votre activité et donnez la parole à votre établissement grâce à un message vocal de 60 secondes.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
        const SizedBox(height: 20),
        TextField(controller: _titreCtrl, decoration: const InputDecoration(labelText: 'Nom du salon ou de l\'enseigne *', border: OutlineInputBorder())),
        const SizedBox(height: 14),
        TextField(controller: _sloganCtrl, decoration: const InputDecoration(labelText: 'Slogan d\'accroche', hintText: 'ex: L\'art de sublimer votre beauté', border: OutlineInputBorder())),
        const SizedBox(height: 14),
        TextField(controller: _descriptionCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Présentation & Spécialités', border: OutlineInputBorder())),
        const SizedBox(height: 14),
        TextField(controller: _whatsappCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Numéro WhatsApp (commandes & RDV) *', border: OutlineInputBorder())),
        const SizedBox(height: 14),
        TextField(controller: _adresseCtrl, decoration: const InputDecoration(labelText: 'Adresse & Localisation', hintText: 'ex: Hamdallaye ACI 2000, Bamako', border: OutlineInputBorder())),
        const SizedBox(height: 24),
        const Text('Message vocal de bienvenue (Cloudflare R2)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        const SizedBox(height: 8),
        VocalPresentationWidget(
          initialAudioUrl: _audioUrl,
          onAudioChanged: (url) => setState(() => _audioUrl = url),
        ),
      ],
    );
  }

  // --- ÉTAPE 6 : GESTION MIXTE PRODUITS ET PRESTATIONS ---
  Widget _buildStep6Mixte() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Étape 6 sur 8', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 4),
        const Text('Gestion mixte : Prestations et Produits', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        const Text(
          'DubaGest V2 permet d\'afficher uniquement des prestations, uniquement des produits, ou les deux à la fois sans forcer l\'usage du stock.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
        const SizedBox(height: 20),
        SwitchListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E8F0))),
          title: const Text('Activer les Prestations & Soins', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('Idéal pour les salons de coiffure, esthétique et prestataires'),
          value: _activerPrestations,
          onChanged: (v) => setState(() => _activerPrestations = v),
        ),
        const SizedBox(height: 14),
        SwitchListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E8F0))),
          title: const Text('Activer la Vente de Produits', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('Permet de vendre des accessoires, perruques, mèches, shampoings'),
          value: _activerProduits,
          onChanged: (v) => setState(() => _activerProduits = v),
        ),
      ],
    );
  }

  // --- ÉTAPE 7 : PRÉVISUALISATION RESPONSIVE INTERACTIVE ---
  Widget _buildStep7Preview() {
    double containerWidth;
    switch (_devicePreviewIndex) {
      case 0: // Mobile
        containerWidth = 380;
        break;
      case 1: // Tablette
        containerWidth = 640;
        break;
      case 2: // Ordinateur
      default:
        containerWidth = double.infinity;
        break;
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.white,
          child: Row(
            children: [
              const Text('Aperçu en direct :', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const Spacer(),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, icon: Icon(Icons.phone_android_rounded, size: 16), label: Text('Mobile')),
                  ButtonSegment(value: 1, icon: Icon(Icons.tablet_rounded, size: 16), label: Text('Tablette')),
                  ButtonSegment(value: 2, icon: Icon(Icons.laptop_rounded, size: 16), label: Text('Ordinateur')),
                ],
                selected: {_devicePreviewIndex},
                onSelectionChanged: (set) => setState(() => _devicePreviewIndex = set.first),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: containerWidth,
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Color(0x15000000), blurRadius: 16, offset: Offset(0, 4))],
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: VitrinePubliquePage(slug: ref.read(vitrineActuelleProvider).value?.slug ?? 'demo'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- ÉTAPE 8 : SUCCÈS & FÉLICITATIONS ---
  Widget _buildStep8Succes() {
    final v = ref.read(vitrineActuelleProvider).value;
    final url = v?.urlPublique ?? 'https://dubagest.com';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 64, color: Color(0xFF16A34A)),
            ),
            const SizedBox(height: 20),
            const Text('Félicitations !', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            const Text(
              'Votre site vitrine professionnel est désormais configuré et prêt à être partagé avec vos clients.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: SelectableText(url, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.green)),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Partager sur WhatsApp'),
                  onPressed: () {
                    final texte = 'Découvrez notre site vitrine officiel : $url';
                    launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(texte)}'), mode: LaunchMode.externalApplication);
                  },
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.dashboard_rounded, size: 18),
                  label: const Text('Ouvrir Ma Vitrine'),
                  onPressed: () => context.go(Routes.maVitrine),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.titre,
    required this.description,
    required this.icone,
    required this.selectionne,
    required this.onTap,
    this.badge,
  });

  final String titre;
  final String description;
  final IconData icone;
  final bool selectionne;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selectionne ? AppColors.green : const Color(0xFFE2E8F0),
            width: selectionne ? 2 : 1,
          ),
          boxShadow: [
            if (selectionne) BoxShadow(color: AppColors.green.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selectionne ? AppColors.green : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icone, color: selectionne ? Colors.white : const Color(0xFF64748B), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(titre, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A))),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                          child: Text(badge!, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 9, color: Color(0xFF16A34A))),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5)),
                ],
              ),
            ),
            if (selectionne) const Icon(Icons.check_circle_rounded, color: AppColors.green),
          ],
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ],
    );
  }
}
