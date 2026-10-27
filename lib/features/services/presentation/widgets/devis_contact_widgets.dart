import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../contacts/domain/usecases/gerer_contacts.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';

/// Section affichant le client sélectionné ou des boutons pour en choisir ou en créer un.
class SectionClientProspect extends StatelessWidget {
  const SectionClientProspect({
    super.key,
    required this.selectedContact,
    required this.onChoisir,
    required this.onCreerNouveau,
    required this.onRetirer,
    this.labelChoix = 'Sélectionner ou créer un contact',
    this.labelCreation = 'Nouveau',
  });

  final Contact? selectedContact;
  final VoidCallback onChoisir;
  final VoidCallback onCreerNouveau;
  final VoidCallback onRetirer;
  final String labelChoix;
  final String labelCreation;

  @override
  Widget build(BuildContext context) {
    if (selectedContact == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Client ou Prospect',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted),
                ),
                OutlinedButton.icon(
                  key: const Key('btn-nouveau-contact-devis'),
                  onPressed: onCreerNouveau,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                  label: Text(labelCreation, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.green,
                    side: const BorderSide(color: AppColors.green),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              key: const Key('btn-choisir-contact-devis'),
              onTap: onChoisir,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_search_rounded, size: 20, color: AppColors.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        labelChoix,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.ink),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final estClient = selectedContact!.relations.contains(RelationContact.client);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.green,
            radius: 18,
            child: Text(
              selectedContact!.nomAffiche.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        selectedContact!.nomAffiche,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: estClient ? AppColors.green.withValues(alpha: 0.15) : AppColors.goldSoft,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        estClient ? 'Client' : 'Prospect',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: estClient ? AppColors.green : AppColors.gold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (selectedContact!.telephone != null && selectedContact!.telephone!.isNotEmpty)
                  Text(
                    selectedContact!.telephone!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),
          IconButton(
            key: const Key('btn-changer-contact-devis'),
            icon: const Icon(Icons.sync_rounded, size: 20, color: AppColors.green),
            onPressed: onChoisir,
            tooltip: 'Changer',
          ),
          IconButton(
            key: const Key('btn-retirer-contact-devis'),
            icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.negative),
            onPressed: onRetirer,
            tooltip: 'Retirer',
          ),
        ],
      ),
    );
  }
}

/// Modal de sélection d'un contact existant avec badges et création rapide.
class ModalChoixContactDevis extends StatelessWidget {
  const ModalChoixContactDevis({
    super.key,
    required this.contacts,
    this.contactActuelId,
    required this.onCreerRapide,
    this.titre = 'Sélectionner un client ou prospect',
    this.labelNouveau = 'Nouveau contact',
  });

  final List<Contact> contacts;
  final String? contactActuelId;
  final Function(String) onCreerRapide;
  final String titre;
  final String labelNouveau;

