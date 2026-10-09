import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/localization/locale_controller.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/profil_entreprise.dart';
import '../providers/contexte_providers.dart';

/// Fiche de l'entreprise : identité, coordonnées, informations légales,
/// préférences. Modifiable avec `entreprise.manage`, sinon en lecture seule.
class EntreprisePage extends ConsumerWidget {
  const EntreprisePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profil = ref.watch(profilEntrepriseProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.moduleAdminEntreprise)),
      body: ResponsiveBody(
        child: AsyncValueView<ProfilEntreprise?>(
          value: profil,
          onRetry: () => ref.invalidate(profilEntrepriseProvider),
          data: (p) => p == null ? const SizedBox.shrink() : _Formulaire(profil: p),
        ),
      ),
    );
  }
}

class _Formulaire extends ConsumerStatefulWidget {
  const _Formulaire({required this.profil});
  final ProfilEntreprise profil;

  @override
  ConsumerState<_Formulaire> createState() => _FormulaireState();
}

class _FormulaireState extends ConsumerState<_Formulaire> {
  final _formKey = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.profil.nom);
  late final _telephone = TextEditingController(text: widget.profil.telephone);
  late final _adresse = TextEditingController(text: widget.profil.adresse);
  late final _ville = TextEditingController(text: widget.profil.ville);
  late final _pays = TextEditingController(text: widget.profil.pays);
  late final _nif = TextEditingController(text: widget.profil.identifiantFiscal);
  late final _rccm = TextEditingController(text: widget.profil.registreCommerce);
  late String _devise = widget.profil.devise;
  late String _langue = widget.profil.langueDocuments;
  bool _envoi = false;
  bool _envoiLogo = false;

  /// Logo : PNG, JPEG ou WEBP, 2 Mo au plus ; envoi en ligne.
  Future<void> _changerLogo() async {
    final x = await openFile(acceptedTypeGroups: [
      XTypeGroup(
        label: context.l10n.entrepriseLogoTypes,
        extensions: const ['png', 'jpg', 'jpeg', 'webp'],
        mimeTypes: const ['image/png', 'image/jpeg', 'image/webp'],
      ),
    ]);
    if (x == null) return;
    setState(() => _envoiLogo = true);
    try {
      final ext = x.name.split('.').last.toLowerCase();
      final type = x.mimeType ?? (ext == 'png' ? 'image/png' : ext == 'webp' ? 'image/webp' : 'image/jpeg');
      await ref.read(logoEntrepriseServiceProvider).envoyer(widget.profil.id, await x.readAsBytes(), type);
      ref.invalidate(profilEntrepriseProvider);
      ref.invalidate(logoEntrepriseProvider);
      if (mounted) showMessageSnackBar(context, context.l10n.entrepriseLogoSaved);
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _envoiLogo = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_nom, _telephone, _adresse, _ville, _pays, _nif, _rccm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    setState(() => _envoi = true);
    try {
      await ref.read(modifierProfilEntrepriseProvider).call(
            ctx,
            widget.profil.copyWith(
              nom: _nom.text,
              telephone: _telephone.text,
              adresse: _adresse.text,
              ville: _ville.text,
              pays: _pays.text,
              identifiantFiscal: _nif.text,
              registreCommerce: _rccm.text,
              devise: _devise,
              langueDocuments: _langue,
            ),
          );
      ref.invalidate(profilEntrepriseProvider);
      await ref.read(contexteSessionProvider.notifier).rafraichir();
      if (mounted) showMessageSnackBar(context, context.l10n.entrepriseSaved);
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ctx = ref.watch(contexteActifProvider);
    final modifiable = ctx != null && ref.watch(modifierProfilEntrepriseProvider).peutModifier(ctx);
    final initiales = widget.profil.nom.trim().split(RegExp(r'\s+')).take(2)
        .map((m) => m.characters.first.toUpperCase()).join();

    Widget champ(TextEditingController c, String label,
            {TextInputType? clavier, int max = 120, String? Function(String?)? validator}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: TextFormField(
            controller: c,
            readOnly: !modifiable,
            keyboardType: clavier,
            maxLength: max,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            decoration: InputDecoration(labelText: label),
            validator: validator,
          ),
        );

    Widget section(String titre, List<Widget> enfants) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(titre, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.md),
                  ...enfants,
                ],
              ),
            ),
          ),
        );

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          section(l10n.entrepriseIdentity, [
            Row(
              children: [
                if (ref.watch(logoEntrepriseProvider).value case final logo?)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(logo, key: const Key('logo-entreprise'), width: 56, height: 56, fit: BoxFit.contain),
                  )
                else
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.green,
                    child: Text(initiales,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                  ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(l10n.entrepriseLogoHint, style: Theme.of(context).textTheme.bodySmall),
                ),
                if (modifiable)
                  TextButton(
                    key: const Key('logo-changer'),
                    onPressed: _envoiLogo ? null : _changerLogo,
                    child: _envoiLogo
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l10n.entrepriseLogoChange),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            champ(_nom, l10n.entrepriseName,
                validator: (v) => (v ?? '').trim().length < 2 ? l10n.ruleNameInvalid : null),
          ]),
          section(l10n.entrepriseContact, [
            champ(_telephone, l10n.entreprisePhone, clavier: TextInputType.phone, max: 30),
            champ(_adresse, l10n.entrepriseAddress, max: 200),
            champ(_ville, l10n.entrepriseCity, max: 80),
            champ(_pays, l10n.entrepriseCountry,
                max: 2,
                validator: (v) => (v ?? '').trim().isEmpty || RegExp(r'^[A-Za-z]{2}$').hasMatch(v!.trim())
                    ? null
                    : l10n.entrepriseCountry),
          ]),
          section(l10n.entrepriseLegal, [
            champ(_nif, l10n.entrepriseTaxId, max: 40),
            champ(_rccm, l10n.entrepriseTradeRegister, max: 40),
          ]),
          section(l10n.entreprisePreferences, [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: DropdownButtonFormField<String>(
                key: const Key('entreprise-devise'),
                initialValue: _devise,
                decoration: InputDecoration(labelText: l10n.entrepriseCurrency),
                items: [
                  for (final d in {...ProfilEntreprise.devises, _devise})
                    DropdownMenuItem(value: d, child: Text(d == 'XOF' ? 'XOF (FCFA)' : d)),
                ],
                onChanged: modifiable ? (v) => setState(() => _devise = v!) : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: DropdownButtonFormField<String>(
                initialValue: _langue,
                decoration: InputDecoration(labelText: l10n.entrepriseDocLanguage),
                items: [
                  for (final l in AppLocales.supported)
                    DropdownMenuItem(
                      value: l.languageCode,
                      child: Text(switch (l.languageCode) {
                        'ar' => l10n.languageArabic,
                        'en' => l10n.languageEnglish,
                        _ => l10n.languageFrench,
                      }),
                    ),
                ],
                onChanged: modifiable ? (v) => setState(() => _langue = v!) : null,
              ),
            ),
          ]),
          if (modifiable)
            FilledButton(
              key: const Key('entreprise-save'),
              onPressed: _envoi ? null : _enregistrer,
              child: Text(l10n.commonSave),
            ),
        ],
      ),
    );
  }
}
