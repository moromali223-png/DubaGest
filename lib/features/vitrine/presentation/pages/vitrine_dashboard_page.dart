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
import '../../domain/entities/vitrine_config.dart';
import '../../domain/entities/vitrine_galerie_item.dart';
import '../../domain/entities/vitrine_membre_equipe.dart';
import '../../domain/entities/vitrine_prestation.dart';
import '../../domain/entities/vitrine_rendez_vous.dart';
import '../../domain/entities/vitrine_types.dart';

/// Page d'administration complète « Ma Vitrine » pour le professionnel
class VitrineDashboardPage extends ConsumerStatefulWidget {
  const VitrineDashboardPage({super.key});

  @override
  ConsumerState<VitrineDashboardPage> createState() => _VitrineDashboardPageState();
}

class _VitrineDashboardPageState extends ConsumerState<VitrineDashboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
    final texte = 'Bonjour ! Découvrez notre site vitrine officiel et nos prestations chez *${vitrine.titreHero ?? "DubaGest"}* ici : ${vitrine.urlPublique}';
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(texte)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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

          return Column(
            children: [
              // 1. En-tête statut et lien public
              _buildHeaderStatus(vitrine),

              // 2. Barre d'onglets
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: AppColors.green,
                  labelColor: AppColors.green,
                  unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  tabs: const [
                    Tab(icon: Icon(Icons.calendar_today_rounded, size: 18), text: 'Rendez-vous'),
                    Tab(icon: Icon(Icons.content_cut_rounded, size: 18), text: 'Prestations & Tarifs'),
                    Tab(icon: Icon(Icons.photo_library_rounded, size: 18), text: 'Galerie Réalisations'),
                    Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Notre Équipe'),
                    Tab(icon: Icon(Icons.storefront_rounded, size: 18), text: 'Produits en vitrine'),
                    Tab(icon: Icon(Icons.tune_rounded, size: 18), text: 'Design & Réglages'),
                  ],
                ),
              ),

              // 3. Contenu de chaque onglet
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _OngletRendezVous(vitrine: vitrine),
                    _OngletPrestations(vitrine: vitrine),
                    _OngletGalerie(vitrine: vitrine),
                    _OngletEquipe(vitrine: vitrine),
                    _OngletProduits(vitrine: vitrine),
                    _OngletReglages(vitrine: vitrine),
                  ],
                ),
              ),
            ],
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
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.language_rounded, size: 20),
                  label: const Text(
                    'Voir mon site',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
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

class _OngletProduits extends StatelessWidget {
  const _OngletProduits({required this.vitrine});
  final VitrineConfig vitrine;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
              child: const Icon(Icons.storefront_rounded, size: 48, color: AppColors.green),
            ),
            const SizedBox(height: 16),
            const Text('Vente de produits en vitrine', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            const Text(
              'Cette section est facultative : si votre salon propose uniquement des prestations et coiffures, vous n\'avez pas besoin d\'ajouter de produits.\n\nSi vous vendez aussi des articles (mèches, perruques, shampoings, crèmes), vos clients pourront les commander directement par WhatsApp.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.green, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
              icon: const Icon(Icons.language_rounded, size: 18),
              label: const Text('Voir la boutique sur mon site'),
              onPressed: () => context.push('/v/${vitrine.slug}'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.inventory_2_rounded, size: 18),
              label: const Text('Gérer les produits en stock'),
              onPressed: () => context.push(Routes.stock),
            ),
          ],
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
