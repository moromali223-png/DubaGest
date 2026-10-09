import 'package:flutter/material.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../domain/entities/perimetre.dart';
import '../../domain/services/boutiques_naming_service.dart';

class PerimetreFormResult {
  const PerimetreFormResult({
    required this.activite,
    required this.type,
    required this.nom,
    required this.code,
    required this.estActif,
    this.supprimer = false,
  });

  final ActiviteCode activite;
  final PerimetreType type;
  final String nom;
  final String? code;
  final bool estActif;
  final bool supprimer;
}

/// Formulaire en feuille modale pour Ajouter ou Modifier une Boutique / Périmètre.
Future<PerimetreFormResult?> showPerimetreFormSheet(
  BuildContext context, {
  required List<ActiviteCode> activites,
  required PerimetreType Function(ActiviteCode) typeParDefaut,
  List<Perimetre> existants = const [],
  Perimetre? initial,
}) =>
    showModalBottomSheet<PerimetreFormResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _PerimetreForm(
        activites: activites,
        typeParDefaut: typeParDefaut,
        existants: existants,
        initial: initial,
      ),
    );

class _PerimetreForm extends StatefulWidget {
  const _PerimetreForm({
    required this.activites,
    required this.typeParDefaut,
    this.existants = const [],
    this.initial,
  });

  final List<ActiviteCode> activites;
  final PerimetreType Function(ActiviteCode) typeParDefaut;
  final List<Perimetre> existants;
  final Perimetre? initial;

  @override
  State<_PerimetreForm> createState() => _PerimetreFormState();
}

class _PerimetreFormState extends State<_PerimetreForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nom;
  late final TextEditingController _code;
  late ActiviteCode _activite;
  late PerimetreType _type;
  late bool _estActif;

  bool get _edition => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _activite = widget.initial?.activite ?? widget.activites.first;
    _type = widget.initial?.type ?? widget.typeParDefaut(_activite);
    _estActif = widget.initial?.estActif ?? true;

    if (_edition) {
      _nom = TextEditingController(text: widget.initial?.nom);
      _code = TextEditingController(text: widget.initial?.code);
    } else {
      // Suggestion séquentielle automatique (Boutique A, Boutique B, SHOP-001...)
      final suggestion = BoutiquesNamingService.suggestionSuivante(
        widget.existants,
        activite: _activite,
        type: _type,
      );
      _nom = TextEditingController(text: suggestion.nom);
      _code = TextEditingController(text: suggestion.code);
    }
  }

  @override
  void dispose() {
    _nom.dispose();
    _code.dispose();
    super.dispose();
  }

  void _submit({bool supprimer = false}) {
    if (!supprimer && !_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(PerimetreFormResult(
      activite: _activite,
      type: _type,
      nom: _nom.text.trim(),
      code: _code.text.trim().isNotEmpty ? _code.text.trim() : null,
      estActif: _estActif,
      supprimer: supprimer,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF01226C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _type == PerimetreType.boutique ? Icons.storefront_rounded : Icons.place_rounded,
                      color: const Color(0xFF01226C),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _edition ? 'Modifier la boutique' : 'Ajouter une boutique',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                        Text(
                          _edition
                              ? 'Personnalisez le nom affiché ou le statut'
                              : 'Nom par défaut suggéré (modifiable à tout moment)',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Activité
              DropdownButtonFormField<ActiviteCode>(
                initialValue: _activite,
                decoration: InputDecoration(
                  labelText: l10n.perimetreActivity,
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
                items: [
                  for (final a in widget.activites)
                    DropdownMenuItem(value: a, child: Text(l10n.activite(a))),
                ],
                onChanged: _edition
                    ? null
                    : (a) {
                        if (a == null) return;
                        setState(() {
                          _activite = a;
                          _type = widget.typeParDefaut(a);
                          final sug = BoutiquesNamingService.suggestionSuivante(
                            widget.existants,
                            activite: _activite,
                            type: _type,
                          );
                          _nom.text = sug.nom;
                          _code.text = sug.code;
                        });
                      },
              ),
              const SizedBox(height: AppSpacing.md),

              // Type de périmètre (Boutique, Agence, etc.)
              DropdownButtonFormField<PerimetreType>(
                initialValue: _type,
                decoration: InputDecoration(
                  labelText: l10n.perimetreType,
                  prefixIcon: const Icon(Icons.business_outlined),
                ),
                items: [
                  for (final t in PerimetreType.values)
                    DropdownMenuItem(value: t, child: Text(l10n.typePerimetre(t))),
                ],
                onChanged: (t) {
                  if (t == null) return;
                  setState(() => _type = t);
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Nom de la boutique
              TextFormField(
                controller: _nom,
                autofocus: !_edition,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nom de la boutique *',
                  hintText: 'Ex: Boutique Centrale ou Boutique A',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                validator: (v) => (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // Code interne
              TextFormField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: 'Code interne (Optionnel)',
                  hintText: 'Ex: SHOP-001, BOU-A',
                  prefixIcon: Icon(Icons.tag_rounded),
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Toggle statut actif
              if (_edition)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _estActif ? 'Boutique active' : 'Boutique désactivée',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _estActif
                        ? 'Visible dans les opérations quotidiennes'
                        : 'Masquée des sélections de nouvelles ventes et caisses',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  value: _estActif,
                  onChanged: (v) => setState(() => _estActif = v),
                ),
              const SizedBox(height: AppSpacing.md),

              // Bouton Enregistrer
              FilledButton(
                key: const Key('perimetre-submit'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF01226C),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _submit,
                child: Text(_edition ? l10n.commonSave : 'Enregistrer la boutique'),
              ),
              if (_edition) ...[
                const SizedBox(height: AppSpacing.sm),
                TextButton.icon(
                  onPressed: () => _submit(supprimer: true),
                  icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                  label: Text(
                    'Supprimer cette boutique',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
