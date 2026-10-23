import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';

/// Section affichant le client sélectionné ou un bouton pour en choisir un.
class SectionClientProspect extends StatelessWidget {
  const SectionClientProspect({
    super.key,
    required this.selectedContact,
    required this.onChoisir,
    required this.onCreerNouveau,
    required this.onRetirer,
  });

  final Contact? selectedContact;
  final VoidCallback onChoisir;
  final VoidCallback onCreerNouveau;
  final VoidCallback onRetirer;

  @override
  Widget build(BuildContext context) {
    if (selectedContact == null) {
      return OutlinedButton.icon(
        onPressed: onChoisir,
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
        label: const Text('Sélectionner un client ou prospect'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: const BorderSide(color: AppColors.border),
          foregroundColor: AppColors.navy,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.navy,
            radius: 18,
            child: Text(
              selectedContact!.nomAffiche.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedContact!.nomAffiche,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy),
                ),
                if (selectedContact!.telephone != null)
                  Text(
                    selectedContact!.telephone!,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded, size: 20, color: AppColors.navy),
            onPressed: onChoisir,
            tooltip: 'Changer',
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.negative),
            onPressed: onRetirer,
            tooltip: 'Retirer',
          ),
        ],
      ),
    );
  }
}

/// Modal de sélection d'un contact existant.
class ModalChoixContactDevis extends StatelessWidget {
  const ModalChoixContactDevis({
    super.key,
    required this.contacts,
    this.contactActuelId,
    required this.onCreerRapide,
  });

  final List<Contact> contacts;
  final String? contactActuelId;
  final Function(String) onCreerRapide;

  @override
  Widget build(BuildContext context) {
    final searchController = TextEditingController();

    return StatefulBuilder(
      builder: (context, setState) {
        final filtered = contacts.where((c) {
          final query = searchController.text.toLowerCase();
          return c.nomAffiche.toLowerCase().contains(query) ||
              (c.telephone?.contains(query) ?? false);
        }).toList();

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un contact...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (filtered.isEmpty && searchController.text.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.navy),
                  title: Text('Créer « ${searchController.text} »'),
                  onTap: () => onCreerRapide(searchController.text),
                ),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final c = filtered[index];
                    final selected = c.id == contactActuelId;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: selected ? AppColors.navy : AppColors.background,
                        child: Text(
                          c.nomAffiche.substring(0, 1).toUpperCase(),
                          style: TextStyle(color: selected ? Colors.white : AppColors.navy),
                        ),
                      ),
                      title: Text(c.nomAffiche, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: c.telephone != null ? Text(c.telephone!) : null,
                      trailing: selected ? const Icon(Icons.check_circle, color: AppColors.navy) : null,
                      onTap: () => Navigator.of(context).pop(c),
                    );
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_off_rounded, color: AppColors.muted),
                title: const Text('Aucun contact (devis libre)'),
                onTap: () => Navigator.of(context).pop('AUCUN'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

/// Dialogue de création rapide d'un nouveau contact.
class DialogueNouveauContactDevis extends ConsumerStatefulWidget {
  const DialogueNouveauContactDevis({super.key, this.nomInitial});
  final String? nomInitial;

  @override
  ConsumerState<DialogueNouveauContactDevis> createState() => _DialogueNouveauContactDevisState();
}

class _DialogueNouveauContactDevisState extends ConsumerState<DialogueNouveauContactDevis> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomCtrl;
  final _telCtrl = TextEditingController();
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _nomCtrl = TextEditingController(text: widget.nomInitial);
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _telCtrl.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (!_formKey.currentState!.validate() || _enCours) return;

    setState(() => _enCours = true);
    try {
      final contact = Contact(
        id: const Uuid().v4(),
        nom: _nomCtrl.text.trim(),
        telephone: _telCtrl.text.trim().isEmpty ? null : _telCtrl.text.trim(),
        type: ContactType.physique,
        relations: {RelationContact.client},
        dateCreation: DateTime.now(),
      );

      // Simulation de l'ajout via le provider (ajustez selon votre API réelle)
      await ref.read(contactsProvider.notifier).ajouterContact(contact);
      
      if (mounted) Navigator.of(context).pop(contact);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.negative),
        );
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau client'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nomCtrl,
              autofocus: widget.nomInitial == null,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nom complet *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Le nom est requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone (optionnel)', hintText: 'Ex. 07 00 00 00 00'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _enCours ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
          onPressed: _enCours ? null : _valider,
          child: _enCours 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Créer et sélectionner'),
        ),
      ],
    );
  }
}
