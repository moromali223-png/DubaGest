import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../features/catalogue/services/media_hybrid_resolver.dart';
import '../providers/vitrine_providers.dart';
import '../../domain/entities/vitrine_config.dart';
import '../../domain/entities/vitrine_prestation.dart';
import '../../domain/entities/vitrine_galerie_item.dart';
import '../../domain/entities/vitrine_membre_equipe.dart';
import '../../domain/entities/vitrine_rendez_vous.dart';

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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  vitrine.modeleVisuel.titre.split('—').first.trim(),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)),
                ),
              ),
              const Spacer(),
              Switch(
                value: vitrine.estPublie,
                activeThumbColor: AppColors.green,
                onChanged: (val) {
                  ref.read(vitrineActuelleProvider.notifier).basculerPublication(val);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          vitrine.urlPublique,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'Copier le lien',
                onPressed: () => _copierLien(vitrine.urlPublique),
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.share_rounded, size: 18),
                tooltip: 'Partager sur WhatsApp',
                onPressed: () => _partagerWhatsApp(vitrine),
              ),
              const SizedBox(width: 4),
              IconButton.outlined(
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                tooltip: 'Voir ma vitrine en direct',
                onPressed: () {
                  context.push('/v/${vitrine.slug}');
                },
              ),
            ],
          ),
        ],
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
              final p = VitrinePrestation(
                id: prestation?.id ?? '',
                vitrineId: vitrine.id,
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.content_cut_rounded, size: 48, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 12),
                  const Text('Aucune prestation enregistrée', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text('Ajoutez vos prestations de coiffure, soins ou services avec leurs tarifs en FCFA.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Créer ma première prestation'),
                    onPressed: () => _ouvrirDialoguePrestation(context, ref),
                  ),
                ],
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

  void _ajouterPhoto(BuildContext context, WidgetRef ref) {
    final urlCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'Coiffures');
    final titreCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('Ajouter une photo à la galerie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titreCtrl, decoration: const InputDecoration(labelText: 'Titre de la réalisation')),
            const SizedBox(height: 10),
            TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Catégorie (ex: Nattes, Braids, Avant/Après)')),
            const SizedBox(height: 10),
            TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'URL ou chemin R2 de la photo')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: () async {
              if (urlCtrl.text.trim().isEmpty) return;
              final item = VitrineGalerieItem(
                id: '',
                vitrineId: vitrine.id,
                entrepriseId: vitrine.entrepriseId,
                titre: titreCtrl.text.trim().isEmpty ? null : titreCtrl.text.trim(),
                categorie: catCtrl.text.trim().isEmpty ? null : catCtrl.text.trim(),
                photoUrl: urlCtrl.text.trim(),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_library_outlined, size: 48, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 12),
                  const Text('Galerie vide', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text('Ajoutez des photos de vos réalisations pour séduire vos clients.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                    icon: const Icon(Icons.add_a_photo_rounded),
                    label: const Text('Ajouter une photo'),
                    onPressed: () => _ajouterPhoto(context, ref),
                  ),
                ],
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

  void _ajouterMembre(BuildContext context, WidgetRef ref) {
    final nomCtrl = TextEditingController();
    final roleCtrl = TextEditingController(text: 'Coiffeur / Coiffeuse');
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('Ajouter un membre à l\'équipe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nomCtrl, decoration: const InputDecoration(labelText: 'Nom et prénom *')),
            const SizedBox(height: 10),
            TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: 'Rôle ou spécialité (ex: Locks & Nattes)')),
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
              final m = VitrineMembreEquipe(
                id: '',
                vitrineId: vitrine.id,
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.groups_rounded, size: 48, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 12),
                  const Text('Aucun membre dans l\'équipe', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text('Présentez vos coiffeurs, maquilleurs et spécialistes pour rassurer vos clients.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                    icon: const Icon(Icons.person_add_rounded),
                    label: const Text('Ajouter un professionnel'),
                    onPressed: () => _ajouterMembre(context, ref),
                  ),
                ],
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
      child: Padding(
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
            const Text('Gestion des produits en vitrine', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            const Text(
              'Vous pouvez publier des produits (shampoings, perruques, accessoires) directement depuis la section Stock & Produits en activant l\'option « Visible sur la vitrine ».',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.green),
              icon: const Icon(Icons.inventory_2_rounded),
              label: const Text('Ouvrir les produits'),
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
