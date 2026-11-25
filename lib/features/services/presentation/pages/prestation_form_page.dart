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

  final _descCtrl = TextEditingController();
  final _lieuCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _remiseCtrl = TextEditingController(text: '0');
  final _dureeCtrl = TextEditingController();

  String? _contactId;
  String? _titreExistant;
  String? _responsableIdExistant;
  MetierCode _metierSelectionne = MetierCode.generique;
  UniteDuree _uniteDuree = UniteDuree.jours;
  final Map<String, dynamic> _champsMetier = {};

  PrioritePrestation _prioriteExistante = PrioritePrestation.normale;
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
    _formController.openSection(3);
    _formController.openSection(4);
  }

  @override
  void dispose() {
    _formController.dispose();
    _descCtrl.dispose();
    _lieuCtrl.dispose();
    _noteCtrl.dispose();
    _remiseCtrl.dispose();
    _dureeCtrl.dispose();
    super.dispose();
  }

  int get _sousTotal => _lignes.fold<int>(0, (sum, l) => sum + l.totalLigne);
  int get _remise => int.tryParse(_remiseCtrl.text.trim()) ?? 0;
  int get _total => (_sousTotal - _remise).clamp(0, 1000000000000);

  // --- Statuts et Résumés dynamiques des sections ---

  FormSectionStatus get _clientStatus => _contactId != null ? FormSectionStatus.complete : FormSectionStatus.emptyRequired;
  String _clientSummary(List<Contact> contacts) {
    final c = contacts.where((c) => c.id == _contactId).firstOrNull;
    return c?.nom ?? 'Aucun client sélectionné';
  }

  FormSectionStatus get _descStatus =>
      _descCtrl.text.trim().isNotEmpty ? FormSectionStatus.complete : FormSectionStatus.emptyOptional;
  String _descSummary() {
    final t = _descCtrl.text.trim();
    if (t.isEmpty) return 'Facultatif';
    final premiereLigne = t.split('\n').first.trim();
    return premiereLigne.length > 42 ? '${premiereLigne.substring(0, 39)}...' : premiereLigne;
  }

  FormSectionStatus get _photosStatus => _photos.isNotEmpty ? FormSectionStatus.complete : FormSectionStatus.emptyOptional;

  FormSectionStatus get _planningStatus => _echeanceJour != null ? FormSectionStatus.complete : FormSectionStatus.emptyRequired;
  String _planningSummary(BuildContext context) {
    if (_echeanceJour == null) return 'Dates du contrat requises';
    final debutStr = _debutPrevu != null ? DateFormat('dd/MM/yyyy').format(_debutPrevu!) : 'Immédiat';
    final finStr = DateFormat('dd/MM/yyyy').format(_echeanceJour!);
    final dureeStr = _dureeCtrl.text.isNotEmpty ? ' (${_dureeCtrl.text} ${_uniteDuree.libelle.toLowerCase()})' : '';
    return '$debutStr → $finStr$dureeStr';
  }

  FormSectionStatus get _lignesStatus => _lignes.isNotEmpty ? FormSectionStatus.complete : FormSectionStatus.emptyRequired;
  String _lignesSummary(BuildContext context) {
    if (_lignes.isEmpty) return 'Aucun service ajouté (Requis)';
    return '${_lignes.length} article(s) • ${montant(context, ref, _total)}';
  }

  FormSectionStatus get _lieuStatus => _lieuCtrl.text.trim().isNotEmpty ? FormSectionStatus.complete : FormSectionStatus.emptyOptional;
  String _lieuSummary() => _lieuCtrl.text.trim().isEmpty ? 'Lieu non précisé' : _lieuCtrl.text.trim();

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
      _titreExistant = p.titre;
      _descCtrl.text = (p.description != null && p.description!.trim().isNotEmpty) ? p.description! : p.titre;
      _lieuCtrl.text = p.lieu ?? '';
      _noteCtrl.text = p.note ?? '';
      _remiseCtrl.text = p.remise.toString();
      _contactId = p.contactId;
      _prioriteExistante = p.priorite;
      _debutPrevu = p.debutPrevu;
      _echeanceJour = p.echeanceJour;

      _dureeCtrl.text = p.dureeEstimee?.toString() ?? '';
      _uniteDuree = p.uniteDuree;
      _dateRemisePrevue = p.dateRemisePrevue;
      _livraisonRequise = p.livraisonRequise;
      _responsableIdExistant = p.responsableId;

      _lignes
        ..clear()
        ..addAll(p.lignes);
      _photos
        ..clear()
        ..addAll(p.photos);
      _champsMetier
        ..clear()
        ..addAll(p.champsMetier);

      _formController.openSection(0);
      _formController.openSection(1);
      _formController.openSection(3);
      _formController.openSection(4);
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalogueAsync = ref.watch(servicesCatalogueProvider);
    final contacts = ref.watch(contactsProvider).value ?? const <Contact>[];

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
          return _construireFormulaire(context, catalogueAsync.value ?? const [], contacts);
        }(),
      };
    }

    return _construireFormulaire(context, catalogueAsync.value ?? const [], contacts);
  }

  // ─────────────────────────────────────────────
  //  FORMULAIRE PRINCIPAL SIMPLIFIÉ
  // ─────────────────────────────────────────────
  Widget _construireFormulaire(
    BuildContext context,
    List<ServiceCatalogue> catalogue,
    List<Contact> contacts,
  ) {
    final selectedContact = contacts.cast<Contact?>().firstWhere(
      (c) => c?.id == _contactId,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.prestationId != null ? 'Modifier le contrat de service' : 'Nouveau contrat de service'),
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
                  // 0. Client
                  CollapsibleFormSection(
                    key: _formController.registerSectionKey(0),
                    title: 'Client',
                    icon: Icons.person_rounded,
                    summary: _clientSummary(contacts),
                    status: _clientStatus,
                    isRequired: true,
                    isExpanded: _formController.isSectionOpen(0),
                    onToggle: () => setState(() => _formController.toggleSection(0)),
                    child: SectionClientProspect(
                      selectedContact: selectedContact,
                      onChoisir: () => _ouvrirSelectionContact(contacts),
                      onCreerNouveau: () => _ouvrirCreationContactRapide(),
                      onRetirer: () => setState(() => _contactId = null),
                    ),
                  ),

                  // 1. Description détaillée du contrat
                  CollapsibleFormSection(
                    key: _formController.registerSectionKey(1),
                    title: 'Description du contrat',
                    icon: Icons.edit_note_rounded,
                    summary: _descSummary(),
                    status: _descStatus,
                    isExpanded: _formController.isSectionOpen(1),
                    onToggle: () => setState(() => _formController.toggleSection(1)),
                    child: TextFormField(
                      controller: _descCtrl,
                      minLines: 3,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Description détaillée du contrat',
                        hintText: 'Précisez les travaux, clauses, besoins ou consignes particulières...',
                        alignLabelWithHint: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),

                  // 2. Photos & Documents
                  CollapsibleFormSection(
                    key: _formController.registerSectionKey(2),
                    title: 'Photos & Documents',
                    icon: Icons.camera_alt_rounded,
                    summary: _photos.isNotEmpty ? '${_photos.length} photo(s)' : 'Facultatif',
                    status: _photosStatus,
                    isExpanded: _formController.isSectionOpen(2),
                    onToggle: () => setState(() => _formController.toggleSection(2)),
                    child: PrestationPhotosSection(
                      photos: _photos,
                      onPhotosChanged: (maj) => setState(() {
                        _photos
                          ..clear()
                          ..addAll(maj);
                      }),
                    ),
                  ),

            // 3. Planification & Échéance (simplifiée)
            CollapsibleFormSection(
              key: _formController.registerSectionKey(3),
              title: 'Planification & Échéance',
              icon: Icons.calendar_today_rounded,
              summary: _planningSummary(context),
              status: _planningStatus,
              isRequired: true,
              isExpanded: _formController.isSectionOpen(3),
              onToggle: () => setState(() => _formController.toggleSection(3)),
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
                  const SizedBox(height: 12),
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

            // 4. Lignes & chiffrage
            CollapsibleFormSection(
              key: _formController.registerSectionKey(4),
              title: 'Prestations & Tarifs',
              icon: Icons.receipt_long_rounded,
              summary: _lignesSummary(context),
              status: _lignesStatus,
              isRequired: true,
              isExpanded: _formController.isSectionOpen(4),
              onToggle: () => setState(() => _formController.toggleSection(4)),
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

            // 5. Lieu & notes
            CollapsibleFormSection(
              key: _formController.registerSectionKey(5),
              title: 'Localisation & Notes',
              icon: Icons.location_on_rounded,
              summary: _lieuSummary(),
              status: _lieuStatus,
              isExpanded: _formController.isSectionOpen(5),
              onToggle: () => setState(() => _formController.toggleSection(5)),
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
      useRootNavigator: true,
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
      useRootNavigator: true,
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
      if (_clientStatus == FormSectionStatus.emptyRequired) {
        _formController.scrollToSection(0);
      } else if (_planningStatus == FormSectionStatus.emptyRequired) {
        _formController.scrollToSection(3);
      } else if (_lignesStatus == FormSectionStatus.emptyRequired) {
        _formController.scrollToSection(4);
      }
      return;
    }

    // Dérivation automatique et fiable du libellé principal (sans champ intitulé séparé)
    final descTexte = _descCtrl.text.trim();
    final premiereLigneDesc = descTexte.isNotEmpty ? descTexte.split('\n').first.trim() : '';
    final String titreFinal;
    if (premiereLigneDesc.isNotEmpty) {
      titreFinal = premiereLigneDesc.length > 60 ? '${premiereLigneDesc.substring(0, 57)}...' : premiereLigneDesc;
    } else if (_lignes.isNotEmpty) {
      titreFinal = _lignes.first.libelle;
    } else if (_titreExistant != null && _titreExistant!.trim().isNotEmpty) {
      titreFinal = _titreExistant!.trim();
    } else {
      titreFinal = 'Contrat de service';
    }

    if (_lignes.isEmpty) {
      if (descTexte.isNotEmpty) {
        _lignes.add(LignePrestation(
          id: const Uuid().v4(),
          libelle: titreFinal,
          quantite: 1.0,
          prixUnitaire: 0,
        ));
      } else {
        showFailureSnackBar(context, 'Veuillez ajouter au moins une prestation ou une description.');
        _formController.scrollToSection(4);
        return;
      }
    }

    final ctx = ref.read(contexteActifProvider);
    final espace = ref.read(espaceCourantProvider);
    final entrepriseId = ctx?.entreprise?.id;
    if (entrepriseId == null) return;

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
              responsableId: _responsableIdExistant,
              titre: titreFinal,
              description: descTexte,
              lignes: _lignes,
              remise: _remise,
              priorite: _prioriteExistante,
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
          responsableId: null,
          titre: titreFinal,
          description: descTexte,
          lignes: _lignes,
          remise: _remise,
          priorite: PrioritePrestation.normale,
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
          champsMetier: _champsMetier,
          metierCode: _metierSelectionne,
        );

        // Création de l'engagement financier local associé (origine PRESTATION conforme au schéma)
        if (_total > 0) {
          try {
            final engagement = fin.Engagement(
              id: nouv.id,
              entrepriseId: entrepriseId,
              activite: ActiviteCode.services,
              perimetreId: espace.perimetreId,
              sens: fin.SensEngagement.aRecevoir,
              contactId: _contactId,
              libelle: titreFinal,
              montantTotal: _total,
              dateEngagement: _debutPrevu ?? DateTime.now(),
              echeance: _echeanceJour,
              origineType: 'PRESTATION',
            );
            await ref.read(financesRepositoryProvider).creerEngagement(engagement);
            ref.invalidate(etatFinancesProvider);
          } catch (_) {
            // Déjà créé par le trigger serveur `tg_prestations_apres`
          }
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
