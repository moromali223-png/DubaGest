import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/forms/forms.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/contact.dart';
import '../../domain/usecases/gerer_contacts.dart';
import '../providers/contacts_providers.dart';
import '../widgets/contact_avatar.dart';

/// Création ([contactId] nul) ou modification d'un contact.
class ContactFormPage extends ConsumerWidget {
  const ContactFormPage({super.key, this.contactId, this.relation});
  final String? contactId;

  /// Relation cochée d'office à la création (ex. fournisseur depuis un achat).
  final RelationContact? relation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final id = contactId;
    if (id == null) return _Formulaire(initial: null, relation: relation);
    final contact = ref.watch(contactProvider(id));
    if (contact case AsyncData(value: final c?)) return _Formulaire(initial: c);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.contactEdit)),
      body: AsyncValueView(
        value: contact,
        isEmpty: (c) => c == null,
        emptyMessage: l10n.contactNotFound,
        onRetry: () => ref.invalidate(contactProvider(id)),
        data: (_) => const SizedBox.shrink(),
      ),
    );
  }
}

class _Formulaire extends ConsumerStatefulWidget {
  const _Formulaire({required this.initial, this.relation});
  final Contact? initial;
  final RelationContact? relation;

  @override
  ConsumerState<_Formulaire> createState() => _FormulaireState();
}

class _FormulaireState extends ConsumerState<_Formulaire> {
  final _formKey = GlobalKey<FormState>();
  final _formController = SmartFormController(initialOpenIndex: 0);

  late TypePersonne _type = widget.initial?.typePersonne ?? TypePersonne.personne;
  late final Set<RelationContact> _relations = {...?widget.initial?.relations, ?widget.relation};
  late final _nom = TextEditingController(text: widget.initial?.nom);
  late final _prenom = TextEditingController(text: widget.initial?.prenom);
  late final _telephone = TextEditingController(text: widget.initial?.telephone);
  late final _whatsapp = TextEditingController(text: widget.initial?.whatsapp);
  late final _email = TextEditingController(text: widget.initial?.email);
  late final _adresse = TextEditingController(text: widget.initial?.adresse);
  late final _ville = TextEditingController(text: widget.initial?.ville);
  late final _remarque = TextEditingController(text: widget.initial?.remarque);
  bool _enCours = false;
  bool _aEteModifie = false;

  bool get _creation => widget.initial == null;

  @override
  void initState() {
    super.initState();
    for (final c in [_nom, _prenom, _telephone, _whatsapp, _email, _adresse, _ville, _remarque]) {
      c.addListener(() {
        if (!_aEteModifie) setState(() => _aEteModifie = true);
      });
    }
  }

  @override
  void dispose() {
    _formController.dispose();
    for (final c in [_nom, _prenom, _telephone, _whatsapp, _email, _adresse, _ville, _remarque]) {
      c.dispose();
    }
    super.dispose();
  }

  SaisieContact get _saisie => SaisieContact(
        typePersonne: _type,
        nom: _nom.text,
        prenom: _prenom.text,
        telephone: _telephone.text,
        whatsapp: _whatsapp.text,
        email: _email.text,
        adresse: _adresse.text,
        ville: _ville.text,
        remarque: _remarque.text,
        relations: _relations,
      );

  // --- Statuts et Résumés dynamiques des sections ---
  FormSectionStatus get _identiteStatus {
    if (_nom.text.trim().isEmpty) return FormSectionStatus.emptyRequired;
    return FormSectionStatus.complete;
  }

  String get _identiteSummary {
    final nomComplet = [_prenom.text.trim(), _nom.text.trim()].where((s) => s.isNotEmpty).join(' ');
    final typeStr = _type == TypePersonne.personne ? 'Particulier' : 'Organisation';
    if (nomComplet.isEmpty) return 'Nom obligatoire • $typeStr';
    return '$nomComplet • $typeStr';
  }

  FormSectionStatus get _relationsStatus {
    if (_relations.isEmpty) return FormSectionStatus.emptyOptional;
    return FormSectionStatus.complete;
  }