  @override
  Widget build(BuildContext context) {
    final searchController = TextEditingController();

    return StatefulBuilder(
      builder: (context, setState) {
        final query = searchController.text.trim().toLowerCase();
        final filtered = contacts.where((c) {
          if (query.isEmpty) return true;
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        titre,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => onCreerRapide(searchController.text.trim()),
                      icon: const Icon(Icons.person_add_rounded, size: 18, color: AppColors.green),
                      label: Text(labelNouveau, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.green)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: TextField(
                  controller: searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Rechercher par nom ou numéro...',
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
              const SizedBox(height: 8),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.greenSoft,
                  child: Icon(Icons.person_add_alt_1_rounded, color: AppColors.green),
                ),
                title: Text(
                  searchController.text.trim().isNotEmpty
                      ? 'Créer « ${searchController.text.trim()} »'
                      : 'Créer un nouveau contact',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.green),
                ),
                subtitle: const Text(
                  'Ajout direct sans quitter le document',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                onTap: () => onCreerRapide(searchController.text.trim()),
              ),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: (MediaQuery.of(context).size.height -
                          MediaQuery.of(context).viewInsets.bottom -
                          260)
                      .clamp(100.0, MediaQuery.of(context).size.height * 0.45),
                ),
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_search_outlined, size: 40, color: AppColors.muted),
                              const SizedBox(height: 8),
                              Text(
                                searchController.text.trim().isNotEmpty
                                    ? 'Aucun contact correspondant à « ${searchController.text.trim()} »'
                                    : 'Aucun contact enregistré',
                                style: const TextStyle(color: AppColors.muted, fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                                onPressed: () => onCreerRapide(searchController.text.trim()),
                                icon: const Icon(Icons.person_add_rounded, size: 18),
                                label: Text(
                                  searchController.text.trim().isNotEmpty
                                      ? 'Créer « ${searchController.text.trim()} »'
                                      : 'Créer un nouveau contact',
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final c = filtered[index];
                          final selected = c.id == contactActuelId;
                          final estClient = c.relations.contains(RelationContact.client);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: selected ? AppColors.green : AppColors.background,
                              child: Text(
                                c.nomAffiche.substring(0, 1).toUpperCase(),
                                style: TextStyle(color: selected ? Colors.white : AppColors.green, fontWeight: FontWeight.w800),
                              ),
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(c.nomAffiche, style: const TextStyle(fontWeight: FontWeight.w800)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: estClient ? AppColors.greenSoft : AppColors.goldSoft,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    estClient ? 'Client' : 'Prospect',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: estClient ? AppColors.green : AppColors.gold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: c.telephone != null ? Text(c.telephone!, style: const TextStyle(fontWeight: FontWeight.w500)) : null,
                            trailing: selected ? const Icon(Icons.check_circle, color: AppColors.green) : null,
                            onTap: () => Navigator.of(context).pop(c),
                          );
                        },
                      ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.person_off_rounded, color: AppColors.muted),
                title: const Text('Aucun contact (client comptoir / libre)'),
                onTap: () => Navigator.of(context).pop('AUCUN'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

/// Dialogue professionnel de création rapide d'un nouveau contact (Client, Locataire, Prospect, etc.).
class DialogueNouveauContactDevis extends ConsumerStatefulWidget {
  const DialogueNouveauContactDevis({
    super.key,
    this.nomInitial,
    this.relation,
  });

  final String? nomInitial;
  final RelationContact? relation;

  static Future<Contact?> afficher(
    BuildContext context, {
    String? nomInitial,
    RelationContact? relation,
  }) =>
      showDialog<Contact>(
        context: context,
        barrierDismissible: false,
        builder: (_) => DialogueNouveauContactDevis(
          nomInitial: nomInitial,
          relation: relation,
        ),
      );

  @override
  ConsumerState<DialogueNouveauContactDevis> createState() => _DialogueNouveauContactDevisState();
}

class _DialogueNouveauContactDevisState extends ConsumerState<DialogueNouveauContactDevis> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomCtrl;
  final _prenomCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();

  TypePersonne _typePersonne = TypePersonne.personne;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _nomCtrl = TextEditingController(text: widget.nomInitial);
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _telCtrl.dispose();
    _adresseCtrl.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (!_formKey.currentState!.validate() || _enCours) return;

    setState(() => _enCours = true);
    try {
      final ctx = ref.read(contexteActifProvider);
      if (ctx == null) throw Exception('Aucun contexte actif');

      final relations = <RelationContact>{
        if (widget.relation != null) widget.relation!,
      };

      final contact = await ref.read(creerContactProvider).call(
            ctx,
            SaisieContact(
              typePersonne: _typePersonne,
              nom: _nomCtrl.text.trim(),
              prenom: _typePersonne == TypePersonne.personne && _prenomCtrl.text.trim().isNotEmpty
                  ? _prenomCtrl.text.trim()
                  : null,
              telephone: _telCtrl.text.trim().isEmpty ? null : _telCtrl.text.trim(),
              adresse: _adresseCtrl.text.trim().isEmpty ? null : _adresseCtrl.text.trim(),
              relations: relations,
            ),
          );

      ref.invalidate(contactsProvider);

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
      scrollable: true,
      actionsOverflowButtonSpacing: 8,
      actionsOverflowDirection: VerticalDirection.up,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add_rounded, color: AppColors.green, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Nouveau contact',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Client ou prospect pour ce devis',
            style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.normal),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<TypePersonne>(
                segments: const [
                  ButtonSegment(
                    value: TypePersonne.personne,
                    label: Text('Particulier'),
                    icon: Icon(Icons.person_outline, size: 18),
                  ),
                  ButtonSegment(
                    value: TypePersonne.organisation,
                    label: Text('Entreprise'),
                    icon: Icon(Icons.business_outlined, size: 18),
                  ),
                ],
                selected: {_typePersonne},
                onSelectionChanged: (s) => setState(() => _typePersonne = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('champ-nouveau-contact-nom'),
                controller: _nomCtrl,
                autofocus: widget.nomInitial == null || widget.nomInitial!.isEmpty,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: _typePersonne == TypePersonne.personne ? 'Nom *' : 'Raison sociale / Société *',
                  prefixIcon: Icon(_typePersonne == TypePersonne.personne ? Icons.badge_outlined : Icons.store_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? (_typePersonne == TypePersonne.personne ? 'Le nom est requis' : 'La raison sociale est requise')
                    : null,
              ),
              if (_typePersonne == TypePersonne.personne) ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('champ-nouveau-contact-prenom'),
                  controller: _prenomCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Prénom (optionnel)',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('champ-nouveau-contact-tel'),
                controller: _telCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone (optionnel)',
                  hintText: 'Ex. 07 00 00 00 00',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _adresseCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Adresse / Ville (optionnel)',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _enCours ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          key: const Key('btn-creer-contact-rapide-valider'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.green),
          onPressed: _enCours ? null : _valider,
          child: _enCours
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Créer et sélectionner'),
        ),
      ],
    );
  }
}
