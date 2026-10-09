import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/sync/sync_models.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../finances/domain/entities/finances.dart' show ModePaiement;
import '../../../finances/presentation/providers/finances_providers.dart';
import '../../../finances/presentation/widgets/finances_widgets.dart' show FinancesLabels;
import '../../domain/entities/commerce.dart';
import '../../domain/services/etat_commerce.dart';
import '../commerce_providers.dart';
import '../recus/filtre_recus.dart';
import '../recus/recu_vente.dart';
import '../recus/recu_vente_widgets.dart';
import '../widgets/choix_contact.dart';
import '../widgets/commerce_widgets.dart';

/// Reçus de toutes les ventes accessibles, prêts pour la recherche.
List<IndexRecu> indexRecus(WidgetRef ref, EtatCommerce etat, List<String> boutiques) {
  final ensemble = boutiques.toSet();
  final contacts = {for (final c in ref.watch(tousContactsProvider).value ?? const <Contact>[]) c.id: c};
  return [
    for (final v in etat.ventes)
      if (ensemble.contains(v.perimetreId))
        IndexRecu(
          vente: v,
          statut: statutRecu(v, resteVente(ref, v)),
          client: contacts[v.contactId]?.nomAffiche,
          telephone: contacts[v.contactId]?.telephone,
          boutique: nomBoutique(ref, v.perimetreId),
          produits: [for (final l in v.lignes) etat.produit(l.produitId)?.nom ?? ''],
        ),
  ];
}

/// Reçus : résumé par boutique, recherche, filtres, liste (tableau sur grand écran).
class VentesPage extends ConsumerStatefulWidget {
  const VentesPage({super.key});

  @override
  ConsumerState<VentesPage> createState() => _VentesPageState();
}

class _VentesPageState extends ConsumerState<VentesPage> {
  FiltreRecus? _filtre;
  final _recherche = TextEditingController();

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final etatAsync = ref.watch(etatCommerceProvider);
    final boutiques = ref.watch(boutiquesVisiblesProvider);
    final toutes = ref.watch(boutiquesProvider);
    final droits = ref.watch(droitsCommerceProvider);
    final large = MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.rcpTitle),
            // Une seule boutique : elle est affichée, pas de sélecteur inutile.
            if (toutes.length == 1)
              Text(toutes.single.nom, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ],
        ),
        actions: const [Padding(padding: EdgeInsets.only(right: 4), child: BoutiqueSelecteur()), SyncStatusButton()],
      ),
      floatingActionButton: !droits.vendre
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go(Routes.ventes),
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: Text(l10n.comNewSale),
            ),
      body: AsyncValueView(
        value: etatAsync,
        onRetry: () => ref.invalidate(etatCommerceProvider),
        data: (etat) {
          final index = indexRecus(ref, etat, boutiques);
          if (index.isEmpty) {
            return EtatVide(
              icone: Icons.receipt_long_outlined,
              titre: l10n.rcpEmptyTitle,
              message: l10n.rcpEmptyMessage,
              action: droits.vendre ? l10n.rcpCreateSale : null,
              onAction: () => context.go(Routes.ventes),
            );
          }
          // Période par défaut : aujourd'hui s'il y a des ventes, sinon tout.
          final maintenant = DateTime.now();
          final filtre = _filtre ??= filtrerRecus(index, const FiltreRecus(), maintenant: maintenant).isEmpty
              ? const FiltreRecus(periode: PeriodeRecus.tout)
              : const FiltreRecus();
          final resultats = filtrerRecus(index, filtre, maintenant: maintenant);

          final contenu = <Widget>[
            _Resume(recus: resultats, boutiques: boutiques, periode: filtre.periode),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('recus-recherche'),
              controller: _recherche,
              decoration: InputDecoration(
                hintText: l10n.rcpSearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _recherche.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _recherche.clear();
                          _filtre = filtre.copyWith(texte: '');
                        }),
                      ),
              ),
              onChanged: (t) => setState(() => _filtre = filtre.copyWith(texte: t)),
            ),
            const SizedBox(height: AppSpacing.sm),
            _Filtres(
              filtre: filtre,
              vendeurs: {for (final r in index) ?r.vente.auteurNom}.toList()..sort(),
              modes: {for (final r in index) ?r.vente.modePaiement}.toList(),
              onChanged: (f) => setState(() => _filtre = f),
            ),
            const SizedBox(height: AppSpacing.sm),
          ];

          if (resultats.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                ...contenu,
                const SizedBox(height: AppSpacing.lg),
                EtatVide(
                  icone: Icons.search_off_rounded,
                  titre: l10n.rcpNoResultTitle,
                  message: l10n.rcpNoResultMessage,
                  action: filtre.actif || filtre.periode != PeriodeRecus.tout ? l10n.rcpReset : null,
                  onAction: () => setState(() {
                    _recherche.clear();
                    _filtre = const FiltreRecus(periode: PeriodeRecus.tout);
                  }),
                ),
              ],
            );
          }

          final plusieursBoutiques = toutes.length > 1;
          if (large) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96),
              children: [
                ...contenu,
                _TableRecus(recus: resultats, avecBoutique: plusieursBoutiques),
              ],
            );
          }
          // Mobile : regroupés par jour.
          final lignes = <Widget>[];
          String? jourCourant;
          final locale = Localizations.localeOf(context).toString();
          for (final r in resultats) {
            final jour = DateFormat.yMMMMEEEEd(locale).format(r.vente.date.toLocal());
            if (jour != jourCourant) {
              jourCourant = jour;
              lignes.add(Padding(
                padding: const EdgeInsets.fromLTRB(4, AppSpacing.md, 4, AppSpacing.xs),
                child: Text(jour, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted)),
              ));
            }
            lignes.add(_TuileRecu(recu: r, avecBoutique: plusieursBoutiques));
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppBreakpoints.contentMaxWidth),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
                children: [...contenu, ...lignes],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Résumé de la période : total et nombre de reçus, par boutique s'il y en a plusieurs.
