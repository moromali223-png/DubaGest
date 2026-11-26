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
    final texte = 'Bonjour ! Découvrez notre site vitrine officiel chez *${vitrine.titreHero ?? "DubaGest"}* ici : ${vitrine.urlPublique}';
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(texte)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _ouvrirStudioPrevisualisation(BuildContext context, VitrineConfig vitrine) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => _StudioPrevisualisationDialog(vitrine: vitrine),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncVitrine = ref.watch(vitrineActuelleProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Ma Vitrine Professionnelle',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.preview_rounded, color: Color(0xFF0F172A)),
            tooltip: 'Prévisualiser le site',
            onPressed: () {
              final v = asyncVitrine.value;
              if (v != null) _ouvrirStudioPrevisualisation(context, v);
            },
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
      body: asyncVitrine.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur : $err')),
        data: (vitrine) {
          if (vitrine == null) {
            return const Center(child: Text('Aucune vitrine configurée.'));
          }

          List<Tab> tabs;
          List<Widget> views;

          if (vitrine.typeActivite.domaine == DomaineActivite.immobilier) {
            tabs = const [
              Tab(icon: Icon(Icons.home_work_rounded, size: 18), text: 'Biens Immobiliers'),
              Tab(icon: Icon(Icons.event_available_rounded, size: 18), text: 'Demandes de Visite'),
              Tab(icon: Icon(Icons.photo_library_rounded, size: 18), text: 'Galerie Photos'),
              Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Notre Équipe'),
              Tab(icon: Icon(Icons.tune_rounded, size: 18), text: 'Design & Réglages'),
            ];
            views = [
              _OngletBiensImmobiliers(vitrine: vitrine),
              _OngletDemandesVisite(vitrine: vitrine),
              _OngletGalerie(vitrine: vitrine),
              _OngletEquipe(vitrine: vitrine),
              _OngletReglages(vitrine: vitrine),
            ];
          } else if (vitrine.typeActivite.domaine == DomaineActivite.services) {
            tabs = const [
              Tab(icon: Icon(Icons.calendar_today_rounded, size: 18), text: 'Rendez-vous'),
              Tab(icon: Icon(Icons.content_cut_rounded, size: 18), text: 'Prestations & Tarifs'),
              Tab(icon: Icon(Icons.photo_library_rounded, size: 18), text: 'Galerie Réalisations'),
              Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Notre Équipe'),
              Tab(icon: Icon(Icons.shopping_bag_rounded, size: 18), text: 'Produits / Wigs'),
              Tab(icon: Icon(Icons.tune_rounded, size: 18), text: 'Design & Réglages'),
            ];
            views = [
              _OngletRendezVous(vitrine: vitrine),
              _OngletPrestations(vitrine: vitrine),
              _OngletGalerie(vitrine: vitrine),
              _OngletEquipe(vitrine: vitrine),
              _OngletProduits(vitrine: vitrine),
              _OngletReglages(vitrine: vitrine),
            ];
          } else {
            // Domaine Commerce
            tabs = const [
              Tab(icon: Icon(Icons.storefront_rounded, size: 18), text: 'Produits en vitrine'),
              Tab(icon: Icon(Icons.photo_library_rounded, size: 18), text: 'Galerie Réalisations'),
              Tab(icon: Icon(Icons.tune_rounded, size: 18), text: 'Design & Réglages'),
            ];
            views = [
              _OngletProduits(vitrine: vitrine),
              _OngletGalerie(vitrine: vitrine),
              _OngletReglages(vitrine: vitrine),
            ];
          }

          return DefaultTabController(
            key: ValueKey('${vitrine.typeActivite.domaine.code}_${tabs.length}'),
            length: tabs.length,
            child: Column(
              children: [
                // 1. En-tête statut et lien public
                _buildHeaderStatus(vitrine),

                // 2. Barre d'onglets adaptée au métier
                Container(
                  color: Colors.white,
                  child: TabBar(
                    isScrollable: true,
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
  }

  Widget _buildHeaderStatus(VitrineConfig vitrine) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: vitrine.estPublie ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: vitrine.estPublie ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      vitrine.estPublie ? 'EN LIGNE' : 'BROUILLON',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: vitrine.estPublie ? const Color(0xFF15803D) : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _ouvrirSelecteurModeleRapide(context, ref, vitrine),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        vitrine.modeleVisuel.titre.split('—').first.trim(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down_rounded, size: 16, color: Color(0xFF4F46E5)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    vitrine.estPublie ? 'Actif' : 'Masqué',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: vitrine.estPublie ? AppColors.green : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Switch(
                    value: vitrine.estPublie,
                    activeThumbColor: AppColors.green,
                    onChanged: (val) {
                      ref.read(vitrineActuelleProvider.notifier).basculerPublication(val);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // GRAND BOUTON PROÉMINENT : PRÉVISUALISER MON SITE AVANT DE PARTAGER
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              icon: const Icon(Icons.preview_rounded, size: 20),
              label: const Text(
                '👁️ Prévisualiser mon site avant de partager',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
              onPressed: () => _ouvrirStudioPrevisualisation(context, vitrine),
            ),
          ),
          const SizedBox(height: 10),
          // DEUX GRANDS BOUTONS PRINCIPAUX TRÈS CLAIRS ET ÉVIDENTS
          Row(
            children: [
              Expanded(
                flex: 6,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 1,
                  ),
                  icon: const Icon(Icons.language_rounded, size: 18),
                  label: const Text(
                    'Plein écran web',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  onPressed: () => context.push('/v/${vitrine.slug}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
                    foregroundColor: const Color(0xFF0F5132),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 18, color: Color(0xFF25D366)),
                  label: const Text(
                    'WhatsApp',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  onPressed: () => _partagerWhatsApp(vitrine),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                icon: const Icon(Icons.auto_awesome_rounded, color: AppColors.green),
                tooltip: 'Personnaliser (Assistant 8 étapes)',
                onPressed: () => context.push(Routes.vitrineWizard),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Barre de lien avec bouton copier
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    vitrine.urlPublique,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF334155)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.green),
                  tooltip: 'Copier le lien',
                  onPressed: () => _copierLien(vitrine.urlPublique),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _ouvrirSelecteurModeleRapide(BuildContext context, WidgetRef ref, VitrineConfig vitrine) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('Choisir le modèle de vitrine', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFFEF3C7), child: Icon(Icons.content_cut_rounded, color: Color(0xFFD97706))),
                title: const Text('Modèle C — Salon de Coiffure', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Coiffures, tarifs en FCFA, rendez-vous WhatsApp, galerie avant/après'),
                selected: vitrine.modeleVisuel == ModeleVitrine.modeleC,
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(vitrineActuelleProvider.notifier).changerModele(
                    activite: TypeActivite.salonCoiffure,
                    modele: ModeleVitrine.modeleC,
                    style: ThemeStyle.luxeOr,
                  );
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFEEF2FF), child: Icon(Icons.shopping_bag_rounded, color: Color(0xFF4F46E5))),
                title: const Text('Modèle B — Boutique Spécialisée', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Cosmétiques, vêtements, accessoires, collections et nouveautés'),
                selected: vitrine.modeleVisuel == ModeleVitrine.modeleB,
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(vitrineActuelleProvider.notifier).changerModele(
                    activite: TypeActivite.boutiqueSpecialisee,
                    modele: ModeleVitrine.modeleB,
                    style: ThemeStyle.commercialVert,
                  );
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFDCFCE7), child: Icon(Icons.storefront_rounded, color: Color(0xFF15803D))),
                title: const Text('Modèle A — Commerce Général', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Alimentation, quincaillerie, magasin, tous produits'),
                selected: vitrine.modeleVisuel == ModeleVitrine.modeleA,
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(vitrineActuelleProvider.notifier).changerModele(
                    activite: TypeActivite.commerceGeneral,
                    modele: ModeleVitrine.modeleA,
                    style: ThemeStyle.commercialVert,
                  );
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFFCE7F3), child: Icon(Icons.spa_rounded, color: Color(0xFFDB2777))),
                title: const Text('Modèle D — Beauté & Esthétique', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Instituts, manucure, maquillage, soins du visage'),
                selected: vitrine.modeleVisuel == ModeleVitrine.modeleD,
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(vitrineActuelleProvider.notifier).changerModele(
                    activite: TypeActivite.beauteEsthetique,
                    modele: ModeleVitrine.modeleD,
                    style: ThemeStyle.elegantBeige,
                  );
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFDCFCE7), child: Icon(Icons.apartment_rounded, color: Color(0xFF15803D))),
                title: const Text('Modèle F — Havenly (Agence & Biens Immobiliers)', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Villas, appartements, recherche par ville, demandes de visite'),
                selected: vitrine.modeleVisuel == ModeleVitrine.modeleF,
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(vitrineActuelleProvider.notifier).changerModele(
                    activite: TypeActivite.agenceImmobiliere,
                    modele: ModeleVitrine.modeleF,
                    style: ThemeStyle.naturelChaud,
                  );
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFF1F5F9), child: Icon(Icons.handyman_rounded, color: Color(0xFF475569))),
                title: const Text('Modèle E — Prestataire de Services', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Artisans, consultants, interventions techniques'),
                selected: vitrine.modeleVisuel == ModeleVitrine.modeleE,
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(vitrineActuelleProvider.notifier).changerModele(
                    activite: TypeActivite.prestataireServices,
                    modele: ModeleVitrine.modeleE,
                    style: ThemeStyle.moderneMinimal,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
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

class _OngletProduits extends ConsumerWidget {
  const _OngletProduits({required this.vitrine});
  final VitrineConfig vitrine;

  void _ouvrirDialogueProduit(BuildContext context, [VitrineProduitItem? produit]) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _DialogueAjoutOuModifProduitVitrine(vitrine: vitrine, produit: produit),
    );
  }

  Future<void> _chargerExemplesDemo(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(vitrineProduitsAdminProvider.notifier);
    
    // Détection de la typologie d'exemples selon l'activité
    final isTech = vitrine.typeActivite == TypeActivite.boutiqueTech || vitrine.modeleVisuel == ModeleVitrine.modeleB;
    final isBeauty = vitrine.typeActivite == TypeActivite.cosmetiqueBeaute || vitrine.typeActivite == TypeActivite.salonCoiffure;

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
  Widget build(BuildContext context, WidgetRef ref) {
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

        return Column(
          children: [
            // Barre d'actions supérieure claire et proéminente
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Catalogue de vente en vitrine',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        '$totalPublies produit(s) en ligne sur ${produits.length} au total',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('➕ Ajouter un produit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        onPressed: () => _ouvrirDialogueProduit(context),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF4F46E5), size: 18),
                        tooltip: 'Charger des produits modèles démo',
                        onPressed: () => _chargerExemplesDemo(context, ref),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Liste des produits ou état vide incitatif
            Expanded(
              child: produits.isEmpty
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
                            const Text(
                              'Aucun produit dans votre catalogue vitrine',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Ajoutez directement vos articles (téléphones, accessoires, vêtements, perruques, soins...) avec photo et prix en FCFA.\nVos clients pourront les commander en un clic sur WhatsApp !',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                                label: const Text('Ajouter mon premier produit', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                                onPressed: () => _ouvrirDialogueProduit(context),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF4F46E5),
                                  side: const BorderSide(color: Color(0xFF818CF8)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                                label: const Text('⚡ Charger 6 produits démo de qualité', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                                onPressed: () => _chargerExemplesDemo(context, ref),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: produits.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final p = produits[i];
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
          // Photo du produit
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
                      child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF94A3B8), size: 32),
                    ),
            ),
          ),
          const SizedBox(width: 14),

          // Détails du produit
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  produit.nom,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (produit.description != null && produit.description!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    produit.description!,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${produit.prix} FCFA',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.green),
                    ),
                    if (produit.aPromotion) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${produit.prixBarre} F',
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
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
                      produit.estPublie ? 'Visible en ligne' : 'Masqué',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: produit.estPublie ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Transform.scale(
                      scale: 0.75,
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

class _OngletReglages extends ConsumerWidget {
  const _OngletReglages({required this.vitrine});
  final VitrineConfig vitrine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = vitrine.sections;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sections visibles sur votre site', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Prestations & Tarifs'),
                  subtitle: const Text('Affiche vos services, coiffures et tarifs'),
                  value: sections.prestations,
                  onChanged: (v) {
                    final maj = vitrine.copyWith(sections: sections.copyWith(prestations: v, tarifs: v));
                    ref.read(vitrineActuelleProvider.notifier).sauvegarder(maj);
                  },
                ),
                SwitchListTile(
                  title: const Text('Produits & Vente'),
                  subtitle: const Text('Affiche vos articles et panier de commande WhatsApp'),
                  value: sections.produits,
                  onChanged: (v) {
                    final maj = vitrine.copyWith(sections: sections.copyWith(produits: v));
                    ref.read(vitrineActuelleProvider.notifier).sauvegarder(maj);
                  },
                ),
                SwitchListTile(
                  title: const Text('Galerie de Réalisations'),
                  subtitle: const Text('Affiche les photos de vos travaux et avant/après'),
                  value: sections.galerie,
                  onChanged: (v) {
                    final maj = vitrine.copyWith(sections: sections.copyWith(galerie: v));
                    ref.read(vitrineActuelleProvider.notifier).sauvegarder(maj);
                  },
                ),
                SwitchListTile(
                  title: const Text('Présentation de l\'Équipe'),
                  subtitle: const Text('Affiche les professionnels du salon'),
                  value: sections.equipe,
                  onChanged: (v) {
                    final maj = vitrine.copyWith(sections: sections.copyWith(equipe: v));
                    ref.read(vitrineActuelleProvider.notifier).sauvegarder(maj);
                  },
                ),
                SwitchListTile(
                  title: const Text('Prise de Rendez-vous'),
                  subtitle: const Text('Permet aux clients de réserver directement'),
                  value: sections.rdv,
                  onChanged: (v) {
                    final maj = vitrine.copyWith(sections: sections.copyWith(rdv: v));
                    ref.read(vitrineActuelleProvider.notifier).sauvegarder(maj);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.tune_rounded),
          label: const Text('Relancer le créateur complet (Wizard 8 étapes)'),
          onPressed: () => context.push(Routes.vitrineWizard),
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
              // 1. Barre d'outils du studio (Adaptive & Anti-débordement)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isSmall = constraints.maxWidth < 620;

                    if (isSmall) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.preview_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Studio de Prévisualisation',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<int>(
                              segments: const [
                                ButtonSegment(value: 0, icon: Icon(Icons.smartphone_rounded, size: 14), label: Text('Mobile', style: TextStyle(fontSize: 10))),
                                ButtonSegment(value: 1, icon: Icon(Icons.tablet_rounded, size: 14), label: Text('Tablette', style: TextStyle(fontSize: 10))),
                                ButtonSegment(value: 2, icon: Icon(Icons.computer_rounded, size: 14), label: Text('PC', style: TextStyle(fontSize: 10))),
                              ],
                              selected: {_modeEcran},
                              onSelectionChanged: (val) => setState(() => _modeEcran = val.first),
                              style: SegmentedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                backgroundColor: const Color(0xFF1E293B),
                                selectedBackgroundColor: AppColors.green,
                                foregroundColor: Colors.white,
                                selectedForegroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        const Icon(Icons.preview_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Studio de Prévisualisation • Vérifiez votre site avant de partager',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 0, icon: Icon(Icons.smartphone_rounded, size: 16), label: Text('Mobile', style: TextStyle(fontSize: 11))),
                            ButtonSegment(value: 1, icon: Icon(Icons.tablet_rounded, size: 16), label: Text('Tablette', style: TextStyle(fontSize: 11))),
                            ButtonSegment(value: 2, icon: Icon(Icons.computer_rounded, size: 16), label: Text('PC', style: TextStyle(fontSize: 11))),
                          ],
                          selected: {_modeEcran},
                          onSelectionChanged: (val) => setState(() => _modeEcran = val.first),
                          style: SegmentedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            selectedBackgroundColor: AppColors.green,
                            foregroundColor: Colors.white,
                            selectedForegroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    );
                  },
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

              // 3. Barre inférieure d'actions de partage (100% Anti-débordement)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  border: Border(top: BorderSide(color: Color(0xFF1E293B))),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isSmall = constraints.maxWidth < 620;

                    if (isSmall) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Lien public : ${v.urlPublique}',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Color(0xFF475569)),
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                  ),
                                  icon: const Icon(Icons.copy_rounded, size: 14),
                                  label: const Text('Copier', style: TextStyle(fontSize: 12)),
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
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                  ),
                                  icon: const Icon(Icons.share_rounded, size: 14),
                                  label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    final texte = 'Bonjour ! Découvrez notre site officiel ici : ${v.urlPublique}';
                                    launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(texte)}'), mode: LaunchMode.externalApplication);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Lien public : ${v.urlPublique}',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF475569)),
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Copier le lien'),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: v.urlPublique));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Lien copié dans le presse-papier !'), backgroundColor: AppColors.green),
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                          icon: const Icon(Icons.share_rounded, size: 16),
                          label: const Text('Partager sur WhatsApp', style: TextStyle(fontWeight: FontWeight.w800)),
                          onPressed: () {
                            Navigator.pop(context);
                            final texte = 'Bonjour ! Découvrez notre site officiel ici : ${v.urlPublique}';
                            launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(texte)}'), mode: LaunchMode.externalApplication);
                          },
                        ),
                      ],
                    );
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

