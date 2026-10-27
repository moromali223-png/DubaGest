import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../finances/presentation/providers/finances_providers.dart';
import '../../domain/entities/commerce.dart';
import '../commerce_providers.dart';
import '../widgets/choix_contact.dart';
import '../widgets/commerce_widgets.dart';

enum _FiltreAchats {
  tous('Tous'),
  brouillons('Brouillons'),
  confirmees('Confirmées'),
  envoyees('Envoyées'),
  recuPartiel('Partiellement reçues'),
  recus('Reçues'),
  annules('Annulées');

  const _FiltreAchats(this.libelle);
  final String libelle;
}

/// Écran principal « Bons de commande » avec indicateurs synthétiques,
/// recherche multi-critères et filtres par statut.
class AchatsPage extends ConsumerStatefulWidget {
  const AchatsPage({super.key});

  @override
  ConsumerState<AchatsPage> createState() => _AchatsPageState();
}

class _AchatsPageState extends ConsumerState<AchatsPage> {
  _FiltreAchats _filtre = _FiltreAchats.tous;
  String _recherche = '';
  final _rechercheCtrl = TextEditingController();

  @override
  void dispose() {
    _rechercheCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final droits = ref.watch(droitsCommerceProvider);
    final etatAsync = ref.watch(etatCommerceProvider);
    final boutiques = ref.watch(boutiquesVisiblesProvider).toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achats de marchandises'),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 4), child: BoutiqueSelecteur()),
          SyncStatusButton(),
        ],
      ),
      floatingActionButton: !droits.creerAchats
          ? null
          : FloatingActionButton.extended(
              key: const Key('achat-ajouter'),
              onPressed: () => context.push(Routes.achatNouveau()),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Réception d\'achat'),
              backgroundColor: const Color(0xFF123B6D),
              foregroundColor: Colors.white,
            ),
      body: ResponsiveBody(
        child: AsyncValueView(
          value: etatAsync,
          onRetry: () => ref.invalidate(etatCommerceProvider),
          data: (etat) {
            // Filtrage par boutique autorisée
            final tousAchatsBoutique = etat.achats.where((a) => boutiques.contains(a.perimetreId)).toList();

            // Calcul des indicateurs synthétiques
            final totalCommandes = tousAchatsBoutique.length;
            final commandesEnAttente = tousAchatsBoutique.where((a) => a.estBrouillon || a.estConfirmee || a.estEnvoyee).length;
            final commandesPartielles = tousAchatsBoutique.where((a) => a.statut == StatutAchat.recuPartiel).length;
            final commandesEntierementRecues = tousAchatsBoutique.where((a) => a.statut == StatutAchat.recu).length;
            final montantTotalCommandes = tousAchatsBoutique
                .where((a) => !a.annule)
                .fold<int>(0, (sum, a) => sum + a.total);

            // Filtrage selon le statut sélectionné et la recherche
            final achatsFiltres = tousAchatsBoutique.where((a) {
              // 1. Filtre statut
              final correspondStatut = switch (_filtre) {
                _FiltreAchats.tous => true,
                _FiltreAchats.brouillons => a.statut == StatutAchat.brouillon,
                _FiltreAchats.confirmees => a.statut == StatutAchat.commande,
                _FiltreAchats.envoyees => a.statut == StatutAchat.envoyee,
                _FiltreAchats.recuPartiel => a.statut == StatutAchat.recuPartiel,
                _FiltreAchats.recus => a.statut == StatutAchat.recu,
                _FiltreAchats.annules => a.annule,
              };
              if (!correspondStatut) return false;

              // 2. Filtre recherche textuelle
              if (_recherche.isEmpty) return true;
              final r = _recherche.toLowerCase();

              // N° commande / référence
              if ((a.reference ?? '').toLowerCase().contains(r)) return true;

              // Nom fournisseur
              final fournisseur = nomContact(ref, a.fournisseurId)?.toLowerCase() ?? '';
              if (fournisseur.contains(r)) return true;

              // Date
              final dateStr = DateFormat('dd/MM/yyyy').format(a.dateAchat);
              if (dateStr.contains(r)) return true;

              // Noms des produits commandés
              for (final l in a.lignes) {
                final nomProduit = etat.produit(l.produitId)?.nom.toLowerCase() ?? '';
                if (nomProduit.contains(r)) return true;
              }

              return false;
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Bannière vers les Bons de commande dans Documents
                Container(
                  margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined, color: Color(0xFF2563EB), size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bons de commande & Négociations fournisseurs',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E40AF)),
                            ),
                            Text(
                              'Pour négocier vos prix ou émettre un bon de commande officiel avant achat, utilisez le module Documents.',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF3B82F6)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        onPressed: () => context.push(Routes.documents),
                        child: const Text('Documents', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

                // 1. Bandeau KPI Synthétiques
                _BandeauKpiCommandes(
                  total: totalCommandes,
                  enAttente: commandesEnAttente,
                  partielles: commandesPartielles,
                  recues: commandesEntierementRecues,
                  montantTotal: montantTotalCommandes,
                ),

                // 2. Barre de recherche multi-critères
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                  child: TextField(
                    controller: _rechercheCtrl,
                    decoration: InputDecoration(
                      hintText: 'Rechercher par N° facture/réf, fournisseur, produit, date...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _recherche.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _rechercheCtrl.clear();
                                setState(() => _recherche = '');
                              },
                            )
                          : null,
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    onChanged: (v) => setState(() => _recherche = v.trim().toLowerCase()),
                  ),
                ),

                // 3. Barre horizontale des filtres de statut
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                    children: [
                      for (final f in _FiltreAchats.values)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
                          child: ChoiceChip(
                            label: Text(f.libelle),
                            selected: _filtre == f,
                            onSelected: (_) => setState(() => _filtre = f),
                          ),
                        ),
                    ],
                  ),
                ),

                // 4. Liste des bons de commande
                Expanded(
                  child: achatsFiltres.isEmpty
                      ? (tousAchatsBoutique.isEmpty
                          ? EtatVide(
                              icone: Icons.shopping_cart_outlined,
                              titre: 'Aucun bon de commande',
                              message: 'Créez votre premier bon de commande pour approvisionner vos stocks.',
                              action: droits.creerAchats ? 'Nouveau bon de commande' : null,
                              onAction: () => context.push(Routes.achatNouveau()),
                            )
                          : Center(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Text(
                                  'Aucun bon de commande ne correspond aux filtres appliqués.',
                                  style: TextStyle(color: Theme.of(context).colorScheme.outline),
                                ),
                              ),
                            ))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, 96),
                          itemCount: achatsFiltres.length,
                          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (_, i) => AchatCarte(achat: achatsFiltres[i]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Bandeau horizontal d'indicateurs synthétiques pour les commandes.
class _BandeauKpiCommandes extends ConsumerWidget {
  const _BandeauKpiCommandes({
    required this.total,
    required this.enAttente,
    required this.partielles,
    required this.recues,
    required this.montantTotal,
  });

  final int total;
  final int enAttente;
  final int partielles;
  final int recues;
  final int montantTotal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: Row(
        children: [
          _CarteKpi(
            titre: 'Total achats',
            valeur: '$total',
            icone: Icons.inventory_2_outlined,
            couleur: const Color(0xFF123B6D),
            fond: const Color(0xFFE8EEFA),
          ),
          const SizedBox(width: 8),
          _CarteKpi(
            titre: 'En attente réception',
            valeur: '$enAttente',
            icone: Icons.hourglass_top_outlined,
            couleur: const Color(0xFF2563EB),
            fond: const Color(0xFFDBEAFE),
          ),
          const SizedBox(width: 8),
          _CarteKpi(
            titre: 'Partiellement reçus',
            valeur: '$partielles',
            icone: Icons.incomplete_circle_outlined,
            couleur: const Color(0xFFD99A2B),
            fond: const Color(0xFFFEF3C7),
          ),
          const SizedBox(width: 8),
          _CarteKpi(
            titre: 'Entièrement en stock',
            valeur: '$recues',
            icone: Icons.check_circle_outline,
            couleur: AppColors.positive,
            fond: AppColors.positiveSoft,
          ),
          const SizedBox(width: 8),
          _CarteKpi(
            titre: 'Total des achats',
            valeur: montant(context, ref, montantTotal),
            icone: Icons.payments_outlined,
            couleur: const Color(0xFF172033),
            fond: const Color(0xFFF1F5F9),
            estMontant: true,
          ),
        ],
      ),
    );
  }
}