  String _relationsSummary(AppLocalizations l10n) {
    if (_relations.isEmpty) return 'Aucune relation définie (Facultatif)';
    return _relations.map((r) => l10n.relationContact(r)).join(' • ');
  }

  FormSectionStatus get _coordonneesStatus {
    final hasTel = _telephone.text.trim().isNotEmpty;
    final hasEmail = _email.text.trim().isNotEmpty;
    final hasWa = _whatsapp.text.trim().isNotEmpty;
    if (hasTel || hasEmail || hasWa) return FormSectionStatus.complete;
    return FormSectionStatus.emptyOptional;
  }

  String get _coordonneesSummary {
    final elements = [
      if (_telephone.text.trim().isNotEmpty) _telephone.text.trim(),
      if (_whatsapp.text.trim().isNotEmpty) 'WA: ${_whatsapp.text.trim()}',
      if (_email.text.trim().isNotEmpty) _email.text.trim(),
    ];
    if (elements.isEmpty) return 'Téléphone, WhatsApp, Email (Facultatif)';
    return elements.join(' • ');
  }

  FormSectionStatus get _adresseStatus {
    final hasAdr = _adresse.text.trim().isNotEmpty;
    final hasVille = _ville.text.trim().isNotEmpty;
    if (hasAdr || hasVille) return FormSectionStatus.complete;
    return FormSectionStatus.emptyOptional;
  }

  String get _adresseSummary {
    final elements = [
      if (_ville.text.trim().isNotEmpty) _ville.text.trim(),
      if (_adresse.text.trim().isNotEmpty) _adresse.text.trim(),
    ];
    if (elements.isEmpty) return 'Ville, adresse physique (Facultatif)';
    return elements.join(', ');
  }

  FormSectionStatus get _notesStatus {
    if (_remarque.text.trim().isNotEmpty) return FormSectionStatus.complete;
    return FormSectionStatus.emptyOptional;
  }

