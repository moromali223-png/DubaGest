import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../entreprise/presentation/providers/espace_providers.dart';
import '../../../commerce/presentation/widgets/commerce_widgets.dart' show montant;
import '../../domain/entities/metier_template.dart';
import '../../domain/entities/prestation.dart';
import '../../domain/entities/service_catalogue.dart';
import '../services_providers.dart';
import '../widgets/prestation_photos_section.dart';

/// Formulaire de création / modification d'une prestation configurable multi-métiers.
class PrestationFormPage extends ConsumerStatefulWidget {
  const PrestationFormPage({super.key, this.prestationId, this.initialContactId, this.initialDate});
  final String? prestationId;
  final String? initialContactId;
  final String? initialDate;

  @override
  ConsumerState<PrestationFormPage> createState() => _PrestationFormPageState();
}

class _PrestationFormPageState extends ConsumerState<PrestationFormPage> {
  final _formKey = GlobalKey<FormState>();
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
  TimeOfDay? _echeanceHeure;
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
    if (widget.initialDate != null) {
      _echeanceJour = DateTime.tryParse(widget.initialDate!);
    }
  }

  @override
  void dispose() {
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

  void _changerModeleMetier(MetierCode code) {
    setState(() {
      _metierSelectionne = code;
      final template = MetierTemplate.templatePour(code);
      if (_titreCtrl.text.trim().isEmpty || _titreCtrl.text == MetierTemplate.templatePour(MetierCode.generique).titreParDefaut) {
        _titreCtrl.text = template.titreParDefaut;
      }
      _dureeCtrl.text = template.dureeParDefaut.toString();
      _uniteDuree = template.uniteParDefaut;
      _recalculerEcheanceDepuisDuree();

      // Init controllers for dynamic fields
      for (final f in template.champs) {
        if (!_champsMetierCtrls.containsKey(f.cle)) {
          _champsMetierCtrls[f.cle] = TextEditingController(text: _champsMetier[f.cle]?.toString() ?? '');
        }
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
      if (_uniteDuree == UniteDuree.heures) {
        _echeanceHeure = TimeOfDay(hour: calculee.hour, minute: calculee.minute);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalogueAsync = ref.watch(servicesCatalogueProvider);
    final contacts = ref.watch(contactsProvider).value ?? const <Contact>[];

    // Initialisation lors de la modification
    if (widget.prestationId != null && !_chargementInitial) {
      final pAsync = ref.watch(prestationDetailProvider(widget.prestationId!));
      pAsync.whenData((p) {
        if (p != null && !_chargementInitial) {
          _chargementInitial = true;
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
          if (p.echeanceHeure != null && p.echeanceHeure!.isNotEmpty) {
            final parts = p.echeanceHeure!.split(':');
            _echeanceHeure = TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0);
          }
          _dureeCtrl.text = p.dureeEstimee?.toString() ?? '';
          _uniteDuree = p.uniteDuree;
          _dateRemisePrevue = p.dateRemisePrevue;
          _livraisonRequise = p.livraisonRequise;
          _responsableId = p.responsableId;
          _lignes.clear();
          _lignes.addAll(p.lignes);
          _photos.clear();
          _photos.addAll(p.photos);
          _champsMetier.clear();
          _champsMetier.addAll(p.champsMetier);

          final template = MetierTemplate.templatePour(p.metierCode);
          for (final f in template.champs) {
            _champsMetierCtrls[f.cle] = TextEditingController(text: p.champsMetier[f.cle]?.toString() ?? '');
          }
          setState(() {});
        }
      });
    }

    final templateCourant = MetierTemplate.templatePour(_metierSelectionne);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.prestationId != null ? 'Modifier le dossier' : 'Nouveau dossier métier'),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total à facturer', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    Text(
                      montant(context, ref, _total),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF01226C)),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: _envoi ? null : _enregistrer,
                child: _envoi
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Enregistrer le dossier'),
              ),
            ],
          ),
        ),
      ),
      body: ResponsiveBody(
        maxWidth: 760,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Sélecteur de Modèle Métier
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.hub_outlined, size: 18, color: Color(0xFF01226C)),
                        SizedBox(width: 8),
                        Text('Modèle & Métier de la prestation *', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final m in MetierCode.values)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                avatar: Icon(m.icone, size: 16, color: _metierSelectionne == m ? Colors.white : const Color(0xFF01226C)),
                                label: Text(m.libelle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                selected: _metierSelectionne == m,
                                selectedColor: const Color(0xFF01226C),
                                labelStyle: TextStyle(color: _metierSelectionne == m ? Colors.white : AppColors.ink),
                                onSelected: (sel) {
                                  if (sel) _changerModeleMetier(m);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (templateCourant.instructions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '💡 ${templateCourant.instructions}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Informations Générales & Client
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _titreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Intitulé du dossier / Titre de la prestation *',
                        hintText: 'Ex. Lot incubation 200 œufs, Réparation iPhone...',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Le titre est obligatoire' : null,
                    ),
                    const SizedBox(height: 12),

                    // Client
                    DropdownButtonFormField<String?>(
                      value: contacts.any((c) => c.id == _contactId) ? _contactId : null,
                      decoration: InputDecoration(
                        labelText: 'Client concerné',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: 'Nouveau client',
                          icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
                          onPressed: () => context.push(Routes.contactNouveau(relation: RelationContact.client.code)),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Client comptoir (non enregistré)')),
                        for (final c in contacts)
                          DropdownMenuItem(value: c.id, child: Text('${c.nomAffiche} (${c.telephone ?? "Sans tel"})')),
                      ],
                      onChanged: (v) => setState(() => _contactId = v),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description / Remarques de la demande',
                        hintText: 'Précisions, consignes spécifiques, état au dépôt...',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Champs Spécifiques au Métier
              if (templateCourant.champs.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(templateCourant.code.icone, size: 18, color: const Color(0xFF01226C)),
                          const SizedBox(width: 8),
                          Text('Détails spécifiques — ${templateCourant.code.libelle}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      for (final champ in templateCourant.champs) ...[
                        if (champ.options.isNotEmpty)
                          DropdownButtonFormField<String>(
                            value: _champsMetier[champ.cle] as String?,
                            decoration: InputDecoration(labelText: champ.libelle, hintText: champ.hint),
                            items: [
                              for (final opt in champ.options)
                                DropdownMenuItem(value: opt, child: Text(opt)),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _champsMetier[champ.cle] = val;
                                if (champ.cle == 'espece' && val != null) {
                                  // Auto preset duration for incubation
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
                            controller: _champsMetierCtrls[champ.cle] ??= TextEditingController(text: _champsMetier[champ.cle]?.toString() ?? ''),
                            keyboardType: champ.type,
                            decoration: InputDecoration(labelText: champ.libelle, hintText: champ.hint),
                            onChanged: (val) => _champsMetier[champ.cle] = val.trim(),
                          ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              if (templateCourant.champs.isNotEmpty) const SizedBox(height: 16),

              // 4. Photographies du Dossier (Obligatoire / Recommandé)
              PrestationPhotosSection(
                photos: _photos,
                onPhotosChanged: (maj) => setState(() {
                  _photos.clear();
                  _photos.addAll(maj);
                }),
              ),
              const SizedBox(height: 16),

              // 5. Durée, Délais & Planification Précise
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.schedule_outlined, size: 18, color: Color(0xFF01226C)),
                        SizedBox(width: 8),
                        Text('Délais & Échéance d\'exécution', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: TextFormField(
                            controller: _dureeCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Durée estimée',
                              hintText: 'Ex. 21',
                              prefixIcon: Icon(Icons.timer_outlined),
                            ),
                            onChanged: (_) => _recalculerEcheanceDepuisDuree(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 5,
                          child: DropdownButtonFormField<UniteDuree>(
                            value: _uniteDuree,
                            decoration: const InputDecoration(labelText: 'Unité'),
                            items: [
                              for (final u in UniteDuree.values)
                                DropdownMenuItem(value: u, child: Text(u.libelle)),
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
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today_outlined, size: 18),
                            label: Text(_echeanceJour != null
                                ? 'Échéance : ${DateFormat('dd/MM/yyyy').format(_echeanceJour!)}'
                                : 'Choisir date d\'échéance'),
                            onPressed: _choisirDateEcheance,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time_rounded, size: 18),
                            label: Text(_echeanceHeure != null
                                ? '${_echeanceHeure!.hour.toString().padLeft(2, '0')}:${_echeanceHeure!.minute.toString().padLeft(2, '0')}'
                                : 'Heure'),
                            onPressed: _choisirHeureEcheance,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<PrioritePrestation>(
                            value: _priorite,
                            decoration: const InputDecoration(labelText: 'Priorité d\'intervention'),
                            items: const [
                              DropdownMenuItem(value: PrioritePrestation.normale, child: Text('Normale')),
                              DropdownMenuItem(value: PrioritePrestation.haute, child: Text('Haute (Urgent)')),
                            ],
                            onChanged: (v) => setState(() => _priorite = v ?? PrioritePrestation.normale),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 6. Prestations, Pièces & Chiffrage
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Prestations & Lignes facturées', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Ajouter une ligne'),
                          onPressed: () => _ajouterLigneModal(catalogueAsync.value ?? const []),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_lignes.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.playlist_add_rounded, size: 36, color: AppColors.muted),
                              const SizedBox(height: 6),
                              const Text('Aucune ligne spécifique ajoutée', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                              const SizedBox(height: 2),
                              const Text('Une ligne avec le titre sera automatiquement créée si vous enregistrez directement.',
                                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.muted)),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          for (int i = 0; i < _lignes.length; i++)
                            _LignePrestationItem(
                              ligne: _lignes[i],
                              onSupprimer: () => setState(() => _lignes.removeAt(i)),
                            ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _remiseCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Remise commerciale éventuelle (FCFA)',
                        prefixIcon: Icon(Icons.discount_outlined),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 7. Lieu & Note interne
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _lieuCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Lieu d\'intervention / Récupération',
                        hintText: 'Ex. Atelier, Sur site client, Domicile...',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noteCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Note interne privée',
                        hintText: 'Observations techniques non visibles par le client...',
                        prefixIcon: Icon(Icons.note_alt_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _choisirDateEcheance() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _echeanceJour ?? now.add(const Duration(days: 1)),
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (d != null) setState(() => _echeanceJour = d);
  }

  Future<void> _choisirHeureEcheance() async {
    final h = await showTimePicker(
      context: context,
      initialTime: _echeanceHeure ?? const TimeOfDay(hour: 17, minute: 0),
    );
    if (h != null) setState(() => _echeanceHeure = h);
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
                bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Ajouter une ligne au dossier', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  if (catalogue.isNotEmpty) ...[
                    DropdownButtonFormField<ServiceCatalogue?>(
                      value: selectionne,
                      decoration: const InputDecoration(labelText: 'Choisir depuis le catalogue'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Prestation personnalisée')),
                        for (final s in catalogue)
                          DropdownMenuItem(value: s, child: Text('${s.nom} (${montant(context, ref, s.prix)} / ${s.unite.libelle})')),
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
                  const SizedBox(height: 20),
                  FilledButton(
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
    if (!_formKey.currentState!.validate()) return;
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
      final echeanceHeureStr = _echeanceHeure != null
          ? '${_echeanceHeure!.hour.toString().padLeft(2, '0')}:${_echeanceHeure!.minute.toString().padLeft(2, '0')}'
          : null;
      final dureeEstimee = int.tryParse(_dureeCtrl.text.trim());

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
              echeanceHeure: echeanceHeureStr,
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
          echeanceHeure: echeanceHeureStr,
          livraisonRequise: _livraisonRequise,
          lieu: _lieuCtrl.text.trim(),
          note: _noteCtrl.text.trim(),
        );

        if (_photos.isNotEmpty || _metierSelectionne != MetierCode.generique || _champsMetier.isNotEmpty) {
          final pMaj = nouv.copyWith(
            metierCode: _metierSelectionne,
            champsMetier: _champsMetier,
            dureeEstimee: dureeEstimee,
            uniteDuree: _uniteDuree,
            photos: _photos,
          );
          await gerer.modifierPrestation(pMaj);
        }
      }

      if (mounted) {
        ref.invalidate(prestationsProvider);
        context.pop();
      }
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }
}

class _LignePrestationItem extends StatelessWidget {
  const _LignePrestationItem({required this.ligne, required this.onSupprimer});
  final LignePrestation ligne;
  final VoidCallback onSupprimer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ligne.libelle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                Text('${ligne.quantite} × ${ligne.prixUnitaire} FCFA',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          Text('${ligne.totalLigne} FCFA', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.negative),
            onPressed: onSupprimer,
          ),
        ],
      ),
    );
  }
}