class _CarteKpi extends StatelessWidget {
  const _CarteKpi({
    required this.titre,
    required this.valeur,
    required this.icone,
    required this.couleur,
    required this.fond,
    this.estMontant = false,
  });

  final String titre;
  final String valeur;
  final IconData icone;
  final Color couleur;
  final Color fond;
  final bool estMontant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: couleur.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 20, color: couleur),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                titre,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: couleur.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 1),
              Text(
                valeur,
                style: TextStyle(
                  fontSize: estMontant ? 13 : 15,
                  fontWeight: FontWeight.w800,
                  color: couleur,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

(String, Color, Color) visuelStatutAchat(AppLocalizations l10n, StatutAchat s) => switch (s) {
      StatutAchat.brouillon => ('Brouillon', AppColors.muted, AppColors.border),
      StatutAchat.commande => (l10n.comStatusOrdered, const Color(0xFF2563EB), const Color(0xFFDBEAFE)),
      StatutAchat.envoyee => ('Envoyée', const Color(0xFF7C3AED), const Color(0xFFEDE9FE)),
      StatutAchat.recuPartiel => (l10n.comStatusPartlyReceived, const Color(0xFFD99A2B), const Color(0xFFFEF3C7)),
      StatutAchat.recu => (l10n.comStatusReceived, AppColors.positive, AppColors.positiveSoft),
      StatutAchat.annule => (l10n.comStatusCancelled, AppColors.negative, AppColors.negativeSoft),
    };

class StatutAchatPuce extends StatelessWidget {
  const StatutAchatPuce({super.key, required this.statut});
  final StatutAchat statut;

  @override
  Widget build(BuildContext context) {
    final (texte, fg, bg) = visuelStatutAchat(context.l10n, statut);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(texte, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}

class AchatCarte extends ConsumerWidget {
  const AchatCarte({super.key, required this.achat});
  final Achat achat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final a = achat;
    final etat = ref.watch(etatCommerceProvider).value;
    final finances = ref.watch(etatFinancesProvider).value;
    final dette = finances?.engagements.where((e) => e.id == a.id).map(finances.suivi).firstOrNull;
    final produits = [for (final l in a.lignes) ?etat?.produit(l.produitId)];

    // Titre de référence : BC-2026-00001 ou Réf
    final titreReference = a.reference != null && a.reference!.isNotEmpty
        ? a.reference!
        : 'BC #${a.id.substring(0, 8).toUpperCase()}';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        key: Key('achat-${a.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(Routes.achat(a.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ligne 1 : Numéro BC, Statut, Badge Sync
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF123B6D).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      titreReference,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF123B6D)),
                    ),
                  ),
                  const Spacer(),
                  StatutAchatPuce(statut: a.statut),
                  const SizedBox(width: 4),
                  RecordSyncBadge(status: a.syncStatus),
                ],
              ),
              const SizedBox(height: 8),

              // Ligne 2 : Fournisseur & Date / Boutique
              Row(
                children: [
                  const Icon(Icons.business_outlined, size: 16, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      nomContact(ref, a.fournisseurId) ?? 'Fournisseur non spécifié',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  DateFormat('dd/MM/yyyy').format(a.dateAchat),
                  nomBoutique(ref, a.perimetreId),
                  '${a.lignes.length} article${a.lignes.length > 1 ? 's' : ''}',
                ].join(' · '),
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const Divider(height: 18),

              // Ligne 3 : Produits (miniatures) & Montant Total / Dette
              Row(
                children: [
                  for (final p in produits.take(4))
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ProduitImage(produit: p, taille: 36, rayon: 8),
                    ),
                  if (produits.length > 4)
                    Text('+${produits.length - 4}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        montant(context, ref, a.total),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Color(0xFF172033),
                        ),
                      ),
                      if (dette != null && dette.reste > 0 && !a.annule)
                        Text(
                          '${l10n.comDebt} : ${montant(context, ref, dette.reste)}',
                          style: const TextStyle(
                            color: Color(0xFFD99A2B),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
