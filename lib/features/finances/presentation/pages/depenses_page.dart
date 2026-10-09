import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../agenda/domain/entities/agenda.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../fichiers/presentation/section_notes_pieces.dart';
import '../../domain/entities/finances.dart';
import '../../domain/services/etat_finances.dart';
import '../providers/finances_providers.dart';
import '../widgets/finances_widgets.dart';

/// Granularité du filtre de période des dépenses.
enum _Periode { jour, mois, annee, dates, tout }

/// Onglet Dépenses : filtre par période (jour, mois, année, dates libres) et
/// par catégorie, total de la période, liste groupée.
class OngletDepenses extends ConsumerStatefulWidget {
  const OngletDepenses({super.key});

  @override
  ConsumerState<OngletDepenses> createState() => _OngletDepensesState();
}

class _OngletDepensesState extends ConsumerState<OngletDepenses> {
  String? _categorieId;
  _Periode _periode = _Periode.mois;

  /// Jour, mois ou année affiché (navigable avec ‹ ›).
  DateTime _reference = _aujourdhui();
  DateTimeRange? _plage;

  static DateTime _aujourdhui() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Début inclus, fin exclue (`null` : sans limite).
  (DateTime?, DateTime?) get _bornes {
    final r = _reference;
    return switch (_periode) {
      _Periode.jour => (r, DateTime(r.year, r.month, r.day + 1)),
      _Periode.mois => (DateTime(r.year, r.month), DateTime(r.year, r.month + 1)),
      _Periode.annee => (DateTime(r.year), DateTime(r.year + 1)),
      _Periode.dates => _plage == null
          ? (null, null)
          : (_plage!.start, DateTime(_plage!.end.year, _plage!.end.month, _plage!.end.day + 1)),
      _Periode.tout => (null, null),
    };
  }

  bool _dans(DateTime d) {
    final (debut, fin) = _bornes;
    return (debut == null || !d.isBefore(debut)) && (fin == null || d.isBefore(fin));
  }

  void _decaler(int pas) => setState(() {
        final r = _reference;
        _reference = switch (_periode) {
          _Periode.jour => DateTime(r.year, r.month, r.day + pas),
          _Periode.mois => DateTime(r.year, r.month + pas),
          _Periode.annee => DateTime(r.year + pas),
          _ => r,
        };
      });

  /// Le suivant n'existe pas encore : pas de période future.
  bool get _suivantPossible {
    final (_, fin) = _bornes;
    return fin != null && !fin.isAfter(_aujourdhui());
  }

