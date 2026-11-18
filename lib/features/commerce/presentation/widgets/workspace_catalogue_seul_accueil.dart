import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/app_header_buttons.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/commerce.dart';
import '../commerce_providers.dart';

/// Workspace Accueil dédié exclusivement au Mode B — DubaGest Catalogue Seul.
/// Isolation stricte : aucun affichage de stock, ventes, caisse, dettes ou dépenses.
class WorkspaceCatalogueSeulAccueil extends ConsumerWidget {
  const WorkspaceCatalogueSeulAccueil({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ctx = ref.watch(contexteActifProvider);
    final etat = ref.watch(etatCommerceProvider).value;

    if (ctx == null) return const SizedBox.shrink();

    final nomEntreprise = ctx.entreprise?.nom ?? 'Ma Boutique';
    final prenom = ctx.nomComplet?.split(' ').first ?? 'Commerçant';
    final produits = etat?.produits ?? const <Produit>[];
    final produitsCatalogue = produits.where((p) => p.estActif).toList();

    // Construction de l'URL publique de la boutique
    final slug = nomEntreprise.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
    final urlBoutique = 'https://dubagest.com/boutique/$slug';

    return ResponsiveBody(
      maxWidth: 960,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        children: [
          // En-tête AppBar personnalisée
          Row(
            children: [
              AppMenuButton(onPressed: () => Scaffold.of(context).openDrawer()),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nomEntreprise,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.ink),
                    ),
                    const Row(
                      children: [
                        Icon(Icons.auto_stories_rounded, size: 12, color: Color(0xFF0284C7)),
                        SizedBox(width: 4),
                        Text(
                          'Catalogue Numérique V2',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SyncStatusButton(boxed: true),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Bannière Vitrine en ligne & Partage
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0369A1), Color(0xFF0284C7)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.public_rounded, size: 14, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Boutique en ligne active',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copier le lien public',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: urlBoutique));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Lien de la boutique copié dans le presse-papier !'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Bonjour $prenom, votre catalogue est prêt.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  urlBoutique,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0369A1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text('Ajouter un produit', style: TextStyle(fontWeight: FontWeight.w800)),
                        onPressed: () => context.push(Routes.produitNouveau()),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Partager', style: TextStyle(fontWeight: FontWeight.w800)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: urlBoutique));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Lien public copié : $urlBoutique'),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Statistiques Catalogue Numérique
          Row(
            children: [
              Expanded(
                child: _CatalogueStatCard(
                  icon: Icons.inventory_2_rounded,
                  label: 'Produits au catalogue',
                  value: '${produitsCatalogue.length}',
                  color: const Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: _CatalogueStatCard(
                  icon: Icons.chat_rounded,
                  label: 'Commandes WhatsApp',
                  value: 'Activées',
                  color: Color(0xFF16A34A),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Titre section Mes Produits
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mes Produits au Catalogue',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.ink),
              ),
              if (produitsCatalogue.isNotEmpty)
                TextButton(
                  onPressed: () => context.go(Routes.produits),
                  child: const Text('Voir tout', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Liste des produits ou vue vide
          if (produitsCatalogue.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0F2FE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_photo_alternate_rounded, size: 40, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Aucun produit pour le moment',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ajoutez vos photos, vos prix et vos présentations vocales pour attirer vos clients.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Ajouter mon premier produit', style: TextStyle(fontWeight: FontWeight.w800)),
                    onPressed: () => context.push(Routes.produitNouveau()),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: produitsCatalogue.take(10).length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final p = produitsCatalogue[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF0284C7)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.nom,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.ink),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.montant(p.prixDetail, 'XOF'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Modifier',
                        icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.muted),
                        onPressed: () => context.push(Routes.produitModifier(p.id)),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _CatalogueStatCard extends StatelessWidget {
  const _CatalogueStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.ink),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
