import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../documents/presentation/providers/documents_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/echeance_loyer.dart';
import '../../domain/entities/historique_paiement_loyer.dart';
import '../providers/immobilier_providers.dart';
import '../widgets/loyer_widgets.dart';

class LoyersPage extends ConsumerStatefulWidget {
  const LoyersPage({super.key});

  @override
  ConsumerState<LoyersPage> createState() => _LoyersPageState();
}

class _LoyersPageState extends ConsumerState<LoyersPage> with SingleTickerProviderStateMixin {
  final TextEditingController _rechercheController = TextEditingController();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _rechercheController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _genererAppels(BuildContext context) async {
    final filtre = ref.read(filtreLoyersProvider);
    const moisNoms = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    final nomMois = moisNoms[(filtre.mois - 1).clamp(0, 11)];

    final messenger = ScaffoldMessenger.of(context);
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('Générer les appels', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          'Voulez-vous générer les appels de loyer pour $nomMois ${filtre.annee} pour tous les contrats de bail actifs ?\n\n'
          'Cette opération est idempotente : aucune échéance existante ne sera dupliquée.',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
            label: const Text('Générer'),
          ),
        ],
      ),
    );

    if (confirmer != true || !mounted) return;

    try {
      final nouvelles = await ref.read(immobilierLoyersControllerProvider.notifier).genererAppelsDuMois(
            mois: filtre.mois,
            annee: filtre.annee,
          );
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              nouvelles.isEmpty
                  ? 'Toutes les échéances de $nomMois ${filtre.annee} sont déjà générées.'
                  : '${nouvelles.length} échéance(s) de loyer générée(s) pour $nomMois ${filtre.annee}.',
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la génération : $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _partagerSurWhatsApp(HistoriquePaiementLoyerItem item, String devise) async {
    final cleanTel = (item.locataireTelephone ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    final fmt = NumberFormat('#,##0', 'fr');
    final montant = '${fmt.format(item.montant)} $devise';
    final reste = '${fmt.format(item.resteAPayer)} $devise';
    final dateStr = DateFormat('dd/MM/yyyy à HH:mm').format(item.datePaiement);
    final titre = item.estQuittance ? 'Quittance de loyer' : 'Reçu d\'acompte de loyer';

    final refInfo = item.referencePaiement != null && item.referencePaiement!.isNotEmpty
        ? '\n🔖 *Réf. Transaction :* ${item.referencePaiement}'
        : '';

    final statutLigne = item.estSolde
        ? '✅ *Statut :* Loyer soldé en totalité'
        : '⏳ *Statut :* Paiement partiel (Reste dû : $reste)';

    final message = '''
🏢 *DubaGest — $titre*
━━━━━━━━━━━━━━━━━━━━━━
📄 *N° :* ${item.numeroDocument ?? 'REC'}
👤 *Locataire :* ${item.locataireNom}
🏠 *Bien :* ${item.bienNom}
📅 *Période :* ${item.periodeLibelle}
💰 *Montant versé :* $montant
💳 *Mode :* ${item.modeLibelle}$refInfo
$statutLigne
🗓️ *Date :* $dateStr
━━━━━━━━━━━━━━━━━━━━━━
_Document officiel généré par DubaGest._
''';

    final uri = cleanTel.isNotEmpty
        ? Uri.parse('https://wa.me/$cleanTel?text=${Uri.encodeComponent(message)}')
        : Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir WhatsApp.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = ref.watch(contexteActifProvider);
    final devise = ctx?.entreprise?.devise ?? 'FCFA';

    final filtre = ref.watch(filtreLoyersProvider);
    final filtreNotifier = ref.read(filtreLoyersProvider.notifier);
    final stats = ref.watch(recouvrementStatistiquesProvider);
    final echeances = ref.watch(echeancesFiltreesProvider);
    final echeancesAsync = ref.watch(echeancesLoyersProvider);
    final biens = ref.watch(biensListProvider).value ?? const [];
    final historiquePaiements = ref.watch(historiquePaiementsLoyersProvider);
    final fmt = NumberFormat('#,##0', 'fr');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loyers & Recouvrement'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
          tabs: [
            Tab(
              icon: const Icon(Icons.calendar_month_outlined, size: 20),
              text: 'Échéances (${echeances.length})',
            ),
            Tab(
              icon: const Icon(Icons.history_rounded, size: 20),
              text: 'Historique règlements (${historiquePaiements.length})',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_outlined),
            tooltip: 'Tableau de bord',
            onPressed: () => context.push(Routes.immobilierDashboard),
          ),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => _genererAppels(context),
            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
            label: const Text('Appels', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => context.push(Routes.loyerRecevoir),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Recevoir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: echeancesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => MessageView(
          icon: Icons.error_outline_rounded,
          title: 'Erreur de chargement',
          message: err.toString(),
        ),
        data: (_) => TabBarView(
          controller: _tabController,
          children: [
            // ==================== ONGLET 1 : ÉCHÉANCES & APPELS ====================
            RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(echeancesLoyersProvider);
                ref.invalidate(documentsProvider);
              },
              child: CustomScrollView(
                slivers: [
                  // 1. En-tête KPI Recouvrement
                  SliverToBoxAdapter(
                    child: RecouvrementStatsHeader(stats: stats, devise: devise),
                  ),

                  // 2. Barre de recherche & Filtre Bien
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Column(
                        children: [
                          TextField(
                            controller: _rechercheController,
                            decoration: InputDecoration(
                              hintText: 'Rechercher référence, locataire, bien...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _rechercheController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _rechercheController.clear();
                                        filtreNotifier.rechercher('');
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onChanged: filtreNotifier.rechercher,
                          ),
                          const SizedBox(height: 8),

                          // Sélecteur rapide de Bien & Mode "Toute l'année"
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String?>(
                                      value: filtre.bienId,
                                      isExpanded: true,
                                      hint: const Text('Tous les biens', style: TextStyle(fontSize: 12.5)),
                                      items: [
                                        const DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text('Tous les biens immobiliers', style: TextStyle(fontSize: 12.5)),
                                        ),
                                        for (final b in biens)
                                          DropdownMenuItem<String?>(
                                            value: b.id,
                                            child: Text('${b.nom} (${b.reference})', style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                                          ),
                                      ],
                                      onChanged: (id) => filtreNotifier.filtrerBien(id),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: Text(filtre.toutePeriode ? 'Année complète' : 'Mois en cours', style: const TextStyle(fontSize: 11.5)),
                                selected: filtre.toutePeriode,
                                onSelected: (_) => filtreNotifier.toggleToutePeriode(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Filtres par Statut Réglementaire Dynamique
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('Tous les statuts'),
                            selected: filtre.statutReglement == null,
                            onSelected: (_) => filtreNotifier.filtrerStatutReglement(null),
                          ),
                          const SizedBox(width: 8),
                          for (final reg in StatutReglementLoyer.values.where((r) => r != StatutReglementLoyer.annule)) ...[
                            FilterChip(
                              label: Text(reg.libelle),
                              avatar: Icon(reg.icone, size: 14, color: reg.couleur),
                              selected: filtre.statutReglement == reg,
                              onSelected: (_) => filtreNotifier.filtrerStatutReglement(reg),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // 4. Liste des échéances
                  if (echeances.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: MessageView(
                        icon: Icons.receipt_long_outlined,
                        title: 'Aucune échéance correspondante',
                        message: filtre.bienId != null || filtre.statutReglement != null
                            ? 'Aucun résultat avec les filtres sélectionnés.'
                            : 'Cliquez sur "Appels" pour générer les avis d\'échéance du mois.',
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final echeance = echeances[index];
                          return InkWell(
                            onTap: () => context.push(Routes.loyerDetails(echeance.id)),
                            borderRadius: BorderRadius.circular(14),
                            child: EcheanceLoyerCard(echeance: echeance),
                          );
                        },
                        childCount: echeances.length,
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),

            // ==================== ONGLET 2 : HISTORIQUE DES RÈGLEMENTS ====================
            RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(documentsProvider);
                ref.invalidate(echeancesLoyersProvider);
              },
              child: CustomScrollView(
                slivers: [
                  // Filtres de recherche pour l'historique
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        children: [
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Filtrer l\'historique (locataire, bien, reçu...)',
                              prefixIcon: const Icon(Icons.history_edu_rounded),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onChanged: filtreNotifier.rechercher,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String?>(
                                      value: filtre.bienId,
                                      isExpanded: true,
                                      hint: const Text('Tous les biens', style: TextStyle(fontSize: 12.5)),
                                      items: [
                                        const DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text('Tous les biens immobiliers', style: TextStyle(fontSize: 12.5)),
                                        ),
                                        for (final b in biens)
                                          DropdownMenuItem<String?>(
                                            value: b.id,
                                            child: Text('${b.nom} (${b.reference})', style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                                          ),
                                      ],
                                      onChanged: (id) => filtreNotifier.filtrerBien(id),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: Text(filtre.toutePeriode ? 'Tout l\'historique' : 'Ce mois', style: const TextStyle(fontSize: 11.5)),
                                selected: filtre.toutePeriode,
                                onSelected: (_) => filtreNotifier.toggleToutePeriode(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Liste des versements enregistrés
                  if (historiquePaiements.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: MessageView(
                        icon: Icons.payments_outlined,
                        title: 'Aucun paiement enregistré',
                        message: 'Les règlements effectués s\'afficheront ici chronologiquement avec quittances et reçus associés.',
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = historiquePaiements[index];
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: AppColors.border, width: 1.2),
                            ),
                            color: AppColors.surface,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Ligne 1: Type & Numéro Document + Date
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: (item.estQuittance ? const Color(0xFF10B981) : const Color(0xFFDF9540))
                                                  .withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              item.estQuittance ? Icons.verified_rounded : Icons.receipt_long_rounded,
                                              size: 16,
                                              color: item.estQuittance ? const Color(0xFF10B981) : const Color(0xFFDF9540),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            item.estQuittance
                                                ? 'Quittance ${item.numeroDocument ?? ""}'
                                                : 'Reçu d\'acompte ${item.numeroDocument ?? ""}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.ink,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        DateFormat('dd/MM/yyyy HH:mm').format(item.datePaiement),
                                        style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Ligne 2: Locataire & Bien loué
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.muted),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                item.locataireNom,
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (item.locataireTelephone != null)
                                              Text(
                                                item.locataireTelephone!,
                                                style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.home_work_outlined, size: 14, color: AppColors.muted),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                item.bienNom,
                                                style: const TextStyle(fontSize: 12, color: AppColors.ink),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              item.periodeLibelle,
                                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Ligne 3: Montant versé & Solde restant
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Montant encaissé', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                                          Text(
                                            '${fmt.format(item.montant)} $devise',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF10B981),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          const Text('Solde restant', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                                          Text(
                                            item.estSolde ? 'Soldé (0 $devise)' : '${fmt.format(item.resteAPayer)} $devise',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: item.estSolde ? const Color(0xFF10B981) : const Color(0xFFDF9540),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),

                                  // Mode de paiement & Réf
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: Text(
                                          item.modeLibelle,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.ink),
                                        ),
                                      ),
                                      if (item.referencePaiement != null && item.referencePaiement!.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          'Réf: ${item.referencePaiement}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                        ),
                                      ],
                                      const Spacer(),

                                      // Actions : Consulter / WhatsApp
                                      if (item.documentId != null)
                                        TextButton.icon(
                                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                          icon: const Icon(Icons.description_outlined, size: 16),
                                          label: const Text('Justificatif', style: TextStyle(fontSize: 12)),
                                          onPressed: () => context.push(Routes.document(item.documentId!)),
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.share_rounded, size: 18, color: Color(0xFF25D366)),
                                        tooltip: 'Partager sur WhatsApp',
                                        onPressed: () => _partagerSurWhatsApp(item, devise),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: historiquePaiements.length,
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_card_rounded),
        label: const Text('Recevoir un loyer', style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: () => context.push(Routes.loyerRecevoir),
      ),
    );
  }
}