  Future<void> _choisirDates() async {
    final plage = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: _aujourdhui(),
      initialDateRange: _plage,
    );
    if (plage != null) setState(() => _plage = plage);
  }

  String _libellePeriode() {
    final l10n = context.l10n;
    return switch (_periode) {
      _Periode.jour => l10n.date(_reference),
      _Periode.mois => l10n.mois(_reference),
      _Periode.annee => '${_reference.year}',
      _Periode.dates =>
        _plage == null ? l10n.periodChooseDates : '${l10n.date(_plage!.start)} – ${l10n.date(_plage!.end)}',
      _Periode.tout => l10n.periodAll,
    };
  }

  Widget _filtrePeriode() {
    final l10n = context.l10n;
    final navigable = _periode == _Periode.jour || _periode == _Periode.mois || _periode == _Periode.annee;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_Periode>(
          key: const Key('depenses-periode'),
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            ButtonSegment(value: _Periode.jour, label: Text(l10n.periodDay)),
            ButtonSegment(value: _Periode.mois, label: Text(l10n.periodMonth)),
            ButtonSegment(value: _Periode.annee, label: Text(l10n.periodYear)),
            ButtonSegment(value: _Periode.dates, label: Text(l10n.periodDates)),
            ButtonSegment(value: _Periode.tout, label: Text(l10n.periodAll)),
          ],
          selected: {_periode},
          onSelectionChanged: (s) {
            setState(() {
              _periode = s.first;
              _reference = _aujourdhui();
            });
            if (s.first == _Periode.dates && _plage == null) _choisirDates();
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            if (navigable)
              IconButton(
                key: const Key('depenses-precedent'),
                tooltip: l10n.periodPrevious,
                onPressed: () => _decaler(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _periode == _Periode.dates ? _choisirDates : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_periode == _Periode.dates) ...[
                        const Icon(Icons.date_range_rounded, size: 18, color: AppColors.green),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          _libellePeriode(),
                          key: const Key('depenses-periode-libelle'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (navigable)
              IconButton(
                key: const Key('depenses-suivant'),
                tooltip: l10n.periodNext,
                onPressed: _suivantPossible ? () => _decaler(1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final droits = ref.watch(droitsFinancesProvider);
    final etat = ref.watch(etatFinancesProvider);

    return Scaffold(
      floatingActionButton: !droits.saisirDepenses
          ? null
          : FloatingActionButton.extended(
              key: const Key('depense-add'),
              heroTag: 'depense-add',
              onPressed: () => context.push(Routes.depenseNouvelle),
              icon: const Icon(Icons.add),
              label: Text(l10n.expenseNew),
            ),
      body: ResponsiveBody(
        child: AsyncValueView(
          value: etat,
          onRetry: () => ref.invalidate(etatFinancesProvider),
          data: (e) {
            final dePeriode = e.depenses.where((d) => _dans(d.dateDepense)).toList();
            final depenses = dePeriode.where((d) => _categorieId == null || d.categorieId == _categorieId).toList();
            final utilisees = {for (final d in dePeriode) d.categorieId};
            // Le total ne compte ni les annulées ni les refusées.
            final comptees = depenses.where(e.depenseComptee).toList();
            final total = comptees.fold(0, (t, d) => t + d.montant);
            // Par jour sur une courte période, par mois au-delà.
            final parJour = _periode == _Periode.jour || _periode == _Periode.mois || _periode == _Periode.dates;
            return ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
              children: [
                _filtrePeriode(),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(color: AppColors.negativeSoft, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.expenseTotalPeriod,
                                style: const TextStyle(color: AppColors.negative, fontWeight: FontWeight.w700)),
                            Text(l10n.expensesCount(comptees.length),
                                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                      Montant(
                        total,
                        key: const Key('depenses-total'),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900, color: AppColors.negative),
                      ),
                    ],
                  ),
                ),
                if (droits.modifierDepenses)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      key: const Key('categories-gerer'),
                      onPressed: () => context.push(Routes.categoriesDepenses),
                      icon: const Icon(Icons.tune, size: 18),
                      label: Text(l10n.expenseCategories),
                    ),
                  ),
                if (utilisees.length > 1)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                          child: ChoiceChip(
                            label: Text(l10n.contactsFilterAll),
                            selected: _categorieId == null,
                            onSelected: (_) => setState(() => _categorieId = null),
                          ),
                        ),
                        for (final c in e.categories.where((c) => utilisees.contains(c.id)))
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                            child: ChoiceChip(
                              avatar: Icon(iconeCategorie(c), size: 18),
                              label: Text(l10n.categorieDepense(c)),
                              selected: _categorieId == c.id,
                              onSelected: (_) => setState(() => _categorieId = c.id),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                if (depenses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xl),
                    child: EmptyView(icon: Icons.receipt_long_outlined, message: l10n.expensesEmpty),
                  ),
                for (final (i, d) in depenses.indexed) ...[
                  if (i == 0 ||
                      depenses[i - 1].dateDepense.month != d.dateDepense.month ||
                      depenses[i - 1].dateDepense.year != d.dateDepense.year ||
                      (parJour && depenses[i - 1].dateDepense.day != d.dateDepense.day))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, AppSpacing.md, 4, AppSpacing.sm),
                      child: Text(
                        parJour ? l10n.date(d.dateDepense) : l10n.mois(d.dateDepense),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.muted),
                      ),
                    ),
                  _DepenseTile(etat: e, depense: d),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DepenseTile extends StatelessWidget {
  const _DepenseTile({required this.etat, required this.depense});
  final EtatFinances etat;
  final Depense depense;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = depense;
    final c = etat.categorie(d.categorieId);
    final suivi = etat.engagements.where((e) => e.id == d.id).map(etat.suivi).firstOrNull;
    final aPayer = !d.annulee && !d.refusee && (suivi?.reste ?? (d.payeeImmediatement ? 0 : d.montant)) > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.negativeSoft,
            foregroundColor: AppColors.negative,
            child: Icon(iconeCategorie(c), size: 20),
          ),
          title: Text(d.libelle, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [
              l10n.categorieDepense(c),
              l10n.date(d.dateDepense),
              if (d.annulee) l10n.expenseCancelled,
              if (d.refusee) l10n.financeRejectedShort,
              if (aPayer) l10n.expenseToPay,
            ].join(' · '),
          ),
          trailing: Montant(d.montant, signe: false, barre: d.annulee || d.refusee),
          onTap: () => context.push(Routes.depense(d.id)),
        ),
      ),
    );
  }
}

