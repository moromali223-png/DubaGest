import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../roles/domain/entities/role.dart';
import '../../domain/entities/document.dart';

/// BottomSheet de sélection du type de document à créer.
///
/// Ouvre directement le formulaire complet dédié du document choisi
/// (Devis, Facture, Bon de commande, Avoir, Reçu, Intervention).
class SelectionTypeDocumentSheet extends ConsumerWidget {
  const SelectionTypeDocumentSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SelectionTypeDocumentSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ctx = ref.watch(contexteActifProvider);

    if (ctx == null) {
      return const SizedBox.shrink();
    }

    final activites = ctx.activites;
    final hasCommerce = activites.any((a) => a.activite == ActiviteCode.commerce && a.estActive);
    final hasServices = activites.any((a) => a.activite == ActiviteCode.services && a.estActive);
    final hasImmobilier = activites.any((a) => a.activite == ActiviteCode.immobilier && a.estActive);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barre d'accroche supérieure
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // En-tête avec titre et bouton fermer
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nouveau document',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Choisissez le type de document adapté à votre besoin',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 1. DEVIS / PROFORMA
                    if (hasServices || hasCommerce)
                      _TypeDocumentItem(
                        icon: Icons.request_quote_outlined,
                        color: const Color(0xFF2563EB),
                        background: const Color(0xFFEFF6FF),
                        badge: hasServices ? 'Services' : 'Commerce',
                        title: 'Devis / Offre de prix',
                        subtitle: 'Proposition chiffrée avec validité, remises et conditions',
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push(Routes.documentNouveau(type: TypeDocument.devis.name));
                        },
                      ),

                    // 2. FACTURE CLIENT
                    if (hasCommerce || hasServices)
                      _TypeDocumentItem(
                        icon: Icons.receipt_long,
                        color: AppColors.green,
                        background: AppColors.greenSoft,
                        badge: 'Officiel',
                        title: 'Facture client',
                        subtitle: 'Facture avec articles, montants, remises et échéances',
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push(Routes.documentNouveau(type: TypeDocument.facture.name));
                        },
                      ),

                    // 3. BON DE COMMANDE
                    if (ctx.membre?.roleCode != RoleCodes.superviseur)
                      _TypeDocumentItem(
                        icon: Icons.shopping_cart_checkout,
                        color: const Color(0xFFEA580C),
                        background: const Color(0xFFFFF7ED),
                        badge: hasCommerce ? 'Commerce' : 'Officiel',
                        title: 'Bon de commande',
                        subtitle: 'Commande fournisseur ou achat avec articles, unités et conditions',
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push(Routes.documentNouveau(type: TypeDocument.bonCommande.name));
                        },
                      ),

                    // 4. AVOIR / NOTE DE CRÉDIT
                    if (hasCommerce || hasServices)
                      _TypeDocumentItem(
                        icon: Icons.assignment_return_outlined,
                        color: const Color(0xFFDC2626),
                        background: const Color(0xFFFEE2E2),
                        badge: 'Comptabilité',
                        title: 'Avoir / Note de crédit',
                        subtitle: 'Correction ou remboursement lié à une facture émise',
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push(Routes.documentNouveau(type: TypeDocument.avoir.name));
                        },
                      ),

                    // 5. REÇU DE PAIEMENT
                    _TypeDocumentItem(
                      icon: Icons.receipt_outlined,
                      color: AppColors.green,
                      background: const Color(0xFFDCFCE7),
                      badge: 'Finances',
                      title: 'Reçu de paiement',
                      subtitle: 'Attestation officielle pour un encaissement ou règlement',
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push(Routes.documentNouveau(type: TypeDocument.recu.name));
                      },
                    ),

                    // 6. BON DE TRAVAIL / INTERVENTION (Services)
                    if (hasServices)
                      _TypeDocumentItem(
                        icon: Icons.build_circle_outlined,
                        color: const Color(0xFF0D9488),
                        background: const Color(0xFFCCFBF1),
                        badge: 'Services',
                        title: 'Ordre de travail / Intervention',
                        subtitle: 'Fiche d\'intervention ou prestation technique avec prestations et pièces',
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push(Routes.documentNouveau(type: TypeDocument.bonTravail.name));
                        },
                      ),

                    // 7. QUITTANCE DE LOYER (Immobilier uniquement)
                    if (hasImmobilier)
                      _TypeDocumentItem(
                        icon: Icons.home_work_outlined,
                        color: const Color(0xFF059669),
                        background: const Color(0xFFECFDF5),
                        badge: 'Immobilier',
                        title: 'Quittance de loyer',
                        subtitle: 'Justificatif de loyer pour un locataire sur un bail actif',
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push(ModuleRoutes.path('immobilier.loyers'));
                        },
                      ),

                    // 8. CONTRAT DE BAIL (Immobilier uniquement)
                    if (hasImmobilier)
                      _TypeDocumentItem(
                        icon: Icons.handshake_outlined,
                        color: const Color(0xFF4F46E5),
                        background: const Color(0xFFEEF2FF),
                        badge: 'Immobilier',
                        title: 'Contrat de bail',
                        subtitle: 'Bail locatif rattaché à un bien et à un locataire',
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push(ModuleRoutes.path('immobilier.contrats'));
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeDocumentItem extends StatelessWidget {
  const _TypeDocumentItem({
    required this.icon,
    required this.color,
    required this.background,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String badge;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
