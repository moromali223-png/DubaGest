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

/// Formulaire de création d'un devis de services avec support multi-métiers & photos.
class DevisFormPage extends ConsumerStatefulWidget {
  const DevisFormPage({super.key, this.initialContactId});
  final String? initialContactId;

  @override
  ConsumerState<DevisFormPage> createState() => _DevisFormPageState();
}

class _DevisFormPageState extends ConsumerState<DevisFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _remiseCtrl = TextEditingController(text: '0');
  final _conditionsCtrl = TextEditingController();

  String? _contactId;
  MetierCode _metierSelectionne = MetierCode.generique;
  final Map<String, dynamic> _champsMetier = {};
  final Map<String, TextEditingController> _champsMetierCtrls = {};

  DateTime _dateEmission = DateTime.now();
  DateTime? _dateValidite = DateTime.now().add(const Duration(days: 30));

  final List<LignePrestation> _lignes = [];
  final List<PhotoPrestation> _photos = [];
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    _contactId = widget.initialContactId;
  }

  @override
  void dispose() {
    _titreCtrl.dispose();
    _descCtrl.dispose();
    _remiseCtrl.dispose();
    _conditionsCtrl.dispose();
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
      if (_titreCtrl.text.trim().isEmpty || _titreCtrl.text == 'Devis de prestation') {
        _titreCtrl.text = 'Devis — ${template.titreParDefaut}';
      }
      for (final f in template.champs) {
        if (!_champsMetierCtrls.containsKey(f.cle)) {
          _champsMetierCtrls[f.cle] = TextEditingController(text: _champsMetier[f.cle]?.toString() ?? '');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalogueAsync = ref.watch(servicesCatalogueProvider);
    final contacts = ref.watch(contactsProvider).value ?? const <Contact>[];
    final templateCourant = MetierTemplate.templatePour(_metierSelectionne);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau devis'),
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
                    const Text('Total devis', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    Text(
                      montant(context, ref, _total),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF01226C)),
                    ),
                  ],
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: _envoi ? null : _enregistrer,
                child: _envoi
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Créer le devis'),
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
              // 1. Modèle Métier
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
                        Text('Modèle métier de la proposition *', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
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
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Coordonnées & Informations
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
                        labelText: 'Objet / Titre du devis *',
                        hintText: 'Ex. Proposition de maintenance réseau, Réparation moteur...',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Le titre est obligatoire' : null,
                    ),
                    const SizedBox(height: 12),
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
                        const DropdownMenuItem(value: null, child: Text('Client prospect (non enregistré)')),
                        for (final c in contacts)
                          DropdownMenuItem(value: c.id, child: Text('${c.nomAffiche} (${c.telephone ?? "Sans tel"})')),
                      ],
                      onChanged: (v) => setState(() => _contactId = v),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today_outlined, size: 18),
                            label: Text('Émis le ${DateFormat('dd/MM/yyyy').format(_dateEmission)}'),
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _dateEmission,
                                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (d != null) setState(() => _dateEmission = d);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.event_available_outlined, size: 18),
                            label: Text(_dateValidite != null
                                ? 'Valide au ${DateFormat('dd/MM/yyyy').format(_dateValidite!)}'
                                : 'Validité'),
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _dateValidite ?? _dateEmission.add(const Duration(days: 30)),
                                firstDate: _dateEmission,
                                lastDate: DateTime.now().add(const Duration(days: 730)),
                              );
                              if (d != null) setState(() => _dateValidite = d);
                            },
                          ),
                        ),
                      ],
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
                          Text('Détails du chiffrage — ${templateCourant.code.libelle}',
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
                            onChanged: (val) => setState(() => _champsMetier[champ.cle] = val),
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

              // 4. Photographies & Croquis du Devis
              PrestationPhotosSection(
                photos: _photos,
                onPhotosChanged: (maj) => setState(() {
                  _photos.clear();
                  _photos.addAll(maj);
                }),
              ),
              const SizedBox(height: 16),

              // 5. Lignes Chiffrées
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
                          child: Text('Prestations chiffrées', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Ajouter une prestation'),
                          onPressed: () => _ajouterLigne(catalogueAsync.value ?? const []),
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
                              const Icon(Icons.request_quote_outlined, size: 36, color: AppColors.muted),
                              const SizedBox(height: 6),
                              const Text('Aucune ligne chiffrée', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
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
                            _LigneItem(
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
                        labelText: 'Remise commerciale (FCFA)',
                        prefixIcon: Icon(Icons.discount_outlined),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 6. Conditions & Modalités
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
                      controller: _conditionsCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Conditions de règlement & validité',
                        hintText: 'Ex. Acompte de 40% à la commande, solde à la livraison...',
                        prefixIcon: Icon(Icons.gavel_outlined),
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

  Future<void> _ajouterLigne(List<ServiceCatalogue> catalogue) async {
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
                  Text('Ajouter une ligne au devis', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  if (catalogue.isNotEmpty) ...[
                    DropdownButtonFormField<ServiceCatalogue?>(
                      value: selectionne,
                      decoration: const InputDecoration(labelText: 'Choisir depuis le catalogue'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Ligne sur-mesure / Forfait')),
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
                    decoration: const InputDecoration(labelText: 'Désignation de la prestation *'),
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
                    child: const Text('Ajouter au devis'),
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
        showFailureSnackBar(context, 'Veuillez renseigner un intitulé de devis ou ajouter des lignes.');
        return;
      }
    }
    final ctx = ref.read(contexteActifProvider);
    final espace = ref.read(espaceCourantProvider);
    final entrepriseId = ctx?.entreprise?.id;
    if (entrepriseId == null) return;

    setState(() => _envoi = true);
    try {
      final now = DateTime.now();
      final numero = 'DEV-${now.year}${now.month.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';

      await ref.read(gererServicesProvider).creerDevis(
            entrepriseId: entrepriseId,
            numero: numero,
            perimetreId: espace.perimetreId,
            contactId: _contactId,
            metierCode: _metierSelectionne,
            champsMetier: _champsMetier,
            titre: _titreCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            lignes: _lignes,
            remise: _remise,
            dateEmission: _dateEmission,
            dateValidite: _dateValidite,
            conditions: _conditionsCtrl.text.trim(),
            photos: _photos,
          );

      if (mounted) {
        ref.invalidate(devisServicesProvider);
        context.pop();
      }
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }
}

class _LigneItem extends StatelessWidget {
  const _LigneItem({required this.ligne, required this.onSupprimer});
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