class _Resume extends ConsumerWidget {
  const _Resume({required this.recus, required this.boutiques, required this.periode});
  final List<IndexRecu> recus;
  final List<String> boutiques;
  final PeriodeRecus periode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final valides = recus.where((r) => r.statut != StatutRecu.annule);
    final total = valides.fold(0, (t, r) => t + r.vente.total);
    final parBoutique = <String, (int, int)>{};
    for (final r in valides) {
      final (n, t) = parBoutique[r.vente.perimetreId] ?? (0, 0);
      parBoutique[r.vente.perimetreId] = (n + 1, t + r.vente.total);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(color: CouleursRecu.bleu, borderRadius: BorderRadius.circular(18)),
          child: Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(libellePeriode(l10n, periode), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(montant(context, ref, total),
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Icon(Icons.receipt_long_rounded, color: CouleursRecu.or),
                Text(l10n.rcpCount(valides.length),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ]),
            ],
          ),
        ),
        if (boutiques.length > 1 && parBoutique.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 88,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final b in boutiques)
                  if (parBoutique[b] case (final n, final t))
                    Container(
                      width: 168,
                      margin: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.storefront_outlined, size: 16, color: CouleursRecu.bleu),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(nomBoutique(ref, b),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ]),
                        const Spacer(),
                        Text(montant(context, ref, t), style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text(l10n.rcpCount(n), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      ]),
                    ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

String libellePeriode(AppLocalizations l10n, PeriodeRecus p) => switch (p) {
      PeriodeRecus.aujourdhui => l10n.rcpPeriodToday,
      PeriodeRecus.hier => l10n.rcpPeriodYesterday,
      PeriodeRecus.semaine => l10n.rcpPeriodWeek,
      PeriodeRecus.mois => l10n.rcpPeriodMonth,
      PeriodeRecus.personnalisee => l10n.rcpPeriodCustom,
      PeriodeRecus.tout => l10n.rcpPeriodAll,
    };

