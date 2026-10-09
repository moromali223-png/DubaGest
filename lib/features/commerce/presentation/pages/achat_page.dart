import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../finances/presentation/providers/finances_providers.dart';
import '../../domain/entities/commerce.dart';
import '../../domain/services/etat_commerce.dart';
import '../commerce_providers.dart';
import '../widgets/choix_contact.dart';
import '../widgets/commerce_widgets.dart';
import 'achats_page.dart' show StatutAchatPuce;

/// Détail d'un achat : produits commandés / reçus, réceptions, dette fournisseur.
class AchatPage extends ConsumerWidget {
  const AchatPage({super.key, required this.achatId});
  final String achatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final etatAsync = ref.watch(etatCommerceProvider);
    final etat = etatAsync.value;
    final achat = etat?.achat(achatId);
    if (etat == null) return Scaffold(appBar: AppBar(), body: const LoadingView());
    if (achat == null) return Scaffold(appBar: AppBar(), body: EmptyView(message: l10n.errorNotFound));

    final droits = ref.watch(droitsCommerceProvider);
    final droitsFinances = ref.watch(droitsFinancesProvider);
    final finances = ref.watch(etatFinancesProvider).value;
    final dette = finances?.engagements.where((e) => e.id == achat.id).map(finances.suivi).firstOrNull;
    final receptions = etat.receptionsDe(achat.id);
    final peutRecevoir = achat.aRecevoir && droits.boutiquesReception.contains(achat.perimetreId);
    final modifiable = achat.statut == StatutAchat.commande && droits.boutiquesReception.contains(achat.perimetreId);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.comPurchaseOf(l10n.date(achat.dateAchat))),
        actions: [
          const SyncStatusButton(),
          if (modifiable)
            IconButton(
              tooltip: l10n.commonEdit,
              onPressed: () => context.push(Routes.achatModifier(achat.id)),
              icon: const Icon(Icons.edit_outlined),
            ),
          if (modifiable)
            PopupMenuButton<String>(
              onSelected: (_) => _annuler(context, ref, achat),
              itemBuilder: (_) => [PopupMenuItem(value: 'annuler', child: Text(l10n.comCancelPurchase))],
            ),
        ],
      ),
      bottomNavigationBar: !peutRecevoir
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: FilledButton.icon(
                  key: const Key('achat-receptionner'),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    showDragHandle: true,
                    builder: (_) => _Reception(achat: achat, etat: etat),
                  ),
                  icon: const Icon(Icons.move_to_inbox_outlined),
                  label: Text(l10n.comReceive),
                ),
              ),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppBreakpoints.contentMaxWidth),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.local_shipping_outlined, color: AppColors.green),
                  title: Text(nomContact(ref, achat.fournisseurId) ?? l10n.comNoSupplier,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text([nomBoutique(ref, achat.perimetreId), ?achat.reference, ?achat.auteurNom].join(' · ')),
                  trailing: StatutAchatPuce(statut: achat.statut),
                  onTap: achat.fournisseurId == null || !droits.voirFournisseurs
                      ? null
                      : () => context.push(Routes.fournisseur(achat.fournisseurId!)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCarte(
                titre: l10n.comProducts,
                icone: Icons.inventory_2_outlined,
                child: Column(
                  children: [
                    for (final l in achat.lignes)
                      if (etat.produit(l.produitId) case final p?)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              ProduitImage(produit: p, taille: 48),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    Text(
                                      '${qteUnite(context, l.quantite, l.unite)} × ${montant(context, ref, l.prixUnitaire)}',
                                      style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                                    ),
                                    if (!achat.annule && l.recu.estPositif)
                                      Text(
                                        '${l10n.comAlreadyReceived} : ${qteUnite(context, l.recu, l.unite)}'
                                        '${l.complete ? ' ✓' : ' · ${l10n.comRemaining} : ${qteUnite(context, l.reste, l.unite)}'}',
                                        style: TextStyle(
                                          color: l.complete ? AppColors.positive : AppColors.warning,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(montant(context, ref, l.montant), style: const TextStyle(fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                    const Divider(),
                    Row(
                      children: [
                        Text(l10n.comTotal, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Text(montant(context, ref, achat.total),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                      ],
                    ),
                  ],
                ),
              ),
              if (dette != null && !achat.annule) ...[
                const SizedBox(height: AppSpacing.md),
                SectionCarte(
                  titre: dette.reste > 0 ? l10n.comDebt : l10n.comFullyPaid,
                  icone: Icons.account_balance_wallet_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text('${l10n.comPaid} : ${montant(context, ref, dette.regle)}',
                              style: const TextStyle(color: AppColors.muted)),
                          const Spacer(),
                          Text(montant(context, ref, dette.reste),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: dette.reste > 0 ? AppColors.warning : AppColors.positive,
                              )),
                        ],
                      ),
                      if (dette.reste > 0 && droitsFinances.decaisser) ...[
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton.icon(
                          onPressed: () => context.push(Routes.paiementNouveau(engagementId: achat.id)),
                          icon: const Icon(Icons.payments_outlined),
                          label: Text(l10n.comPaySupplier),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (receptions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                SectionCarte(
                  titre: l10n.comReceptions,
                  icone: Icons.move_to_inbox_outlined,
                  child: Column(
                    children: [
                      for (final r in receptions)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.check_circle_outline, color: AppColors.positive),
                          title: Text(l10n.dateTime(r.date)),
                          subtitle: Text([
                            for (final lr in r.lignes)
                              if (achat.lignes.where((l) => l.id == lr.ligneId).firstOrNull case final l?)
                                '${etat.produit(l.produitId)?.nom ?? ''} : ${qteUnite(context, lr.quantite, l.unite)}',
                          ].join('\n')),
                          trailing: RecordSyncBadge(status: r.syncStatus),
                        ),
                    ],
                  ),
                ),
              ],
              if (achat.note != null) ...[
                const SizedBox(height: AppSpacing.md),
                SectionCarte(child: Text(achat.note!)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _annuler(BuildContext context, WidgetRef ref, Achat achat) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.comCancelPurchase),
        content: Text(l10n.comCancelPurchaseConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.comCancelPurchase),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    try {
      await ref
          .read(gererCommerceProvider)
          .annulerAchat(ctx, achat, finances: ref.read(etatFinancesProvider).value);
      if (context.mounted) confirmer(context, l10n.comPurchaseSaved);
    } catch (e) {
      if (context.mounted) signalerErreur(context, e);
    }
  }
}

/// Réception : quantité reçue aujourd'hui par ligne (pré-remplie avec le reste).
class _Reception extends ConsumerStatefulWidget {
  const _Reception({required this.achat, required this.etat});
  final Achat achat;
  final EtatCommerce etat;

  @override
  ConsumerState<_Reception> createState() => _ReceptionState();
}

class _ReceptionState extends ConsumerState<_Reception> {
  late final Map<String, Qte> _quantites = {
    for (final l in widget.achat.lignes) l.id: l.reste,
  };
  bool _enCours = false;

  Future<void> _valider() async {
    final l10n = context.l10n;
    final ctx = ref.read(contexteActifProvider);
    final etat = ref.read(etatCommerceProvider).value;
    if (ctx == null || etat == null) return;
    setState(() => _enCours = true);
    try {
      await ref.read(gererCommerceProvider).receptionner(ctx, etat, widget.achat, _quantites);
      if (!mounted) return;
      Navigator.pop(context);
      confirmer(context, l10n.comReceptionDone);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enCours = false);
      signalerErreur(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final a = widget.achat;
    final etat = widget.etat;
    final aRecevoir = [for (final l in a.lignes) if (!l.complete) l];
    final rien = _quantites.values.every((q) => !q.estPositif);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
        children: [
          Text(l10n.comReceiveTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          for (final l in aRecevoir)
            if (etat.produit(l.produitId) case final p?)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          ProduitImage(produit: p, taille: 44),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.nom, style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text(
                                  '${l10n.comOrdered} : ${qteUnite(context, l.quantite, l.unite)}'
                                  '${l.recu.estPositif ? ' · ${l10n.comAlreadyReceived} : ${qteUnite(context, l.recu, l.unite)}' : ''}',
                                  style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: Key('reception-${l.id}'),
                              initialValue: _texte(_quantites[l.id]!),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                              decoration: InputDecoration(
                                labelText: l10n.comReceivedToday,
                                suffixText: l.unite,
                                errorText: (_quantites[l.id] ?? Qte.zero) > l.reste
                                    ? '${l10n.comRemaining} : ${qteUnite(context, l.reste, l.unite)}'
                                    : null,
                              ),
                              onChanged: (t) => setState(() => _quantites[l.id] = Qte.lire(t) ?? Qte.zero),
                            ),
                          ),
                        ],
                      ),
                      if ((_quantites[l.id] ?? Qte.zero).estPositif) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '${l10n.comStockImpact} : ${quantiteLisible(context, p, etat.quantiteBoutique(p.id, a.perimetreId))}'
                          ' → ${quantiteLisible(context, p, etat.quantiteBoutique(p.id, a.perimetreId) + _quantites[l.id]!.fois(l.facteur))}',
                          style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('reception-valider'),
            onPressed: rien || _enCours ? null : _valider,
            child: _enCours
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : Text(l10n.comConfirmReception),
          ),
        ],
      ),
    );
  }

  static String _texte(Qte q) => q.estEntier ? '${q.brut ~/ Qte.echelle}' : q.valeur.toString();
}
