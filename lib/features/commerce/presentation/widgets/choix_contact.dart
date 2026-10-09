import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../contacts/domain/usecases/gerer_contacts.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../contacts/presentation/widgets/contact_avatar.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../commerce_providers.dart';

/// Contacts ayant une relation (fournisseurs, clients), lisibles hors-ligne.
final contactsRelationProvider =
    StreamProvider.autoDispose.family<List<Contact>, RelationContact>((ref, relation) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null) return const Stream.empty();
  return ref.watch(observerContactsProvider).call(ctx, FiltreContacts(relation: relation));
});

/// Tous les contacts actifs (pour retrouver un nom).
final tousContactsProvider = StreamProvider.autoDispose<List<Contact>>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null) return const Stream.empty();
  return ref.watch(observerContactsProvider).call(ctx, const FiltreContacts(inclureArchives: true));
});

String? nomContact(WidgetRef ref, String? id) => id == null
    ? null
    : ref.watch(tousContactsProvider).value?.where((c) => c.id == id).firstOrNull?.nomAffiche;

/// Choisir un fournisseur ou un client ; « Nouveau » ouvre la fiche contact
/// avec la relation déjà cochée.
Future<Contact?> choisirContact(BuildContext context, RelationContact relation) =>
    showModalBottomSheet<Contact>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(heightFactor: 0.85, child: _ChoixContact(relation: relation)),
    );

class _ChoixContact extends ConsumerStatefulWidget {
  const _ChoixContact({required this.relation});
  final RelationContact relation;

  @override
  ConsumerState<_ChoixContact> createState() => _ChoixContactState();
}

class _ChoixContactState extends ConsumerState<_ChoixContact> {
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fournisseur = widget.relation == RelationContact.fournisseur;
    final contacts = ref.watch(contactsRelationProvider(widget.relation)).value ?? const <Contact>[];
    final mots = _recherche.toLowerCase().split(' ').where((m) => m.isNotEmpty);
    final liste = [
      for (final c in contacts)
        if (mots.every((m) => '${c.nomAffiche} ${c.telephone ?? ''}'.toLowerCase().contains(m))) c,
    ];
    final peutCreer = ref.watch(droitsCommerceProvider).creerContacts;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(fournisseur ? l10n.comChooseSupplier : l10n.comChooseCustomer,
                style: Theme.of(context).textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              decoration: InputDecoration(hintText: l10n.comSearchContact, prefixIcon: const Icon(Icons.search)),
              onChanged: (t) => setState(() => _recherche = t),
            ),
          ),
          if (peutCreer)
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.greenSoft,
                child: Icon(Icons.person_add_alt_1_outlined, color: AppColors.green),
              ),
              title: Text(fournisseur ? l10n.comNewSupplier : l10n.comNewCustomer,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.green)),
              onTap: () {
                Navigator.pop(context);
                context.push(Routes.contactNouveau(relation: widget.relation.code));
              },
            ),
          const Divider(),
          Expanded(
            child: liste.isEmpty
                ? Center(child: Text(l10n.comNoContact, style: const TextStyle(color: AppColors.muted)))
                : ListView.builder(
                    itemCount: liste.length,
                    itemBuilder: (_, i) {
                      final c = liste[i];
                      return ListTile(
                        key: Key('contact-${c.id}'),
                        leading: ContactAvatar(contact: c),
                        title: Text(c.nomAffiche, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: c.telephone == null ? null : Text(c.telephone!),
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Ajout express d'un client à la caisse : un nom, un téléphone facultatif.
/// Un client existant avec le même téléphone est repris (pas de doublon).
Future<Contact?> ajouterClientRapide(BuildContext context, WidgetRef ref) async {
  final saisie = await showDialog<(String, String?)>(context: context, builder: (_) => const _AjoutClientRapide());
  if (saisie == null || !context.mounted) return null;
  final (nom, telephone) = saisie;
  final ctx = ref.read(contexteActifProvider);
  if (ctx == null) return null;
  if (telephone != null) {
    final chiffres = telephone.replaceAll(RegExp(r'\D'), '');
    final existant = ref
        .read(tousContactsProvider)
        .value
        ?.where((c) => c.telephone != null && c.telephone!.replaceAll(RegExp(r'\D'), '').endsWith(chiffres))
        .firstOrNull;
    if (existant != null && chiffres.length >= 8) return existant;
  }
  try {
    return await ref.read(creerContactProvider).call(
          ctx,
          SaisieContact(
            typePersonne: TypePersonne.personne,
            nom: nom,
            telephone: telephone,
            relations: const {RelationContact.client},
          ),
        );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.failure(e))));
    }
    return null;
  }
}

class _AjoutClientRapide extends StatefulWidget {
  const _AjoutClientRapide();

  @override
  State<_AjoutClientRapide> createState() => _AjoutClientRapideState();
}

class _AjoutClientRapideState extends State<_AjoutClientRapide> {
  final _nom = TextEditingController();
  final _telephone = TextEditingController();

  @override
  void dispose() {
    _nom.dispose();
    _telephone.dispose();
    super.dispose();
  }

  void _valider() {
    final nom = _nom.text.trim();
    if (nom.isEmpty) return;
    final tel = _telephone.text.trim();
    Navigator.pop(context, (nom, tel.isEmpty ? null : tel));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.rcpAddName),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('client-rapide-nom'),
              controller: _nom,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.rcpCustomerName, prefixIcon: const Icon(Icons.person_outline)),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('client-rapide-telephone'),
              controller: _telephone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              decoration:
                  InputDecoration(labelText: l10n.rcpPhoneOptional, prefixIcon: const Icon(Icons.phone_outlined)),
              onSubmitted: (_) => _valider(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
        FilledButton(
          key: const Key('client-rapide-enregistrer'),
          onPressed: _nom.text.trim().isEmpty ? null : _valider,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
