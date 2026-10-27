import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/forms/forms.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../contacts/presentation/widgets/contact_avatar.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/bien_immobilier.dart';
import '../providers/immobilier_providers.dart';
import '../widgets/immobilier_widgets.dart';

class BienFormPage extends ConsumerStatefulWidget {
  const BienFormPage({super.key, this.bienId});
  final String? bienId;

  @override
  ConsumerState<BienFormPage> createState() => _BienFormPageState();
}

class _BienFormPageState extends ConsumerState<BienFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _formController = SmartFormController(allowMultipleOpen: true);

  late TextEditingController _nomController;
  late TextEditingController _referenceController;
  late TextEditingController _descriptionController;
  late TextEditingController _loyerController;
  late TextEditingController _depotController;
  late TextEditingController _adresseController;
  late TextEditingController _villeController;
  late TextEditingController _quartierController;
  late TextEditingController _complementController;
  late TextEditingController _surfaceController;
  late TextEditingController _piecesController;
  late TextEditingController _chambresController;
  late TextEditingController _sdbController;
  late TextEditingController _etageController;
  late TextEditingController _notesController;

  TypeBien _type = TypeBien.appartement;
  StatutBien _statut = StatutBien.disponible;
  PeriodiciteLoyer _periodicite = PeriodiciteLoyer.mensuelle;
  Contact? _proprietaire;

  bool _meuble = false;
  bool _clim = false;
  bool _parking = false;
  bool _eauIndep = true;
  bool _elecIndep = true;

  bool _chargementInitial = true;
  bool _enregistrementEnCours = false;

  @override
  void initState() {
    super.initState();
    _formController.openAll(6);
    _nomController = TextEditingController();
    _referenceController = TextEditingController();
    _descriptionController = TextEditingController();
    _loyerController = TextEditingController();
    _depotController = TextEditingController();
    _adresseController = TextEditingController();
    _villeController = TextEditingController();
    _quartierController = TextEditingController();
    _complementController = TextEditingController();
    _surfaceController = TextEditingController();
    _piecesController = TextEditingController();
    _chambresController = TextEditingController();
    _sdbController = TextEditingController();
    _etageController = TextEditingController();
    _notesController = TextEditingController();

    if (widget.bienId == null) {
      _chargementInitial = false;
      final random = DateTime.now().millisecondsSinceEpoch % 10000;
      _referenceController.text = 'BIEN-${random.toString().padLeft(4, '0')}';
    } else {
      _chargementInitial = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _chargerBienExistant();
      });
    }
  }

  Future<void> _chargerBienExistant() async {
    try {
      final bien = await ref.read(immobilierRepositoryProvider).getBien(widget.bienId!);
      if (bien != null && mounted) {
        setState(() {
          _nomController.text = bien.nom;
          _referenceController.text = bien.reference;
          _descriptionController.text = bien.description ?? '';
          _loyerController.text = bien.loyerReference > 0 ? bien.loyerReference.toString() : '';
          _depotController.text = bien.depotGarantiePrevu > 0 ? bien.depotGarantiePrevu.toString() : '';
          _adresseController.text = bien.adresse ?? '';
          _villeController.text = bien.ville ?? '';
          _quartierController.text = bien.quartier ?? '';
          _complementController.text = bien.complementAdresse ?? '';

          final carac = bien.caracteristiques;
          _surfaceController.text = carac.surfaceM2 != null ? carac.surfaceM2.toString() : '';
          _piecesController.text = carac.nbPieces != null ? carac.nbPieces.toString() : '';
          _chambresController.text = carac.nbChambres != null ? carac.nbChambres.toString() : '';
          _sdbController.text = carac.nbSallesDeBain != null ? carac.nbSallesDeBain.toString() : '';
          _etageController.text = carac.etage != null ? carac.etage.toString() : '';

          _meuble = carac.meuble;
          _clim = carac.climatisation;
          _parking = carac.parking;
          _eauIndep = carac.compteurEauIndependant;
          _elecIndep = carac.compteurElectriciteIndependant;

          _notesController.text = bien.notes ?? '';
          _type = bien.type;
          _statut = bien.statut;
          _periodicite = bien.periodicite;
        });

        final prop = await ref.read(contactProvider(bien.proprietaireId).future);
        if (mounted && prop != null) {
          setState(() => _proprietaire = prop);
        }
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement du bien: $e');
    } finally {
      if (mounted) {
        setState(() => _chargementInitial = false);
      }
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _referenceController.dispose();
    _descriptionController.dispose();
    _loyerController.dispose();
    _depotController.dispose();
    _adresseController.dispose();
    _villeController.dispose();
    _quartierController.dispose();
    _complementController.dispose();
    _surfaceController.dispose();
    _piecesController.dispose();
    _chambresController.dispose();
    _sdbController.dispose();
    _etageController.dispose();
    _notesController.dispose();
    _formController.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      if (_nomController.text.isEmpty || _referenceController.text.isEmpty) {
        _formController.scrollToSection(0);
      } else if (_proprietaire == null) {
        _formController.scrollToSection(1);
      } else if (_loyerController.text.isEmpty) {
        _formController.scrollToSection(2);
      }
      return;
    }

    if (_proprietaire == null) {
      HapticFeedback.heavyImpact();
      _formController.scrollToSection(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner le propriétaire du bien.'),
          backgroundColor: AppColors.negative,
        ),
      );
      return;
    }

    setState(() => _enregistrementEnCours = true);

    try {
      final ctx = ref.read(contexteActifProvider);
      final entrepriseId = ctx!.entreprise!.id;

      final carac = CaracteristiquesBien(
        surfaceM2: double.tryParse(_surfaceController.text.trim()),
        nbPieces: int.tryParse(_piecesController.text.trim()),
        nbChambres: int.tryParse(_chambresController.text.trim()),
        nbSallesDeBain: int.tryParse(_sdbController.text.trim()),
        etage: int.tryParse(_etageController.text.trim()),
        meuble: _meuble,
        climatisation: _clim,
        parking: _parking,
        compteurEauIndependant: _eauIndep,
        compteurElectriciteIndependant: _elecIndep,
      );

      final bien = BienImmobilier(
        id: widget.bienId ?? const Uuid().v4(),
        entrepriseId: entrepriseId,
        reference: _referenceController.text.trim(),
        nom: _nomController.text.trim(),
        type: _type,
        statut: _statut,
        proprietaireId: _proprietaire!.id,
        loyerReference: int.tryParse(_loyerController.text.replaceAll(' ', '')) ?? 0,
        periodicite: _periodicite,
        depotGarantiePrevu: int.tryParse(_depotController.text.replaceAll(' ', '')) ?? 0,
        description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
        adresse: _adresseController.text.trim().isNotEmpty ? _adresseController.text.trim() : null,
        ville: _villeController.text.trim().isNotEmpty ? _villeController.text.trim() : null,
        quartier: _quartierController.text.trim().isNotEmpty ? _quartierController.text.trim() : null,
        complementAdresse: _complementController.text.trim().isNotEmpty ? _complementController.text.trim() : null,
        caracteristiques: carac,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        creeLe: DateTime.now(),
        misAJourLe: DateTime.now(),
      );

      await ref.read(immobilierRepositoryProvider).sauvegarderBien(bien);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.bienId == null ? 'Bien enregistré avec succès' : 'Bien mis à jour avec succès'),
            backgroundColor: AppColors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.negative),
        );
      }
    } finally {
      if (mounted) setState(() => _enregistrementEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estEdition = widget.bienId != null;

    if (estEdition && _chargementInitial) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chargement...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(estEdition ? 'Modifier le bien' : 'Nouveau bien'),
        actions: [
          if (!_enregistrementEnCours)
            IconButton(
              icon: const Icon(Icons.check_rounded),
              onPressed: _enregistrer,
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: SmartFormContainer(
                controller: _formController,
                children: [
            // 1. Désignation
            CollapsibleFormSection(
              key: _formController.registerSectionKey(0),
              title: '1. Désignation & Type',
              icon: Icons.home_work_outlined,
              isExpanded: _formController.isSectionOpen(0),
              onToggle: () => setState(() => _formController.toggleSection(0)),
              isRequired: true,
              summary: _nomController.text.isNotEmpty ? '${_nomController.text} (${_type.libelle})' : null,
              status: _nomController.text.isNotEmpty ? FormSectionStatus.complete : FormSectionStatus.emptyRequired,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nomController,
                    decoration: const InputDecoration(labelText: 'Nom ou Désignation du bien *', hintText: 'Ex: Appartement 2B'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Le nom est requis' : null,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _referenceController,
                          decoration: const InputDecoration(labelText: 'Référence unique *'),
                          validator: (v) => v == null || v.trim().isEmpty ? 'La référence est requise' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<StatutBien>(
                          value: _statut,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Statut'),
                          items: [
                            for (final s in StatutBien.values)
                              DropdownMenuItem(
                                value: s,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(s.icone, size: 16, color: s.couleur),
                                    const SizedBox(width: 6),
                                    Text(s.libelle, style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() => _statut = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<TypeBien>(
                    value: _type,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Type de bien'),
                    items: [
                      for (final t in TypeBien.values)
                        DropdownMenuItem(
                          value: t,
                          child: Row(
                            children: [
                              Icon(t.icone, size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(t.libelle),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description (facultative)'),
                  ),
                ],
              ),
            ),

            // 2. Propriétaire
            CollapsibleFormSection(
              key: _formController.registerSectionKey(1),
              title: '2. Propriétaire du bien *',
              icon: Icons.badge_outlined,
              isExpanded: _formController.isSectionOpen(1),
              onToggle: () => setState(() => _formController.toggleSection(1)),
              isRequired: true,
              summary: _proprietaire?.nomAffiche,
              status: _proprietaire != null ? FormSectionStatus.complete : FormSectionStatus.emptyRequired,
              child: Column(
                children: [
                  if (_proprietaire != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          ContactAvatar(contact: _proprietaire!, radius: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_proprietaire!.nomAffiche, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(_proprietaire!.telephone ?? 'Propriétaire sélectionné', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final choisi = await choisirProprietaire(context);
                              if (choisi != null) setState(() => _proprietaire = choisi);
                            },
                            child: const Text('Changer'),
                          ),
                        ],
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      icon: const Icon(Icons.person_search_outlined),
                      label: const Text('Sélectionner ou Créer le propriétaire'),
                      onPressed: () async {
                        final choisi = await choisirProprietaire(context);
                        if (choisi != null) setState(() => _proprietaire = choisi);
                      },
                    ),
                ],
              ),
            ),

            // 3. Finances
            CollapsibleFormSection(
              key: _formController.registerSectionKey(2),
              title: '3. Conditions Financières Indicatives',
              icon: Icons.account_balance_wallet_outlined,
              isExpanded: _formController.isSectionOpen(2),
              onToggle: () => setState(() => _formController.toggleSection(2)),
              isRequired: true,
              summary: _loyerController.text.isNotEmpty ? '${_loyerController.text} FCFA / ${_periodicite.libelle}' : null,
              status: _loyerController.text.isNotEmpty ? FormSectionStatus.complete : FormSectionStatus.emptyRequired,
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _loyerController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Loyer *', suffixText: 'FCFA'),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<PeriodiciteLoyer>(
                          value: _periodicite,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Période'),
                          items: [
                            for (final p in PeriodiciteLoyer.values)
                              DropdownMenuItem(value: p, child: Text(p.libelle, style: const TextStyle(fontSize: 13))),
                          ],
                          onChanged: (v) => setState(() => _periodicite = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _depotController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Caution prévue', suffixText: 'FCFA'),
                  ),
                ],
              ),
            ),

            // 4. Localisation
            CollapsibleFormSection(
              key: _formController.registerSectionKey(3),
              title: '4. Localisation & Adresse',
              icon: Icons.location_on_outlined,
              isExpanded: _formController.isSectionOpen(3),
              onToggle: () => setState(() => _formController.toggleSection(3)),
              summary: _villeController.text.isNotEmpty ? '${_villeController.text} ${_quartierController.text}' : null,
              status: _villeController.text.isNotEmpty ? FormSectionStatus.complete : FormSectionStatus.emptyOptional,
              child: Column(
                children: [
                  TextFormField(
                    controller: _adresseController,
                    decoration: const InputDecoration(labelText: 'Adresse / Rue'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: _villeController, decoration: const InputDecoration(labelText: 'Ville'), onChanged: (_) => setState(() {}))),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(controller: _quartierController, decoration: const InputDecoration(labelText: 'Quartier'), onChanged: (_) => setState(() {}))),
                    ],
                  ),
                ],
              ),
            ),

            // 5. Caractéristiques
            CollapsibleFormSection(
              key: _formController.registerSectionKey(4),
              title: '5. Caractéristiques du Bien',
              icon: _type == TypeBien.terrain ? Icons.landscape_outlined : Icons.tune_rounded,
              isExpanded: _formController.isSectionOpen(4),
              onToggle: () => setState(() => _formController.toggleSection(4)),
              status: _surfaceController.text.isNotEmpty ? FormSectionStatus.complete : FormSectionStatus.emptyOptional,
              child: Column(
                children: [
                  TextFormField(
                    controller: _surfaceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Surface (m²)'),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_type != TypeBien.terrain) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: _piecesController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pièces'))),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(controller: _chambresController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Chambres'))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: _sdbController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'SDB'))),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(controller: _etageController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Étage'))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        FilterChip(label: const Text('Meublé'), selected: _meuble, onSelected: (v) => setState(() => _meuble = v)),
                        FilterChip(label: const Text('Clim'), selected: _clim, onSelected: (v) => setState(() => _clim = v)),
                        FilterChip(label: const Text('Parking'), selected: _parking, onSelected: (v) => setState(() => _parking = v)),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // 6. Notes
            CollapsibleFormSection(
              key: _formController.registerSectionKey(5),
              title: '6. Notes & Remarques Internes',
              icon: Icons.notes_outlined,
              isExpanded: _formController.isSectionOpen(5),
              onToggle: () => setState(() => _formController.toggleSection(5)),
              summary: _notesController.text.isNotEmpty ? 'Notes présentes' : null,
              status: _notesController.text.isNotEmpty ? FormSectionStatus.complete : FormSectionStatus.emptyOptional,
              child: TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Observations réservées à l\'agence'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
    StickyFormActions(
      onSubmit: _enregistrementEnCours ? null : _enregistrer,
      onCancel: () => Navigator.of(context).maybePop(),
      isLoading: _enregistrementEnCours,
      submitLabel: estEdition ? 'Mettre à jour le bien' : 'Enregistrer le bien',
    ),
  ],
),
    );
  }
}
