import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/forms/forms.dart';
import '../../../commerce/presentation/widgets/commerce_widgets.dart' show montant;
import '../../../contacts/domain/entities/contact.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../entreprise/presentation/providers/espace_providers.dart';
import '../../domain/entities/metier_template.dart';
import '../../domain/entities/prestation.dart';
import '../../domain/entities/service_catalogue.dart';
import '../services_providers.dart';
import '../widgets/devis_contact_widgets.dart';
import '../widgets/form_kit.dart';

final _fmtDate = DateFormat('dd/MM/yyyy');

enum _TypeRemise { montant, pourcentage }

/// Conditions de règlement les plus courantes, applicables en un clic.
const _conditionsTypes = <String, String>{
  'Acompte 30 %': 'Acompte de 30 % à la commande, solde à la fin des travaux.',
  'Acompte 50 %': 'Acompte de 50 % à la commande, solde à la livraison.',
  'À réception': 'Paiement intégral à la réception des travaux.',
  '30 jours': 'Paiement à 30 jours date d\'émission de la facture.',
};

const _dureesValidite = [15, 30, 60, 90];
const _nbEtapes = 3;

/// Formulaire de création d'un devis professionnel DubaGest.
///
/// 3 étapes numérotées : 1 Client & objet · 2 Prestations & prix · 3 Validité & règlement.
class DevisFormPage extends ConsumerStatefulWidget {
  const DevisFormPage({super.key, this.initialContactId});
  final String? initialContactId;

  @override
  ConsumerState<DevisFormPage> createState() => _DevisFormPageState();
}

