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
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../entreprise/presentation/providers/espace_providers.dart';
import '../../domain/entities/commerce.dart';
import '../../domain/entities/quantite.dart';
import '../../domain/services/etat_commerce.dart';
import '../commerce_providers.dart';
import 'choix_produit.dart';
import 'commerce_widgets.dart';
import 'fiche_scan.dart';
import 'operation_stock.dart';
import 'scanner.dart';

/// Workspace Gestionnaire de Stock — Accueil dédié, centré sur le métier :
/// VOIR → CONTRÔLER → AGIR → VÉRIFIER.
/// Aucun jargon financier, focus total sur la disponibilité et la traçabilité.
class WorkspaceGestionnaireStockAccueil extends ConsumerWidget {
  const WorkspaceGestionnaireStockAccueil({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ctx = ref.watch(contexteActifProvider);
    final etat = ref.watch(etatCommerceProvider).value;
    final espace = ref.watch(espaceCourantProvider);

    if (ctx == null) return const SizedBox.shrink();

    final prenom = ctx.nomComplet?.split(' ').first ?? 'Gestionnaire';
    final boutiqueCouranteId = espace.perimetreId ?? ref.watch(boutiqueCouranteProvider);
    final boutiquesVisibles = ref.watch(boutiquesVisiblesProvider);
    final nomBoutiqueAffichee = boutiqueCouranteId != null
        ? nomBoutique(ref, boutiqueCouranteId)
        : (ctx.perimetres.where((p) => p.activite == espace.activite).firstOrNull?.nom ?? 'Boutique');

    // Calculs de synthèse stock
    final resume = etat?.resume(boutiquesVisibles) ??
        const ResumeStock(produits: 0, faibles: 0, ruptures: 0, mouvementsDuJour: 0);

    final produitsASurveiller = etat?.aSurveiller(boutiquesVisibles) ?? const <Produit>[];

    // Mouvements récents
    final mouvementsRecents = (etat?.mouvements ?? const <MouvementStock>[])
        .where((m) => boutiqueCouranteId == null || m.perimetreId == boutiqueCouranteId)
        .take(6)
        .toList();

    final formatHeure = DateFormat.Hm(Localizations.localeOf(context).toString());

    return RefreshIndicator(
      onRefresh: () => ref.read(contexteSessionProvider.notifier).rafraichir(),
      child: ResponsiveBody(
        maxWidth: 820,
        child: ListView(
          key: const Key('workspace-gestionnaire-stock-accueil'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // 1. Header Gestionnaire de Stock
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
                        'Bonjour $prenom 👋',
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
                                const Icon(Icons.inventory_2_rounded, size: 14, color: Color(0xFF01226C)),
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
                BoutonScanner(onCode: (code) => traiterCodeScanne(context, ref, code)),
                const SizedBox(width: 6),
                const SyncStatusButton(boxed: true),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // 2. Grille des 4 KPIs Essentiels
            Row(
              children: [
                Expanded(
                  child: _KpiStockCard(
                    key: const Key('kpi-stock-faible'),
                    titre: 'Stock faible',
                    valeur: '${resume.faibles}',
                    icone: Icons.warning_amber_rounded,
                    couleur: const Color(0xFFDF9540),
                    onTap: () => context.push(Routes.stock),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _KpiStockCard(
                    key: const Key('kpi-stock-rupture'),
                    titre: 'Ruptures',
                    valeur: '${resume.ruptures}',
                    icone: Icons.error_outline_rounded,
                    couleur: const Color(0xFFE53935),
                    onTap: () => context.push(Routes.stock),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _KpiStockCard(
                    key: const Key('kpi-stock-mouvements'),
                    titre: 'Mouvements',
                    valeur: '${resume.mouvementsDuJour}',
                    icone: Icons.swap_horiz_rounded,
                    couleur: const Color(0xFF01226C),
                    onTap: () => context.push(Routes.mouvementsStock),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _KpiStockCard(
                    key: const Key('kpi-stock-produits'),
                    titre: 'Produits',
                    valeur: '${resume.produits}',
                    icone: Icons.category_rounded,
                    couleur: AppColors.green,
                    onTap: () => context.push(Routes.produits),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // 3. Actions Rapides
            Text(
              'Actions rapides',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _ActionRapideBouton(
                    key: const Key('btn-action-entree'),
                    titre: '+ Entrée',
                    sousTitre: 'Réception / Ajout',
                    icone: Icons.add_circle_outline_rounded,
                    couleur: AppColors.green,
                    onTap: () => _declencherAction(context, ref, OperationStock.entree, boutiqueCouranteId),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionRapideBouton(
                    key: const Key('btn-action-sortie'),
                    titre: '− Sortie',
                    sousTitre: 'Perte / Casse',
                    icone: Icons.remove_circle_outline_rounded,
                    couleur: const Color(0xFFE53935),
                    onTap: () => _declencherAction(context, ref, OperationStock.sortie, boutiqueCouranteId),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ActionRapideBouton(
                    key: const Key('btn-action-transfert'),
                    titre: '⇄ Transfert',
                    sousTitre: 'Entre boutiques',
                    icone: Icons.swap_horizontal_circle_outlined,
                    couleur: const Color(0xFF01226C),
                    onTap: () => _declencherAction(context, ref, OperationStock.transfert, boutiqueCouranteId),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionRapideBouton(
                    key: const Key('btn-action-inventaire'),
                    titre: '📋 Inventaire',
                    sousTitre: 'Comptage physique',
                    icone: Icons.checklist_rounded,
                    couleur: const Color(0xFF8B5CF6),
                    onTap: () => _declencherAction(context, ref, OperationStock.inventaire, boutiqueCouranteId),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // 4. Alertes Stock
            Row(
              children: [
                Expanded(
                  child: Text(
                    '⚠️ Alertes stock',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                if (produitsASurveiller.isNotEmpty)
                  TextButton(
                    onPressed: () => context.push(Routes.stock),
                    child: const Text('Voir tout', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            if (produitsASurveiller.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.green.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: AppColors.green, size: 28),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tout va bien',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.green,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Aucun produit n\'est actuellement sous son seuil minimum.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  for (final p in produitsASurveiller.take(4))
                    _AlerteProduitItem(
                      produit: p,
                      etat: etat,
                      boutiques: boutiquesVisibles,
                      onEntree: () => ouvrirOperationStock(
                        context,
                        produit: p,
                        operation: OperationStock.entree,
                        perimetreId: boutiqueCouranteId,
                      ),
                      onVoir: () => context.push(Routes.produit(p.id)),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.xl),

            // 5. Dernières Opérations
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Dernières opérations',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(Routes.mouvementsStock),
                  child: const Text('Historique', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            if (mouvementsRecents.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.history_rounded, size: 36, color: AppColors.muted),
                    SizedBox(height: 8),
                    Text(
                      'Aucun mouvement récent',
                      style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: 15),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Les entrées, sorties, ventes et transferts apparaîtront ici automatiquement.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  for (final m in mouvementsRecents)
                    _MouvementItem(
                      mouvement: m,
                      produit: etat?.produits.where((p) => p.id == m.produitId).firstOrNull,
                      formatHeure: formatHeure,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _declencherAction(
    BuildContext context,
    WidgetRef ref,
    OperationStock op,
    String? perimetreId,
  ) async {
    final produit = await choisirProduit(
      context,
      titre: switch (op) {
        OperationStock.entree => 'Choisir le produit à entrer',
        OperationStock.sortie => 'Choisir le produit à sortir',
        OperationStock.transfert => 'Choisir le produit à transférer',
        OperationStock.inventaire => 'Choisir le produit à inventorier',
      },
    );
    if (produit != null && context.mounted) {
      await ouvrirOperationStock(
        context,
        produit: produit,
        operation: op,
        perimetreId: perimetreId,
      );
    }
  }
}

class _KpiStockCard extends StatelessWidget {
  const _KpiStockCard({
    super.key,
    required this.titre,
    required this.valeur,
    required this.icone,
    required this.couleur,
    required this.onTap,
  });

  final String titre;
  final String valeur;
  final IconData icone;
  final Color couleur;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icone, color: couleur, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      valeur,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      titre,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
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
}

class _ActionRapideBouton extends StatelessWidget {
  const _ActionRapideBouton({
    super.key,
    required this.titre,
    required this.sousTitre,
    required this.icone,
    required this.couleur,
    required this.onTap,
  });

  final String titre;
  final String sousTitre;
  final IconData icone;
  final Color couleur;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: couleur.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: couleur.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icone, color: couleur, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titre,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: couleur,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      sousTitre,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.muted,
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
}

class _AlerteProduitItem extends StatelessWidget {
  const _AlerteProduitItem({
    required this.produit,
    required this.etat,
    required this.boutiques,
    required this.onEntree,
    required this.onVoir,
  });

  final Produit produit;
  final EtatCommerce? etat;
  final List<String> boutiques;
  final VoidCallback onEntree;
  final VoidCallback onVoir;

  @override
  Widget build(BuildContext context) {
    final statut = etat?.statutDans(produit, boutiques) ?? StatutStock.faible;
    final qte = etat?.quantite(produit.id, boutiques) ?? Qte.zero;
    final uniteAffichee = produit.plusGrandeUnite;
    final quantiteConvertie = qte.divisePar(uniteAffichee.facteur);

    final isRupture = statut == StatutStock.rupture;
    final couleur = isRupture ? const Color(0xFFE53935) : const Color(0xFFDF9540);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: couleur.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          ProduitImage(produit: produit, taille: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  produit.nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.ink),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: couleur.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isRupture ? '🔴 Rupture' : '🟠 Faible (${formatQte(context, quantiteConvertie)} ${uniteAffichee.nom})',
                        style: TextStyle(
                          color: couleur,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: '+ Entrée',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.green.withValues(alpha: 0.12),
              foregroundColor: AppColors.green,
            ),
            onPressed: onEntree,
            icon: const Icon(Icons.add_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _MouvementItem extends StatelessWidget {
  const _MouvementItem({
    required this.mouvement,
    required this.produit,
    required this.formatHeure,
  });

  final MouvementStock mouvement;
  final Produit? produit;
  final DateFormat formatHeure;

  @override
  Widget build(BuildContext context) {
    final estPositif = mouvement.delta.estPositif;
    final couleur = estPositif ? AppColors.green : (mouvement.delta.estNul ? AppColors.muted : const Color(0xFFE53935));

    final libelleType = switch (mouvement.type) {
      TypeMouvementStock.entree => 'Entrée',
      TypeMouvementStock.sortie => 'Sortie',
      TypeMouvementStock.transfertEntree => 'Transfert reçu',
      TypeMouvementStock.transfertSortie => 'Transfert envoyé',
      TypeMouvementStock.inventaire => 'Inventaire',
    };

    final libelleMotif = switch (mouvement.motif) {
      MotifMouvement.achat => 'Achat',
      MotifMouvement.vente => 'Vente',
      MotifMouvement.perte => 'Perte',
      MotifMouvement.casse => 'Casse',
      MotifMouvement.transfert => 'Transfert',
      MotifMouvement.ajustement => 'Ajustement',
      MotifMouvement.erreurComptage => 'Comptage',
      MotifMouvement.manquant => 'Manquant',
      MotifMouvement.retour => 'Retour',
      MotifMouvement.autre => 'Autre',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${estPositif ? '+' : ''}${formatQte(context, mouvement.delta.absolue)}',
              style: TextStyle(
                color: couleur,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  produit?.nom ?? 'Produit',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.ink),
                ),
                Text(
                  '$libelleType • $libelleMotif',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Text(
            formatHeure.format(mouvement.date),
            style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