/// Filtres simples : période, vendeur, paiement, statut.
class _Filtres extends StatelessWidget {
  const _Filtres({required this.filtre, required this.vendeurs, required this.modes, required this.onChanged});
  final FiltreRecus filtre;
  final List<String> vendeurs;
  final List<String> modes;
  final ValueChanged<FiltreRecus> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();

    Widget menu<T>({
      required Key key,
      required IconData icone,
      required String libelle,
      required bool actif,
      required List<(T, String)> options,
      required ValueChanged<T> onSelected,
    }) =>
        Padding(
          padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
          child: PopupMenuButton<T>(
            key: key,
            onSelected: onSelected,
            itemBuilder: (_) => [for (final (v, t) in options) PopupMenuItem(value: v, child: Text(t))],
            child: Chip(
              avatar: Icon(icone, size: 18, color: actif ? AppColors.green : AppColors.muted),
              label: Text(libelle, style: TextStyle(fontWeight: actif ? FontWeight.w700 : FontWeight.w500)),
              side: BorderSide(color: actif ? AppColors.green : AppColors.border),
              backgroundColor: actif ? AppColors.greenSoft : AppColors.surface,
              deleteIcon: const Icon(Icons.expand_more_rounded, size: 18),
              onDeleted: () {},
            ),
          ),
        );

    final periode = filtre.periode == PeriodeRecus.personnalisee && filtre.debut != null
        ? '${DateFormat.MMMd(locale).format(filtre.debut!)} – ${DateFormat.MMMd(locale).format(filtre.fin ?? filtre.debut!)}'
        : libellePeriode(l10n, filtre.periode);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          menu<PeriodeRecus>(
            key: const Key('recus-periode'),
            icone: Icons.calendar_today_outlined,
            libelle: periode,
            actif: true,
            options: [for (final p in PeriodeRecus.values) (p, libellePeriode(l10n, p))],
            onSelected: (p) async {
              if (p != PeriodeRecus.personnalisee) return onChanged(filtre.copyWith(periode: p));
              final plage = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (plage != null) {
                onChanged(filtre.copyWith(periode: p, debut: () => plage.start, fin: () => plage.end));
              }
            },
          ),
          if (vendeurs.length > 1)
            menu<String?>(
              key: const Key('recus-vendeur'),
              icone: Icons.badge_outlined,
              libelle: filtre.vendeur ?? l10n.rcpAllSellers,
              actif: filtre.vendeur != null,
              options: [(null, l10n.rcpAllSellers), for (final v in vendeurs) (v, v)],
              onSelected: (v) => onChanged(filtre.copyWith(vendeur: () => v)),
            ),
          menu<String?>(
            key: const Key('recus-paiement'),
            icone: Icons.payments_outlined,
            libelle: switch (filtre.paiement) {
              null => l10n.rcpAllPayments,
              FiltreRecus.credit => l10n.rcpCredit,
              final code => l10n.modePaiement(ModePaiement.parse(code)),
            },
            actif: filtre.paiement != null,
            options: [
              (null, l10n.rcpAllPayments),
              for (final m in modes) (m, l10n.modePaiement(ModePaiement.parse(m))),
              (FiltreRecus.credit, l10n.rcpCredit),
            ],
            onSelected: (v) => onChanged(filtre.copyWith(paiement: () => v)),
          ),
          menu<StatutRecu?>(
            key: const Key('recus-statut'),
            icone: Icons.flag_outlined,
            libelle: filtre.statut == null ? l10n.rcpAllStatuses : libelleStatutRecu(l10n, filtre.statut!),
            actif: filtre.statut != null,
            options: [(null, l10n.rcpAllStatuses), for (final s in StatutRecu.values) (s, libelleStatutRecu(l10n, s))],
            onSelected: (v) => onChanged(filtre.copyWith(statut: () => v)),
          ),
        ],
      ),
    );
  }
}

