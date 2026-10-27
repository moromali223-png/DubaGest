import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/forms/forms.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../entreprise/presentation/providers/espace_providers.dart';
import '../../../utilisateurs/domain/entities/membre.dart';
import '../../../utilisateurs/presentation/providers/membres_providers.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../../finances/domain/entities/finances.dart' as fin;
import '../../../finances/presentation/providers/finances_providers.dart';
import '../../../commerce/presentation/widgets/commerce_widgets.dart' show montant;
import '../../domain/entities/metier_template.dart';
import '../../domain/entities/prestation.dart';
import '../../domain/entities/service_catalogue.dart';
import '../services_providers.dart';
import '../widgets/devis_contact_widgets.dart';
import '../widgets/prestation_photos_section.dart';

/// Formulaire de création / modification d'une prestation multi-métiers.
class PrestationFormPage extends ConsumerStatefulWidget {
  const PrestationFormPage({
    super.key,
    this.prestationId,
    this.initialContactId,
    this.initialDate,
  });

  final String? prestationId;
  final String? initialContactId;
  final String? initialDate;

  @override
  ConsumerState<PrestationFormPage> createState() => _PrestationFormPageState();
}

class _PrestationFormPageState extends ConsumerState<PrestationFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _formController = SmartFormController(initialOpenIndex: 0, allowMultipleOpen: true);

  final _titreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _lieuCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _remiseCtrl = TextEditingController(text: '0');
  final _dureeCtrl = TextEditingController();

  String? _contactId;
  String? _responsableId;
  MetierCode _metierSelectionne = MetierCode.generique;
  UniteDuree _uniteDuree = UniteDuree.jours;
  final Map<String, dynamic> _champsMetier = {};
  final Map<String, TextEditingController> _champsMetierCtrls = {};

  PrioritePrestation _priorite = PrioritePrestation.normale;
  DateTime? _debutPrevu;
  DateTime? _echeanceJour;
  DateTime? _dateRemisePrevue;
  bool _livraisonRequise = false;

  final List<LignePrestation> _lignes = [];
  final List<PhotoPrestation> _photos = [];
  bool _chargementInitial = false;
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    _contactId = widget.initialContactId;
    _debutPrevu = DateTime.now();
    if (widget.initialDate != null) {
      _echeanceJour = DateTime.tryParse(widget.initialDate!);
    }
    _formController.openSection(0);
    _formController.openSection(1);
    _formController.openSection(2);
    _formController.openSection(4);
    _formController.openSection(5);
  }

  @override
  void dispose() {
    _formController.dispose();
    _titreCtrl.dispose();
    _descCtrl.dispose();
    _lieuCtrl.dispose();
    _noteCtrl.dispose();
    _remiseCtrl.dispose();
    _dureeCtrl.dispose();
    for (final c in _champsMetierCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _sousTotal => _lignes.fold<int>(0, (sum, l) => sum + l.totalLigne);
  int get _remise => int.tryParse(_remiseCtrl.text.trim()) ?? 0;
  int get _total => (_sousTotal - _remise).clamp(0, 1000000000000);

  // --- Statuts et Résumés dynamiques des sections ---

  FormSectionStatus get _metierStatus => FormSectionStatus.complete;
  String _metierSummary() => _metierSelectionne.libelle;

  FormSectionStatus get _clientStatus => _contactId != null ? FormSectionStatus.complete : FormSectionStatus.emptyRequired;
  String _clientSummary(List<Contact> contacts) {
    final c = contacts.where((c) => c.id == _contactId).firstOrNull;
    return c?.nom ?? 'Aucun client sélectionné';
  }

  FormSectionStatus get _infosStatus => _titreCtrl.text.trim().isNotEmpty ? FormSectionStatus.complete : FormSectionStatus.emptyRequired;
  String _infosSummary() {
    if (_titreCtrl.text.isEmpty) return 'Titre requis';
    return _titreCtrl.text;
  }

  FormSectionStatus get _techStatus => FormSectionStatus.complete;
  String _techSummary(MetierTemplate template) {
    final filled = template.champs.where((f) => _champsMetier[f.cle] != null && _champsMetier[f.cle].toString().isNotEmpty).length;
    if (filled == 0) return 'Aucun détail technique saisi';
    return '$filled champ(s) renseigné(s)';
  }

  FormSectionStatus get _photosStatus => _photos.isNotEmpty ? FormSectionStatus.complete : FormSectionStatus.emptyOptional;

  FormSectionStatus get _planningStatus => _echeanceJour != null ? FormSectionStatus.complete : FormSectionStatus.emptyRequired;
  String _planningSummary(BuildContext context) {
    if (_echeanceJour == null) return 'Dates du contrat requises';
    final debutStr = _debutPrevu != null ? DateFormat('dd/MM/yyyy').format(_debutPrevu!) : 'Immédiat';
    final finStr = DateFormat('dd/MM/yyyy').format(_echeanceJour!);
    final dureeStr = _dureeCtrl.text.isNotEmpty ? ' (${_dureeCtrl.text} ${_uniteDuree.libelle.toLowerCase()})' : '';
    return '$debutStr → $finStr$dureeStr • ${_priorite == PrioritePrestation.haute ? "Urgent" : "Normal"}';
  }

  FormSectionStatus get _lignesStatus => _lignes.isNotEmpty ? FormSectionStatus.complete : FormSectionStatus.emptyRequired;
  String _lignesSummary(BuildContext context) {
    if (_lignes.isEmpty) return 'Aucun service ajouté (Requis)';
    return '${_lignes.length} article(s) • ${montant(context, ref, _total)}';
  }

  FormSectionStatus get _lieuStatus => _lieuCtrl.text.trim().isNotEmpty ? FormSectionStatus.complete : FormSectionStatus.emptyOptional;
  String _lieuSummary() => _lieuCtrl.text.trim().isEmpty ? 'Lieu non précisé' : _lieuCtrl.text.trim();

  void _changerModeleMetier(MetierCode code) {
    setState(() {
      _metierSelectionne = code;
      final template = MetierTemplate.templatePour(code);
      if (_titreCtrl.text.trim().isEmpty ||
          _titreCtrl.text == MetierTemplate.templatePour(MetierCode.generique).titreParDefaut) {
        _titreCtrl.text = template.titreParDefaut;
      }
      _dureeCtrl.text = template.dureeParDefaut.toString();
      _uniteDuree = template.uniteParDefaut;
      _recalculerEcheanceDepuisDuree();

      for (final f in template.champs) {
        if (f.options.isEmpty) {
          if (!_champsMetierCtrls.containsKey(f.cle)) {
            _champsMetierCtrls[f.cle] = TextEditingController(
              text: _champsMetier[f.cle]?.toString() ?? '',
            );
          }
        }
      }
      if (template.champs.isNotEmpty) {
        _formController.openSection(3);
      }
    });
  }

  void _recalculerEcheanceDepuisDuree() {
    final duree = int.tryParse(_dureeCtrl.text.trim()) ?? 0;
    if (duree <= 0) return;
    final debut = _debutPrevu ?? DateTime.now();
    final moteur = ref.read(moteurEcheancesProvider);
    final calculee = moteur.calculerEcheancePrevue(debut, duree, _uniteDuree);
    setState(() {
      _echeanceJour = DateTime(calculee.year, calculee.month, calculee.day);
    });
  }

  void _recalculerDureeDepuisEcheance() {
    if (_echeanceJour == null) return;
    final debut = _debutPrevu ?? DateTime.now();
    final diffDays = _echeanceJour!.difference(debut).inDays;
    if (diffDays >= 0) {
      if (_uniteDuree == UniteDuree.semaines) {
        _dureeCtrl.text = (diffDays / 7).ceil().clamp(1, 9999).toString();
      } else if (_uniteDuree == UniteDuree.mois) {
        _dureeCtrl.text = (diffDays / 30).ceil().clamp(1, 9999).toString();
      } else if (_uniteDuree == UniteDuree.heures) {
        _dureeCtrl.text = (diffDays * 24).clamp(1, 99999).toString();
      } else {
        _dureeCtrl.text = diffDays == 0 ? '1' : diffDays.toString();
      }
    }
  }

  void _chargerDonneesPrestation(Prestation p) {
    if (_chargementInitial) return;
    _chargementInitial = true;

    setState(() {
      _metierSelectionne = p.metierCode;
      _titreCtrl.text = p.titre;
      _descCtrl.text = p.description ?? '';
      _lieuCtrl.text = p.lieu ?? '';
      _noteCtrl.text = p.note ?? '';
      _remiseCtrl.text = p.remise.toString();
      _contactId = p.contactId;
      _priorite = p.priorite;
      _debutPrevu = p.debutPrevu;
      _echeanceJour = p.echeanceJour;

      _dureeCtrl.text = p.dureeEstimee?.toString() ?? '';
      _uniteDuree = p.uniteDuree;
      _dateRemisePrevue = p.dateRemisePrevue;
      _livraisonRequise = p.livraisonRequise;
      _responsableId = p.responsableId;

      _lignes
        ..clear()
        ..addAll(p.lignes);
      _photos
        ..clear()
        ..addAll(p.photos);
      _champsMetier
        ..clear()
        ..addAll(p.champsMetier);

      final template = MetierTemplate.templatePour(p.metierCode);
      for (final f in template.champs) {
        if (f.options.isEmpty) {
          _champsMetierCtrls[f.cle] = TextEditingController(
            text: p.champsMetier[f.cle]?.toString() ?? '',
          );
        }
      }

      _formController.openSection(0);
      _formController.openSection(1);
      _formController.openSection(2);
      if (template.champs.isNotEmpty) _formController.openSection(3);
      _formController.openSection(template.champs.isNotEmpty ? 5 : 4);
      _formController.openSection(template.champs.isNotEmpty ? 6 : 5);
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalogueAsync = ref.watch(servicesCatalogueProvider);
    final contacts = ref.watch(contactsProvider).value ?? const <Contact>[];
    final membres = ref.watch(membresProvider).value ?? const <Membre>[];

    // Chargement sécurisé (pas d’effet de bord dans le build)
    if (widget.prestationId != null) {
      final pAsync = ref.watch(prestationDetailProvider(widget.prestationId!));

      return switch (pAsync) {
        AsyncLoading() => Scaffold(
          appBar: AppBar(title: const Text('Modifier le contrat de service')),
          body: const LoadingView(message: 'Chargement du contrat de service...'),
        ),
        AsyncError(:final error) => Scaffold(
          appBar: AppBar(title: const Text('Modifier le contrat de service')),
          body: ErrorView(
            error: error,
            onRetry: () => ref.invalidate(prestationDetailProvider(widget.prestationId!)),
          ),
        ),
        AsyncData(value: null) => Scaffold(
          appBar: AppBar(title: const Text('Modifier le contrat de service')),
          body: const EmptyView(
            icon: Icons.search_off_rounded,
            message: 'Contrat de service introuvable ou supprimé.',
          ),
        ),
        AsyncData(:final value) => () {
          if (!_chargementInitial) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _chargerDonneesPrestation(value!);
            });
          }
          return _construireFormulaire(context, catalogueAsync.value ?? const [], contacts, membres);
        }(),
      };
    }

    return _construireFormulaire(context, catalogueAsync.value ?? const [], contacts, membres);
  }

  // ─────────────────────────────────────────────
  //  FORMULAIRE PRINCIPAL
  // ─────────────────────────────────────────────
  Widget _construireFormulaire(
      BuildContext context,
      List<ServiceCatalogue> catalogue,
      List<Contact> contacts,
      List<Membre> membres,
      ) {
    final templateCourant = MetierTemplate.templatePour(_metierSelectionne);
    final selectedContact = contacts.cast<Contact?>().firstWhere(
      (c) => c?.id == _contactId,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.prestationId != null ? 'Modifier le contrat de service' : 'Formulaire de nouveau contrat de service'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: SmartFormContainer(
                controller: _formController,
                maxWidth: 800,
                sideSummary: _lignes.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: _PrestationSummary(
                          sousTotal: _sousTotal,
                          remise: _remise,
                          total: _total,
                        ),
                      )
                    : null,
                children: [
                  // 1. Modèle métier
            CollapsibleFormSection(
              key: _formController.registerSectionKey(0),
              title: 'Type de service',
              icon: Icons.category_rounded,
              summary: _metierSummary(),
              status: _metierStatus,
              isExpanded: _formController.isSectionOpen(0),
              onToggle: () => setState(() => _formController.toggleSection(0)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        for (final m in MetierCode.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: FilterChip(
                              avatar: Icon(
                                m.icone,
                                size: 18,
                                color: _metierSelectionne == m ? AppColors.gold : AppColors.primary,
                              ),
                              label: Text(m.libelle),
                              selected: _metierSelectionne == m,
                              onSelected: (sel) {
                                if (sel) _changerModeleMetier(m);
                              },
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _metierSelectionne == m ? Colors.white : AppColors.ink,
                              ),
                              backgroundColor: AppColors.surface,
                              side: BorderSide(
                                color: _metierSelectionne == m ? AppColors.primary : AppColors.border,
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (templateCourant.instructions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.greenSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.green.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb_outline, size: 20, color: AppColors.green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              templateCourant.instructions,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.green,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 2. Client
            CollapsibleFormSection(
              key: _formController.registerSectionKey(1),
              title: 'Client',
              icon: Icons.person_rounded,
              summary: _clientSummary(contacts),
              status: _clientStatus,
              isRequired: true,
              isExpanded: _formController.isSectionOpen(1),
              onToggle: () => setState(() => _formController.toggleSection(1)),
              child: SectionClientProspect(
                selectedContact: selectedContact,
                onChoisir: () => _ouvrirSelectionContact(contacts),
                onCreerNouveau: () => _ouvrirCreationContactRapide(),
                onRetirer: () => setState(() => _contactId = null),
              ),
            ),

            // 3. Informations générales
            CollapsibleFormSection(
              key: _formController.registerSectionKey(2),
              title: 'Informations de base',
              icon: Icons.edit_note_rounded,
              summary: _infosSummary(),
              status: _infosStatus,
              isRequired: true,
              isExpanded: _formController.isSectionOpen(2),
              onToggle: () => setState(() => _formController.toggleSection(2)),
              child: Column(
                children: [
                  TextFormField(
                    controller: _titreCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      labelText: 'Intitulé du contrat de service *',
                      hintText: 'Ex. Contrat de maintenance annuelle, Couvaison lot B...',
                      prefixIcon: Icon(Icons.edit_note_rounded),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'L\'intitulé du contrat est obligatoire' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Description détaillée du contrat',
                      hintText: 'Précisez les clauses, besoins ou consignes particulières...',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),

            // 4. Champs spécifiques métier
            if (templateCourant.champs.isNotEmpty)
              CollapsibleFormSection(
                key: _formController.registerSectionKey(3),
                title: 'Détails techniques',
                icon: Icons.tune_rounded,
                summary: _techSummary(templateCourant),
                status: _techStatus,
                isExpanded: _formController.isSectionOpen(3),
                onToggle: () => setState(() => _formController.toggleSection(3)),
                child: Column(
                  children: [
                    for (final champ in templateCourant.champs) ...[
                      if (champ.options.isNotEmpty)
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: champ.options.contains(_champsMetier[champ.cle]) ? _champsMetier[champ.cle] as String : null,
                          decoration: InputDecoration(
                            labelText: champ.libelle,
                            hintText: champ.hint,
                            prefixIcon: const Icon(Icons.tune_rounded),
                          ),
                          items: [
                            for (final opt in champ.options) DropdownMenuItem(value: opt, child: Text(opt)),
                          ],
                          validator: champ.requis ? (val) => val == null || val.isEmpty ? 'Ce champ est requis' : null : null,
                          onChanged: (val) {
                            setState(() {
                              _champsMetier[champ.cle] = val;
                              if (champ.cle == 'espece' && val != null) {
                                if (val.contains('17j')) _dureeCtrl.text = '17';
                                if (val.contains('21j')) _dureeCtrl.text = '21';
                                if (val.contains('28j')) _dureeCtrl.text = '28';
                                if (val.contains('30j')) _dureeCtrl.text = '30';
                                _recalculerEcheanceDepuisDuree();
                              }
                            });
                          },
                        )
                      else
                        TextFormField(
                          controller: _champsMetierCtrls[champ.cle] ??= TextEditingController(
                            text: _champsMetier[champ.cle]?.toString() ?? '',
                          ),
                          keyboardType: champ.type,
                          decoration: InputDecoration(
                            labelText: champ.libelle,
                            hintText: champ.hint,
                            prefixIcon: const Icon(Icons.info_outline_rounded),
                          ),
                          validator: (val) {
                            if (champ.requis && (val == null || val.trim().isEmpty)) {
                              return 'Ce champ est requis';
                            }
                            if (champ.type == TextInputType.number && val != null && val.trim().isNotEmpty) {
                              if (double.tryParse(val.trim()) == null) return 'Nombre invalide';
                            }
                            return null;
                          },
                          onChanged: (val) => _champsMetier[champ.cle] = val.trim(),
                        ),
                      if (champ != templateCourant.champs.last) const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),

            // 5. Photos
            CollapsibleFormSection(
              key: _formController.registerSectionKey(templateCourant.champs.isNotEmpty ? 4 : 3),
              title: 'Photos & Documents',
              icon: Icons.camera_alt_rounded,
              summary: _photos.isNotEmpty ? '${_photos.length} document(s)' : 'Facultatif',
              status: _photosStatus,
              isExpanded: _formController.isSectionOpen(templateCourant.champs.isNotEmpty ? 4 : 3),
              onToggle: () => setState(() => _formController.toggleSection(templateCourant.champs.isNotEmpty ? 4 : 3)),
              child: PrestationPhotosSection(
                photos: _photos,
                onPhotosChanged: (maj) => setState(() {
                  _photos
                    ..clear()
                    ..addAll(maj);
                }),
              ),
            ),

            // 6. Planification & Échéance
            CollapsibleFormSection(
              key: _formController.registerSectionKey(templateCourant.champs.isNotEmpty ? 5 : 4),
              title: 'Planification & Échéance',
              icon: Icons.calendar_today_rounded,
              summary: _planningSummary(context),
              status: _planningStatus,
              isRequired: true,
              isExpanded: _formController.isSectionOpen(templateCourant.champs.isNotEmpty ? 5 : 4),
              onToggle: () => setState(() => _formController.toggleSection(templateCourant.champs.isNotEmpty ? 5 : 4)),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _DateTimePickerButton(
                          icon: Icons.calendar_today_rounded,
                          label: 'Date de début',
                          value: _debutPrevu != null ? DateFormat('dd MMM yyyy').format(_debutPrevu!) : 'Aujourd\'hui',
                          onPressed: _choisirDateDebut,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateTimePickerButton(
                          icon: Icons.event_available_rounded,
                          label: 'Date d\'échéance',
                          value: _echeanceJour != null ? DateFormat('dd MMM yyyy').format(_echeanceJour!) : 'Choisir une date',
                          onPressed: _choisirDateEcheance,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: TextFormField(
                          controller: _dureeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Durée estimée',
                            prefixIcon: Icon(Icons.timer_outlined),
                          ),
                          onChanged: (_) => _recalculerEcheanceDepuisDuree(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 5,
                        child: DropdownButtonFormField<UniteDuree>(
                          isExpanded: true,
                          value: _uniteDuree,
                          decoration: const InputDecoration(labelText: 'Unité'),
                          items: [
                            for (final u in UniteDuree.values) DropdownMenuItem(value: u, child: Text(u.libelle)),
                          ],
                          onChanged: (u) {
                            if (u != null) {
                              setState(() {
                                _uniteDuree = u;
                                _recalculerEcheanceDepuisDuree();
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<PrioritePrestation>(
                    isExpanded: true,
                    value: _priorite,
                    decoration: const InputDecoration(
                      labelText: 'Niveau de priorité',
                      prefixIcon: Icon(Icons.flag_rounded),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: PrioritePrestation.normale,
                        child: Row(
                          children: [
                            Icon(Icons.circle, size: 10, color: AppColors.muted.withValues(alpha: 0.5)),
                            const SizedBox(width: 8),
                            const Text('Normale'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: PrioritePrestation.haute,
                        child: Row(
                          children: [
                            const Icon(Icons.circle, size: 10, color: AppColors.negative),
                            const SizedBox(width: 8),
                            const Text('Haute (Urgent)', style: TextStyle(color: AppColors.negative, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _priorite = v ?? PrioritePrestation.normale),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    isExpanded: true,
                    value: _responsableId,
                    decoration: const InputDecoration(
                      labelText: 'Responsable du suivi',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Non assigné')),
                      for (final m in membres) DropdownMenuItem(value: m.id, child: Text(m.nomAffiche)),
                    ],
                    onChanged: (v) => setState(() => _responsableId = v),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Livraison requise', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Le client souhaite être livré ou restitué à la fin', style: TextStyle(fontSize: 12)),
                    secondary: Icon(Icons.local_shipping_outlined, color: _livraisonRequise ? AppColors.primary : AppColors.muted),
                    value: _livraisonRequise,
                    onChanged: (v) => setState(() => _livraisonRequise = v),
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ),

            // 7. Lignes & chiffrage
            CollapsibleFormSection(
              key: _formController.registerSectionKey(templateCourant.champs.isNotEmpty ? 6 : 5),
              title: 'Prestations & Tarifs',
              icon: Icons.receipt_long_rounded,
              summary: _lignesSummary(context),
              status: _lignesStatus,
              isRequired: true,
              isExpanded: _formController.isSectionOpen(templateCourant.champs.isNotEmpty ? 6 : 5),
              onToggle: () => setState(() => _formController.toggleSection(templateCourant.champs.isNotEmpty ? 6 : 5)),
              child: Column(
                children: [
                  if (_lignes.isEmpty)
                    _EmptyStatePlaceholder(
                      icon: Icons.receipt_long_outlined,
                      message: 'Aucun service ajouté',
                      actionLabel: 'Ajouter une prestation',
                      onAction: () => _ajouterLigneModal(catalogue),
                    )
                  else ...[
                    ...List.generate(_lignes.length, (i) {
                      return _LignePrestationItem(
                        ligne: _lignes[i],
                        onSupprimer: () => setState(() => _lignes.removeAt(i)),
                      );
                    }),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _ajouterLigneModal(catalogue),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('Ajouter une ligne'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _remiseCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Remise commerciale (FCFA)',
                      prefixIcon: Icon(Icons.discount_outlined),
                      suffixIcon: Icon(Icons.money_off_rounded, size: 20),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),

            // 8. Lieu & notes
            CollapsibleFormSection(
              key: _formController.registerSectionKey(templateCourant.champs.isNotEmpty ? 7 : 6),
              title: 'Localisation & Notes',
              icon: Icons.location_on_rounded,
              summary: _lieuSummary(),
              status: _lieuStatus,
              isExpanded: _formController.isSectionOpen(templateCourant.champs.isNotEmpty ? 7 : 6),
              onToggle: () => setState(() => _formController.toggleSection(templateCourant.champs.isNotEmpty ? 7 : 6)),
              child: Column(
                children: [
                  TextFormField(
                    controller: _lieuCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Lieu d’exécution',
                      hintText: 'Atelier, site client...',
                      prefixIcon: Icon(Icons.location_on_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noteCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Observations internes',
                      hintText: 'Notes techniques réservées à l\'équipe...',
                      prefixIcon: Icon(Icons.note_rounded),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
    StickyFormActions(
      onSubmit: _enregistrer,
      onCancel: () => context.pop(),
      isLoading: _envoi,
      submitLabel: widget.prestationId != null ? 'Mettre à jour le contrat de service' : 'Enregistrer le contrat de service',
      summaryWidget: MediaQuery.sizeOf(context).width < AppBreakpoints.expanded && _lignes.isNotEmpty
          ? _PrestationSummary(
              sousTotal: _sousTotal,
              remise: _remise,
              total: _total,
            )
          : null,
    ),
  ],
),
    );
  }

  // Suppression de _buildRecapitulatif car remplacé par StickyFormActions

  // ─────────────────────────────────────────────
  //  ACTIONS
  // ─────────────────────────────────────────────
  Future<void> _ouvrirCreationContactRapide([String? nomInitial]) async {
    final nouveau = await DialogueNouveauContactDevis.afficher(
      context,
      nomInitial: nomInitial,
      relation: RelationContact.client,
    );
    if (!mounted || nouveau == null) return;
    setState(() => _contactId = nouveau.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Client « ${nouveau.nomAffiche} » créé et sélectionné'),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _ouvrirSelectionContact(List<Contact> contacts) async {
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ModalChoixContactDevis(
          contacts: contacts,
          contactActuelId: _contactId,
          onCreerRapide: (nom) async {
            Navigator.pop(ctx);
            await _ouvrirCreationContactRapide(nom);
          },
        ),
      ),
    );

    if (!mounted || result == null) return;
    if (result == 'AUCUN') {
      setState(() => _contactId = null);
    } else if (result is Contact) {
      setState(() => _contactId = result.id);
    }
  }

  Future<void> _choisirDateDebut() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _debutPrevu ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (d != null) {
      setState(() {
        _debutPrevu = d;
        if (_dureeCtrl.text.isNotEmpty) {
          _recalculerEcheanceDepuisDuree();
        } else if (_echeanceJour != null) {
          _recalculerDureeDepuisEcheance();
        }
      });
    }
  }

  Future<void> _choisirDateEcheance() async {
    final debut = _debutPrevu ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _echeanceJour ?? debut.add(const Duration(days: 7)),
      firstDate: debut,
      lastDate: DateTime(2040),
    );
    if (d != null) {
      setState(() {
        _echeanceJour = d;
        _recalculerDureeDepuisEcheance();
      });
    }
  }

  Future<void> _ajouterLigneModal(List<ServiceCatalogue> catalogue) async {
    final libelleCtrl = TextEditingController();
    final prixCtrl = TextEditingController();
    final qteCtrl = TextEditingController(text: '1');
    ServiceCatalogue? selectionne;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Ajouter une ligne',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (catalogue.isNotEmpty) ...[
                    DropdownButtonFormField<ServiceCatalogue?>(
                      value: selectionne,
                      decoration: const InputDecoration(labelText: 'Depuis le catalogue'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Prestation personnalisée'),
                        ),
                        for (final s in catalogue)
                          DropdownMenuItem(
                            value: s,
                            child: Text(
                              '${s.nom} (${montant(context, ref, s.prix)} / ${s.unite.libelle})',
                            ),
                          ),
                      ],
                      onChanged: (s) {
                        setModalState(() {
                          selectionne = s;
                          if (s != null) {
                            libelleCtrl.text = s.nom;
                            prixCtrl.text = s.prix.toString();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: libelleCtrl,
                    decoration: const InputDecoration(labelText: 'Intitulé de la ligne *'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: qteCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Quantité'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: prixCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Prix unitaire (FCFA)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: () {
                      if (libelleCtrl.text.trim().isEmpty) return;
                      final qte = double.tryParse(qteCtrl.text.trim().replaceAll(',', '.')) ?? 1.0;
                      final prix = int.tryParse(prixCtrl.text.trim()) ?? 0;
                      setState(() {
                        _lignes.add(LignePrestation(
                          id: const Uuid().v4(),
                          serviceId: selectionne?.id,
                          libelle: libelleCtrl.text.trim(),
                          quantite: qte,
                          prixUnitaire: prix,
                        ));
                      });
                      Navigator.of(modalCtx).pop();
                    },
                    child: const Text('Valider la ligne'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _enregistrer() async {
    if (_envoi) return;
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      // On tente de scroller vers la première section en erreur
      if (_clientStatus == FormSectionStatus.emptyRequired) {
        _formController.scrollToSection(1);
      } else if (_infosStatus == FormSectionStatus.emptyRequired) {
        _formController.scrollToSection(2);
      } else if (_planningStatus == FormSectionStatus.emptyRequired) {
        _formController.scrollToSection(_metierSelectionne == MetierCode.generique ? 4 : 5);
      } else if (_lignesStatus == FormSectionStatus.emptyRequired) {
        _formController.scrollToSection(_metierSelectionne == MetierCode.generique ? 5 : 6);
      }
      return;
    }

    if (_lignes.isEmpty) {
      if (_titreCtrl.text.trim().isNotEmpty) {
        _lignes.add(LignePrestation(
          id: const Uuid().v4(),
          libelle: _titreCtrl.text.trim(),
          quantite: 1.0,
          prixUnitaire: 0,
        ));
      } else {
        showFailureSnackBar(context, 'Veuillez renseigner un titre ou ajouter au moins une ligne.');
        _formController.scrollToSection(2);
        return;
      }
    }

    final ctx = ref.read(contexteActifProvider);
    final espace = ref.read(espaceCourantProvider);
    final entrepriseId = ctx?.entreprise?.id;
    if (entrepriseId == null) return;

    // Collecter les valeurs des champs métiers depuis les contrôleurs
    final template = MetierTemplate.templatePour(_metierSelectionne);
    for (final champ in template.champs) {
      if (champ.options.isEmpty) {
        final ctrl = _champsMetierCtrls[champ.cle];
        if (ctrl != null) {
          _champsMetier[champ.cle] = ctrl.text.trim();
        }
      }
    }

    setState(() => _envoi = true);
    try {
      final gerer = ref.read(gererServicesProvider);
      final dureeEstimee = int.tryParse(_dureeCtrl.text.trim());

      _champsMetier['type_dossier'] = 'CONTRAT';

      if (widget.prestationId != null) {
        final existante = await ref.read(servicesRepositoryProvider).getPrestation(widget.prestationId!);
        if (existante != null) {
          await gerer.modifierPrestation(
            existante.copyWith(
              metierCode: _metierSelectionne,
              champsMetier: _champsMetier,
              contactId: _contactId,
              responsableId: _responsableId,
              titre: _titreCtrl.text.trim(),
              description: _descCtrl.text.trim(),
              lignes: _lignes,
              remise: _remise,
              priorite: _priorite,
              debutPrevu: _debutPrevu,
              echeanceJour: _echeanceJour,
              echeanceHeure: null,
              dureeEstimee: dureeEstimee,
              uniteDuree: _uniteDuree,
              dateRemisePrevue: _dateRemisePrevue,
              livraisonRequise: _livraisonRequise,
              lieu: _lieuCtrl.text.trim(),
              note: _noteCtrl.text.trim(),
              photos: _photos,
            ),
          );
        }
      } else {
        final nouv = await gerer.creerPrestation(
          entrepriseId: entrepriseId,
          perimetreId: espace.perimetreId,
          contactId: _contactId,
          responsableId: _responsableId,
          titre: _titreCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          lignes: _lignes,
          remise: _remise,
          priorite: _priorite,
          debutPrevu: _debutPrevu,
          echeanceJour: _echeanceJour,
          echeanceHeure: null,
          livraisonRequise: _livraisonRequise,
          lieu: _lieuCtrl.text.trim(),
          note: _noteCtrl.text.trim(),
          photos: _photos,
          champsMetier: _champsMetier,
          metierCode: _metierSelectionne,
        );

        if (dureeEstimee != null || _uniteDuree != UniteDuree.jours) {
          final pMaj = nouv.copyWith(
            dureeEstimee: dureeEstimee,
            uniteDuree: _uniteDuree,
          );
          await gerer.modifierPrestation(pMaj);
        }

        // Création de l'engagement financier associé pour traçabilité du CA
        if (_total > 0) {
          final engagement = fin.Engagement(
            id: nouv.id,
            entrepriseId: entrepriseId,
            activite: ActiviteCode.services,
            perimetreId: espace.perimetreId,
            sens: fin.SensEngagement.aRecevoir,
            contactId: _contactId,
            libelle: 'Contrat - ${_titreCtrl.text.trim()}',
            montantTotal: _total,
            dateEngagement: _debutPrevu ?? DateTime.now(),
            echeance: _echeanceJour,
            origineType: 'CONTRAT_SERVICE',
          );
          await ref.read(financesRepositoryProvider).creerEngagement(engagement);
          ref.invalidate(etatFinancesProvider);
        }
      }

      if (mounted) {
        ref.invalidate(prestationsProvider);
        showMessageSnackBar(
          context,
          widget.prestationId != null
              ? 'Contrat de service modifié avec succès'
              : 'Contrat de service enregistré avec succès',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }
}

// ─────────────────────────────────────────────
//  WIDGETS COMPOSANTS MODERNES
// ─────────────────────────────────────────────

class _DateTimePickerButton extends StatelessWidget {
  const _DateTimePickerButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(icon, size: 16, color: AppColors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStatePlaceholder extends StatelessWidget {
  const _EmptyStatePlaceholder({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.greenSoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: AppColors.green.withValues(alpha: 0.05), blurRadius: 10)
              ],
            ),
            child: Icon(icon, size: 32, color: AppColors.green.withValues(alpha: 0.3)),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(actionLabel),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrestationSummary extends ConsumerWidget {
  const _PrestationSummary({
    required this.sousTotal,
    required this.remise,
    required this.total,
  });

  final int sousTotal;
  final int remise;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _SummaryRow(label: 'Sous-total', value: sousTotal),
          if (remise > 0) ...[
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'Remise',
              value: -remise,
              color: AppColors.negative,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, thickness: 0.5),
          ),
          _SummaryRow(
            label: 'Total à facturer',
            value: total,
            isBold: true,
            color: AppColors.primary,
            fontSize: 18,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends ConsumerWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.color,
    this.fontSize = 13,
  });

  final String label;
  final int value;
  final bool isBold;
  final Color? color;
  final double fontSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            color: isBold ? AppColors.ink : AppColors.muted,
          ),
        ),
        Text(
          montant(context, ref, value),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: color ?? AppColors.ink,
          ),
        ),
      ],
    );
  }
}

class _LignePrestationItem extends StatelessWidget {
  const _LignePrestationItem({
    required this.ligne,
    required this.onSupprimer,
  });

  final LignePrestation ligne;
  final VoidCallback onSupprimer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.settings_outlined, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ligne.libelle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${ligne.quantite} × ${ligne.prixUnitaire} FCFA',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${ligne.totalLigne} FCFA',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onSupprimer,
                child: const Text(
                  'Supprimer',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.negative,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
