import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../perimetres/presentation/providers/perimetres_providers.dart';
import '../../domain/entities/caisse_tresorerie_models.dart';
import '../../domain/entities/finances.dart';
import '../../domain/services/etat_finances.dart';
import '../providers/finances_providers.dart';
import 'caisse_labels.dart';
import 'finances_widgets.dart';

/// 1. Entrée ou sortie d'argent SANS autre source (apport, retrait,
/// remboursement…). Ventes, dettes, achats et dépenses alimentent la caisse
/// d'eux-mêmes : ils ne sont pas proposés ici (jamais de double saisie).
Future<void> showNouvelleOperationModal(
  BuildContext context, {
  required EtatFinances etat,
  String? perimetreIdParDefaut,
  SensPaiement sensInitial = SensPaiement.entree,
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (_) =>
      _NouvelleOperationSheet(etat: etat, perimetreIdParDefaut: perimetreIdParDefaut, sensInitial: sensInitial),
);

class _NouvelleOperationSheet extends ConsumerStatefulWidget {
  const _NouvelleOperationSheet({required this.etat, this.perimetreIdParDefaut, required this.sensInitial});

  final EtatFinances etat;
  final String? perimetreIdParDefaut;
  final SensPaiement sensInitial;

  @override
  ConsumerState<_NouvelleOperationSheet> createState() => _NouvelleOperationSheetState();
}

class _NouvelleOperationSheetState extends ConsumerState<_NouvelleOperationSheet> {
  final _formKey = GlobalKey<FormState>();
  late SensPaiement _sens;
  late NaturePaiement _nature;
  final _montantController = TextEditingController();
  final _motifController = TextEditingController();

  ModePaiement _mode = ModePaiement.especes;
  String? _perimetreId;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _sens = widget.sensInitial;
    _nature = _naturesPour(_sens, ajuster: false).first;
    _perimetreId = widget.perimetreIdParDefaut;
  }

  @override
  void dispose() {
    _montantController.dispose();
    _motifController.dispose();
    super.dispose();
  }

  static List<NaturePaiement> _naturesPour(SensPaiement sens, {required bool ajuster}) => [
    if (sens == SensPaiement.entree) NaturePaiement.apport else NaturePaiement.retrait,
    NaturePaiement.remboursement,
    NaturePaiement.autre,
    if (ajuster) ...[if (sens == SensPaiement.entree) NaturePaiement.soldeInitial, NaturePaiement.ajustement],
  ];

  Future<void> _valider() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final montant = ChampMontant.lire(_montantController.text) ?? 0;
    final ctx = ref.read(contexteActifProvider);
    if (montant <= 0 || ctx == null) return;

    setState(() => _enCours = true);
    try {
      await ref
          .read(gererOperationsCaisseProvider)
          .ajouter(
            ctx,
            widget.etat,
            sens: _sens,
            nature: _nature,
            montant: montant,
            mode: _mode,
            motif: _motifController.text,
            perimetreId: _perimetreId,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final droits = ref.watch(droitsFinancesProvider);
    final sites = (ref.watch(perimetresProvider).value ?? const []).where((p) => p.estActif).toList();
    final natures = _naturesPour(_sens, ajuster: droits.ajuster);
    final entree = _sens == SensPaiement.entree;

    return _Feuille(
      titre: entree ? l10n.cashIn : l10n.cashOut,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<SensPaiement>(
              segments: [
                ButtonSegment(
                  value: SensPaiement.entree,
                  icon: const Icon(Icons.south_west_rounded, color: AppColors.positive),
                  label: Text(l10n.cashIn),
                ),
                ButtonSegment(
                  value: SensPaiement.sortie,
                  icon: const Icon(Icons.north_east_rounded, color: AppColors.negative),
                  label: Text(l10n.cashOut),
                ),
              ],
              selected: {_sens},
              onSelectionChanged: (s) => setState(() {
                _sens = s.first;
                _nature = _naturesPour(_sens, ajuster: droits.ajuster).first;
              }),
            ),
            const SizedBox(height: AppSpacing.lg),
            ChampMontant(
              key: const Key('operation-montant'),
              controller: _montantController,
              label: l10n.paymentAmount,
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in natures)
                  ChoiceChip(
                    key: Key('operation-nature-${n.code}'),
                    label: Text(l10n.naturePaiement(n)),
                    selected: _nature == n,
                    onSelected: (_) => setState(() => _nature = n),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const Key('operation-motif'),
              controller: _motifController,
              maxLength: 300,
              decoration: InputDecoration(
                labelText: l10n.cashOperationReason,
                hintText: l10n.naturePaiement(_nature),
                counterText: '',
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<ModePaiement>(
              initialValue: _mode,
              decoration: InputDecoration(
                labelText: l10n.paymentMode,
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
              ),
              items: [
                for (final m in ref.watch(modesPaiementProvider))
                  DropdownMenuItem(value: m, child: Text(l10n.modePaiement(m))),
              ],
              onChanged: (v) => v == null ? null : setState(() => _mode = v),
            ),
            if (sites.length > 1) ...[
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String?>(
                initialValue: _perimetreId,
                decoration: InputDecoration(
                  labelText: l10n.cashSite,
                  prefixIcon: const Icon(Icons.storefront_outlined),
                ),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.cashCompanyLevel)),
                  for (final s in sites) DropdownMenuItem(value: s.id, child: Text(s.nom)),
                ],
                onChanged: (v) => setState(() => _perimetreId = v),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const Key('operation-valider'),
              style: FilledButton.styleFrom(
                backgroundColor: entree ? AppColors.positive : AppColors.negative,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: _enCours ? null : _valider,
              child: _enCours
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(l10n.commonSave, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2. Transfert : boutique → boutique et/ou moyen → moyen (espèces → banque…).
/// Une seule opération : les deux jambes partent ensemble, le total ne change pas.
Future<void> showTransfertModal(BuildContext context, {required EtatFinances etat, String? perimetreIdParDefaut}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransfertSheet(etat: etat, perimetreIdParDefaut: perimetreIdParDefaut),
    );

class _TransfertSheet extends ConsumerStatefulWidget {
  const _TransfertSheet({required this.etat, this.perimetreIdParDefaut});
  final EtatFinances etat;
  final String? perimetreIdParDefaut;

  @override
  ConsumerState<_TransfertSheet> createState() => _TransfertSheetState();
}

class _TransfertSheetState extends ConsumerState<_TransfertSheet> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _motifController = TextEditingController();

  ModePaiement _modeSource = ModePaiement.especes;
  ModePaiement _modeDest = ModePaiement.virement;
  late String? _siteSource = widget.perimetreIdParDefaut;
  late String? _siteDest = widget.perimetreIdParDefaut;
  bool _enCours = false;

  @override
  void dispose() {
    _montantController.dispose();
    _motifController.dispose();
    super.dispose();
  }

  bool get _identique => _siteSource == _siteDest && _modeSource == _modeDest;

  Future<void> _valider() async {
    if (!(_formKey.currentState?.validate() ?? false) || _identique) return;
    final montant = ChampMontant.lire(_montantController.text) ?? 0;
    final ctx = ref.read(contexteActifProvider);
    if (montant <= 0 || ctx == null) return;

    setState(() => _enCours = true);
    try {
      await ref
          .read(gererOperationsCaisseProvider)
          .transferer(
            ctx,
            widget.etat,
            montant: montant,
            modeSource: _modeSource,
            modeDest: _modeDest,
            perimetreSourceId: _siteSource,
            perimetreDestId: _siteDest,
            motif: _motifController.text,
          );
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        final texte = context.l10n.cashTransferDone;
        Navigator.pop(context);
        messenger.showSnackBar(SnackBar(content: Text(texte)));
      }
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sites = (ref.watch(perimetresProvider).value ?? const []).where((p) => p.estActif).toList();
    final modes = ref.watch(modesPaiementProvider);

    Widget extremite(
      String titre,
      String? site,
      ModePaiement mode,
      ValueChanged<String?> surSite,
      ValueChanged<ModePaiement> surMode,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          titre,
          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (sites.length > 1) ...[
          DropdownButtonFormField<String?>(
            initialValue: site,
            decoration: InputDecoration(labelText: l10n.cashSite, isDense: true),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.cashCompanyLevel)),
              for (final s in sites) DropdownMenuItem(value: s.id, child: Text(s.nom)),
            ],
            onChanged: surSite,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        DropdownButtonFormField<ModePaiement>(
          initialValue: mode,
          decoration: InputDecoration(labelText: l10n.paymentMode, isDense: true),
          items: [for (final m in modes) DropdownMenuItem(value: m, child: Text(l10n.modePaiement(m)))],
          onChanged: (v) => v == null ? null : surMode(v),
        ),
      ],
    );

    return _Feuille(
      titre: l10n.cashTransferTitle,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ChampMontant(
              key: const Key('transfert-montant'),
              controller: _montantController,
              label: l10n.paymentAmount,
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.md),
            extremite(
              l10n.cashTransferFrom,
              _siteSource,
              _modeSource,
              (v) => setState(() => _siteSource = v),
              (v) => setState(() => _modeSource = v),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Icon(Icons.arrow_downward_rounded, color: AppColors.muted),
            ),
            extremite(
              l10n.cashTransferTo,
              _siteDest,
              _modeDest,
              (v) => setState(() => _siteDest = v),
              (v) => setState(() => _modeDest = v),
            ),
            if (_identique)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(l10n.cashTransferSame, style: const TextStyle(color: AppColors.negative, fontSize: 12)),
              ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _motifController,
              maxLength: 300,
              decoration: InputDecoration(labelText: l10n.cashOperationReason, counterText: ''),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const Key('transfert-valider'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: _enCours || _identique ? null : _valider,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: Text(l10n.cashTransferTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 3. Fermeture de caisse : solde attendu, espèces comptées, écart. Un écart
/// n'est jamais corrigé en silence : il se justifie (cause + explication).
Future<void> showClotureCaisseModal(
  BuildContext context, {
  required EtatFinances etat,
  required SessionCaisse session,
}) => showDialog(
  context: context,
  builder: (_) => _ClotureCaisseDialog(etat: etat, session: session),
);

class _ClotureCaisseDialog extends ConsumerStatefulWidget {
  const _ClotureCaisseDialog({required this.etat, required this.session});
  final EtatFinances etat;
  final SessionCaisse session;

  @override
  ConsumerState<_ClotureCaisseDialog> createState() => _ClotureCaisseDialogState();
}

class _ClotureCaisseDialogState extends ConsumerState<_ClotureCaisseDialog> {
  final _compteController = TextEditingController();
  final _noteController = TextEditingController();
  MotifEcart? _motif;
  bool _enCours = false;

  @override
  void dispose() {
    _compteController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _cloturer() async {
    final compte = ChampMontant.lire(_compteController.text);
    final ctx = ref.read(contexteActifProvider);
    if (compte == null || ctx == null) return;

    setState(() => _enCours = true);
    try {
      await ref
          .read(gererCaisseProvider)
          .cloturer(
            ctx,
            widget.etat,
            widget.session,
            soldeReel: compte,
            note: _noteController.text,
            motifEcart: _motif,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final devise = ref.watch(deviseProvider);
    final attendu = widget.etat.solde(widget.session);
    final compte = ChampMontant.lire(_compteController.text);
    final ecart = compte == null ? null : compte - attendu;
    final aJustifier = ecart != null && ecart != 0;
    final pret = compte != null && (!aJustifier || (_motif != null && _noteController.text.trim().isNotEmpty));

    return AlertDialog(
      title: Text(l10n.cashClose),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.cashExpected(l10n.montant(attendu, devise)), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            ChampMontant(
              key: const Key('cloture-compte'),
              controller: _compteController,
              label: l10n.cashCounted,
              obligatoire: false,
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
            if (ecart != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  ecart == 0 ? l10n.cashNoGap : l10n.cashGapJustify(l10n.montant(ecart, devise)),
                  key: const Key('cloture-ecart'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ecart == 0 ? AppColors.positive : AppColors.negative,
                  ),
                ),
              ),
            if (aJustifier) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final m in MotifEcart.values)
                    ChoiceChip(
                      key: Key('cloture-motif-${m.code}'),
                      label: Text(l10n.motifEcart(m)),
                      selected: _motif == m,
                      onSelected: (_) => setState(() => _motif = m),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('cloture-note'),
              controller: _noteController,
              maxLength: 300,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: aJustifier ? l10n.cashGapNoteRequired : l10n.cashClosingNote,
                counterText: '',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
        FilledButton(
          key: const Key('cloture-confirmer'),
          onPressed: !pret || _enCours ? null : _cloturer,
          child: Text(l10n.cashClose),
        ),
      ],
    );
  }
}

/// Feuille du bas commune : poignée, titre, fermeture, clavier pris en compte.
class _Feuille extends StatelessWidget {
  const _Feuille({required this.titre, required this.child});
  final String titre;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    padding: EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  titre,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    ),
  );
}

/// 4. Détail d'une opération : montant, source, moyen, boutique, contact,
/// accès au document source, annulation (jamais d'effacement).
Future<void> showDetailOperationModal(
  BuildContext context, {
  required EtatFinances etat,
  required OperationTresorerie operation,
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (_) => _DetailOperationSheet(etat: etat, operation: operation),
);

class _DetailOperationSheet extends ConsumerWidget {
  const _DetailOperationSheet({required this.etat, required this.operation});
  final EtatFinances etat;
  final OperationTresorerie operation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final op = operation;
    final droits = ref.watch(droitsFinancesProvider);
    final sites = ref.watch(nomsPerimetresProvider);
    final contacts = ref.watch(contactsParIdProvider).value ?? const {};
    final transfert = op.transfertId == null ? null : etat.transfert(op.transfertId!);
    final annulable = !op.estAnnule && !op.estRefuse && !op.estAnnulation && op.depenseId == null;
    final peutAnnuler =
        annulable &&
        (transfert != null ? droits.transferer && !transfert.annule : droits.annulerPaiements && op.paiementId != null);

    Widget ligne(String label, String valeur) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Expanded(
            child: Text(valeur, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    return _Feuille(
      titre: op.libelle ?? l10n.origineMouvement(op.origine),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Montant(
            op.montant,
            signe: op.estEntree,
            barre: op.estAnnule || op.estRefuse || op.estAnnulation,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.sm),
          ligne(l10n.cashDetailSource, l10n.origineMouvement(op.origine)),
          ligne(l10n.paymentMode, l10n.modePaiement(op.mode)),
          ligne(l10n.cashDetailDate, l10n.dateTime(op.date)),
          if (op.perimetreId != null) ligne(l10n.cashSite, sites[op.perimetreId] ?? '—'),
          if (op.contactId != null && contacts[op.contactId] != null)
            ligne(l10n.cashDetailContact, contacts[op.contactId]!.nomAffiche),
          if (op.reference != null) ligne(l10n.cashDetailReference, op.reference!),
          if (op.note != null && op.note != op.libelle) ligne(l10n.cashOperationReason, op.note!),
          if (op.enAttente) ligne('', l10n.cashPending),
          const SizedBox(height: AppSpacing.md),
          if (op.depenseId != null || (op.paiementId != null && transfert == null))
            OutlinedButton.icon(
              key: const Key('operation-ouvrir-source'),
              onPressed: () {
                Navigator.pop(context);
                context.push(op.depenseId != null ? Routes.depense(op.depenseId!) : Routes.paiement(op.paiementId!));
              },
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(l10n.cashDetailOpen),
            ),
          if (peutAnnuler) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              key: const Key('operation-annuler'),
              style: TextButton.styleFrom(foregroundColor: AppColors.negative),
              onPressed: () => _annuler(context, ref, transfert),
              icon: const Icon(Icons.undo_rounded),
              label: Text(transfert != null ? l10n.cashTransferCancel : l10n.cashCancelOperation),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _annuler(BuildContext context, WidgetRef ref, TransfertTresorerie? transfert) async {
    final l10n = context.l10n;
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    // Un transfert s'annule d'un bloc, avec un motif ; un paiement par son inverse.
    String? motif;
    if (transfert != null) {
      final controleur = TextEditingController();
      motif = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(l10n.cashTransferCancel),
          content: TextField(
            controller: controleur,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.cashCancelReason),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: Text(l10n.commonCancel)),
            FilledButton(
              onPressed: () => Navigator.pop(d, controleur.text.trim()),
              child: Text(l10n.cashTransferCancel),
            ),
          ],
        ),
      );
      controleur.dispose();
      if (motif == null || motif.isEmpty) return;
    }
    try {
      if (transfert != null) {
        await ref.read(gererOperationsCaisseProvider).annulerTransfert(ctx, etat, transfert, motif: motif!);
      } else {
        final p = etat.paiement(operation.paiementId!);
        if (p == null) return;
        await ref.read(annulerPaiementProvider).call(ctx, etat, p);
      }
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) showFailureSnackBar(context, e);
    }
  }
}
