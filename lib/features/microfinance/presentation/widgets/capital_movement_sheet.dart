import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/microfinance_enums.dart';
import '../../domain/entities/microfinance_models.dart';
import '../providers/microfinance_providers.dart';

/// Modal de création d'un compte/caisse de trésorerie Microfinance.
Future<MicrofinanceAccount?> afficherFormulaireCompteMicrofinance(
  BuildContext context, {
  MicrofinanceAccount? existant,
}) {
  return showModalBottomSheet<MicrofinanceAccount>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AccountFormSheet(existant: existant),
  );
}

/// Modal d'enregistrement d'un mouvement de capital / dépense / transfert interne.
Future<MicrofinanceFundMovement?> afficherFormulaireMouvementFonds(
  BuildContext context, {
  TypeMouvementFonds typeInitial = TypeMouvementFonds.apportSupplementaire,
}) {
  return showModalBottomSheet<MicrofinanceFundMovement>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FundMovementSheet(typeInitial: typeInitial),
  );
}

class _AccountFormSheet extends ConsumerStatefulWidget {
  const _AccountFormSheet({this.existant});
  final MicrofinanceAccount? existant;

  @override
  ConsumerState<_AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<_AccountFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomCtrl;
  late final TextEditingController _numCtrl;
  late final TextEditingController _soldeInitCtrl;
  late final TextEditingController _obsCtrl;