class _DevisFormPageState extends ConsumerState<DevisFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _formController = SmartFormController(initialOpenIndex: 0);

  final _titreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _remiseCtrl = TextEditingController(text: '0');
  final _conditionsCtrl = TextEditingController();

  String? _contactId;
  MetierCode _metierSelectionne = MetierCode.generique;
  final Map<String, dynamic> _champsMetier = {};
  final Map<String, TextEditingController> _champsMetierCtrls = {};

  DateTime _dateEmission = DateUtils.dateOnly(DateTime.now());
  DateTime? _dateValidite = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 30));

  final List<LignePrestation> _lignes = [];
  _TypeRemise _typeRemise = _TypeRemise.montant;
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    _contactId = widget.initialContactId;
    _titreCtrl.text = _titreDefaut;
  }

  @override
  void dispose() {
    _formController.dispose();
    _titreCtrl.dispose();
    _descCtrl.dispose();
    _remiseCtrl.dispose();
    _conditionsCtrl.dispose();
    for (final c in _champsMetierCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------- Calculs & état

  String get _titreDefaut => 'Devis — ${MetierTemplate.templatePour(_metierSelectionne).titreParDefaut}';

  int get _sousTotal => _lignes.fold<int>(0, (sum, l) => sum + l.totalLigne);

  double get _saisieRemise =>
      double.tryParse(_remiseCtrl.text.trim().replaceAll(',', '.').replaceAll(' ', '')) ?? 0;

  /// Remise toujours exprimée en FCFA (garantie non négative et plafonnée).
  int get _remise {
    final v = _saisieRemise;
    if (v <= 0) return 0;
    final brut = _typeRemise == _TypeRemise.pourcentage ? (_sousTotal * v / 100).round() : v.round();
    return brut.clamp(0, _sousTotal);
  }

  int get _total => (_sousTotal - _remise).clamp(0, 1000000000000);

  int? get _joursValidite => _dateValidite?.difference(_dateEmission).inDays;

  bool get _etape1Faite => _titreCtrl.text.trim().length >= 3;
  bool get _etape2Faite => _lignes.isNotEmpty;
  bool get _etape3Faite => _conditionsCtrl.text.trim().isNotEmpty;

  int get _etapesFaites => (_etape1Faite ? 1 : 0) + (_etape2Faite ? 1 : 0) + (_etape3Faite ? 1 : 0);

  /// Vrai seulement si l'utilisateur a réellement modifié quelque chose
  /// (le titre pré-rempli par défaut n'est pas une modification).
  bool get _aDesModifications =>
      _contactId != widget.initialContactId ||
      _titreCtrl.text.trim() != _titreDefaut ||
      _descCtrl.text.trim().isNotEmpty ||
      _conditionsCtrl.text.trim().isNotEmpty ||
      _lignes.isNotEmpty;

  // ---------------------------------------------------------------- Actions

  void _changerModeleMetier(MetierCode code) {
    setState(() {
      final ancienTitreDefaut = _titreDefaut;
      _metierSelectionne = code;
      final template = MetierTemplate.templatePour(code);
      final titreActuel = _titreCtrl.text.trim();

      // Met à jour l'intitulé si l'utilisateur n'avait pas tapé un titre personnalisé
      if (titreActuel.isEmpty || titreActuel == ancienTitreDefaut || titreActuel == 'Devis de prestation') {
        _titreCtrl.text = _titreDefaut;
      }

      for (final f in template.champs) {
        _champsMetierCtrls.putIfAbsent(
          f.cle,
          () => TextEditingController(text: _champsMetier[f.cle]?.toString() ?? ''),
        );
      }
    });
  }

  Future<void> _choisirDateEmission() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dateEmission,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
    );
    if (d == null) return;
    setState(() {
      final duree = _dateValidite?.difference(_dateEmission).inDays ?? 30;
      _dateEmission = DateUtils.dateOnly(d);
      _dateValidite = _dateEmission.add(Duration(days: duree < 1 ? 30 : duree));
    });
  }

  Future<void> _choisirDateValidite() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dateValidite ?? _dateEmission.add(const Duration(days: 30)),
      firstDate: _dateEmission,
      lastDate: DateTime.now().add(const Duration(days: 730)),
      locale: const Locale('fr', 'FR'),
    );
    if (d != null) setState(() => _dateValidite = DateUtils.dateOnly(d));
  }

  Future<void> _ouvrirLigne(List<ServiceCatalogue> catalogue, {int? index}) async {
    final ligne = await showModalBottomSheet<LignePrestation>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LigneSheet(
        catalogue: catalogue,
        existante: index != null ? _lignes[index] : null,
      ),
    );
    if (ligne == null || !mounted) return;
    setState(() {
      if (index != null) {
        _lignes[index] = ligne;
      } else {
        _lignes.add(ligne);
      }
    });
  }

  /// Ajout en un clic d'un service du catalogue (quantité 1, prix du catalogue).
  void _ajouterDepuisCatalogue(ServiceCatalogue s) {
    HapticFeedback.selectionClick();
    setState(() {
      _lignes.add(LignePrestation(
        id: const Uuid().v4(),
        serviceId: s.id,
        libelle: s.nom,
        quantite: 1.0,
        prixUnitaire: s.prix,
      ));
    });
  }

  void _supprimerLigne(int i) {
    final ligne = _lignes[i];
    setState(() => _lignes.removeAt(i));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('« ${ligne.libelle} » retirée'),
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () {
            if (!mounted) return;
            setState(() => _lignes.insert(i.clamp(0, _lignes.length), ligne));
          },
        ),
      ));
  }

  Future<bool> _confirmer({
    required String titre,
    required String message,
    required String confirmer,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titre),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmer),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _enregistrer() async {
    FocusScope.of(context).unfocus();
    if (_envoi) return;

    if (!_formKey.currentState!.validate()) {
      showFailureSnackBar(context, 'Veuillez vérifier les informations saisies.');
      return;
    }

    final lignes = List<LignePrestation>.of(_lignes);
    if (lignes.isEmpty) {
      if (_titreCtrl.text.trim().isNotEmpty) {
        lignes.add(LignePrestation(
          id: const Uuid().v4(),
          libelle: _titreCtrl.text.trim(),
          quantite: 1.0,
          prixUnitaire: 0,
        ));
      } else {
        showFailureSnackBar(context, 'Ajoutez au moins une prestation chiffrée.');
        return;
      }
    }

    if (_total <= 0) {
      final ok = await _confirmer(
        titre: 'Devis à 0 FCFA',
        message: 'Ce devis n\'a aucun montant chiffré. Voulez-vous tout de même l\'enregistrer ?',
        confirmer: 'Enregistrer quand même',
      );
      if (!ok || !mounted) return;
    }

    final ctx = ref.read(contexteActifProvider);
    final espace = ref.read(espaceCourantProvider);
    final entrepriseId = ctx?.entreprise?.id;
    if (entrepriseId == null) {
      showFailureSnackBar(context, 'Entreprise non connectée. Impossible d\'enregistrer le devis.');
      return;
    }

    // Filtrer les champs techniques renseignés
    final template = MetierTemplate.templatePour(_metierSelectionne);
    final champsMetier = <String, dynamic>{
      for (final f in template.champs)
        if (_champsMetier[f.cle] != null && _champsMetier[f.cle].toString().trim().isNotEmpty)
          f.cle: _champsMetier[f.cle],
    };

    setState(() => _envoi = true);
    try {
      final now = DateTime.now();
      final numero =
          'DEV-${now.year}${now.month.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(7)}';

      final devisCree = await ref.read(gererServicesProvider).creerDevis(
            entrepriseId: entrepriseId,
            numero: numero,
            perimetreId: espace.perimetreId,
            contactId: _contactId,
            metierCode: _metierSelectionne,
            champsMetier: champsMetier,
            titre: _titreCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            lignes: lignes,
            remise: _remise,
            dateEmission: _dateEmission,
            dateValidite: _dateValidite,
            conditions: _conditionsCtrl.text.trim(),
            photos: const [],
          );

      if (!mounted) return;
      ref.invalidate(devisServicesProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Devis ${devisCree.numero} créé avec succès (${montant(context, ref, _total)})'),
          action: SnackBarAction(
            label: 'Consulter',
            textColor: AppColors.gold,
            onPressed: () => context.push(Routes.devis(devisCree.id)),
          ),
        ),
      );
      context.pop();
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  // ---------------------------------------------------------------- Client / prospect

  Future<void> _ouvrirSelecteurContact(BuildContext context, List<Contact> contacts) async {
    final choix = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ModalChoixContactDevis(
        contacts: contacts,
        contactActuelId: _contactId,
        onCreerRapide: (nomRecherche) => Navigator.of(context).pop(('CREER', nomRecherche)),
      ),
    );

    if (!mounted || choix == null) return;
    if (choix == 'AUCUN') {
      setState(() => _contactId = null);
    } else if (choix is (String, String?)) {
      final (_, nom) = choix;
      await _ouvrirCreationContactRapide(nom);
    } else if (choix is Contact) {
      setState(() => _contactId = choix.id);
    }
  }

  Future<void> _ouvrirCreationContactRapide([String? nomInitial]) async {
    final nouveau = await showDialog<Contact?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogueNouveauContactDevis(nomInitial: nomInitial),
    );
    if (!mounted || nouveau == null) return;
    setState(() => _contactId = nouveau.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contact « ${nouveau.nomAffiche} » créé et sélectionné'),
        backgroundColor: AppColors.navy,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------- Interface

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(servicesCatalogueProvider).value ?? const <ServiceCatalogue>[];
    final contacts = ref.watch(contactsProvider).value ?? const <Contact>[];
    final templateCourant = MetierTemplate.templatePour(_metierSelectionne);

    final Contact? contactSelectionne = _contactId == null
        ? null
        : contacts.where((c) => c.id == _contactId).firstOrNull ??
            ref.watch(contactProvider(_contactId!)).value;

    final sousTitreValidite = _dateValidite == null
        ? 'Émis le ${_fmtDate.format(_dateEmission)} · sans date limite'
        : 'Émis le ${_fmtDate.format(_dateEmission)} · valable $_joursValidite jours';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _envoi) return;
        final nav = Navigator.of(context);
        final quitter = !_aDesModifications ||
            await _confirmer(
              titre: 'Quitter sans enregistrer ?',
              message: 'Les données saisies pour ce devis ne seront pas conservées.',
              confirmer: 'Quitter',
            );
        if (!mounted) return;
        if (quitter) nav.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Nouveau devis'), centerTitle: false),
        bottomNavigationBar: _BarreTotal(
          remise: _remise,
          total: _total,
          envoi: _envoi,
          onEnregistrer: _enregistrer,
        ),
        body: ResponsiveBody(
          maxWidth: 720,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _EnteteProgression(faites: _etapesFaites, total: _nbEtapes),
                const SizedBox(height: 14),

                // ───────── ÉTAPE 1 : Client & objet
                NumberedSection(
                  number: 1,
                  title: 'Client & objet du devis',
                  subtitle: contactSelectionne != null
                      ? 'Client sélectionné · ${_metierSelectionne.libelle}'
                      : 'Client non renseigné (devis libre)',
                  done: _etape1Faite,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionClientProspect(
                        selectedContact: contactSelectionne,
                        onChoisir: () => _ouvrirSelecteurContact(context, contacts),
                        onCreerNouveau: () => _ouvrirCreationContactRapide(),
                        onRetirer: () => setState(() => _contactId = null),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<MetierCode>(
                        value: _metierSelectionne,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Type de prestation',
                          prefixIcon: Icon(Icons.handyman_outlined, color: AppColors.navy),
                        ),
                        items: [
                          for (final m in MetierCode.values)
                            DropdownMenuItem(
                              value: m,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(m.icone, size: 18, color: AppColors.navy),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      m.libelle,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        onChanged: (code) {
                          if (code != null) _changerModeleMetier(code);
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _titreCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        maxLength: 120,
                        decoration: const InputDecoration(
                          labelText: 'Objet du devis *',
                          hintText: 'Ex. Installation électrique maison, Pose tuyauterie...',
                          counterText: '',
                        ),
                        validator: (v) {
                          final t = v?.trim() ?? '';
                          if (t.isEmpty) return 'Indiquez l\'objet du devis, par exemple « Installation électrique »';
                          if (t.length < 3) return 'Précisez un peu l\'objet (au moins 3 caractères)';
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      const FieldHint('Ce titre apparaît en tête du devis remis à votre client.'),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _descCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description des travaux (facultative)',
                          hintText: 'Périmètre, spécificités, exclusions...',
                        ),
                      ),
                    ],
                  ),
                ),

                // Détails techniques métier (facultatif, repliés)
                if (templateCourant.champs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _CarteCard(
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(top: 8),
                        leading: Icon(templateCourant.code.icone, color: AppColors.navy, size: 20),
                        title: Text(
                          'Détails techniques (${templateCourant.code.libelle})',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                        subtitle: const Text(
                          'Facultatif — dimensions, nature d\'ouvrage, etc.',
                          style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                        ),
                        children: [
                          for (final champ in templateCourant.champs) ...[
                            if (champ.options.isNotEmpty)
                              DropdownButtonFormField<String>(
                                value: champ.options.contains(_champsMetier[champ.cle])
                                    ? _champsMetier[champ.cle] as String
                                    : null,
                                isExpanded: true,
                                decoration: InputDecoration(labelText: champ.libelle, hintText: champ.hint),
                                items: [
                                  for (final opt in champ.options) DropdownMenuItem(value: opt, child: Text(opt)),
                                ],
                                onChanged: (val) => setState(() => _champsMetier[champ.cle] = val),
                              )
                            else
                              TextFormField(
                                controller: _champsMetierCtrls[champ.cle] ??=
                                    TextEditingController(text: _champsMetier[champ.cle]?.toString() ?? ''),
                                keyboardType: champ.type,
                                decoration: InputDecoration(labelText: champ.libelle, hintText: champ.hint),
                                onChanged: (val) => _champsMetier[champ.cle] = val.trim(),
                              ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // ───────── ÉTAPE 2 : Prestations & prix
                NumberedSection(
                  number: 2,
                  title: _lignes.isEmpty ? 'Prestations & prix' : 'Prestations chiffrées (${_lignes.length})',
                  subtitle: _lignes.isEmpty
                      ? 'Aucune ligne pour le moment'
                      : '${_lignes.length} ligne(s) · sous-total ${montant(context, ref, _sousTotal)}',
                  done: _etape2Faite,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (catalogue.isNotEmpty) ...[
                        const Text(
                          'AJOUT RAPIDE DEPUIS VOTRE CATALOGUE',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.muted,
                            letterSpacing: .6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final s in catalogue.take(6))
                              ActionChip(
                                avatar: const Icon(Icons.add_rounded, size: 16, color: AppColors.navy),
                                label: Text(s.nom, style: const TextStyle(fontSize: 11.5)),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _ajouterDepuisCatalogue(s),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (_lignes.isEmpty)
                        _LignesVides(onAjouter: () => _ouvrirLigne(catalogue))
                      else ...[
                        const _EnteteLignes(),
                        for (int i = 0; i < _lignes.length; i++)
                          _LigneItem(
                            numero: i + 1,
                            ligne: _lignes[i],
                            onModifier: () => _ouvrirLigne(catalogue, index: i),
                            onSupprimer: () => _supprimerLigne(i),
                          ),
                        const FieldHint(
                          'Touchez une ligne pour la modifier, glissez-la vers la gauche pour la retirer.',
                          icon: Icons.swipe_left_alt_rounded,
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.navy,
                            side: const BorderSide(color: AppColors.navy),
                            minimumSize: const Size.fromHeight(44),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Ajouter une ligne'),
                          onPressed: () => _ouvrirLigne(catalogue),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _remiseCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                              decoration: InputDecoration(
                                labelText: 'Remise commerciale (facultative)',
                                prefixIcon: const Icon(Icons.discount_outlined),
                                suffixText: _typeRemise == _TypeRemise.pourcentage ? '%' : 'FCFA',
                                helperText: _remise > 0 ? 'Déduction : − ${montant(context, ref, _remise)}' : null,
                              ),
                              validator: (_) {
                                final v = _saisieRemise;
                                if (v < 0) return 'Remise invalide';
                                if (_typeRemise == _TypeRemise.pourcentage && v > 100) return 'Maximum 100 %';
                                if (_typeRemise == _TypeRemise.montant && v > _sousTotal && _sousTotal > 0) {
                                  return 'La remise dépasse le sous-total';
                                }
                                return null;
                              },
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: SegmentedButton<_TypeRemise>(
                              showSelectedIcon: false,
                              style: const ButtonStyle(visualDensity: VisualDensity.compact),
                              segments: const [
                                ButtonSegment(value: _TypeRemise.montant, label: Text('FCFA')),
                                ButtonSegment(value: _TypeRemise.pourcentage, label: Text('%')),
                              ],
                              selected: {_typeRemise},
                              onSelectionChanged: (s) => setState(() => _typeRemise = s.first),
                            ),
                          ),
                        ],
                      ),
                      if (_lignes.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _Recapitulatif(sousTotal: _sousTotal, remise: _remise, total: _total),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ───────── ÉTAPE 3 : Validité & règlement
                NumberedSection(
                  number: 3,
                  title: 'Validité & règlement',
                  subtitle: sousTitreValidite,
                  done: _etape3Faite,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _ChampDate(
                              libelle: 'Date d\'émission',
                              valeur: _fmtDate.format(_dateEmission),
                              icone: Icons.calendar_today_outlined,
                              onTap: _choisirDateEmission,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ChampDate(
                              libelle: 'Valable jusqu\'au',
                              valeur: _dateValidite != null ? _fmtDate.format(_dateValidite!) : 'Non définie',
                              icone: Icons.event_available_outlined,
                              onTap: _choisirDateValidite,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final j in _dureesValidite)
                            ChoiceChip(
                              label: Text('$j jours', style: const TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                              selected: _joursValidite == j,
                              onSelected: (_) => setState(() => _dateValidite = _dateEmission.add(Duration(days: j))),
                            ),
                        ],
                      ),
                      const FieldHint('Une durée de validité claire protège vos prix et rassure le client.'),
                      const SizedBox(height: 14),
                      const Text(
                        'MODALITÉS DE PAIEMENT',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.muted,
                          letterSpacing: .6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final e in _conditionsTypes.entries)
                            ActionChip(
                              label: Text(e.key, style: const TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setState(() => _conditionsCtrl.text = e.value),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _conditionsCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Conditions de règlement & garanties',
                          hintText: 'Ex. Acompte de 30 % à la commande, solde à la livraison.',
                          alignLabelWithHint: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =================================================================== Composants UI

class _CarteCard extends StatelessWidget {
  const _CarteCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// Bandeau navy en tête de page : où j'en suis dans la création du devis.
class _EnteteProgression extends StatelessWidget {
  const _EnteteProgression({required this.faites, required this.total});
  final int faites;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pret = faites == total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navy, AppColors.navy.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Votre devis en 3 étapes',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '$faites/$total',
                style: const TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: faites / total,
              minHeight: 6,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pret
                ? 'Tout est prêt : vous pouvez créer le devis.'
                : 'Complétez chaque étape pour un devis clair et professionnel.',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ChampDate extends StatelessWidget {
  const _ChampDate({
    required this.libelle,
    required this.valeur,
    required this.icone,
    required this.onTap,
  });

  final String libelle;
  final String valeur;
  final IconData icone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: libelle,
          prefixIcon: Icon(icone, size: 18, color: AppColors.navy),
        ),
        child: Text(valeur, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }
}

class _LignesVides extends StatelessWidget {
  const _LignesVides({required this.onAjouter});
  final VoidCallback onAjouter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.format_list_bulleted_add, size: 32, color: AppColors.muted),
          const SizedBox(height: 8),
          const Text(
            'Aucune prestation chiffrée',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.ink),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ajoutez les travaux, pièces ou forfaits pour constituer le devis.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onAjouter,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Ajouter une ligne'),
          ),
        ],
      ),
    );
  }
}

class _EnteteLignes extends StatelessWidget {
  const _EnteteLignes();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: .4);
    return const Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 48, 6),
      child: Row(
        children: [
          SizedBox(width: 24, child: Text('N°', style: style)),
          Expanded(child: Text('DÉSIGNATION', style: style)),
          Text('MONTANT', style: style),
        ],
      ),
    );
  }
}

class _LigneItem extends ConsumerWidget {
  const _LigneItem({
    required this.numero,
    required this.ligne,
    required this.onModifier,
    required this.onSupprimer,
  });

  final int numero;
  final LignePrestation ligne;
  final VoidCallback onModifier;
  final VoidCallback onSupprimer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(ligne.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onSupprimer(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.only(right: 18),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.negative.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.negative),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onModifier,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text('$numero',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ligne.libelle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      const SizedBox(height: 2),
                      Text(
                        '${formatQuantite(ligne.quantite)} × ${montant(context, ref, ligne.prixUnitaire)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  montant(context, ref, ligne.totalLigne),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.navy),
                ),
                IconButton(
                  tooltip: 'Retirer',
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.negative),
                  onPressed: onSupprimer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Recapitulatif extends ConsumerWidget {
  const _Recapitulatif({required this.sousTotal, required this.remise, required this.total});

  final int sousTotal;
  final int remise;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget ligne(String label, String val, {bool estTotal = false, Color? couleur}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: estTotal ? 14 : 12.5,
                    fontWeight: estTotal ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              Text(
                val,
                style: TextStyle(
                  fontSize: estTotal ? 16 : 13,
                  fontWeight: estTotal ? FontWeight.w900 : FontWeight.w700,
                  color: couleur ?? (estTotal ? AppColors.navy : null),
                ),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ligne('Sous-total', montant(context, ref, sousTotal)),
          if (remise > 0)
            ligne('Remise accordée', '− ${montant(context, ref, remise)}', couleur: AppColors.negative),
          const Divider(height: 12),
          ligne('Net à payer', montant(context, ref, total), estTotal: true),
          if (total > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Arrêté le présent devis à la somme de : ${montantEnLettres(total)} francs CFA.',
              style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _BarreTotal extends ConsumerWidget {
  const _BarreTotal({
    required this.remise,
    required this.total,
    required this.envoi,
    required this.onEnregistrer,
  });

  final int remise;
  final int total;
  final bool envoi;
  final VoidCallback onEnregistrer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, -3)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    remise > 0 ? 'Net à payer (remise incluse)' : 'Net à payer',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    montant(context, ref, total),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: AppColors.navy,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(160, 48),
                backgroundColor: AppColors.navy,
              ),
              onPressed: envoi ? null : onEnregistrer,
              icon: envoi
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_rounded, size: 20),
              label: const Text('Créer le devis', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- Feuille « ligne »

class _LigneSheet extends ConsumerStatefulWidget {
  const _LigneSheet({required this.catalogue, this.existante});
  final List<ServiceCatalogue> catalogue;
  final LignePrestation? existante;

  @override
  ConsumerState<_LigneSheet> createState() => _LigneSheetState();
}

class _LigneSheetState extends ConsumerState<_LigneSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _libelleCtrl;
  late final TextEditingController _prixCtrl;
  late final TextEditingController _qteCtrl;
  ServiceCatalogue? _selectionne;

  @override
  void initState() {
    super.initState();
    final e = widget.existante;
    _libelleCtrl = TextEditingController(text: e?.libelle ?? '');
    _prixCtrl = TextEditingController(text: e != null ? '${e.prixUnitaire}' : '');
    _qteCtrl = TextEditingController(text: e != null ? formatQuantite(e.quantite) : '1');
    if (e?.serviceId != null) {
      for (final s in widget.catalogue) {
        if (s.id == e!.serviceId) _selectionne = s;
      }
    }
  }

  @override
  void dispose() {
    _libelleCtrl.dispose();
    _prixCtrl.dispose();
    _qteCtrl.dispose();
    super.dispose();
  }

  double get _qte => double.tryParse(_qteCtrl.text.trim().replaceAll(',', '.')) ?? 0;
  int get _prix => int.tryParse(_prixCtrl.text.trim().replaceAll(' ', '')) ?? 0;

  void _ajusterQuantite(double delta) {
    final nouvelle = (_qte + delta).clamp(1, 100000).toDouble();
    setState(() => _qteCtrl.text = formatQuantite(nouvelle));
  }

  void _valider() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(LignePrestation(
      id: widget.existante?.id ?? const Uuid().v4(),
      serviceId: _selectionne?.id,
      libelle: _libelleCtrl.text.trim(),
      quantite: _qte,
      prixUnitaire: _prix,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final edition = widget.existante != null;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(
                edition ? 'Modifier la ligne' : 'Ajouter une prestation ou fourniture',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              if (widget.catalogue.isNotEmpty) ...[
                DropdownButtonFormField<ServiceCatalogue?>(
                  value: _selectionne,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Depuis le catalogue de services (facultatif)',
                    prefixIcon: Icon(Icons.menu_book_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Ligne libre / Sur-mesure')),
                    for (final s in widget.catalogue)
                      DropdownMenuItem(
                        value: s,
                        child: Text(
                          '${s.nom} — ${montant(context, ref, s.prix)} / ${s.unite.libelle}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (s) => setState(() {
                    _selectionne = s;
                    if (s != null) {
                      _libelleCtrl.text = s.nom;
                      _prixCtrl.text = s.prix.toString();
                    }
                  }),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _libelleCtrl,
                autofocus: !edition && widget.catalogue.isEmpty,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Désignation *',
                  hintText: 'Ex. Pose de disjoncteur, Câble 2.5mm², Main-d\'œuvre...',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Décrivez la prestation ou la fourniture' : null,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qteCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: InputDecoration(
                        labelText: 'Quantité *',
                        suffixText: _selectionne?.unite.libelle,
                      ),
                      validator: (_) => _qte <= 0 ? 'La quantité doit être supérieure à 0' : null,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _prixCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Prix unitaire *', suffixText: 'FCFA'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Indiquez le prix (0 si offert)' : null,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton.outlined(
                    tooltip: 'Moins',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.remove_rounded, size: 18),
                    onPressed: () => _ajusterQuantite(-1),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'Plus',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    onPressed: () => _ajusterQuantite(1),
                  ),
                  const SizedBox(width: 10),
                  const Text('Ajuster la quantité', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Text('Total de la ligne',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.muted)),
                    const Spacer(),
                    Text(
                      montant(context, ref, (_qte * _prix).round()),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.navy),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AppColors.navy,
                ),
                onPressed: _valider,
                child: Text(
                  edition ? 'Enregistrer la modification' : 'Ajouter au devis',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =================================================================== Utilitaires

String formatQuantite(double q) {
  if (q == q.roundToDouble()) return q.toInt().toString();
  return q.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll('.', ',');
}

const _unites = [
  'zéro', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf',
  'dix', 'onze', 'douze', 'treize', 'quatorze', 'quinze', 'seize',
];

String _sous100(int n, {bool invariable = false}) {
  if (n < 17) return _unites[n];
  if (n < 20) return 'dix-${_unites[n - 10]}';
  final d = n ~/ 10, r = n % 10;
  if (d == 7) return n == 71 ? 'soixante-et-onze' : 'soixante-${_sous100(n - 60)}';
  if (d == 9) return 'quatre-vingt-${_sous100(n - 80)}';
  const dizaines = {2: 'vingt', 3: 'trente', 4: 'quarante', 5: 'cinquante', 6: 'soixante', 8: 'quatre-vingt'};
  final base = dizaines[d]!;
  if (r == 0) return (d == 8 && !invariable) ? 'quatre-vingts' : base;
  if (r == 1 && d != 8) return '$base-et-un';
  return '$base-${_unites[r]}';
}

String _sous1000(int n, {bool invariable = false}) {
  final c = n ~/ 100, r = n % 100;
  if (c == 0) return _sous100(r, invariable: invariable);
  final cent = c == 1 ? 'cent' : '${_unites[c]}-cent${r == 0 && !invariable ? 's' : ''}';
  final centBase = c == 1 ? 'cent' : '${_unites[c]}-cent';
  return r == 0 ? cent : '$centBase-${_sous100(r, invariable: invariable)}';
}

/// Montant en toutes lettres (orthographe rectifiée de 1990).
String montantEnLettres(int n) {
  String brut(int n) {
    if (n == 0) return 'zéro';
    final parts = <String>[];
    final mrd = n ~/ 1000000000;
    final mio = (n ~/ 1000000) % 1000;
    final mil = (n ~/ 1000) % 1000;
    final reste = n % 1000;
    if (mrd > 0) parts.add('${brut(mrd)}-milliard${mrd > 1 ? 's' : ''}');
    if (mio > 0) parts.add('${_sous1000(mio)}-million${mio > 1 ? 's' : ''}');
    if (mil > 0) parts.add(mil == 1 ? 'mille' : '${_sous1000(mil, invariable: true)}-mille');
    if (reste > 0) parts.add(_sous1000(reste));
    return parts.join('-');
  }

  final s = brut(n < 0 ? 0 : n);
  return s[0].toUpperCase() + s.substring(1);
}