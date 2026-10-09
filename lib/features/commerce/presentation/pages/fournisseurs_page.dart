import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../contacts/presentation/widgets/contact_avatar.dart';
import '../../../finances/domain/entities/finances.dart';
import '../../../finances/domain/services/etat_finances.dart';
import '../../../finances/presentation/providers/finances_providers.dart';
import '../../domain/services/etat_commerce.dart';
import '../commerce_providers.dart';
import '../widgets/choix_contact.dart';
import '../widgets/commerce_widgets.dart';
import 'achats_page.dart' show AchatCarte;

/// Dette envers un fournisseur : sommes à payer non soldées.
int detteFournisseur(EtatFinances? finances, String contactId) => finances == null
    ? 0
    : finances.suivis
        .where((s) => s.engagement.sens == SensEngagement.aPayer && s.engagement.contactId == contactId && !s.engagement.annule)
        .fold(0, (t, s) => t + s.reste);

class FournisseursPage extends ConsumerStatefulWidget {
  const FournisseursPage({super.key});

  @override
  ConsumerState<FournisseursPage> createState() => _FournisseursPageState();
}

class _FournisseursPageState extends ConsumerState<FournisseursPage> {
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final droits = ref.watch(droitsCommerceProvider);
    final contacts = ref.watch(contactsRelationProvider(RelationContact.fournisseur));
    final etat = ref.watch(etatCommerceProvider).value;
    final finances = ref.watch(etatFinancesProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.comSuppliersTitle), actions: const [SyncStatusButton()]),
      floatingActionButton: !droits.creerContacts
          ? null
          : FloatingActionButton.extended(
              key: const Key('fournisseur-ajouter'),
              onPressed: () => context.push(Routes.contactNouveau(relation: RelationContact.fournisseur.code)),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text(l10n.comAddSupplier),
            ),
      body: ResponsiveBody(
        child: AsyncValueView(
          value: contacts,
          onRetry: () => ref.invalidate(contactsRelationProvider(RelationContact.fournisseur)),
          data: (liste) {
            if (liste.isEmpty) {
              return EtatVide(
                icone: Icons.local_shipping_outlined,
                titre: l10n.comSuppliersEmptyTitle,
                message: l10n.comSuppliersEmptyMessage,
                action: droits.creerContacts ? l10n.comAddSupplier : null,
                onAction: () => context.push(Routes.contactNouveau(relation: RelationContact.fournisseur.code)),
              );
            }
            final mots = _recherche.toLowerCase().split(' ').where((m) => m.isNotEmpty);
            final filtres = [
              for (final c in liste)
                if (mots.every((m) => '${c.nomAffiche} ${c.telephone ?? ''} ${c.ville ?? ''}'.toLowerCase().contains(m)))
                  c,
            ];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                  child: TextField(
                    decoration: InputDecoration(hintText: l10n.comSearchContact, prefixIcon: const Icon(Icons.search)),
                    onChanged: (t) => setState(() => _recherche = t),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
                    itemCount: filtres.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) {
                      final c = filtres[i];
                      final resume = etat?.resumeFournisseur(c.id);
                      final dette = detteFournisseur(finances, c.id);
                      return Card(
                        child: ListTile(
                          key: Key('fournisseur-${c.id}'),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          leading: ContactAvatar(contact: c, radius: 24),
                          title: Text(c.nomAffiche, style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text([
                            l10n.comPurchasesCount(resume?.nombreAchats ?? 0),
                            if (resume?.dernierAchat case final d?) l10n.date(d),
                          ].join(' · ')),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(montant(context, ref, resume?.totalAchete ?? 0),
                                  style: const TextStyle(fontWeight: FontWeight.w800)),
                              if (dette > 0)
                                Text('${l10n.comDebt} : ${montant(context, ref, dette)}',
                                    style: const TextStyle(
                                        color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          onTap: () => context.push(Routes.fournisseur(c.id)),
                        ),
                      );
                    },
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

class FournisseurPage extends ConsumerWidget {
  const FournisseurPage({super.key, required this.contactId});
  final String contactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final contact = ref.watch(contactProvider(contactId));
    final etat = ref.watch(etatCommerceProvider).value;
    final finances = ref.watch(etatFinancesProvider).value;
    final droits = ref.watch(droitsCommerceProvider);

    return switch (contact) {
      AsyncData(value: final c?) => Scaffold(
          appBar: AppBar(title: Text(c.nomAffiche), actions: const [SyncStatusButton()]),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppBreakpoints.contentMaxWidth),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Row(
                    children: [
                      ContactAvatar(contact: c, radius: 32),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.nomAffiche, style: Theme.of(context).textTheme.titleLarge),
                            if (c.telephone != null) Text(c.telephone!, style: const TextStyle(color: AppColors.muted)),
                            if (c.adresse != null || c.ville != null)
                              Text([?c.adresse, ?c.ville].join(', '), style: const TextStyle(color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      if (droits.creerAchats)
                        FilledButton.icon(
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                          onPressed: () => context.push(Routes.achatNouveau(fournisseurId: c.id)),
                          icon: const Icon(Icons.add_shopping_cart_rounded),
                          label: Text(l10n.comNewPurchase),
                        ),
                      if (c.telephone != null)
                        OutlinedButton.icon(
                          onPressed: () => launchUrl(Uri(scheme: 'tel', path: c.telephone)),
                          icon: const Icon(Icons.call_outlined),
                          label: Text(l10n.comCall),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => context.push(Routes.contact(c.id)),
                        icon: const Icon(Icons.badge_outlined),
                        label: Text(l10n.comOpenContact),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (etat != null) ..._contenu(context, ref, c, etat, finances),
                ],
              ),
            ),
          ),
        ),
      AsyncData() => Scaffold(appBar: AppBar(), body: EmptyView(message: l10n.errorNotFound)),
      AsyncError(:final error) => Scaffold(appBar: AppBar(), body: ErrorView(error: error)),
      _ => Scaffold(appBar: AppBar(), body: const LoadingView()),
    };
  }

  List<Widget> _contenu(BuildContext context, WidgetRef ref, Contact c, EtatCommerce etat, EtatFinances? finances) {
    final l10n = context.l10n;
    final resume = etat.resumeFournisseur(c.id);
    final dette = detteFournisseur(finances, c.id);
    final produits = etat.produitsDuFournisseur(c.id);
    final achats = etat.achatsDuFournisseur(c.id);
    Widget chiffre(String libelle, String valeur, {Color? couleur}) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(libelle, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(valeur,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: couleur ?? AppColors.ink)),
                ],
              ),
            ),
          ),
        );
    return [
      Row(
        children: [
          chiffre(l10n.comTotalBought, montant(context, ref, resume.totalAchete)),
          chiffre(l10n.comDebt, montant(context, ref, dette), couleur: dette > 0 ? AppColors.warning : AppColors.positive),
        ],
      ),
      Row(
        children: [
          chiffre(l10n.comPaid, montant(context, ref, resume.totalAchete - dette < 0 ? 0 : resume.totalAchete - dette)),
          chiffre(l10n.comLastPurchase, resume.dernierAchat == null ? '—' : l10n.date(resume.dernierAchat!)),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      SectionCarte(
        titre: l10n.comSuppliedProducts,
        icone: Icons.inventory_2_outlined,
        child: produits.isEmpty
            ? Text(l10n.comNeverBought, style: const TextStyle(color: AppColors.muted))
            : Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final p in produits)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.push(Routes.produit(p.id)),
                      child: SizedBox(
                        width: 84,
                        child: Column(
                          children: [
                            ProduitImage(produit: p, taille: 72),
                            const SizedBox(height: 4),
                            Text(p.nom,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
      const SizedBox(height: AppSpacing.md),
      Text(l10n.comPurchaseHistory, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.sm),
      if (achats.isEmpty)
        Text(l10n.comNeverBought, style: const TextStyle(color: AppColors.muted))
      else
        for (final a in achats)
          Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: AchatCarte(achat: a)),
    ];
  }
}
