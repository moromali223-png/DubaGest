import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/agenda.dart';
import '../../domain/usecases/gerer_agenda.dart';
import '../providers/agenda_providers.dart';
import 'agenda_page.dart';

/// Nouvelle échéance (éventuellement liée à une fiche), ou modification.
class EcheanceFormPage extends ConsumerWidget {
  const EcheanceFormPage({super.key, this.echeanceId, this.cibleType, this.cibleId, this.titre});
  final String? echeanceId;
  final CibleType? cibleType;
  final String? cibleId;
  final String? titre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (echeanceId == null) {
      return _Formulaire(cibleType: cibleType, cibleId: cibleId, titreInitial: titre);
    }
    final echeances = ref.watch(echeancesProvider);
    final e = echeances.value?.where((x) => x.id == echeanceId).firstOrNull;
    if (e != null) return _Formulaire(initial: e);
    return Scaffold(
      appBar: AppBar(),
      body: echeances.isLoading ? const LoadingView() : EmptyView(message: context.l10n.financeNotFound),
    );
  }
}

class _Formulaire extends ConsumerStatefulWidget {
  const _Formulaire({this.initial, this.cibleType, this.cibleId, this.titreInitial});
  final Echeance? initial;
  final CibleType? cibleType;
  final String? cibleId;
  final String? titreInitial;

  @override
  ConsumerState<_Formulaire> createState() => _FormulaireState();
}

class _FormulaireState extends ConsumerState<_Formulaire> {
  final _formKey = GlobalKey<FormState>();
  late final _titre = TextEditingController(text: widget.initial?.titre ?? widget.titreInitial);
  late final _note = TextEditingController(text: widget.initial?.note);
  late TypeEcheance _type =
      widget.initial?.type ?? (widget.cibleType == null ? TypeEcheance.tache : TypeEcheance.relance);
  late DateTime _date = widget.initial?.dateHeure.toLocal() ?? _demainNeufHeures();
  late int? _rappel = widget.initial?.rappelMinutes ?? 60;
  late String? _responsableId = widget.initial?.responsableId;
  late String? _responsableNom = widget.initial?.responsableNom;
  bool _enCours = false;

  static DateTime _demainNeufHeures() {
    final d = DateTime.now().add(const Duration(days: 1));
    return DateTime(d.year, d.month, d.day, 9);
  }

  @override
  void dispose() {
    _titre.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    final saisie = SaisieEcheance(
      type: _type,
      titre: _titre.text,
      note: _note.text,
      dateHeure: _date,
      rappelMinutes: _rappel,
      responsableId: _responsableId,
      responsableNom: _responsableNom,
      cibleType: widget.initial?.cibleType ?? widget.cibleType,
      cibleId: widget.initial?.cibleId ?? widget.cibleId,
    );
    setState(() => _enCours = true);
    try {
      final gerer = ref.read(gererEcheancesProvider);
      if (widget.initial == null) {
        final e = await gerer.creer(ctx, saisie);
        if (mounted) context.pushReplacement(Routes.echeance(e.id));
      } else {
        await gerer.modifier(ctx, widget.initial!, saisie);
        if (mounted) context.pop();
      }
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _choisirDate() async {
    final jour = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (jour == null || !mounted) return;
    final heure = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
    setState(() => _date = DateTime(jour.year, jour.month, jour.day, heure?.hour ?? _date.hour, heure?.minute ?? _date.minute));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ctx = ref.watch(contexteActifProvider);
    final membres = ref.watch(membresAssignablesProvider).value ?? const [];
    const espace = SizedBox(height: AppSpacing.md);
    const rappels = <int?>[null, 15, 60, 1440];

    return Scaffold(
      appBar: AppBar(title: Text(widget.initial == null ? l10n.agendaNew : l10n.agendaEdit)),
      body: ResponsiveBody(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final t in TypeEcheance.values)
                    ChoiceChip(
                      key: Key('echeance-type-${t.code}'),
                      avatar: Icon(iconeEcheance(t), size: 18),
                      label: Text(l10n.typeEcheance(t)),
                      selected: _type == t,
                      onSelected: (_) => setState(() => _type = t),
                    ),
                ],
              ),
              espace,
              TextFormField(
                key: const Key('echeance-titre'),
                controller: _titre,
                maxLength: 200,
                decoration: InputDecoration(labelText: l10n.agendaTitle, hintText: l10n.agendaTitleHint, counterText: ''),
                validator: (v) => (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
              ),
              espace,
              InkWell(
                key: const Key('echeance-date'),
                borderRadius: BorderRadius.circular(12),
                onTap: _choisirDate,
                child: InputDecorator(
                  decoration: InputDecoration(labelText: l10n.agendaWhen, prefixIcon: const Icon(Icons.event_outlined)),
                  child: Text('${l10n.date(_date)} · ${l10n.heure(_date)}'),
                ),
              ),
              espace,
              DropdownButtonFormField<int?>(
                initialValue: _rappel,
                decoration: InputDecoration(labelText: l10n.agendaReminder, prefixIcon: const Icon(Icons.alarm)),
                items: [
                  for (final r in rappels)
                    DropdownMenuItem(value: r, child: Text(r == null ? l10n.agendaNoReminder : l10n.agendaReminderBefore(l10n.delai(r)))),
                ],
                onChanged: (v) => setState(() => _rappel = v),
              ),
              espace,
              DropdownButtonFormField<String?>(
                key: const Key('echeance-responsable'),
                initialValue: _responsableId,
                decoration: InputDecoration(labelText: l10n.agendaAssignee, prefixIcon: const Icon(Icons.person_outline)),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.agendaNobody)),
                  if (ctx != null) DropdownMenuItem(value: ctx.userId, child: Text(l10n.agendaMe)),
                  for (final m in membres.where((m) => m.userId != ctx?.userId))
                    DropdownMenuItem(value: m.userId, child: Text(m.nomComplet ?? m.userId)),
                  // Responsable actuel absent de la liste (hors-ligne) : on le garde.
                  if (_responsableId != null &&
                      _responsableId != ctx?.userId &&
                      !membres.any((m) => m.userId == _responsableId))
                    DropdownMenuItem(value: _responsableId, child: Text(_responsableNom ?? '…')),
                ],
                onChanged: (v) => setState(() {
                  _responsableId = v;
                  _responsableNom = v == null
                      ? null
                      : (v == ctx?.userId ? ctx?.nomComplet : membres.where((m) => m.userId == v).firstOrNull?.nomComplet);
                }),
              ),
              espace,
              TextFormField(
                controller: _note,
                maxLength: 1000,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(labelText: l10n.paymentNote, counterText: ''),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                key: const Key('echeance-enregistrer'),
                onPressed: _enCours ? null : _enregistrer,
                child: _enCours
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.commonSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