  Future<void> _enregistrer() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      if (_nom.text.trim().isEmpty) {
        _formController.scrollToSection(0);
      }
      return;
    }
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    try {
      if (_creation) {
        final doublons = await ref.read(detecterDoublonsProvider).call(ctx, _saisie);
        if (doublons.isNotEmpty) {
          if (!mounted) return;
          final choix = await showDialog<_ChoixDoublon>(
            context: context,
            builder: (_) => _DoublonsDialog(doublons: doublons, relations: _relations),
          );
          if (!mounted || choix == null) return;
          setState(() => _enCours = true);
          switch (choix) {
            case _OuvrirFiche(:final contact):
              _aEteModifie = false;
              context.pushReplacement(Routes.contact(contact.id));
              return;
            case _AjouterRelation(:final contact):
              await ref.read(modifierContactProvider).ajouterRelation(ctx, contact, _relations);
              if (!mounted) return;
              _aEteModifie = false;
              showMessageSnackBar(context, context.l10n.contactSaved);
              context.pushReplacement(Routes.contact(contact.id));
              return;
            case _CreerQuandMeme():
          }
        }
        setState(() => _enCours = true);
        final cree = await ref.read(creerContactProvider).call(ctx, _saisie);
        if (!mounted) return;
        _aEteModifie = false;
        showMessageSnackBar(context, context.l10n.contactSaved);
        context.pushReplacement(Routes.contact(cree.id));
      } else {
        setState(() => _enCours = true);
        await ref.read(modifierContactProvider).call(ctx, widget.initial!, _saisie);
        if (!mounted) return;
        _aEteModifie = false;
        showMessageSnackBar(context, context.l10n.contactSaved);
        context.pop();
      }
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final personne = _type == TypePersonne.personne;
    const espace = SizedBox(height: AppSpacing.md);

    return UnsavedChangesScope(
      hasUnsavedChanges: _aEteModifie && !_enCours,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(_creation ? l10n.contactNew : l10n.contactEdit),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SmartFormContainer(
                    controller: _formController,
                    children: [
                      // Section 1 : Identité & Nom (Obligatoire)
                      CollapsibleFormSection(
                        key: _formController.registerSectionKey(0),
                        title: personne ? 'Identité du contact' : 'Entreprise & Organisation',
                        icon: personne ? Icons.person_rounded : Icons.business_rounded,
                        summary: _identiteSummary,
                        status: _identiteStatus,
                        isRequired: true,
                        isExpanded: _formController.isSectionOpen(0),
                        onToggle: () => setState(() => _formController.toggleSection(0)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SegmentedButton<TypePersonne>(
                              segments: [
                                ButtonSegment(
                                  value: TypePersonne.personne,
                                  icon: const Icon(Icons.person_outline),
                                  label: Text(l10n.contactTypePersonne),
                                ),
                                ButtonSegment(
                                  value: TypePersonne.organisation,
                                  icon: const Icon(Icons.business_outlined),
                                  label: Text(l10n.contactTypeOrganisation),
                                ),
                              ],
                              selected: {_type},
                              onSelectionChanged: (s) => setState(() {
                                _type = s.first;
                                _aEteModifie = true;
                              }),
                            ),
                            espace,
                            if (personne) ...[
                              TextFormField(
                                key: const Key('contact-prenom'),
                                controller: _prenom,
                                textCapitalization: TextCapitalization.words,
                                maxLength: 100,
                                decoration: InputDecoration(labelText: l10n.contactFieldPrenom, counterText: ''),
                              ),
                              espace,
                            ],
                            TextFormField(
                              key: const Key('contact-nom'),
                              controller: _nom,
                              textCapitalization: TextCapitalization.words,
                              maxLength: 200,
                              decoration: InputDecoration(
                                labelText: '${personne ? l10n.contactFieldNom : l10n.contactFieldRaisonSociale} *',
                                counterText: '',
                              ),
                              validator: (v) => (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
                            ),
                          ],
                        ),
                      ),

                      // Section 2 : Rôles & Relations (Client, Fournisseur)
                      CollapsibleFormSection(
                        key: _formController.registerSectionKey(1),
                        title: l10n.contactFieldRelations,
                        icon: Icons.groups_rounded,
                        summary: _relationsSummary(l10n),
                        status: _relationsStatus,
                        isExpanded: _formController.isSectionOpen(1),
                        onToggle: () => setState(() => _formController.toggleSection(1)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sélectionnez les rôles de ce contact dans votre activité :',
                              style: TextStyle(fontSize: 13, color: AppColors.muted),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                for (final r in RelationContact.values)
                                  FilterChip(
                                    key: Key('contact-relation-${r.code}'),
                                    label: Text(l10n.relationContact(r)),
                                    selected: _relations.contains(r),
                                    onSelected: (on) => setState(() {
                                      _aEteModifie = true;
                                      on ? _relations.add(r) : _relations.remove(r);
                                    }),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Section 3 : Coordonnées (Téléphone, WhatsApp, Email)
                      CollapsibleFormSection(
                        key: _formController.registerSectionKey(2),
                        title: 'Coordonnées & Téléphone',
                        icon: Icons.contact_phone_rounded,
                        summary: _coordonneesSummary,
                        status: _coordonneesStatus,
                        isExpanded: _formController.isSectionOpen(2),
                        onToggle: () => setState(() => _formController.toggleSection(2)),
                        child: Column(
                          children: [
                            TextFormField(
                              key: const Key('contact-telephone'),
                              controller: _telephone,
                              keyboardType: TextInputType.phone,
                              maxLength: 30,
                              decoration: InputDecoration(
                                labelText: l10n.contactFieldTelephone,
                                prefixIcon: const Icon(Icons.phone_outlined),
                                counterText: '',
                              ),
                            ),
                            espace,
                            TextFormField(
                              controller: _whatsapp,
                              keyboardType: TextInputType.phone,
                              maxLength: 30,
                              decoration: InputDecoration(
                                labelText: l10n.contactFieldWhatsapp,
                                helperText: l10n.contactWhatsappHint,
                                prefixIcon: const Icon(Icons.chat_outlined),
                                counterText: '',
                              ),
                            ),
                            espace,
                            TextFormField(
                              key: const Key('contact-email'),
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              maxLength: 254,
                              decoration: InputDecoration(
                                labelText: l10n.contactFieldEmail,
                                prefixIcon: const Icon(Icons.mail_outline),
                                counterText: '',
                              ),
                              validator: (v) {
                                final t = (v ?? '').trim();
                                return t.isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                                    ? null
                                    : l10n.validationEmail;
                              },
                            ),
                          ],
                        ),
                      ),

                      // Section 4 : Adresse & Localisation
                      CollapsibleFormSection(
                        key: _formController.registerSectionKey(3),
                        title: 'Adresse & Localisation',
                        icon: Icons.location_on_rounded,
                        summary: _adresseSummary,
                        status: _adresseStatus,
                        isExpanded: _formController.isSectionOpen(3),
                        onToggle: () => setState(() => _formController.toggleSection(3)),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _ville,
                              textCapitalization: TextCapitalization.words,
                              maxLength: 100,
                              decoration: InputDecoration(
                                labelText: l10n.contactFieldVille,
                                prefixIcon: const Icon(Icons.location_city_outlined),
                                counterText: '',
                              ),
                            ),
                            espace,
                            TextFormField(
                              controller: _adresse,
                              maxLength: 300,
                              decoration: InputDecoration(
                                labelText: l10n.contactFieldAdresse,
                                prefixIcon: const Icon(Icons.place_outlined),
                                counterText: '',
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Section 5 : Remarques & Notes
                      CollapsibleFormSection(
                        key: _formController.registerSectionKey(4),
                        title: 'Notes & Remarques',
                        icon: Icons.note_alt_rounded,
                        summary: _remarque.text.trim().isEmpty ? 'Aucune note (Facultatif)' : _remarque.text.trim(),
                        status: _notesStatus,
                        isExpanded: _formController.isSectionOpen(4),
                        onToggle: () => setState(() => _formController.toggleSection(4)),
                        child: TextFormField(
                          controller: _remarque,
                          maxLines: 4,
                          minLines: 2,
                          maxLength: longueurMaxRemarque,
                          decoration: InputDecoration(
                            labelText: l10n.contactFieldRemarque,
                            hintText: 'Informations complémentaires, préférences...',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Barre d'actions fixe
              StickyFormActions(
                submitKey: const Key('contact-save'),
                onSubmit: _enCours ? null : _enregistrer,
                onCancel: () => Navigator.of(context).maybePop(),
                isLoading: _enCours,
                submitLabel: l10n.commonSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

sealed class _ChoixDoublon {
  const _ChoixDoublon();
}

class _OuvrirFiche extends _ChoixDoublon {
  const _OuvrirFiche(this.contact);
  final Contact contact;
}

class _AjouterRelation extends _ChoixDoublon {
  const _AjouterRelation(this.contact);
  final Contact contact;
}

class _CreerQuandMeme extends _ChoixDoublon {
  const _CreerQuandMeme();
}

/// « Cette personne existe peut-être déjà » : on propose d'utiliser la fiche
/// existante (en lui ajoutant la relation) plutôt que d'en créer une seconde.
class _DoublonsDialog extends StatelessWidget {
  const _DoublonsDialog({required this.doublons, required this.relations});
  final List<Contact> doublons;
  final Set<RelationContact> relations;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      key: const Key('contact-duplicates'),
      title: Text(l10n.contactDuplicateTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.contactDuplicateMessage(doublons.length)),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in doublons.take(5))
                    Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListTile(
                            leading: ContactAvatar(contact: c),
                            title: Text(c.nomAffiche),
                            subtitle: Text([
                              ...c.relations.map(l10n.relationContact),
                              if (c.telephone != null) c.telephone!,
                            ].join(' · ')),
                          ),
                          OverflowBar(
                            alignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, _OuvrirFiche(c)),
                                child: Text(l10n.contactDuplicateOpen),
                              ),
                              if (relations.isNotEmpty && !c.relations.containsAll(relations))
                                TextButton(
                                  key: Key('contact-duplicate-add-${c.id}'),
                                  onPressed: () => Navigator.pop(context, _AjouterRelation(c)),
                                  child: Text(l10n.contactDuplicateAddRelation),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
        FilledButton(
          key: const Key('contact-duplicate-create'),
          onPressed: () => Navigator.pop(context, const _CreerQuandMeme()),
          child: Text(l10n.contactDuplicateCreateAnyway),
        ),
      ],
    );
  }
}