/// Ligne de reçu (mobile) : numéro, client, total, heure, statut.
class _TuileRecu extends ConsumerWidget {
  const _TuileRecu({required this.recu, required this.avecBoutique});
  final IndexRecu recu;
  final bool avecBoutique;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final v = recu.vente;
    final heure = DateFormat.Hm(Localizations.localeOf(context).toString()).format(v.date.toLocal());
    final annule = recu.statut == StatutRecu.annule;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        key: Key('vente-${v.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(Routes.vente(v.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: annule ? AppColors.negativeSoft : CouleursRecu.bleu.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.receipt_long_rounded, color: annule ? AppColors.negative : CouleursRecu.bleu),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.numero ?? numeroRecu(v.dateCommerciale ?? jourCommercial(v.date), v.poste ?? '', v.sequence ?? 1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        decoration: annule ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    Text(
                      [
                        recu.client ?? l10n.rcpCounterCustomer,
                        if (avecBoutique) recu.boutique,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    if (recu.statut != StatutRecu.paye) ...[
                      const SizedBox(height: 4),
                      StatutRecuBadge(statut: recu.statut, compact: true),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(montant(context, ref, v.total), style: const TextStyle(fontWeight: FontWeight.w900)),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(heure, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                    RecordSyncBadge(status: v.syncStatus),
                  ]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tableau professionnel (tablette large, ordinateur).
class _TableRecus extends ConsumerWidget {
  const _TableRecus({required this.recus, required this.avecBoutique});
  final List<IndexRecu> recus;
  final bool avecBoutique;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    const entete = TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          headingRowColor: const WidgetStatePropertyAll(CouleursRecu.fond),
          columns: [
            DataColumn(label: Text(l10n.rcpTitle, style: entete)),
            DataColumn(label: Text(l10n.rcpDate, style: entete)),
            if (avecBoutique) DataColumn(label: Text(l10n.rcpShop, style: entete)),
            DataColumn(label: Text(l10n.comCustomer, style: entete)),
            DataColumn(label: Text(l10n.comSeller, style: entete)),
            DataColumn(label: Text(l10n.comTotal, style: entete), numeric: true),
            DataColumn(label: Text(l10n.comPayment, style: entete)),
            DataColumn(label: Text(l10n.rcpStatus, style: entete)),
          ],
          rows: [
            for (final r in recus)
              DataRow(
                key: ValueKey(r.vente.id),
                onSelectChanged: (_) => context.push(Routes.vente(r.vente.id)),
                cells: [
                  DataCell(Text(r.vente.numero ?? '—', style: const TextStyle(fontWeight: FontWeight.w800))),
                  DataCell(Text(DateFormat.yMd(locale).add_Hm().format(r.vente.date.toLocal()))),
                  if (avecBoutique) DataCell(Text(r.boutique)),
                  DataCell(Text(r.client ?? l10n.rcpCounterCustomer)),
                  DataCell(Text(r.vente.auteurNom ?? '—')),
                  DataCell(Text(montant(context, ref, r.vente.total), style: const TextStyle(fontWeight: FontWeight.w800))),
                  DataCell(Text(libellePaiementVente(l10n, r.vente))),
                  DataCell(StatutRecuBadge(statut: r.statut, compact: true)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Détail d'un reçu
// =============================================================================

/// Détail d'un reçu : statut, actions (PDF, partage, impression), reçu,
/// historique ; annulation selon les droits (jamais de suppression).
class VenteDetailPage extends ConsumerWidget {
  const VenteDetailPage({super.key, required this.venteId});
  final String venteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final etat = ref.watch(etatCommerceProvider).value;
    final v = etat?.vente(venteId);
    if (etat == null) return Scaffold(appBar: AppBar(), body: const LoadingView());
    if (v == null) return Scaffold(appBar: AppBar(), body: EmptyView(message: l10n.errorNotFound));
    final droits = ref.watch(droitsCommerceProvider);
    final finances = ref.watch(etatFinancesProvider).value;
    final creance = finances?.engagements.where((e) => e.id == v.id).map(finances.suivi).firstOrNull;
    final annulable = droits.annulerVentes && !v.annulee && (creance == null ? v.total == 0 : creance.regle == 0);
    final recu = donneesRecu(context, ref, v);
    final locale = Localizations.localeOf(context).toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(v.numero ?? l10n.rcpSaleReceipt),
        actions: [
          const SyncStatusButton(),
          if (annulable)
            PopupMenuButton<String>(
              key: const Key('vente-menu'),
              onSelected: (_) => _annuler(context, ref, v),
              itemBuilder: (_) => [PopupMenuItem(value: 'annuler', child: Text(l10n.comCancelSale))],
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Row(children: [
                StatutRecuBadge(statut: recu.statut),
                const Spacer(),
                RecordSyncBadge(status: v.syncStatus),
              ]),
              if (v.annulee)
                Card(
                  margin: const EdgeInsets.only(top: AppSpacing.sm),
                  color: AppColors.negativeSoft,
                  child: ListTile(
                    leading: const Icon(Icons.block, color: AppColors.negative),
                    title: Text(recu.annulation ?? l10n.comCancelled, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: v.motifAnnulation == null ? null : Text(v.motifAnnulation!),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              ActionsRecu(recu: recu),
              const SizedBox(height: AppSpacing.md),
              RecuVenteTicket(recu: recu),
              const SizedBox(height: AppSpacing.md),
              SectionCarte(
                titre: l10n.rcpTraceability,
                icone: Icons.history_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Evenement(
                      icone: Icons.point_of_sale_rounded,
                      texte: l10n.rcpCreatedBy(v.auteurNom ?? '—'),
                      date: DateFormat.yMd(locale).add_Hm().format(v.date.toLocal()),
                    ),
                    if (v.syncStatus == RecordSyncStatus.pendingSync)
                      _Evenement(icone: Icons.cloud_upload_outlined, texte: l10n.rcpOnDevice),
                    if (v.annulee)
                      _Evenement(icone: Icons.block, texte: recu.annulation ?? l10n.comCancelled, couleur: AppColors.negative),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _annuler(BuildContext context, WidgetRef ref, Vente v) async {
    final l10n = context.l10n;
    // Le dialogue garde son champ : rien n'est libéré pendant sa fermeture.
    final motif = await showDialog<String>(context: context, builder: (_) => const _DialogueAnnulation());
    if (motif == null || !context.mounted) return;
    final ctx = ref.read(contexteActifProvider);
    final etat = ref.read(etatCommerceProvider).value;
    if (ctx == null || etat == null) return;
    try {
      await ref
          .read(gererCommerceProvider)
          .annulerVente(ctx, etat, v, motif: motif, finances: ref.read(etatFinancesProvider).value);
      if (context.mounted) confirmer(context, l10n.comSaleCancelledDone);
    } catch (e) {
      if (context.mounted) signalerErreur(context, e);
    }
  }
}

class _Evenement extends StatelessWidget {
  const _Evenement({required this.icone, required this.texte, this.date, this.couleur});
  final IconData icone;
  final String texte;
  final String? date;
  final Color? couleur;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icone, size: 18, color: couleur ?? AppColors.muted),
          const SizedBox(width: 8),
          Expanded(child: Text(texte, style: TextStyle(color: couleur, fontWeight: FontWeight.w600))),
          if (date != null) Text(date!, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
        ]),
      );
}

/// Motif d'annulation ; renvoie le motif (éventuellement vide) ou `null`.
class _DialogueAnnulation extends StatefulWidget {
  const _DialogueAnnulation();

  @override
  State<_DialogueAnnulation> createState() => _DialogueAnnulationState();
}

class _DialogueAnnulationState extends State<_DialogueAnnulation> {
  final _motif = TextEditingController();

  @override
  void dispose() {
    _motif.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.comCancelSale),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.comCancelSaleConfirm),
          const SizedBox(height: AppSpacing.md),
          TextField(controller: _motif, decoration: InputDecoration(labelText: l10n.comCancelReason)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
          onPressed: () => Navigator.pop(context, _motif.text),
          child: Text(l10n.comCancelSale),
        ),
      ],
    );
  }
}
