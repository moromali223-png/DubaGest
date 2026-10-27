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
  late final _formController = SmartFormController(initialOpenIndex: 0, allowMultipleOpen: true)..openAll(5);

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
                      // ─── Section 1 : Identité du contact ───
                      CollapsibleFormSection(
                        key: _formController.registerSectionKey(0),
                        title: personne ? 'Identité du contact' : 'Entreprise & Organisation',
                        icon: personne ? Icons.person_rounded : Icons.business_rounded,
                        accentColor: const Color(0xFF01226C),
                        summary: _identiteSummary,
                        status: _identiteStatus,
                        headerTrailing: const _PillBadge(label: 'Requis', isRequired: true),
                        isExpanded: _formController.isSectionOpen(0),
                        onToggle: () => setState(() => _formController.toggleSection(0)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Sélecteur Type Personne / Organisation façon Pillules fluides
                            _TypePersonnePills(
                              selected: _type,
                              onChanged: (t) => setState(() {
                                _type = t;
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
                                decoration: _buildInputDecoration(
                                  label: l10n.contactFieldPrenom,
                                  hint: 'Prénom (ex: Amadou, Fatoumata...)',
                                  icon: Icons.person_outline_rounded,
                                ),
                              ),
                              espace,
                            ],
                            TextFormField(
                              key: const Key('contact-nom'),
                              controller: _nom,
                              textCapitalization: TextCapitalization.words,
                              maxLength: 200,
                              decoration: _buildInputDecoration(
                                label: personne ? l10n.contactFieldNom : l10n.contactFieldRaisonSociale,
                                hint: personne ? 'Nom de famille (ex: Traoré)' : 'Raison sociale (ex: Mali BTP SARL)',
                                icon: personne ? Icons.badge_outlined : Icons.domain_rounded,
                                isRequired: true,
                              ),
                              validator: (v) => (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
                            ),
                          ],
                        ),
                      ),

                      // ─── Section 2 : Relation avec l'entreprise ───
                      CollapsibleFormSection(
                        key: _formController.registerSectionKey(1),
                        title: "Relation avec l'entreprise",
                        icon: Icons.hub_outlined,
                        accentColor: const Color(0xFFDF9540),
                        summary: _relationsSummary(l10n),
                        status: _relationsStatus,
                        headerTrailing: const _PillBadge(label: 'Facultatif', isRequired: false),
                        isExpanded: _formController.isSectionOpen(1),
                        onToggle: () => setState(() => _formController.toggleSection(1)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sélectionnez les rôles de ce contact dans votre activité (cumulables) :',
                              style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.3),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final r in RelationContact.values)
                                  _RelationPillChip(
                                    relation: r,
                                    label: l10n.relationContact(r),
                                    isSelected: _relations.contains(r),
                                    onTap: () => setState(() {
                                      _aEteModifie = true;
                                      if (_relations.contains(r)) {
                                        _relations.remove(r);
                                      } else {
                                        _relations.add(r);
                                      }
                                    }),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // ─── Section 3 : Coordonnées & Téléphone ───
                      CollapsibleFormSection(
                        key: _formController.registerSectionKey(2),
                        title: 'Coordonnées & Téléphone',
                        icon: Icons.phone_in_talk_rounded,
                        accentColor: const Color(0xFF0284C7),
                        summary: _coordonneesSummary,
                        status: _coordonneesStatus,
                        headerTrailing: const _PillBadge(label: 'Facultatif', isRequired: false),
                        isExpanded: _formController.isSectionOpen(2),
                        onToggle: () => setState(() => _formController.toggleSection(2)),
                        child: Column(
                          children: [
                            TextFormField(
                              key: const Key('contact-telephone'),
                              controller: _telephone,
                              keyboardType: TextInputType.phone,
                              maxLength: 30,
                              decoration: _buildInputDecoration(
                                label: l10n.contactFieldTelephone,
                                hint: 'Numéro principal (ex: +223 70 00 00 00)',
                                icon: Icons.phone_outlined,
                              ),
                            ),
                            espace,
                            TextFormField(
                              controller: _whatsapp,
                              keyboardType: TextInputType.phone,
                              maxLength: 30,
                              decoration: _buildInputDecoration(
                                label: l10n.contactFieldWhatsapp,
                                hint: 'WhatsApp direct (ex: +223 70 00 00 00)',
                                helper: l10n.contactWhatsappHint,
                                icon: Icons.chat_bubble_outline_rounded,
                              ),
                            ),
                            espace,
                            TextFormField(
                              key: const Key('contact-email'),
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              maxLength: 254,
                              decoration: _buildInputDecoration(
                                label: l10n.contactFieldEmail,
                                hint: 'Adresse électronique (ex: contact@exemple.com)',
                                icon: Icons.mail_outline_rounded,
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

                      // ─── Section 4 : Adresse & Localisation ───
                      CollapsibleFormSection(
                        key: _formController.registerSectionKey(3),
                        title: 'Adresse & Localisation',
                        icon: Icons.location_on_rounded,
                        accentColor: const Color(0xFF10B981),
                        summary: _adresseSummary,
                        status: _adresseStatus,
                        headerTrailing: const _PillBadge(label: 'Facultatif', isRequired: false),
                        isExpanded: _formController.isSectionOpen(3),
                        onToggle: () => setState(() => _formController.toggleSection(3)),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _ville,
                              textCapitalization: TextCapitalization.words,
                              maxLength: 100,
                              decoration: _buildInputDecoration(
                                label: l10n.contactFieldVille,
                                hint: 'Ville ou commune (ex: Bamako, Ségou...)',
                                icon: Icons.location_city_outlined,
                              ),
                            ),
                            espace,
                            TextFormField(
                              controller: _adresse,
                              maxLength: 300,
                              decoration: _buildInputDecoration(
                                label: l10n.contactFieldAdresse,
                                hint: 'Quartier, rue, porte, repère géographique...',
                                icon: Icons.place_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ─── Section 5 : Notes & Remarques ───
                      CollapsibleFormSection(
                        key: _formController.registerSectionKey(4),
                        title: 'Notes & Remarques',
                        icon: Icons.edit_note_rounded,
                        accentColor: const Color(0xFF8B5CF6),
                        summary: _remarque.text.trim().isEmpty ? 'Aucune note (Facultatif)' : _remarque.text.trim(),
                        status: _notesStatus,
                        headerTrailing: const _PillBadge(label: 'Facultatif', isRequired: false),
                        isExpanded: _formController.isSectionOpen(4),
                        onToggle: () => setState(() => _formController.toggleSection(4)),
                        child: TextFormField(
                          controller: _remarque,
                          maxLines: 4,
                          minLines: 2,
                          maxLength: longueurMaxRemarque,
                          decoration: InputDecoration(
                            labelText: l10n.contactFieldRemarque,
                            hintText: 'Informations complémentaires, préférences, notes utiles...',
                            alignLabelWithHint: true,
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 48),
                              child: Icon(Icons.notes_rounded, size: 20, color: Color(0xFF64748B)),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF01226C), width: 1.8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ─── Barre d'actions fixe ergonomique & anti-clavier ───
              _ContactFormBottomBar(
                onSave: _enCours ? null : _enregistrer,
                onCancel: () => Navigator.of(context).maybePop(),
                isLoading: _enCours,
                saveLabel: l10n.commonSave,
                cancelLabel: l10n.commonCancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── COMPOSANTS MODERNISÉS DUBAGEST CONTACTS ───

InputDecoration _buildInputDecoration({
  required String label,
  String? hint,
  String? helper,
  required IconData icon,
  bool isRequired = false,
}) {
  return InputDecoration(
    labelText: isRequired ? '$label *' : label,
    hintText: hint,
    helperText: helper,
    counterText: '',
    prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF01226C), width: 1.8),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
    ),
  );
}

class _TypePersonnePills extends StatelessWidget {
  const _TypePersonnePills({
    required this.selected,
    required this.onChanged,
  });

  final TypePersonne selected;
  final ValueChanged<TypePersonne> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PillOption(
              label: 'Particulier',
              icon: Icons.person_rounded,
              isSelected: selected == TypePersonne.personne,
              onTap: () => onChanged(TypePersonne.personne),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _PillOption(
              label: 'Organisation / Société',
              icon: Icons.business_rounded,
              isSelected: selected == TypePersonne.organisation,
              onTap: () => onChanged(TypePersonne.organisation),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillOption extends StatelessWidget {
  const _PillOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? const Color(0xFF01226C) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? const Color(0xFF01226C) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  const _PillBadge({required this.label, required this.isRequired});

  final String label;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final bgColor = isRequired ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9);
    final textColor = isRequired ? const Color(0xFFDC2626) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: isRequired ? FontWeight.w800 : FontWeight.w600,
          color: textColor,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _RelationPillChip extends StatelessWidget {
  const _RelationPillChip({
    required this.relation,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final RelationContact relation;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  IconData get _icon => switch (relation) {
        RelationContact.client => Icons.person_pin_circle_outlined,
        RelationContact.fournisseur => Icons.local_shipping_outlined,
        RelationContact.locataire => Icons.vpn_key_outlined,
        RelationContact.proprietaire => Icons.home_work_outlined,
        RelationContact.prestataire => Icons.handyman_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('contact-relation-${relation.code}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF01226C) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF01226C) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF01226C).withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? Icons.check_circle_rounded : _icon,
                size: 16,
                color: isSelected ? const Color(0xFFDF9540) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactFormBottomBar extends StatelessWidget {
  const _ContactFormBottomBar({
    required this.onSave,
    required this.onCancel,
    required this.isLoading,
    required this.saveLabel,
    required this.cancelLabel,
  });

  final VoidCallback? onSave;
  final VoidCallback onCancel;
  final bool isLoading;
  final String saveLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            bottomInset > 0 ? 8 : 12,
          ),
          child: Row(
            children: [
              // Bouton Annuler secondaire
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: isLoading ? null : onCancel,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text(
                    cancelLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF475569),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Bouton Enregistrer principal
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  key: const Key('contact-save'),
                  onPressed: onSave,
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 20),
                  label: Text(
                    saveLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: -0.2,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    backgroundColor: const Color(0xFF01226C),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: const Color(0xFF01226C).withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
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
