import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../entreprise/presentation/providers/espace_providers.dart';
import '../../domain/entities/dossier_dette.dart';
import '../../domain/entities/finances.dart';
import '../../domain/usecases/gerer_finances.dart';
import '../providers/finances_providers.dart';
import 'finances_widgets.dart';

/// Modal d'encaissement ou décaissement intelligent pour un dossier financier.
/// Supporte l'affectation automatique ou la sélection manuelle des dettes à régler.
class DialogRecevoirPaiementDossier extends ConsumerStatefulWidget {
  const DialogRecevoirPaiementDossier({
    super.key,
    required this.dossier,
  });

  final DossierDette dossier;

  static Future<bool?> show(BuildContext context, DossierDette dossier) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DialogRecevoirPaiementDossier(dossier: dossier),
    );
  }

  @override
  ConsumerState<DialogRecevoirPaiementDossier> createState() => _DialogRecevoirPaiementDossierState();
}

class _DialogRecevoirPaiementDossierState extends ConsumerState<DialogRecevoirPaiementDossier> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _referenceController = TextEditingController();
  final _noteController = TextEditingController();

  late ModePaiement _mode = ModePaiement.especes;
  late DateTime _date = DateTime.now();
  String? _sessionId;
  bool _affectationAuto = true;
  final Set<String> _engagementsSelectionnes = {};
  bool _enCours = false;

  DossierDette get _dossier => widget.dossier;
  bool get _recevoir => _dossier.sens == SensEngagement.aRecevoir;

  @override
  void initState() {
    super.initState();
    // Proposer par défaut le montant restant total
    if (_dossier.reste > 0) {
      _montantController.text = _dossier.reste.toString();
    }

    final site = ref.read(espaceCourantProvider).perimetreId;
    final etat = ref.read(etatFinancesProvider).value;
    if (etat != null) {
      final sessions = [
        for (final c in etat.caisses)
          if (etat.sessionOuverte(c.id) case final s?) (s, c),
      ];
      _sessionId = (sessions.where((x) => x.$1.perimetreId == site).firstOrNull ?? sessions.firstOrNull)?.$1.id;
    }

    // Par défaut, sélectionner tous les engagements avec reste > 0
    for (final s in _dossier.engagements) {
      if (s.reste > 0 && !s.engagement.annule) {
        _engagementsSelectionnes.add(s.engagement.id);
      }
    }
  }

  @override
  void dispose() {
    _montantController.dispose();
    _referenceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _validerPaiement() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ctx = ref.read(contexteActifProvider);
    final etat = ref.read(etatFinancesProvider).value;
    if (ctx == null || etat == null) return;

    final montant = ChampMontant.lire(_montantController.text) ?? 0;
    if (montant <= 0) return;

    setState(() => _enCours = true);

    try {
      final gerer = ref.read(enregistrerPaiementProvider);

      // Calcul des affectations (Auto ou Manuelle)
      final Map<String, int> affectations = {};
      var resteAVentiler = montant;

      final engagementsCibles = _affectationAuto
          ? (_dossier.engagements.where((s) => s.reste > 0 && !s.engagement.annule).toList()
            ..sort((a, b) => (a.engagement.echeance ?? DateTime(9999))
                .compareTo(b.engagement.echeance ?? DateTime(9999))))
          : _dossier.engagements
              .where((s) => _engagementsSelectionnes.contains(s.engagement.id) && s.reste > 0)
              .toList();

      for (final s in engagementsCibles) {
        if (resteAVentiler <= 0) break;
        final part = resteAVentiler > s.reste ? s.reste : resteAVentiler;
        affectations[s.engagement.id] = part;
        resteAVentiler -= part;
      }

      final passeParCaisse = _mode.passeParCaisse && _sessionId != null;

      await gerer.call(
        ctx,
        etat,
        SaisiePaiement(
          sens: _recevoir ? SensPaiement.entree : SensPaiement.sortie,
          montant: montant,
          mode: _mode,
          date: _date,
          contactId: _dossier.contactId,
          reference: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          perimetreId: passeParCaisse ? null : ref.read(espaceCourantProvider).perimetreId,
          sessionId: passeParCaisse ? _sessionId : null,
          affectations: affectations,
        ),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.failure(e)),
            backgroundColor: AppColors.negative,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final etat = ref.watch(etatFinancesProvider).value;
    final modes = ref.watch(modesPaiementProvider);
    final devise = ref.watch(deviseProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final sessions = [
      if (etat != null)
        for (final c in etat.caisses)
          if (etat.sessionOuverte(c.id) case final s?) (s, c),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // En-tête avec nom de la personne et reste dû
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.greenSoft,
                      child: Text(
                        _dossier.nomAffiche.characters.first.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.green),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _recevoir ? 'Recevoir un paiement' : 'Effectuer un paiement',
                            style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            _dossier.nomAffiche,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Reste : ${l10n.montant(_dossier.reste, devise)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, color: AppColors.border),

                // Montant à régler
                ChampMontant(
                  controller: _montantController,
                  label: '${l10n.paymentAmount} *',
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Raccourcis montants (Totalité, 50%, etc.)
                if (_dossier.reste > 0)
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('Tout solder'),
                        onPressed: () => setState(() => _montantController.text = _dossier.reste.toString()),
                      ),
                      if (_dossier.reste >= 2)
                        ActionChip(
                          label: const Text('50 %'),
                          onPressed: () => setState(
                            () => _montantController.text = (_dossier.reste ~/ 2).toString(),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.md),

                // Mode de paiement
                Text('Mode de règlement', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final m in modes)
                      ChoiceChip(
                        label: Text(l10n.modePaiement(m)),
                        selected: _mode == m,
                        onSelected: (_) => setState(() => _mode = m),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Si espèces : choix de la Caisse
                if (_mode.passeParCaisse && sessions.isNotEmpty) ...[
                  DropdownButtonFormField<String?>(
                    initialValue: _sessionId,
                    decoration: InputDecoration(
                      labelText: l10n.paymentCashRegister,
                      prefixIcon: const Icon(Icons.point_of_sale_outlined),
                    ),
                    items: [
                      for (final (s, c) in sessions)
                        DropdownMenuItem(
                          value: s.id,
                          child: Text('${c.nom} · ${l10n.montant(etat?.solde(s) ?? 0, devise)}'),
                        ),
                      DropdownMenuItem(value: null, child: Text(l10n.paymentNoCashRegister)),
                    ],
                    onChanged: (v) => setState(() => _sessionId = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Date du règlement
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _date = d);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date du paiement',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(l10n.date(_date)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Affectation des dettes
                if (_dossier.engagements.where((s) => s.reste > 0).length > 1) ...[
                  Card(
                    color: AppColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Affectation automatique',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            subtitle: const Text(
                              'Règle les échéances les plus anciennes en priorité.',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: _affectationAuto,
                            onChanged: (v) => setState(() => _affectationAuto = v),
                          ),
                          if (!_affectationAuto) ...[
                            const Divider(),
                            const Text(
                              'Sélectionnez les dettes à solder avec ce paiement :',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                            ),
                            const SizedBox(height: 4),
                            for (final s in _dossier.engagements.where((s) => s.reste > 0 && !s.engagement.annule))
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: Text(s.engagement.libelle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  'Reste : ${l10n.montant(s.reste, devise)}${s.engagement.echeance != null ? ' · Éch: ${l10n.date(s.engagement.echeance!)}' : ''}',
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                                ),
                                value: _engagementsSelectionnes.contains(s.engagement.id),
                                onChanged: (on) => setState(() {
                                  if (on == true) {
                                    _engagementsSelectionnes.add(s.engagement.id);
                                  } else {
                                    _engagementsSelectionnes.remove(s.engagement.id);
                                  }
                                }),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Note / Référence
                TextFormField(
                  controller: _referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Référence reçu / transaction (Facultatif)',
                    prefixIcon: Icon(Icons.tag_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Bouton de validation
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF01226C),
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _enCours ? null : _validerPaiement,
                  icon: _enCours
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(
                    _recevoir ? 'Valider l\'encaissement' : 'Valider le paiement',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
