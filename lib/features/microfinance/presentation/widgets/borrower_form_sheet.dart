import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/microfinance_models.dart';
import '../providers/microfinance_providers.dart';

/// Formulaire modal de création / modification d'un emprunteur.
/// Permet aussi d'importer rapidement un Contact existant sans imposer de caution/garantie.
Future<MicrofinanceBorrower?> afficherFormulaireEmprunteur(
  BuildContext context, {
  MicrofinanceBorrower? existant,
}) {
  return showModalBottomSheet<MicrofinanceBorrower>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => BorrowerFormSheet(existant: existant),
  );
}

class BorrowerFormSheet extends ConsumerStatefulWidget {
  const BorrowerFormSheet({super.key, this.existant});
  final MicrofinanceBorrower? existant;

  @override
  ConsumerState<BorrowerFormSheet> createState() => _BorrowerFormSheetState();
}

class _BorrowerFormSheetState extends ConsumerState<BorrowerFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomCtrl;
  late final TextEditingController _telCtrl;
  late final TextEditingController _waCtrl;
  late final TextEditingController _adresseCtrl;
  late final TextEditingController _locCtrl;
  late final TextEditingController _profCtrl;
  late final TextEditingController _actCtrl;
  late final TextEditingController _typePieceCtrl;
  late final TextEditingController _refPieceCtrl;
  late final TextEditingController _infosCtrl;
  late final TextEditingController _obsCtrl;

  String? _contactId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.existant;
    _contactId = b?.contactId;
    _nomCtrl = TextEditingController(text: b?.nomComplet ?? '');
    _telCtrl = TextEditingController(text: b?.telephone ?? '');
    _waCtrl = TextEditingController(text: b?.whatsapp ?? '');
    _adresseCtrl = TextEditingController(text: b?.adresse ?? '');
    _locCtrl = TextEditingController(text: b?.localisation ?? '');
    _profCtrl = TextEditingController(text: b?.profession ?? '');
    _actCtrl = TextEditingController(text: b?.activite ?? '');
    _typePieceCtrl = TextEditingController(text: b?.typePiece ?? 'CNI');
    _refPieceCtrl = TextEditingController(text: b?.referencePiece ?? '');
    _infosCtrl = TextEditingController(text: b?.infosComplementaires ?? '');
    _obsCtrl = TextEditingController(text: b?.observations ?? '');
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _telCtrl.dispose();
    _waCtrl.dispose();
    _adresseCtrl.dispose();
    _locCtrl.dispose();
    _profCtrl.dispose();
    _actCtrl.dispose();
    _typePieceCtrl.dispose();
    _refPieceCtrl.dispose();
    _infosCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  void _appliquerContact(Contact c) {
    setState(() {
      _contactId = c.id;
      _nomCtrl.text = c.nomAffiche;
      if (c.telephone != null && c.telephone!.isNotEmpty) _telCtrl.text = c.telephone!;
      if (c.whatsapp != null && c.whatsapp!.isNotEmpty) _waCtrl.text = c.whatsapp!;
      if (c.adresse != null && c.adresse!.isNotEmpty) _adresseCtrl.text = c.adresse!;
      if (c.ville != null && c.ville!.isNotEmpty) _locCtrl.text = c.ville!;
    });
  }

  Future<void> _choisirContactExistant(List<Contact> contacts) async {
    final choisi = await showDialog<Contact>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importer depuis Contacts'),
        content: SizedBox(
          width: 400,
          height: 320,
          child: contacts.isEmpty
              ? const Center(child: Text('Aucun contact disponible.'))
              : ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (_, i) {
                    final c = contacts[i];
                    return ListTile(
                      leading: CircleAvatar(child: Text(c.initiales.isEmpty ? 'C' : c.initiales)),
                      title: Text(c.nomAffiche),
                      subtitle: Text(c.telephone ?? c.adresse ?? ''),
                      onTap: () => Navigator.pop(ctx, c),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
    if (choisi != null) _appliquerContact(choisi);
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final ctx = ref.read(contexteActifProvider);
    if (ctx?.entreprise == null) return;

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final existant = widget.existant;
      final borrower = MicrofinanceBorrower(
        id: existant?.id ?? const Uuid().v4(),
        entrepriseId: ctx!.entreprise!.id,
        codeEmprunteur: existant?.codeEmprunteur ?? '',
        contactId: _contactId,
        nomComplet: _nomCtrl.text.trim(),
        telephone: _telCtrl.text.trim(),
        whatsapp: _waCtrl.text.trim().isEmpty ? null : _waCtrl.text.trim(),
        adresse: _adresseCtrl.text.trim().isEmpty ? null : _adresseCtrl.text.trim(),
        localisation: _locCtrl.text.trim().isEmpty ? null : _locCtrl.text.trim(),
        profession: _profCtrl.text.trim().isEmpty ? null : _profCtrl.text.trim(),
        activite: _actCtrl.text.trim().isEmpty ? null : _actCtrl.text.trim(),
        typePiece: _typePieceCtrl.text.trim().isEmpty ? null : _typePieceCtrl.text.trim(),
        referencePiece: _refPieceCtrl.text.trim().isEmpty ? null : _refPieceCtrl.text.trim(),
        infosComplementaires: _infosCtrl.text.trim().isEmpty ? null : _infosCtrl.text.trim(),
        dateInscription: existant?.dateInscription ?? now,
        observations: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
        version: existant?.version ?? 1,
        createdAt: existant?.createdAt ?? now,
        updatedAt: now,
      );

      final saved = await ref.read(microfinanceRepositoryProvider).sauvegarderEmprunteur(borrower);
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsProvider).value ?? const [];
    final isEdit = widget.existant != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Form(
          key: _formKey,
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isEdit ? 'Modifier l\'emprunteur' : 'Nouvel emprunteur',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (!isEdit && contacts.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _choisirContactExistant(contacts),
                      icon: const Icon(Icons.contact_page_outlined, size: 18),
                      label: const Text('Importer Contact'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nomCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom et prénom complets *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _telCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone *',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Téléphone requis' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _waCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp',
                        prefixIcon: Icon(Icons.chat_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _adresseCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Adresse / Quartier',
                        prefixIcon: Icon(Icons.home_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _locCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ville / Localisation',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _profCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Profession',
                        prefixIcon: Icon(Icons.work_outline),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _actCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Activité commerciale',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _typePieceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Type de pièce d\'identité',
                        hintText: 'CNI, Passeport...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _refPieceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'N° pièce d\'identité',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _infosCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Informations complémentaires (facultatif)',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _obsCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Observations (facultatif)',
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _saving ? null : _enregistrer,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(isEdit ? 'Enregistrer les modifications' : 'Enregistrer l\'emprunteur'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