/// Fiche d'une dépense : paiement, somme à payer, annulation.
class DepensePage extends ConsumerWidget {
  const DepensePage({super.key, required this.depenseId});
  final String depenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.expenseDetailTitle), actions: const [SyncStatusButton()]),
      body: ResponsiveBody(
        child: AsyncValueView(
          value: ref.watch(etatFinancesProvider),
          onRetry: () => ref.invalidate(etatFinancesProvider),
          isEmpty: (e) => !e.depenses.any((d) => d.id == depenseId),
          emptyMessage: l10n.financeNotFound,
          data: (e) => _FicheDepense(etat: e, depense: e.depenses.firstWhere((d) => d.id == depenseId)),
        ),
      ),
    );
  }
}

class _FicheDepense extends ConsumerWidget {
  const _FicheDepense({required this.etat, required this.depense});
  final EtatFinances etat;
  final Depense depense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final droits = ref.watch(droitsFinancesProvider);
    final contacts = ref.watch(contactsParIdProvider).value ?? const {};
    final d = depense;
    final suivi = etat.engagements.where((e) => e.id == d.id).map(etat.suivi).firstOrNull;
    final paiements = etat.paiementsSuivis.where((p) => p.paiement.affectations.any((a) => a.engagementId == d.id));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        EcritureRefuseeBanniere(
          status: d.syncStatus,
          onRetirer: d.version == null
              ? () async {
                  await ref.read(retirerEcritureProvider).call('depenses', d.id);
                  if (context.mounted) context.pop();
                }
              : null,
        ),
        Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.negativeSoft,
              foregroundColor: AppColors.negative,
              child: Icon(iconeCategorie(etat.categorie(d.categorieId))),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.libelle, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  Text(
                    l10n.categorieDepense(etat.categorie(d.categorieId)),
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Montant(
            d.montant,
            signe: false,
            barre: d.annulee || d.refusee,
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (d.annulee)
          Center(
            child: Text(
              l10n.expenseCancelled,
              style: const TextStyle(color: AppColors.negative, fontWeight: FontWeight.w700),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.event_outlined, color: AppColors.green),
                title: Text(l10n.expenseDate),
                subtitle: Text(l10n.date(d.dateDepense)),
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.green),
                title: Text(l10n.expenseSettlement),
                subtitle: Text(
                  d.payeeImmediatement
                      ? l10n.expensePaidWith(l10n.modePaiement(d.mode ?? ModePaiement.autre))
                      : (suivi == null || suivi.reste > 0
                            ? l10n.expenseToPayRemaining(
                                l10n.montant(suivi?.reste ?? d.montant, ref.watch(deviseProvider)),
                              )
                            : l10n.debtStatePaid),
                ),
                trailing: suivi == null ? null : const Icon(Icons.chevron_right),
                onTap: suivi == null ? null : () => context.push(Routes.engagement(d.id)),
              ),
              if (d.contactId != null)
                ListTile(
                  leading: const Icon(Icons.person_outline, color: AppColors.green),
                  title: Text(l10n.expenseSupplier),
                  subtitle: Text(contacts[d.contactId]?.nomAffiche ?? '…'),
                ),
              if (d.reference != null)
                ListTile(
                  leading: const Icon(Icons.tag, color: AppColors.green),
                  title: Text(l10n.paymentReference),
                  subtitle: Text(d.reference!),
                ),
              if (d.note != null)
                ListTile(
                  leading: const Icon(Icons.notes_outlined, color: AppColors.green),
                  title: Text(l10n.paymentNote),
                  subtitle: Text(d.note!),
                ),
              if (d.annulee && d.motifAnnulation != null)
                ListTile(
                  leading: const Icon(Icons.block, color: AppColors.negative),
                  title: Text(l10n.debtCancelReason),
                  subtitle: Text(d.motifAnnulation!),
                ),
            ],
          ),
        ),
        if (paiements.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.debtPayments, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                for (final p in paiements)
                  ListTile(
                    title: Text(l10n.modePaiement(p.paiement.mode)),
                    subtitle: Text(l10n.dateTime(p.paiement.datePaiement)),
                    trailing: Montant(p.paiement.montant, signe: false, barre: p.annule || p.paiement.refuse),
                    onTap: () => context.push(Routes.paiement(p.paiement.id)),
                  ),
              ],
            ),
          ),
        ],
        if (!d.annulee && !d.refusee) ...[
          const SizedBox(height: AppSpacing.lg),
          if (!d.payeeImmediatement && (suivi?.reste ?? 0) > 0 && droits.decaisser)
            FilledButton.icon(
              key: const Key('depense-payer'),
              onPressed: () => context.push(Routes.paiementNouveau(engagementId: d.id)),
              icon: const Icon(Icons.north_east),
              label: Text(l10n.debtPay),
            ),
          if (droits.modifierDepenses) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const Key('depense-modifier'),
              onPressed: () => _modifier(context, ref),
              icon: const Icon(Icons.edit_outlined),
              label: Text(l10n.commonEdit),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const Key('depense-annuler'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.negative),
              onPressed: () => _annuler(context, ref),
              icon: const Icon(Icons.block),
              label: Text(l10n.expenseCancel),
            ),
          ],
        ],
        if (!d.refusee) ...[
          const SizedBox(height: AppSpacing.lg),
          // Justificatif (photo du reçu du fournisseur) et notes.
          SectionNotesPieces(type: CibleType.depense, cibleId: d.id),
        ],
      ],
    );
  }

  Future<void> _modifier(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    final libelle = TextEditingController(text: depense.libelle);
    var categorieId = depense.categorieId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setState) => AlertDialog(
          title: Text(l10n.expenseEdit),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: libelle,
                maxLength: 200,
                decoration: InputDecoration(labelText: l10n.expenseLabel),
              ),
              DropdownButtonFormField<String>(
                initialValue: categorieId,
                decoration: InputDecoration(labelText: l10n.expenseCategory),
                items: [
                  for (final c in etat.categories.where((c) => c.estActive || c.id == categorieId))
                    DropdownMenuItem(value: c.id, child: Text(l10n.categorieDepense(c))),
                ],
                onChanged: (v) => setState(() => categorieId = v ?? categorieId),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.expenseAmountLocked, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l10n.commonCancel)),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l10n.commonSave)),
          ],
        ),
      ),
    );
    final texte = libelle.text;
    libelle.dispose();
    if (ok != true) return;
    try {
      await ref
          .read(modifierDepenseProvider)
          .call(
            ctx,
            etat,
            depense,
            categorieId: categorieId,
            libelle: texte,
            date: depense.dateDepense,
            reference: depense.reference,
            note: depense.note,
          );
    } catch (e) {
      if (context.mounted) showFailureSnackBar(context, e);
    }
  }

  Future<void> _annuler(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    final motif = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.expenseCancelTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(depense.payeeImmediatement ? l10n.expenseCancelMessagePaid : l10n.expenseCancelMessage),
            TextField(
              controller: motif,
              maxLength: 500,
              decoration: InputDecoration(labelText: l10n.debtCancelReason),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l10n.commonCancel)),
          FilledButton(
            key: const Key('depense-annuler-confirmer'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            onPressed: () => Navigator.pop(d, true),
            child: Text(l10n.expenseCancel),
          ),
        ],
      ),
    );
    final texte = motif.text;
    motif.dispose();
    if (ok != true) return;
    try {
      await ref.read(modifierDepenseProvider).annuler(ctx, etat, depense, motif: texte);
    } catch (e) {
      if (context.mounted) showFailureSnackBar(context, e);
    }
  }
}