  late TypeCompteMicrofinance _type;
  late SourceFondsMicrofinance _source;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.existant;
    _type = a?.typeCompte ?? TypeCompteMicrofinance.caissePhysique;
    _source = a?.sourceFondsDefaut ?? SourceFondsMicrofinance.capitalPersonnel;
    _nomCtrl = TextEditingController(text: a?.nom ?? '');
    _numCtrl = TextEditingController(text: a?.numeroCompte ?? '');
    _soldeInitCtrl = TextEditingController(text: '${a?.soldeInitial ?? 0}');
    _obsCtrl = TextEditingController(text: a?.observations ?? '');
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _numCtrl.dispose();
    _soldeInitCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final ctx = ref.read(contexteActifProvider);
    if (ctx?.entreprise == null) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final ex = widget.existant;
      final soldeInit = int.tryParse(_soldeInitCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final acc = MicrofinanceAccount(
        id: ex?.id ?? const Uuid().v4(),
        entrepriseId: ctx!.entreprise!.id,
        nom: _nomCtrl.text.trim(),
        typeCompte: _type,
        sourceFondsDefaut: _source,
        numeroCompte: _numCtrl.text.trim().isEmpty ? null : _numCtrl.text.trim(),
        soldeInitial: ex?.soldeInitial ?? soldeInit,
        soldeActuel: ex?.soldeActuel ?? soldeInit,
        devise: ctx.entreprise!.devise ?? 'XOF',
        observations: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
        version: ex?.version ?? 1,
        createdAt: ex?.createdAt ?? now,
        updatedAt: now,
      );
      final saved = await ref.read(microfinanceRepositoryProvider).sauvegarderCompte(acc);
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isNew = widget.existant == null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              isNew ? 'Nouveau compte / caisse Microfinance' : 'Modifier le compte',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nomCtrl,
              decoration: const InputDecoration(labelText: 'Nom du compte (ex: Caisse Centrale, Orange Money) *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<TypeCompteMicrofinance>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type de compte'),
              items: [
                for (final t in TypeCompteMicrofinance.values)
                  DropdownMenuItem(value: t, child: Text(t.libelle(l10n.localeName))),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<SourceFondsMicrofinance>(
              initialValue: _source,
              decoration: const InputDecoration(labelText: 'Source principale des fonds'),
              items: [
                for (final s in SourceFondsMicrofinance.values)
                  DropdownMenuItem(value: s, child: Text(s.libelle(l10n.localeName))),
              ],
              onChanged: (v) => setState(() => _source = v ?? _source),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _numCtrl,
              decoration: const InputDecoration(labelText: 'Numéro compte / téléphone (facultatif)'),
            ),
            if (isNew) ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: _soldeInitCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Capital initial / Dotation de départ (FCFA)',
                  helperText: 'Enregistré automatiquement comme capital initial disponible',
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextFormField(
              controller: _obsCtrl,
              decoration: const InputDecoration(labelText: 'Observations (facultatif)'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _saving ? null : _valider,
              icon: const Icon(Icons.check_rounded),
              label: Text(isNew ? 'Créer le compte' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FundMovementSheet extends ConsumerStatefulWidget {
  const _FundMovementSheet({required this.typeInitial});
  final TypeMouvementFonds typeInitial;

  @override
  ConsumerState<_FundMovementSheet> createState() => _FundMovementSheetState();
}

class _FundMovementSheetState extends ConsumerState<_FundMovementSheet> {
  final _formKey = GlobalKey<FormState>();
  final _montantCtrl = TextEditingController();
  final _libelleCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  late TypeMouvementFonds _type;
  SourceFondsMicrofinance _source = SourceFondsMicrofinance.capitalPersonnel;
  ModePaiementMicrofinance _mode = ModePaiementMicrofinance.especes;
  String? _accountId;
  String? _accountDestId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.typeInitial;
    _libelleCtrl.text = _type.libelle('fr');
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _libelleCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final ctx = ref.read(contexteActifProvider);
    if (ctx?.entreprise == null || _accountId == null) return;
    final montant = int.tryParse(_montantCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    setState(() => _saving = true);
    try {
      final res = await ref.read(microfinanceRepositoryProvider).enregistrerMouvementFonds(
            entrepriseId: ctx!.entreprise!.id,
            accountId: _accountId!,
            accountDestinationId:
                _type == TypeMouvementFonds.transfertInterne ? _accountDestId : null,
            typeMouvement: _type,
            sourceFonds: _source,
            montant: montant,
            modePaiement: _mode,
            dateMouvement: DateTime.now(),
            libelle: _libelleCtrl.text.trim(),
            observations: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
          );
      if (mounted) Navigator.pop(context, res);
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accounts = (ref.watch(mfAccountsProvider).value ?? const [])
        .where((a) => a.estActif && a.deletedAt == null)
        .toList();
    _accountId ??= accounts.firstOrNull?.id;
    _accountDestId ??= accounts.where((a) => a.id != _accountId).firstOrNull?.id;
    final devise = ref.watch(contexteActifProvider)?.entreprise?.devise ?? 'XOF';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Opération de Capital & Trésorerie',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TypeMouvementFonds>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type d\'opération'),
              items: [
                for (final t in TypeMouvementFonds.values)
                  DropdownMenuItem(value: t, child: Text(t.libelle(l10n.localeName))),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _type = v;
                    _libelleCtrl.text = v.libelle('fr');
                  });
                }
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: InputDecoration(
                labelText: _type == TypeMouvementFonds.transfertInterne
                    ? 'Compte source (émetteur)'
                    : 'Compte concerné',
              ),
              items: [
                for (final a in accounts)
                  DropdownMenuItem(
                    value: a.id,
                    child: Text('${a.nom} (${l10n.montant(a.soldeActuel, devise)})'),
                  ),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
            if (_type == TypeMouvementFonds.transfertInterne) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _accountDestId,
                decoration: const InputDecoration(labelText: 'Compte destinataire'),
                items: [
                  for (final a in accounts.where((x) => x.id != _accountId))
                    DropdownMenuItem(
                      value: a.id,
                      child: Text('${a.nom} (${l10n.montant(a.soldeActuel, devise)})'),
                    ),
                ],
                onChanged: (v) => setState(() => _accountDestId = v),
                validator: (v) =>
                    _type == TypeMouvementFonds.transfertInterne && (v == null || v == _accountId)
                        ? 'Choisissez un compte destinataire différent'
                        : null,
              ),
            ],
            const SizedBox(height: 10),
            TextFormField(
              controller: _montantCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Montant ($devise) *'),
              validator: (v) {
                final m = int.tryParse((v ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                return m <= 0 ? 'Montant requis (> 0)' : null;
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<SourceFondsMicrofinance>(
                    initialValue: _source,
                    isExpanded: true,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Source',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    items: [
                      for (final s in SourceFondsMicrofinance.values)
                        DropdownMenuItem(
                          value: s,
                          child: Text(
                            s.libelle(l10n.localeName),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _source = v ?? _source),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<ModePaiementMicrofinance>(
                    initialValue: _mode,
                    isExpanded: true,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Moyen',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    items: [
                      for (final m in ModePaiementMicrofinance.values)
                        DropdownMenuItem(
                          value: m,
                          child: Text(
                            m.libelle(l10n.localeName),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _mode = v ?? _mode),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _libelleCtrl,
              decoration: const InputDecoration(labelText: 'Libellé *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Libellé requis' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _obsCtrl,
              decoration: const InputDecoration(labelText: 'Observations (facultatif)'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _saving ? null : _valider,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Enregistrer l\'opération'),
            ),
          ],
        ),
      ),
    );
  }
}

