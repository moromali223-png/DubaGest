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
import '../../../services/presentation/widgets/devis_contact_widgets.dart';
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
  bool _voirTous = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fournisseur = widget.relation == RelationContact.fournisseur;
    final contactsPrincipaux = ref.watch(contactsRelationProvider(widget.relation)).value ?? const <Contact>[];
    final tousContacts = (ref.watch(tousContactsProvider).value ?? const <Contact>[])
        .where((c) => !c.estArchive)
        .toList();

    final mots = _recherche.toLowerCase().split(' ').where((m) => m.isNotEmpty);

    // Si une recherche est saisie ou si aucun contact principal n'existe ou si l'utilisateur coche 'voir tous' :
    // On permet de choisir parmi TOUS les contacts actifs de l'entreprise
    final List<Contact> source;
    if (mots.isNotEmpty || _voirTous || contactsPrincipaux.isEmpty) {
      source = tousContacts;
    } else {
      source = contactsPrincipaux;
    }

    final liste = [
      for (final c in source)
        if (mots.isEmpty || mots.every((m) => '${c.nomAffiche} ${c.telephone ?? ''}'.toLowerCase().contains(m))) c,
    ];

    // Trier : les contacts ayant déjà la relation demandée en premier, puis ordre alphabétique
    liste.sort((a, b) {
      final aHas = a.relations.contains(widget.relation);
      final bHas = b.relations.contains(widget.relation);
      if (aHas && !bHas) return -1;
      if (!aHas && bHas) return 1;
      return a.nomAffiche.toLowerCase().compareTo(b.nomAffiche.toLowerCase());
    });

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
              decoration: InputDecoration(
                hintText: l10n.comSearchContact,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (t) => setState(() => _recherche = t),
            ),
          ),
          if (contactsPrincipaux.isNotEmpty && tousContacts.length > contactsPrincipaux.length && mots.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _voirTous = !_voirTous),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(
                        _voirTous ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        size: 20,
                        color: AppColors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Afficher tous les contacts (${tousContacts.length})',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
                      ),
                    ],
                  ),
                ),
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
              onTap: () async {
                final nouveau = await DialogueNouveauContactDevis.afficher(
                  context,
                  nomInitial: _recherche.trim().isNotEmpty ? _recherche.trim() : null,
                  relation: widget.relation,
                );
                if (nouveau != null && mounted) {
                  ref.invalidate(contactsRelationProvider(widget.relation));
                  ref.invalidate(tousContactsProvider);
                  Navigator.pop(context, nouveau);
                }
              },
            ),
          const Divider(),
          Expanded(
            child: liste.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_search_outlined, size: 48, color: AppColors.muted),
                          const SizedBox(height: AppSpacing.sm),
                          Text(l10n.comNoContact, style: const TextStyle(color: AppColors.muted)),
                          if (peutCreer) ...[
                            const SizedBox(height: AppSpacing.md),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                              onPressed: () async {
                                final nouveau = await DialogueNouveauContactDevis.afficher(
                                  context,
                                  nomInitial: _recherche.trim().isNotEmpty ? _recherche.trim() : null,
                                  relation: widget.relation,
                                );
                                if (nouveau != null && mounted) {
                                  ref.invalidate(contactsRelationProvider(widget.relation));
                                  ref.invalidate(tousContactsProvider);
                                  Navigator.pop(context, nouveau);
                                }
                              },
                              icon: const Icon(Icons.person_add_rounded, size: 18),
                              label: Text(fournisseur ? l10n.comNewSupplier : l10n.comNewCustomer),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: liste.length,
                    itemBuilder: (_, i) {
                      final c = liste[i];
                      final aLaRelation = c.relations.contains(widget.relation);
                      return ListTile(
                        key: Key('contact-${c.id}'),
                        leading: ContactAvatar(contact: c),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(c.nomAffiche, style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                            if (!aLaRelation)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.greenSoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  fournisseur ? '+ Fournisseur' : '+ Client',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.green,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: c.telephone == null
                            ? (!aLaRelation
                                ? Text(
                                    'Contact existant (${c.relations.isEmpty ? "Sans rôle" : c.relations.map((r) => l10n.relationContact(r)).join(", ")})',
                                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                  )
                                : null)
                            : Text(!aLaRelation
                                ? '${c.telephone!} • Contact existant'
                                : c.telephone!),
                        onTap: () async {
                          final ctx = ref.read(contexteActifProvider);
                          if (ctx != null && !aLaRelation) {
                            try {
                              await ref.read(modifierContactProvider).ajouterRelation(ctx, c, {widget.relation});
                            } catch (_) {}
                          }
                          if (context.mounted) Navigator.pop(context, c);
                        },
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
