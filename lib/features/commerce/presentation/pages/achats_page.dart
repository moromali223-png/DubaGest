import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

enum _FiltreAchats { tous, aRecevoir, recus, annules }

/// Achats auprès des fournisseurs : à recevoir, reçus, annulés.
class AchatsPage extends ConsumerStatefulWidget {
  const AchatsPage({super.key});

  @override
  ConsumerState<AchatsPage> createState() => _AchatsPageState();
}

class _AchatsPageState extends ConsumerState<AchatsPage> {
  _FiltreAchats _filtre = _FiltreAchats.tous;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final droits = ref.watch(droitsCommerceProvider);
    final etatAsync = ref.watch(etatCommerceProvider);
    final boutiques = ref.watch(boutiquesVisiblesProvider).toSet();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.comPurchasesTitle),
        actions: const [Padding(padding: EdgeInsets.only(right: 4), child: BoutiqueSelecteur()), SyncStatusButton()],
      ),
      floatingActionButton: !droits.creerAchats
          ? null
          : FloatingActionButton.extended(
              key: const Key('achat-ajouter'),
              onPressed: () => context.push(Routes.achatNouveau()),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.comNewPurchase),
            ),
      body: ResponsiveBody(
        child: AsyncValueView(
          value: etatAsync,
          onRetry: () => ref.invalidate(etatCommerceProvider),
          data: (etat) {
            final achats = [
              for (final a in etat.achats)
                if (boutiques.contains(a.perimetreId) &&
                    switch (_filtre) {
                      _FiltreAchats.tous => true,
                      _FiltreAchats.aRecevoir => a.aRecevoir,
                      _FiltreAchats.recus => a.statut == StatutAchat.recu,
                      _FiltreAchats.annules => a.annule,
                    })
                  a,
            ];
            if (etat.achats.isEmpty) {
              return EtatVide(
                icone: Icons.receipt_long_outlined,
                titre: l10n.comPurchaseEmptyTitle,
                message: l10n.comPurchaseEmptyMessage,
                action: droits.creerAchats ? l10n.comNewPurchase : null,
                onAction: () => context.push(Routes.achatNouveau()),
              );
            }
            return Column(
              children: [
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                    children: [
                      for (final (f, t) in [
                        (_FiltreAchats.tous, l10n.comFamilyAll),
                        (_FiltreAchats.aRecevoir, l10n.comFilterToReceive),
                        (_FiltreAchats.recus, l10n.comFilterReceived),
                        (_FiltreAchats.annules, l10n.comFilterCancelled),
                      ])
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                          child: ChoiceChip(
                            label: Text(t),
                            selected: _filtre == f,
                            onSelected: (_) => setState(() => _filtre = f),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 96),
                    itemCount: achats.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) => AchatCarte(achat: achats[i]),
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

(String, Color, Color) visuelStatutAchat(AppLocalizations l10n, StatutAchat s) => switch (s) {
      StatutAchat.commande => (l10n.comStatusOrdered, const Color(0xFF2563EB), const Color(0xFFDBEAFE)),
      StatutAchat.recuPartiel => (l10n.comStatusPartlyReceived, AppColors.warning, AppColors.warningSoft),
      StatutAchat.recu => (l10n.comStatusReceived, AppColors.positive, AppColors.positiveSoft),
      StatutAchat.annule => (l10n.comStatusCancelled, AppColors.muted, AppColors.border),
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
      child: Text(texte, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
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
    return Card(
      child: InkWell(
        key: Key('achat-${a.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(Routes.achat(a.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(nomContact(ref, a.fournisseurId) ?? l10n.comNoSupplier,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                  StatutAchatPuce(statut: a.statut),
                  RecordSyncBadge(status: a.syncStatus),
                ],
              ),
              Text(
                [l10n.date(a.dateAchat), ?a.reference, nomBoutique(ref, a.perimetreId)].join(' · '),
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  for (final p in produits.take(4))
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ProduitImage(produit: p, taille: 36, rayon: 8),
                    ),
                  if (produits.length > 4)
                    Text('+${produits.length - 4}', style: const TextStyle(color: AppColors.muted)),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(montant(context, ref, a.total), style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (dette != null && dette.reste > 0 && !a.annule)
                        Text('${l10n.comDebt} : ${montant(context, ref, dette.reste)}',
                            style: const TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w700)),
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