/// Catégories de dépenses : celles fournies (traduites) et celles de l'entreprise.
class CategoriesDepensesPage extends ConsumerWidget {
  const CategoriesDepensesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.expenseCategories)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('categorie-add'),
        onPressed: () => _creer(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.expenseCategoryNew),
      ),
      body: ResponsiveBody(
        child: AsyncValueView(
          value: ref.watch(etatFinancesProvider),
          onRetry: () => ref.invalidate(etatFinancesProvider),
          data: (e) => ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
            children: [
              Card(
                child: Column(
                  children: [
                    for (final c in e.categories)
                      SwitchListTile(
                        key: Key('categorie-${c.id}'),
                        secondary: Icon(iconeCategorie(c)),
                        title: Text(l10n.categorieDepense(c)),
                        subtitle: Text(c.estActive ? l10n.commonActive : l10n.commonInactive),
                        value: c.estActive,
                        onChanged: (v) async {
                          final ctx = ref.read(contexteActifProvider);
                          if (ctx == null) return;
                          try {
                            await ref.read(gererCategoriesProvider).modifier(ctx, c, estActive: v);
                          } catch (err) {
                            if (context.mounted) showFailureSnackBar(context, err);
                          }
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.expenseCategoriesHint, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _creer(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ctx = ref.read(contexteActifProvider);
    final etat = ref.read(etatFinancesProvider).value;
    if (ctx == null || etat == null) return;
    final nom = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.expenseCategoryNew),
        content: TextField(
          key: const Key('categorie-nom'),
          controller: nom,
          autofocus: true,
          maxLength: 60,
          decoration: InputDecoration(labelText: l10n.expenseCategoryName),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l10n.commonCreate)),
        ],
      ),
    );
    final texte = nom.text;
    nom.dispose();
    if (ok != true) return;
    try {
      await ref.read(gererCategoriesProvider).creer(ctx, etat, texte);
    } catch (e) {
      if (context.mounted) showFailureSnackBar(context, e);
    }
  }
}
