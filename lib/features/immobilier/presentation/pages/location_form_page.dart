import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../contacts/presentation/widgets/contact_avatar.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/bien_immobilier.dart';
import '../../domain/entities/location_immobilier.dart';
import '../providers/immobilier_providers.dart';
import '../widgets/immobilier_widgets.dart';
import '../widgets/locataire_widgets.dart';
import '../widgets/location_widgets.dart';
import '../../../../shared/forms/forms.dart';

class LocationFormPage extends ConsumerStatefulWidget {
  const LocationFormPage({
    super.key,
    this.initialBienId,
    this.initialLocataireId,
  });

  final String? initialBienId;
  final String? initialLocataireId;

  @override
  ConsumerState<LocationFormPage> createState() => _LocationFormPageState();
}

class _LocationFormPageState extends ConsumerState<LocationFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _formController = SmartFormController(allowMultipleOpen: true);

  BienImmobilier? _bienSelectionne;
  Contact? _locataireSelectionne;

  DateTime _dateDebut = DateTime.now();
  DateTime? _dateFinPrevue;

  late final _loyerCtrl = TextEditingController();
  late final _chargesCtrl = TextEditingController(text: '0');
  late final _depotCtrl = TextEditingController(text: '0');
  late final _remarquesCtrl = TextEditingController();

  bool _etatLieuxEntree = false;
  bool _chargement = false;
  String? _erreurChevauchement;

  @override
  void initState() {
    super.initState();
    _formController.openAll(5);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialiser());
  }

  Future<void> _initialiser() async {
    if (widget.initialBienId != null) {
      final bien = await ref.read(immobilierRepositoryProvider).getBien(widget.initialBienId!);
      if (bien != null && mounted) {
        setState(() {
          _bienSelectionne = bien;
          _loyerCtrl.text = bien.loyerReference.toString();
          _depotCtrl.text = bien.depotGarantiePrevu.toString();
        });
      }
    }

    if (widget.initialLocataireId != null) {
      final contact = await ref.read(contactProvider(widget.initialLocataireId!).future);
      if (contact != null && mounted) {
        setState(() => _locataireSelectionne = contact);
      }
    }
  }

  @override
  void dispose() {
    _loyerCtrl.dispose();
    _chargesCtrl.dispose();
    _depotCtrl.dispose();
    _remarquesCtrl.dispose();
    _formController.dispose();
    super.dispose();
  }

  Future<void> _selectionnerDateDebut() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateDebut,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      setState(() {
        _dateDebut = picked;
        _erreurChevauchement = null;
      });
    }
  }

  Future<void> _selectionnerDateFinPrevue() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFinPrevue ?? _dateDebut.add(const Duration(days: 365)),
      firstDate: _dateDebut,
      lastDate: DateTime(2045),
    );
    if (picked != null) {
      setState(() {
        _dateFinPrevue = picked;
        _erreurChevauchement = null;
      });
    }
  }

  Future<void> _sauvegarder() async {
    setState(() => _erreurChevauchement = null);

    if (_bienSelectionne == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un bien immobilier à louer.')),
      );
      return;
    }

    if (_locataireSelectionne == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un locataire.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final loyer = int.tryParse(_loyerCtrl.text.replaceAll(' ', '')) ?? 0;
    final charges = int.tryParse(_chargesCtrl.text.replaceAll(' ', '')) ?? 0;
    final depot = int.tryParse(_depotCtrl.text.replaceAll(' ', '')) ?? 0;

    setState(() => _chargement = true);

    try {
      final ctx = ref.read(contexteActifProvider);
      if (ctx == null || ctx.entreprise == null) return;

      final location = LocationImmobilier(
        id: const Uuid().v4(),
        entrepriseId: ctx.entreprise!.id,
        bienId: _bienSelectionne!.id,
        locataireId: _locataireSelectionne!.id,
        dateDebut: _dateDebut,
        dateFinPrevue: _dateFinPrevue,
        loyerMensuel: loyer,
        chargesMensuelles: charges,
        depotGarantie: depot,
        statut: _dateDebut.isAfter(DateTime.now()) ? StatutLocation.enAttente : StatutLocation.active,
        etatLieuxEntree: _etatLieuxEntree,
        remarques: _remarquesCtrl.text.trim().isEmpty ? null : _remarquesCtrl.text.trim(),
        creeLe: DateTime.now(),
        misAJourLe: DateTime.now(),
      );

      final cree = await ref.read(immobilierRepositoryProvider).sauvegarderLocation(location);

      ref.invalidate(locationsListProvider);
      ref.invalidate(biensListProvider);
      ref.invalidate(parcOccupationStatistiquesProvider);

      if (mounted) {
        context.go(Routes.locationDetails(cree.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location enregistrée avec succès.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _erreurChevauchement = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = ref.watch(contexteActifProvider);
    final devise = ctx?.entreprise?.devise ?? 'FCFA';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nouvelle Location'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: SmartFormContainer(
                controller: _formController,
                children: [
                  if (_erreurChevauchement != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _erreurChevauchement!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 1. SÉLECTION DU BIEN
                  CollapsibleFormSection(
                    key: _formController.registerSectionKey(0),
                    title: '1. BIEN IMMOBILIER',
                    icon: _bienSelectionne?.type.icone ?? Icons.home_work_outlined,
                    isExpanded: _formController.isSectionOpen(0),
                    onToggle: () => setState(() => _formController.toggleSection(0)),
                    isRequired: true,
                    summary: _bienSelectionne != null
                        ? 'Réf : ${_bienSelectionne!.reference} · ${_bienSelectionne!.ville ?? ''}'
                        : 'Aucun bien sélectionné',
                    status: _bienSelectionne != null ? FormSectionStatus.complete : FormSectionStatus.emptyRequired,
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.border, width: 1.2),
                      ),
                      color: AppColors.surface,
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _bienSelectionne?.type.icone ?? Icons.home_work_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                        title: Text(
                          _bienSelectionne?.nom ?? 'Sélectionner un logement...',
                          style: TextStyle(
                            fontWeight: _bienSelectionne != null ? FontWeight.w800 : FontWeight.w500,
                            color: _bienSelectionne != null ? AppColors.ink : AppColors.muted,
                          ),
                        ),
                        subtitle: Text(
                          _bienSelectionne != null
                              ? 'Réf : ${_bienSelectionne!.reference} · ${_bienSelectionne!.ville ?? ''}'
                              : 'Appuyez pour choisir le bien dans le parc',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: _bienSelectionne != null
                            ? StatutBienBadge(statut: _bienSelectionne!.statut)
                            : const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                        onTap: () async {
                          final b = await choisirBien(context);
                          if (b != null) {
                            setState(() {
                              _bienSelectionne = b;
                              _loyerCtrl.text = b.loyerReference.toString();
                              _depotCtrl.text = b.depotGarantiePrevu.toString();
                              _erreurChevauchement = null;
                            });
                          }
                        },
                      ),
                    ),
                  ),

                  // 2. SÉLECTION DU LOCATAIRE
                  CollapsibleFormSection(
                    key: _formController.registerSectionKey(1),
                    title: '2. LOCATAIRE OCCUPANT',
                    icon: Icons.person_outline_rounded,
                    isExpanded: _formController.isSectionOpen(1),
                    onToggle: () => setState(() => _formController.toggleSection(1)),
                    isRequired: true,
                    summary: _locataireSelectionne?.nomAffiche,
                    status: _locataireSelectionne != null ? FormSectionStatus.complete : FormSectionStatus.emptyRequired,
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.border, width: 1.2),
                      ),
                      color: AppColors.surface,
                      child: ListTile(
                        leading: _locataireSelectionne != null
                            ? ContactAvatar(contact: _locataireSelectionne!, radius: 20)
                            : Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                              ),
                        title: Text(
                          _locataireSelectionne?.nomAffiche ?? 'Sélectionner un locataire...',
                          style: TextStyle(
                            fontWeight: _locataireSelectionne != null ? FontWeight.w800 : FontWeight.w500,
                            color: _locataireSelectionne != null ? AppColors.ink : AppColors.muted,
                          ),
                        ),
                        subtitle: Text(
                          _locataireSelectionne != null
                              ? '${_locataireSelectionne!.telephone ?? ''} · ${_locataireSelectionne!.ville ?? ''}'
                              : 'Appuyez pour sélectionner ou créer un locataire',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                        onTap: () async {
                          final loc = await choisirLocataire(context);
                          if (loc != null) {
                            setState(() {
                              _locataireSelectionne = loc;
                              _erreurChevauchement = null;
                            });
                          }
                        },
                      ),
                    ),
                  ),

                  // 3. PÉRIODE D'OCCUPATION
                  CollapsibleFormSection(
                    key: _formController.registerSectionKey(2),
                    title: '3. PÉRIODE D\'OCCUPATION',
                    icon: Icons.calendar_today_rounded,
                    isExpanded: _formController.isSectionOpen(2),
                    onToggle: () => setState(() => _formController.toggleSection(2)),
                    isRequired: true,
                    summary: 'Du ${_dateDebut.day.toString().padLeft(2, '0')}/${_dateDebut.month.toString().padLeft(2, '0')}/${_dateDebut.year}'
                        ' ${_dateFinPrevue != null ? "au ${_dateFinPrevue!.day.toString().padLeft(2, '0')}/${_dateFinPrevue!.month.toString().padLeft(2, '0')}/${_dateFinPrevue!.year}" : "(indéterminée)"}',
                    status: FormSectionStatus.complete,
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _selectionnerDateDebut,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date de début *',
                                prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                              ),
                              child: Text(
                                '${_dateDebut.day.toString().padLeft(2, '0')}/${_dateDebut.month.toString().padLeft(2, '0')}/${_dateDebut.year}',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _selectionnerDateFinPrevue,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Date fin prévue',
                                prefixIcon: const Icon(Icons.event_rounded, size: 18),
                                suffixIcon: _dateFinPrevue != null
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 16),
                                        onPressed: () => setState(() => _dateFinPrevue = null),
                                      )
                                    : null,
                              ),
                              child: Text(
                                _dateFinPrevue != null
                                    ? '${_dateFinPrevue!.day.toString().padLeft(2, '0')}/${_dateFinPrevue!.month.toString().padLeft(2, '0')}/${_dateFinPrevue!.year}'
                                    : 'Indéterminée',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _dateFinPrevue != null ? AppColors.ink : AppColors.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 4. CONDITIONS FINANCIÈRES
                  CollapsibleFormSection(
                    key: _formController.registerSectionKey(3),
                    title: '4. CONDITIONS FINANCIÈRES',
                    icon: Icons.payments_outlined,
                    isExpanded: _formController.isSectionOpen(3),
                    onToggle: () => setState(() => _formController.toggleSection(3)),
                    isRequired: true,
                    summary: _loyerCtrl.text.isNotEmpty ? '${_loyerCtrl.text} $devise' : null,
                    status: _loyerCtrl.text.isNotEmpty ? FormSectionStatus.complete : FormSectionStatus.emptyRequired,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _loyerCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Loyer mensuel hors charges *',
                            prefixIcon: const Icon(Icons.payments_outlined),
                            suffixText: devise,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Indiquez le loyer';
                            final n = int.tryParse(v.replaceAll(' ', ''));
                            if (n == null || n <= 0) return 'Montant invalide';
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _chargesCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Charges mensuelles',
                                  prefixIcon: const Icon(Icons.water_drop_outlined, size: 18),
                                  suffixText: devise,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _depotCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Dépôt de garantie',
                                  prefixIcon: const Icon(Icons.shield_outlined, size: 18),
                                  suffixText: devise,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 5. ÉTATS DES LIEUX ET CLAUSES
                  CollapsibleFormSection(
                    key: _formController.registerSectionKey(4),
                    title: '5. ÉTAT DES LIEUX & CLAUSES',
                    icon: Icons.fact_check_outlined,
                    isExpanded: _formController.isSectionOpen(4),
                    onToggle: () => setState(() => _formController.toggleSection(4)),
                    summary: _etatLieuxEntree ? 'État des lieux réalisé' : null,
                    status: _etatLieuxEntree || _remarquesCtrl.text.isNotEmpty ? FormSectionStatus.complete : FormSectionStatus.emptyOptional,
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'État des lieux d\'entrée réalisé',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          subtitle: const Text(
                            'Atteste de la remise des clés et de l\'état d\'entrée du logement',
                            style: TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                          value: _etatLieuxEntree,
                          onChanged: (val) => setState(() => _etatLieuxEntree = val),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _remarquesCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Remarques ou conditions particulières',
                            alignLabelWithHint: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          StickyFormActions(
            onSubmit: _chargement ? null : _sauvegarder,
            onCancel: () => Navigator.of(context).maybePop(),
            isLoading: _chargement,
            submitLabel: 'Valider et Activer la Location',
          ),
        ],
      ),
    );
  }
}
