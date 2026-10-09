import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/service_catalogue.dart';
import '../services_providers.dart';

/// Formulaire d'ajout / modification d'un service type dans le catalogue.
class ServiceFormPage extends ConsumerStatefulWidget {
  const ServiceFormPage({super.key, this.serviceId});
  final String? serviceId;

  @override
  ConsumerState<ServiceFormPage> createState() => _ServiceFormPageState();
}

class _ServiceFormPageState extends ConsumerState<ServiceFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _catCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _prixCtrl = TextEditingController();
  final _dureeCtrl = TextEditingController();

  UniteFacturation _unite = UniteFacturation.forfait;
  bool _chargementInitial = false;
  bool _envoi = false;

  static const _categoriesSuggestions = [
    'Coiffure',
    'Beauté',
    'Réparation',
    'Mécanique',
    'Couture',
    'Nettoyage',
    'Informatique',
    'Entretien',
    'Travaux',
  ];

  static const _dureesSuggestions = [
    (15, '15 min'),
    (30, '30 min'),
    (45, '45 min'),
    (60, '1 h'),
    (90, '1 h 30'),
    (120, '2 h'),
  ];

  @override
  void dispose() {
    _nomCtrl.dispose();
    _catCtrl.dispose();
    _descCtrl.dispose();
    _prixCtrl.dispose();
    _dureeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.serviceId != null && !_chargementInitial) {
      final catalogue = ref.watch(servicesCatalogueProvider).value ?? const <ServiceCatalogue>[];
      final service = catalogue.where((s) => s.id == widget.serviceId).firstOrNull;
      if (service != null) {
        _chargementInitial = true;
        _nomCtrl.text = service.nom;
        _catCtrl.text = service.categorie ?? '';
        _descCtrl.text = service.description ?? '';
        _prixCtrl.text = service.prix.toString();
        _dureeCtrl.text = service.dureeMinutes?.toString() ?? '';
        _unite = service.unite;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.serviceId != null ? 'Modifier le service' : 'Nouveau service'),
        actions: [
          if (widget.serviceId != null)
            IconButton(
              icon: const Icon(Icons.archive_outlined, color: AppColors.negative),
              tooltip: 'Archiver ce service',
              onPressed: _archiver,
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _envoi ? null : _enregistrer,
            child: _envoi
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Enregistrer le service'),
          ),
        ),
      ),
      body: ResponsiveBody(
        maxWidth: 640,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nomCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom du service *',
                  hintText: 'Ex. Coupe homme, Changement écran, Forfait vidange...',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Le nom est obligatoire' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _catCtrl,
                decoration: const InputDecoration(
                  labelText: 'Catégorie (optionnel)',
                  hintText: 'Ex. Coiffure, Réparation, Entretien...',
                ),
              ),
              const SizedBox(height: 8),

              // Suggestions rapides de catégorie
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final cat in _categoriesSuggestions)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(cat, style: const TextStyle(fontSize: 12)),
                          onPressed: () => setState(() => _catCtrl.text = cat),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _prixCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Tarif indicatif (FCFA) *',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Le tarif est requis' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<UniteFacturation>(
                      value: _unite,
                      decoration: const InputDecoration(labelText: 'Unité'),
                      items: [
                        for (final u in UniteFacturation.values)
                          DropdownMenuItem(value: u, child: Text(u.libelle)),
                      ],
                      onChanged: (u) => setState(() => _unite = u ?? UniteFacturation.forfait),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _dureeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Durée estimée (minutes)',
                  hintText: 'Ex. 30, 60, 120...',
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
              ),
              const SizedBox(height: 8),

              // Suggestions rapides de durée
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (mins, label) in _dureesSuggestions)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(label, style: const TextStyle(fontSize: 12)),
                          onPressed: () => setState(() => _dureeCtrl.text = mins.toString()),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description / Conditions',
                  hintText: 'Détails inclus dans ce service type...',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    final ctx = ref.read(contexteActifProvider);
    final entrepriseId = ctx?.entreprise?.id;
    if (entrepriseId == null) return;

    setState(() => _envoi = true);
    try {
      final gerer = ref.read(gererServicesProvider);
      final prix = int.tryParse(_prixCtrl.text.trim()) ?? 0;
      final duree = int.tryParse(_dureeCtrl.text.trim());

      if (widget.serviceId != null) {
        final service = ServiceCatalogue(
          id: widget.serviceId!,
          entrepriseId: entrepriseId,
          nom: _nomCtrl.text.trim(),
          categorie: _catCtrl.text.trim().isNotEmpty ? _catCtrl.text.trim() : null,
          description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
          prix: prix,
          unite: _unite,
          dureeMinutes: duree,
        );
        await gerer.modifierServiceCatalogue(service);
      } else {
        await gerer.ajouterAuCatalogue(
          entrepriseId: entrepriseId,
          nom: _nomCtrl.text.trim(),
          categorie: _catCtrl.text.trim().isNotEmpty ? _catCtrl.text.trim() : null,
          description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
          prix: prix,
          unite: _unite,
          dureeMinutes: duree,
        );
      }

      if (mounted) {
        ref.invalidate(servicesCatalogueProvider);
        context.pop();
      }
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _archiver() async {
    if (widget.serviceId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archiver ce service ?'),
        content: const Text('Ce service n\'apparaîtra plus dans les suggestions, mais vos anciennes prestations resteront inchangées.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(gererServicesProvider).archiverServiceCatalogue(widget.serviceId!);
      if (mounted) {
        ref.invalidate(servicesCatalogueProvider);
        context.pop();
      }
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    }
  }
}
