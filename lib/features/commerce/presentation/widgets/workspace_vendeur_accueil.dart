import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/app_header_buttons.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../entreprise/domain/entities/contexte_session.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../entreprise/presentation/providers/espace_providers.dart';
import '../../../finances/domain/entities/finances.dart' show ModePaiement;
import '../../../finances/presentation/providers/finances_providers.dart';
import '../../domain/entities/commerce.dart';
import '../../domain/services/etat_commerce.dart';
import '../commerce_providers.dart';
import '../recus/recu_vente.dart';
import '../recus/recu_vente_widgets.dart';
import 'choix_contact.dart';
import 'commerce_widgets.dart';

/// Workspace Vendeur — Accueil épuré, centré sur le métier :
/// VENDRE → ENCAISSER → DONNER LE REÇU.
class WorkspaceVendeurAccueil extends ConsumerWidget {
  const WorkspaceVendeurAccueil({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ctx = ref.watch(contexteActifProvider);
    final etat = ref.watch(etatCommerceProvider).value;
    final espace = ref.watch(espaceCourantProvider);

    if (ctx == null) return const SizedBox.shrink();

    final prenom = ctx.nomComplet?.split(' ').first ?? 'Vendeur';
    final boutiqueCouranteId = espace.perimetreId ?? ref.watch(boutiqueCouranteProvider);
    final nomBoutiqueAffichee = boutiqueCouranteId != null
        ? nomBoutique(ref, boutiqueCouranteId)
        : (ctx.perimetres.where((p) => p.activite == espace.activite).firstOrNull?.nom ?? 'Boutique');

    // Récupération des ventes de la journée pour le vendeur
    final now = DateTime.now();
    final debutJour = DateTime(now.year, now.month, now.day);
    final finJour = debutJour.add(const Duration(days: 1));

    final ventesToutes = etat?.ventes ?? const <Vente>[];
    final ventesBoutique = ventesToutes.where((v) {
      if (boutiqueCouranteId != null && v.perimetreId != boutiqueCouranteId) return false;
      return !v.annulee;
    }).toList();

    final ventesJour = ventesBoutique.where((v) {
      return v.date.isAfter(debutJour) && v.date.isBefore(finJour);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final totalVendu = ventesJour.fold<int>(0, (sum, v) => sum + v.total);
    final nbVentes = ventesJour.length;
    final articlesVendus = ventesJour.fold<num>(
      0,
      (sum, v) => sum + v.lignes.fold<num>(0, (s, l) => s + l.quantite.valeur),
    ).toInt();
    final panierMoyen = nbVentes > 0 ? (totalVendu ~/ nbVentes) : 0;

    // Répartition des règlements
    int especes = 0;
    int mobileMoney = 0;
    int carte = 0;
    int credit = 0;

    for (final v in ventesJour) {
      if (v.reglement == ReglementVente.credit || (v.montantPaye < v.total && v.montantPaye == 0)) {
        credit += v.total;
      } else {
        final mode = (v.modePaiement ?? '').toUpperCase();
        if (mode.contains('MOBILE') || mode.contains('ORANGE') || mode.contains('WAVE') || mode.contains('MOOV')) {
          mobileMoney += v.total;
        } else if (mode.contains('CARTE') || mode.contains('CARD')) {
          carte += v.total;
        } else {
          especes += v.total;
        }
      }
    }

    final contacts = {for (final c in ref.watch(tousContactsProvider).value ?? const <Contact>[]) c.id: c};
    final formatHeure = DateFormat.Hm(Localizations.localeOf(context).toString());

    return RefreshIndicator(
      onRefresh: () => ref.read(contexteSessionProvider.notifier).rafraichir(),
      child: ResponsiveBody(
        maxWidth: 720,
        child: ListView(
          key: const Key('workspace-vendeur-accueil'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // 1. Header Vendeur : Profil épuré, Boutique active et Statut Synchro
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Builder(
                  builder: (scaffoldContext) =>
                      AppMenuButton(onPressed: () => Scaffold.of(scaffoldContext).openDrawer()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bonjour $prenom',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF01226C).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.storefront_rounded, size: 14, color: Color(0xFF01226C)),
                                const SizedBox(width: 4),
                                Text(
                                  nomBoutiqueAffichee,
                                  style: const TextStyle(
                                    color: Color(0xFF01226C),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
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

            // 2. Bouton Géant « + NOUVELLE VENTE »
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('btn-nouvelle-vente-vendeur'),
                borderRadius: BorderRadius.circular(18),
                onTap: () => context.push(Routes.ventes),
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF01226C), Color(0xFF0C3D9A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF01226C).withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.green,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.green.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add_shopping_cart_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NOUVELLE VENTE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Enregistrer une vente en quelques secondes',
                              style: TextStyle(
                                color: AppColors.onInkMuted,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 18),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // 3. Section « Ma journée » (4 KPIs)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ma journée',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                Text(
                  l10n.rcpPeriodToday,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Grille 2x2 des KPIs
            Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    icon: Icons.payments_rounded,
                    iconColor: AppColors.green,
                    title: 'Total vendu',
                    value: montant(context, ref, totalVendu),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _KpiCard(
                    icon: Icons.receipt_long_rounded,
                    iconColor: const Color(0xFF01226C),
                    title: 'Ventes',
                    value: '$nbVentes',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    icon: Icons.inventory_2_outlined,
                    iconColor: const Color(0xFFDF9540),
                    title: 'Articles vendus',
                    value: '$articlesVendus',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _KpiCard(
                    icon: Icons.shopping_basket_outlined,
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'Panier moyen',
                    value: montant(context, ref, panierMoyen),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Répartition des règlements
            if (totalVendu > 0) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Règlements reçus',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.ink),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (especes > 0)
                          _ReglementChip(
                            label: 'Espèces',
                            montant: montant(context, ref, especes),
                            color: AppColors.green,
                          ),
                        if (mobileMoney > 0)
                          _ReglementChip(
                            label: 'Mobile Money',
                            montant: montant(context, ref, mobileMoney),
                            color: const Color(0xFF01226C),
                          ),
                        if (carte > 0)
                          _ReglementChip(
                            label: 'Carte',
                            montant: montant(context, ref, carte),
                            color: const Color(0xFF8B5CF6),
                          ),
                        if (credit > 0)
                          _ReglementChip(
                            label: 'À crédit',
                            montant: montant(context, ref, credit),
                            color: AppColors.warning,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // 4. Section « Mes ventes récentes »
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mes ventes récentes',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(Routes.historiqueVentes),
                  child: const Text('Voir tout →', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            if (ventesJour.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 44, color: AppColors.muted),
                    const SizedBox(height: 10),
                    const Text(
                      'Vous n\'avez pas encore effectué de vente aujourd\'hui.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Appuyez sur Nouvelle vente pour enregistrer votre premier encaissement.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(180, 42)),
                      onPressed: () => context.push(Routes.ventes),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('Nouvelle vente'),
                    ),
                  ],
                ),
              )
            else
              Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    for (final (i, v) in ventesJour.take(5).indexed) ...[
                      if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        onTap: () => context.push(Routes.vente(v.id)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.greenSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.receipt_rounded, color: AppColors.green, size: 20),
                        ),
                        title: Text(
                          v.numero ?? 'REC-${DateFormat('yyyyMMdd').format(v.date)}-${v.sequence ?? 1}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.ink),
                        ),
                        subtitle: Text(
                          '${contacts[v.contactId]?.nomAffiche ?? "Client comptoir"} · ${formatHeure.format(v.date.toLocal())}',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              montant(context, ref, v.total),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.ink),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              v.reglement == ReglementVente.credit ? 'À crédit' : (v.modePaiement ?? 'Espèces'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: v.reglement == ReglementVente.credit ? AppColors.warning : AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: AppSpacing.lg),
            // Raccourci vers le module Commerce Ventes si test/inspection
            Semantics(
              label: 'Module Ventes',
              child: InkWell(
                key: const ValueKey('module-commerce.ventes'),
                onTap: () => context.push(Routes.ventes),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.point_of_sale_rounded, color: AppColors.green, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Accéder au catalogue & ventes',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.ink),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ReglementChip extends StatelessWidget {
  const _ReglementChip({
    required this.label,
    required this.montant,
    required this.color,
  });

  final String label;
  final String montant;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '$label : ',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
          Flexible(
            child: Text(
              montant,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
